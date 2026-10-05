testthat::test_that("count PMF matches enumeration including deterministic members", {
  p <- c(0, .2, .7, 1)
  patterns <- as.matrix(expand.grid(rep(list(0:1), 4)))
  probs <- apply(patterns, 1, function(y) prod(ifelse(y == 1, p, 1 - p)))
  exact <- vapply(0:4, function(k) sum(probs[rowSums(patterns) == k]), 0)
  testthat::expect_equal(goal013_count_pmf(p), exact)
  testthat::expect_equal(goal013_count_pmf(numeric()), 1)
  testthat::expect_equal(goal013_score_events(numeric(), integer())$covered90, TRUE)
})

testthat::test_that("selection preserves static compatibility, ties and failures", {
  s <- c(static = -10, harmonic = -9, array = -9, station = -9)
  testthat::expect_identical(goal013_select(s, rep(TRUE, 4)), "static_compatible")
  s["array"] <- -5
  testthat::expect_identical(goal013_select(s, rep(TRUE, 4)), "array")
  s["station"] <- -6
  testthat::expect_identical(goal013_select(s, rep(TRUE, 4)), "unresolved")
  testthat::expect_identical(goal013_select(s, c(TRUE, FALSE, TRUE, TRUE)), "numerical_failure")
})
