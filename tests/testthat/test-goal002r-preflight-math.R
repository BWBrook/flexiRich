testthat::test_that("decision-scale preflight contract is frozen", {
  contract <- goal002r_preflight_contract()
  testthat::expect_identical(contract$orders, c(256L, 512L))
  testthat::expect_identical(contract$a_bounds, c(-8, 10))
  testthat::expect_identical(contract$sigma_bounds, c(0, 5.5))
  testthat::expect_identical(contract$grid_size, 61L)
  testthat::expect_identical(contract$max_unseen, 29L)
  testthat::expect_identical(contract$search_starts, 12L)
  testthat::expect_identical(
    contract$reference_tolerances,
    c(1e-10, 1e-12)
  )
  testthat::expect_identical(contract$value_gate, 5e-4)
  testthat::expect_identical(contract$gradient_max_gate, 1e-2)
  testthat::expect_identical(contract$gradient_rms_gate, 1e-3)
  testthat::expect_identical(contract$selection_headroom, 0.5)
})

testthat::test_that("high-order rules retain finite log weights and moments", {
  expected <- c(`0` = 1, `2` = 1, `4` = 3, `6` = 15, `8` = 105, `10` = 945)
  for (order in c(256L, 512L)) {
    rule <- goal002r_preflight_rule(order)
    testthat::expect_identical(nrow(rule), order)
    testthat::expect_true(all(is.finite(rule$node)))
    testthat::expect_true(all(is.finite(rule$log_weight)))
    testthat::expect_lt(max(abs(rule$node + rev(rule$node))), 5e-10)
    testthat::expect_lt(
      max(abs(rule$log_weight - rev(rule$log_weight))),
      5e-10
    )
    weights <- exp(rule$log_weight)
    moments <- vapply(
      as.integer(names(expected)),
      function(power) sum(weights * rule$node^power),
      numeric(1)
    )
    testthat::expect_equal(moments, unname(expected), tolerance = 1e-11)
  }
})

testthat::test_that("preflight order interfaces reject non-fixed orders", {
  rule <- goal002r_preflight_rule(256L)
  testthat::expect_error(
    goal002r_preflight_rule(256.5),
    "Preflight order must be exactly 256 or 512"
  )
  testthat::expect_error(
    goal002r_preflight_rule(128L),
    "Preflight order must be exactly 256 or 512"
  )
  testthat::expect_error(
    goal002r_preflight_rule_checks(rule, 256.5),
    "Preflight order must be exactly 256 or 512"
  )
  testthat::expect_error(
    goal002r_preflight_rule_checks(rule, 128L),
    "Preflight order must be exactly 256 or 512"
  )
})

testthat::test_that("rule checks report the frozen diagnostics for both orders", {
  for (order in c(256L, 512L)) {
    checks <- goal002r_preflight_rule_checks(
      goal002r_preflight_rule(order),
      order
    )
    testthat::expect_identical(
      names(checks),
      c("order", "check", "observed", "threshold", "passed")
    )
    testthat::expect_identical(nrow(checks), 9L)
    testthat::expect_identical(checks$order, rep(order, 9L))
    testthat::expect_true(all(checks$passed))
  }
})

testthat::test_that("fixed rule returns value and primitive derivatives", {
  rule <- goal002r_preflight_rule(256L)
  deterministic <- goal002r_preflight_gh(
    a = log(0.2),
    sigma_alpha = 0,
    rule = rule
  )
  testthat::expect_equal(
    deterministic,
    c(log_m0 = -0.2, derivative_a = -0.2, derivative_sigma = 0),
    tolerance = 1e-14
  )

  shifted <- goal002r_preflight_gh(
    a = 2,
    sigma_alpha = 4,
    rule = rule
  )
  testthat::expect_true(all(is.finite(shifted)))
  testthat::expect_lte(shifted[["log_m0"]], 0)
})

testthat::test_that("primitive evaluator enforces its protected rectangle", {
  rule <- goal002r_preflight_rule(256L)
  for (a in c(-8, 10)) {
    for (sigma_alpha in c(0, 5.5)) {
      result <- goal002r_preflight_gh(a, sigma_alpha, rule)
      testthat::expect_true(all(is.finite(result)))
    }
  }
  testthat::expect_error(goal002r_preflight_gh(-8.000001, 1, rule))
  testthat::expect_error(goal002r_preflight_gh(10.000001, 1, rule))
  testthat::expect_error(goal002r_preflight_gh(1, -0.000001, rule))
  testthat::expect_error(goal002r_preflight_gh(1, 5.500001, rule))
})

testthat::test_that("positive-sigma primitive derivatives match finite differences", {
  contract <- goal002r_preflight_contract()
  cases <- tibble::tribble(
    ~order, ~a,  ~sigma_alpha,
    256L,   -7.5, 0.01,
    256L,    1,   2.75,
    256L,    9.5, 5.49,
    512L,   -7.5, 0.01,
    512L,    1,   2.75,
    512L,    9.5, 5.49
  )
  step <- 1e-5
  for (index in seq_len(nrow(cases))) {
    rule <- goal002r_preflight_rule(cases$order[index])
    estimate <- goal002r_preflight_gh(
      cases$a[index],
      cases$sigma_alpha[index],
      rule
    )
    derivative_a <- (
      goal002r_preflight_gh(
        cases$a[index] + step, cases$sigma_alpha[index], rule
      )[["log_m0"]] -
        goal002r_preflight_gh(
          cases$a[index] - step, cases$sigma_alpha[index], rule
        )[["log_m0"]]
    ) / (2 * step)
    derivative_sigma <- (
      goal002r_preflight_gh(
        cases$a[index], cases$sigma_alpha[index] + step, rule
      )[["log_m0"]] -
        goal002r_preflight_gh(
          cases$a[index], cases$sigma_alpha[index] - step, rule
        )[["log_m0"]]
    ) / (2 * step)
    testthat::expect_equal(
      estimate[["derivative_a"]], derivative_a,
      tolerance = contract$finite_difference_tolerance
    )
    testthat::expect_equal(
      estimate[["derivative_sigma"]], derivative_sigma,
      tolerance = contract$finite_difference_tolerance
    )
  }
})

testthat::test_that("exposure reduction preserves the row-wise calculation", {
  checks <- goal002r_preflight_algebra_checks()
  testthat::expect_identical(nrow(checks), 4L)
  testthat::expect_true(all(checks$passed))
  testthat::expect_lte(max(checks$absolute_error), 1e-12)
})
