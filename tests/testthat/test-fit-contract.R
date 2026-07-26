goal002_test_root <- function() {
  if (dir.exists("R") && file.exists("stan/flexirich_g.stan")) {
    return(normalizePath(".", mustWork = TRUE))
  }
  normalizePath(file.path("..", ".."), mustWork = TRUE)
}

goal002_monitored_fixture <- function() {
  c(
    "omega",
    "mu_alpha",
    "sigma_alpha",
    "sigma_camera",
    "alpha[1]",
    "alpha[2]",
    "alpha[3]",
    "alpha[4]",
    "camera_effect[1]",
    "camera_effect[2]",
    "q_member[3]",
    "q_member[4]",
    "expected_richness",
    "richness_lower_tail",
    "richness_upper_tail"
  )
}

goal002_richness_metadata_fixture <- function() {
  list(
    status = "estimated",
    tau = 0.05,
    observed_richness = 2L,
    candidate_pool_size = 4L,
    lower_cutoff = 2L,
    upper_cutoff = 4L,
    mean_lower_mass = 0.06,
    mean_upper_mass = 0.04,
    row_diagnostics = tibble::tibble(
      variable = c(
        "expected_richness",
        "richness_lower_tail",
        "richness_upper_tail"
      ),
      rhat = c(1, 1, 1),
      ess_bulk = c(800, 800, 800),
      ess_tail = c(800, 800, 800)
    ),
    detail = ""
  )
}

goal002_generated_contract_fixture <- function(valid = TRUE) {
  list(
    status = if (valid) "passed" else "failed",
    reasons = if (valid) character() else "q_member_support",
    metrics = list(
      n_draws = 8L,
      candidate_pool_size = 4L,
      observed_richness = 2L,
      max_expected_richness_error = if (valid) 0 else NA_real_
    ),
    details = if (valid) {
      character()
    } else {
      stats::setNames(
        "q_member contains a value outside [0, 1].",
        "q_member_support"
      )
    }
  )
}

goal002_q_draw_fixture <- function(iterations_per_chain = 200L) {
  n_draws <- 4L * iterations_per_chain
  q <- withr::with_seed(
    77002101L,
    cbind(
      rep(1, n_draws),
      rep(1, n_draws),
      stats::rbeta(n_draws, 2, 5),
      stats::rbeta(n_draws, 3, 4)
    )
  )
  colnames(q) <- sprintf("q_member[%d]", 1:4)
  list(
    q = q,
    detected_ever = c(1L, 1L, 0L, 0L),
    chain = rep(1:4, each = iterations_per_chain),
    iteration = rep(
      seq_len(iterations_per_chain),
      times = 4L
    )
  )
}

goal002_diagnostic_fixture <- function(clean = TRUE) {
  variables <- goal002_monitored_fixture()
  iterations <- 1:12
  chains <- rep(1:4, each = length(iterations))
  energy_pattern <- rep(c(0, 1), length.out = length(iterations))

  result <- list(
    summary = list(
      monitored_variables = variables,
      statistics = tibble::tibble(
        variable = variables,
        rhat = rep(1, length(variables)),
        ess_bulk = rep(800, length(variables)),
        ess_tail = rep(800, length(variables))
      ),
      richness = goal002_richness_metadata_fixture()
    ),
    sampler = list(
      expected_chains = 4L,
      max_treedepth = 12L,
      draws = tibble::tibble(
        divergent__ = rep(0L, length(chains)),
        treedepth__ = rep(6L, length(chains)),
        energy__ = rep(energy_pattern, times = 4L),
        .chain = as.integer(chains),
        .iteration = rep(iterations, times = 4L)
      )
    )
  )

  if (!clean) {
    result <- corrupt_goal002_diagnostic(result, "rhat")
  }
  result
}

