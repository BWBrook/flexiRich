testthat::test_that("expected likelihood is centred at its generating point", {
  membership <- c(10, 25, 40)
  log_rate <- log(c(0.001, 0.002, 0.004))
  likelihood <- goal004_task1_expected_log_likelihood(
    membership = membership,
    log_rate = log_rate,
    candidate_count = 50,
    truth_membership = 25,
    truth_rate = 0.002,
    effort = rep(7, 9 * 26)
  )

  maximum <- which(likelihood == max(likelihood), arr.ind = TRUE)
  testthat::expect_identical(as.integer(maximum[1L, ]), c(2L, 2L))
})

testthat::test_that("zero-effort cells are unsampled", {
  arguments <- list(
    membership = seq(0, 50, by = 5),
    log_rate = log(c(0.001, 0.002, 0.004)),
    candidate_count = 50,
    truth_membership = 25,
    truth_rate = 0.002
  )
  without_zero <- do.call(
    goal004_task1_expected_log_likelihood,
    c(arguments, list(effort = c(7, 5, 3)))
  )
  with_zero <- do.call(
    goal004_task1_expected_log_likelihood,
    c(arguments, list(effort = c(0, 7, 0, 5, 3, 0)))
  )

  testthat::expect_equal(with_zero, without_zero, tolerance = 1e-12)
  testthat::expect_equal(
    attr(with_zero, "expected_detected"),
    attr(without_zero, "expected_detected"),
    tolerance = 1e-12
  )
})

testthat::test_that("all-zero fringe data retain zero membership support", {
  likelihood <- goal004_task1_expected_log_likelihood(
    membership = c(0, 1, 5),
    log_rate = log(c(0.001, 0.002)),
    candidate_count = 56,
    truth_membership = 0,
    truth_rate = 0.002,
    effort = rep(7, 9 * 4)
  )

  testthat::expect_true(all(is.finite(likelihood)))
  testthat::expect_equal(likelihood[1L, ], c(0, 0), tolerance = 1e-14)
  testthat::expect_true(all(likelihood[1L, ] > likelihood[2L, ]))
})

testthat::test_that("frozen effort representatives retain the full audit", {
  effort <- goal004_task1_effort_windows(
    read_goal003_task4_manifests()
  )

  testthat::expect_equal(nrow(effort$audit), 60L)
  testthat::expect_equal(nrow(effort$representatives), 6L)
  testthat::expect_equal(sum(effort$audit$representative), 6L)
  expected <- effort$representatives |>
    dplyr::arrange(train_occasions, match(
      effort_label,
      c("minimum", "lower_median", "maximum")
    )) |>
    dplyr::select(train_occasions, effort_label, active_camera_days)
  testthat::expect_equal(
    expected$active_camera_days,
    c(28, 224, 252, 790, 1210, 1570)
  )
})

testthat::test_that("exchangeable surface has normalized finite summaries", {
  surface <- goal004_task1_exchangeable_surface(
    candidate_count = 50,
    truth_membership = 25,
    truth_rate = 0.002,
    effort = rep(7, 9 * 4),
    rate_prior_id = "centred_broad"
  )

  testthat::expect_equal(sum(surface$marginal_membership), 1, tolerance = 1e-12)
  testthat::expect_equal(sum(surface$marginal_rate), 1, tolerance = 1e-12)
  testthat::expect_equal(
    surface$summary$prior_membership_mean,
    25,
    tolerance = 1e-12
  )
  testthat::expect_true(all(is.finite(unlist(
    surface$summary[c(
      "posterior_membership_mean",
      "posterior_membership_sd",
      "posterior_membership_crps",
      "profile_membership_span",
      "profile_rate_ratio"
    )],
    use.names = FALSE
  ))))
})

testthat::test_that("zero fringe histories learn less for rare candidates", {
  common <- goal004_task1_stratified_surface(
    truth_membership = 25,
    truth_rate = 0.002,
    effort = rep(7, 9 * 4),
    rate_prior_id = "centred_broad",
    fringe_prior_scale = 5,
    fringe_rate_multiplier = 1
  )
  rare <- goal004_task1_stratified_surface(
    truth_membership = 25,
    truth_rate = 0.002,
    effort = rep(7, 9 * 4),
    rate_prior_id = "centred_broad",
    fringe_prior_scale = 5,
    fringe_rate_multiplier = 0.1
  )

  testthat::expect_equal(sum(common$marginal_core), 1, tolerance = 1e-12)
  testthat::expect_equal(sum(common$marginal_fringe), 1, tolerance = 1e-12)
  testthat::expect_gt(
    common$summary$fringe_mean_reduction,
    rare$summary$fringe_mean_reduction
  )
  testthat::expect_lt(
    common$summary$posterior_fringe_mean,
    rare$summary$posterior_fringe_mean
  )
})

testthat::test_that("decision checkpoint distinguishes all three outcomes", {
  core <- tibble::tibble(
    model = "exchangeable",
    candidate_count = 50L,
    fringe_prior_scale = NA_real_,
    fringe_rate_multiplier = NA_real_,
    truth_membership = c(10, 25, 40),
    rate_prior_id = "centred_broad",
    train_occasions = 4L,
    effort_label = "lower_median",
    posterior_membership_mean = c(12, 25, 38),
    posterior_total_mean = c(12, 25, 38),
    crps_improvement = c(0.2, 0.3, 0.4),
    fringe_mean_reduction = NA_real_
  )
  broad <- core |>
    dplyr::mutate(
      model = "core_fringe",
      candidate_count = 106L,
      fringe_prior_scale = 5,
      fringe_rate_multiplier = 0.1,
      posterior_membership_mean = posterior_membership_mean + 0.5,
      posterior_total_mean = posterior_membership_mean + 2,
      fringe_mean_reduction = 0.3
    )
  passing <- dplyr::bind_rows(core, broad)

  shifted <- goal004_task1_add_pool_shifts(
    dplyr::mutate(
      passing,
      effort_replicate = 1L,
      effort_block_start = 10L
    )
  )
  testthat::expect_equal(nrow(shifted), nrow(passing))
  testthat::expect_equal(
    shifted$total_shift_vs_primary50[shifted$model == "exchangeable"],
    c(0, 0, 0)
  )

  testthat::expect_identical(
    goal004_task1_decision(passing)$status,
    "PROCEED"
  )
  broad$fringe_mean_reduction <- 0.1
  testthat::expect_identical(
    goal004_task1_decision(dplyr::bind_rows(core, broad))$status,
    "CORE_ONLY"
  )
  core$posterior_membership_mean <- c(20, 25, 30)
  testthat::expect_identical(
    goal004_task1_decision(dplyr::bind_rows(core, broad))$status,
    "STOP"
  )
})
