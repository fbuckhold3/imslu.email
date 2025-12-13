# Helper script to get email distribution list
# This can be sourced by the report or used for Connect Cloud email configuration

library(dplyr)
source("R/fetch_redcap_data.R")

#' Get email distribution list for weekly report
#'
#' @return Character vector of email addresses
get_email_list <- function() {
  # Fetch both datasets
  fac_data <- fetch_faculty_data()
  res_data <- fetch_resident_data()

  # Get faculty emails
  fac_emails <- character(0)
  if ("fac_email" %in% names(fac_data)) {
    fac_emails <- fac_data$fac_email[!is.na(fac_data$fac_email) & fac_data$fac_email != ""]
  }

  # Get resident emails from main records (not repeating instruments)
  res_emails <- character(0)
  if ("email" %in% names(res_data)) {
    main_records <- res_data[is.na(res_data$redcap_repeat_instrument) |
                              res_data$redcap_repeat_instrument == "", ]
    res_emails <- main_records$email[!is.na(main_records$email) & main_records$email != ""]
  }

  # Combine and remove duplicates
  all_emails <- unique(c(fac_emails, res_emails))

  # Remove any invalid emails (basic validation)
  all_emails <- all_emails[grepl("@", all_emails)]

  return(all_emails)
}

# For testing: uncomment to see the email list
# email_list <- get_email_list()
# cat("Total recipients:", length(email_list), "\n")
# cat("Sample emails:\n")
# print(head(email_list, 10))
