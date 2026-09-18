# send_resident_digests.R
#
# Renders an individual weekly digest for each active resident, then POSTs
# to a dedicated Power Automate HTTP trigger which sends the email — same
# pattern as send_faculty_reports.R (render -> base64 -> POST), no
# SharePoint/manifest-CSV file drop involved.
#
# Required .Renviron vars:
#   REDCAP_URL                    REDCap API base URL
#   RDM_TOKEN                     RDM database token (test or prod, your call)
#   DIGEST_APP_URL                Deployed imslu.resident.digest Connect URL
#   POWER_AUTOMATE_RESIDENT_URL   HTTP trigger URL from the resident PA flow
#                                 (separate from faculty's POWER_AUTOMATE_URL)
#
# Usage:
#   source("send_resident_digests.R")             # sends to all active residents
#   source("send_resident_digests.R")             # set TEST_MODE <- TRUE below to dry-run
#
# Resident email field confirmed live against RDM prod (redcap-dictionary-
# review, 2026-09-16): "email" on resident_data.

library(httr)
library(dplyr)
library(quarto)
library(base64enc)

# ---- Configuration ----------------------------------------------------------

REPORT_QMD <- "resident_weekly_digest.qmd"

RESIDENT_EMAIL_FIELD <- "email"

rdm_token      <- Sys.getenv("RDM_TOKEN", unset = "")
redcap_url     <- Sys.getenv("REDCAP_URL", unset = "https://redcapsurvey.slu.edu/api/")
digest_app_url <- Sys.getenv("DIGEST_APP_URL", unset = "")
PA_URL         <- Sys.getenv("POWER_AUTOMATE_RESIDENT_URL", unset = "")

# Set TRUE to render + print routing info without POSTing to Power Automate
TEST_MODE <- FALSE

# Rate limit between PA trigger calls (seconds) — avoids overwhelming the flow
PA_DELAY_SEC <- 2

if (!nzchar(rdm_token)) stop("RDM_TOKEN not set.")
if (!nzchar(PA_URL) && !TEST_MODE) stop("POWER_AUTOMATE_RESIDENT_URL not set — see header comment.")
if (!nzchar(digest_app_url))
  message("NOTE: DIGEST_APP_URL not set — digests will render without action links.")

# ---- Active resident roster + email ────────────────────────────────────────

message("Fetching resident roster from REDCap...")
residents_raw <- {
  resp <- httr::POST(
    redcap_url,
    body = list(token = rdm_token, content = "record", action = "export",
                format = "json", type = "flat",
                `forms[0]` = "resident_data", rawOrLabel = "raw", rawOrLabelHeaders = "raw",
                exportCheckboxLabel = "false", exportSurveyFields = "false",
                exportDataAccessGroups = "false", returnFormat = "json"),
    encode = "form", httr::timeout(30))
  if (httr::status_code(resp) != 200) stop("Resident pull failed: HTTP ", httr::status_code(resp))
  jsonlite::fromJSON(httr::content(resp, "text", encoding = "UTF-8"))
}

if (!RESIDENT_EMAIL_FIELD %in% names(residents_raw)) {
  stop("Field '", RESIDENT_EMAIL_FIELD, "' not found on resident_data.")
}

active_residents <- residents_raw |>
  filter(is.na(res_archive) | res_archive %in% c("0", "")) |>
  filter(!record_id %in% c("157", "999", "2039")) |>   # rotator placeholder / test records
  filter(!is.na(name), name != "") |>
  transmute(record_id, name, email = .data[[RESIDENT_EMAIL_FIELD]])

message(sprintf("  %d active resident(s) found", nrow(active_residents)))

# Optional: single-name filter for testing
args <- commandArgs(trailingOnly = TRUE)
if (length(args) > 0) {
  name_filter <- args[1]
  active_residents <- active_residents |> filter(grepl(name_filter, name, ignore.case = TRUE))
  message(sprintf("  Filtering to %d resident(s) matching '%s'", nrow(active_residents), name_filter))
}
if (nrow(active_residents) == 0) stop("No residents found. Check filters/environment.")

