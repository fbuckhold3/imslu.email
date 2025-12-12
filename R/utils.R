#' Helper functions to summarize evaluation and attendance data from REDCap
#'
#' These functions process the resident data which includes:
#' - Assessment records (repeated instrument)
#' - Faculty evaluation records (repeated instrument)


#' Count assessments by specialty
#'
#' @param res_data Resident data from REDCap
#' @return Summary table with specialty and count
count_by_specialty <- function(res_data) {
  # Filter to Assessment records only
  assessments <- res_data[res_data$redcap_repeat_instrument == "Assessment" &
                           !is.na(res_data$ass_date), ]

  # Count by specialty
  specialty_counts <- assessments %>%
    dplyr::group_by(ass_specialty) %>%
    dplyr::summarize(
      `Number of Evaluations` = dplyr::n(),
      .groups = 'drop'
    ) %>%
    dplyr::arrange(dplyr::desc(`Number of Evaluations`))

  # Rename column for display
  colnames(specialty_counts)[1] <- "Specialty"

  return(as.data.frame(specialty_counts))
}


#' Count assessments by faculty provider
#'
#' @param res_data Resident data from REDCap
#' @return Summary table with faculty name and count
count_by_provider <- function(res_data) {
  # Filter to Assessment records only
  assessments <- res_data[res_data$redcap_repeat_instrument == "Assessment" &
                           !is.na(res_data$ass_date), ]

  # Count by faculty
  provider_counts <- assessments %>%
    dplyr::group_by(ass_faculty) %>%
    dplyr::summarize(
      `Number of Evaluations` = dplyr::n(),
      .groups = 'drop'
    ) %>%
    dplyr::arrange(dplyr::desc(`Number of Evaluations`))

  # Rename column for display
  colnames(provider_counts)[1] <- "Faculty"

  return(as.data.frame(provider_counts))
}


#' Count assessments by resident
#'
#' @param res_data Resident data from REDCap
#' @return Summary table with resident name and count
count_by_resident <- function(res_data) {
  # Filter to Assessment records only
  assessments <- res_data[res_data$redcap_repeat_instrument == "Assessment" &
                           !is.na(res_data$ass_date), ]

  # Count by resident, also include their level
  resident_counts <- assessments %>%
    dplyr::group_by(name, ass_level) %>%
    dplyr::summarize(
      `Number of Evaluations` = dplyr::n(),
      .groups = 'drop'
    ) %>%
    dplyr::arrange(dplyr::desc(`Number of Evaluations`))

  # Rename columns for display
  colnames(resident_counts)[1:2] <- c("Resident", "Level")

  return(as.data.frame(resident_counts))
}


#' Count faculty evaluations (attendance/completion of faculty evals)
#'
#' @param res_data Resident data from REDCap
#' @return Summary table showing faculty evaluation counts by resident
count_faculty_evals <- function(res_data) {
  # Filter to Faculty Evaluation records only
  fac_evals <- res_data[res_data$redcap_repeat_instrument == "Faculty Evaluation" &
                         !is.na(res_data$fac_eval_date), ]

  # Count by resident
  fac_eval_counts <- fac_evals %>%
    dplyr::group_by(name) %>%
    dplyr::summarize(
      `Faculty Evaluations Completed` = dplyr::n(),
      .groups = 'drop'
    ) %>%
    dplyr::arrange(dplyr::desc(`Faculty Evaluations Completed`))

  # Rename column for display
  colnames(fac_eval_counts)[1] <- "Resident"

  return(as.data.frame(fac_eval_counts))
}
