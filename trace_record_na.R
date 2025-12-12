# Trace exactly what's happening with Record_NA
library(dplyr)
source("R/fetch_redcap_data.R")
source("R/utils.R")

cat("=== TRACING RECORD_NA ISSUE ===\n\n")

res_data <- fetch_resident_data()
academic_year_start <- get_academic_year_start()

# Step 1: Check what we get after fetch
cat("STEP 1: After fetch_resident_data()\n")
fac_all <- res_data[!is.na(res_data$redcap_repeat_instrument) &
                     res_data$redcap_repeat_instrument == "Faculty Evaluation", ]
cat("  Total Faculty Evals:", nrow(fac_all), "\n")
cat("  Unique record_ids:", length(unique(fac_all$record_id)), "\n\n")

# Step 2: Apply the exact filters from the function (NEW logic)
cat("STEP 2: Apply filters from get_top_residents_fac_eval() [NEW LOGIC]\n")

# Build filter step by step - matching the NEW code
filter_condition <- !is.na(res_data$redcap_repeat_instrument) &
                    res_data$redcap_repeat_instrument == "Faculty Evaluation" &
                    !is.na(res_data$fac_eval_date) &
                    !is.na(res_data$record_id)

cat("  Filter before NA handling:", sum(filter_condition, na.rm = TRUE), "TRUE,", sum(is.na(filter_condition)), "NA\n")

# Ensure any NA values in filter become FALSE (explicit NA handling)
filter_condition[is.na(filter_condition)] <- FALSE

cat("  Filter after NA->FALSE:", sum(filter_condition), "TRUE,", sum(is.na(filter_condition)), "NA\n")

fac_evals <- res_data[filter_condition, , drop = FALSE]

cat("  After all filters:", nrow(fac_evals), "\n")

# Convert date
if (!inherits(fac_evals$fac_eval_date, "Date")) {
  fac_evals$fac_eval_date <- as.Date(fac_evals$fac_eval_date)
}

# Filter by date
fac_evals <- fac_evals[fac_evals$fac_eval_date >= academic_year_start, , drop = FALSE]
cat("  After date filter:", nrow(fac_evals), "\n\n")

# Step 3: Check for any problematic record_ids
cat("STEP 3: Check for problematic record_ids\n")
cat("  Record_ids that are is.na():", sum(is.na(fac_evals$record_id)), "\n")
cat("  Record_ids that are '':", sum(fac_evals$record_id == "", na.rm = TRUE), "\n")
cat("  Record_ids that are 'NA':", sum(fac_evals$record_id == "NA", na.rm = TRUE), "\n")
cat("  Record_ids with whitespace 'NA ':", sum(fac_evals$record_id == "NA ", na.rm = TRUE), "\n")
cat("  Record_ids with whitespace ' NA':", sum(fac_evals$record_id == " NA", na.rm = TRUE), "\n\n")

# Step 4: Group by record_id
cat("STEP 4: Group by record_id\n")
eval_counts <- fac_evals %>%
  group_by(record_id) %>%
  summarize(Count = n(), .groups = 'drop') %>%
  arrange(desc(Count))

cat("  Total groups:", nrow(eval_counts), "\n")
cat("  Top 10:\n")
for (i in 1:min(10, nrow(eval_counts))) {
  rid <- eval_counts$record_id[i]
  count <- eval_counts$Count[i]

  # Check what this record_id actually is
  rid_display <- if (is.na(rid)) {
    "<actual NA>"
  } else {
    sprintf("'%s' (nchar=%d, trimmed='%s')", rid, nchar(rid), trimmed <- trimws(rid))
  }

  cat("   ", i, ". ", rid_display, " - Count: ", count, "\n", sep = "")
}
cat("\n")

# Step 5: Get names and merge
cat("STEP 5: Get names and merge\n")
resident_names <- res_data[is.na(res_data$redcap_repeat_instrument) |
                             res_data$redcap_repeat_instrument == "",
                           c("record_id", "name"), drop = FALSE]
resident_names <- resident_names[!duplicated(resident_names$record_id), , drop = FALSE]

top_5 <- head(eval_counts, 5)
result <- merge(top_5, resident_names, by = "record_id", all.x = TRUE)

cat("  Before name replacement:\n")
for (i in 1:nrow(result)) {
  cat("    ", i, ". record_id='", result$record_id[i], "' name='", result$name[i], "' Count=", result$Count[i], "\n", sep = "")
}
cat("\n")

# Step 6: Apply name replacement
cat("STEP 6: Apply name replacement logic\n")
needs_replacement <- is.na(result$name) | result$name == ""
cat("  Rows needing replacement:", sum(needs_replacement), "\n")
if (any(needs_replacement)) {
  cat("  Details:\n")
  for (i in which(needs_replacement)) {
    old_name <- result$name[i]
    new_name <- paste0("Record_", result$record_id[i])
    cat("    Row", i, ": '", old_name, "' -> '", new_name, "'\n", sep = "")
  }
}

result$name[needs_replacement] <- paste0("Record_", result$record_id[needs_replacement])

cat("\n  Final result:\n")
for (i in 1:nrow(result)) {
  cat("    ", i, ". '", result$name[i], "' - Count: ", result$Count[i], "\n", sep = "")
}

cat("\n=== CONCLUSION ===\n")
if (any(result$name == "Record_NA")) {
  idx <- which(result$name == "Record_NA")[1]
  cat("❌ Found Record_NA at row", idx, "\n")
  cat("   This record_id value is: '", result$record_id[idx], "'\n", sep = "")
  cat("   nchar:", nchar(result$record_id[idx]), "\n")
  cat("   class:", class(result$record_id[idx]), "\n")
  cat("   Comparing to 'NA':", result$record_id[idx] == "NA", "\n")
} else {
  cat("✅ No Record_NA found!\n")
}
