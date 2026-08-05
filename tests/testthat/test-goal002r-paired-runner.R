testthat::test_that("paired comparison cases preserve the approved design", {
  cases <- goal002r_paired_cases()

  testthat::expect_identical(
    cases$case_id,
    c(
      "small-easy",
      "small-unseen",
      "standard-short-low",
      "standard-short-high",
      "standard-long-medium",
      "historical-hard"
    )
  )
  testthat::expect_identical(cases$candidate_pool_size, c(8L, 8L, 30L, 30L, 30L, 30L))
  testthat::expect_identical(cases$true_richness, c(4L, 6L, 8L, 27L, 20L, 20L))
  testthat::expect_identical(cases$n_cameras, c(3L, 3L, 9L, 9L, 9L, 9L))
  testthat::expect_identical(cases$n_occasions, c(52L, 13L, 26L, 26L, 208L, 208L))
  testthat::expect_identical(
    cases$simulation_seed,
    c(940001L, 940006L, 940003L, 940004L, 940005L, 320020503L)
  )
  testthat::expect_identical(
    cases$baseline_fit_seed,
    c(240001L, 240002L, 240003L, 240004L, 240005L, 520020503L)
  )
  testthat::expect_identical(
    cases$collapsed_fit_seed,
    c(250001L, 250002L, 250003L, 250004L, 250005L, 720020503L)
  )
  testthat::expect_identical(
    cases$prior_key,
    c(rep("primary", 5L), "sensitivity_membership")
  )
  testthat::expect_identical(
    cases$historical_stress,
    c(rep(FALSE, 5L), TRUE)
  )
  testthat::expect_equal(cases$sd_log_rate[1:2], c(0.8, 0.8))
  testthat::expect_equal(cases$sd_camera[1:2], c(0.25, 0.25))
})

testthat::test_that("paired cases derive both paths from identical canonical data", {
  cases <- goal002r_paired_cases()
  prepared <- lapply(seq_len(nrow(cases)), function(index) {
    goal002r_prepare_paired_case(cases[index, , drop = FALSE])
  })

  testthat::expect_true(all(vapply(
    prepared,
    function(case) case$simulation$truth$observed_richness > 0L,
    logical(1)
  )))
  testthat::expect_true(all(vapply(
    prepared,
    function(case) identical(
      case$data$data_hash,
      case$collapsed_data$source_data_hash
    ),
    logical(1)
  )))
  testthat::expect_true(all(vapply(
    prepared,
    function(case) identical(
      case$data$candidate_ids,
      case$collapsed_data$candidate_ids
    ),
    logical(1)
  )))
})

testthat::test_that("collapsed path permits exactly one prespecified rescue", {
  prepared <- goal002r_prepare_paired_case(
    goal002r_paired_cases()[1L, , drop = FALSE]
  )
  calls <- list()
  fake_fit <- function(data, seed, prior_profile, sampler, quadrature_order,
                       project_root, output_dir, force_recompile,
                       health_thresholds) {
    calls[[length(calls) + 1L]] <<- list(
      seed = seed,
      sampler = sampler,
      quadrature_order = quadrature_order,
      thresholds = health_thresholds
    )
    if (length(calls) == 1L) {
      stop("primary sampler-health failure", call. = FALSE)
    }
    structure(
      list(draws = matrix(1, nrow = 4L, ncol = 1L)),
      class = c("flexirich_g_collapsed_fit", "list")
    )
  }

  result <- goal002r_run_collapsed_path(
    prepared$collapsed_data,
    seed = 250001L,
    prior_profile = goal002_prior_profiles()$primary,
    output_dir = tempfile("goal002r-collapsed-path-"),
    fit_function = fake_fit
  )

  testthat::expect_identical(result$terminal_status, "rescue_clean")
  testthat::expect_false(result$primary_clean)
  testthat::expect_true(result$terminal_clean)
  testthat::expect_true(result$rescue_used)
  testthat::expect_identical(vapply(calls, `[[`, integer(1), "seed"), c(250001L, 750001L))
  testthat::expect_equal(calls[[1L]]$sampler$adapt_delta, 0.9)
  testthat::expect_equal(calls[[2L]]$sampler$adapt_delta, 0.99)
  testthat::expect_identical(calls[[1L]]$quadrature_order, 128L)
  testthat::expect_identical(
    calls[[1L]]$thresholds,
    goal002r_default_health_thresholds(
      max_divergences = 0L,
      max_treedepth_hits = 0L,
      min_ebfmi = 0.3,
      max_rhat = 1.01,
      min_bulk_ess = 400,
      min_tail_ess = 400
    )
  )
})

