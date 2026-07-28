goal002_run_fixture <- function(
  status = "primary_clean",
  C = 30L,
  true_richness = 20L,
  observed_richness = 18L
) {
  probability <- numeric(C + 1L)
  probability[true_richness + 1L] <- 1
  pmf <- tibble::tibble(
    richness = seq.int(0L, C),
    probability = probability
  )

  list(
    run_id = "fixture",
    terminal_status = status,
    true_richness = true_richness,
    observed_richness = observed_richness,
    posterior_pmf = if (identical(status, "final_nonclean")) NULL else pmf,
    interval_90_lower = if (identical(status, "final_nonclean")) {
      NA_integer_
    } else {
      true_richness
    },
    interval_90_upper = if (identical(status, "final_nonclean")) {
      NA_integer_
    } else {
      true_richness
    }
  )
}

goal002_pilot_fixture <- function() {
  manifest <- goal002_frozen_manifest()
  pmfs <- lapply(manifest$true_richness, function(truth) {
    probability <- numeric(31L)
    probability[truth + 1L] <- 1
    tibble::tibble(
      richness = 0:30,
      probability = probability
    )
  })
  hash <- paste(rep("a", 64L), collapse = "")

  dplyr::mutate(
    manifest,
    terminal_status = "primary_clean",
    rescue_used = FALSE,
    observed_richness = pmax(0L, true_richness - 1L),
    data_hash = hash,
    model_hash = hash,
    primary_attempt_path = file.path(
      "outputs",
      "goal002",
      "frozen",
      run_id,
      "primary"
    ),
    rescue_attempt_path = NA_character_,
    summary_path = file.path(
      "outputs",
      "goal002",
      "frozen",
      run_id,
      "summary.rds"
    ),
    elapsed_seconds = 1,
    artifacts_verified = TRUE,
    diagnostic_evidence = rep(
      list(goal002_clean_diagnostic_evidence_fixture()),
      dplyr::n()
    ),
    posterior_pmf = pmfs
  )
}

goal002_clean_diagnostic_evidence_fixture <- function() {
  list(
    passed = TRUE,
    divergences = 0L,
    treedepth_hits = 0L,
    min_ebfmi = 0.8,
    max_rhat = 1,
    min_bulk_ess = 800,
    min_tail_ess = 800,
    richness_diagnostics_passed = TRUE,
    generated_richness_passed = TRUE
  )
}

goal002_make_nonclean <- function(results, rows) {
  results$terminal_status[rows] <- "final_nonclean"
  results$rescue_used[rows] <- TRUE
  results$rescue_attempt_path[rows] <- file.path(
    "outputs",
    "goal002",
    "frozen",
    results$run_id[rows],
    "rescue"
  )
  results$posterior_pmf[rows] <- rep(list(NULL), length(rows))
  results
}

testthat::test_that("development manifest has one independent row per cell", {
  manifest <- goal002_development_manifest()
  testthat::expect_equal(nrow(manifest), 6L)
  testthat::expect_setequal(manifest$true_richness, c(8L, 20L, 27L))
  testthat::expect_setequal(manifest$n_occasions, c(26L, 208L))
  testthat::expect_true(all(manifest$prior_profile == "primary"))
  testthat::expect_equal(anyDuplicated(manifest$simulation_seed), 0L)
  testthat::expect_equal(anyDuplicated(manifest$fit_seed), 0L)
})

testthat::test_that("frozen manifest contains exactly 60 plus 36 fits", {
  manifest <- goal002_frozen_manifest()
  testthat::expect_equal(sum(manifest$run_type == "primary"), 60L)
  testthat::expect_equal(sum(manifest$run_type == "sensitivity"), 36L)
  testthat::expect_equal(nrow(manifest), 96L)
  testthat::expect_true(all(
    manifest$replicate[manifest$run_type == "sensitivity"] <= 3L
  ))
  testthat::expect_equal(anyDuplicated(manifest$run_id), 0L)
})

testthat::test_that("non-clean runs receive conservative gate values", {
  result <- goal002_run_fixture(status = "final_nonclean", C = 30L)
  gate <- goal002_gate_values(result, C = 30L)

  testthat::expect_false(gate$covered_90)
  testthat::expect_equal(gate$truth_probability, 0)
  testthat::expect_equal(gate$absolute_error, 30)
  testthat::expect_equal(gate$squared_error, 900)
  testthat::expect_equal(gate$rps, 30)
  testthat::expect_true(is.na(gate$signed_error))
})

