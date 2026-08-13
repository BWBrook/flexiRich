.goal003_task4_scoring_fixture <- function() {
  manifest <- read_goal003_task4_manifests()
  row <- manifest$datasets |>
    dplyr::filter(
      scenario_id == "matched_mid",
      train_occasions == 4L,
      replicate == 1L
    )
  simulate_goal003_task4_dataset(row, manifest)
}

testthat::test_that("Task 4 scores exact richness and discovery predictions", {
  simulation <- .goal003_task4_scoring_fixture()
  truth <- simulation$truth
  C <- nrow(truth$species)
  unseen <- !truth$species$training_detected
  n_unseen <- sum(unseen)

  richness_probability <- numeric(C + 1L)
  richness_probability[[truth$true_richness + 1L]] <- 1
  discovery_probability <- numeric(n_unseen + 1L)
  discovery_probability[[truth$true_new_species + 1L]] <- 1
  identity <- tibble::tibble(
    species_id = truth$species$species_id,
    training_detected = truth$species$training_detected,
    future_first_detection_probability = as.numeric(
      truth$species$future_first_detection
    )
  )
  score <- score_goal003_task4_prediction(
    dataset_id = simulation$dataset_id,
    fit_id = "hand-fit",
    method = "flexirich",
    run_role = "primary",
    terminal_clean = TRUE,
    truth = truth,
    richness_pmf = tibble::tibble(
      richness = seq.int(0L, C),
      probability = richness_probability
    ),
    new_species_count_pmf = tibble::tibble(
      new_species_count = seq.int(0L, n_unseen),
      probability = discovery_probability
    ),
    future_identity = identity
  )

  testthat::expect_identical(
    names(score),
    c("richness", "discovery")
  )
  testthat::expect_true(score$richness$prediction_available)
  testthat::expect_equal(score$richness$point_estimate, truth$true_richness)
  testthat::expect_equal(score$richness$absolute_error, 0)
  testthat::expect_equal(score$richness$rps, 0)
  testthat::expect_equal(score$richness$log_score, 0)
  testthat::expect_true(score$richness$interval_90_covered)
  testthat::expect_equal(score$discovery$absolute_error, 0)
  testthat::expect_equal(score$discovery$count_rps, 0)
  testthat::expect_equal(score$discovery$identity_brier, 0)
  testthat::expect_equal(score$discovery$n_unseen_candidates, n_unseen)
})

testthat::test_that("Task 4 scoring preserves zero mass and non-clean fits", {
  simulation <- .goal003_task4_scoring_fixture()
  truth <- simulation$truth
  C <- nrow(truth$species)
  wrong <- numeric(C + 1L)
  wrong[[1L]] <- 1
  scored <- score_goal003_task4_prediction(
    dataset_id = simulation$dataset_id,
    fit_id = "wrong-fit",
    method = "flexirich",
    run_role = "primary",
    terminal_clean = TRUE,
    truth = truth,
    richness_pmf = tibble::tibble(
      richness = seq.int(0L, C),
      probability = wrong
    )
  )
  testthat::expect_equal(scored$richness$point_estimate, 0)
  testthat::expect_true(is.infinite(scored$richness$log_score))

  nonclean <- score_goal003_task4_prediction(
    dataset_id = simulation$dataset_id,
    fit_id = "nonclean-fit",
    method = "flexirich",
    run_role = "primary",
    terminal_clean = FALSE,
    truth = truth
  )
  testthat::expect_false(nonclean$richness$prediction_available)
  testthat::expect_false(nonclean$richness$interval_90_covered)
  testthat::expect_true(is.na(nonclean$richness$point_estimate))
  testthat::expect_false(nonclean$discovery$prediction_available)
})

testthat::test_that("Task 4 deterministic baselines obey method eligibility", {
  simulation <- .goal003_task4_scoring_fixture()
  baseline <- evaluate_goal003_task4_baselines(simulation)

  testthat::expect_identical(
    names(baseline),
    c("point_predictions", "richness_scores", "discovery_scores")
  )
  testthat::expect_setequal(
    baseline$point_predictions$method,
    c(
      "observed", "chao2", "ichao2", "chao2_complete",
      "ichao2_complete", "inext"
    )
  )
  testthat::expect_setequal(
    baseline$richness_scores$method,
    c(
      "observed", "chao2", "ichao2", "chao2_complete",
      "ichao2_complete", "inext", "lower_prior"
    )
  )
  testthat::expect_setequal(
    baseline$discovery_scores$method,
    c("observed", "inext")
  )
  observed <- baseline$richness_scores |>
    dplyr::filter(method == "observed")
  testthat::expect_equal(
    observed$point_estimate,
    simulation$truth$observed_richness
  )
  testthat::expect_true(observed$prediction_available)
})

