#!/usr/bin/env Rscript
# Deploy weekly report to Posit Connect Cloud
# Run this script from the project root directory

library(rsconnect)

cat("====================================\n")
cat("IMSLU Weekly Report Deployment\n")
cat("====================================\n\n")

# Check if already configured
accounts <- accounts()

if (nrow(accounts) == 0) {
  cat("No Posit Connect Cloud account configured.\n\n")
  cat("Please run the following commands in R first:\n\n")
  cat('library(rsconnect)\n')
  cat('connectApiUser(\n')
  cat('  account = "your-account-name",\n')
  cat('  server = "connect.posit.cloud",\n')
  cat('  apiKey = "your-api-key"\n')
  cat(')\n\n')
  cat("Get your API key from: https://connect.posit.cloud (Your Name > API Keys)\n\n")
  stop("Configuration required")
}

cat("Deploying to Posit Connect Cloud...\n\n")
cat("Account:", accounts$name[1], "\n")
cat("Server:", accounts$server[1], "\n\n")

# Deploy the Quarto document
result <- deployDoc(
  doc = "weekly_report.qmd",
  appTitle = "IMSLU Weekly Assessment Report",
  server = accounts$server[1],
  account = accounts$name[1],
  forceUpdate = TRUE
)

cat("\n====================================\n")
cat("Deployment Complete!\n")
cat("====================================\n\n")

cat("Next steps:\n")
cat("1. Go to: https://connect.posit.cloud\n")
cat("2. Find: 'IMSLU Weekly Assessment Report'\n")
cat("3. Click Settings > Schedule\n")
cat("4. Add Schedule:\n")
cat("   - Frequency: Weekly\n")
cat("   - Day: Monday\n")
cat("   - Time: 08:00 (your timezone)\n")
cat("5. Enable 'Send email'\n")
cat("6. Test with 'Run Schedule Now'\n\n")

cat("The email list will automatically pull from:\n")
cat("  - Faculty: fac_data$fac_email\n")
cat("  - Residents: res_data$email\n\n")

cat("✓ Deployment successful!\n")
