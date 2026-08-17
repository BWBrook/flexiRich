testthat::test_that("Goal004 Task 4 prior effort matches all 20 blocks", {
  manifest <- read_goal004_task4_manifests()
  effort <- goal004_task4_prior_effort(manifest)

  testthat::expect_identical(nrow(effort$summary), 20L)
  testthat::expect_identical(nrow(effort$cells), 180L)
  testthat::expect_identical(
    effort$summary$training_active_camera_days,
    .goal004_task4_effort_starts()$training_active_camera_days
  )
  testthat::expect_identical(
    effort$summary$future_active_camera_days,
    .goal004_task4_effort_starts()$future_active_camera_days
  )
})

testthat::test_that("Goal004 Task 4 prior forecasts retain Task 2 anchors", {
  forecast <- goal004_task4_prior_forecasts(n_draws = 200L)

  testthat::expect_identical(forecast$seed, 40042L)
  testthat::expect_identical(forecast$n_draws, 200L)
  testthat::expect_identical(nrow(forecast$effort_windows), 20L)
  testthat::expect_true(all(forecast$task2_anchor_max_abs_error == 0))
  testthat::expect_identical(
    nrow(forecast$predictive_pmf),
    6L * 20L * 2L * 51L
  )
  sums <- forecast$predictive_pmf |>
    dplyr::summarise(
      probability = sum(probability),
      .by = c(profile_id, window_id, outcome)
    )
  testthat::expect_lt(max(abs(sums$probability - 1)), 1e-14)
  testthat::expect_true(all(
    forecast$candidate_prediction$prior_membership_probability >= 0 &
      forecast$candidate_prediction$prior_membership_probability <= 1
  ))
})
