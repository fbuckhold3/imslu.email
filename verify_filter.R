# Quick verification: Are NA record_id Faculty Evaluations being filtered?

library(dplyr)
source("R/fetch_redcap_data.R")
source("R/utils.R")

cat("Fetching data with filters...\n\n")
res_data <- fetch_resident_data()

# Check Faculty Evaluations
fac_evals <- res_data[!is.na(res_data$redcap_repeat_instrument) &
                       res_data$redcap_repeat_instrument == "Faculty Evaluation", ]

cat("=== VERIFICATION RESULTS ===\n\n")
cat("Total Faculty Evaluation rows:", nrow(fac_evals), "\n")
cat("Faculty Evaluations with NA record_id:", sum(is.na(fac_evals$record_id)), "\n")

if (sum(is.na(fac_evals$record_id)) > 0) {
  cat("\n❌ FILTER NOT WORKING - NA record_ids still present\n")
  cat("   Action: Check if fetch_redcap_data.R was saved/sourced correctly\n")
} else {
  cat("\n✅ FILTER WORKING - No NA record_ids in Faculty Evaluations\n")
}

# Also check in the function
cat("\n=== CHECKING TOP RESIDENTS FUNCTION ===\n")
academic_year_start <- get_academic_year_start()
top_res <- get_top_residents_fac_eval(res_data, academic_year_start, top_n = 5)

cat("Top 5 residents:\n")
print(top_res)

if (any(grepl("Record_NA", top_res$Resident))) {
  cat("\n❌ Record_NA still appearing in results\n")
} else {
  cat("\n✅ No Record_NA in top residents\n")
}
