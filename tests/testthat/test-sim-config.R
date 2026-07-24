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

testthat::test_that("configuration rejects impossible values", {
  testthat::expect_error(
    flexirich_sim_config(candidate_pool_size = 10L, true_richness = 11L),
    "true_richness"
  )
  testthat::expect_error(
    flexirich_sim_config(occasion_days = 14L),
    "occasion_days must equal 7"
  )
  testthat::expect_error(
    flexirich_sim_config(daily_failure_prob = 1.1),
    "daily_failure_prob"
  )
  testthat::expect_error(
    flexirich_sim_config(sd_log_rate = -0.1),
    "sd_log_rate"
  )
})
