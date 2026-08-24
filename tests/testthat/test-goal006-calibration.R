.goal006_test_contract <- function() {
  read_goal006_task1_contract(verify_external = FALSE)
}

testthat::test_that("Goal006 quadrature matches direct selection integration", {
  quadrature <- goal006_gauss_hermite(64L)
  active_days <- c(310, 280, 260, 240)
  camera_effect <- c(-0.3, -0.1, 0.1, 0.3)
  cases <- tidyr::crossing(
    class_location = c(log(0.00025), log(0.001), log(0.004)),
    log_rate_sd = c(0.75, 1, 1.25)
  )
  error <- vapply(seq_len(nrow(cases)), function(index) {
    row <- cases[index, ]
    observed <- goal006_selection_log_probability(
      row$class_location,
      row$log_rate_sd,
      active_days,
      camera_effect,
      quadrature
    )
    reference <- goal006_selection_reference(
      row$class_location,
      row$log_rate_sd,
      active_days,
      camera_effect
    )$log_probability
    abs(observed - reference)
  }, numeric(1))
  testthat::expect_lt(max(error), 1e-8)
  testthat::expect_equal(sum(quadrature$weight), 1, tolerance = 1e-14)
  testthat::expect_true(all(quadrature$weight > 0))
})

testthat::test_that("Goal006 quadrature gradients match the analytic reference", {
  quadrature <- goal006_gauss_hermite(64L)
  active_days <- c(310, 280, 260, 240)
  camera_effect <- c(-0.3, -0.1, 0.1, 0.3)
  step <- 1e-5
  location <- log(0.0005)
  f <- function(shift) {
    goal006_selection_log_probability(
      location + shift,
      1,
      active_days,
      camera_effect,
      quadrature
    )
  }
  finite_difference <- (f(step) - f(-step)) / (2 * step)
  reference <- goal006_selection_reference(
    location,
    1,
    active_days,
    camera_effect
  )$gradient_class_location
  testthat::expect_lt(abs(finite_difference - reference), 1e-5)
})

testthat::test_that("Goal006 synthetic calibration is deterministic and outcome-free", {
  contract <- .goal006_test_contract()
  row <- contract$synthetic[1, ]
  first <- simulate_goal006_calibration_dataset(row, contract)
  second <- simulate_goal006_calibration_dataset(row, contract)

  testthat::expect_identical(first, second)
  testthat::expect_false(first$audit$empirical_outcomes_used)
  testthat::expect_equal(nrow(first$truth$species), 50L)
  testthat::expect_true(all(first$truth$species$calibration_detected %in%
    c(TRUE, FALSE)))
  testthat::expect_equal(sum(first$truth$cameras$camera_effect), 0, tolerance = 1e-14)
  testthat::expect_identical(
    first$source_data$stan_data$detected_ever,
    as.integer(first$truth$species$calibration_detected[
      match(
        first$source_data$candidate_ids,
        first$truth$species$species_id
      )
    ])
  )
})

testthat::test_that("Goal006 calibration uses only detected species", {
  contract <- .goal006_test_contract()
  simulation <- simulate_goal006_calibration_dataset(
    contract$synthetic[11, ],
    contract
  )
  data <- prepare_goal006_calibration_data(
    simulation$source_data,
    simulation$encounter_class,
    contract$calibration_fits[1, ]
  )
  expected <- simulation$source_data$candidate_ids[
    simulation$source_data$stan_data$detected_ever == 1L
  ]

  testthat::expect_identical(data$detected_species_ids, expected)
  testthat::expect_identical(data$stan_data$D, as.integer(length(expected)))
  testthat::expect_equal(sum(data$class_counts), length(expected))
  testthat::expect_false(any(
    simulation$source_data$candidate_ids[
      simulation$source_data$stan_data$detected_ever == 0L
    ] %in% data$detected_species_ids
  ))
  testthat::expect_false(any(c(
    "member", "omega", "q_member", "detected_ever"
  ) %in% names(data$stan_data)))
})

testthat::test_that("Goal006 exclusions rebuild the calibration sample", {
  contract <- .goal006_test_contract()
  simulation <- simulate_goal006_calibration_dataset(
    contract$synthetic[1, ],
    contract
  )
  primary <- prepare_goal006_calibration_data(
    simulation$source_data,
    simulation$encounter_class,
    contract$calibration_fits[1, ]
  )
  loso <- prepare_goal006_calibration_data(
    simulation$source_data,
    simulation$encounter_class,
    contract$calibration_fits[5, ]
  )
  quarter <- prepare_goal006_calibration_data(
    simulation$source_data,
    simulation$encounter_class,
    contract$calibration_fits[14, ]
  )

  testthat::expect_equal(loso$stan_data$J, primary$stan_data$J - 1L)
  testthat::expect_false(
    contract$calibration_fits$excluded_camera_id[[5L]] %in% loso$camera_ids
  )
  testthat::expect_equal(length(quarter$source_data$occasion_ids), 39L)
  testthat::expect_lt(
    sum(quarter$stan_data$total_active_days),
    sum(primary$stan_data$total_active_days)
  )
})

testthat::test_that("Goal006 artifact schema rejects identity leakage", {
  schema <- goal006_output_schema()$calibration_artifact
  artifact <- stats::setNames(vector("list", length(schema)), schema)
  artifact$artifact_version <- "goal006-calibration-artifact-v1"
  artifact$model_id <- goal006_model_contract()$calibration_model_id
  artifact$calibration_start_index <- 1L
  artifact$calibration_end_index <- 52L
  artifact$class_order <- c("routine", "occasional")
  artifact$location_mean <- c(routine = -6, occasional = -8)
  artifact$location_covariance <- diag(2)
  artifact$class_prior <- list(mean = c(-6, -8), sd = 1.5)
  artifact$log_rate_sd <- 1
  artifact$source_receipts <- tibble::tibble(source = "synthetic")
  artifact$fit_seed <- 1L
  artifact$diagnostics <- list(clean = TRUE)
  artifact$approximation_checks <- list(max_quantile_error = 0)

  testthat::expect_silent(validate_goal006_calibration_artifact(artifact))
  artifact$source_receipts$candidate_id <- "leaked-name"
  testthat::expect_error(
    validate_goal006_calibration_artifact(artifact),
    "violates its boundary",
    fixed = TRUE
  )
})

testthat::test_that("Goal006 Stan source contains the selection adjustment", {
  root <- if (dir.exists("R")) "." else file.path("..", "..")
  text <- paste(readLines(
    file.path(root, "stan", "goal006_selection_calibration.stan"),
    warn = FALSE
  ), collapse = "\n")
  testthat::expect_match(text, "selection_log_probability", fixed = TRUE)
  testthat::expect_match(
    text,
    "history_log_likelihood[i] -",
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
