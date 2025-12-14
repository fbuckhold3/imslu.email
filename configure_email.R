#!/usr/bin/env Rscript
# Test email delivery for Posit Connect Cloud
# Run this after deploying to set up email for a specific recipient

library(rsconnect)

# For testing, we'll use a simple email configuration
# Replace these with your actual values:
TEST_EMAIL <- "Fred.buckhold@slucare.ssmhealth.com"

cat("This script will help configure email delivery for your deployed report.\n\n")
cat("To configure email delivery:\n")
cat("1. Go to your content on Posit Connect Cloud\n")
cat("2. Click 'Settings' tab\n")
cat("3. Look for 'Schedule' or 'Output' section\n")
cat("4. When creating a schedule, look for:\n")
cat("   - 'Email' checkbox\n")
cat("   - 'Send email when this content runs' option\n")
cat("   - 'Recipients' or 'Email To' field\n")
cat("\nTest email address:", TEST_EMAIL, "\n")
cat("\nIf you don't see email options, the Quarto email blocks should handle it automatically.\n")
cat("The email blocks in weekly_report.qmd define:\n")
cat("  - Subject: IMSLU Weekly Assessment Report - [Date]\n")
cat("  - Body: Summary with quick stats\n")
cat("  - Attachment: Full HTML report\n")
