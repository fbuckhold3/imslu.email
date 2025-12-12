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
  fac_data <- httr::content(response, encoding = "UTF-8")

  # Filter out archived records (archived == "No")
  fac_data <- fac_data[fac_data$archived == "No", ]

  # Select only needed columns
  fac_data <- fac_data[, c("fac_name", "fac_email", "fac_clin", "fac_div")]

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
  res_data <- httr::content(response, encoding = "UTF-8")

  # Filter out archived residents (res_archive != "Yes")
  res_data <- res_data[res_data$res_archive != "Yes", ]

  return(res_data)
}
