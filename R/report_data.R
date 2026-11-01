# report_data.R — the one place the Monday weekly report reads data.
#
# Read-only. RDM prod (RDM_TOKEN) + live Amion via amiontools. Constants,
# roster rule and loader are copied from imslu.program.dash (9a5743c,
# R/constants.R + R/load_program_data.R) so the email shows the same
# numbers as the program dashboard. Change them there first, then here,
# until they move into gmed.
#
# Any failed pull stops the render on purpose: Connect then keeps last
# week's page (dated) instead of publishing a half-empty one.

suppressPackageStartupMessages({
  library(dplyr)
})

# Test / non-resident records in RDM prod (157 = rotator placeholder).
TEST_RECORDS <- c("157", "194", "999", "2039", "2040", "2042", "2043")

CLASS_LEVELS <- c("Intern", "PGY2", "PGY3")

# Program expectation: 25 assessments received and 25 faculty evaluations
# done per resident per academic year (about one a week).
ANNUAL_TARGET <- 25

# MKSAP goals (Fred, 2026-10-30), due April 1, pace linear from July 1.
# The dashboard raises a PGY3's goal to the whole bank when their predicted
# ABIM pass is < 90%; that needs ITE + iteviz, so the email uses the class
# goal only.
MKSAP_DUE_MMDD <- "04-01"
MKSAP_GOAL     <- c(Intern = 1000, PGY2 = 2000, PGY3 = 2000)

ay_start_of <- function(date) {
  y <- as.integer(format(date, "%Y"))
  as.Date(sprintf("%d-07-01", ifelse(as.integer(format(date, "%m")) >= 7, y, y - 1L)))
}

# Most recent completed Sunday-Saturday week (a Monday render reports the
# week that ended two days before).
report_week <- function(as_of) {
  sat <- as_of - (as.integer(format(as_of, "%u")) %% 7L + 1L)
  list(start = sat - 6, end = sat)
}

rdm_credentials <- function() {
  # RDM_TOKEN is the ecosystem name; REDCAP_RDM_TOKEN is what this content
  # item was first deployed with, kept as a fallback until it's renamed.
  token <- Sys.getenv("RDM_TOKEN", unset = Sys.getenv("REDCAP_RDM_TOKEN"))
  url   <- Sys.getenv("REDCAP_URL")
  if (!nzchar(token) || !nzchar(url)) {
    stop("RDM_TOKEN and REDCAP_URL must be set (~/.Renviron locally, Connect env vars when deployed).")
  }
  list(token = token, url = url)
}

.rd <- function(cred, fields = NULL, forms = NULL, raw_or_label = "raw") {
  out <- REDCapR::redcap_read(redcap_uri = cred$url, token = cred$token,
                              fields = fields, forms = forms,
                              raw_or_label = raw_or_label, verbose = FALSE)
  if (!out$success) stop("REDCap pull failed: ", out$outcome_message)
  tibble::as_tibble(out$data) |> mutate(record_id = as.character(record_id))
}

.repeat_rows <- function(df, instrument) {
  if (!"redcap_repeat_instrument" %in% names(df)) return(df[0, ])
  df |> filter(!is.na(redcap_repeat_instrument),
               tolower(redcap_repeat_instrument) == tolower(instrument))
}

.base_rows <- function(df) {
  if (!"redcap_repeat_instrument" %in% names(df)) return(df)
  df |> filter(is.na(redcap_repeat_instrument))
}

# Active residents with their class for the academic year starting `ay`
# (same rule as the dashboard, PCEC report and MKSAP import).
build_roster <- function(res, ay) {
  res |>
    .base_rows() |>
    mutate(grad_yr = suppressWarnings(as.integer(as.character(grad_yr))),
           years_left = grad_yr - ay,
           class = case_when(
             type == "Categorical" & years_left == 1L ~ "PGY3",
             type == "Categorical" & years_left == 2L ~ "PGY2",
             type == "Categorical" & years_left == 3L ~ "Intern",
             type == "Preliminary" & years_left == 1L ~ "Intern",
             TRUE ~ NA_character_),
           class = factor(class, levels = CLASS_LEVELS),
           prelim = type == "Preliminary",
           resident = coalesce(
             if_else(!is.na(first_name) & !is.na(last_name),
                     paste(first_name, last_name), NA_character_),
             name)) |>
    filter(!record_id %in% TEST_RECORDS,
           type %in% c("Categorical", "Preliminary"),
           is.na(res_archive) | res_archive != "Yes",
           !is.na(class),
           !grepl("^test$", tolower(coalesce(first_name, ""))),
           !grepl("^test$", tolower(coalesce(last_name, "")))) |>
    select(record_id, resident, class, prelim, clinic_firm) |>
    arrange(class, resident)
}

#' Pull everything the report needs.
#'
#' @param as_of Date the report is "as of" (normally today).
#' @return list(as_of, ay, ay_start, week, roster, activity, assessments,
#'   faculty_evals, peer, mksap)
load_report_data <- function(as_of = Sys.Date(), cred = rdm_credentials()) {
  ay_start <- ay_start_of(as_of)
  ay       <- as.integer(format(ay_start, "%Y"))

  res <- .rd(cred, raw_or_label = "label",
             fields = c("record_id", "name", "first_name", "last_name", "type",
                        "grad_yr", "res_archive", "clinic_firm"))
  roster <- build_roster(res, ay)

  # Whole assessment form: the type classifier reads which item block is
  # filled, and the CC dedupe compares full content.
  assessments <- .rd(cred, forms = "assessment", raw_or_label = "label") |>
    .repeat_rows("assessment") |>
    mutate(ass_date = as.Date(ass_date)) |>
    filter(!is.na(ass_date))

  faculty_evals <- .rd(cred, fields = c("record_id", "fac_eval_date")) |>
    .repeat_rows("faculty_evaluation") |>
    mutate(fac_eval_date = as.Date(fac_eval_date)) |>
    filter(!is.na(fac_eval_date))

  # peer_evaluator_id is only ever counted, never displayed.
  peer <- .rd(cred, fields = c("record_id", "peer_date", "peer_evaluator_id")) |>
    .repeat_rows("peer_eval") |>
    mutate(peer_date = as.Date(peer_date),
           peer_evaluator_id = as.character(peer_evaluator_id))

  mksap <- .rd(cred, fields = c("record_id", "mk_export_date", "mk_n_complete")) |>
    .repeat_rows("mksap_progress") |>
    mutate(mk_export_date = as.Date(mk_export_date),
           mk_n_complete = as.numeric(mk_n_complete))

  # Live Amion + questions log + duty-hour log; ~20 s.
  activity <- amiontools::build_resident_activity(rdm_token = cred$token,
                                                  redcap_url = cred$url,
                                                  ay_start = ay)
  activity$record_id <- as.character(activity$record_id)

  list(as_of = as_of, ay = ay, ay_start = ay_start, week = report_week(as_of),
       roster = roster, activity = activity, assessments = assessments,
       faculty_evals = faculty_evals, peer = peer, mksap = mksap)
}
