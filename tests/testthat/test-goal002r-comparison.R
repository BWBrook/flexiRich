testthat::test_that("PMF alignment fills the full candidate-pool support", {
  baseline <- tibble::tibble(
    richness = c(1L, 3L),
    probability = c(0.25, 0.75)
  )
  collapsed <- tibble::tibble(
    richness = c(2L, 3L),
    probability = c(0.4, 0.6)
  )

  aligned <- goal002r_align_pmf(
    baseline,
    collapsed,
    candidate_pool_size = 3L
  )

  testthat::expect_identical(aligned$richness, 0:3)
  testthat::expect_equal(
    aligned$baseline_probability,
    c(0, 0.25, 0, 0.75)
  )
  testthat::expect_equal(
    aligned$collapsed_probability,
    c(0, 0, 0.4, 0.6)
  )
})

testthat::test_that("PMF alignment rejects invalid probability support", {
  valid <- tibble::tibble(richness = 1:2, probability = c(0.5, 0.5))
  duplicated <- tibble::tibble(
    richness = c(1L, 1L),
    probability = c(0.5, 0.5)
  )
  outside_pool <- tibble::tibble(richness = 1:2, probability = c(0.4, 0.4))

  testthat::expect_error(
    goal002r_align_pmf(duplicated, valid, 2L),
    "baseline.*unique"
  )
  testthat::expect_error(
    goal002r_align_pmf(outside_pool, valid, 2L),
    "baseline.*normalised"
  )
})

testthat::test_that("PMF comparison reports hand-checked fidelity metrics", {
  baseline <- tibble::tibble(
    richness = 0:2,
    probability = c(0.5, 0.5, 0)
  )
  collapsed <- tibble::tibble(
    richness = 0:2,
    probability = c(0.4, 0.5, 0.1)
  )

  comparison <- goal002r_compare_pmf(baseline, collapsed, 2L)

  testthat::expect_equal(comparison$total_variation, 0.1, tolerance = 1e-14)
  testthat::expect_equal(comparison$baseline_mean, 0.5)
  testthat::expect_equal(comparison$collapsed_mean, 0.7)
  testthat::expect_equal(comparison$absolute_mean_difference, 0.2)
  testthat::expect_identical(comparison$absolute_median_difference, 1L)
  testthat::expect_identical(comparison$absolute_lower_90_difference, 0L)
  testthat::expect_identical(comparison$absolute_upper_90_difference, 1L)
  testthat::expect_false(comparison$passed)
})

testthat::test_that("identical PMFs pass every richness fidelity threshold", {
  pmf <- tibble::tibble(
    richness = 1:3,
    probability = c(0.25, 0.5, 0.25)
  )

  comparison <- goal002r_compare_pmf(pmf, pmf, 3L)

  testthat::expect_identical(comparison$passed, TRUE)
  testthat::expect_equal(comparison$total_variation, 0)
  testthat::expect_equal(comparison$absolute_mean_difference, 0)
  testthat::expect_identical(comparison$absolute_median_difference, 0L)
  testthat::expect_identical(comparison$absolute_lower_90_difference, 0L)
  testthat::expect_identical(comparison$absolute_upper_90_difference, 0L)
})

testthat::test_that("identical shared-parameter draws pass fidelity checks", {
  x <- rep(c(-0.1, 0.1), 100)
  draws <- cbind(
    omega = 0.5 + x,
    mu_alpha = -6 + x,
    sigma_alpha = 1 + x,
    sigma_camera = 0.3 + x / 10,
    `camera_effect[1]` = x,
    `camera_effect[2]` = -x
  )

  comparison <- goal002r_compare_shared_draws(draws, draws, camera_count = 2L)

  testthat::expect_identical(
    comparison$parameter,
    c(
      "omega", "mu_alpha", "sigma_alpha", "sigma_camera",
      "camera_effect[1]", "camera_effect[2]"
    )
  )
  testthat::expect_equal(comparison$absolute_mean_difference, rep(0, 6L))
  testthat::expect_true(all(comparison$passed))
})

testthat::test_that("shared-parameter comparison detects a material shift", {
  x <- rep(c(-0.1, 0.1), 100)
  baseline <- cbind(
    omega = 0.5 + x,
    mu_alpha = -6 + x,
    sigma_alpha = 1 + x,
    sigma_camera = 0.3 + x / 10,
    `camera_effect[1]` = x,
    `camera_effect[2]` = -x
  )
  collapsed <- baseline
  collapsed[, "mu_alpha"] <- collapsed[, "mu_alpha"] + 1

  comparison <- goal002r_compare_shared_draws(
    baseline,
    collapsed,
    camera_count = 2L
  )

  testthat::expect_false(comparison$passed[comparison$parameter == "mu_alpha"])
  testthat::expect_true(all(
    comparison$passed[comparison$parameter != "mu_alpha"]
  ))
  testthat::expect_equal(
    comparison$absolute_mean_difference[
      comparison$parameter == "mu_alpha"
    ],
    1
  )
})

