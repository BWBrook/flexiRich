testthat::test_that("default configuration is Judbury-shaped and valid", {
  config <- flexirich_sim_config(seed = 42L)

  testthat::expect_s3_class(config, "flexirich_sim_config")
  testthat::expect_identical(config$candidate_pool_size, 30L)
  testthat::expect_identical(config$true_richness, 20L)
  testthat::expect_identical(config$n_cameras, 9L)
  testthat::expect_identical(config$n_occasions, 208L)
  testthat::expect_identical(config$occasion_days, 7L)
  testthat::expect_identical(config$seed, 42L)
})

testthat::test_that("configuration rejects invalid fields without warnings", {
  invalid_args <- list(
    candidate_pool_size = list(candidate_pool_size = 0L),
    true_richness = list(candidate_pool_size = 10L, true_richness = 11L),
    n_cameras = list(n_cameras = Inf),
    n_occasions = list(n_occasions = .Machine$integer.max + 1),
    occasion_days = list(occasion_days = 14L),
    start_date = list(start_date = as.Date(NA)),
    mean_log_rate = list(mean_log_rate = Inf),
    sd_log_rate = list(sd_log_rate = -0.1),
    sd_camera = list(sd_camera = -0.1),
    initial_operating_prob = list(initial_operating_prob = -0.1),
    daily_failure_prob = list(daily_failure_prob = 1.1),
    daily_repair_prob = list(daily_repair_prob = 1.1),
    seed = list(seed = .Machine$integer.max)
  )

  for (field in names(invalid_args)) {
    testthat::expect_no_warning(
      testthat::expect_error(
        do.call(flexirich_sim_config, invalid_args[[field]]),
        field,
        info = paste("invalid field:", field)
      )
    )
  }

  testthat::expect_no_warning(
    testthat::expect_error(validate_sim_config("not a list"), "config")
  )
})
