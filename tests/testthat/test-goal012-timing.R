testthat::test_that("Goal012 strata preserve zero effort and exact effort/context boundaries", {
  y <- matrix(c(
    NA, 0, 1, 0, 1, NA,
    NA, 1, 0, 1, 0, NA
  ), nrow = 2L, byrow = TRUE)
  effort <- matrix(c(
    0, 3, 3, 3, 7, 0,
    0, 3, 3, 3, 3, 0
  ), nrow = 2L, byrow = TRUE)
  context <- matrix(c(
    "inactive", "core", "core", "boundary", "core", "inactive",
    "inactive", "core", "core", "core", "core", "inactive"
  ), nrow = 2L, byrow = TRUE)
  strata <- goal012_timing_strata(y, effort, context)

  testthat::expect_equal(length(strata$indices), 4L)
  testthat::expect_equal(strata$table$row, c(1L, 1L, 1L, 2L))
  testthat::expect_equal(strata$table$active_days, c(3L, 3L, 7L, 3L))
  testthat::expect_equal(strata$table$context,
                         c("boundary", "core", "core", "core"))
  testthat::expect_equal(strata$table$n_cells, c(1L, 2L, 1L, 4L))
  testthat::expect_equal(strata$table$n_detected, c(0L, 1L, 1L, 2L))
  testthat::expect_equal(strata$table$nondetected, c(1L, 1L, 0L, 2L))
  testthat::expect_equal(strata$mixed, c(2L, 4L))
  testthat::expect_true(all(is.na(y)[effort == 0]))
  testthat::expect_length(goal012_timing_strata(
    matrix(NA_real_, 2L, 3L), matrix(0, 2L, 3L),
    matrix("unused", 2L, 3L)
  )$indices, 0L)
})

testthat::test_that("twenty timing shuffles conserve every mixed-stratum margin", {
  y <- matrix(c(
    0, 1, 0, 1, 0, 1, NA,
    1, 0, 1, 0, 1, 0, NA
  ), nrow = 2L, byrow = TRUE)
  effort <- matrix(c(
    7, 7, 7, 7, 3, 3, 0,
    7, 7, 7, 7, 3, 3, 0
  ), nrow = 2L, byrow = TRUE)
  context <- matrix(c(
    rep("a", 4), rep("b", 3),
    rep("a", 4), rep("b", 3)
  ), nrow = 2L, byrow = TRUE)
  strata <- goal012_timing_strata(y, effort, context)
  original_na <- is.na(y)
  original_counts <- vapply(strata$indices, function(i) sum(y[i] == 1), integer(1L))
  withr::with_seed(12012, {
    for (replicate in seq_len(20L)) {
      shuffled <- goal012_shuffle_timing(y, strata)
      testthat::expect_equal(dim(shuffled), dim(y))
      testthat::expect_identical(is.na(shuffled), original_na)
      testthat::expect_equal(
        vapply(strata$indices, function(i) sum(shuffled[i] == 1), integer(1L)),
        original_counts
      )
      testthat::expect_equal(shuffled[is.na(y)], y[is.na(y)])
    }
  })
})

testthat::test_that("exact timing expectations match complete allocation enumeration", {
  y <- matrix(c(0, 1, 0, 1), nrow = 1L)
  effort <- matrix(7, nrow = 1L, ncol = 4L)
  context <- matrix("same", nrow = 1L, ncol = 4L)
  strata <- goal012_timing_strata(y, effort, context)
  eligible <- matrix(TRUE, nrow = 1L, ncol = 3L)
  within <- c(TRUE, FALSE, TRUE)
  expected <- goal012_expected_timing(y, strata, eligible, "sp", within)
  allocations <- combn(strata$indices[[1L]], 2L, simplify = FALSE)
  observed <- vapply(allocations, function(chosen) {
    draw <- matrix(0, 1L, 4L)
    draw[chosen] <- 1
    goal012_timing_statistics(draw, eligible, "sp", within)["switches_all"]
  }, numeric(1L))
  observed_positive <- vapply(allocations, function(chosen) {
    draw <- matrix(0, 1L, 4L)
    draw[chosen] <- 1
    goal012_timing_statistics(draw, eligible, "sp", within)["positive_pairs_all"]
  }, numeric(1L))
  observed_within <- vapply(allocations, function(chosen) {
    draw <- matrix(0, 1L, 4L)
    draw[chosen] <- 1
    goal012_timing_statistics(draw, eligible, "sp", within)["switches_within_block"]
  }, numeric(1L))
  testthat::expect_equal(unname(expected["switches_all"]), mean(observed),
                         tolerance = 1e-12)
  testthat::expect_equal(unname(expected["positive_pairs_all"]), mean(observed_positive),
                         tolerance = 1e-12)
  testthat::expect_equal(unname(expected["switches_within_block"]), mean(observed_within),
                         tolerance = 1e-12)
  testthat::expect_equal(unname(expected["species:sp"]), mean(observed),
                         tolerance = 1e-12)
})

testthat::test_that("independent strata and eligibility masks are represented exactly", {
  y <- matrix(c(0, 1, 1, 0), nrow = 1L)
  effort <- matrix(7, nrow = 1L, ncol = 4L)
  context <- matrix(c("left", "left", "right", "right"), nrow = 1L)
  strata <- goal012_timing_strata(y, effort, context)
  eligible <- matrix(c(TRUE, TRUE, FALSE), nrow = 1L)
  within <- c(TRUE, FALSE, TRUE)
  expected <- goal012_expected_timing(y, strata, eligible, "sp", within)
  # Enumerate all independent one-detection allocations in the two strata.
  allocations <- expand.grid(strata$indices[[1L]], strata$indices[[2L]])
  observed <- t(vapply(seq_len(nrow(allocations)), function(i) {
    draw <- matrix(0, nrow = 1L, ncol = 4L)
    draw[c(allocations[i, 1L], allocations[i, 2L])] <- 1
    goal012_timing_statistics(draw, eligible, "sp", within)
  }, numeric(length(expected))))
  testthat::expect_equal(unname(colMeans(observed)), unname(expected),
                         tolerance = 1e-12)
  testthat::expect_error(
    goal012_timing_statistics(y, matrix(c(TRUE, NA, FALSE), 1L, 3L),
                              "sp", within),
    "eligible cannot contain NA"
  )
})
