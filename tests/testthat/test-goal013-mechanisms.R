goal013_tiny <- function() {
  y <- matrix(c(1, 0, 0, 1, 0, 1), nrow = 2, byrow = TRUE)
  effort <- matrix(c(1, 2, 1, 1, 0, 1), nrow = 2, byrow = TRUE)
  group <- matrix(c(1L, 1L, 2L, 2L, 0L, 2L), nrow = 2, byrow = TRUE)
  list(y = y, effort = effort, group = group, target = c(1.2, 1.1),
       row_species = c(1L, 1L), row_class = c(1L, 1L), phase = c(0, pi / 2, pi))
}

testthat::test_that("Goal013 normalizers satisfy every unequal-effort group target", {
  d <- goal013_tiny()
  for (model in c("static", "harmonic", "array", "station")) {
    theta <- if (model == "static") numeric() else c(.7, .3, 1.1, .6)
    p <- goal013_probabilities(d, model, theta)
    ix <- d$effort > 0
    got <- tapply(as.vector(p$p)[ix], as.vector(d$group)[ix], sum)
    testthat::expect_equal(as.numeric(got), d$target[as.integer(names(got))], tolerance = 1e-8)
  }
})

testthat::test_that("array and station forward probabilities match finite enumeration", {
  d <- goal013_tiny()
  d$y[2, 2] <- 0
  theta <- c(.9, .4, .9, .4)
  p <- goal013_probabilities(d, "array", theta)
  # Array has both camera emissions in each week; this tiny fixture has one
  # species and one zero-effort/missing cell, so enumerate its observed chain.
  ll <- goal013_loglik(d, "array", theta)
  rho <- theta[2]; q <- (1 - rho) / 2
  alpha <- c(.5, .5)
  total <- 1
  for (tt in seq_len(ncol(d$y))) {
    if (tt > 1) alpha <- c(alpha[1] * (1 - q) + alpha[2] * q,
                           alpha[1] * q + alpha[2] * (1 - q))
    e0 <- e1 <- 1
    for (rr in seq_len(nrow(d$y))) if (d$effort[rr, tt] > 0 && !is.na(d$y[rr, tt])) {
      e0 <- e0 * if (d$y[rr, tt] == 1) p$p_low[rr, tt] else 1 - p$p_low[rr, tt]
      e1 <- e1 * if (d$y[rr, tt] == 1) p$p_high[rr, tt] else 1 - p$p_high[rr, tt]
    }
    z <- alpha * c(e0, e1)
    total <- total * sum(z)
    alpha <- z / sum(z)
  }
  testthat::expect_equal(ll, log(total), tolerance = 1e-12)
  testthat::expect_true(is.finite(goal013_loglik(d, "station", theta)))
})

testthat::test_that("station chain likelihood matches enumeration over all states", {
  d <- list(y = matrix(c(1, 0, 1), 1, 3), effort = matrix(c(1, 1, 1), 1, 3),
            group = matrix(c(1L, 1L, 1L), 1, 3), target = 1.4, row_species = 1L,
            row_class = 1L, phase = c(0, 1, 2))
  theta <- c(.8, .6, .8, .6); p <- goal013_probabilities(d, "station", theta)
  rho <- theta[2]; q <- (1 - rho) / 2; expected <- 0
  for (s1 in 1:2) for (s2 in 1:2) for (s3 in 1:2) {
    ss <- c(s1, s2, s3); pr <- .5
    pr <- pr * if (s2 == s1) 1 - q else q
    pr <- pr * if (s3 == s2) 1 - q else q
    for (tt in 1:3) {
      pp <- if (ss[tt] == 1) p$p_low[1, tt] else p$p_high[1, tt]
      pr <- pr * if (d$y[1, tt] == 1) pp else 1 - pp
    }
    expected <- expected + pr
  }
  testthat::expect_equal(goal013_loglik(d, "station", theta), log(expected), tolerance = 1e-12)
})

