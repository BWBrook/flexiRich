.goal004_task4_passing_gate_inputs <- function() {
  manifest <- read_goal004_task4_manifests()
  context <- manifest$datasets |>
    dplyr::select(
      dataset_id,
      fidelity,
      true_richness,
      train_occasions,
      replicate
    )
  fit_status <- manifest$fits |>
    dplyr::left_join(context, by = "dataset_id") |>
    dplyr::mutate(
      terminal_clean = TRUE,
      elapsed_seconds = dplyr::if_else(method == "occupancy", 50, 100)
    )
  fit_richness <- fit_status |>
    dplyr::mutate(
      prediction_available = TRUE,
      point_estimate = true_richness + dplyr::case_when(
        run_role == "prior_sensitivity" ~ 0.5,
        run_role == "pool_sensitivity" ~ 0.1,
        .default = 0
      ),
      absolute_error = abs(point_estimate - true_richness),
      rps = dplyr::case_when(
        method == "goal003" & train_occasions == 4L ~ 0.50,
        method == "occupancy" & train_occasions == 4L ~ 0.39,
        train_occasions == 4L ~ 0.40,
        .default = 0.20
      ),
      log_score = 1,
      interval_90_lower = true_richness - 5L,
      interval_90_upper = true_richness + 5L,
      interval_90_covered = TRUE,
      interval_90_width = 10
    ) |>
    dplyr::select(
      dataset_id,
      fit_id,
      method,
      run_role,
      prior_profile,
      pool_profile,
      candidate_pool_size,
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
  sensitivity_prior <- manifest$fits |>
    dplyr::filter(run_role == "prior_sensitivity") |>
    dplyr::distinct(dataset_id, prior_profile) |>
    dplyr::left_join(context, by = "dataset_id")
  prior_keys <- dplyr::bind_rows(
    context |>
      dplyr::mutate(prior_profile = "primary"),
    sensitivity_prior
  ) |>
    dplyr::distinct(dataset_id, prior_profile, .keep_all = TRUE)
  prior_richness <- prior_keys |>
    dplyr::transmute(
      dataset_id,
      fit_id = NA_character_,
      method = "goal004_prior",
      run_role = "prior_only",
      prior_profile,
      pool_profile = "core_50",
      candidate_pool_size = 50L,
      terminal_clean = TRUE,
      prediction_available = TRUE,
      true_richness,
      point_estimate = 25,
      absolute_error = abs(25 - true_richness),
      rps = dplyr::if_else(train_occasions == 4L, 0.60, 0.40),
      log_score = 1,
      interval_90_lower = 3L,
      interval_90_upper = 47L,
      interval_90_covered = TRUE,
      interval_90_width = 44
    )
  richness <- dplyr::bind_rows(fit_richness, prior_richness)

  fit_discovery <- fit_status |>
    dplyr::transmute(
      dataset_id,
      fit_id,
      method,
      run_role,
      prior_profile,
      terminal_clean,
      count_rps = dplyr::case_when(
        method == "goal004" & run_role == "primary" &
          fidelity == "aligned" & train_occasions == 4L ~ 0.40,
        method == "goal004" & run_role == "primary" &
          fidelity == "aligned" & train_occasions == 26L ~ 0.30,
        .default = 0.50
      ),
      identity_brier = dplyr::if_else(
        method == "goal004" & run_role == "primary" & fidelity == "aligned",
        0.20,
        0.25
      )
    )
  prior_discovery <- prior_keys |>
    dplyr::transmute(
      dataset_id,
      fit_id = NA_character_,
      method = "goal004_prior",
      run_role = "prior_only",
      prior_profile,
      terminal_clean = TRUE,
      count_rps = 0.50,
      identity_brier = 0.25
    )
  discovery <- dplyr::bind_rows(fit_discovery, prior_discovery)

  fit_membership <- fit_status |>
    dplyr::transmute(
      dataset_id,
      fit_id,
      method,
      run_role,
      prior_profile,
      terminal_clean,
      unseen_candidate_brier = dplyr::case_when(
        method == "goal004" & run_role == "primary" &
          fidelity == "aligned" & train_occasions == 4L ~ 0.20,
        method == "goal004" & run_role == "primary" &
          fidelity == "aligned" & train_occasions == 26L ~ 0.15,
        .default = 0.25
      )
    )
  prior_membership <- prior_keys |>
    dplyr::transmute(
      dataset_id,
      fit_id = NA_character_,
      method = "goal004_prior",
      run_role = "prior_only",
      prior_profile,
      terminal_clean = TRUE,
      unseen_candidate_brier = 0.25
    )
  membership <- dplyr::bind_rows(fit_membership, prior_membership)

  nested_pairs <- fit_status |>
    dplyr::filter(run_role == "pool_sensitivity") |>
    dplyr::transmute(
      dataset_id,
      fit_id,
      train_occasions,
      replicate,
      terminal_clean,
      primary_terminal_clean = TRUE,
      abs_core_mean_shift = 0.1,
      core_pmf_total_variation = 0.01
    )
  sensitivity_pairs <- fit_status |>
    dplyr::filter(run_role == "prior_sensitivity") |>
    dplyr::transmute(
      dataset_id,
      fit_id,
      prior_profile,
      fidelity,
      true_richness,
      train_occasions,
      replicate,
      terminal_clean,
      primary_terminal_clean = TRUE,
      primary_point_estimate = true_richness,
      sensitivity_point_estimate = true_richness + 0.5,
      abs_mean_shift = 0.5,
      primary_rps = dplyr::if_else(train_occasions == 4L, 0.40, 0.20),
      sensitivity_rps = dplyr::if_else(train_occasions == 4L, 0.40, 0.20),
      own_prior_rps = dplyr::if_else(train_occasions == 4L, 0.60, 0.40)
    )
  list(
    manifest = manifest,
    fit_status = fit_status |>
      dplyr::select(
        fit_id,
        dataset_id,
        method,
        run_role,
        prior_profile,
        pool_profile,
        candidate_pool_size,
        fit_seed,
        terminal_clean,
        elapsed_seconds
      ),
    richness = richness,
    discovery = discovery,
    membership = membership,
    nested_pairs = nested_pairs,
    sensitivity_pairs = sensitivity_pairs
  )
}

testthat::test_that("Goal004 Task 4 evaluator applies every frozen gate", {
  input <- .goal004_task4_passing_gate_inputs()
  result <- do.call(evaluate_goal004_task4_gates, input)

  testthat::expect_identical(
    names(result),
    c("gates", "primary_pairs", "nested_pairs", "sensitivity_pairs")
  )
  testthat::expect_true(all(result$gates$passed))
  testthat::expect_setequal(
    substr(result$gates$gate_id, 1L, 3L),
    sprintf("G%02d", 1:11)
  )
  testthat::expect_identical(nrow(result$primary_pairs), 180L)
  testthat::expect_identical(nrow(result$nested_pairs), 30L)
  testthat::expect_identical(nrow(result$sensitivity_pairs), 180L)
})

testthat::test_that("Goal004 Task 4 catastrophic denominator is fixed at 120", {
  input <- .goal004_task4_passing_gate_inputs()
  affected_ids <- input$manifest$datasets |>
    dplyr::filter(
      fidelity == "weak_signal",
      train_occasions == 4L
    ) |>
    dplyr::slice_head(n = 6L) |>
    dplyr::pull(dataset_id)
  affected <- input$richness$method == "goal004" &
    input$richness$run_role == "primary" &
    input$richness$dataset_id %in% affected_ids
  input$richness$absolute_error[affected] <- 13
  result <- do.call(evaluate_goal004_task4_gates, input)
  gate <- result$gates |>
    dplyr::filter(gate_id == "G05-catastrophic-or-nonclean")

  testthat::expect_identical(gate$denominator, 120L)
  testthat::expect_equal(gate$numerator, 6)
  testthat::expect_false(gate$passed)
})

testthat::test_that("Goal004 Task 4 prospective count improvement is strict", {
  input <- .goal004_task4_passing_gate_inputs()
  affected <- input$discovery$method == "goal004" &
    input$discovery$run_role == "primary" &
    input$discovery$dataset_id %in% input$manifest$datasets$dataset_id[
      input$manifest$datasets$fidelity == "aligned" &
        input$manifest$datasets$train_occasions == 4L
    ]
  input$discovery$count_rps[affected] <- 0.50
  result <- do.call(evaluate_goal004_task4_gates, input)
  gate <- result$gates |>
    dplyr::filter(gate_id == "G07-discovery-count-04w")

  testthat::expect_equal(gate$value, 1)
  testthat::expect_false(gate$passed)
})

testthat::test_that("Goal004 Task 4 integrity rejects incomplete fit evidence", {
  input <- .goal004_task4_passing_gate_inputs()
  input$fit_status <- input$fit_status[-1L, ]
  result <- do.call(evaluate_goal004_task4_gates, input)

  testthat::expect_false(result$gates$passed[
    result$gates$gate_id == "G01-integrity"
  ])
})
