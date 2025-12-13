#!/usr/bin/env Rscript
#' Generate Email Recipient List
#'
#' This script generates the email recipient list from faculty and resident databases
#' for use in Posit Connect email configuration
#'
#' Usage:
#'   Rscript get_email_list.R

# Source helper functions
source("R/fetch_redcap_data.R")

cat("Fetching faculty and resident data from REDCap...\n\n")

# Fetch data from both REDCap databases
fac_data <- fetch_faculty_data()
res_data <- fetch_resident_data()

# Extract faculty emails
fac_emails <- character(0)
if (nrow(fac_data) > 0 && "fac_email" %in% names(fac_data)) {
  fac_emails <- fac_data$fac_email[!is.na(fac_data$fac_email) & fac_data$fac_email != ""]
}

# Extract resident emails (from unique residents, not repeating instances)
res_emails <- character(0)
if (nrow(res_data) > 0 && "email" %in% names(res_data)) {
  # Get unique resident records (redcap_repeat_instrument is empty for main records)
  resident_records <- res_data[is.na(res_data$redcap_repeat_instrument) |
                                res_data$redcap_repeat_instrument == "", , drop = FALSE]
  res_emails <- resident_records$email[!is.na(resident_records$email) &
                                        resident_records$email != ""]
  res_emails <- unique(res_emails)
}

# Summary
cat("Email Recipient Summary:\n")
cat("========================\n")
cat(sprintf("Faculty emails: %d\n", length(fac_emails)))
cat(sprintf("Resident emails: %d\n", length(res_emails)))
cat(sprintf("Total unique recipients: %d\n\n", length(unique(c(fac_emails, res_emails)))))

# Combine and deduplicate
all_emails <- unique(c(fac_emails, res_emails))

# Output for copying
cat("Email List (comma-separated):\n")
cat("==============================\n")
cat(paste(all_emails, collapse = ", "))
cat("\n\n")

# Output as list for easier reading
cat("Email List (one per line):\n")
cat("==========================\n")
cat(paste(all_emails, collapse = "\n"))
cat("\n\n")

cat("Copy the email list above and paste it into Posit Connect's email configuration.\n")
