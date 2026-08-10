if (!dir.exists("R") ||
    !file.exists(file.path("config", "goal003_candidate_pool.csv"))) {
  stop("Run this script from the flexiRich repository root.", call. = FALSE)
}

for (path in sort(list.files(
  "R",
  pattern = "\\.R$",
  full.names = TRUE
))) {
  source(path, local = FALSE)
}

output <- file.path("outputs", "goal003", "judbury_inputs.rds")
if (file.exists(output)) {
  stop("Goal003 Judbury input output already exists.", call. = FALSE)
}
dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
result <- build_goal003_judbury_data()
saveRDS(result, output, version = 3)
cat(
  "Goal003 Judbury inputs: PASS\n",
  "Output: ", normalizePath(output, mustWork = TRUE), "\n",
  "Candidate species: ", result$weekly$audit$n_candidate_species, "\n",
  "Detected species: ", result$weekly$audit$n_detected_species, "\n",
  "Primary-pool events: ", result$metadata$n_primary_pool_events, "\n",
  sep = ""
)
