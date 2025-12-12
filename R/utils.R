#' Helper functions for REDCap evaluation report
#'
#' These functions analyze assessment data by type, time period, and specialty


#' Get current academic year start date (July 1)
get_academic_year_start <- function() {
  today <- Sys.Date()
  year <- as.numeric(format(today, "%Y"))
  month <- as.numeric(format(today, "%m"))

  # If before July, academic year started last year
  if (month < 7) {
    return(as.Date(paste0(year - 1, "-07-01")))
  } else {
    return(as.Date(paste0(year, "-07-01")))
  }
}


#' Determine assessment type based on which fields are populated
#'
#' @param row Single row of assessment data
#' @return Assessment type as string
determine_assessment_type <- function(row) {
  # Check which type of assessment fields are filled
  # Priority order matters if multiple types could be filled

  # Check for Continuity Clinic (cc_)
  cc_cols <- grep("^ass_cc_", names(row), value = TRUE)
  if (any(!is.na(row[cc_cols]))) {
    return("Continuity Clinic")
  }

  # Check for Clinic Day (day_)
  day_cols <- grep("^ass_day_", names(row), value = TRUE)
  if (any(!is.na(row[day_cols]))) {
    return("Clinic Day")
  }

  # Check for Consults (cons_)
  cons_cols <- grep("^ass_cons_", names(row), value = TRUE)
  if (any(!is.na(row[cons_cols]))) {
    return("Consults")
  }

  # Check for Intern Inpatient (int_ip_)
  int_ip_cols <- grep("^ass_int_ip_", names(row), value = TRUE)
  if (any(!is.na(row[int_ip_cols]))) {
    return("Intern Inpatient")
  }

  # Check for Resident Inpatient (res_ip_)
  res_ip_cols <- grep("^ass_res_ip_", names(row), value = TRUE)
  if (any(!is.na(row[res_ip_cols]))) {
    return("Resident Inpatient")
  }

  # Check for Observational (obs_)
  obs_cols <- grep("^ass_obs_", names(row), value = TRUE)
  if (any(!is.na(row[obs_cols]))) {
    return("Observational")
  }

  # If none match, return "Other"
  return("Other")
}


#' Add assessment type column to data
#'
#' @param assessments Assessment data frame
#' @return Data frame with assessment_type column added
add_assessment_type <- function(assessments) {
  # Handle empty data frame
  if (nrow(assessments) == 0) {
    assessments$assessment_type <- character(0)
    return(assessments)
  }

  assessments$assessment_type <- apply(assessments, 1, determine_assessment_type)
  return(assessments)
}


#' Count assessments by type and specialty for a time period
#'
#' @param res_data Resident data from REDCap
#' @param start_date Start date for filtering (Date object)
#' @param period_label Label for the time period (e.g., "Last 4 Weeks", "Academic Year")
#' @return Summary table
count_assessments_by_type_specialty <- function(res_data, start_date, period_label) {
  # Handle empty input
  if (nrow(res_data) == 0) {
    return(data.frame(`Assessment Type` = character(0),
                     Specialty = character(0),
                     Count = integer(0),
                     check.names = FALSE))
  }

  # Filter to Assessment records
  assessments <- res_data[res_data$redcap_repeat_instrument == "Assessment" &
                           !is.na(res_data$ass_date), , drop = FALSE]

  # Return empty if no assessments
  if (nrow(assessments) == 0) {
    return(data.frame(`Assessment Type` = character(0),
                     Specialty = character(0),
                     Count = integer(0),
                     check.names = FALSE))
  }

  # Convert ass_date to Date if needed
  if (!inherits(assessments$ass_date, "Date")) {
    assessments$ass_date <- as.Date(assessments$ass_date)
  }

  # Filter by date
  assessments <- assessments[assessments$ass_date >= start_date, , drop = FALSE]

  # Return empty if no assessments in date range
  if (nrow(assessments) == 0) {
    return(data.frame(`Assessment Type` = character(0),
                     Specialty = character(0),
                     Count = integer(0),
                     check.names = FALSE))
  }

  # Add assessment type
  assessments <- add_assessment_type(assessments)

  # Count by type and specialty
  summary_table <- assessments %>%
    dplyr::group_by(assessment_type, ass_specialty) %>%
    dplyr::summarize(
      Count = dplyr::n(),
      .groups = 'drop'
    ) %>%
    dplyr::arrange(assessment_type, dplyr::desc(Count))

  colnames(summary_table) <- c("Assessment Type", "Specialty", period_label)

  return(as.data.frame(summary_table))
}


#' Count total assessments by type for a time period
#'
#' @param res_data Resident data from REDCap
#' @param start_date Start date for filtering
#' @return Summary table
count_assessments_by_type <- function(res_data, start_date) {
  # Handle empty input
  if (nrow(res_data) == 0) {
    return(data.frame(`Assessment Type` = character(0),
                     `Total Count` = integer(0),
                     check.names = FALSE))
  }

  assessments <- res_data[res_data$redcap_repeat_instrument == "Assessment" &
                           !is.na(res_data$ass_date), , drop = FALSE]

  # Return empty if no assessments
  if (nrow(assessments) == 0) {
    return(data.frame(`Assessment Type` = character(0),
                     `Total Count` = integer(0),
                     check.names = FALSE))
  }

  if (!inherits(assessments$ass_date, "Date")) {
    assessments$ass_date <- as.Date(assessments$ass_date)
  }

  assessments <- assessments[assessments$ass_date >= start_date, , drop = FALSE]

  # Return empty if no assessments in date range
  if (nrow(assessments) == 0) {
    return(data.frame(`Assessment Type` = character(0),
                     `Total Count` = integer(0),
                     check.names = FALSE))
  }

  assessments <- add_assessment_type(assessments)

  summary_table <- assessments %>%
    dplyr::group_by(assessment_type) %>%
    dplyr::summarize(
      `Total Count` = dplyr::n(),
      .groups = 'drop'
    ) %>%
    dplyr::arrange(dplyr::desc(`Total Count`))

  colnames(summary_table)[1] <- "Assessment Type"

  return(as.data.frame(summary_table))
}


