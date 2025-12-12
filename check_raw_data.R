# Check raw data structure from REDCap before any filtering
library(httr)
library(dplyr)

cat("=== RAW DATA CHECK (before filtering) ===\n\n")

# Fetch data WITHOUT our custom filters
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
raw_data <- read.csv(text = httr::content(response, "text", encoding = "UTF-8"),
                     stringsAsFactors = FALSE)

cat("1. RAW DATA STRUCTURE:\n")
cat("   Total rows:", nrow(raw_data), "\n")
cat("   record_id class:", class(raw_data$record_id), "\n\n")

# Check Faculty Evaluations specifically
fac_evals_raw <- raw_data[!is.na(raw_data$redcap_repeat_instrument) &
                           raw_data$redcap_repeat_instrument == "Faculty Evaluation", ]

cat("2. RAW FACULTY EVALUATIONS:\n")
cat("   Total:", nrow(fac_evals_raw), "\n")
cat("   With is.na(record_id):", sum(is.na(fac_evals_raw$record_id)), "\n")
cat("   With record_id == '':", sum(fac_evals_raw$record_id == "", na.rm = TRUE), "\n")
cat("   With record_id == 'NA':", sum(fac_evals_raw$record_id == "NA", na.rm = TRUE), "\n\n")

# Sample of problematic record_ids
cat("3. SAMPLE OF PROBLEMATIC RECORD_IDS:\n")
problem_rows <- fac_evals_raw[is.na(fac_evals_raw$record_id) |
                               fac_evals_raw$record_id == "" |
                               fac_evals_raw$record_id == "NA", ]

if (nrow(problem_rows) > 0) {
  cat("   Found", nrow(problem_rows), "problematic rows\n")
  cat("   Showing first 5:\n\n")

  for (i in 1:min(5, nrow(problem_rows))) {
    cat("   Row", i, ":\n")
    cat("     record_id value: '", problem_rows$record_id[i], "'\n", sep = "")
    cat("     is.na(): ", is.na(problem_rows$record_id[i]), "\n", sep = "")
    cat("     == 'NA': ", !is.na(problem_rows$record_id[i]) && problem_rows$record_id[i] == "NA", "\n", sep = "")
    cat("     == '': ", !is.na(problem_rows$record_id[i]) && problem_rows$record_id[i] == "", "\n", sep = "")
    cat("     nchar(): ", nchar(as.character(problem_rows$record_id[i])), "\n", sep = "")
    if (!is.na(problem_rows$fac_eval_date[i])) {
      cat("     fac_eval_date: ", problem_rows$fac_eval_date[i], "\n", sep = "")
    }
    cat("\n")
  }
} else {
  cat("   No problematic rows found!\n")
}

cat("\n4. CHECKING WHAT FILTERS WOULD CATCH:\n")
cat("   Rows with !is.na(record_id):", sum(!is.na(fac_evals_raw$record_id)), "\n")
cat("   Rows with !is.na(record_id) & record_id != '':", sum(!is.na(fac_evals_raw$record_id) & fac_evals_raw$record_id != ""), "\n")
cat("   Rows with !is.na(record_id) & record_id != '' & record_id != 'NA':",
    sum(!is.na(fac_evals_raw$record_id) & fac_evals_raw$record_id != "" & fac_evals_raw$record_id != "NA"), "\n")

cat("\n=== END RAW DATA CHECK ===\n")
