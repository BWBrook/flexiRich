testthat::test_that("Goal002R contract is explicit and small", {
  contract <- goal002r_contract()
  testthat::expect_identical(contract$occasion_days, 7L)
  testthat::expect_identical(
    contract$quadrature_orders,
    c(16L, 32L, 64L, 128L)
  )
  testthat::expect_identical(contract$quadrature_default, 128L)
  testthat::expect_identical(contract$quadrature_reference, 256L)
  testthat::expect_identical(contract$pmf_tolerance, 1e-12)
  testthat::expect_match(contract$stan_file, "flexirich_g_collapsed\\.stan")
  testthat::expect_match(contract$output_root, "^outputs/goal002r$")
  testthat::expect_error(
    goal002r_stan_data(goal002r_toy_data(), quadrature_order = 17L),
    "quadrature_order must be one of",
    fixed = FALSE
  )
})

testthat::test_that("Goal002R reuses only the inherited prior values", {
  prior <- goal002r_default_prior()
  expected <- goal002_prior_profiles()$primary
  testthat::expect_identical(prior, expected)
  testthat::expect_error(
    goal002r_output_path("../outside"),
    "safe relative path",
    fixed = TRUE
  )
})
