.goal007_test_simulation <- function(index = 1L) {
  contract <- read_goal007_task1_contract(verify_external = FALSE)
  simulation <- simulate_goal007_task2_dataset(
    contract$task2_datasets[index, ],
    contract
  )
  list(contract = contract, simulation = simulation)
}

testthat::test_that("Goal007 shared prior transformation is exact", {
  metrics <- goal007_prior_bridge_metrics()
  testthat::expect_true(metrics$passed)
  testthat::expect_lte(metrics$maximum_transform_error, 1e-12)
  testthat::expect_lte(metrics$maximum_covariance_error, 1e-12)

  locations <- goal007_class_locations(log(0.75), log(2))
  testthat::expect_equal(locations[["routine"]], log(0.0015), tolerance = 1e-14)
  testthat::expect_equal(locations[["occasional"]], log(0.00075), tolerance = 1e-14)
  testthat::expect_error(
    goal007_class_locations(c(0, 1), 0),
    "Invalid Goal007 shared-shift"
  )
})

testthat::test_that("Goal007 Task 2 simulation is fresh and deterministic", {
  fixture <- .goal007_test_simulation()
  row <- fixture$contract$task2_datasets[1, ]
  repeated <- simulate_goal007_task2_dataset(row, fixture$contract)

  testthat::expect_identical(fixture$simulation, repeated)
  testthat::expect_identical(fixture$simulation$simulation_id, row$dataset_id)
  testthat::expect_false(fixture$simulation$audit$empirical_outcomes_used)
  testthat::expect_identical(
    fixture$simulation$audit$goal007_profile_id,
    row$profile_id
  )
  testthat::expect_equal(nrow(fixture$simulation$truth$species), 50L)
  testthat::expect_equal(
    fixture$simulation$audit$simulation_seed,
    row$simulation_seed
  )
})

testthat::test_that("Goal007 adapter reuses detected histories but excludes truth", {
  fixture <- .goal007_test_simulation(2L)
  simulation <- fixture$simulation
  data <- prepare_goal007_calibration_data(
    simulation$source_data,
    simulation$encounter_class,
    "shared_F5"
  )

  testthat::expect_identical(
    data$base_data$detected_species_ids,
    simulation$source_data$candidate_ids[
      simulation$source_data$stan_data$detected_ever == 1L
    ]
  )
  testthat::expect_identical(data$model_spec$model_id, "shared_F5")
  testthat::expect_equal(
    data$stan_data$contrast_sd,
    goal007_contrast_sd(5),
    tolerance = 1e-14
  )
  testthat::expect_false(any(c(
    "class_prior_mean", "class_prior_sd", "truth", "member", "omega",
    "q_member", "detected_ever"
  ) %in% names(data$stan_data)))
  testthat::expect_error(
    prepare_goal007_calibration_data(
      simulation$source_data,
      simulation$encounter_class,
      "independent"
    ),
    "shared_F5 or shared_F3"
  )
})

testthat::test_that("Goal007 R likelihood is the Goal006 likelihood after transformation", {
  fixture <- .goal007_test_simulation(3L)
  data <- prepare_goal007_calibration_data(
    fixture$simulation$source_data,
    fixture$simulation$encounter_class,
    "shared_F3"
  )
  common_shift <- -0.2
  contrast_deviation <- 0.3
  locations <- goal007_class_locations(common_shift, contrast_deviation)
  alpha <- unname(locations[data$base_data$encounter_class])
  camera_effect <- rep(0, data$stan_data$J)

  goal007 <- goal007_calibration_likelihood_terms(
    data,
    common_shift,
    contrast_deviation,
    alpha,
    camera_effect
  )
  goal006 <- goal006_calibration_likelihood_terms(
    data$base_data,
    unname(locations),
    alpha,
    camera_effect
  )
  testthat::expect_equal(goal007$class_location, locations)
  testthat::expect_equal(
    goal007$history_log_likelihood,
    goal006$history_log_likelihood,
    tolerance = 1e-14
  )
  testthat::expect_equal(
    goal007$log_selection_probability,
    goal006$log_selection_probability,
    tolerance = 1e-14
  )
  testthat::expect_equal(
    goal007$selection_adjusted_log_likelihood,
    goal006$selection_adjusted_log_likelihood,
    tolerance = 1e-14
  )
})

testthat::test_that("Goal007 artifact validator rejects identity leakage", {
  schema <- goal007_output_schema()$calibration_artifact
  artifact <- stats::setNames(vector("list", length(schema)), schema)
  artifact$artifact_version <- "goal007-calibration-artifact-v1"
  artifact$model_id <- "shared_F5"
  artifact$class_order <- c("routine", "occasional")
  artifact$location_mean <- c(routine = -6, occasional = -8)
  artifact$location_covariance <- diag(2)
  artifact$prior_metadata <- list(
    base_location = c(routine = -6, occasional = -8),
    common_shift_sd = 1.5,
    contrast_factor = 5,
    contrast_sd = goal007_contrast_sd(5)
  )
  artifact$fit_seed <- 1L
  artifact$source_hashes <- tibble::tibble(source = "synthetic", sha256 = "x")
  artifact$diagnostics <- list(clean = TRUE)
  artifact$approximation_checks <- list(max_quantile_error = 0)

  testthat::expect_silent(validate_goal007_calibration_artifact(artifact))
  artifact$source_hashes$species_id <- "leaked"
  testthat::expect_error(
    validate_goal007_calibration_artifact(artifact),
    "violates its boundary"
  )
})

testthat::test_that("Goal007 Stan source retains selection adjustment and shared priors", {
  root <- if (dir.exists("R")) "." else file.path("..", "..")
  text <- paste(readLines(
    file.path(root, "stan", "goal007_shared_shift_calibration.stan"),
    warn = FALSE
  ), collapse = "\n")

  testthat::expect_match(text, "common_shift ~ normal", fixed = TRUE)
  testthat::expect_match(text, "contrast_deviation ~ normal", fixed = TRUE)
  testthat::expect_match(
    text,
    "class_location[2] = base_location[2] + common_shift + contrast_deviation",
    fixed = TRUE
  )
  testthat::expect_match(
    text,
    "log_selection_probability[class_index[i]]",
    fixed = TRUE
  )
  testthat::expect_false(grepl("omega", text, fixed = TRUE))
  testthat::expect_false(grepl("q_member", text, fixed = TRUE))
})
