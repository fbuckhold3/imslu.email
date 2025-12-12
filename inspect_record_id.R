# Deep inspection of record_id to find why Record_NA persists
library(dplyr)
source("R/fetch_redcap_data.R")
source("R/utils.R")

cat("=== DEEP RECORD_ID INSPECTION ===\n\n")

# Fetch data
res_data <- fetch_resident_data()
academic_year_start <- get_academic_year_start()

# 1. Check the type and class of record_id
cat("1. RECORD_ID DATA TYPE:\n")
cat("   Class:", class(res_data$record_id), "\n")
cat("   Type:", typeof(res_data$record_id), "\n\n")

# 2. Check for string "NA" vs actual NA
fac_evals_all <- res_data[!is.na(res_data$redcap_repeat_instrument) &
                           res_data$redcap_repeat_instrument == "Faculty Evaluation", ]

cat("2. FACULTY EVALUATION RECORD_IDS:\n")
cat("   Total faculty evals:", nrow(fac_evals_all), "\n")
cat("   With actual NA (is.na):", sum(is.na(fac_evals_all$record_id)), "\n")
cat("   With string 'NA':", sum(!is.na(fac_evals_all$record_id) & fac_evals_all$record_id == "NA", na.rm = TRUE), "\n")
cat("   With empty string:", sum(!is.na(fac_evals_all$record_id) & fac_evals_all$record_id == "", na.rm = TRUE), "\n\n")

# 3. Show unique record_id values (first 20)
unique_ids <- unique(fac_evals_all$record_id)
cat("3. FIRST 20 UNIQUE RECORD_IDS:\n")
for (i in 1:min(20, length(unique_ids))) {
  id <- unique_ids[i]
  if (is.na(id)) {
    cat("   [", i, "] <NA> (actual NA value)\n", sep = "")
  } else if (id == "") {
    cat("   [", i, "] '' (empty string)\n", sep = "")
  } else if (id == "NA") {
    cat("   [", i, "] 'NA' (string NA)\n", sep = "")
  } else {
    cat("   [", i, "] '", id, "'\n", sep = "")
  }
}
cat("\n")

# 4. Apply the exact same filter as the function
cat("4. APPLYING FUNCTION FILTERS:\n")
fac_evals_filtered <- res_data[!is.na(res_data$redcap_repeat_instrument) &
                                res_data$redcap_repeat_instrument == "Faculty Evaluation" &
                                !is.na(res_data$fac_eval_date) &
                                !is.na(res_data$record_id), , drop = FALSE]

if (!inherits(fac_evals_filtered$fac_eval_date, "Date")) {
  fac_evals_filtered$fac_eval_date <- as.Date(fac_evals_filtered$fac_eval_date)
}

fac_evals_filtered <- fac_evals_filtered[fac_evals_filtered$fac_eval_date >= academic_year_start, , drop = FALSE]

cat("   After all filters:", nrow(fac_evals_filtered), "rows\n")
cat("   Actual NAs remaining:", sum(is.na(fac_evals_filtered$record_id)), "\n")
cat("   String 'NA' remaining:", sum(!is.na(fac_evals_filtered$record_id) & fac_evals_filtered$record_id == "NA", na.rm = TRUE), "\n\n")

# 5. Group and see what happens
cat("5. GROUPING BY RECORD_ID:\n")
eval_counts <- fac_evals_filtered %>%
  group_by(record_id) %>%
  summarize(Count = n(), .groups = 'drop') %>%
  arrange(desc(Count))

cat("   Total groups:", nrow(eval_counts), "\n")
cat("   Top 10 groups:\n")
for (i in 1:min(10, nrow(eval_counts))) {
  rid <- eval_counts$record_id[i]
  count <- eval_counts$Count[i]

  if (is.na(rid)) {
    cat("   ", i, ". <NA> (actual NA) - Count:", count, "\n")
  } else if (rid == "") {
    cat("   ", i, ". '' (empty) - Count:", count, "\n")
  } else if (rid == "NA") {
    cat("   ", i, ". 'NA' (string) - Count:", count, "\n")
  } else {
    cat("   ", i, ". '", rid, "' - Count:", count, "\n", sep = "")
  }
}
cat("\n")

# 6. Get names and see final result
cat("6. MERGING WITH NAMES:\n")
resident_names <- res_data[is.na(res_data$redcap_repeat_instrument) |
                             res_data$redcap_repeat_instrument == "",
                           c("record_id", "name"), drop = FALSE]
resident_names <- resident_names[!duplicated(resident_names$record_id), , drop = FALSE]

top_5 <- head(eval_counts, 5)
result <- merge(top_5, resident_names, by = "record_id", all.x = TRUE)

cat("   Before name replacement:\n")
print(result[, c("record_id", "name", "Count")])
cat("\n")

# Apply the name replacement logic
result$name[is.na(result$name) | result$name == ""] <- paste0("Record_", result$record_id[is.na(result$name) | result$name == ""])

cat("   After name replacement:\n")
print(result[, c("record_id", "name", "Count")])
cat("\n")

cat("=== CONCLUSION ===\n")
if (any(result$name == "Record_NA", na.rm = TRUE)) {
  cat("❌ Found 'Record_NA' - this means record_id is string 'NA'\n")
  cat("   Need to add filter for string 'NA' values\n")
} else if (any(grepl("^Record_", result$name) & is.na(result$record_id))) {
  cat("❌ Found Record_<NA> - record_id is actual NA that got through filters\n")
  cat("   The !is.na() filter is not working as expected\n")
} else {
  cat("✅ No Record_NA found in inspection\n")
}