testthat::test_that("baseline path delegates its single rescue to Goal 002", {
  prepared <- goal002r_prepare_paired_case(
    goal002r_paired_cases()[1L, , drop = FALSE]
  )
  call <- NULL
  fake_fit <- function(data, seed, prior_profile, output_dir, allow_rescue) {
    call <<- list(
      data_hash = data$data_hash,
      seed = seed,
      prior_profile = prior_profile,
      output_dir = output_dir,
      allow_rescue = allow_rescue
    )
    list(
      terminal_status = "rescue_clean",
      rescue_used = TRUE,
      attempts = list(
        primary = list(clean = FALSE, elapsed_seconds = 12),
        rescue = list(clean = TRUE, elapsed_seconds = 18)
      ),
      draws = matrix(1, nrow = 4L, ncol = 1L)
    )
  }

  result <- goal002r_run_baseline_path(
    prepared$data,
    seed = 240001L,
    prior_profile = goal002_prior_profiles()$primary,
    output_dir = tempfile("goal002r-baseline-path-"),
    fit_function = fake_fit
  )

  testthat::expect_identical(call$data_hash, prepared$data$data_hash)
  testthat::expect_identical(call$seed, 240001L)
  testthat::expect_true(call$allow_rescue)
  testthat::expect_identical(result$terminal_status, "rescue_clean")
  testthat::expect_false(result$primary_clean)
  testthat::expect_true(result$terminal_clean)
  testthat::expect_true(result$rescue_used)
  testthat::expect_equal(result$primary_seconds, 12)
  testthat::expect_identical(result$terminal_fit$draws, matrix(1, 4L, 1L))
})

testthat::test_that("Goal 002 baseline fits accept the Goal 002R evidence root", {
  output_dir <- file.path(
    goal002r_project_root(),
    "outputs",
    "goal002r",
    "paired-comparison",
    paste0("test-baseline-", Sys.getpid())
  )

  testthat::expect_identical(
    .goal002_output_directory(output_dir),
    normalizePath(output_dir, mustWork = FALSE)
  )
})

testthat::test_that("case results expose paired data and geometry evidence", {
  prepared <- goal002r_prepare_paired_case(
    goal002r_paired_cases()[1L, , drop = FALSE]
  )
  baseline <- list(
    terminal_status = "primary_clean",
    primary_clean = TRUE,
    terminal_clean = TRUE,
    rescue_used = FALSE,
    primary_seconds = 10,
    terminal_fit = list(
      terminal_attempt_id = "primary",
      attempts = list(primary = list(diagnostics = list(metrics = list(
        divergences = 0,
        treedepth_hits = 0,
        min_ebfmi = 0.8,
        max_rhat = 1.001,
        min_bulk_ess = 900,
        min_tail_ess = 850
      ))))
    ),
    attempts = list(primary = list(error = NULL))
  )
  collapsed <- list(
    terminal_status = "rescue_clean",
    primary_clean = FALSE,
    terminal_clean = TRUE,
    rescue_used = TRUE,
    primary_seconds = 12,
    terminal_fit = list(health = list(metrics = list(
      divergences = 0,
      treedepth_hits = 0,
      min_ebfmi = 0.7,
      max_rhat = 1.002,
      min_bulk_ess = 800,
      min_tail_ess = 750
    ))),
    attempts = list(
      primary = list(error = "sampler-health failure"),
      rescue = list(error = NULL)
    )
  )

  result <- goal002r_paired_case_result(prepared, baseline, collapsed)

  testthat::expect_identical(result$case_id, "small-easy")
  testthat::expect_identical(result$camera_count, 3L)
  testthat::expect_identical(result$observed_richness, 4L)
  testthat::expect_identical(result$baseline_data_hash, result$collapsed_source_data_hash)
  testthat::expect_true(result$data_hash_identical)
  testthat::expect_true(result$supported)
  testthat::expect_true(result$baseline_primary_clean)
  testthat::expect_false(result$collapsed_primary_clean)
  testthat::expect_true(result$collapsed_terminal_clean)
  testthat::expect_identical(result$collapsed_primary_error, "sampler-health failure")
  testthat::expect_equal(result$baseline_primary_seconds, 10)
  testthat::expect_equal(result$collapsed_primary_seconds, 12)
  testthat::expect_equal(result$baseline_max_rhat, 1.001)
  testthat::expect_equal(result$collapsed_max_rhat, 1.002)
  testthat::expect_equal(result$baseline_min_tail_ess, 850)
  testthat::expect_equal(result$collapsed_min_tail_ess, 750)
})

