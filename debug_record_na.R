# Debug script - trace where Record_NA is coming from

library(dplyr)
source("R/fetch_redcap_data.R")
source("R/utils.R")

cat("=== DETAILED TRACE ===\n\n")

# Fetch fresh data
cat("1. Fetching data...\n")
res_data <- fetch_resident_data()

# Check immediately after fetch
fac_evals_all <- res_data[!is.na(res_data$redcap_repeat_instrument) &
                           res_data$redcap_repeat_instrument == "Faculty Evaluation", ]
cat("   Faculty Evals after fetch:", nrow(fac_evals_all), "\n")
cat("   With NA record_id:", sum(is.na(fac_evals_all$record_id)), "\n\n")

# Now check what the function sees
cat("2. Inside get_top_residents_fac_eval filtering...\n")
academic_year_start <- get_academic_year_start()

# Replicate the function's filter
fac_evals_filtered <- res_data[res_data$redcap_repeat_instrument == "Faculty Evaluation" &
                                 !is.na(res_data$fac_eval_date) &
                                 !is.na(res_data$record_id), , drop = FALSE]

if (!inherits(fac_evals_filtered$fac_eval_date, "Date")) {
  fac_evals_filtered$fac_eval_date <- as.Date(fac_evals_filtered$fac_eval_date)
}

fac_evals_filtered <- fac_evals_filtered[fac_evals_filtered$fac_eval_date >= academic_year_start, , drop = FALSE]

cat("   After function filters:", nrow(fac_evals_filtered), "\n")
cat("   With NA record_id:", sum(is.na(fac_evals_filtered$record_id)), "\n\n")

# Check the grouping
cat("3. Grouping by record_id...\n")
eval_counts <- fac_evals_filtered %>%
  group_by(record_id) %>%
  summarize(Count = n(), .groups = 'drop') %>%
  arrange(desc(Count))

cat("   Top 10 groups:\n")
print(head(eval_counts, 10))

cat("\n4. Checking if any record_id is actually NA:\n")
na_group <- eval_counts[is.na(eval_counts$record_id), ]
if (nrow(na_group) > 0) {
  cat("   ❌ FOUND IT! NA group has", na_group$Count, "evaluations\n")
  cat("   This means the filters aren't working properly\n")
} else {
  cat("   ✓ No NA group found\n")
}

cat("\n5. Calling the actual function...\n")
result <- get_top_residents_fac_eval(res_data, academic_year_start, top_n = 10)
print(result)

cat("\n=== CONCLUSION ===\n")
if (any(grepl("Record_NA", result$Resident))) {
  cat("Record_NA is appearing. Checking record_id for that row...\n")
  # Need to add more debugging to the function itself
} else {
  cat("No Record_NA found!\n")
}
