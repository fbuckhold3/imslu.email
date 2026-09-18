# fetch_resident_digest_data.R ── assembles one resident's weekly-digest
# payload. Every domain pulls through the same shared functions ind.dash
# and imslu.resident.digest use (amiontools/gmed) — this file is a thin
# aggregation layer, not a re-implementation.
#
# NEW DEPENDENCY for this repo: gmed + amiontools (GitHub-installed, same
# as every other app in this ecosystem). imslu.email didn't depend on
# either before this — flagged for Fred to add via
# renv::install("fbuckhold3/gmed"); renv::install("fbuckhold3/amiontools")
# and renv::snapshot(), never edited into renv.lock directly here.
#
# Email rendering constraint: this data feeds an HTML email (Power
# Automate/Outlook delivery), so the .qmd that consumes it must render with
# plain HTML tables + static ggplot2 images only — no plotly/DT/htmlwidgets
# (Outlook doesn't run JS). This file just returns plain data.frames/lists;
# the chart-vs-table decision lives in the .qmd itself.

#' Build the full weekly-digest payload for one resident.
#'
#' @param record_id RDM record_id.
#' @param rdm_token,redcap_url REDCap credentials (test or prod — caller's
#'   choice; render_resident_digests.R decides which).
#' @param digest_app_url Base URL of the deployed imslu.resident.digest app.
#'   Not used by any per-domain field here — the .qmd links to it directly
#'   via `params$digest_app_url` for its two generic "update your
#'   information" buttons (Fred's call, 2026-09-17: per-section deep links
#'   read as odd/redundant when they all open the same app).
#' @return A named list — see inline comments for each element's shape.
#' @export
build_resident_digest_data <- function(record_id, rdm_token, redcap_url,
                                       digest_app_url = "") {

  # ── Batch pre-fetch cache: send_resident_digests.R (looping over the full
  # roster) sets DIGEST_BATCH_CACHE to an .rds path containing a pre-pulled
  # crosswalk/amion/roster, so each resident's separate quarto_render()
  # subprocess doesn't re-pull the entire Amion dataset + roster from
  # scratch. Unset (e.g. the live Shiny app rendering one resident at
  # login, or an ad hoc test render) -> falls back to fetching fresh, same
  # as before this existed.
  .cache_path <- Sys.getenv("DIGEST_BATCH_CACHE", unset = "")
  .cache <- if (nzchar(.cache_path) && file.exists(.cache_path)) {
    tryCatch(readRDS(.cache_path), error = function(e) NULL)
  } else NULL

  # ── Header info: access code + coach name (same fields the Shiny app's
  # roundsui_resident_panel() shows) ────────────────────────────────────────
  resident <- tryCatch({
    roster <- if (!is.null(.cache)) .cache$roster else
      gmed::load_rdm_residents_only(rdm_token = rdm_token, redcap_url = redcap_url)
    row <- roster[roster$record_id == as.character(record_id), , drop = FALSE]
    access_code <- if (nrow(row) > 0) row$access_code[1] else NA_character_
    coach_code  <- if (nrow(row) > 0) row$coach[1] else NA_character_
    coach_name  <- if (!is.na(coach_code) && nzchar(coach_code)) {
      tryCatch(gmed::get_coach_name_from_code(coach_code), error = function(e) NA_character_)
    } else NA_character_
    list(access_code = access_code, coach_name = coach_name)
  }, error = function(e) list(access_code = NA_character_, coach_name = NA_character_))

  # ── Duty hours: this week's total + 4-week rolling average + 80h flag ────
  duty <- tryCatch({
    summ <- if (!is.null(.cache)) {
      amiontools::build_duty_hour_summary(rdm_token = rdm_token, redcap_url = redcap_url,
                                          crosswalk = .cache$crosswalk, amion = .cache$amion)
    } else {
      amiontools::build_duty_hour_summary(rdm_token = rdm_token, redcap_url = redcap_url)
    }
    wk <- summ$weekly[summ$weekly$record_id == as.character(record_id), , drop = FALSE]
    wk <- wk[order(wk$week_start), ]
    this_wk <- if (nrow(wk) > 0) wk[nrow(wk), ] else NULL
    list(
      this_week_hours   = if (!is.null(this_wk)) round(this_wk$Total_Hours, 1) else NA_real_,
      rolling_4wk_avg   = if (!is.null(this_wk)) round(this_wk$rolling_4wk_avg_hours, 1) else NA_real_,
      flag_80h          = if (!is.null(this_wk)) isTRUE(this_wk$flag_80h) else FALSE
    )
  }, error = function(e) list(this_week_hours = NA_real_, rolling_4wk_avg = NA_real_,
                              flag_80h = FALSE))

  # ── Upcoming week's schedule (next Mon-Sun) ───────────────────────────────
  schedule <- tryCatch({
    today <- Sys.Date()
    next_mon <- today + ((8 - as.integer(format(today, "%u"))) %% 7)
    if (next_mon == today) next_mon <- today + 7  # always the NEXT week, not today's
    next_sun <- next_mon + 6
    detail <- if (!is.null(.cache)) {
      amiontools::build_daily_detail(rdm_token = rdm_token, redcap_url = redcap_url,
                                     crosswalk = .cache$crosswalk, amion = .cache$amion)
    } else {
      amiontools::build_daily_detail(rdm_token = rdm_token, redcap_url = redcap_url)
    }
    rows <- detail[detail$record_id == as.character(record_id) &
                     detail$Date >= next_mon & detail$Date <= next_sun, , drop = FALSE]
    rows <- rows[order(rows$Date), ]
    list(week_start = next_mon, week_end = next_sun, rows = rows)
  }, error = function(e) list(week_start = NA, week_end = NA, rows = data.frame()))

  # ── Noon-conference attendance this week ──────────────────────────────────
  attendance <- tryCatch({
    today <- Sys.Date()
    week_start <- today - ((as.integer(format(today, "%u")) - 1) %% 7)
    resp <- httr::POST(
      redcap_url,
      body = list(token = rdm_token, content = "record", action = "export",
                  format = "json", type = "flat",
                  records = as.character(record_id), `forms[0]` = "questions",
                  `fields[0]` = "record_id",
                  rawOrLabel = "raw", rawOrLabelHeaders = "raw",
                  exportCheckboxLabel = "false", exportSurveyFields = "false",
                  exportDataAccessGroups = "false", returnFormat = "json"),
      encode = "form", httr::timeout(30))
    n_this_week <- 0L
    if (httr::status_code(resp) == 200) {
      dat <- jsonlite::fromJSON(httr::content(resp, "text", encoding = "UTF-8"))
      if (is.data.frame(dat) && nrow(dat) > 0) {
        dat <- dat[!is.na(dat$redcap_repeat_instrument) &
                     dat$redcap_repeat_instrument == "questions", , drop = FALSE]
        dts <- suppressWarnings(as.Date(dat$q_date))
        n_this_week <- sum(dts >= week_start & dts <= today, na.rm = TRUE)
      }
    }
    list(week_start = week_start, n_this_week = n_this_week)
  }, error = function(e) list(week_start = NA, n_this_week = NA_integer_))

  # ── Evaluations received (past week) + completed (last 2 weeks) ─────────
  evals <- tryCatch({
    received <- gmed::count_recent_instances(rdm_token = rdm_token, redcap_url = redcap_url,
      record_id = record_id, instrument = "assessment", date_field = "ass_date", days = 7)
    completed <- gmed::count_recent_instances(rdm_token = rdm_token, redcap_url = redcap_url,
      record_id = record_id, instrument = "faculty_evaluation", date_field = "fac_eval_date", days = 14)
    completed_this_week <- gmed::count_recent_instances(rdm_token = rdm_token, redcap_url = redcap_url,
      record_id = record_id, instrument = "faculty_evaluation", date_field = "fac_eval_date", days = 7)
    list(n_received_week = received$n, n_completed_2wk = completed$n,
         completed_done_this_week = completed_this_week$n > 0)
  }, error = function(e) list(n_received_week = NA_integer_, n_completed_2wk = NA_integer_,
                              completed_done_this_week = TRUE))

  # ── Peer reviews: completed (last 2 weeks) + recently worked with (4 wks) ─
  peer <- tryCatch({
    completed <- amiontools::peer_count_completed_recent(
      evaluator_id = record_id, redcap_url = redcap_url, rdm_token = rdm_token, days = 14)
    completed_this_week <- amiontools::peer_count_completed_recent(
      evaluator_id = record_id, redcap_url = redcap_url, rdm_token = rdm_token, days = 7)
    teammates <- if (!is.null(.cache)) {
      amiontools::get_recent_teammates(
        resident_id = record_id, rdm_token = rdm_token, redcap_url = redcap_url, days = 28,
        crosswalk = .cache$crosswalk, amion = .cache$amion)
    } else {
      amiontools::get_recent_teammates(
        resident_id = record_id, rdm_token = rdm_token, redcap_url = redcap_url, days = 28)
    }
    list(n_completed_2wk = completed$n, done_this_week = completed_this_week$n > 0,
         teammates = teammates)
  }, error = function(e) list(n_completed_2wk = NA_integer_, done_this_week = TRUE,
                              teammates = data.frame()))

  list(
    record_id  = record_id,
    resident   = resident,
    duty       = duty,
    schedule   = schedule,
    attendance = attendance,
    evals      = evals,
    peer       = peer
  )
}