.goal003_task4_passing_gate_inputs <- function() {
  manifest <- read_goal003_task4_manifests()
  dataset_truth <- manifest$datasets |>
    dplyr::select(
      dataset_id,
      scenario_id,
      scenario_class,
      train_occasions,
      true_richness
    )
  fit_status <- manifest$fits |>
    dplyr::mutate(
      terminal_status = "primary_clean",
      terminal_clean = TRUE,
      elapsed_seconds = dplyr::if_else(method == "occupancy", 50, 100)
    )
  fit_scores <- manifest$fits |>
    dplyr::left_join(dataset_truth, by = "dataset_id") |>
    dplyr::mutate(
      terminal_clean = TRUE,
      prediction_available = TRUE,
      point_estimate = true_richness + dplyr::if_else(
        run_role == "primary",
        0,
        0.5
      ),
      absolute_error = abs(point_estimate - true_richness),
      rps = dplyr::case_when(
        method == "occupancy" ~ 0.39,
        run_role == "primary" ~ 0.4,
        .default = 0.41
      ),
      log_score = 1,
      interval_90_lower = true_richness - 1L,
      interval_90_upper = true_richness + 1L,
      interval_90_covered = TRUE,
      interval_90_width = 2
    ) |>
    dplyr::select(
      dataset_id,
      fit_id,
      method,
      run_role,
      prior_profile,
      pool_profile,
      terminal_clean,
      prediction_available,
      true_richness,
      point_estimate,
      absolute_error,
      rps,
      log_score,
      interval_90_lower,
      interval_90_upper,
      interval_90_covered,
      interval_90_width
    )
  calibration_ids <- manifest$datasets$dataset_id[
    manifest$datasets$scenario_class == "matched" &
      manifest$datasets$replicate <= 3L
  ]
  fit_scores$interval_90_covered[
    fit_scores$method == "flexirich" &
      fit_scores$run_role == "primary" &
      fit_scores$dataset_id %in% calibration_ids
  ] <- FALSE
  baseline_scores <- tidyr::crossing(
    dataset_id = dataset_truth$dataset_id,
    method = c("observed", "lower_prior")
  ) |>
    dplyr::left_join(dataset_truth, by = "dataset_id") |>
    dplyr::mutate(
      fit_id = NA_character_,
      run_role = "baseline",
      prior_profile = NA_character_,
      pool_profile = "primary_50",
      terminal_clean = TRUE,
      prediction_available = TRUE,
      point_estimate = true_richness - 1,
      absolute_error = 1,
      rps = dplyr::if_else(method == "observed", 0.5, 0.6),
      log_score = 1,
      interval_90_lower = true_richness - 2L,
      interval_90_upper = true_richness + 2L,
      interval_90_covered = TRUE,
      interval_90_width = 4
    ) |>
    dplyr::select(dplyr::all_of(names(fit_scores)))
  list(
    manifest = manifest,
    fit_status = fit_status,
    richness_scores = dplyr::bind_rows(baseline_scores, fit_scores)
  )
}

testthat::test_that("Task 4 gate evaluator applies all frozen thresholds", {
  input <- .goal003_task4_passing_gate_inputs()
  result <- evaluate_goal003_task4_gates(
    input$manifest,
    input$fit_status,
    input$richness_scores
  )
  testthat::expect_identical(
    names(result),
    c("gates", "cell_summary", "sensitivity_pairs")
  )
  testthat::expect_true(all(result$gates$passed))
  testthat::expect_equal(nrow(result$sensitivity_pairs), 240L)

  broken <- input$richness_scores
  affected <- broken$method == "flexirich" &
    broken$run_role == "primary" &
    broken$dataset_id %in% input$manifest$datasets$dataset_id[
      input$manifest$datasets$scenario_id == "seasonal_availability" &
        input$manifest$datasets$train_occasions == 4L &
        input$manifest$datasets$replicate <= 8L
    ]
  broken$interval_90_covered[affected] <- FALSE
  failed <- evaluate_goal003_task4_gates(
    input$manifest,
    input$fit_status,
    broken
  )
  testthat::expect_false(all(failed$gates$passed))
  testthat::expect_false(failed$gates$passed[
    failed$gates$gate_id ==
      "misspecified_coverage-seasonal_availability-04w"
  ])
})