#' Find top faculty by assessment count for a time period
#'
#' @param res_data Resident data from REDCap
#' @param start_date Start date for filtering
#' @param top_n Number of top faculty to return
#' @return Data frame with top faculty
get_top_faculty <- function(res_data, start_date, top_n = 5) {
  # Handle empty input
  if (nrow(res_data) == 0) {
    return(data.frame(Faculty = character(0),
                     `Evaluations Completed` = integer(0),
                     check.names = FALSE))
  }

  assessments <- res_data[res_data$redcap_repeat_instrument == "Assessment" &
                           !is.na(res_data$ass_date), , drop = FALSE]

  if (nrow(assessments) == 0) {
    return(data.frame(Faculty = character(0),
                     `Evaluations Completed` = integer(0),
                     check.names = FALSE))
  }

  if (!inherits(assessments$ass_date, "Date")) {
    assessments$ass_date <- as.Date(assessments$ass_date)
  }

  assessments <- assessments[assessments$ass_date >= start_date, , drop = FALSE]

  if (nrow(assessments) == 0) {
    return(data.frame(Faculty = character(0),
                     `Evaluations Completed` = integer(0),
                     check.names = FALSE))
  }

  top_faculty <- assessments %>%
    dplyr::group_by(ass_faculty) %>%
    dplyr::summarize(
      `Evaluations Completed` = dplyr::n(),
      .groups = 'drop'
    ) %>%
    dplyr::arrange(dplyr::desc(`Evaluations Completed`)) %>%
    dplyr::slice(1:top_n)

  colnames(top_faculty)[1] <- "Faculty"

  return(as.data.frame(top_faculty))
}


#' Find top residents by faculty evaluation count for a time period
#'
#' @param res_data Resident data from REDCap
#' @param start_date Start date for filtering
#' @param top_n Number of top residents to return
#' @return Data frame with top residents
get_top_residents_fac_eval <- function(res_data, start_date, top_n = 5) {
  # Handle empty input
  if (nrow(res_data) == 0) {
    return(data.frame(Resident = character(0),
                     `Faculty Evals Completed` = integer(0),
                     check.names = FALSE))
  }

  fac_evals <- res_data[res_data$redcap_repeat_instrument == "Faculty Evaluation" &
                         !is.na(res_data$fac_eval_date), , drop = FALSE]

  if (nrow(fac_evals) == 0) {
    return(data.frame(Resident = character(0),
                     `Faculty Evals Completed` = integer(0),
                     check.names = FALSE))
  }

  if (!inherits(fac_evals$fac_eval_date, "Date")) {
    fac_evals$fac_eval_date <- as.Date(fac_evals$fac_eval_date)
  }

  fac_evals <- fac_evals[fac_evals$fac_eval_date >= start_date, , drop = FALSE]

  if (nrow(fac_evals) == 0) {
    return(data.frame(Resident = character(0),
                     `Faculty Evals Completed` = integer(0),
                     check.names = FALSE))
  }

  top_residents <- fac_evals %>%
    dplyr::group_by(name) %>%
    dplyr::summarize(
      `Faculty Evals Completed` = dplyr::n(),
      .groups = 'drop'
    ) %>%
    dplyr::arrange(dplyr::desc(`Faculty Evals Completed`)) %>%
    dplyr::slice(1:top_n)

  colnames(top_residents)[1] <- "Resident"

  return(as.data.frame(top_residents))
}


#' Count questions by rotation for a time period
#'
#' @param res_data Resident data from REDCap
#' @param start_date Start date for filtering
#' @return Summary table
count_questions_by_rotation <- function(res_data, start_date) {
  # Handle empty input
  if (nrow(res_data) == 0) {
    return(data.frame(Rotation = character(0),
                     `Question Count` = integer(0),
                     check.names = FALSE))
  }

  questions <- res_data[res_data$redcap_repeat_instrument == "Questions" &
                         !is.na(res_data$q_date), , drop = FALSE]

  if (nrow(questions) == 0) {
    return(data.frame(Rotation = character(0),
                     `Question Count` = integer(0),
                     check.names = FALSE))
  }

  if (!inherits(questions$q_date, "Date")) {
    questions$q_date <- as.Date(questions$q_date)
  }

  questions <- questions[questions$q_date >= start_date, , drop = FALSE]

  if (nrow(questions) == 0) {
    return(data.frame(Rotation = character(0),
                     `Question Count` = integer(0),
                     check.names = FALSE))
  }

  rotation_counts <- questions %>%
    dplyr::group_by(q_rotation) %>%
    dplyr::summarize(
      `Question Count` = dplyr::n(),
      .groups = 'drop'
    ) %>%
    dplyr::arrange(dplyr::desc(`Question Count`))

  colnames(rotation_counts)[1] <- "Rotation"

  return(as.data.frame(rotation_counts))
}