testthat::test_that("manifest seeds and sensitivity pairing are exact", {
  development <- goal002_development_manifest()
  testthat::expect_equal(
    development$simulation_seed,
    120020000L + development$cell_id
  )
  testthat::expect_equal(
    development$fit_seed,
    220020000L + development$cell_id
  )

  frozen <- goal002_frozen_manifest()
  primary <- dplyr::filter(frozen, run_type == "primary")
  testthat::expect_equal(
    primary$simulation_seed,
    320020000L + 100L * primary$cell_id + primary$replicate
  )
  testthat::expect_equal(
    primary$fit_seed,
    420020000L + 100L * primary$cell_id + primary$replicate
  )
  sensitivity <- dplyr::filter(frozen, run_type == "sensitivity")
  paired <- dplyr::left_join(
    sensitivity,
    dplyr::select(
      primary,
      cell_id,
      replicate,
      primary_simulation_seed = simulation_seed
    ),
    by = c("cell_id", "replicate")
  )
  testthat::expect_equal(
    paired$simulation_seed,
    paired$primary_simulation_seed
  )
  testthat::expect_equal(
    sensitivity$fit_seed[
      sensitivity$prior_profile == "sensitivity_membership"
    ],
    520020000L +
      100L * sensitivity$cell_id[
        sensitivity$prior_profile == "sensitivity_membership"
      ] +
      sensitivity$replicate[
        sensitivity$prior_profile == "sensitivity_membership"
      ]
  )
  testthat::expect_equal(
    sensitivity$fit_seed[
      sensitivity$prior_profile == "sensitivity_tail"
    ],
    620020000L +
      100L * sensitivity$cell_id[
        sensitivity$prior_profile == "sensitivity_tail"
      ] +
      sensitivity$replicate[
        sensitivity$prior_profile == "sensitivity_tail"
      ]
  )
})

testthat::test_that("manifest validation rejects every row-set corruption", {
  for (phase in c("development", "frozen")) {
    manifest <- if (phase == "development") {
      goal002_development_manifest()
    } else {
      goal002_frozen_manifest()
    }
    testthat::expect_true(validate_goal002_manifest(manifest, phase))

    duplicate <- dplyr::bind_rows(manifest, manifest[1L, ])
    testthat::expect_error(
      validate_goal002_manifest(duplicate, phase),
      "differs"
    )
    missing <- manifest[-1L, ]
    testthat::expect_error(
      validate_goal002_manifest(missing, phase),
      "differs"
    )
    altered <- manifest
    altered$fit_seed[1L] <- altered$fit_seed[1L] + 1L
    testthat::expect_error(
      validate_goal002_manifest(altered, phase),
      "differs"
    )
    extra <- manifest
    extra$unexpected <- 1L
    testthat::expect_error(
      validate_goal002_manifest(extra, phase),
      "fields"
    )
  }
})

testthat::test_that("all Criteria 19 through 35 are returned canonically", {
  gates <- evaluate_goal002_gates(goal002_pilot_fixture())
  testthat::expect_identical(
    names(gates)[seq_len(17L)],
    paste0("criterion_", 19:35)
  )
  for (criterion in gates[seq_len(17L)]) {
    testthat::expect_identical(
      names(criterion),
      c(
        "criterion",
        "numerator",
        "denominator",
        "statistic",
        "threshold",
        "passed",
        "reason"
      )
    )
    testthat::expect_true(criterion$passed)
  }
})

testthat::test_that("fixed coverage denominators do not drop non-clean runs", {
  results <- goal002_pilot_fixture()
  six_month <- which(
    results$run_type == "primary" &
      results$n_occasions == 26L
  )[1L]
  results <- goal002_make_nonclean(results, six_month)
  gates <- evaluate_goal002_gates(results)

  testthat::expect_equal(gates$criterion_25$denominator, 10)
  testthat::expect_equal(gates$criterion_30$denominator, 30)
  testthat::expect_equal(
    gates$six_month_primary_summary$planned_n,
    30L
  )
  testthat::expect_equal(
    gates$six_month_primary_summary$clean_n,
    29L
  )
  testthat::expect_true(is.na(
    gates$six_month_primary_summary$signed_bias
  ))
  testthat::expect_equal(
    gates$criterion_30$numerator,
    29
  )
})

