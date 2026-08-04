testthat::test_that("quadrature certification selects the first passing order", {
  data <- goal002r_toy_data()
  certificate <- goal002r_certify_quadrature(
    data$zero_history,
    mu_alpha = log(0.001),
    sigma_alpha = 2,
    camera_effect = stats::setNames(c(-0.2, 0.2), data$camera_ids)
  )
  testthat::expect_true(certificate$reference_error <= 1e-8)
  testthat::expect_identical(certificate$selected_order, 128L)
  testthat::expect_true(all(
    certificate$candidates$order[certificate$candidates$passed] >=
      certificate$selected_order
  ))
})

testthat::test_that("quadrature certification rejects an under-resolved tail", {
  data <- goal002r_toy_data()
  certificate <- goal002r_certify_quadrature(
    data$zero_history,
    mu_alpha = log(0.001),
    sigma_alpha = 3,
    camera_effect = stats::setNames(c(-0.2, 0.2), data$camera_ids)
  )
  testthat::expect_true(certificate$reference_error <= 1e-8)
  testthat::expect_true(is.na(certificate$selected_order))
  testthat::expect_false(any(certificate$candidates$passed))
})

testthat::test_that("fit health checks enforce posterior richness invariants", {
  testthat::skip_if_not(
    requireNamespace("cmdstanr", quietly = TRUE),
    message = "cmdstanr is unavailable"
  )
  status <- check_goal002_cmdstan(error = FALSE)
  testthat::skip_if_not(
    isTRUE(status$matches),
    message = "required CmdStan is unavailable"
  )
  fit <- goal002r_fit(
    goal002r_toy_data(),
    seed = 220020904L,
    sampler = goal002r_default_sampler(
      iter_warmup = 200L,
      iter_sampling = 200L,
      chains = 2L,
      parallel_chains = 2L
    ),
    quadrature_order = 16L,
    output_dir = tempfile("goal002r-health-")
  )
  testthat::expect_true(goal002r_validate_fit_health(fit))
  testthat::expect_true(fit$health$passed)
  testthat::expect_equal(fit$health$metrics$divergences, 0)
  testthat::expect_equal(fit$health$metrics$treedepth_hits, 0)
})
