#!/usr/bin/env Rscript
# Test email distribution list before deploying
# This verifies the email list is working correctly

library(dplyr)
source("R/fetch_redcap_data.R")
source("R/get_email_list.R")

cat("====================================\n")
cat("Testing Email Distribution List\n")
cat("====================================\n\n")

# Fetch data
cat("Fetching data from REDCap...\n")
fac_data <- fetch_faculty_data()
res_data <- fetch_resident_data()

cat("✓ Data fetched successfully\n\n")

# Check faculty emails
cat("Faculty Data:\n")
cat("  Total faculty records:", nrow(fac_data), "\n")
if ("fac_email" %in% names(fac_data)) {
  fac_emails <- fac_data$fac_email[!is.na(fac_data$fac_email) & fac_data$fac_email != ""]
  cat("  Faculty emails found:", length(fac_emails), "\n")
  cat("  Sample faculty emails:\n")
  print(head(fac_emails, 5))
} else {
  cat("  ⚠ WARNING: 'fac_email' field not found in faculty data!\n")
}

cat("\n")

# Check resident emails
cat("Resident Data:\n")
main_records <- res_data[is.na(res_data$redcap_repeat_instrument) |
                          res_data$redcap_repeat_instrument == "", ]
cat("  Total resident records:", nrow(main_records), "\n")
if ("email" %in% names(res_data)) {
  res_emails <- main_records$email[!is.na(main_records$email) & main_records$email != ""]
  cat("  Resident emails found:", length(res_emails), "\n")
  cat("  Sample resident emails:\n")
  print(head(res_emails, 5))
} else {
  cat("  ⚠ WARNING: 'email' field not found in resident data!\n")
}

cat("\n")

# Get combined list
cat("Combined Email List:\n")
email_list <- get_email_list()
cat("  Total unique recipients:", length(email_list), "\n")
cat("  Valid emails (with @):", sum(grepl("@", email_list)), "\n\n")

# Check for issues
cat("Validation:\n")
if (length(email_list) == 0) {
  cat("  ❌ ERROR: No emails found!\n")
  cat("     Check that 'fac_email' and 'email' fields exist in your databases.\n")
} else if (length(email_list) < 5) {
  cat("  ⚠ WARNING: Very few emails found (", length(email_list), ")\n")
  cat("     This seems low. Verify your data.\n")
} else {
  cat("  ✓ Email list looks good!\n")
}

# Check for invalid emails
invalid <- email_list[!grepl("@", email_list)]
if (length(invalid) > 0) {
  cat("  ⚠ WARNING: Found", length(invalid), "invalid email(s):\n")
  print(invalid)
}

cat("\n")

# Show full list for review
cat("Full Email List:\n")
cat("================\n")
for (i in seq_along(email_list)) {
  cat(sprintf("%2d. %s\n", i, email_list[i]))
}

cat("\n====================================\n")
cat("Test Complete!\n")
cat("====================================\n\n")

if (length(email_list) > 0) {
  cat("✓ Ready to deploy\n")
  cat("\nNext step: Run deploy_to_connect.R\n")
} else {
  cat("❌ Fix email configuration before deploying\n")
}