testthat::test_that("rescue-clean inference is included and addressable", {
  results <- goal002_pilot_fixture()
  row <- which(results$run_type == "primary")[1L]
  results$terminal_status[row] <- "rescue_clean"
  results$rescue_used[row] <- TRUE
  results$rescue_attempt_path[row] <- file.path(
    "outputs",
    "goal002",
    "frozen",
    results$run_id[row],
    "rescue"
  )
  gates <- evaluate_goal002_gates(results)

  testthat::expect_true(gates$criterion_19$passed)
  testthat::expect_true(gates$criterion_21$passed)
  testthat::expect_true(gates$criterion_22$passed)
  testthat::expect_true(
    gates$primary_gate_values$covered_90[
      gates$primary_gate_values$run_id == results$run_id[row]
    ]
  )
})

testthat::test_that("Criterion 20 uses frozen diagnostic evidence", {
  results <- goal002_pilot_fixture()
  row <- which(results$run_type == "primary")[1L]
  results$diagnostic_evidence[[row]]$max_rhat <- 1.02
  results$diagnostic_evidence[[row]]$passed <- FALSE

  gates <- evaluate_goal002_gates(results)
  testthat::expect_false(gates$criterion_20$passed)
  testthat::expect_equal(
    gates$criterion_20$numerator,
    95
  )
})

testthat::test_that("Criterion 22 enforces overall and per-cell limits", {
  results <- goal002_pilot_fixture()
  primary <- which(results$run_type == "primary")
  one_per_cell <- vapply(
    1:3,
    function(cell) {
      which(
        results$run_type == "primary" &
          results$cell_id == cell
      )[1L]
    },
    integer(1)
  )
  gates <- evaluate_goal002_gates(
    goal002_make_nonclean(results, one_per_cell)
  )
  testthat::expect_true(gates$criterion_22$passed)

  gates <- evaluate_goal002_gates(
    goal002_make_nonclean(results, primary[1:4])
  )
  testthat::expect_false(gates$criterion_22$passed)

  same_cell <- which(
    results$run_type == "primary" &
      results$cell_id == 1L
  )[1:2]
  gates <- evaluate_goal002_gates(
    goal002_make_nonclean(results, same_cell)
  )
  testthat::expect_false(gates$criterion_22$passed)
})

testthat::test_that("four-year non-clean runs fail recovery gates", {
  results <- goal002_pilot_fixture()
  row <- which(
    results$run_type == "primary" &
      results$n_occasions == 208L
  )[1L]
  gates <- evaluate_goal002_gates(
    goal002_make_nonclean(results, row)
  )

  testthat::expect_false(gates$criterion_25$passed)
  testthat::expect_false(gates$criterion_26$passed)
  testthat::expect_false(gates$criterion_27$passed)
  testthat::expect_false(gates$criterion_28$passed)
  testthat::expect_false(gates$criterion_29$passed)
})

testthat::test_that("four-year non-clean sensitivity fails stability gates", {
  results <- goal002_pilot_fixture()
  row <- which(
    results$run_type == "sensitivity" &
      results$n_occasions == 208L
  )[1L]
  gates <- evaluate_goal002_gates(
    goal002_make_nonclean(results, row)
  )

  testthat::expect_false(gates$criterion_33$passed)
  testthat::expect_false(gates$criterion_34$passed)
  testthat::expect_true(gates$criterion_32$passed)
})

testthat::test_that("non-clean sensitivity cannot expose inference", {
  results <- goal002_pilot_fixture()
  row <- which(results$run_type == "sensitivity")[1L]
  results <- goal002_make_nonclean(results, row)
  results$posterior_pmf[row] <- list(
    goal002_pilot_fixture()$posterior_pmf[[row]]
  )
  gates <- evaluate_goal002_gates(results)
  testthat::expect_false(gates$criterion_24$passed)
})

testthat::test_that("primary and rescue attempt addresses are audited", {
  results <- goal002_pilot_fixture()
  results$primary_attempt_path[1L] <- NA_character_
  gates <- evaluate_goal002_gates(results)
  testthat::expect_false(gates$criterion_19$passed)

  results <- goal002_pilot_fixture()
  results <- goal002_make_nonclean(results, 1L)
  results$rescue_attempt_path[1L] <- NA_character_
  gates <- evaluate_goal002_gates(results)
  testthat::expect_false(gates$criterion_19$passed)
  testthat::expect_false(gates$criterion_21$passed)
})