corrupt_goal002_diagnostic <- function(diagnostics, defect) {
  switch(
    defect,
    divergences = {
      diagnostics$sampler$draws$divergent__[1L] <- 1L
    },
    treedepth = {
      diagnostics$sampler$draws$treedepth__[1L] <-
        diagnostics$sampler$max_treedepth
    },
    ebfmi = {
      first_chain <- diagnostics$sampler$draws$.chain == 1L
      diagnostics$sampler$draws$energy__[first_chain] <- 1
    },
    rhat = {
      diagnostics$summary$statistics$rhat[1L] <- 1.02
    },
    bulk_ess = {
      diagnostics$summary$statistics$ess_bulk[1L] <- 399
    },
    tail_ess = {
      diagnostics$summary$statistics$ess_tail[1L] <- 399
    },
    stop("Unknown diagnostic defect.", call. = FALSE)
  )
  diagnostics
}

goal002_attempt_fixture <- function(
  clean = TRUE,
  attempt_id = "primary"
) {
  diagnostics <- goal002_diagnostic_fixture(clean = clean)
  classified <- classify_goal002_diagnostics(
    diagnostics$summary,
    diagnostics$sampler,
    goal002_diagnostic_thresholds()
  )
  classified$generated_richness <- goal002_generated_contract_fixture(
    valid = TRUE
  )
  classified <- classified[c(
    "clean",
    "reasons",
    "metrics",
    "richness",
    "generated_richness",
    "details"
  )]
  sampler_profile_id <- if (identical(attempt_id, "primary")) {
    "primary-sampler-v1"
  } else {
    "rescue-sampler-v1"
  }

  list(
    attempt_id = attempt_id,
    sampler_profile_id = sampler_profile_id,
    seed = if (identical(attempt_id, "primary")) 72002101L else 72502101L,
    started_at_utc = "2026-07-26T00:00:00Z",
    elapsed_seconds = 1,
    model_source_hash = paste(rep("a", 64L), collapse = ""),
    data_hash = paste(rep("b", 64L), collapse = ""),
    prior_profile = "primary-v1",
    R_version = as.character(getRversion()),
    cmdstanr_version = as.character(utils::packageVersion("cmdstanr")),
    cmdstan_version = "2.38.0",
    compiler = "g++ test compiler",
    output_files = sprintf(
      "outputs/goal002/test/%s/flexirich-g-%d.csv",
      attempt_id,
      1:4
    ),
    diagnostics = classified,
    clean = classified$clean
  )
}

goal002_task7_fit_fixture <- function(
  terminal_status = "primary_clean"
) {
  data <- goal002_oracle_fixture(C = 4L)$data
  primary <- goal002_attempt_fixture(
    clean = identical(terminal_status, "primary_clean"),
    attempt_id = "primary"
  )
  primary$data_hash <- data$data_hash
  rescue <- NULL
  if (!identical(terminal_status, "primary_clean")) {
    rescue <- goal002_attempt_fixture(
      clean = identical(terminal_status, "rescue_clean"),
      attempt_id = "rescue"
    )
    rescue$data_hash <- data$data_hash
  }
  resolution <- resolve_goal002_attempts(primary, rescue)

  variables <- c(
    "omega",
    "mu_alpha",
    "sigma_alpha",
    "sigma_camera",
    sprintf("alpha[%d]", seq_len(data$stan_data$C)),
    sprintf("camera_effect[%d]", seq_len(data$stan_data$J)),
    sprintf("member_ll[%d]", seq_len(data$stan_data$C)),
    sprintf("q_member[%d]", seq_len(data$stan_data$C)),
    sprintf("g_member[%d]", seq_len(data$stan_data$C)),
    "S_grid",
    "expected_richness",
    sprintf("y_rep[%d]", seq_len(data$stan_data$G))
  )
  draw_matrix <- matrix(
    0,
    nrow = 8L,
    ncol = length(variables),
    dimnames = list(NULL, variables)
  )
  q_names <- sprintf("q_member[%d]", seq_len(data$stan_data$C))
  g_names <- sprintf("g_member[%d]", seq_len(data$stan_data$C))
  q <- cbind(
    rep(1, 8L),
    rep(1, 8L),
    rep(c(0.2, 0.4), 4L),
    rep(c(0.3, 0.5), 4L)
  )
  g <- cbind(
    rep(1, 8L),
    rep(1, 8L),
    rep(c(0, 1), 4L),
    rep(c(1, 0), 4L)
  )
  draw_matrix[, q_names] <- q
  draw_matrix[, g_names] <- g
  draw_matrix[, "S_grid"] <- rowSums(g)
  draw_matrix[, "expected_richness"] <- rowSums(q)

  result <- list(
    terminal_status = resolution$terminal_status,
    rescue_used = resolution$rescue_used,
    terminal_attempt_id = resolution$terminal_attempt_id,
    candidate_ids = data$candidate_ids,
    camera_ids = data$camera_ids,
    detected_ever = data$stan_data$detected_ever,
    observed = data$observed,
    grouped = data$grouped,
    data_hash = data$data_hash,
    prior_profile = goal002_prior_profiles()$primary,
    model_source_hash = primary$model_source_hash,
    attempts = resolution$attempts,
    draws = if (identical(terminal_status, "final_nonclean")) {
      NULL
    } else {
      posterior::as_draws_matrix(draw_matrix)
    }
  )
  class(result) <- c("flexirich_g_fit", "list")
  result
}

