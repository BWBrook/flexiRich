if (!dir.exists("R") || !file.exists("renv.lock")) {
  stop("Run this script from the flexiRich repository root.", call. = FALSE)
}

for (path in sort(list.files("R", pattern = "[.]R$", full.names = TRUE))) {
  source(path, local = FALSE)
}

manifest <- read_goal004_task4_manifests()
prior <- goal004_task4_prior_forecasts(n_draws = 200L, manifest = manifest)
hand_rows <- manifest$datasets |>
  dplyr::filter(replicate == 1L)
for (index in seq_len(nrow(hand_rows))) {
  row <- hand_rows[index, ]
  simulation <- simulate_goal004_task4_dataset(row, manifest)
  validate_flexirich_g_data(simulation$training_data)
  baseline <- evaluate_goal003_task4_baselines(simulation)
  prior_score <- score_goal004_task4_prior(
    row,
    simulation$truth,
    prior,
    profile_id = "primary"
  )
  if (nrow(baseline$richness_scores) != 7L ||
      nrow(baseline$discovery_scores) != 2L ||
      nrow(prior_score$membership) != 1L ||
      any(c("truth", "member", "true_richness") %in%
        names(simulation$training_data))) {
    stop("A Goal004 Task 4 execution hand case failed.", call. = FALSE)
  }
}

artifact_root <- tempfile("goal004-task4-hand-artifact-")
dir.create(artifact_root)
on.exit(unlink(artifact_root, recursive = TRUE), add = TRUE)
first_row <- hand_rows[1L, .goal004_task4_dataset_fields]
published <- publish_goal003_task4_artifact(
  artifact_root,
  first_row$dataset_id,
  function(staging) {
    .goal004_task4_write_dataset(first_row, manifest, prior, staging)
  }
)
required <- c(
  "simulation.rds", "truth-species.csv", "dataset-status.csv",
  "baseline-richness-scores.csv", "prior-richness-scores.csv",
  "prior-membership-scores.csv", "completion-status.txt"
)
if (any(!file.exists(file.path(published, required)))) {
  stop("The Goal004 Task 4 hand artifact is incomplete.", call. = FALSE)
}

cat("Goal004 Task 4 execution hand cases: PASS\n")
cat("scenario_duration_cases=", nrow(hand_rows), "\n", sep = "")
cat("stan_fits_executed=0\n")
cat("empirical_outcomes_used=false\n")
