.goal003_sampler_test_profile <- function() {
  list(
    chains = 1L,
    parallel_chains = 1L,
    iter_warmup = 10L,
    iter_sampling = 5L,
    adapt_delta = 0.9,
    max_treedepth = 12L
  )
}

.goal003_sampler_test_thresholds <- function() {
  list(
    max_divergences = 0L,
    max_treedepth_hits = 0L,
    min_ebfmi = 0.3,
    max_rhat = 1.01,
    min_bulk_ess = 400,
    min_tail_ess = 400
  )
}

.goal003_sampler_test_summary <- function() {
  tibble::tibble(
    variable = c("theta", "alpha[1]"),
    rhat = c(1.01, 1.001),
    ess_bulk = c(400, 800),
    ess_tail = c(400, 700)
  )
}

.goal003_sampler_test_draws <- function() {
  tibble::tibble(
    divergent__ = rep(0, 8L),
    treedepth__ = rep(5, 8L),
    energy__ = c(1, 2, 1, 3, 2, 4, 2, 5),
    .chain = rep(1L, 8L),
    .iteration = seq_len(8L)
  )
}

testthat::test_that("shared diagnostics enforce every frozen boundary", {
  summary <- .goal003_sampler_test_summary()
  sampler <- .goal003_sampler_test_draws()
  profile <- .goal003_sampler_test_profile()
  thresholds <- .goal003_sampler_test_thresholds()
  reference <- classify_goal003_diagnostics(
    summary,
    sampler,
    profile,
    thresholds
  )

  testthat::expect_true(reference$clean)
  testthat::expect_equal(reference$metrics$max_rhat, 1.01)
  testthat::expect_equal(reference$metrics$min_bulk_ess, 400)
  testthat::expect_equal(reference$metrics$min_tail_ess, 400)

  cases <- list(
    divergences = function(x) {
      x$sampler$divergent__[[1L]] <- 1
      x
    },
    treedepth = function(x) {
      x$sampler$treedepth__[[1L]] <- profile$max_treedepth
      x
    },
    ebfmi = function(x) {
      x$sampler$energy__ <- seq_len(nrow(x$sampler))
      x
    },
    rhat = function(x) {
      x$summary$rhat[[1L]] <- thresholds$max_rhat + 0.001
      x
    },
    bulk = function(x) {
      x$summary$ess_bulk[[1L]] <- thresholds$min_bulk_ess - 1
      x
    },
    tail = function(x) {
      x$summary$ess_tail[[1L]] <- thresholds$min_tail_ess - 1
      x
    }
  )
  for (case in names(cases)) {
    broken <- cases[[case]](list(summary = summary, sampler = sampler))
    classified <- classify_goal003_diagnostics(
      broken$summary,
      broken$sampler,
      profile,
      thresholds
    )
    testthat::expect_false(classified$clean, info = case)
    testthat::expect_true(length(classified$reasons) > 0L, info = case)
  }
})

testthat::test_that("shared diagnostics fail closed on malformed evidence", {
  summary <- .goal003_sampler_test_summary()
  sampler <- .goal003_sampler_test_draws()
  profile <- .goal003_sampler_test_profile()
  thresholds <- .goal003_sampler_test_thresholds()

  missing <- classify_goal003_diagnostics(
    summary[, setdiff(names(summary), "rhat")],
    sampler,
    profile,
    thresholds
  )
  nonfinite <- summary
  nonfinite$ess_tail[[1L]] <- NA_real_
  nonfinite <- classify_goal003_diagnostics(
    nonfinite,
    sampler,
    profile,
    thresholds
  )
  malformed_sampler <- classify_goal003_diagnostics(
    summary,
    sampler[, setdiff(names(sampler), "energy__")],
    profile,
    thresholds
  )

  testthat::expect_false(missing$clean)
  testthat::expect_false(nonfinite$clean)
  testthat::expect_false(malformed_sampler$clean)
})

testthat::test_that("fit diagnostics monitor the caller-supplied variables", {
  requested <- NULL
  fit <- list(
    summary = function(variables) {
      requested <<- variables
      .goal003_sampler_test_summary()
    },
    sampler_diagnostics = function(...) {
      .goal003_sampler_test_draws()
    }
  )
  monitored <- c("theta", "alpha")
  out <- .goal003_fit_diagnostics(
    fit,
    .goal003_sampler_test_profile(),
    monitored,
    .goal003_sampler_test_thresholds()
  )

  testthat::expect_identical(requested, monitored)
  testthat::expect_true(out$clean)
})

testthat::test_that("terminal status allows only one rescue", {
  attempt <- function(clean) {
    list(diagnostics = list(clean = clean))
  }

  testthat::expect_identical(
    .goal003_terminal_status(attempt(TRUE), NULL),
    "primary_clean"
  )
  testthat::expect_identical(
    .goal003_terminal_status(attempt(FALSE), attempt(TRUE)),
    "rescue_clean"
  )
  testthat::expect_identical(
    .goal003_terminal_status(attempt(FALSE), attempt(FALSE)),
    "final_nonclean"
  )
  testthat::expect_identical(
    .goal003_terminal_status(attempt(FALSE), NULL),
    "final_nonclean"
  )
})
