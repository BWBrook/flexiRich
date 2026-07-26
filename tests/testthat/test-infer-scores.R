testthat::test_that("lower-bound comparator matches the exact hand case", {
  pmf <- lower_bound_prior_pmf(
    candidate_pool_size = 4L,
    observed_richness = 2L,
    omega_alpha = 1,
    omega_beta = 1
  )

  testthat::expect_s3_class(pmf, "tbl_df")
  testthat::expect_identical(names(pmf), c("richness", "probability"))
  testthat::expect_identical(pmf$richness, 0:4)
  testthat::expect_type(pmf$probability, "double")
  testthat::expect_equal(
    pmf$probability,
    c(0, 0, 0.1, 0.3, 0.6),
    tolerance = 1e-14
  )
  testthat::expect_equal(sum(pmf$probability), 1, tolerance = 1e-14)
  testthat::expect_equal(
    ranked_probability_score(pmf, truth = 3L),
    0.37,
    tolerance = 1e-14
  )
})

testthat::test_that("lower-bound comparator has beta-binomial moments", {
  pmf <- lower_bound_prior_pmf(
    candidate_pool_size = 8L,
    observed_richness = 2L,
    omega_alpha = 3,
    omega_beta = 4
  )
  pmf_mean <- sum(pmf$richness * pmf$probability)
  pmf_variance <- sum(
    (pmf$richness - pmf_mean)^2 * pmf$probability
  )

  testthat::expect_equal(pmf_mean, 16 / 3, tolerance = 1e-13)
  testthat::expect_equal(pmf_variance, 20 / 9, tolerance = 1e-13)
})

testthat::test_that("lower-bound comparator handles richness boundaries", {
  empty <- lower_bound_prior_pmf(0L, 0L, 1, 1)
  none_observed <- lower_bound_prior_pmf(2L, 0L, 1, 1)
  complete <- lower_bound_prior_pmf(4L, 4L, 1, 1)

  testthat::expect_identical(empty$richness, 0L)
  testthat::expect_identical(empty$probability, 1)
  testthat::expect_equal(
    none_observed$probability,
    rep(1 / 3, 3),
    tolerance = 1e-14
  )
  testthat::expect_equal(
    complete$probability,
    c(0, 0, 0, 0, 1)
  )
})

testthat::test_that("lower-bound comparator remains stable for extreme beta shapes", {
  concentrated <- lower_bound_prior_pmf(4L, 0L, 1e300, 1e300)
  upper_tail <- lower_bound_prior_pmf(4L, 0L, 1e300, 1e-300)
  lower_tail <- lower_bound_prior_pmf(4L, 0L, 1e-300, 1e300)

  testthat::expect_equal(
    concentrated$probability,
    c(1, 4, 6, 4, 1) / 16,
    tolerance = 1e-12
  )
  for (pmf in list(concentrated, upper_tail, lower_tail)) {
    testthat::expect_true(all(is.finite(pmf$probability)))
    testthat::expect_true(all(pmf$probability >= 0))
    testthat::expect_equal(
      sum(pmf$probability),
      1,
      tolerance = 1e-14
    )
  }
  testthat::expect_gt(upper_tail$probability[5L], 1 - 1e-12)
  testthat::expect_gt(lower_tail$probability[1L], 1 - 1e-12)
})

testthat::test_that("lower-bound comparator rejects invalid richness inputs", {
  invalid_candidate_pool <- list(
    NULL,
    numeric(),
    c(1, 2),
    NA_real_,
    NaN,
    Inf,
    -1,
    1.5,
    TRUE,
    "4",
    2^31
  )
  invalid_observed <- list(
    NULL,
    numeric(),
    c(0, 1),
    NA_real_,
    NaN,
    Inf,
    -1,
    1.5,
    TRUE,
    "2"
  )

  for (value in invalid_candidate_pool) {
    testthat::expect_error(
      lower_bound_prior_pmf(value, 0L, 1, 1),
      "candidate_pool_size",
      fixed = TRUE
    )
  }
  for (value in invalid_observed) {
    testthat::expect_error(
      lower_bound_prior_pmf(4L, value, 1, 1),
      "observed_richness",
      fixed = TRUE
    )
  }
  testthat::expect_error(
    lower_bound_prior_pmf(3L, 4L, 1, 1),
    "must not exceed",
    fixed = TRUE
  )
})

testthat::test_that("lower-bound comparator rejects invalid beta shapes", {
  invalid_shapes <- list(
    NULL,
    numeric(),
    c(1, 2),
    NA_real_,
    NaN,
    Inf,
    0,
    -1,
    TRUE,
    "1"
  )

  for (value in invalid_shapes) {
    testthat::expect_error(
      lower_bound_prior_pmf(4L, 2L, value, 1),
      "omega_alpha",
      fixed = TRUE
    )
    testthat::expect_error(
      lower_bound_prior_pmf(4L, 2L, 1, value),
      "omega_beta",
      fixed = TRUE
    )
  }
})

testthat::test_that("discrete summaries use frozen tie and quantile rules", {
  pmf <- tibble::tibble(
    richness = 0:4,
    probability = c(0, 0.2, 0.3, 0.3, 0.2)
  )
  out <- discrete_richness_summary(
    pmf,
    levels = c(0.8, 0.9, 0.95)
  )

  testthat::expect_equal(out$mean, 2.5, tolerance = 1e-14)
  testthat::expect_identical(out$median, 2L)
  testthat::expect_identical(out$mode, 2L)
  testthat::expect_identical(
    names(out$intervals),
    c("80", "90", "95")
  )
})