testthat::test_that("clean diagnostics require every frozen threshold", {
  diagnostics <- goal002_diagnostic_fixture(clean = TRUE)
  result <- classify_goal002_diagnostics(
    diagnostics$summary,
    diagnostics$sampler,
    goal002_diagnostic_thresholds()
  )

  testthat::expect_true(result$clean)
  testthat::expect_length(result$reasons, 0L)
  testthat::expect_identical(
    names(result),
    c(
      "clean",
      "reasons",
      "metrics",
      "richness",
      "generated_richness",
      "details"
    )
  )
  testthat::expect_identical(
    names(result$metrics),
    c(
      "divergences",
      "treedepth_hits",
      "ebfmi_by_chain",
      "min_ebfmi",
      "max_rhat",
      "min_bulk_ess",
      "min_tail_ess"
    )
  )
  testthat::expect_identical(
    names(result$metrics$ebfmi_by_chain),
    as.character(1:4)
  )
  testthat::expect_identical(
    result$richness,
    goal002_richness_metadata_fixture()
  )
  testthat::expect_identical(
    result$generated_richness$status,
    "not_checked"
  )
})

testthat::test_that("each diagnostic defect makes a fit non-clean", {
  defects <- c(
    "divergences", "treedepth", "ebfmi", "rhat", "bulk_ess", "tail_ess"
  )
  for (defect in defects) {
    diagnostics <- goal002_diagnostic_fixture(clean = TRUE)
    diagnostics <- corrupt_goal002_diagnostic(diagnostics, defect)
    result <- classify_goal002_diagnostics(
      diagnostics$summary,
      diagnostics$sampler,
      goal002_diagnostic_thresholds()
    )
    testthat::expect_false(result$clean, info = defect)
    testthat::expect_true(defect %in% result$reasons, info = defect)
  }
})

testthat::test_that("malformed posterior summaries fail closed", {
  cases <- list(
    summary_missing_rows = function(x) {
      x$summary$statistics <- x$summary$statistics[-1L, ]
      x
    },
    summary_duplicate_rows = function(x) {
      x$summary$statistics <- dplyr::bind_rows(
        x$summary$statistics,
        x$summary$statistics[1L, ]
      )
      x
    },
    summary_nonfinite = function(x) {
      x$summary$statistics$rhat[1L] <- NA_real_
      x
    }
  )

  for (reason in names(cases)) {
    diagnostics <- cases[[reason]](goal002_diagnostic_fixture())
    result <- classify_goal002_diagnostics(
      diagnostics$summary,
      diagnostics$sampler,
      goal002_diagnostic_thresholds()
    )
    testthat::expect_false(result$clean, info = reason)
    testthat::expect_true(reason %in% result$reasons, info = reason)
  }
})

testthat::test_that("richness diagnostic metadata is persisted and fail closed", {
  diagnostics <- goal002_diagnostic_fixture()
  invalid <- diagnostics
  invalid$summary$richness$status <- "invalid"
  invalid$summary$richness$detail <- "constant lower-tail series"
  invalid_result <- classify_goal002_diagnostics(
    invalid$summary,
    invalid$sampler,
    goal002_diagnostic_thresholds()
  )
  testthat::expect_false(invalid_result$clean)
  testthat::expect_true(
    "richness_tail_degenerate" %in% invalid_result$reasons
  )
  testthat::expect_identical(
    invalid_result$richness$detail,
    "constant lower-tail series"
  )

  mismatched <- diagnostics
  mismatched$summary$richness$row_diagnostics$rhat[1L] <- 1.001
  mismatched_result <- classify_goal002_diagnostics(
    mismatched$summary,
    mismatched$sampler,
    goal002_diagnostic_thresholds()
  )
  testthat::expect_false(mismatched_result$clean)
  testthat::expect_true(
    "richness_diagnostic_mismatch" %in% mismatched_result$reasons
  )
})

