testthat::test_that("Goal004 Task 2 profiles encode only approved perturbations", {
  profiles <- read_goal004_task2_profiles()
  primary <- profiles[profiles$profile_id == "primary", ]

  testthat::expect_identical(profiles$profile_order, 1:6)
  testthat::expect_equal(primary$routine_median_rate, 0.002)
  testthat::expect_equal(primary$occasional_median_rate, 0.0005)
  testthat::expect_equal(primary$log_rate_sd, 1)
  testthat::expect_equal(
    profiles$routine_median_rate[profiles$profile_id == "rate_lower"],
    primary$routine_median_rate / 2
  )
  testthat::expect_equal(
    profiles$occasional_median_rate[profiles$profile_id == "rate_lower"],
    primary$occasional_median_rate / 2
  )
  testthat::expect_equal(
    profiles$routine_median_rate[profiles$profile_id == "rate_higher"],
    primary$routine_median_rate * 2
  )
  testthat::expect_equal(
    profiles$occasional_median_rate[profiles$profile_id == "rate_higher"],
    primary$occasional_median_rate * 2
  )
  testthat::expect_equal(
    profiles$log_rate_sd[profiles$profile_id == "spread_wider"],
    1.25
  )
  testthat::expect_equal(
    profiles$class_blur_probability[profiles$profile_id == "class_blur"],
    0.1
  )
  testthat::expect_equal(
    unlist(profiles[
      profiles$profile_id == "membership_regularised",
      c("omega_alpha", "omega_beta")
    ], use.names = FALSE),
    c(2, 2)
  )
  testthat::expect_identical(
    goal004_task2_fringe_prior(),
    list(
      membership_expected_count_scale = 5,
      routine_median_rate = 0.002,
      rare_median_rate = 0.0002,
      log_rate_sd = 1
    )
  )
})

testthat::test_that("Goal004 strata come directly from the reviewed worksheet", {
  mapping <- goal004_task2_candidate_mapping()

  testthat::expect_equal(nrow(mapping$core), 50L)
  testthat::expect_equal(nrow(mapping$fringe), 56L)
  testthat::expect_equal(
    as.integer(table(mapping$core$encounter_class)[c("routine", "occasional")]),
    c(44L, 6L)
  )
  testthat::expect_equal(
    as.integer(table(mapping$fringe$encounter_class)[c("routine", "rare")]),
    c(3L, 53L)
  )
  testthat::expect_identical(anyDuplicated(c(
    mapping$core$candidate_id,
    mapping$fringe$candidate_id
  )), 0L)
})

testthat::test_that("uniform membership gives exact uniform core richness", {
  uniform <- goal004_beta_binomial_pmf(50, 1, 1)
  regularised <- goal004_beta_binomial_pmf(50, 2, 2)

  testthat::expect_equal(sum(uniform$probability), 1, tolerance = 1e-14)
  testthat::expect_equal(
    uniform$probability,
    rep(1 / 51, 51),
    tolerance = 1e-13
  )
  testthat::expect_equal(
    regularised$probability,
    rev(regularised$probability),
    tolerance = 1e-14
  )
  testthat::expect_gt(
    regularised$probability[[26L]],
    uniform$probability[[26L]]
  )
})

testthat::test_that("prior-only windows include the exact following month", {
  effort <- goal004_task2_effort_windows(read_goal003_task4_manifests())

  testthat::expect_equal(nrow(effort$summary), 6L)
  testthat::expect_equal(nrow(effort$cells), 54L)
  testthat::expect_equal(
    effort$summary$training_active_camera_days,
    c(28, 224, 252, 790, 1210, 1570)
  )
  testthat::expect_true(all(effort$summary$future_active_camera_days >= 0L))
  testthat::expect_true(all(
    effort$summary$future_active_camera_days <= 9L * 4L * 7L
  ))
})

testthat::test_that("small Goal004 prior calibration is reproducible", {
  first <- goal004_task2_prior_only(n_draws = 300L, seed = 404L)
  second <- goal004_task2_prior_only(n_draws = 300L, seed = 404L)

  testthat::expect_identical(first$invariants, second$invariants)
  testthat::expect_identical(
    first$core_predictive_summary,
    second$core_predictive_summary
  )
  testthat::expect_true(all(first$invariants$passed))
  testthat::expect_equal(nrow(first$core_richness_pmf), 6L * 51L)
  testthat::expect_equal(nrow(first$core_candidate_membership), 6L * 50L)
  testthat::expect_equal(
    nrow(first$core_candidate_prediction),
    6L * 6L * 50L
  )
  testthat::expect_true(all(
    first$core_candidate_prediction$future_first_detection_probability <=
      first$core_candidate_prediction$prior_membership_probability
  ))
  testthat::expect_true(all(
    first$core_candidate_prediction$training_detection_probability <=
      first$core_candidate_prediction$prior_membership_probability
  ))
})
