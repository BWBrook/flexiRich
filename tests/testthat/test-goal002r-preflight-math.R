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
  testthat::expect_identical(contract$mode_initial_bound, 1)
  testthat::expect_identical(contract$mode_max_expansions, 64L)
  testthat::expect_identical(contract$tail_initial_scales, 8)
  testthat::expect_identical(contract$tail_max_expansions, 20L)
  testthat::expect_identical(contract$tail_relative_bound, 1e-14)
  testthat::expect_identical(contract$tail_stability, 1e-9)
  testthat::expect_identical(contract$richardson_max_halvings, 8L)
  testthat::expect_identical(contract$richardson_convergence, 2.5e-6)
  testthat::expect_identical(contract$reference_relative_slope, 1e-10)
  testthat::expect_identical(contract$reference_scaled_uncertainty, 1e-4)
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

testthat::test_that("adaptive references agree at both locked tolerances", {
  states <- tibble::tribble(
    ~a, ~sigma_alpha,
    -8, 0,
    -8, 5.5,
     0, 2.75,
    10, 0,
    10, 5.5
  )
  for (index in seq_len(nrow(states))) {
    result <- goal002r_preflight_reference_pair(
      states$a[index],
      states$sigma_alpha[index]
    )
    testthat::expect_true(all(is.finite(result)))
    testthat::expect_lte(
      max(result[c(
        "value_agreement",
        "derivative_a_agreement",
        "derivative_sigma_agreement"
      )]),
      1e-8
    )
  }
})

testthat::test_that("adaptive reference remains anchored near zero sigma", {
  result <- goal002r_preflight_reference(10, 1e-5, 1e-12)
  testthat::expect_true(all(is.finite(result)))
})

testthat::test_that("whole-line oracle matches frozen difficult states", {
  sentinel <- goal002r_preflight_reference_pair(10, 5.5 / 60)
  testthat::expect_equal(
    sentinel[c("log_m0", "derivative_a", "derivative_sigma")],
    c(
      log_m0 = -1351.413795,
      derivative_a = -460.412146,
      derivative_sigma = 19422.772652
    ),
    tolerance = 5e-6
  )
  half_kernel <- goal002r_preflight_reference_pair(10, 0.55)
  testthat::expect_true(all(is.finite(half_kernel)))
  for (result in list(sentinel, half_kernel)) {
    testthat::expect_lte(result[["value_agreement"]], 1e-8)
    testthat::expect_true(result[["derivative_a_mixed_pass"]] == 1)
    testthat::expect_true(result[["derivative_sigma_mixed_pass"]] == 1)
    testthat::expect_true(result[["scaled_reference_a_pass"]] == 1)
    testthat::expect_true(result[["scaled_reference_sigma_pass"]] == 1)
    testthat::expect_lte(
      result[["maximum_tail_relative_bound"]],
      1e-14
    )
    testthat::expect_lte(result[["maximum_expansion_change"]], 1e-9)
  }

  zero <- goal002r_preflight_reference_pair(10, 0)
  testthat::expect_equal(
    zero[c("log_m0", "derivative_a", "derivative_sigma")],
    c(log_m0 = -exp(10), derivative_a = -exp(10), derivative_sigma = 0),
    tolerance = 0
  )
})

testthat::test_that("reference derivatives pass repaired diagnostics", {
  states <- tibble::tribble(
    ~a, ~sigma_alpha,
    -8, 5.5,
     0, 2.75,
    10, 5.5,
    10, 0,
    10.0, 5.5 / 60,
     9.7, 5.5 / 60,
     9.4, 5.5 / 60,
     9.1, 5.5 / 60,
     8.8, 5.5 / 60
  )
  checks <- goal002r_preflight_derivative_checks(states)
  testthat::expect_identical(nrow(checks), 18L)
  testthat::expect_true(all(c(
    "observed", "threshold", "refinements", "converged", "passed"
  ) %in% names(checks)))
  testthat::expect_true(all(checks$passed))
  testthat::expect_lte(max(checks$absolute_error), 1e-5)
  boundary <- checks[
    checks$a == 10 & checks$sigma_alpha == 0 &
      checks$parameter == "sigma_alpha",
  ]
  testthat::expect_identical(boundary$method, "exact_evenness")
  testthat::expect_identical(boundary$analytic, 0)
  testthat::expect_lte(boundary$observed, 1e-12)
  positive <- checks[checks$sigma_alpha > 0, ]
  testthat::expect_true(all(positive$method == "richardson"))
  testthat::expect_true(all(positive$refinements <= 8L))
  testthat::expect_true(all(positive$converged))
})

testthat::test_that("narrow oracle intervals force certified expansion", {
  default <- .goal002r_preflight_reference_core(10, 5.5 / 60, 1e-12)
  narrow <- .goal002r_preflight_reference_core(
    10,
    5.5 / 60,
    1e-12,
    initial_scales = 2
  )
  testthat::expect_gt(attr(narrow, "tail_expansions"), 1L)
  testthat::expect_lte(attr(narrow, "tail_relative_bound"), 1e-14)
  testthat::expect_equal(
    as.numeric(narrow),
    as.numeric(default),
    tolerance = 1e-9
  )
})

testthat::test_that("reference precheck freezes states and criteria", {
  states <- .goal002r_preflight_reference_states()
  testthat::expect_identical(nrow(states), 3726L)
  testthat::expect_true(all(c(1e-2, 1e-3, 1e-4, 1e-5, 1e-6) %in%
    states$sigma_alpha[states$a == 10]))
  testthat::expect_identical(nrow(dplyr::distinct(states)), 3726L)

  pair <- goal002r_preflight_reference_pair(10, 0.55)
  passing <- .goal002r_preflight_reference_precheck_row(10, 0.55, pair)
  testthat::expect_identical(passing$passed, TRUE)
  failing_pair <- pair
  failing_pair[["value_agreement"]] <- 1.1e-8
  failing <- .goal002r_preflight_reference_precheck_row(
    10,
    0.55,
    failing_pair
  )
  testthat::expect_identical(failing$passed, FALSE)
  failure <- .goal002r_preflight_first_reference_failure(failing)
  testthat::expect_identical(failure$criterion, "delta_value")
  testthat::expect_identical(failure$observed, 1.1e-8)
  testthat::expect_identical(failure$threshold, 1e-8)
})