testthat::test_that("structural point masses bypass inapplicable mixing metrics", {
  diagnostics <- goal002_diagnostic_fixture()
  richness_rows <- diagnostics$summary$statistics$variable %in% c(
    "expected_richness",
    "richness_lower_tail",
    "richness_upper_tail"
  )
  diagnostics$summary$statistics <-
    diagnostics$summary$statistics[!richness_rows, ]
  diagnostics$summary$monitored_variables <-
    diagnostics$summary$monitored_variables[!richness_rows]
  diagnostics$summary$richness <- goal002_richness_metadata_fixture()
  diagnostics$summary$richness$status <- "structural_point_mass"
  diagnostics$summary$richness$observed_richness <- 4L
  diagnostics$summary$richness$lower_cutoff <- NA_integer_
  diagnostics$summary$richness$upper_cutoff <- NA_integer_
  diagnostics$summary$richness$mean_lower_mass <- NA_real_
  diagnostics$summary$richness$mean_upper_mass <- NA_real_
  diagnostics$summary$richness$row_diagnostics[
    c("rhat", "ess_bulk", "ess_tail")
  ] <- NA_real_
  diagnostics$summary$richness$detail <-
    "Richness is a structural point mass."

  result <- classify_goal002_diagnostics(
    diagnostics$summary,
    diagnostics$sampler,
    goal002_diagnostic_thresholds()
  )
  testthat::expect_true(result$clean)
  testthat::expect_identical(
    result$richness$status,
    "structural_point_mass"
  )
})

testthat::test_that("malformed sampler diagnostics fail closed", {
  cases <- list(
    sampler_schema = function(x) {
      x$sampler$draws$energy__ <- NULL
      x
    },
    sampler_missing_chains = function(x) {
      x$sampler$draws <- dplyr::filter(x$sampler$draws, .chain != 4L)
      x
    },
    sampler_duplicate_rows = function(x) {
      x$sampler$draws <- dplyr::bind_rows(
        x$sampler$draws,
        x$sampler$draws[1L, ]
      )
      x
    },
    sampler_nonfinite = function(x) {
      x$sampler$draws$energy__[1L] <- NA_real_
      x
    }
  )

  for (reason in names(cases)) {
    diagnostics <- cases[[reason]](goal002_diagnostic_fixture())
    result <- classify_goal002_diagnostics(
      diagnostics$summary,
      diagnostics$sampler,
      goal002_diagnostic_thresholds()
    )
    testthat::expect_false(result$clean, info = reason)
    testthat::expect_true(reason %in% result$reasons, info = reason)
  }
})

testthat::test_that("the monitored variable contract includes only zero-candidate q rows", {
  fixture <- goal002_oracle_fixture(C = 4L)
  monitored <- .goal002_monitored_variables(fixture$data)

  testthat::expect_identical(monitored, goal002_monitored_fixture())
  testthat::expect_false(any(c("q_member[1]", "q_member[2]") %in% monitored))
  testthat::expect_true(all(c("q_member[3]", "q_member[4]") %in% monitored))
  testthat::expect_false("S_grid" %in% monitored)
  testthat::expect_true(all(c(
    "expected_richness",
    "richness_lower_tail",
    "richness_upper_tail"
  ) %in% monitored))
})