testthat::test_that("shared-parameter comparison requires every camera effect", {
  draws <- cbind(
    omega = seq(0.4, 0.6, length.out = 20),
    mu_alpha = seq(-6.1, -5.9, length.out = 20),
    sigma_alpha = seq(0.9, 1.1, length.out = 20),
    sigma_camera = seq(0.2, 0.4, length.out = 20),
    `camera_effect[1]` = seq(-0.1, 0.1, length.out = 20)
  )

  testthat::expect_error(
    goal002r_compare_shared_draws(draws, draws, camera_count = 2L),
    "camera_effect\\[2\\]"
  )
})

testthat::test_that("shared-parameter MCSE preserves posterior chain structure", {
  variables <- c(
    "omega", "mu_alpha", "sigma_alpha", "sigma_camera",
    "camera_effect[1]", "camera_effect[2]"
  )
  values <- array(
    NA_real_,
    dim = c(40L, 4L, length(variables)),
    dimnames = list(NULL, NULL, variables)
  )
  pattern <- sin(seq(0, 4 * pi, length.out = 40L))
  for (chain in seq_len(4L)) {
    values[, chain, ] <- outer(
      pattern + chain / 5,
      seq_along(variables) / 10,
      `+`
    )
  }
  draws <- posterior::as_draws_matrix(posterior::as_draws_array(values))
  expected <- posterior::summarise_draws(
    posterior::subset_draws(draws, variable = "mu_alpha"),
    mcse = posterior::mcse_mean
  )$mcse

  comparison <- goal002r_compare_shared_draws(draws, draws, camera_count = 2L)
  observed <- comparison$baseline_mcse[
    comparison$parameter == "mu_alpha"
  ]

  testthat::expect_equal(observed, expected, tolerance = 1e-14)
})

.goal002r_decision_fixture <- function() {
  case_id <- c(
    "small-easy",
    "small-unseen",
    "standard-short-low",
    "standard-short-high",
    "standard-long-medium",
    "historical-hard"
  )
  camera_count <- c(3L, 3L, 9L, 9L, 9L, 9L)
  paired_case <- seq_len(5L)
  parameter_results <- dplyr::bind_rows(lapply(paired_case, function(index) {
    tibble::tibble(
      case_id = case_id[[index]],
      parameter = c(
        "omega", "mu_alpha", "sigma_alpha", "sigma_camera",
        sprintf("camera_effect[%d]", seq_len(camera_count[[index]]))
      ),
      passed = TRUE
    )
  }))
  quadrature_results <- dplyr::bind_rows(lapply(case_id, function(id) {
    tibble::tibble(
      case_id = id,
      draw_index = seq_len(25L),
      passed = TRUE
    )
  }))
  list(
    case_results = tibble::tibble(
      case_id = case_id,
      camera_count = camera_count,
      supported = rep(TRUE, 6L),
      historical_stress = c(rep(FALSE, 5L), TRUE),
      baseline_primary_clean = c(rep(TRUE, 5L), FALSE),
      collapsed_primary_clean = rep(TRUE, 6L),
      baseline_terminal_clean = c(rep(TRUE, 5L), FALSE),
      collapsed_terminal_clean = rep(TRUE, 6L),
      baseline_primary_seconds = rep(10, 6L),
      collapsed_primary_seconds = c(15, 16, 17, 18, 19, 18)
    ),
    pmf_results = tibble::tibble(
      case_id = case_id[paired_case],
      support_valid = TRUE,
      passed = TRUE
    ),
    parameter_results = parameter_results,
    quadrature_results = quadrature_results
  )
}

testthat::test_that("complete passing evidence yields RETAIN", {
  fixture <- .goal002r_decision_fixture()

  result <- goal002r_comparison_decision(
    fixture$case_results,
    fixture$pmf_results,
    fixture$parameter_results,
    fixture$quadrature_results
  )

  testthat::expect_identical(result$decision, "RETAIN")
  testthat::expect_true(all(result$criteria$passed))
  testthat::expect_identical(
    result$criteria$criterion,
    c(
      "all_cases_supported",
      "quadrature_checks",
      "richness_support",
      "pmf_fidelity",
      "shared_parameter_fidelity",
      "collapsed_terminal_clean",
      "historical_stress_clean",
      "primary_geometry_not_worse",
      "terminal_geometry_not_worse",
      "runtime_acceptable"
    )
  )
})