goal002_terminal_fixture <- function(
  row = goal002_development_manifest()[1L, ],
  manifest_hash = paste(rep("b", 64L), collapse = ""),
  freeze_hash = NA_character_
) {
  hash <- paste(rep("a", 64L), collapse = "")
  c(
    as.list(row),
    list(
      terminal_status = "primary_clean",
      rescue_used = FALSE,
      observed_richness = max(0L, row$true_richness - 1L),
      data_hash = hash,
      model_hash = hash,
      primary_attempt_path = file.path(
        "outputs",
        "goal002",
        "development",
        row$run_id,
        "primary"
      ),
      rescue_attempt_path = NA_character_,
      summary_path = file.path(
        "outputs",
        "goal002",
        "development",
        row$run_id,
        "summary.rds"
      ),
      elapsed_seconds = 1,
      manifest_hash = manifest_hash,
      freeze_hash = freeze_hash,
      artifacts_verified = TRUE,
      diagnostic_evidence =
        goal002_clean_diagnostic_evidence_fixture(),
      posterior_pmf = {
        probability <- numeric(31L)
        probability[row$true_richness + 1L] <- 1
        tibble::tibble(
          richness = 0:30,
          probability = probability
        )
      }
    )
  )
}

goal002_pilot_diagnostics_fixture <- function(
  clean,
  observed_richness,
  candidate_pool_size
) {
  metrics <- list(
    divergences = if (clean) 0L else 1L,
    treedepth_hits = 0L,
    ebfmi_by_chain = stats::setNames(
      rep(0.8, 4L),
      as.character(1:4)
    ),
    min_ebfmi = 0.8,
    max_rhat = 1,
    min_bulk_ess = 800,
    min_tail_ess = 800
  )
  richness <- list(
    status = "estimated",
    tau = 0.05,
    observed_richness = observed_richness,
    candidate_pool_size = candidate_pool_size,
    lower_cutoff = observed_richness,
    upper_cutoff = candidate_pool_size,
    mean_lower_mass = 0.1,
    mean_upper_mass = 0.1,
    row_diagnostics = tibble::tibble(
      variable = c(
        "expected_richness",
        "richness_lower_tail",
        "richness_upper_tail"
      ),
      rhat = rep(1, 3L),
      ess_bulk = rep(800, 3L),
      ess_tail = rep(800, 3L)
    ),
    detail = ""
  )
  generated <- list(
    status = "passed",
    reasons = character(),
    metrics = list(
      n_draws = 40L,
      candidate_pool_size = candidate_pool_size,
      observed_richness = observed_richness,
      max_expected_richness_error = 0
    ),
    details = character()
  )
  reasons <- if (clean) character() else "divergences"
  list(
    clean = clean,
    reasons = reasons,
    metrics = metrics,
    richness = richness,
    generated_richness = generated,
    details = if (clean) {
      character()
    } else {
      stats::setNames(
        "One divergent transition was observed.",
        reasons
      )
    }
  )
}

goal002_pilot_attempt_fixture <- function(
  data,
  clean,
  attempt_id,
  fit_seed
) {
  diagnostics <- goal002_pilot_diagnostics_fixture(
    clean = clean,
    observed_richness = sum(data$stan_data$detected_ever),
    candidate_pool_size = data$stan_data$C
  )
  list(
    attempt_id = attempt_id,
    sampler_profile_id = if (attempt_id == "primary") {
      "primary-sampler-v1"
    } else {
      "rescue-sampler-v1"
    },
    seed = if (attempt_id == "primary") {
      as.integer(fit_seed)
    } else {
      as.integer(fit_seed + 500000L)
    },
    started_at_utc = "2026-07-28T00:00:00Z",
    elapsed_seconds = 1,
    model_source_hash = paste(rep("a", 64L), collapse = ""),
    data_hash = data$data_hash,
    prior_profile = "primary-v1",
    R_version = as.character(getRversion()),
    cmdstanr_version = as.character(utils::packageVersion("cmdstanr")),
    cmdstan_version = "2.38.0",
    compiler = "g++ test compiler",
    output_files = if (clean) {
      sprintf(
        "outputs/goal002/fixture/%s/chain-%d.csv",
        attempt_id,
        1:4
      )
    } else {
      character()
    },
    diagnostics = diagnostics,
    clean = clean
  )
}