testthat::test_that("proper-tail cutoffs obey mass and deterministic tie rules", {
  central <- .goal002_select_richness_tail_cutoffs(
    c(0.05, 0.10, 0.80, 0.05),
    observed_richness = 0L,
    tau = 0.05
  )
  testthat::expect_identical(central$lower_cutoff, 0L)
  testthat::expect_identical(central$upper_cutoff, 3L)
  testthat::expect_equal(central$mean_lower_mass, 0.05)
  testthat::expect_equal(central$mean_upper_mass, 0.05)

  prefer_larger <- .goal002_select_richness_tail_cutoffs(
    c(0.04, 0.02, 0.94),
    observed_richness = 0L,
    tau = 0.05
  )
  testthat::expect_identical(prefer_larger$lower_cutoff, 1L)

  upper_larger <- .goal002_select_richness_tail_cutoffs(
    c(0.94, 0.02, 0.04),
    observed_richness = 0L,
    tau = 0.05
  )
  testthat::expect_identical(upper_larger$upper_cutoff, 1L)

  lower_extreme <- .goal002_select_richness_tail_cutoffs(
    c(0.05, 0, 0.95),
    observed_richness = 0L,
    tau = 0.05
  )
  upper_extreme <- .goal002_select_richness_tail_cutoffs(
    c(0.95, 0, 0.05),
    observed_richness = 0L,
    tau = 0.05
  )
  testthat::expect_identical(lower_extreme$lower_cutoff, 0L)
  testthat::expect_identical(upper_extreme$upper_cutoff, 2L)

  lower_dominant <- .goal002_select_richness_tail_cutoffs(
    c(0.90, 0.05, 0.03, 0.02),
    observed_richness = 0L,
    tau = 0.05
  )
  upper_dominant <- .goal002_select_richness_tail_cutoffs(
    c(0.02, 0.03, 0.05, 0.90),
    observed_richness = 0L,
    tau = 0.05
  )
  testthat::expect_identical(lower_dominant$lower_cutoff, 0L)
  testthat::expect_identical(lower_dominant$upper_cutoff, 2L)
  testthat::expect_identical(upper_dominant$lower_cutoff, 1L)
  testthat::expect_identical(upper_dominant$upper_cutoff, 3L)
})

testthat::test_that("Rao-Blackwellised richness tails are finite and order invariant", {
  fixture <- goal002_q_draw_fixture()
  result <- .goal002_build_richness_diagnostics(
    fixture$q,
    fixture$detected_ever,
    fixture$chain,
    fixture$iteration
  )

  testthat::expect_identical(result$metadata$status, "estimated")
  testthat::expect_equal(sum(result$mean_pmf), 1, tolerance = 1e-14)
  testthat::expect_true(all(is.finite(
    unlist(result$metadata$row_diagnostics[-1L])
  )))
  testthat::expect_true(all(is.finite(
    result$series$richness_lower_tail
  )))
  testthat::expect_true(all(is.finite(
    result$series$richness_upper_tail
  )))
  testthat::expect_gt(stats::sd(result$series$richness_lower_tail), 0)
  testthat::expect_gt(stats::sd(result$series$richness_upper_tail), 0)

  permutation <- c(4L, 1L, 3L, 2L)
  permuted <- .goal002_build_richness_diagnostics(
    fixture$q[, permutation, drop = FALSE],
    fixture$detected_ever[permutation],
    fixture$chain,
    fixture$iteration
  )
  testthat::expect_identical(
    permuted$metadata$lower_cutoff,
    result$metadata$lower_cutoff
  )
  testthat::expect_identical(
    permuted$metadata$upper_cutoff,
    result$metadata$upper_cutoff
  )
  testthat::expect_equal(permuted$mean_pmf, result$mean_pmf, tolerance = 1e-14)
  testthat::expect_equal(
    permuted$series[c(
      "expected_richness",
      "richness_lower_tail",
      "richness_upper_tail"
    )],
    result$series[c(
      "expected_richness",
      "richness_lower_tail",
      "richness_upper_tail"
    )],
    tolerance = 1e-14
  )
})