testthat::test_that("posterior mismatch takes REJECT precedence over runtime", {
  fixture <- .goal002r_decision_fixture()
  fixture$pmf_results$passed[[1L]] <- FALSE
  fixture$case_results$collapsed_primary_seconds <- rep(30, 6L)

  result <- goal002r_comparison_decision(
    fixture$case_results,
    fixture$pmf_results,
    fixture$parameter_results,
    fixture$quadrature_results
  )

  testthat::expect_identical(result$decision, "REJECT")
  testthat::expect_false(result$criteria$passed[
    result$criteria$criterion == "pmf_fidelity"
  ])
  testthat::expect_false(result$criteria$passed[
    result$criteria$criterion == "runtime_acceptable"
  ])
})

testthat::test_that("excessive runtime alone yields REVISE", {
  fixture <- .goal002r_decision_fixture()
  fixture$case_results$collapsed_primary_seconds <- rep(25, 6L)

  result <- goal002r_comparison_decision(
    fixture$case_results,
    fixture$pmf_results,
    fixture$parameter_results,
    fixture$quadrature_results
  )

  testthat::expect_identical(result$decision, "REVISE")
  runtime <- result$criteria[
    result$criteria$criterion == "runtime_acceptable",
    ,
    drop = FALSE
  ]
  testthat::expect_equal(runtime$observed, 2.5)
  testthat::expect_false(runtime$passed)
})

testthat::test_that("worse sampling geometry yields REJECT", {
  fixture <- .goal002r_decision_fixture()
  fixture$case_results$collapsed_primary_clean <- rep(FALSE, 6L)
  fixture$case_results$baseline_terminal_clean <- rep(TRUE, 6L)
  fixture$case_results$collapsed_terminal_clean[[6L]] <- FALSE
  fixture$quadrature_results <- fixture$quadrature_results[
    fixture$quadrature_results$case_id != "historical-hard",
  ]

  result <- goal002r_comparison_decision(
    fixture$case_results,
    fixture$pmf_results,
    fixture$parameter_results,
    fixture$quadrature_results
  )

  testthat::expect_identical(result$decision, "REJECT")
  testthat::expect_false(result$criteria$passed[
    result$criteria$criterion == "primary_geometry_not_worse"
  ])
  testthat::expect_false(result$criteria$passed[
    result$criteria$criterion == "terminal_geometry_not_worse"
  ])
})

testthat::test_that("missing prespecified cases yield REVISE", {
  fixture <- .goal002r_decision_fixture()
  omitted <- "standard-long-medium"
  fixture$case_results <- fixture$case_results[
    fixture$case_results$case_id != omitted,
  ]
  fixture$pmf_results <- fixture$pmf_results[
    fixture$pmf_results$case_id != omitted,
  ]
  fixture$parameter_results <- fixture$parameter_results[
    fixture$parameter_results$case_id != omitted,
  ]
  fixture$quadrature_results <- fixture$quadrature_results[
    fixture$quadrature_results$case_id != omitted,
  ]

  result <- goal002r_comparison_decision(
    fixture$case_results,
    fixture$pmf_results,
    fixture$parameter_results,
    fixture$quadrature_results
  )

  testthat::expect_identical(result$decision, "REVISE")
  testthat::expect_false(result$criteria$passed[
    result$criteria$criterion == "all_cases_supported"
  ])
})

testthat::test_that("missing shared parameters yield REVISE", {
  fixture <- .goal002r_decision_fixture()
  keep <- !(
    fixture$parameter_results$case_id == "small-easy" &
      fixture$parameter_results$parameter == "mu_alpha"
  )
  fixture$parameter_results <- fixture$parameter_results[keep, ]

  result <- goal002r_comparison_decision(
    fixture$case_results,
    fixture$pmf_results,
    fixture$parameter_results,
    fixture$quadrature_results
  )

  testthat::expect_identical(result$decision, "REVISE")
  testthat::expect_false(result$criteria$passed[
    result$criteria$criterion == "shared_parameter_fidelity"
  ])
})

testthat::test_that("fewer than 25 quadrature draws yield REVISE", {
  fixture <- .goal002r_decision_fixture()
  fixture$quadrature_results <- fixture$quadrature_results[-1L, ]

  result <- goal002r_comparison_decision(
    fixture$case_results,
    fixture$pmf_results,
    fixture$parameter_results,
    fixture$quadrature_results
  )

  testthat::expect_identical(result$decision, "REVISE")
  testthat::expect_false(result$criteria$passed[
    result$criteria$criterion == "quadrature_checks"
  ])
})
