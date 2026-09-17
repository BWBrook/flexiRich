testthat::test_that("Goal008 repeated-species dependence has analytic coverage", {
  caller_kind <- RNGkind()
  set.seed(9182L)
  caller_seed <- .Random.seed
  result <- goal008_gaussian_dependence(
    n_simulation = 20000L,
    seed = 812008L
  )
  coverage <- result$coverage

  testthat::expect_equal(
    coverage$information_per_species,
    c(8 / 9, 1.6, 1.6),
    tolerance = 1e-12
  )
  expected_misspecified <- 2 * stats::pnorm(
    stats::qnorm(0.95) * sqrt(5 / 9)
  ) - 1
  testthat::expect_equal(
    coverage$exact_coverage,
    c(0.9, expected_misspecified, 0.9),
    tolerance = 1e-12
  )
  testthat::expect_true(
    all(abs(
      coverage$simulated_coverage - coverage$exact_coverage
    ) <= 5 * coverage$monte_carlo_se + 0.003)
  )
  testthat::expect_lt(
    coverage$reported_se[[2L]],
    coverage$true_sampling_se[[2L]]
  )
  testthat::expect_equal(
    result$finite_set$value[[1L]],
    1 / sqrt(6),
    tolerance = 1e-12
  )
  testthat::expect_identical(result$parameters$rng_kind, "Mersenne-Twister")
  testthat::expect_identical(result$parameters$normal_kind, "Inversion")
  testthat::expect_identical(result$parameters$sample_kind, "Rejection")
  testthat::expect_equal(result$parameters$generating_mean, 0, tolerance = 0)
  testthat::expect_identical(result$parameters$location_prior, "flat")
  testthat::expect_identical(RNGkind(), caller_kind)
  testthat::expect_identical(.Random.seed, caller_seed)
})

testthat::test_that("Goal008 exact shared-omega PMF matches enumeration", {
  detected <- c(1L, 0L, 0L, 1L, 0L)
  q <- c(0.8, 0.6, 0.25, 0.9, 0.1)
  exact <- goal008_finite_pool_pmf(detected, q, a = 1.3, b = 2.1)
  brute <- goal008_finite_pool_pmf_bruteforce(
    detected, q, a = 1.3, b = 2.1
  )

  testthat::expect_equal(exact, brute, tolerance = 1e-14)
  testthat::expect_equal(sum(exact$probability), 1, tolerance = 1e-14)
  testthat::expect_identical(
    exact$richness,
    sum(detected):(length(detected))
  )

  hand <- goal008_finite_pool_pmf(c(1L, 0L), c(0.8, 0.5))
  testthat::expect_equal(hand$probability, c(0.5, 0.5), tolerance = 1e-14)

  complete <- goal008_finite_pool_pmf(c(1L, 1L), c(0.8, 0.9))
  complete_brute <- goal008_finite_pool_pmf_bruteforce(
    c(1L, 1L), c(0.8, 0.9)
  )
  testthat::expect_equal(complete$richness, 2L)
  testthat::expect_equal(complete$probability, 1)
  testthat::expect_equal(complete, complete_brute)
})

testthat::test_that("Goal008 fixed-visibility boundary recovers exact controls", {
  candidate_count <- 6L
  beta_binomial <- goal008_finite_pool_pmf(
    rep(0L, candidate_count), rep(0, candidate_count), a = 1, b = 1
  )
  beta_binomial_brute <- goal008_finite_pool_pmf_bruteforce(
    rep(0L, candidate_count), rep(0, candidate_count), a = 1, b = 1
  )
  testthat::expect_equal(
    beta_binomial$probability,
    rep(1 / (candidate_count + 1), candidate_count + 1L),
    tolerance = 1e-14
  )
  testthat::expect_equal(beta_binomial, beta_binomial_brute, tolerance = 1e-14)

  perfectly_visible <- goal008_finite_pool_pmf(
    c(1L, 0L), c(0.8, 1), a = 1, b = 1
  )
  testthat::expect_equal(perfectly_visible$probability, c(1, 0), tolerance = 0)
  testthat::expect_error(
    goal008_finite_pool_pmf(c(1L, 0L), c(0, 0.5)),
    "observed detection cannot have zero probability",
    fixed = TRUE
  )
})

testthat::test_that("Goal008 missed-detection counterexamples hold targets fixed", {
  missed <- goal008_missed_probability_examples()
  means <- unique(missed$mean_log_rate)
  testthat::expect_length(means, 1L)
  by_effort <- split(missed, missed$effort)
  testthat::expect_true(all(vapply(
    by_effort,
    function(rows) diff(rows$missed_probability) != 0,
    logical(1)
  )))

  seasonal <- goal008_seasonal_allocation_examples()
  testthat::expect_true(all(seasonal$total_effort == 60))
  year_round <- seasonal[seasonal$availability == "year_round", ]
  testthat::expect_equal(
    year_round$missed_probability,
    rep(exp(-1.2), 3L),
    tolerance = 1e-14
  )
  season_a <- seasonal[seasonal$availability == "season_A_only", ]
  testthat::expect_gt(
    length(unique(season_a$missed_probability)),
    1L
  )
  testthat::expect_equal(
    season_a$missed_probability[season_a$schedule == "season_B_concentrated"],
    1,
    tolerance = 0
  )
})

testthat::test_that("Goal008 rejects invalid finite-pool inputs", {
  testthat::expect_error(
    goal008_finite_pool_pmf(c(1L, 0L), c(0.5, -0.1)),
    "fixed candidate pool",
    fixed = TRUE
  )
  testthat::expect_error(
    goal008_finite_pool_pmf_bruteforce(
      rep(0L, 21L), rep(0.5, 21L)
    ),
    "restricted to small pools",
    fixed = TRUE
  )
})
