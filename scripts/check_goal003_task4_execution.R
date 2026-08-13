if (!dir.exists("R") || !file.exists("renv.lock")) {
  stop("Run this script from the flexiRich repository root.", call. = FALSE)
}

for (path in sort(list.files("R", pattern = "\\.R$", full.names = TRUE))) {
  source(path, local = FALSE)
}

manifest <- read_goal003_task4_manifests()
hand_rows <- manifest$datasets |>
  dplyr::filter(replicate == 1L)
for (index in seq_len(nrow(hand_rows))) {
  row <- hand_rows[index, ]
  simulation <- simulate_goal003_task4_dataset(row, manifest)
  validate_flexirich_g_data(simulation$training_data)
  baseline <- evaluate_goal003_task4_baselines(simulation)
  if (nrow(baseline$richness_scores) != 7L ||
      nrow(baseline$discovery_scores) != 2L ||
      any(c("truth", "member", "true_richness") %in%
        names(simulation$training_data))) {
    stop("A Task 4 execution hand case failed.", call. = FALSE)
  }
}

artifact_root <- tempfile("goal003-task4-hand-artifact-")
dir.create(artifact_root)
on.exit(unlink(artifact_root, recursive = TRUE), add = TRUE)
first_row <- hand_rows[1L, .goal003_task4_dataset_fields]
published <- publish_goal003_task4_artifact(
  artifact_root,
  first_row$dataset_id,
  function(staging) {
    .goal003_task4_write_dataset(first_row, manifest, staging)
  }
)
required_outputs <- c(
  "simulation.rds", "truth-species.csv", "dataset-status.csv",
  "baseline-point-predictions.csv", "baseline-richness-scores.csv",
  "baseline-discovery-scores.csv", "completion-status.txt"
)
if (any(!file.exists(file.path(published, required_outputs)))) {
  stop("The Task 4 dataset artifact hand case is incomplete.", call. = FALSE)
}

cat("Goal003 Task 4 execution hand cases: PASS\n")
cat("scenario_duration_cases=", nrow(hand_rows), "\n", sep = "")
cat("stan_fits_executed=0\n")
cat("empirical_outcomes_used=false\n")
