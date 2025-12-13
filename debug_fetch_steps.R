# Debug each step of fetch_resident_data() with detailed logging

library(httr)

cat("=== STEP-BY-STEP FETCH DEBUGGING ===\n\n")

url <- Sys.getenv("REDCAP_URL")
token <- Sys.getenv("REDCAP_RDM_TOKEN")

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
res_data <- read.csv(text = httr::content(response, "text", encoding = "UTF-8"),
                     stringsAsFactors = FALSE)

cat("STEP 0: Initial fetch\n")
fac_evals <- res_data[!is.na(res_data$redcap_repeat_instrument) &
                       res_data$redcap_repeat_instrument == "Faculty Evaluation", ]
cat("  Total rows:", nrow(res_data), "\n")
cat("  Faculty Evals:", nrow(fac_evals), "\n")
cat("  Faculty Evals with NA record_id:", sum(is.na(fac_evals$record_id)), "\n\n")

# STEP 1: Archive filter
cat("STEP 1: Archive filter\n")
if ("res_archive" %in% names(res_data) && "record_id" %in% names(res_data)) {
  archived_ids <- unique(res_data$record_id[res_data$res_archive == "Yes" & !is.na(res_data$res_archive)])
  cat("  Archived IDs found:", length(archived_ids), "\n")

  if (length(archived_ids) > 0) {
    res_data <- res_data[!res_data$record_id %in% archived_ids, , drop = FALSE]
    cat("  Rows after archive filter:", nrow(res_data), "\n")
  }
}
fac_evals <- res_data[!is.na(res_data$redcap_repeat_instrument) &
                       res_data$redcap_repeat_instrument == "Faculty Evaluation", ]
cat("  Faculty Evals after archive:", nrow(fac_evals), "\n")
cat("  Faculty Evals with NA record_id:", sum(is.na(fac_evals$record_id)), "\n\n")

# STEP 2: Assessment specialty filter (THE SUSPECT!)
cat("STEP 2: Assessment specialty filter\n")
if ("redcap_repeat_instrument" %in% names(res_data) && "ass_specialty" %in% names(res_data)) {
  # Build filter condition
  filter_cond <- res_data$redcap_repeat_instrument != "Assessment" |
                 (!is.na(res_data$ass_specialty) & res_data$ass_specialty != "")

  cat("  Filter condition: ", sum(filter_cond, na.rm = TRUE), "TRUE, ", sum(is.na(filter_cond)), "NA\n")

  # Check Faculty Evals in filter
  is_fac_eval <- !is.na(res_data$redcap_repeat_instrument) & res_data$redcap_repeat_instrument == "Faculty Evaluation"
  cat("  Faculty Evals in filter_cond==TRUE:", sum(filter_cond[is_fac_eval], na.rm = TRUE), "\n")
  cat("  Faculty Evals in filter_cond==NA:", sum(is.na(filter_cond[is_fac_eval])), "\n")

  res_data <- res_data[filter_cond, , drop = FALSE]
  cat("  Rows after assessment filter:", nrow(res_data), "\n")
}
fac_evals <- res_data[!is.na(res_data$redcap_repeat_instrument) &
                       res_data$redcap_repeat_instrument == "Faculty Evaluation", ]
cat("  Faculty Evals after assessment filter:", nrow(fac_evals), "\n")
cat("  Faculty Evals with NA record_id:", sum(is.na(fac_evals$record_id)), "\n\n")

# STEP 3: Faculty Eval invalid record_id filter
cat("STEP 3: Faculty Eval invalid record_id filter\n")
if ("redcap_repeat_instrument" %in% names(res_data) && "record_id" %in% names(res_data)) {
  is_fac_eval <- !is.na(res_data$redcap_repeat_instrument) & res_data$redcap_repeat_instrument == "Faculty Evaluation"
  has_invalid_record <- is.na(res_data$record_id)
  fac_eval_with_invalid <- is_fac_eval & has_invalid_record
  both_invalid <- is.na(res_data$redcap_repeat_instrument) & has_invalid_record

  bad_rows <- fac_eval_with_invalid | both_invalid
  bad_rows[is.na(bad_rows)] <- FALSE

  cat("  Faculty Evals with invalid record_id to remove:", sum(fac_eval_with_invalid), "\n")
  cat("  Both invalid to remove:", sum(both_invalid), "\n")
  cat("  Total bad rows:", sum(bad_rows), "\n")

  res_data <- res_data[!bad_rows, , drop = FALSE]
  cat("  Rows after Faculty Eval filter:", nrow(res_data), "\n")
}
fac_evals <- res_data[!is.na(res_data$redcap_repeat_instrument) &
                       res_data$redcap_repeat_instrument == "Faculty Evaluation", ]
cat("  Faculty Evals after fac eval filter:", nrow(fac_evals), "\n")
cat("  Faculty Evals with NA record_id:", sum(is.na(fac_evals$record_id)), "\n\n")

cat("=== FINAL RESULT ===\n")
cat("Total rows:", nrow(res_data), "\n")
cat("Faculty Evaluations:", nrow(fac_evals), "\n")
cat("Faculty Evals with NA record_id:", sum(is.na(fac_evals$record_id)), "\n")
