#' Fetch Faculty Demographics from REDCap
#'
#' @param url REDCap API URL
#' @param token Faculty database API token
#' @return Data frame with faculty demographics (fac_name, fac_email, fac_clin, fac_div)
fetch_faculty_data <- function(url = Sys.getenv("REDCAP_URL"),
                                token = Sys.getenv("REDCAP_FAC_TOKEN")) {

  formData <- list(
    "token" = token,
    content = 'record',
    action = 'export',
    format = 'csv',
    type = 'flat',
    csvDelimiter = '',
    'forms[0]' = 'faculty_demographics',
    rawOrLabel = 'label',
    rawOrLabelHeaders = 'raw',
    exportCheckboxLabel = 'false',
    exportSurveyFields = 'false',
    exportDataAccessGroups = 'false',
    returnFormat = 'json'
  )

  response <- httr::POST(url, body = formData, encode = "form")

  # Parse CSV response
  fac_data <- read.csv(text = httr::content(response, "text", encoding = "UTF-8"),
                       stringsAsFactors = FALSE)

  # Check if data was returned
  if (nrow(fac_data) == 0) {
    warning("No faculty data returned from REDCap")
    return(data.frame())
  }

  # Filter out archived records (archived == "No") if column exists
  if ("archived" %in% names(fac_data)) {
    fac_data <- fac_data[fac_data$archived == "No", , drop = FALSE]
  }

  # Select only needed columns if they exist
  needed_cols <- c("fac_name", "fac_email", "fac_clin", "fac_div")
  existing_cols <- intersect(needed_cols, names(fac_data))
  if (length(existing_cols) > 0) {
    fac_data <- fac_data[, existing_cols, drop = FALSE]
  }

  return(fac_data)
}


#' Fetch Resident Data and Evaluations from REDCap
#'
#' @param url REDCap API URL
#' @param token RDM database API token
#' @return Data frame with resident data and evaluations (includes assessments and faculty evaluations)
fetch_resident_data <- function(url = Sys.getenv("REDCAP_URL"),
                                 token = Sys.getenv("REDCAP_RDM_TOKEN")) {

  formData <- list(
    "token" = token,
    content = 'record',
    action = 'export',
    format = 'csv',
    type = 'flat',
    csvDelimiter = '',
    'fields[0]' = 'fac_f_name',
    'forms[0]' = 'resident_data',
    'forms[1]' = 'assessment',
    'forms[2]' = 'faculty_evaluation',
    'forms[3]' = 'questions',
    rawOrLabel = 'label',
    rawOrLabelHeaders = 'raw',
    exportCheckboxLabel = 'false',
    exportSurveyFields = 'false',
    exportDataAccessGroups = 'false',
    returnFormat = 'json'
  )

  response <- httr::POST(url, body = formData, encode = "form")

  # Parse CSV response
  res_data <- read.csv(text = httr::content(response, "text", encoding = "UTF-8"),
                       stringsAsFactors = FALSE)

  # Check if data was returned
  if (nrow(res_data) == 0) {
    warning("No resident data returned from REDCap")
    return(data.frame())
  }

  # Filter out archived residents (res_archive != "Yes") if column exists
  if ("res_archive" %in% names(res_data)) {
    res_data <- res_data[res_data$res_archive != "Yes", , drop = FALSE]
  }

  return(res_data)
}
