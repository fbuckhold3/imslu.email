# render_resident_digests.R
#
# LOCAL PREVIEW/DRY-RUN TOOL — renders one self-contained HTML weekly digest
# per active resident to disk plus a CSV summary, so you can eyeball output
# before sending anything. This is NOT the send path: the real pipeline is
# send_resident_digests.R, which renders + POSTs each digest directly to a
# Power Automate HTTP trigger (mirroring send_faculty_reports.R) — no
# SharePoint/manifest-CSV file drop involved. Use this script only to
# render and inspect files locally.
#
# NEW DEPENDENCY: this script (and resident_weekly_digest.qmd) needs gmed +
# amiontools, which imslu.email didn't depend on before. Flagged for Fred:
#   renv::install("fbuckhold3/gmed")
#   renv::install("fbuckhold3/amiontools")
#   renv::snapshot()
# before this will run — never edited into renv.lock directly here.
#
# Resident email field confirmed live against RDM prod (redcap-dictionary-
# review, 2026-09-16): "email" on resident_data, label "Email address
# (prefer @slucare.ssmhealth.com address)" — RESIDENT_EMAIL_FIELD below.
#
# USAGE (run from project root):
#   Rscript render_resident_digests.R
#   Rscript render_resident_digests.R "Arnold"     # single resident (name match)
#
# ENVIRONMENT (set in .Renviron, TEST vs PROD is your call each run):
#   RDM_TOKEN, REDCAP_URL, DIGEST_APP_URL (deployed imslu.resident.digest URL)
#
# OUTPUT DIRECTORY:
#   Default: output/  (override with OUTPUT_DIR env var, e.g. a
#   SharePoint-synced OneDrive path, matching the faculty pipeline's pattern)

suppressPackageStartupMessages({
  library(dplyr)
  library(quarto)
  library(readr)
})

RESIDENT_EMAIL_FIELD <- "email"   # confirmed live, RDM prod, 2026-09-16

rdm_token      <- Sys.getenv("RDM_TOKEN", unset = "")
redcap_url     <- Sys.getenv("REDCAP_URL", unset = "https://redcapsurvey.slu.edu/api/")
digest_app_url <- Sys.getenv("DIGEST_APP_URL", unset = "")

if (!nzchar(rdm_token)) stop("RDM_TOKEN not set — see .Renviron.example.")
if (!nzchar(digest_app_url))
  message("NOTE: DIGEST_APP_URL not set — digest emails will render without action links.")

# ── Active resident roster + email ────────────────────────────────────────────
# load_rdm_residents_only() doesn't surface email — pull resident_data raw
# for record_id/name/email/archive status directly instead.
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
  stop("Field '", RESIDENT_EMAIL_FIELD, "' not found on resident_data — ",
       "confirm the real email field name (redcap-dictionary-review) before running this.")
}

active_residents <- residents_raw |>
  filter(is.na(res_archive) | res_archive %in% c("0", "")) |>
  filter(!record_id %in% c("157", "999", "2039")) |>   # rotator placeholder / test records
  filter(!is.na(name), name != "") |>
  transmute(record_id, name, email = .data[[RESIDENT_EMAIL_FIELD]])

# Optional: single-name filter for testing
args <- commandArgs(trailingOnly = TRUE)
if (length(args) > 0) {
  name_filter <- args[1]
  active_residents <- active_residents |> filter(grepl(name_filter, name, ignore.case = TRUE))
  cat(sprintf("Filtering to %d resident(s) matching '%s'\n", nrow(active_residents), name_filter))
}
if (nrow(active_residents) == 0) stop("No residents found. Check filters/environment.")

# ── Output directory ───────────────────────────────────────────────────────────
out_dir <- Sys.getenv("OUTPUT_DIR", unset = "output")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
cat(sprintf("Rendering %d resident digests into: %s\n\n", nrow(active_residents), out_dir))

# ── Render loop ────────────────────────────────────────────────────────────────
results <- tibble(
  record_id = character(), name = character(), email = character(),
  status = character(), output_file = character(), rendered_at = character()
)
project_root <- getwd()

for (i in seq_len(nrow(active_residents))) {
  res          <- active_residents[i, ]
  safe_name    <- gsub("[^a-zA-Z0-9]", "_", trimws(res$name))
  out_filename <- sprintf("%s_weekly_digest_%s.html", safe_name, Sys.Date())
  out_path     <- file.path(out_dir, out_filename)

  cat(sprintf("[%d/%d] %-30s", i, nrow(active_residents), res$name))

  tryCatch({
    quarto::quarto_render(
      input          = "resident_weekly_digest.qmd",
      execute_params = list(record_id = res$record_id, resident_name = res$name,
                            rdm_token = rdm_token, redcap_url = redcap_url,
                            digest_app_url = digest_app_url),
      execute_dir    = project_root,
      output_file    = out_filename,
      quiet          = TRUE
    )
    rendered_path <- out_filename
    if (file.exists(rendered_path)) file.rename(rendered_path, out_path)
    else if (!file.exists(out_path)) warning("Output file not found after render: ", rendered_path)

    cat("✓\n")
    results <- add_row(results, record_id = res$record_id, name = res$name,
                       email = coalesce(res$email, NA_character_), status = "success",
                       output_file = out_path, rendered_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
  }, error = function(e) {
    cat("✗  ERROR:", conditionMessage(e), "\n")
    results <<- add_row(results, record_id = res$record_id, name = res$name,
                        email = coalesce(res$email, NA_character_),
                        status = paste("error:", conditionMessage(e)),
                        output_file = NA_character_, rendered_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
  })
}

n_ok <- sum(results$status == "success")
cat(sprintf("\n=== Done: %d succeeded, %d failed ===\n", n_ok, nrow(results) - n_ok))

no_email <- results |> filter(status == "success", is.na(email) | email == "")
if (nrow(no_email) > 0) {
  cat(sprintf("\nWARNING: %d residents have no email on file:\n", nrow(no_email)))
  print(select(no_email, name), n = Inf)
}

# ── Write summary CSV (for local review only — not read by any PA flow) ──────
manifest_path <- file.path(out_dir, sprintf("render_summary_%s.csv", Sys.Date()))
write_csv(results, manifest_path)
cat(sprintf("\nSummary CSV: %s\n", manifest_path))
cat(sprintf("Reports folder:               %s/\n", out_dir))