goal002_pilot_fit_artifact <- function(
  row,
  terminal_status = "primary_clean"
) {
  simulation <- simulate_flexirich_g(flexirich_sim_config(
    candidate_pool_size = 30L,
    true_richness = row$true_richness,
    n_cameras = 9L,
    n_occasions = row$n_occasions,
    occasion_days = 7L,
    seed = row$simulation_seed
  ))
  data <- sim_to_flexirich_g_data(simulation)
  primary <- goal002_pilot_attempt_fixture(
    data,
    clean = terminal_status == "primary_clean",
    attempt_id = "primary",
    fit_seed = row$fit_seed
  )
  rescue <- if (terminal_status == "primary_clean") {
    NULL
  } else {
    goal002_pilot_attempt_fixture(
      data,
      clean = terminal_status == "rescue_clean",
      attempt_id = "rescue",
      fit_seed = row$fit_seed
    )
  }
  resolution <- resolve_goal002_attempts(primary, rescue)

  C <- data$stan_data$C
  J <- data$stan_data$J
  G <- data$stan_data$G
  variables <- c(
    "omega",
    "mu_alpha",
    "sigma_alpha",
    "sigma_camera",
    sprintf("alpha[%d]", seq_len(C)),
    sprintf("camera_effect[%d]", seq_len(J)),
    sprintf("member_ll[%d]", seq_len(C)),
    sprintf("q_member[%d]", seq_len(C)),
    sprintf("g_member[%d]", seq_len(C)),
    "S_grid",
    "expected_richness",
    sprintf("y_rep[%d]", seq_len(G))
  )
  draws <- matrix(
    0,
    nrow = 40L,
    ncol = length(variables),
    dimnames = list(NULL, variables)
  )
  draws[, "omega"] <- rep(c(0.4, 0.6), 20L)
  draws[, "mu_alpha"] <- rep(c(-8, -7), 20L)
  draws[, "sigma_alpha"] <- rep(c(0.8, 1.2), 20L)
  draws[, "sigma_camera"] <- rep(c(0.4, 0.6), 20L)
  for (candidate in seq_len(C)) {
    draws[, sprintf("alpha[%d]", candidate)] <-
      -8 + candidate / C + rep(c(-0.1, 0.1), 20L)
  }
  camera_effect <- seq(-0.4, 0.4, length.out = J)
  camera_effect <- camera_effect - mean(camera_effect)
  for (camera in seq_len(J)) {
    draws[, sprintf("camera_effect[%d]", camera)] <-
      camera_effect[[camera]]
  }
  detected <- data$stan_data$detected_ever == 1L
  q <- matrix(0.2, nrow = 40L, ncol = C)
  q[, detected] <- 1
  g <- matrix(
    withr::with_seed(
      99002001L,
      stats::rbinom(40L * C, 1L, as.vector(q))
    ),
    nrow = 40L,
    ncol = C
  )
  g[, detected] <- 1
  draws[, sprintf("q_member[%d]", seq_len(C))] <- q
  draws[, sprintf("g_member[%d]", seq_len(C))] <- g
  draws[, "S_grid"] <- rowSums(g)
  draws[, "expected_richness"] <- rowSums(q)
  draws[, sprintf("y_rep[%d]", seq_len(G))] <- matrix(
    rep(data$stan_data$n_detected, each = 40L),
    nrow = 40L,
    ncol = G
  )

  fit <- list(
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
    draws = if (terminal_status == "final_nonclean") {
      NULL
    } else {
      posterior::as_draws_matrix(draws)
    }
  )
  class(fit) <- c("flexirich_g_fit", "list")
  fit
}

goal002_materialize_terminal_fixture <- function(
  root,
  row = goal002_development_manifest()[1L, ],
  terminal_status = "primary_clean",
  manifest_hash = paste(rep("b", 64L), collapse = ""),
  freeze_hash = NA_character_,
  save_terminal = TRUE,
  simulation_row = row
) {
  run_dir <- file.path(
    root,
    "outputs",
    "goal002",
    "development",
    row$run_id
  )
  dir.create(run_dir, recursive = TRUE)
  fit <- goal002_pilot_fit_artifact(simulation_row, terminal_status)
  for (attempt_id in names(fit$attempts)) {
    attempt_dir <- file.path(run_dir, attempt_id)
    dir.create(attempt_dir)
    if (fit$attempts[[attempt_id]]$clean) {
      files <- file.path(
        attempt_dir,
        sprintf("chain-%d.csv", 1:4)
      )
      file.create(files)
      fit$attempts[[attempt_id]]$output_files <- file.path(
        "outputs",
        "goal002",
        "development",
        row$run_id,
        attempt_id,
        basename(files)
      )
    }
  }
  validate_flexirich_g_fit(fit)
  summary <- summarise_flexirich_g(fit, fit$candidate_ids)
  fit_path <- file.path(run_dir, "fit.rds")
  summary_path <- file.path(run_dir, "summary.rds")
  saveRDS(fit, fit_path)
  saveRDS(summary, summary_path)

  record <- c(
    as.list(row),
    list(
      terminal_status = fit$terminal_status,
      rescue_used = fit$rescue_used,
      observed_richness = as.integer(sum(fit$detected_ever)),
      data_hash = fit$data_hash,
      model_hash = fit$model_source_hash,
      primary_attempt_path = file.path(
        "outputs",
        "goal002",
        "development",
        row$run_id,
        "primary"
      ),
      rescue_attempt_path = if (fit$rescue_used) {
        file.path(
          "outputs",
          "goal002",
          "development",
          row$run_id,
          "rescue"
        )
      } else {
        NA_character_
      },
      summary_path = file.path(
        "outputs",
        "goal002",
        "development",
        row$run_id,
        "summary.rds"
      ),
      elapsed_seconds = sum(vapply(
        fit$attempts,
        `[[`,
        numeric(1),
        "elapsed_seconds"
      )),
      manifest_hash = manifest_hash,
      freeze_hash = freeze_hash,
      artifacts_verified = TRUE,
      diagnostic_evidence = .goal002_diagnostic_evidence(
        fit$attempts[[fit$terminal_attempt_id]]
      ),
      posterior_pmf = summary$richness$pmf
    )
  )
  if (save_terminal) {
    saveRDS(record, file.path(run_dir, "terminal.rds"))
  }
  list(
    run_dir = run_dir,
    fit_path = fit_path,
    summary_path = summary_path,
    record = record
  )
}

