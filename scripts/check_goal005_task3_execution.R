if (!dir.exists("R") || !file.exists("renv.lock")) {
  stop("Run this script from the flexiRich repository root.", call. = FALSE)
}

for (path in sort(list.files("R", pattern = "[.]R$", full.names = TRUE))) {
  source(path, local = FALSE)
}

manifest <- read_goal005_task3_manifest()
row <- manifest$datasets |>
  dplyr::filter(
    scenario_id == "aligned_mid",
    train_occasions == 12L,
    replicate == 1L
  )
simulation <- simulate_goal005_task3_dataset(row, manifest)
fit <- manifest$fits |>
  dplyr::filter(
    dataset_id == row$dataset_id,
    information_level == "F1.25"
  )
mapping <- goal004_task2_candidate_mapping()$core
prepared <- prepare_goal005_class_calibration_data(
  simulation$training_data,
  stats::setNames(mapping$encounter_class, mapping$candidate_id),
  c(
    routine = fit$routine_location_estimate,
    occasional = fit$occasional_location_estimate
  ),
  fit$calibration_sd
)
checks <- c(
  datasets = nrow(manifest$datasets) == 108L,
  calibrations = nrow(manifest$calibrations) == 84L,
  fits = nrow(manifest$fits) == 756L,
  fresh_seed = simulation$audit$simulation_seed == 660000001L,
  truth_isolated = !any(c("truth", "member", "true_richness") %in%
    names(prepared)),
  positive_calibration = prepared$calibration_sd > 0
)
if (!all(checks)) {
  stop("Goal005 Task 3 deterministic execution check failed.", call. = FALSE)
}
cat("Goal005 Task 3 deterministic execution contract: PASS\n")
print(checks)
