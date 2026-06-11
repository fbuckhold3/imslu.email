# send_faculty_reports.R
#
# Renders an individual Quarto report for each active faculty member and fellow,
# then POSTs to a Power Automate HTTP trigger which sends the email.
#
# Routing:
#   Faculty (fac_fell == 1): CC goes to division/section director (fac_admin == 1)
#   Fellow  (fac_fell == 2): CC goes to fellowship PD (fac_med_ed___5 == 1)
#
# Required .Renviron vars:
#   REDCAP_URL               REDCap API base URL
#   REDCAP_FAC_TOKEN         IMSLUFaculty database token
#   POWER_AUTOMATE_URL       HTTP trigger URL from your PA flow
#
# Usage:
#   source("send_faculty_reports.R")          # sends to all active faculty/fellows
#   source("send_faculty_reports.R")          # set TEST_MODE <- TRUE below to dry-run

library(httr)
library(dplyr)
library(quarto)
library(base64enc)

source("R/fetch_redcap_data.R")

# ---- Configuration ----------------------------------------------------------

# Path to the parameterized Quarto report
REPORT_QMD <- "faculty_report.qmd"          # update if your file is named differently

# Power Automate HTTP trigger URL (set in .Renviron, never hardcode)
PA_URL <- Sys.getenv("POWER_AUTOMATE_URL")

# Set TRUE to render + print routing info without POSTing to Power Automate
TEST_MODE <- FALSE

# Rate limit between PA trigger calls (seconds) — avoids overwhelming the flow
PA_DELAY_SEC <- 2

# ---- Fetch & Build Routing --------------------------------------------------

message("Fetching faculty routing data from REDCap...")
routing_data <- fetch_faculty_routing()

if (nrow(routing_data) == 0) stop("No active faculty returned — check REDCap token and URL.")

message(sprintf("  %d active records found", nrow(routing_data)))

# Build division -> director email and division -> fellowship PD email lookups
routing_tables <- build_routing_tables(routing_data)

# Diagnostic: report any divisions with no admin or PD mapped
all_divs <- unique(as.character(routing_data$fac_div[!is.na(routing_data$fac_div)]))
unmapped_admin <- setdiff(all_divs, names(routing_tables$admin))
unmapped_pd    <- setdiff(all_divs, names(routing_tables$fellow_pd))

if (length(unmapped_admin) > 0) {
  div_labels <- c("1"="Addiction Medicine","2"="Allergy","3"="Cardiology",
                  "4"="Endocrinology","5"="Gastroenterology","6"="Geriatrics",
                  "7"="GIM - Hospitalist","8"="GIM - Primary Care",
                  "9"="Hematology / Oncology","10"="Infectious Disease",
                  "11"="Nephrology","12"="Palliative Care",
                  "13"="Pulmonary / Critical Care","14"="Rheumatology","15"="Other")
  message("WARNING: No division admin mapped for: ",
          paste(div_labels[unmapped_admin], collapse = ", "))
}
if (length(unmapped_pd) > 0) {
  message("NOTE: No fellowship PD mapped for divisions: ",
          paste(unmapped_pd, collapse = ", "),
          " (only relevant if fellows exist in those divisions)")
}

# ---- Separate Faculty vs Fellows --------------------------------------------

# fac_fell: 1 = Faculty, 2 = Fellow
faculty <- routing_data %>% filter(fac_fell == 1)
fellows <- routing_data %>% filter(fac_fell == 2)

message(sprintf("  %d faculty, %d fellows to process", nrow(faculty), nrow(fellows)))

# ---- Helper: render + send one report ---------------------------------------

send_one_report <- function(record_id, fac_name, fac_email, fac_div,
                             fac_div_label, person_type, cc_email) {

  # -- Render --
  outfile <- tempfile(fileext = ".html")

  tryCatch({
    quarto::quarto_render(
      input        = REPORT_QMD,
      output_file  = outfile,
      execute_params = list(
        record_id    = record_id,
        fac_name     = fac_name,
        person_type  = person_type    # "faculty" or "fellow" — use in QMD if needed
      )
    )
  }, error = function(e) {
    message(sprintf("  ERROR rendering report for %s: %s", fac_name, e$message))
    return(NULL)
  })

  if (!file.exists(outfile)) {
    message(sprintf("  SKIP %s — render produced no output file", fac_name))
    return(invisible(NULL))
  }

  # -- Route CC -----------------------------------------------------------------
  if (is.na(cc_email) || nchar(trimws(cc_email)) == 0) {
    message(sprintf("  WARNING: No CC email for %s (div %s) — sending without CC",
                    fac_name, fac_div_label))
    cc_email <- ""
  }

  # -- Encode --
  html_b64 <- base64encode(outfile)
  safe_name <- gsub("[^A-Za-z0-9]", "_", fac_name)
  filename  <- paste0(safe_name, "_Faculty_Report.html")

  # -- Log --
  message(sprintf("  [%s] %s -> %s | CC: %s",
                  toupper(person_type), fac_name, fac_email,
                  if (nchar(cc_email) > 0) cc_email else "(none)"))

  if (TEST_MODE) {
    message("  TEST MODE — skipping POST")
    return(invisible(NULL))
  }

  # -- POST to Power Automate --
  resp <- tryCatch(
    httr::POST(
      PA_URL,
      httr::content_type_json(),
      body = jsonlite::toJSON(list(
        to_email               = fac_email,
        cc_email               = cc_email,
        faculty_name           = fac_name,
        division               = fac_div_label,
        person_type            = person_type,
        html_attachment_base64 = html_b64,
        filename               = filename
      ), auto_unbox = TRUE)
    ),
    error = function(e) {
      message(sprintf("  ERROR posting for %s: %s", fac_name, e$message))
      NULL
    }
  )

  if (!is.null(resp) && httr::status_code(resp) >= 400) {
    message(sprintf("  ERROR: PA returned HTTP %d for %s", httr::status_code(resp), fac_name))
  }

  Sys.sleep(PA_DELAY_SEC)
}

# ---- Send Faculty Reports ---------------------------------------------------

message("\n--- Sending faculty reports ---")

for (i in seq_len(nrow(faculty))) {
  row      <- faculty[i, ]
  div_key  <- as.character(row$fac_div)
  cc_email <- routing_tables$admin[div_key]
  cc_email <- if (is.na(cc_email)) "" else cc_email

  send_one_report(
    record_id    = row$record_id,
    fac_name     = row$fac_name,
    fac_email    = row$fac_email,
    fac_div      = div_key,
    fac_div_label = if (!is.na(row$fac_div_label)) row$fac_div_label else paste("Division", div_key),
    person_type  = "faculty",
    cc_email     = cc_email
  )
}

# ---- Send Fellow Reports ----------------------------------------------------

message("\n--- Sending fellow reports ---")

for (i in seq_len(nrow(fellows))) {
  row      <- fellows[i, ]
  div_key  <- as.character(row$fac_div)
  cc_email <- routing_tables$fellow_pd[div_key]
  cc_email <- if (is.na(cc_email)) "" else cc_email

  send_one_report(
    record_id    = row$record_id,
    fac_name     = row$fac_name,
    fac_email    = row$fac_email,
    fac_div      = div_key,
    fac_div_label = if (!is.na(row$fac_div_label)) row$fac_div_label else paste("Division", div_key),
    person_type  = "fellow",
    cc_email     = cc_email
  )
}

message("\nDone. Check above for any warnings or errors.")
