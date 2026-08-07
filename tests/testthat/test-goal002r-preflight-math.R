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

testthat::test_that("exposure reduction preserves the row-wise calculation", {
  checks <- goal002r_preflight_algebra_checks()
  testthat::expect_identical(nrow(checks), 4L)
  testthat::expect_true(all(checks$passed))
  testthat::expect_lte(max(checks$absolute_error), 1e-12)
})
