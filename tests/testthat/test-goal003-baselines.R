testthat::test_that("incidence samples omit zero effort and retain partial weeks", {
  data <- .goal003_baseline_fixture()
  primary <- make_goal003_incidence_sample(data)
  complete <- make_goal003_incidence_sample(data, complete_only = TRUE)

  testthat::expect_identical(primary$n_sampling_units, 11L)
  testthat::expect_identical(complete$n_sampling_units, 10L)
  testthat::expect_identical(primary$observed_richness, 4L)
  testthat::expect_identical(dim(primary$incidence), c(8L, 11L))
  testthat::expect_identical(
    primary$incidence_frequency,
    as.integer(rowSums(primary$incidence))
  )
  testthat::expect_true("cam_a::occ_003" %in% primary$sample_ids)
  testthat::expect_false("cam_a::occ_003" %in% complete$sample_ids)
  testthat::expect_false("cam_b::occ_002" %in% primary$sample_ids)
})

testthat::test_that("Chao2 and iChao2 reproduce the published North example", {
  sample <- .goal003_sample_from_frequencies(
    T = 12L,
    frequencies = c(
      rep(1L, 9L), rep(2L, 4L), rep(3L, 3L),
      rep(5L, 11L)
    ),
    C = 60L
  )
  estimate <- estimate_goal003_incidence_richness(sample)

  testthat::expect_equal(
    estimate$raw_estimate[estimate$method == "chao2"],
    36.28125,
    tolerance = 1e-12
  )
  testthat::expect_equal(
    estimate$raw_estimate[estimate$method == "ichao2"],
    38.58238636363636,
    tolerance = 1e-12
  )
})

testthat::test_that("iChao2 uses the positive-Q4 correction", {
  sample <- .goal003_sample_from_frequencies(
    T = 17L,
    frequencies = c(
      rep(1L, 12L), rep(2L, 8L), rep(3L, 3L),
      rep(4L, 3L), rep(6L, 12L)
    ),
    C = 80L
  )
  estimate <- estimate_goal003_incidence_richness(sample)
  chao2 <- 38 + (16 / 17) * 12^2 / (2 * 8)
  ichao2 <- chao2 + (14 / (4 * 17)) * (3 / 3) * max(
    12 - (14 / (2 * 16)) * (8 * 3 / 3),
    0
  )

  testthat::expect_equal(
    estimate$raw_estimate[estimate$method == "chao2"],
    chao2,
    tolerance = 1e-12
  )
  testthat::expect_equal(
    estimate$raw_estimate[estimate$method == "ichao2"],
    ichao2,
    tolerance = 1e-12
  )
})

testthat::test_that("incidence estimators preserve raw values and finite-pool caps", {
  sample <- .goal003_sample_from_frequencies(
    T = 10L,
    frequencies = c(rep(1L, 8L), 5L, 5L),
    C = 10L
  )
  estimate <- estimate_goal003_incidence_richness(sample)

  testthat::expect_gt(
    estimate$raw_estimate[estimate$method == "chao2"],
    10
  )
  testthat::expect_equal(
    estimate$estimate[estimate$method == "chao2"],
    10
  )
  testthat::expect_true(
    estimate$exceeded_pool[estimate$method == "chao2"]
  )
})

testthat::test_that("incidence estimators report small-sample ineligibility", {
  sample <- .goal003_sample_from_frequencies(
    T = 3L,
    frequencies = c(1L, 2L),
    C = 4L
  )
  estimate <- estimate_goal003_incidence_richness(sample)

  testthat::expect_true(estimate$eligible[estimate$method == "chao2"])
  testthat::expect_false(estimate$eligible[estimate$method == "ichao2"])
  testthat::expect_true(is.na(
    estimate$estimate[estimate$method == "ichao2"]
  ))
})

testthat::test_that("observed and lower-bound PMFs use the exact finite support", {
  sample <- make_goal003_incidence_sample(.goal003_baseline_fixture())
  observed <- goal003_observed_richness_pmf(sample)
  lower_bound <- goal003_lower_bound_prior_pmf(sample)

  testthat::expect_identical(observed$richness, 0:8)
  testthat::expect_identical(observed$probability, c(0, 0, 0, 0, 1, 0, 0, 0, 0))
  testthat::expect_equal(sum(lower_bound$probability), 1, tolerance = 1e-14)
  testthat::expect_true(all(lower_bound$probability[1:4] == 0))

  forecast <- predict_goal003_observed_new_species(sample)
  testthat::expect_identical(
    forecast$new_species_count_pmf$new_species_count,
    0:4
  )
  testthat::expect_identical(
    forecast$new_species_count_pmf$probability,
    c(1, 0, 0, 0, 0)
  )
  testthat::expect_true(all(
    forecast$future_identity$future_first_detection_probability == 0
  ))
})

testthat::test_that("iNEXT curves retain package estimates and finite-pool caps", {
  sample <- make_goal003_incidence_sample(.goal003_baseline_fixture())
  result <- estimate_goal003_inext_curve(sample, endpoint = 15L)

  testthat::expect_identical(
    names(result),
    c("curve", "asymptotic", "metadata")
  )
  testthat::expect_identical(
    names(result$curve),
    c(
      "basis", "sample_size", "coverage", "method", "raw_estimate",
      "estimate", "exceeded_pool"
    )
  )
  testthat::expect_identical(
    sort(unique(result$curve$basis)),
    c("coverage", "sample_size")
  )
  testthat::expect_equal(nrow(result$curve), 30L)
  observed_row <- result$curve |>
    dplyr::filter(
      basis == "sample_size",
      sample_size == sample$n_sampling_units
    )
  testthat::expect_equal(observed_row$raw_estimate, 4, tolerance = 1e-12)
  testthat::expect_true(all(result$curve$estimate <= 8))
  testthat::expect_identical(result$metadata$version, "3.0.2")
})

testthat::test_that("iNEXT prospective output is explicit about eligibility", {
  sample <- make_goal003_incidence_sample(.goal003_baseline_fixture())
  forecast <- predict_goal003_inext_new_species(
    sample,
    future_sampling_units = 4L
  )
  too_far <- predict_goal003_inext_new_species(
    sample,
    future_sampling_units = 12L
  )
  no_future <- predict_goal003_inext_new_species(
    sample,
    future_sampling_units = 0L
  )

  testthat::expect_true(forecast$eligible)
  testthat::expect_true(is.finite(forecast$expected_new_species))
  testthat::expect_gte(forecast$expected_new_species, 0)
  testthat::expect_false(too_far$eligible)
  testthat::expect_match(too_far$reason, "twice")
  testthat::expect_true(no_future$eligible)
  testthat::expect_equal(no_future$expected_new_species, 0)
})

testthat::test_that("iNEXT curve enforces its locked extrapolation boundary", {
  sample <- make_goal003_incidence_sample(.goal003_baseline_fixture())

  testthat::expect_error(
    estimate_goal003_inext_curve(sample, endpoint = 23L),
    "T through 2T",
    fixed = TRUE
  )
  testthat::expect_error(
    estimate_goal003_inext_curve(sample, endpoint = 10L),
    "T through 2T",
    fixed = TRUE
  )
})
