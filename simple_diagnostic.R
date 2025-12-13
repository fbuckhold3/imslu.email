# Ultra-simple diagnostic - just show the data
library(dplyr)
source("R/fetch_redcap_data.R")
source("R/utils.R")

cat("=== SIMPLE DATA INSPECTION ===\n\n")

# Get data
res_data <- fetch_resident_data()
academic_year_start <- get_academic_year_start()

cat("1. FACULTY EVALS IN RES_DATA:\n")
fac_in_res <- res_data[!is.na(res_data$redcap_repeat_instrument) &
                        res_data$redcap_repeat_instrument == "Faculty Evaluation", ]
cat("   Total:", nrow(fac_in_res), "\n")
cat("   With NA record_id:", sum(is.na(fac_in_res$record_id)), "\n")
cat("   Sample of record_ids (first 10 unique):\n")
print(head(unique(fac_in_res$record_id), 10))
cat("\n")

cat("2. CALL THE FUNCTION:\n")
result <- get_top_residents_fac_eval(res_data, academic_year_start, top_n = 10)
cat("   Top 10 residents:\n")
print(result)
cat("\n")

cat("3. MANUAL FILTER (copy of function code):\n")
filter_condition <- !is.na(res_data$redcap_repeat_instrument) &
                    res_data$redcap_repeat_instrument == "Faculty Evaluation" &
                    !is.na(res_data$fac_eval_date) &
                    !is.na(res_data$record_id)
filter_condition[is.na(filter_condition)] <- FALSE
fac_evals <- res_data[filter_condition, , drop = FALSE]

cat("   Rows after filter:", nrow(fac_evals), "\n")
cat("   NA record_ids:", sum(is.na(fac_evals$record_id)), "\n")

# Convert date and filter by date with explicit NA handling
if (!inherits(fac_evals$fac_eval_date, "Date")) {
  fac_evals$fac_eval_date <- as.Date(fac_evals$fac_eval_date)
}

# Filter by date with explicit NA handling
date_filter <- fac_evals$fac_eval_date >= academic_year_start
date_filter[is.na(date_filter)] <- FALSE
fac_evals <- fac_evals[date_filter, , drop = FALSE]

cat("   After date filter:", nrow(fac_evals), "\n")
cat("   NA record_ids after date:", sum(is.na(fac_evals$record_id)), "\n")

# Group
eval_counts <- fac_evals %>%
  group_by(record_id) %>%
  summarize(Count = n(), .groups = 'drop') %>%
  arrange(desc(Count))

cat("   After grouping - top 10:\n")
print(head(eval_counts, 10))
cat("\n")

cat("4. CHECK FOR ISSUES:\n")
if (any(is.na(eval_counts$record_id))) {
  cat("   ❌ Found NA in grouped record_ids!\n")
  cat("   This should be IMPOSSIBLE after the filter!\n")
  cat("   Checking original fac_evals data frame...\n\n")

  # Get rows with NA record_id
  na_rows <- fac_evals[is.na(fac_evals$record_id), ]
  cat("   Number of rows with NA record_id in fac_evals:", nrow(na_rows), "\n")

  if (nrow(na_rows) > 0) {
    cat("   Sample of NA rows (first 3):\n")
    cols_to_show <- c("record_id", "redcap_repeat_instrument", "fac_eval_date",
                      "redcap_repeat_instance")
    existing_cols <- intersect(cols_to_show, names(na_rows))
    print(head(na_rows[, existing_cols, drop = FALSE], 3))
  }
} else {
  cat("   ✅ No NAs found in grouped data\n")
}
