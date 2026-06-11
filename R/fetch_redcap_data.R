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


#' Fetch Faculty Data with Routing Fields for Individual Report Sending
#'
#' Returns all active faculty and fellows with the fields needed to:
#'   - Identify division/section directors (fac_admin == "Yes")
#'   - Identify fellowship PDs (fac_med_ed___5 == "Checked")
#'   - Route reports correctly (fac_fell: Faculty vs Fellow)
#'
#' @param url REDCap API URL
#' @param token Faculty database API token
#' @return Data frame with one row per active faculty/fellow, including routing fields
fetch_faculty_routing <- function(url = Sys.getenv("REDCAP_URL"),
                                  token = Sys.getenv("REDCAP_FAC_TOKEN")) {

  # Use raw values so checkbox columns (fac_med_ed___5) come back as 0/1
  # and dropdown/yesno fields are consistent for filtering
  formData <- list(
    "token"                  = token,
    content                  = 'record',
    action                   = 'export',
    format                   = 'csv',
    type                     = 'flat',
    csvDelimiter             = '',
    'forms[0]'               = 'faculty_demographics',
    rawOrLabel               = 'raw',
    rawOrLabelHeaders        = 'raw',
    exportCheckboxLabel      = 'false',
    exportSurveyFields       = 'false',
    exportDataAccessGroups   = 'false',
    returnFormat             = 'json'
  )

  response <- httr::POST(url, body = formData, encode = "form")

  fac_data <- read.csv(text = httr::content(response, "text", encoding = "UTF-8"),
                       stringsAsFactors = FALSE)

  if (nrow(fac_data) == 0) {
    warning("No faculty data returned from REDCap")
    return(data.frame())
  }

  # Raw values: archived 0 = active, 1 = archived
  if ("archived" %in% names(fac_data)) {
    fac_data <- fac_data[fac_data$archived == 0 | is.na(fac_data$archived), , drop = FALSE]
  }

  # Drop records with no email
  if ("fac_email" %in% names(fac_data)) {
    fac_data <- fac_data[!is.na(fac_data$fac_email) & nchar(trimws(fac_data$fac_email)) > 0, , drop = FALSE]
  }

  # Division mapping (from data dictionary fac_div choices)
  div_labels <- c(
    "1"  = "Addiction Medicine",
    "2"  = "Allergy",
    "3"  = "Cardiology",
    "4"  = "Endocrinology",
    "5"  = "Gastroenterology",
    "6"  = "Geriatrics",
    "7"  = "GIM - Hospitalist",
    "8"  = "GIM - Primary Care",
    "9"  = "Hematology / Oncology",
    "10" = "Infectious Disease",
    "11" = "Nephrology",
    "12" = "Palliative Care",
    "13" = "Pulmonary / Critical Care",
    "14" = "Rheumatology",
    "15" = "Other"
  )

  if ("fac_div" %in% names(fac_data)) {
    fac_data$fac_div_label <- div_labels[as.character(fac_data$fac_div)]
  }

  # Raw values:
  #   fac_fell:  1 = Faculty, 2 = Fellow
  #   fac_admin: 1 = Yes (division/section head), 0 = No
  #   fac_med_ed___5: 1 = Checked (Fellowship PD), 0 = Unchecked
  #   dep_lead:  1 = Yes, 0 = No

  return(fac_data)
}


#' Build Division Routing Lookup Tables
#'
#' Given the full faculty routing data frame, returns two named vectors:
#'   $admin:  fac_div -> email of division/section director
#'   $fellow_pd: fac_div -> email of fellowship PD
#'
#' @param routing_data Output of fetch_faculty_routing()
#' @return List with $admin and $fellow_pd named vectors (div code -> email)
build_routing_tables <- function(routing_data) {

  # Division admins (section heads): fac_admin == 1
  admins <- routing_data[!is.na(routing_data$fac_admin) & routing_data$fac_admin == 1, ]
  admin_lookup <- stats::setNames(admins$fac_email, as.character(admins$fac_div))

  # Fellowship PDs: fac_med_ed___5 == 1
  pd_col <- "fac_med_ed___5"
  if (pd_col %in% names(routing_data)) {
    pds <- routing_data[!is.na(routing_data[[pd_col]]) & routing_data[[pd_col]] == 1, ]
    pd_lookup <- stats::setNames(pds$fac_email, as.character(pds$fac_div))
  } else {
    warning("fac_med_ed___5 column not found — fellowship PD routing unavailable")
    pd_lookup <- character(0)
  }

  list(admin = admin_lookup, fellow_pd = pd_lookup)
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