testthat::test_that("pilot CLI accepts exactly the two documented phases", {
  testthat::expect_identical(
    goal002_parse_pilot_args(c("--phase", "development")),
    "development"
  )
  testthat::expect_identical(
    goal002_parse_pilot_args(c("--phase", "frozen")),
    "frozen"
  )
  for (bad in list(
    character(),
    "--phase",
    c("--phase", "other"),
    c("--phase", "development", "extra"),
    c("development", "--phase")
  )) {
    testthat::expect_error(
      goal002_parse_pilot_args(bad),
      "Usage"
    )
  }
})

testthat::test_that("terminal action skips only complete matching records", {
  root <- withr::local_tempdir()
  manifest_hash <- paste(rep("b", 64L), collapse = "")
  freeze_hash <- paste(rep("c", 64L), collapse = "")
  row <- goal002_development_manifest()[1L, ]
  run_dir <- file.path(
    root,
    "outputs",
    "goal002",
    "development",
    row$run_id
  )

  testthat::expect_identical(
    goal002_terminal_action(
      run_dir,
      row,
      manifest_hash,
      freeze_hash
    ),
    "run"
  )

  dir.create(run_dir, recursive = TRUE)
  testthat::expect_error(
    goal002_terminal_action(
      run_dir,
      row,
      manifest_hash,
      freeze_hash
    ),
    "partial"
  )

  unlink(run_dir, recursive = TRUE)
  artifact <- goal002_materialize_terminal_fixture(
    root,
    row,
    manifest_hash = manifest_hash,
    freeze_hash = freeze_hash
  )
  record <- artifact$record
  testthat::expect_identical(
    goal002_terminal_action(
      run_dir,
      row,
      manifest_hash,
      freeze_hash
    ),
    "skip"
  )

  record$manifest_hash <- paste(rep("d", 64L), collapse = "")
  saveRDS(record, file.path(run_dir, "terminal.rds"))
  testthat::expect_error(
    goal002_terminal_action(
      run_dir,
      row,
      manifest_hash,
      freeze_hash
    ),
    "hash"
  )
})

testthat::test_that("terminal skip requires complete readable artefacts", {
  root <- withr::local_tempdir()
  manifest_hash <- paste(rep("b", 64L), collapse = "")
  row <- goal002_development_manifest()[1L, ]

  make <- function(label, status = "primary_clean") {
    case_root <- file.path(root, label)
    dir.create(case_root)
    goal002_materialize_terminal_fixture(
      case_root,
      row,
      terminal_status = status,
      manifest_hash = manifest_hash
    )
  }
  assert_rejected <- function(artifact, pattern) {
    testthat::expect_error(
      goal002_terminal_action(
        artifact$run_dir,
        row,
        manifest_hash,
        NA_character_
      ),
      pattern
    )
  }

  valid <- make("valid")
  testthat::expect_identical(
    goal002_terminal_action(
      valid$run_dir,
      row,
      manifest_hash,
      NA_character_
    ),
    "skip"
  )

  missing_primary <- make("missing-primary")
  unlink(file.path(missing_primary$run_dir, "primary"), recursive = TRUE)
  assert_rejected(missing_primary, "attempt|artefact")

  missing_rescue <- make("missing-rescue", "rescue_clean")
  unlink(file.path(missing_rescue$run_dir, "rescue"), recursive = TRUE)
  assert_rejected(missing_rescue, "attempt|artefact")

  missing_summary <- make("missing-summary")
  unlink(missing_summary$summary_path)
  assert_rejected(missing_summary, "summary|artefact")

  missing_fit <- make("missing-fit")
  unlink(missing_fit$fit_path)
  assert_rejected(missing_fit, "fit|artefact")

  corrupt_summary <- make("corrupt-summary")
  writeBin(charToRaw("not an RDS"), corrupt_summary$summary_path)
  assert_rejected(corrupt_summary, "summary|unreadable|artefact")

  corrupt_fit <- make("corrupt-fit")
  writeBin(charToRaw("not an RDS"), corrupt_fit$fit_path)
  assert_rejected(corrupt_fit, "fit|unreadable|artefact")

  missing_output <- make("missing-output")
  fit <- readRDS(missing_output$fit_path)
  output <- file.path(
    root,
    "missing-output",
    fit$attempts$primary$output_files[[1L]]
  )
  unlink(output)
  assert_rejected(missing_output, "output|attempt|artefact")
})