testthat::test_that("bounded S_grid tail ESS may be NA while RB tails are finite", {
  fixture <- goal002_q_draw_fixture()
  richness <- .goal002_build_richness_diagnostics(
    fixture$q,
    fixture$detected_ever,
    fixture$chain,
    fixture$iteration
  )
  s_grid <- array(
    4,
    dim = c(200L, 4L, 1L),
    dimnames = list(NULL, NULL, "S_grid")
  )
  for (chain in 1:4) {
    s_grid[seq(chain, 200L, by = 25L), chain, 1L] <- 2
  }
  s_grid <- posterior::as_draws_array(s_grid)

  testthat::expect_true(is.na(posterior::ess_tail(s_grid)))
  testthat::expect_identical(richness$metadata$status, "estimated")
  testthat::expect_true(all(is.finite(
    richness$metadata$row_diagnostics$rhat
  )))
  testthat::expect_true(all(is.finite(
    richness$metadata$row_diagnostics$ess_bulk
  )))
  testthat::expect_true(all(is.finite(
    richness$metadata$row_diagnostics$ess_tail
  )))
})

testthat::test_that("structural richness point masses are explicit", {
  q <- matrix(1, nrow = 40L, ncol = 3L)
  result <- .goal002_build_richness_diagnostics(
    q,
    detected_ever = rep(1L, 3L),
    chain = rep(1:4, each = 10L),
    iteration = rep(1:10, times = 4L)
  )

  testthat::expect_identical(
    result$metadata$status,
    "structural_point_mass"
  )
  testthat::expect_identical(result$metadata$lower_cutoff, NA_integer_)
  testthat::expect_identical(result$metadata$upper_cutoff, NA_integer_)
  testthat::expect_true(all(is.na(
    result$metadata$row_diagnostics$rhat
  )))
  testthat::expect_identical(
    result$mean_pmf,
    stats::setNames(c(0, 0, 0, 1), as.character(0:3))
  )
})

testthat::test_that("invalid or degenerate richness tails fail closed", {
  fixture <- goal002_q_draw_fixture()
  constant <- fixture$q
  constant[, 3:4] <- 0.5
  degenerate <- .goal002_build_richness_diagnostics(
    constant,
    fixture$detected_ever,
    fixture$chain,
    fixture$iteration
  )
  testthat::expect_identical(degenerate$metadata$status, "invalid")
  testthat::expect_match(degenerate$metadata$detail, "constant")

  nonfinite <- fixture$q
  nonfinite[1L, 3L] <- NA_real_
  out_of_range <- fixture$q
  out_of_range[1L, 3L] <- 1.01
  testthat::expect_identical(
    .goal002_build_richness_diagnostics(
      nonfinite,
      fixture$detected_ever,
      fixture$chain,
      fixture$iteration
    )$metadata$status,
    "invalid"
  )
  testthat::expect_identical(
    .goal002_build_richness_diagnostics(
      out_of_range,
      fixture$detected_ever,
      fixture$chain,
      fixture$iteration
    )$metadata$status,
    "invalid"
  )

  testthat::expect_error(
    .goal002_select_richness_tail_cutoffs(
      c(0.4, 0.4),
      observed_richness = 0L
    ),
    "sum to one"
  )
  testthat::expect_error(
    .goal002_select_richness_tail_cutoffs(
      c(0.5, -0.1, 0.6),
      observed_richness = 0L
    ),
    "non-negative"
  )
})

testthat::test_that("chain-shifted q draws fail richness convergence", {
  fixture <- goal002_q_draw_fixture()
  shifted <- fixture$q
  low_chain <- fixture$chain <= 2L
  shifted[low_chain, 3L] <- 0.1 + shifted[low_chain, 3L] / 100
  shifted[!low_chain, 3L] <- 0.9 + shifted[!low_chain, 3L] / 100
  result <- .goal002_build_richness_diagnostics(
    shifted,
    fixture$detected_ever,
    fixture$chain,
    fixture$iteration
  )

  testthat::expect_identical(result$metadata$status, "estimated")
  testthat::expect_gt(max(result$metadata$row_diagnostics$rhat), 1.01)
})

