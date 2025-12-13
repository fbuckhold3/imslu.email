# Ultra-detailed debugging of date filter issue
library(dplyr)
source("R/fetch_redcap_data.R")
source("R/utils.R")

cat("=== ULTRA-DETAILED DATE FILTER DEBUG ===\n\n")

res_data <- fetch_resident_data()
academic_year_start <- get_academic_year_start()

# Build initial filter
filter_condition <- !is.na(res_data$redcap_repeat_instrument) &
                    res_data$redcap_repeat_instrument == "Faculty Evaluation" &
                    !is.na(res_data$fac_eval_date) &
                    !is.na(res_data$record_id)
filter_condition[is.na(filter_condition)] <- FALSE
fac_evals <- res_data[filter_condition, , drop = FALSE]

cat("AFTER INITIAL FILTER:\n")
cat("  Rows:", nrow(fac_evals), "\n")
cat("  NA record_ids:", sum(is.na(fac_evals$record_id)), "\n")
cat("  Class of fac_eval_date:", class(fac_evals$fac_eval_date), "\n")
cat("  Sample fac_eval_date values (first 5):", head(fac_evals$fac_eval_date, 5), "\n")
cat("  NA fac_eval_dates:", sum(is.na(fac_evals$fac_eval_date)), "\n\n")

# Convert to Date
cat("CONVERTING TO DATE:\n")
if (!inherits(fac_evals$fac_eval_date, "Date")) {
  cat("  Before conversion - class:", class(fac_evals$fac_eval_date), "\n")
  cat("  Before conversion - NAs:", sum(is.na(fac_evals$fac_eval_date)), "\n")

  fac_evals$fac_eval_date <- as.Date(fac_evals$fac_eval_date)

  cat("  After conversion - class:", class(fac_evals$fac_eval_date), "\n")
  cat("  After conversion - NAs:", sum(is.na(fac_evals$fac_eval_date)), "\n")
  cat("  After conversion - NA record_ids:", sum(is.na(fac_evals$record_id)), "\n")
  cat("  After conversion - rows:", nrow(fac_evals), "\n\n")
}

# Build date filter
cat("BUILDING DATE FILTER:\n")
cat("  academic_year_start:", as.character(academic_year_start), "\n")
date_filter <- fac_evals$fac_eval_date >= academic_year_start
cat("  date_filter TRUE count:", sum(date_filter, na.rm = TRUE), "\n")
cat("  date_filter NA count:", sum(is.na(date_filter)), "\n")
cat("  date_filter FALSE count:", sum(!date_filter, na.rm = TRUE), "\n\n")

cat("CONVERTING NAs TO FALSE:\n")
date_filter[is.na(date_filter)] <- FALSE
cat("  After NA->FALSE, TRUE count:", sum(date_filter), "\n")
cat("  After NA->FALSE, NA count:", sum(is.na(date_filter)), "\n")
cat("  After NA->FALSE, FALSE count:", sum(!date_filter), "\n\n")

cat("BEFORE SUBSETTING:\n")
cat("  fac_evals rows:", nrow(fac_evals), "\n")
cat("  fac_evals NA record_ids:", sum(is.na(fac_evals$record_id)), "\n")
cat("  date_filter length:", length(date_filter), "\n")
cat("  Rows to keep (TRUE in filter):", sum(date_filter), "\n\n")

# Apply filter
fac_evals <- fac_evals[date_filter, , drop = FALSE]

cat("AFTER SUBSETTING:\n")
cat("  fac_evals rows:", nrow(fac_evals), "\n")
cat("  fac_evals NA record_ids:", sum(is.na(fac_evals$record_id)), "\n")
cat("  fac_evals NA fac_eval_dates:", sum(is.na(fac_evals$fac_eval_date)), "\n")
cat("  fac_evals NA instruments:", sum(is.na(fac_evals$redcap_repeat_instrument)), "\n\n")

# Check if there are actual rows with all NA
cat("CHECKING FOR ALL-NA ROWS:\n")
if (nrow(fac_evals) > 0) {
  all_na_rows <- apply(fac_evals, 1, function(row) all(is.na(row)))
  cat("  Rows with all NA:", sum(all_na_rows), "\n")

  if (sum(all_na_rows) > 0) {
    cat("  These are phantom rows created by subsetting!\n")
  }
}

# Sample some rows
cat("\nSAMPLE OF FIRST 10 ROWS:\n")
cols_to_show <- c("record_id", "redcap_repeat_instrument", "fac_eval_date")
existing_cols <- intersect(cols_to_show, names(fac_evals))
if (nrow(fac_evals) > 0) {
  print(head(fac_evals[, existing_cols, drop = FALSE], 10))
}

cat("\n=== CONCLUSION ===\n")
if (sum(is.na(fac_evals$record_id)) > 0) {
  cat("❌ Still have", sum(is.na(fac_evals$record_id)), "NA record_ids\n")
} else {
  cat("✅ No NA record_ids!\n")
}
