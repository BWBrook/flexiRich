testthat::test_that("occupancy data preserve species by camera detections", {
  source_data <- .goal003_baseline_fixture()
  data <- prepare_goal003_occupancy_data(source_data)

  testthat::expect_identical(data$stan_data$C, 8L)
  testthat::expect_identical(data$stan_data$J, 2L)
  testthat::expect_identical(dim(data$site_detected_ever), c(8L, 2L))
  testthat::expect_identical(
    data$detected_ever,
    c(1L, 1L, 1L, 1L, 0L, 0L, 0L, 0L)
  )
  testthat::expect_true(all(
    data$stan_data$n_detected <= data$stan_data$n_trials
  ))
  testthat::expect_match(data$data_hash, "^[0-9a-f]{64}$")
})

testthat::test_that("occupancy conditionals match direct site enumeration", {
  data <- prepare_goal003_occupancy_data(.goal003_baseline_fixture())
  psi <- seq(0.1, 0.45, length.out = 8L)
  rate <- exp(seq(log(0.005), log(0.08), length.out = 8L))
  out <- goal003_occupancy_conditionals(data, psi, rate)

  i <- 5L
  j <- 1L
  member <- exp(out$member_ll[i, j])
  enumerated <- psi[[i]] * member /
    ((1 - psi[[i]]) + psi[[i]] * member)
  testthat::expect_equal(out$q_site[i, j], enumerated, tolerance = 1e-13)
  testthat::expect_true(all(
    out$q_site[data$site_detected_ever == 1L] == 1
  ))
  testthat::expect_equal(
    out$q_grid,
    1 - apply(1 - out$q_site, 1L, prod),
    tolerance = 1e-14
  )
})

testthat::test_that("occupancy conditionals remain defined at extreme hazards", {
  data <- prepare_goal003_occupancy_data(.goal003_baseline_fixture())
  low <- goal003_occupancy_conditionals(
    data,
    psi = rep(0.2, 8L),
    rate = rep(1e-300, 8L)
  )
  high <- goal003_occupancy_conditionals(
    data,
    psi = rep(0.2, 8L),
    rate = rep(1e300, 8L)
  )

  testthat::expect_false(any(is.nan(low$member_ll)))
  testthat::expect_false(any(is.nan(high$member_ll)))
  testthat::expect_true(all(low$q_site >= 0 & low$q_site <= 1))
  testthat::expect_true(all(high$q_site >= 0 & high$q_site <= 1))
})

testthat::test_that("occupancy draw summaries produce exact PMF hand cases", {
  candidate_ids <- c("sp_a", "sp_b")
  camera_ids <- c("cam_a", "cam_b")
  q_site <- array(0, dim = c(2L, 2L, 2L))
  q_site[, 1L, 1L] <- 1
  q_site[2L, 2L, 1L] <- 0.5
  rate <- matrix(c(0.1, 0.1, 0.1, 0.1), nrow = 2L, byrow = TRUE)
  out <- summarise_goal003_occupancy_draws(
    q_site,
    rate,
    candidate_ids,
    camera_ids,
    detected_ever = c(1L, 0L),
    future_active_days = c(cam_a = 7, cam_b = 0)
  )

  testthat::expect_identical(out$richness_pmf$richness, 0:2)
  testthat::expect_equal(
    out$richness_pmf$probability,
    c(0, 0.75, 0.25),
    tolerance = 1e-14
  )
  p_discovery <- 0.25 * (-expm1(-0.7))
  testthat::expect_equal(
    out$new_species_count_pmf$probability,
    c(1 - p_discovery, p_discovery),
    tolerance = 1e-14
  )
  testthat::expect_identical(
    names(out$new_species_count_pmf),
    c("new_species_count", "probability")
  )
  testthat::expect_equal(
    out$future_identity$future_first_detection_probability,
    c(0, p_discovery),
    tolerance = 1e-14
  )
})

testthat::test_that("occupancy forecasts respect zero future effort and seen species", {
  q_site <- array(0.4, dim = c(3L, 2L, 2L))
  q_site[, 1L, 1L] <- 1
  rate <- matrix(0.02, nrow = 3L, ncol = 2L)
  out <- summarise_goal003_occupancy_draws(
    q_site,
    rate,
    candidate_ids = c("seen", "unseen"),
    camera_ids = c("cam_a", "cam_b"),
    detected_ever = c(1L, 0L),
    future_active_days = c(cam_a = 0, cam_b = 0)
  )

  testthat::expect_equal(
    out$new_species_count_pmf$probability,
    c(1, 0)
  )
  testthat::expect_true(all(
    out$future_identity$future_first_detection_probability == 0
  ))
})

testthat::test_that("occupancy profiles are frozen at the contract values", {
  prior <- goal003_occupancy_prior()
  sampler <- goal003_occupancy_sampler_profiles()
  thresholds <- goal003_occupancy_diagnostic_thresholds()

  testthat::expect_equal(prior$mu_psi_location, stats::qlogis(0.1))
  testthat::expect_equal(prior$mu_log_rate_location, log(0.02))
  testthat::expect_identical(sampler$primary$iter_sampling, 1000L)
  testthat::expect_equal(sampler$rescue$adapt_delta, 0.999)
  testthat::expect_identical(sampler$rescue$max_treedepth, 15L)
  testthat::expect_equal(thresholds$max_rhat, 1.01)
})

testthat::test_that("future effort must cover the fitted camera grid", {
  cameras <- c("cam_a", "cam_b")
  valid <- tidyr::expand_grid(
    camera_id = cameras,
    occasion_id = c("future_1", "future_2")
  ) |>
    dplyr::mutate(active_days = 7L)
  totals <- .goal003_future_active_days(valid, cameras)

  testthat::expect_identical(totals, c(cam_a = 14, cam_b = 14))
  testthat::expect_error(
    .goal003_future_active_days(valid[-1L, ], cameras),
    "complete",
    fixed = TRUE
  )
})