testthat::test_that("discrete quantiles choose the first CDF boundary", {
  pmf <- tibble::tibble(
    richness = 0:2,
    probability = c(0.2, 0.3, 0.5)
  )
  out <- discrete_richness_summary(pmf, levels = 0.6)

  testthat::expect_identical(out$median, 1L)
  testthat::expect_identical(out$mode, 2L)
  testthat::expect_identical(names(out$intervals), "60")
  testthat::expect_identical(
    out$intervals[["60"]],
    c(lower = 0L, upper = 2L)
  )
})

testthat::test_that("interval labels are stable and cannot collide", {
  pmf <- tibble::tibble(
    richness = 0:2,
    probability = c(0.2, 0.3, 0.5)
  )
  out <- discrete_richness_summary(pmf, levels = c(0.95, 0.8, 1 / 3))

  testthat::expect_identical(
    names(out$intervals),
    c("95", "80", "33.3333333333333")
  )
  testthat::expect_error(
    discrete_richness_summary(pmf, levels = c(0.8, 0.8)),
    "duplicate",
    fixed = TRUE
  )
  testthat::expect_error(
    discrete_richness_summary(
      pmf,
      levels = c(0.8, 0.8 + .Machine$double.eps)
    ),
    "unique interval names",
    fixed = TRUE
  )
})

testthat::test_that("discrete summaries reject invalid interval levels", {
  pmf <- tibble::tibble(
    richness = 0:2,
    probability = c(0.2, 0.3, 0.5)
  )
  invalid_levels <- list(
    NULL,
    numeric(),
    NA_real_,
    NaN,
    Inf,
    0,
    1,
    -0.1,
    1.1,
    TRUE,
    "0.8"
  )

  for (value in invalid_levels) {
    testthat::expect_error(
      discrete_richness_summary(pmf, levels = value),
      "levels",
      fixed = TRUE
    )
  }
})

testthat::test_that("score consumers reject malformed PMFs without reordering", {
  valid <- tibble::tibble(
    richness = 0:2,
    probability = c(0.2, 0.3, 0.5)
  )
  malformed <- list(
    data.frame(richness = 0:2, probability = c(0.2, 0.3, 0.5)),
    tibble::tibble(
      richness = 0:2,
      probability = c(0.2, 0.3, 0.5),
      extra = 1
    ),
    tibble::tibble(
      richness = as.numeric(0:2),
      probability = c(0.2, 0.3, 0.5)
    ),
    tibble::tibble(
      richness = 0:2,
      probability = c(0L, 0L, 1L)
    ),
    valid[c(2, 1, 3), ],
    tibble::tibble(
      richness = c(0L, 1L, 1L),
      probability = c(0.2, 0.3, 0.5)
    ),
    tibble::tibble(
      richness = c(0L, 2L),
      probability = c(0.5, 0.5)
    ),
    tibble::tibble(
      richness = 0:2,
      probability = c(0.2, -0.1, 0.9)
    ),
    tibble::tibble(
      richness = 0:2,
      probability = c(0.2, NA_real_, 0.8)
    ),
    tibble::tibble(
      richness = 0:2,
      probability = c(0.2, Inf, 0.8)
    ),
    tibble::tibble(
      richness = 0:2,
      probability = c(0.2, 0.3, 0.4)
    )
  )

  for (pmf in malformed) {
    testthat::expect_error(
      discrete_richness_summary(pmf, levels = 0.8),
      "pmf",
      fixed = TRUE
    )
    testthat::expect_error(
      ranked_probability_score(pmf, truth = 1L),
      "pmf",
      fixed = TRUE
    )
  }
})

testthat::test_that("ranked probability score has the frozen unnormalised range", {
  point_mass <- function(C, location) {
    probability <- numeric(C + 1L)
    probability[location + 1L] <- 1
    tibble::tibble(richness = 0:C, probability = probability)
  }

  testthat::expect_identical(
    ranked_probability_score(point_mass(0L, 0L), truth = 0L),
    0
  )
  testthat::expect_identical(
    ranked_probability_score(point_mass(4L, 2L), truth = 2L),
    0
  )
  testthat::expect_identical(
    ranked_probability_score(point_mass(4L, 0L), truth = 4L),
    4
  )

  pmf <- tibble::tibble(
    richness = 0:4,
    probability = c(0.05, 0.1, 0.2, 0.25, 0.4)
  )
  scores <- vapply(
    0:4,
    function(truth) ranked_probability_score(pmf, truth),
    numeric(1)
  )
  testthat::expect_true(all(is.finite(scores)))
  testthat::expect_true(all(scores >= 0))
  testthat::expect_true(all(scores <= 4))
})

testthat::test_that("ranked probability score rejects invalid truth", {
  pmf <- tibble::tibble(
    richness = 0:2,
    probability = c(0.2, 0.3, 0.5)
  )
  invalid_truth <- list(
    NULL,
    numeric(),
    c(1, 2),
    NA_real_,
    NaN,
    Inf,
    -1,
    3,
    1.5,
    TRUE,
    "1"
  )

  for (value in invalid_truth) {
    testthat::expect_error(
      ranked_probability_score(pmf, truth = value),
      "truth",
      fixed = TRUE
    )
  }
})
