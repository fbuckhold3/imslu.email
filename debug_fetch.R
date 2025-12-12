# Debug the fetch function to see why Faculty Evals with NA record_id aren't being filtered

library(httr)

cat("=== DEBUGGING FETCH FUNCTION ===\n\n")

# Inline the fetch function with debugging
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

cat("1. AFTER INITIAL FETCH:\n")
fac_all <- res_data[!is.na(res_data$redcap_repeat_instrument) &
                     res_data$redcap_repeat_instrument == "Faculty Evaluation", ]
cat("   Total Faculty Evals:", nrow(fac_all), "\n")
cat("   With NA record_id:", sum(is.na(fac_all$record_id)), "\n\n")

# Apply the filtering logic with debugging
cat("2. APPLYING FILTER LOGIC:\n")

is_fac_eval <- !is.na(res_data$redcap_repeat_instrument) & res_data$redcap_repeat_instrument == "Faculty Evaluation"
cat("   is_fac_eval: ", sum(is_fac_eval, na.rm = TRUE), "TRUE\n")

has_invalid_record <- is.na(res_data$record_id)
cat("   has_invalid_record: ", sum(has_invalid_record), "TRUE\n")

fac_eval_with_invalid <- is_fac_eval & has_invalid_record
cat("   fac_eval_with_invalid: ", sum(fac_eval_with_invalid, na.rm = TRUE), "TRUE\n")

both_invalid <- is.na(res_data$redcap_repeat_instrument) & has_invalid_record
cat("   both_invalid: ", sum(both_invalid, na.rm = TRUE), "TRUE\n")

bad_rows <- fac_eval_with_invalid | both_invalid
cat("   bad_rows (before NA handling): ", sum(bad_rows, na.rm = TRUE), "TRUE, ", sum(is.na(bad_rows)), "NA\n")

bad_rows[is.na(bad_rows)] <- FALSE
cat("   bad_rows (after NA->FALSE): ", sum(bad_rows), "TRUE\n\n")

res_data_filtered <- res_data[!bad_rows, , drop = FALSE]

cat("3. AFTER FILTERING:\n")
fac_after <- res_data_filtered[!is.na(res_data_filtered$redcap_repeat_instrument) &
                                res_data_filtered$redcap_repeat_instrument == "Faculty Evaluation", ]
cat("   Total Faculty Evals:", nrow(fac_after), "\n")
cat("   With NA record_id:", sum(is.na(fac_after$record_id)), "\n\n")

cat("4. CHECKING SPECIFIC ROWS:\n")
# Find Faculty Evals with NA record_id before filtering
problem_rows_before <- which(is_fac_eval & has_invalid_record)
cat("   Row indices with Faculty Eval + NA record_id BEFORE filter:", length(problem_rows_before), "\n")
if (length(problem_rows_before) > 0) {
  cat("   First few: ", head(problem_rows_before, 10), "\n")
  cat("   bad_rows status for these: ", bad_rows[head(problem_rows_before, 5)], "\n")
}

cat("\n=== CONCLUSION ===\n")
if (sum(is.na(fac_after$record_id)) == 0) {
  cat("✅ Filter WORKED - no NA record_ids after filtering\n")
} else {
  cat("❌ Filter FAILED -", sum(is.na(fac_after$record_id)), "NA record_ids still present\n")
  cat("   This should be impossible if the logic is correct!\n")
}