testthat::test_that("terminal paths cannot escape or share run artefacts", {
  root <- withr::local_tempdir()
  manifest_hash <- paste(rep("b", 64L), collapse = "")
  row <- goal002_development_manifest()[1L, ]

  escaped <- goal002_materialize_terminal_fixture(
    file.path(root, "escaped"),
    row,
    manifest_hash = manifest_hash
  )
  record <- readRDS(file.path(escaped$run_dir, "terminal.rds"))
  record$summary_path <- file.path("..", "..", "outside.rds")
  saveRDS(record, file.path(escaped$run_dir, "terminal.rds"))
  testthat::expect_error(
    goal002_terminal_action(
      escaped$run_dir,
      row,
      manifest_hash,
      NA_character_
    ),
    "path|escape|summary"
  )

  shared <- goal002_materialize_terminal_fixture(
    file.path(root, "shared"),
    row,
    manifest_hash = manifest_hash
  )
  record <- readRDS(file.path(shared$run_dir, "terminal.rds"))
  record$summary_path <- record$primary_attempt_path
  saveRDS(record, file.path(shared$run_dir, "terminal.rds"))
  testthat::expect_error(
    goal002_terminal_action(
      shared$run_dir,
      row,
      manifest_hash,
      NA_character_
    ),
    "path|summary|shared"
  )
})

testthat::test_that("terminal evidence must agree with fit and summary", {
  root <- withr::local_tempdir()
  manifest_hash <- paste(rep("b", 64L), collapse = "")
  row <- goal002_development_manifest()[1L, ]

  mismatch <- goal002_materialize_terminal_fixture(
    file.path(root, "mismatch"),
    row,
    manifest_hash = manifest_hash
  )
  record <- readRDS(file.path(mismatch$run_dir, "terminal.rds"))
  record$observed_richness <- record$observed_richness + 1L
  saveRDS(record, file.path(mismatch$run_dir, "terminal.rds"))
  testthat::expect_error(
    goal002_terminal_action(
      mismatch$run_dir,
      row,
      manifest_hash,
      NA_character_
    ),
    "agree|observed|artefact"
  )

  diagnostic <- goal002_materialize_terminal_fixture(
    file.path(root, "diagnostic"),
    row,
    manifest_hash = manifest_hash
  )
  fit <- readRDS(diagnostic$fit_path)
  fit$attempts$primary$diagnostics$metrics$max_rhat <- 1.02
  saveRDS(fit, diagnostic$fit_path)
  testthat::expect_error(
    goal002_terminal_action(
      diagnostic$run_dir,
      row,
      manifest_hash,
      NA_character_
    ),
    "diagnostic|R-hat|rhat"
  )
})