testthat::test_that("diagnostic threshold boundaries are inclusive", {
  diagnostics <- goal002_diagnostic_fixture()
  diagnostics$summary$statistics$rhat[] <- 1.01
  diagnostics$summary$statistics$ess_bulk[] <- 400
  diagnostics$summary$statistics$ess_tail[] <- 400
  diagnostics$summary$richness$row_diagnostics <-
    diagnostics$summary$statistics |>
    dplyr::filter(grepl("^expected_richness|^richness_", variable))

  at_boundary <- classify_goal002_diagnostics(
    diagnostics$summary,
    diagnostics$sampler,
    goal002_diagnostic_thresholds()
  )
  testthat::expect_true(at_boundary$clean)

  ebfmi_thresholds <- goal002_diagnostic_thresholds()
  ebfmi_thresholds$min_ebfmi <- at_boundary$metrics$min_ebfmi
  testthat::expect_true(classify_goal002_diagnostics(
    diagnostics$summary,
    diagnostics$sampler,
    ebfmi_thresholds
  )$clean)

  diagnostics$summary$statistics$rhat[1L] <- 1.0100001
  testthat::expect_true("rhat" %in% classify_goal002_diagnostics(
    diagnostics$summary,
    diagnostics$sampler,
    goal002_diagnostic_thresholds()
  )$reasons)
})

testthat::test_that("generated richness draws pass or fail exact contracts", {
  fit <- goal002_task7_fit_fixture("primary_clean")
  clean <- .goal002_check_generated_richness(
    fit$draws,
    fit$detected_ever
  )
  testthat::expect_identical(clean$status, "passed")
  testthat::expect_length(clean$reasons, 0L)
  testthat::expect_equal(
    clean$metrics$max_expected_richness_error,
    0
  )

  corruptions <- list(
    q_member_nonfinite = function(x) {
      x[1L, "q_member[3]"] <- NA_real_
      x
    },
    q_member_support = function(x) {
      x[1L, "q_member[3]"] <- 1.1
      x
    },
    g_member_support = function(x) {
      x[1L, "g_member[3]"] <- 0.5
      x
    },
    detected_membership = function(x) {
      x[1L, "q_member[1]"] <- 0.9
      x
    },
    s_grid_support = function(x) {
      x[1L, "S_grid"] <- 1.5
      x
    },
    s_grid_reconstruction = function(x) {
      x[1L, "S_grid"] <- 4
      x
    },
    expected_richness_reconstruction = function(x) {
      x[1L, "expected_richness"] <-
        x[1L, "expected_richness"] + 0.1
      x
    },
    generated_draw_schema = function(x) {
      x[, colnames(x) != "S_grid", drop = FALSE]
    }
  )

  for (reason in names(corruptions)) {
    corrupted <- corruptions[[reason]](as.matrix(fit$draws))
    result <- .goal002_check_generated_richness(
      corrupted,
      fit$detected_ever
    )
    testthat::expect_identical(result$status, "failed", info = reason)
    testthat::expect_true(reason %in% result$reasons, info = reason)
  }
})

testthat::test_that("attempt resolution permits at most one rescue", {
  primary_clean <- resolve_goal002_attempts(
    primary = goal002_attempt_fixture(clean = TRUE),
    rescue = NULL
  )
  testthat::expect_identical(
    primary_clean$terminal_status,
    "primary_clean"
  )
  testthat::expect_false(primary_clean$rescue_used)
  testthat::expect_identical(primary_clean$terminal_attempt_id, "primary")
  testthat::expect_identical(names(primary_clean$attempts), "primary")

  rescued <- resolve_goal002_attempts(
    primary = goal002_attempt_fixture(clean = FALSE),
    rescue = goal002_attempt_fixture(clean = TRUE, attempt_id = "rescue")
  )
  testthat::expect_identical(rescued$terminal_status, "rescue_clean")
  testthat::expect_true(rescued$rescue_used)
  testthat::expect_identical(rescued$terminal_attempt_id, "rescue")
  testthat::expect_identical(
    names(rescued$attempts),
    c("primary", "rescue")
  )

  nonclean <- resolve_goal002_attempts(
    primary = goal002_attempt_fixture(clean = FALSE),
    rescue = goal002_attempt_fixture(clean = FALSE, attempt_id = "rescue")
  )
  testthat::expect_identical(nonclean$terminal_status, "final_nonclean")
  testthat::expect_true(nonclean$rescue_used)
  testthat::expect_length(nonclean$attempts, 2L)

  testthat::expect_error(
    resolve_goal002_attempts(
      primary = goal002_attempt_fixture(clean = TRUE),
      rescue = goal002_attempt_fixture(clean = TRUE, attempt_id = "rescue")
    ),
    "clean primary.*rescue",
    ignore.case = TRUE
  )
})