testthat::test_that("clean pair evidence carries PMF and parameter decisions", {
  pmf <- tibble::tibble(
    richness = 0:2,
    probability = c(0.1, 0.6, 0.3)
  )
  x <- rep(c(-0.1, 0.1), 100)
  draws <- posterior::as_draws_matrix(cbind(
    omega = 0.5 + x,
    mu_alpha = -6 + x,
    sigma_alpha = 1 + x,
    sigma_camera = 0.3 + x / 10,
    `camera_effect[1]` = x,
    `camera_effect[2]` = -x
  ))

  result <- goal002r_compare_clean_pair(
    case_id = "small-easy",
    candidate_pool_size = 2L,
    camera_count = 2L,
    baseline_pmf = pmf,
    collapsed_pmf = pmf,
    baseline_draws = draws,
    collapsed_draws = draws
  )

  testthat::expect_identical(result$pmf$case_id, "small-easy")
  testthat::expect_true(result$pmf$support_valid)
  testthat::expect_true(result$pmf$passed)
  testthat::expect_identical(unique(result$parameters$case_id), "small-easy")
  testthat::expect_true(all(result$parameters$passed))
})

testthat::test_that("quadrature checks use 25 evenly spaced posterior draws", {
  prepared <- goal002r_prepare_paired_case(
    goal002r_paired_cases()[1L, , drop = FALSE]
  )
  n_draws <- 40L
  draws <- cbind(
    mu_alpha = seq(log(0.0008), log(0.0012), length.out = n_draws),
    sigma_alpha = seq(0.7, 0.9, length.out = n_draws),
    `camera_effect[1]` = rep(-0.1, n_draws),
    `camera_effect[2]` = rep(0, n_draws),
    `camera_effect[3]` = rep(0.1, n_draws)
  )
  fit <- list(draws = posterior::as_draws_matrix(draws))

  checks <- goal002r_check_collapsed_quadrature(
    case_id = "small-easy",
    fit = fit,
    data = prepared$collapsed_data
  )

  testthat::expect_identical(checks$draw_index, seq_len(25L))
  testthat::expect_identical(length(unique(checks$posterior_row)), 25L)
  testthat::expect_identical(checks$posterior_row[c(1L, 25L)], c(1L, 40L))
  testthat::expect_true(all(checks$absolute_error <= 1e-8))
  testthat::expect_true(all(checks$passed))
})

testthat::test_that("paired output writer emits only the six contracted files", {
  output_dir <- tempfile("goal002r-paired-output-")
  evidence <- list(
    case_results = tibble::tibble(case_id = "small-easy", supported = TRUE),
    pmf_results = tibble::tibble(case_id = "small-easy", passed = TRUE),
    parameter_results = tibble::tibble(
      case_id = "small-easy",
      parameter = "omega",
      passed = TRUE
    ),
    quadrature_results = tibble::tibble(
      case_id = "small-easy",
      draw_index = 1L,
      passed = TRUE
    ),
    decision = list(
      decision = "REVISE",
      criteria = tibble::tibble(
        criterion = "runtime_acceptable",
        observed = 2.5,
        requirement = "<= 2",
        passed = FALSE
      )
    )
  )

  paths <- goal002r_write_paired_outputs(evidence, output_dir)

  testthat::expect_identical(
    sort(basename(unname(paths))),
    sort(c(
      "case-results.csv",
      "pmf-fidelity.csv",
      "parameter-fidelity.csv",
      "quadrature-checks.csv",
      "decision-criteria.csv",
      "decision.txt"
    ))
  )
  testthat::expect_identical(sort(list.files(output_dir)), sort(basename(unname(paths))))
  testthat::expect_identical(readLines(paths[["decision"]]), "REVISE")
})
