testthat::test_that("Task 4 membership scoring isolates unseen candidates", {
  manifest <- read_goal004_task4_manifests()
  simulation <- simulate_goal004_task4_dataset(
    manifest$datasets[1L, ],
    manifest
  )
  truth <- simulation$truth
  perfect <- tibble::tibble(
    species_id = truth$species$species_id,
    membership_probability = as.numeric(truth$species$member)
  )
  score <- score_goal004_task4_membership(
    simulation$dataset_id,
    "fit",
    "goal004",
    "primary",
    TRUE,
    truth,
    perfect
  )

  testthat::expect_identical(score$all_candidate_brier, 0)
  testthat::expect_identical(score$unseen_candidate_brier, 0)
  testthat::expect_identical(score$n_candidates, 50L)
  testthat::expect_identical(
    score$n_unseen_candidates,
    as.integer(sum(!truth$species$training_detected))
  )
})

testthat::test_that("Task 4 prior scores use exact membership probability", {
  manifest <- read_goal004_task4_manifests()
  row <- manifest$datasets[1L, ]
  simulation <- simulate_goal004_task4_dataset(row, manifest)
  prior <- goal004_task4_prior_forecasts(n_draws = 200L)
  score <- score_goal004_task4_prior(
    row,
    simulation$truth,
    prior,
    profile_id = "primary"
  )

  testthat::expect_equal(
    score$membership$all_candidate_brier,
    0.25,
    tolerance = 1e-15
  )
  testthat::expect_equal(
    score$membership$unseen_candidate_brier,
    0.25,
    tolerance = 1e-15
  )
  testthat::expect_true(is.finite(score$richness$rps))
  testthat::expect_true(is.finite(score$discovery$count_rps))
  testthat::expect_true(is.finite(score$discovery$identity_brier))
})

testthat::test_that("Task 4 fit scoring treats non-clean fits as unavailable", {
  manifest <- read_goal004_task4_manifests()
  row <- manifest$datasets[1L, ]
  simulation <- simulate_goal004_task4_dataset(row, manifest)
  fit_row <- manifest$fits |>
    dplyr::filter(
      dataset_id == row$dataset_id,
      method == "goal004",
      run_role == "primary"
    )
  score <- score_goal004_task4_fit(
    fit_row,
    simulation$truth,
    terminal_clean = FALSE
  )

  testthat::expect_false(score$richness$prediction_available)
  testthat::expect_false(score$discovery$prediction_available)
  testthat::expect_false(score$membership$prediction_available)
  testthat::expect_false(score$richness$interval_90_covered)
})
