testthat::test_that("the compact Goal002R workflow produces a valid summary", {
  testthat::skip_if_not(
    requireNamespace("cmdstanr", quietly = TRUE),
    message = "cmdstanr is unavailable"
  )
  status <- check_goal002_cmdstan(error = FALSE)
  testthat::skip_if_not(
    isTRUE(status$matches),
    message = "required CmdStan is unavailable"
  )

  fit <- goal002r_fit(
    goal002r_toy_data(),
    seed = 220020903L,
    sampler = goal002r_default_sampler(
      iter_warmup = 200L,
      iter_sampling = 200L,
      chains = 2L,
      parallel_chains = 2L
    ),
    quadrature_order = 16L,
    output_dir = tempfile("goal002r-fit-")
  )
  summary <- goal002r_summarise_fit(fit)

  testthat::expect_true(validate_goal002r_summary(summary))
  testthat::expect_true(all(summary$richness$pmf$richness %in% 2:4))
  testthat::expect_equal(
    sum(summary$richness$pmf$probability),
    1,
    tolerance = 1e-12
  )
  testthat::expect_true(all(fit$draws[, "S_grid"] ==
    trunc(fit$draws[, "S_grid"])))
  testthat::expect_equal(
    unname(fit$draws[, "expected_richness"]),
    unname(2 + 2 * fit$draws[, "q_unseen"]),
    tolerance = 1e-10
  )
  reconstructed_q <- vapply(
    seq_len(nrow(fit$draws)),
    function(i) goal002r_q_unseen(
      fit$draws[i, "omega"],
      fit$draws[i, "log_m0"]
    ),
    numeric(1)
  )
  testthat::expect_equal(
    reconstructed_q,
    as.numeric(fit$draws[, "q_unseen"]),
    tolerance = 1e-10
  )
})