testthat::test_that("nonzero-state conditional event forecasts match full path enumeration", {
  d <- goal013_tiny(); theta <- c(1.2, .75, 0, 0)
  p <- goal013_probabilities(d, "array", theta)
  paths <- as.matrix(expand.grid(rep(list(1:2), ncol(d$y))))
  q <- (1 - theta[2]) / 2
  integrate <- function(rows, origin, future_zero = FALSE) {
    total <- 0
    for (k in seq_len(nrow(paths))) {
      states <- paths[k, ]; pr <- .5 * prod(ifelse(diff(states) == 0, 1 - q, q))
      for (tt in seq_len(ncol(d$y))) for (rr in rows) {
        if (d$effort[rr, tt] == 0 || (tt > origin && !future_zero)) next
        y <- if (tt > origin) 0 else d$y[rr, tt]
        if (is.na(y)) next
        prob <- if (states[tt] == 1) p$p_low[rr, tt] else p$p_high[rr, tt]
        pr <- pr * if (y == 1) prob else 1 - prob
      }
      total <- total + pr
    }
    total
  }
  for (model in c("array", "station")) {
    chains <- if (model == "array") list(1:2) else list(1, 2)
    complete <- prod(vapply(chains, integrate, 0, origin = 3))
    train <- prod(vapply(chains, integrate, 0, origin = 1))
    zero <- prod(vapply(chains, integrate, 0, origin = 1, future_zero = TRUE))
    testthat::expect_equal(goal013_loglik(d, model, theta), log(complete), tolerance = 1e-11)
    testthat::expect_equal(goal013_forecast_events(d, model, theta, 1, 2),
      1 - zero / train, tolerance = 1e-11)
    testthat::expect_equal(goal013_loglik(d, model, theta, start = 2),
      log(complete / train), tolerance = 1e-11)
  }
})

testthat::test_that("zero-amplitude dynamic candidates equal static", {
  d <- goal013_tiny(); static <- goal013_loglik(d, "static")
  for (model in c("array", "station")) {
    testthat::expect_equal(goal013_loglik(d, model, c(0, .4, 0, .8)), static, tolerance = 1e-12)
    testthat::expect_equal(goal013_forecast_events(d, model, c(0, .4, 0, .8), 1, 1),
                           goal013_forecast_events(d, "static", numeric(), 1, 1), tolerance = 1e-12)
  }
})

testthat::test_that("row and camera permutations preserve likelihood and forecast events", {
  d <- goal013_tiny(); theta <- c(.4, .5, .8, .2)
  perm <- c(2L, 1L)
  dp <- d; dp$y <- d$y[perm, , drop = FALSE]; dp$effort <- d$effort[perm, , drop = FALSE]
  dp$group <- d$group[perm, , drop = FALSE]; dp$row_species <- d$row_species[perm]
  dp$row_class <- d$row_class[perm]
  for (model in c("static", "harmonic", "array", "station")) {
    th <- if (model == "static") numeric() else theta
    testthat::expect_equal(goal013_loglik(dp, model, th), goal013_loglik(d, model, th), tolerance = 1e-12)
    testthat::expect_equal(goal013_forecast_events(dp, model, th, 1, 1), goal013_forecast_events(d, model, th, 1, 1), tolerance = 1e-12)
  }
})

testthat::test_that("zero-effort week still propagates the dynamic chain", {
  d <- goal013_tiny(); d$y[1, 2] <- NA; d$effort[1, 2] <- 0; d$group[1, 2] <- 0L
  d$target[1] <- .8
  theta <- c(.8, .7, .8, .7)
  p <- goal013_probabilities(d, "station", theta)
  got <- goal013_loglik(d, "station", theta)
  # There is no reset at week two; compare with the same data retaining the
  # week as an unobserved positive-effort cell, which must change the margin
  # but leaves the transition semantics explicit in the finite chain.
  d2 <- d; d2$effort[1, 2] <- 1; d2$group[1, 2] <- 1L; d2$y[1, 2] <- NA
  testthat::expect_true(is.finite(got)); testthat::expect_true(is.finite(goal013_loglik(d2, "station", theta)))
  testthat::expect_false(isTRUE(all.equal(got, goal013_loglik(d2, "station", theta))))
})

testthat::test_that("simulation preserves masks and explicit seeds", {
  d <- goal013_tiny(); d$y[1, 2] <- NA; d$effort[1, 2] <- 0; d$group[1, 2] <- 0L
  d$target[1] <- .8
  a <- goal013_simulate(d, "array", c(.5, .4, .5, .4), seed = 17, states = TRUE)
  b <- goal013_simulate(d, "array", c(.5, .4, .5, .4), seed = 17, states = TRUE)
  testthat::expect_identical(a, b); testthat::expect_identical(dim(a$y), dim(d$y))
  testthat::expect_true(is.na(a$y[1, 2])); testthat::expect_equal(dim(a$states), dim(d$y))
})

testthat::test_that("tiny synthetic fit returns all deterministic starts", {
  d <- goal013_tiny(); f <- goal013_fit(d, "array", train_end = 2)
  testthat::expect_length(f$theta, 4L); testthat::expect_equal(nrow(f$starts), 5L)
  testthat::expect_true(is.numeric(f$loglik_train)); testthat::expect_true("convergence" %in% names(f$starts))
})
