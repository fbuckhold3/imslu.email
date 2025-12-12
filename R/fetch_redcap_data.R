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

  # Filter out archived residents
  # Note: res_archive is only set on the main form row, not repeating instruments
  # So we need to identify archived record_ids and filter ALL rows for those IDs
  if ("res_archive" %in% names(res_data) && "record_id" %in% names(res_data)) {
    # Find record_ids where res_archive == "Yes" (on any row for that record)
    archived_ids <- unique(res_data$record_id[res_data$res_archive == "Yes" & !is.na(res_data$res_archive)])

    # Filter out ALL rows for archived record_ids
    if (length(archived_ids) > 0) {
      res_data <- res_data[!res_data$record_id %in% archived_ids, , drop = FALSE]
    }
  }

  # Filter out Assessment records with blank ass_specialty
  # These are typically old/incomplete assessments from data merges
  if ("redcap_repeat_instrument" %in% names(res_data) && "ass_specialty" %in% names(res_data)) {
    # Keep row if it's NOT an Assessment, OR if it IS an Assessment with non-blank specialty
    res_data <- res_data[
      res_data$redcap_repeat_instrument != "Assessment" |
      (!is.na(res_data$ass_specialty) & res_data$ass_specialty != ""),
      , drop = FALSE
    ]
  }

  # Filter out Faculty Evaluation records with invalid record_id
  # Also filter out rows where BOTH redcap_repeat_instrument AND record_id are NA/invalid
  if ("redcap_repeat_instrument" %in% names(res_data) && "record_id" %in% names(res_data)) {
    # Identify Faculty Evaluations
    is_fac_eval <- !is.na(res_data$redcap_repeat_instrument) & res_data$redcap_repeat_instrument == "Faculty Evaluation"

    # Identify invalid record_id (NA, empty string, or string "NA")
    has_invalid_record <- is.na(res_data$record_id) |
                          res_data$record_id == "" |
                          res_data$record_id == "NA"

    # Remove Faculty Evaluations with invalid record_id
    fac_eval_with_invalid <- is_fac_eval & has_invalid_record

    # Also remove rows where BOTH instrument and record_id are invalid (old merge data)
    both_invalid <- is.na(res_data$redcap_repeat_instrument) & has_invalid_record

    # Remove both types of bad rows
    bad_rows <- fac_eval_with_invalid | both_invalid
    res_data <- res_data[!bad_rows, , drop = FALSE]
  }

  return(res_data)
}