testthat::test_that("attempt metadata has an exact validated schema", {
  attempt <- goal002_attempt_fixture(clean = TRUE)
  testthat::expect_true(validate_goal002_attempt(attempt))
  testthat::expect_identical(
    names(attempt),
    c(
      "attempt_id",
      "sampler_profile_id",
      "seed",
      "started_at_utc",
      "elapsed_seconds",
      "model_source_hash",
      "data_hash",
      "prior_profile",
      "R_version",
      "cmdstanr_version",
      "cmdstan_version",
      "compiler",
      "output_files",
      "diagnostics",
      "clean"
    )
  )

  extra <- attempt
  extra$mutable_backend <- list()
  testthat::expect_error(
    validate_goal002_attempt(extra),
    "component contract"
  )

  inconsistent <- attempt
  inconsistent$clean <- FALSE
  testthat::expect_error(
    validate_goal002_attempt(inconsistent),
    "clean.*diagnostics",
    ignore.case = TRUE
  )
})

testthat::test_that("fit objects have exact terminal and draw contracts", {
  primary <- goal002_task7_fit_fixture("primary_clean")
  rescued <- goal002_task7_fit_fixture("rescue_clean")
  nonclean <- goal002_task7_fit_fixture("final_nonclean")

  testthat::expect_true(validate_flexirich_g_fit(primary))
  testthat::expect_true(validate_flexirich_g_fit(rescued))
  testthat::expect_true(validate_flexirich_g_fit(nonclean))
  testthat::expect_s3_class(primary$draws, "draws_matrix")
  testthat::expect_s3_class(rescued$draws, "draws_matrix")
  testthat::expect_null(nonclean$draws)
  testthat::expect_identical(
    names(primary),
    c(
      "terminal_status",
      "rescue_used",
      "terminal_attempt_id",
      "candidate_ids",
      "camera_ids",
      "detected_ever",
      "observed",
      "grouped",
      "data_hash",
      "prior_profile",
      "model_source_hash",
      "attempts",
      "draws"
    )
  )
})

testthat::test_that("source-hashed compilation stays beneath ignored outputs", {
  project_root <- goal002_test_root()
  stan_file <- file.path(project_root, "stan", "flexirich_g.stan")
  source_hash <- digest::digest(
    stan_file,
    algo = "sha256",
    file = TRUE,
    serialize = FALSE
  )
  expected_executable <- normalizePath(
    file.path(
      project_root,
      "outputs",
      "goal002",
      "cmdstan",
      "bin",
      paste0("flexirich_g-", substr(source_hash, 1L, 16L))
    ),
    mustWork = TRUE
  )

  model <- compile_flexirich_g_model(force_recompile = FALSE)
  testthat::expect_identical(
    normalizePath(model$exe_file(), mustWork = TRUE),
    expected_executable
  )
  testthat::expect_false(any(file.exists(c(
    file.path(project_root, "stan", "flexirich_g"),
    file.path(project_root, "stan", "flexirich_g.hpp"),
    file.path(project_root, "stan", "flexirich_g.o"),
    file.path(project_root, "stan", "flexirich_g.d")
  ))))
})

testthat::test_that("fit validation rejects unsafe output reuse before sampling", {
  fixture <- goal002_oracle_fixture(C = 4L)
  prior <- goal002_prior_profiles()$primary

  testthat::expect_error(
    fit_flexirich_g(
      fixture$data,
      seed = 72002101L,
      prior_profile = prior,
      output_dir = tempfile(),
      allow_rescue = FALSE
    ),
    "outputs/goal002",
    fixed = TRUE
  )

  existing <- file.path(
    goal002_test_root(),
    "outputs",
    "goal002",
    paste0("test-existing-", Sys.getpid())
  )
  dir.create(existing, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(existing, recursive = TRUE, force = TRUE), add = TRUE)
  testthat::expect_error(
    fit_flexirich_g(
      fixture$data,
      seed = 72002101L,
      prior_profile = prior,
      output_dir = existing,
      allow_rescue = FALSE
    ),
    "must not already exist",
    fixed = TRUE
  )
})