testthat::test_that("terminal attempt seeds must match the manifest fit seed", {
  root <- withr::local_tempdir()
  manifest_hash <- paste(rep("b", 64L), collapse = "")
  row <- goal002_development_manifest()[2L, ]

  primary <- goal002_materialize_terminal_fixture(
    file.path(root, "primary"),
    row,
    manifest_hash = manifest_hash
  )
  primary_fit <- readRDS(primary$fit_path)
  primary_summary <- readRDS(primary$summary_path)
  primary_fit$attempts$primary$seed <- row$fit_seed + 1L
  primary_summary$metadata$terminal_attempt$seed <-
    primary_fit$attempts$primary$seed
  saveRDS(primary_fit, primary$fit_path)
  saveRDS(primary_summary, primary$summary_path)
  testthat::expect_error(
    goal002_terminal_action(
      primary$run_dir,
      row,
      manifest_hash,
      NA_character_
    ),
    "seed"
  )

  rescue <- goal002_materialize_terminal_fixture(
    file.path(root, "rescue"),
    row,
    terminal_status = "rescue_clean",
    manifest_hash = manifest_hash
  )
  rescue_fit <- readRDS(rescue$fit_path)
  rescue_summary <- readRDS(rescue$summary_path)
  rescue_fit$attempts$rescue$seed <- row$fit_seed + 500001L
  rescue_summary$metadata$terminal_attempt$seed <-
    rescue_fit$attempts$rescue$seed
  saveRDS(rescue_fit, rescue$fit_path)
  saveRDS(rescue_summary, rescue$summary_path)
  testthat::expect_error(
    goal002_terminal_action(
      rescue$run_dir,
      row,
      manifest_hash,
      NA_character_
    ),
    "seed"
  )
})

testthat::test_that("terminal data hash must match the manifest simulation", {
  root <- withr::local_tempdir()
  manifest_hash <- paste(rep("b", 64L), collapse = "")
  row <- goal002_development_manifest()[2L, ]
  simulation_row <- row
  simulation_row$simulation_seed <- row$simulation_seed + 1L

  artifact <- goal002_materialize_terminal_fixture(
    root,
    row,
    manifest_hash = manifest_hash,
    simulation_row = simulation_row
  )
  testthat::expect_error(
    goal002_terminal_action(
      artifact$run_dir,
      row,
      manifest_hash,
      NA_character_
    ),
    "simulation|data hash|manifest"
  )
})

testthat::test_that("development dispatcher resumes without replacing a run", {
  root <- withr::local_tempdir()
  dir.create(file.path(root, "config"))
  utils::write.csv(
    goal002_development_manifest(),
    file.path(root, "config", "goal002_development_manifest.csv"),
    row.names = FALSE,
    quote = TRUE
  )
  calls <- new.env(parent = emptyenv())
  calls$n <- 0L
  fake_runner <- function(row, run_dir, manifest_hash, freeze_hash) {
    calls$n <- calls$n + 1L
    goal002_materialize_terminal_fixture(
      root,
      row,
      manifest_hash = manifest_hash,
      freeze_hash = freeze_hash,
      save_terminal = FALSE
    )$record
  }

  first <- dispatch_goal002_pilot(
    phase = "development",
    project_root = root,
    run_row = fake_runner
  )
  testthat::expect_equal(calls$n, 6L)
  testthat::expect_true(all(first$action == "completed"))

  second <- dispatch_goal002_pilot(
    phase = "development",
    project_root = root,
    run_row = fake_runner
  )
  testthat::expect_equal(calls$n, 6L)
  testthat::expect_true(all(second$action == "skipped"))

  terminal_path <- file.path(
    root,
    "outputs",
    "goal002",
    "development",
    goal002_development_manifest()$run_id[1L],
    "terminal.rds"
  )
  terminal_before <- readRDS(terminal_path)
  terminal_before$manifest_hash <- paste(rep("d", 64L), collapse = "")
  saveRDS(terminal_before, terminal_path)
  testthat::expect_error(
    dispatch_goal002_pilot(
      phase = "development",
      project_root = root,
      run_row = fake_runner
    ),
    "hash"
  )
  testthat::expect_identical(readRDS(terminal_path), terminal_before)
  testthat::expect_equal(calls$n, 6L)
})

testthat::test_that("frozen dispatch requires a matching freeze record", {
  root <- withr::local_tempdir()
  dir.create(file.path(root, "config"))
  frozen <- goal002_frozen_manifest()
  utils::write.csv(
    frozen,
    file.path(root, "config", "goal002_frozen_manifest.csv"),
    row.names = FALSE,
    quote = TRUE
  )
  never_run <- function(...) {
    testthat::fail("Frozen runner must not be reached.")
  }

  testthat::expect_error(
    dispatch_goal002_pilot(
      phase = "frozen",
      project_root = root,
      run_row = never_run
    ),
    "freeze"
  )

  utils::write.csv(
    tibble::tibble(
      key = "frozen_manifest_hash",
      value = paste(rep("d", 64L), collapse = "")
    ),
    file.path(root, "config", "goal002_freeze.csv"),
    row.names = FALSE,
    quote = TRUE
  )
  testthat::expect_error(
    dispatch_goal002_pilot(
      phase = "frozen",
      project_root = root,
      run_row = never_run
    ),
    "manifest hash"
  )
})
