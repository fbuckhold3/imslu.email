# Diagnostic Script: Investigate Record_NA in Top Residents
# Run this script to understand why some residents show as "Record_NA"

library(dplyr)

# Load helper functions
source("R/fetch_redcap_data.R")
source("R/utils.R")

# Fetch data
cat("Fetching data...\n")
res_data <- fetch_resident_data()

# Calculate time periods
academic_year_start <- get_academic_year_start()

cat("\n=== DIAGNOSTIC REPORT ===\n\n")

# 1. Check main resident records (where names should be)
cat("1. MAIN RESIDENT RECORDS (where names are stored):\n")
main_records <- res_data[is.na(res_data$redcap_repeat_instrument) |
                          res_data$redcap_repeat_instrument == "",
                        c("record_id", "name"), drop = FALSE]
main_records <- main_records[!duplicated(main_records$record_id), , drop = FALSE]

cat("   Total main records:", nrow(main_records), "\n")
cat("   Records with names:", sum(!is.na(main_records$name) & main_records$name != ""), "\n")
cat("   Records WITHOUT names:", sum(is.na(main_records$name) | main_records$name == ""), "\n\n")

# Show records without names
no_name <- main_records[is.na(main_records$name) | main_records$name == "", ]
if (nrow(no_name) > 0) {
  cat("   Record IDs with missing names:\n")
  print(no_name)
  cat("\n")
}

# 2. Check Faculty Evaluations
cat("2. FACULTY EVALUATIONS:\n")
fac_evals <- res_data[res_data$redcap_repeat_instrument == "Faculty Evaluation" &
                       !is.na(res_data$fac_eval_date), , drop = FALSE]

if (!inherits(fac_evals$fac_eval_date, "Date")) {
  fac_evals$fac_eval_date <- as.Date(fac_evals$fac_eval_date)
}
fac_evals <- fac_evals[fac_evals$fac_eval_date >= academic_year_start, , drop = FALSE]

cat("   Total faculty evaluations this year:", nrow(fac_evals), "\n")
cat("   Unique residents with evaluations:", length(unique(fac_evals$record_id)), "\n\n")

# Count evaluations by record_id
eval_counts <- fac_evals %>%
  group_by(record_id) %>%
  summarize(Count = n(), .groups = 'drop') %>%
  arrange(desc(Count))

cat("   Top 10 residents by evaluation count:\n")
print(head(eval_counts, 10))
cat("\n")

# 3. Identify the problematic records
cat("3. MATCHING EVALUATION RECORDS WITH NAMES:\n")
top_5_ids <- head(eval_counts$record_id, 5)

cat("   Top 5 record_ids:\n")
for (rid in top_5_ids) {
  if (is.na(rid)) {
    cat("   - Record NA → INVALID RECORD_ID ✗✗✗\n")
    cat("     (85 faculty evaluations have NULL/NA record_id - data quality issue!)\n")
    next
  }

  name_match <- main_records[main_records$record_id == rid & !is.na(main_records$record_id), "name"]
  has_name <- length(name_match) > 0 && !is.na(name_match) && name_match != ""

  if (has_name) {
    cat("   - Record", rid, "→ Name:", name_match, "✓\n")
  } else {
    cat("   - Record", rid, "→ NO NAME FOUND ✗\n")

    # Check if this record_id exists at all in main records
    exists_in_main <- rid %in% main_records$record_id
    if (exists_in_main) {
      cat("     (record exists in main records but name is blank/NA)\n")
    } else {
      cat("     (record_id does NOT exist in main records!)\n")
    }
  }
}

cat("\n")

# 4. Deep dive: Check if faculty eval rows have a name field
cat("4. CHECKING NAME FIELD IN FACULTY EVALUATION ROWS:\n")
if ("name" %in% names(fac_evals)) {
  sample_evals <- head(fac_evals[, c("record_id", "name", "fac_eval_date")], 10)
  cat("   Sample faculty evaluation rows (showing record_id and name):\n")
  print(sample_evals)
  cat("\n")

  # Check how many have names directly in the eval rows
  eval_with_names <- sum(!is.na(fac_evals$name) & fac_evals$name != "")
  cat("   Faculty eval rows WITH names in them:", eval_with_names, "\n")
  cat("   Faculty eval rows WITHOUT names:", nrow(fac_evals) - eval_with_names, "\n")
} else {
  cat("   'name' column does not exist in faculty evaluation rows\n")
}

cat("\n")

# 5. Full details of NA record_id evaluations
cat("5. FULL DETAILS OF NA RECORD_ID EVALUATIONS:\n")
na_evals <- fac_evals[is.na(fac_evals$record_id), ]

if (nrow(na_evals) > 0) {
  cat("   Found", nrow(na_evals), "evaluations with NA record_id\n\n")

  # Show first 5 complete rows
  cat("   Showing first 5 complete rows (all columns):\n")
  cat("   =============================================\n\n")

  for (i in 1:min(5, nrow(na_evals))) {
    cat("   --- Evaluation", i, "---\n")
    row <- na_evals[i, ]

    # Get all column names and values
    for (col_name in names(row)) {
      val <- row[[col_name]]
      if (!is.na(val) && val != "") {
        cat("   ", col_name, ": ", val, "\n", sep="")
      }
    }
    cat("\n")
  }

  # Save full details to CSV for deeper analysis
  csv_file <- "na_record_id_evaluations.csv"
  write.csv(na_evals, csv_file, row.names = FALSE)
  cat("   All", nrow(na_evals), "NA record_id evaluations saved to:", csv_file, "\n")
} else {
  cat("   No evaluations with NA record_id found\n")
}

cat("\n")

# 6. Recommendation
cat("6. RECOMMENDATION:\n")

na_count <- sum(is.na(fac_evals$record_id))
if (na_count > 0) {
  cat("   CRITICAL ISSUE: ", na_count, " faculty evaluations have NA record_id\n", sep="")
  cat("   Action needed:\n")
  cat("   - Check REDCap Faculty Evaluation form submissions\n")
  cat("   - These evaluations are missing the resident identifier\n")
  cat("   - Fix the form or re-submit these evaluations with proper record_id\n")
  cat("   - Until fixed, these will show as 'Record_NA' in reports\n\n")
}

problematic_ids <- top_5_ids[!is.na(top_5_ids) & !top_5_ids %in% main_records$record_id[!is.na(main_records$name) & main_records$name != ""]]

if (length(problematic_ids) > 0) {
  cat("   Additional record IDs needing attention:", paste(problematic_ids, collapse = ", "), "\n")
  cat("   Action needed: Add 'name' values to these records in REDCap\n")
}

cat("\n=== END OF DIAGNOSTIC REPORT ===\n")