# ---- Pre-fetch shared data once for the whole batch ─────────────────────────
# Each resident's digest renders in its own quarto subprocess, so without
# this every one of them independently re-pulls the entire Amion dataset +
# resident roster from scratch (87 residents = 87 full re-pulls). Fetch once
# here, hand it to each subprocess via a temp .rds file + env var (inherited
# by quarto_render()'s child process); build_resident_digest_data() picks it
# up automatically when DIGEST_BATCH_CACHE is set.
message("\nPre-fetching shared Amion/roster data once for the whole batch...")
digest_cache_path <- tempfile(fileext = ".rds")
saveRDS(list(
  crosswalk = amiontools::get_amion_crosswalk(rdm_token = rdm_token, redcap_url = redcap_url, verified_only = TRUE),
  amion     = amiontools::fetch_amion_data(),
  roster    = gmed::load_rdm_residents_only(rdm_token = rdm_token, redcap_url = redcap_url)
), digest_cache_path)
Sys.setenv(DIGEST_BATCH_CACHE = digest_cache_path)
message("  Cached to ", digest_cache_path)

# ---- Helper: render + send one digest ───────────────────────────────────────

send_one_digest <- function(record_id, name, email) {

  # quarto_render()'s output_file must be a bare filename (Quarto rejects a
  # path), so render into the project dir under that name, then move it
  # somewhere temp-safe and clean up — same workaround render_resident_
  # digests.R already uses.
  out_filename <- sprintf(".digest_render_%s.html", record_id)
  outfile <- file.path(tempdir(), out_filename)
  project_root <- getwd()

  ok <- tryCatch({
    quarto::quarto_render(
      input          = REPORT_QMD,
      output_file    = out_filename,
      execute_dir    = project_root,
      execute_params = list(record_id = record_id, resident_name = name,
                            rdm_token = rdm_token, redcap_url = redcap_url,
                            digest_app_url = digest_app_url),
      quiet = TRUE
    )
    if (file.exists(file.path(project_root, out_filename))) {
      file.rename(file.path(project_root, out_filename), outfile)
      TRUE
    } else FALSE
  }, error = function(e) {
    message(sprintf("  ERROR rendering digest for %s: %s", name, e$message))
    FALSE
  })

  if (!isTRUE(ok) || !file.exists(outfile)) {
    message(sprintf("  SKIP %s — render produced no output file", name))
    return(invisible(NULL))
  }
  on.exit(unlink(outfile), add = TRUE)

  if (is.na(email) || nchar(trimws(email)) == 0) {
    message(sprintf("  SKIP %s — no email on file", name))
    return(invisible(NULL))
  }

  # Extract just our own content div (between the qmd's EMAIL_BODY markers)
  # for the email body -- sending the whole rendered document (with its own
  # <html>/<head>/<body>) as an email Body renders inconsistently across
  # clients. See resident_weekly_digest.qmd for the marker comments.
  rendered <- paste(readLines(outfile, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  m <- regmatches(rendered, regexpr(
    "(?s)(?<=<!--EMAIL_BODY_START-->).*(?=<!--EMAIL_BODY_END-->)",
    rendered, perl = TRUE))
  if (length(m) == 0 || !nzchar(m)) {
    message(sprintf("  ERROR: could not find EMAIL_BODY markers in rendered output for %s", name))
    return(invisible(NULL))
  }
  html_body <- trimws(m)

  message(sprintf("  %-30s -> %s", name, email))

  if (TEST_MODE) {
    message("  TEST MODE — skipping POST")
    return(invisible(NULL))
  }

  resp <- tryCatch(
    httr::POST(
      PA_URL,
      httr::content_type_json(),
      body = jsonlite::toJSON(list(
        to_email      = email,
        resident_name = name,
        person_type   = "resident",
        html_body     = html_body
      ), auto_unbox = TRUE)
    ),
    error = function(e) {
      message(sprintf("  ERROR posting for %s: %s", name, e$message))
      NULL
    }
  )

  if (!is.null(resp) && httr::status_code(resp) >= 400) {
    body_txt <- tryCatch(httr::content(resp, "text", encoding = "UTF-8"), error = function(e) "(no body)")
    message(sprintf("  ERROR: PA returned HTTP %d for %s\n    %s",
                    httr::status_code(resp), name, substr(body_txt, 1, 500)))
  }

  Sys.sleep(PA_DELAY_SEC)
}

# ---- Send Resident Digests ───────────────────────────────────────────────────

message("\n--- Sending resident digests ---")

for (i in seq_len(nrow(active_residents))) {
  row <- active_residents[i, ]
  send_one_digest(record_id = row$record_id, name = row$name, email = row$email)
}

unlink(digest_cache_path)

message("\nDone. Check above for any warnings or errors.")
