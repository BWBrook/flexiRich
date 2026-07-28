.goal002_manifest_fields <- c(
  "run_id",
  "run_type",
  "prior_profile",
  "cell_id",
  "true_richness",
  "n_occasions",
  "replicate",
  "simulation_seed",
  "fit_seed"
)

.goal002_terminal_fields <- c(
  "run_id",
  "run_type",
  "prior_profile",
  "cell_id",
  "true_richness",
  "n_occasions",
  "replicate",
  "simulation_seed",
  "fit_seed",
  "terminal_status",
  "rescue_used",
  "observed_richness",
  "data_hash",
  "model_hash",
  "primary_attempt_path",
  "rescue_attempt_path",
  "summary_path",
  "elapsed_seconds"
)

.goal002_terminal_statuses <- c(
  "primary_clean",
  "rescue_clean",
  "final_nonclean"
)

.stop_invalid_goal002_pilot <- function(message) {
  stop(message, call. = FALSE)
}

.goal002_pilot_scalar_integer <- function(
  x,
  name,
  lower = 0L,
  upper = .Machine$integer.max
) {
  valid <- is.numeric(x) &&
    !is.complex(x) &&
    !is.logical(x) &&
    length(x) == 1L &&
    !is.na(x) &&
    is.finite(x) &&
    x == trunc(x) &&
    x >= lower &&
    x <= upper
  if (!valid) {
    .stop_invalid_goal002_pilot(
      paste0(name, " must be one finite whole number in range.")
    )
  }
  as.integer(x)
}

.goal002_pilot_scalar_text <- function(x, name) {
  valid <- is.character(x) &&
    length(x) == 1L &&
    !is.na(x) &&
    nzchar(x)
  if (!valid) {
    .stop_invalid_goal002_pilot(
      paste0(name, " must be one non-empty character value.")
    )
  }
  x
}

.goal002_pilot_hash <- function(x) {
  digest::digest(x, algo = "sha256", serialize = TRUE)
}

.goal002_cells <- function() {
  tibble::tibble(
    cell_id = seq_len(6L),
    true_richness = c(8L, 20L, 27L, 8L, 20L, 27L),
    n_occasions = c(26L, 26L, 26L, 208L, 208L, 208L)
  )
}

.goal002_manifest_row_id <- function(
  phase,
  prior_profile,
  cell_id,
  replicate
) {
  profile_label <- switch(
    prior_profile,
    primary = "primary",
    sensitivity_membership = "membership",
    sensitivity_tail = "tail",
    .stop_invalid_goal002_pilot("Unknown prior profile.")
  )
  sprintf(
    "%s-c%02d-r%02d-%s",
    phase,
    cell_id,
    replicate,
    profile_label
  )
}

goal002_development_manifest <- function() {
  cells <- .goal002_cells()
  tibble::tibble(
    run_id = vapply(
      cells$cell_id,
      function(cell_id) {
        .goal002_manifest_row_id(
          "development",
          "primary",
          cell_id,
          1L
        )
      },
      character(1)
    ),
    run_type = rep("primary", 6L),
    prior_profile = rep("primary", 6L),
    cell_id = cells$cell_id,
    true_richness = cells$true_richness,
    n_occasions = cells$n_occasions,
    replicate = rep(1L, 6L),
    simulation_seed = 120020000L + cells$cell_id,
    fit_seed = 220020000L + cells$cell_id
  )
}

goal002_frozen_manifest <- function() {
  cells <- .goal002_cells()
  primary <- tidyr::crossing(
    cell_id = cells$cell_id,
    replicate = seq_len(10L)
  ) |>
    dplyr::left_join(cells, by = "cell_id") |>
    dplyr::mutate(
      run_id = vapply(
        seq_len(dplyr::n()),
        function(index) {
          .goal002_manifest_row_id(
            "frozen",
            "primary",
            cell_id[index],
            replicate[index]
          )
        },
        character(1)
      ),
      run_type = "primary",
      prior_profile = "primary",
      simulation_seed =
        320020000L + 100L * cell_id + replicate,
      fit_seed =
        420020000L + 100L * cell_id + replicate
    ) |>
    dplyr::select(dplyr::all_of(.goal002_manifest_fields))

  sensitivity_profiles <- c(
    "sensitivity_membership",
    "sensitivity_tail"
  )
  sensitivity <- tidyr::crossing(
    prior_profile = sensitivity_profiles,
    cell_id = cells$cell_id,
    replicate = seq_len(3L)
  ) |>
    dplyr::left_join(cells, by = "cell_id") |>
    dplyr::mutate(
      run_id = vapply(
        seq_len(dplyr::n()),
        function(index) {
          .goal002_manifest_row_id(
            "frozen",
            prior_profile[index],
            cell_id[index],
            replicate[index]
          )
        },
        character(1)
      ),
      run_type = "sensitivity",
      simulation_seed =
        320020000L + 100L * cell_id + replicate,
      fit_seed = dplyr::if_else(
        prior_profile == "sensitivity_membership",
        520020000L + 100L * cell_id + replicate,
        620020000L + 100L * cell_id + replicate
      )
    ) |>
    dplyr::select(dplyr::all_of(.goal002_manifest_fields))

  dplyr::bind_rows(primary, sensitivity)
}

validate_goal002_manifest <- function(manifest, phase) {
  phase <- .goal002_pilot_scalar_text(phase, "phase")
  if (!phase %in% c("development", "frozen")) {
    .stop_invalid_goal002_pilot(
      "phase must be exactly 'development' or 'frozen'."
    )
  }
  if (!is.data.frame(manifest)) {
    .stop_invalid_goal002_pilot("manifest must be a data frame.")
  }
  manifest <- tibble::as_tibble(manifest)
  if (!identical(names(manifest), .goal002_manifest_fields)) {
    .stop_invalid_goal002_pilot(
      "manifest fields differ from the frozen schema."
    )
  }
  canonical <- if (identical(phase, "development")) {
    goal002_development_manifest()
  } else {
    goal002_frozen_manifest()
  }
  if (!identical(manifest, canonical)) {
    .stop_invalid_goal002_pilot(
      paste0(
        phase,
        " manifest differs from its deterministic frozen rows."
      )
    )
  }
  TRUE
}

.goal002_manifest_hash <- function(manifest, phase) {
  validate_goal002_manifest(manifest, phase)
  .goal002_pilot_hash(tibble::as_tibble(manifest))
}

.goal002_run_value <- function(run_result, name, default = NULL) {
  if (is.data.frame(run_result)) {
    if (nrow(run_result) != 1L) {
      .stop_invalid_goal002_pilot(
        "run_result data frames must contain exactly one row."
      )
    }
    if (!name %in% names(run_result)) {
      return(default)
    }
    return(run_result[[name]][[1L]])
  }
  if (!is.list(run_result)) {
    .stop_invalid_goal002_pilot(
      "run_result must be a list or one-row data frame."
    )
  }
  if (!name %in% names(run_result)) {
    return(default)
  }
  run_result[[name]]
}

.goal002_profile_for_result <- function(run_result) {
  profile <- .goal002_run_value(
    run_result,
    "prior_profile",
    "primary"
  )
  if (is.list(profile)) {
    return(validate_goal002_profile(profile, type = "prior"))
  }
  profile <- .goal002_pilot_scalar_text(
    profile,
    "run_result$prior_profile"
  )
  profiles <- goal002_prior_profiles()
  if (!profile %in% names(profiles)) {
    .stop_invalid_goal002_pilot(
      "run_result$prior_profile is unknown."
    )
  }
  profiles[[profile]]
}

goal002_gate_values <- function(run_result, C) {
  C <- .goal002_pilot_scalar_integer(
    C,
    "C",
    lower = 1L
  )
  status <- .goal002_run_value(run_result, "terminal_status")
  if (!is.character(status) ||
      length(status) != 1L ||
      is.na(status) ||
      !status %in% .goal002_terminal_statuses) {
    .stop_invalid_goal002_pilot(
      "run_result$terminal_status is invalid."
    )
  }
  truth <- .goal002_pilot_scalar_integer(
    .goal002_run_value(run_result, "true_richness"),
    "run_result$true_richness",
    upper = C
  )
  observed <- .goal002_pilot_scalar_integer(
    .goal002_run_value(run_result, "observed_richness"),
    "run_result$observed_richness",
    upper = C
  )
  profile <- .goal002_profile_for_result(run_result)
  baseline <- lower_bound_prior_pmf(
    candidate_pool_size = C,
    observed_richness = observed,
    omega_alpha = profile$omega_alpha,
    omega_beta = profile$omega_beta
  )
  baseline_rps <- ranked_probability_score(baseline, truth)

  if (identical(status, "final_nonclean")) {
    return(tibble::tibble(
      covered_90 = FALSE,
      truth_probability = 0,
      posterior_mean = NA_real_,
      signed_error = NA_real_,
      absolute_error = as.numeric(C),
      squared_error = as.numeric(C)^2,
      rps = as.numeric(C),
      baseline_rps = baseline_rps,
      interval_width = NA_real_,
      prior_contraction = NA_real_,
      boundary_mass_observed = NA_real_,
      boundary_mass_candidate_pool = NA_real_
    ))
  }

  pmf <- .goal002_run_value(run_result, "posterior_pmf")
  validated_pmf <- tryCatch(
    .validate_richness_pmf(pmf),
    error = function(e) NULL
  )
  if (is.null(validated_pmf) ||
      !identical(validated_pmf$candidate_pool_size, C) ||
      any(validated_pmf$probability[
        validated_pmf$richness < observed
      ] > 1e-12)) {
    .stop_invalid_goal002_pilot(
      "A clean run requires a valid posterior PMF on 0:C."
    )
  }
  posterior <- discrete_richness_summary(
    pmf,
    levels = 0.9
  )
  interval <- posterior$intervals[["90"]]
  supplied_lower <- .goal002_run_value(
    run_result,
    "interval_90_lower",
    interval[["lower"]]
  )
  supplied_upper <- .goal002_run_value(
    run_result,
    "interval_90_upper",
    interval[["upper"]]
  )
  if (!identical(
    as.integer(c(supplied_lower, supplied_upper)),
    unname(interval)
  )) {
    .stop_invalid_goal002_pilot(
      "Supplied 90% interval disagrees with posterior_pmf."
    )
  }

  baseline_summary <- discrete_richness_summary(
    baseline,
    levels = 0.9
  )
  posterior_variance <- sum(
    (pmf$richness - posterior$mean)^2 * pmf$probability
  )
  baseline_variance <- sum(
    (baseline$richness - baseline_summary$mean)^2 *
      baseline$probability
  )
  prior_contraction <- if (baseline_variance == 0) {
    NA_real_
  } else {
    1 - posterior_variance / baseline_variance
  }
  signed_error <- posterior$mean - truth

  tibble::tibble(
    covered_90 =
      truth >= interval[["lower"]] &&
      truth <= interval[["upper"]],
    truth_probability =
      pmf$probability[pmf$richness == truth],
    posterior_mean = posterior$mean,
    signed_error = signed_error,
    absolute_error = abs(signed_error),
    squared_error = signed_error^2,
    rps = ranked_probability_score(pmf, truth),
    baseline_rps = baseline_rps,
    interval_width =
      as.numeric(interval[["upper"]] - interval[["lower"]]),
    prior_contraction = prior_contraction,
    boundary_mass_observed =
      pmf$probability[pmf$richness == observed],
    boundary_mass_candidate_pool =
      pmf$probability[pmf$richness == C]
  )
}

.goal002_nonempty_path <- function(x) {
  is.character(x) & !is.na(x) & nzchar(x)
}

.goal002_criterion <- function(
  criterion,
  numerator,
  denominator,
  statistic,
  threshold,
  passed,
  reason
) {
  criterion <- .goal002_pilot_scalar_integer(
    criterion,
    "criterion",
    lower = 19L,
    upper = 35L
  )
  if (!is.logical(passed) || length(passed) != 1L || is.na(passed)) {
    .stop_invalid_goal002_pilot(
      "criterion passed must be exactly TRUE or FALSE."
    )
  }
  tibble::tibble(
    criterion = criterion,
    numerator = as.numeric(numerator),
    denominator = as.numeric(denominator),
    statistic = as.numeric(statistic),
    threshold = as.character(threshold),
    passed = passed,
    reason = as.character(reason)
  )
}

.goal002_validate_results_shape <- function(results) {
  if (!is.data.frame(results)) {
    .stop_invalid_goal002_pilot("results must be a data frame.")
  }
  results <- tibble::as_tibble(results)
  missing <- setdiff(
    c(.goal002_terminal_fields, "posterior_pmf"),
    names(results)
  )
  if (length(missing) > 0L) {
    .stop_invalid_goal002_pilot(
      paste0(
        "results are missing required fields: ",
        paste(missing, collapse = ", "),
        "."
      )
    )
  }
  validate_goal002_manifest(
    results[.goal002_manifest_fields],
    "frozen"
  )
  if (!is.character(results$terminal_status) ||
      anyNA(results$terminal_status) ||
      any(!results$terminal_status %in% .goal002_terminal_statuses)) {
    .stop_invalid_goal002_pilot(
      "results contain an invalid terminal_status."
    )
  }
  if (!is.logical(results$rescue_used) ||
      anyNA(results$rescue_used)) {
    .stop_invalid_goal002_pilot(
      "results$rescue_used must be complete logical data."
    )
  }
  if (!is.integer(results$observed_richness) ||
      anyNA(results$observed_richness) ||
      any(results$observed_richness < 0L |
        results$observed_richness > 30L)) {
    .stop_invalid_goal002_pilot(
      "results$observed_richness is invalid."
    )
  }
  valid_hash <- function(x) {
    is.character(x) &&
      !anyNA(x) &&
      all(grepl("^[0-9a-f]{64}$", x))
  }
  if (!valid_hash(results$data_hash) ||
      !valid_hash(results$model_hash)) {
    .stop_invalid_goal002_pilot(
      "results contain invalid data or model hashes."
    )
  }
  if (!is.numeric(results$elapsed_seconds) ||
      anyNA(results$elapsed_seconds) ||
      any(!is.finite(results$elapsed_seconds)) ||
      any(results$elapsed_seconds < 0)) {
    .stop_invalid_goal002_pilot(
      "results$elapsed_seconds is invalid."
    )
  }
  if (!is.list(results$posterior_pmf)) {
    .stop_invalid_goal002_pilot(
      "results$posterior_pmf must be a list-column."
    )
  }
  results
}

.goal002_gate_table <- function(results, C) {
  gate_rows <- lapply(seq_len(nrow(results)), function(index) {
    gate <- goal002_gate_values(results[index, , drop = FALSE], C)
    dplyr::bind_cols(
      results[index, c(
        "run_id",
        "run_type",
        "prior_profile",
        "cell_id",
        "true_richness",
        "n_occasions",
        "replicate",
        "simulation_seed",
        "fit_seed",
        "terminal_status",
        "rescue_used",
        "observed_richness"
      )],
      gate
    )
  })
  dplyr::bind_rows(gate_rows)
}

.goal002_fixed_mean <- function(x) {
  if (anyNA(x)) NA_real_ else mean(x)
}

.goal002_fixed_median <- function(x) {
  if (anyNA(x)) NA_real_ else stats::median(x)
}

evaluate_goal002_gates <- function(results) {
  results <- .goal002_validate_results_shape(results)
  candidate_pool_size <- 30L
  gates <- .goal002_gate_table(results, candidate_pool_size)
  primary <- dplyr::filter(gates, run_type == "primary")
  sensitivity <- dplyr::filter(gates, run_type == "sensitivity")
  four_primary <- dplyr::filter(primary, n_occasions == 208L)
  six_primary <- dplyr::filter(primary, n_occasions == 26L)
  four_nonclean <- any(
    four_primary$terminal_status == "final_nonclean"
  )

  primary_path_ok <- .goal002_nonempty_path(
    results$primary_attempt_path
  )
  rescue_required <- results$rescue_used
  rescue_path_ok <- !rescue_required |
    .goal002_nonempty_path(results$rescue_attempt_path)
  summary_path_ok <- .goal002_nonempty_path(results$summary_path)
  addressed_paths <- c(
    results$primary_attempt_path[primary_path_ok],
    results$rescue_attempt_path[
      rescue_required &
        .goal002_nonempty_path(results$rescue_attempt_path)
    ]
  )
  unique_paths <- anyDuplicated(addressed_paths) == 0L
  attempts_ok <- primary_path_ok &
    rescue_path_ok &
    summary_path_ok
  criterion_19 <- .goal002_criterion(
    19L,
    sum(attempts_ok),
    nrow(results),
    sum(attempts_ok),
    "96/96 terminal rows and unique attempt addresses",
    all(attempts_ok) && unique_paths && nrow(results) == 96L,
    paste0(
      sum(attempts_ok),
      " of 96 rows retain required attempt and summary addresses; ",
      "attempt paths unique: ",
      unique_paths,
      "."
    )
  )

  clean_rows <- results$terminal_status != "final_nonclean"
  clean_inference <- vapply(
    results$posterior_pmf,
    function(pmf) !is.null(pmf),
    logical(1)
  )
  criterion_20 <- .goal002_criterion(
    20L,
    sum(clean_rows & clean_inference),
    sum(clean_rows),
    sum(clean_rows & clean_inference),
    "all terminal-clean fits satisfy the frozen diagnostic contract",
    all(!clean_rows | clean_inference),
    paste0(
      sum(clean_rows & clean_inference),
      " of ",
      sum(clean_rows),
      " terminal-clean rows expose validated inference."
    )
  )

  expected_rescue <- results$terminal_status != "primary_clean"
  rescue_contract <- results$rescue_used == expected_rescue &
    (!expected_rescue |
      .goal002_nonempty_path(results$rescue_attempt_path))
  criterion_21 <- .goal002_criterion(
    21L,
    sum(rescue_contract),
    nrow(results),
    sum(results$rescue_used),
    "at most one primary attempt plus one committed rescue",
    all(rescue_contract),
    paste0(
      sum(results$rescue_used),
      " rows used the single prespecified rescue configuration."
    )
  )

  clean_primary <- primary$terminal_status != "final_nonclean"
  clean_by_cell <- primary |>
    dplyr::mutate(clean = clean_primary) |>
    dplyr::group_by(cell_id) |>
    dplyr::summarise(
      clean = sum(clean),
      scheduled = dplyr::n(),
      .groups = "drop"
    )
  criterion_22_pass <- sum(clean_primary) >= 57L &&
    nrow(clean_by_cell) == 6L &&
    all(clean_by_cell$scheduled == 10L) &&
    all(clean_by_cell$clean >= 9L)
  criterion_22 <- .goal002_criterion(
    22L,
    sum(clean_primary),
    60L,
    min(clean_by_cell$clean),
    "at least 57/60 clean and at least 9/10 in every cell",
    criterion_22_pass,
    paste0(
      sum(clean_primary),
      " of 60 primary fits are clean; minimum cell count is ",
      min(clean_by_cell$clean),
      " of 10."
    )
  )

  nonclean_rows <- !clean_rows
  retained_nonclean <- nonclean_rows &
    primary_path_ok &
    rescue_path_ok &
    summary_path_ok
  criterion_23 <- .goal002_criterion(
    23L,
    sum(retained_nonclean),
    sum(nonclean_rows),
    sum(nonclean_rows),
    "every terminal non-clean fit remains reported",
    all(!nonclean_rows | retained_nonclean),
    paste0(
      sum(retained_nonclean),
      " of ",
      sum(nonclean_rows),
      " terminal non-clean rows remain addressable."
    )
  )

  sensitivity_nonclean <- results$run_type == "sensitivity" &
    nonclean_rows
  sensitivity_hidden <- vapply(
    results$posterior_pmf,
    is.null,
    logical(1)
  )
  criterion_24 <- .goal002_criterion(
    24L,
    sum(sensitivity_nonclean & sensitivity_hidden),
    sum(sensitivity_nonclean),
    sum(sensitivity_nonclean),
    "no posterior interpretation from terminal non-clean sensitivity fits",
    all(!sensitivity_nonclean | sensitivity_hidden),
    paste0(
      sum(sensitivity_nonclean & sensitivity_hidden),
      " of ",
      sum(sensitivity_nonclean),
      " terminal non-clean sensitivity rows suppress inference."
    )
  )

  coverage_by_cell <- four_primary |>
    dplyr::group_by(cell_id) |>
    dplyr::summarise(
      covered = sum(covered_90),
      scheduled = dplyr::n(),
      .groups = "drop"
    )
  criterion_25_pass <- !four_nonclean &&
    nrow(coverage_by_cell) == 3L &&
    all(coverage_by_cell$scheduled == 10L) &&
    all(coverage_by_cell$covered >= 8L)
  criterion_25 <- .goal002_criterion(
    25L,
    min(coverage_by_cell$covered),
    10L,
    min(coverage_by_cell$covered),
    "at least 8/10 covered in every four-year richness cell",
    criterion_25_pass,
    paste0(
      "Minimum cell coverage is ",
      min(coverage_by_cell$covered),
      " of 10; four-year terminal non-clean present: ",
      four_nonclean,
      "."
    )
  )

  median_absolute_error <- .goal002_fixed_median(
    four_primary$absolute_error
  )
  criterion_26 <- .goal002_criterion(
    26L,
    sum(four_primary$absolute_error <= 2),
    30L,
    median_absolute_error,
    "median absolute error <= 2 species",
    !four_nonclean &&
      is.finite(median_absolute_error) &&
      median_absolute_error <= 2,
    paste0(
      "Four-year median absolute error is ",
      format(median_absolute_error),
      "; terminal non-clean present: ",
      four_nonclean,
      "."
    )
  )

  observed_absolute_error <- abs(
    four_primary$observed_richness -
      four_primary$true_richness
  )
  median_observed_error <- .goal002_fixed_median(
    observed_absolute_error
  )
  criterion_27 <- .goal002_criterion(
    27L,
    sum(
      four_primary$absolute_error < observed_absolute_error
    ),
    30L,
    median_absolute_error,
    paste0(
      "posterior median absolute error < raw median ",
      "absolute error (",
      format(median_observed_error),
      ")"
    ),
    !four_nonclean &&
      is.finite(median_absolute_error) &&
      is.finite(median_observed_error) &&
      median_absolute_error < median_observed_error,
    paste0(
      "Posterior and raw four-year median absolute errors are ",
      format(median_absolute_error),
      " and ",
      format(median_observed_error),
      ", respectively."
    )
  )

  median_rps <- .goal002_fixed_median(four_primary$rps)
  median_baseline_rps <- .goal002_fixed_median(
    four_primary$baseline_rps
  )
  criterion_28 <- .goal002_criterion(
    28L,
    sum(four_primary$rps < four_primary$baseline_rps),
    30L,
    median_rps,
    paste0(
      "median posterior RPS < median baseline RPS (",
      format(median_baseline_rps),
      ")"
    ),
    !four_nonclean &&
      is.finite(median_rps) &&
      is.finite(median_baseline_rps) &&
      median_rps < median_baseline_rps,
    paste0(
      "Four-year posterior and baseline median RPS are ",
      format(median_rps),
      " and ",
      format(median_baseline_rps),
      ", respectively."
    )
  )

  maximum_absolute_error <- max(four_primary$absolute_error)
  criterion_29 <- .goal002_criterion(
    29L,
    sum(four_primary$absolute_error < 6),
    30L,
    maximum_absolute_error,
    "maximum absolute error < 6 species",
    !four_nonclean && maximum_absolute_error < 6,
    paste0(
      "Maximum four-year absolute error is ",
      format(maximum_absolute_error),
      "; terminal non-clean present: ",
      four_nonclean,
      "."
    )
  )

  six_coverage <- sum(six_primary$covered_90)
  criterion_30 <- .goal002_criterion(
    30L,
    six_coverage,
    30L,
    six_coverage,
    "at least 24/30 six-month intervals cover truth",
    nrow(six_primary) == 30L && six_coverage >= 24L,
    paste0(
      six_coverage,
      " of 30 six-month intervals cover truth."
    )
  )

  six_month_primary_summary <- tibble::tibble(
    planned_n = as.integer(nrow(six_primary)),
    clean_n = as.integer(sum(
      six_primary$terminal_status != "final_nonclean"
    )),
    signed_bias = .goal002_fixed_mean(six_primary$signed_error),
    median_absolute_error = .goal002_fixed_median(
      six_primary$absolute_error
    ),
    mean_interval_width = .goal002_fixed_mean(
      six_primary$interval_width
    ),
    mean_prior_contraction = .goal002_fixed_mean(
      six_primary$prior_contraction
    ),
    mean_lower_boundary_mass = .goal002_fixed_mean(
      six_primary$boundary_mass_observed
    ),
    mean_upper_boundary_mass = .goal002_fixed_mean(
      six_primary$boundary_mass_candidate_pool
    )
  )
  criterion_31 <- .goal002_criterion(
    31L,
    nrow(six_primary),
    30L,
    six_month_primary_summary$clean_n,
    "report six-month behaviour with planned and clean counts",
    nrow(six_primary) == 30L,
    paste0(
      "Six-month summaries retain ",
      nrow(six_primary),
      " planned rows and ",
      six_month_primary_summary$clean_n,
      " clean rows; no hard accuracy threshold applied."
    )
  )

  criterion_32 <- .goal002_criterion(
    32L,
    nrow(sensitivity),
    36L,
    sum(sensitivity$terminal_status == "final_nonclean"),
    "all 36 sensitivity fits and non-clean states reported",
    nrow(sensitivity) == 36L,
    paste0(
      nrow(sensitivity),
      " sensitivity rows reported, including ",
      sum(sensitivity$terminal_status == "final_nonclean"),
      " terminal non-clean rows."
    )
  )

  primary_pairs <- primary |>
    dplyr::select(
      cell_id,
      n_occasions,
      replicate,
      primary_terminal_status = terminal_status,
      primary_posterior_mean = posterior_mean
    )
  sensitivity_shift <- sensitivity |>
    dplyr::left_join(
      primary_pairs,
      by = c("cell_id", "n_occasions", "replicate")
    ) |>
    dplyr::mutate(
      pair_nonclean =
        terminal_status == "final_nonclean" |
        primary_terminal_status == "final_nonclean",
      absolute_shift = dplyr::if_else(
        pair_nonclean,
        as.numeric(candidate_pool_size),
        abs(posterior_mean - primary_posterior_mean)
      )
    )
  four_sensitivity <- dplyr::filter(
    sensitivity_shift,
    n_occasions == 208L
  )
  sensitivity_by_profile <- four_sensitivity |>
    dplyr::group_by(prior_profile) |>
    dplyr::summarise(
      planned = dplyr::n(),
      clean = sum(!pair_nonclean),
      median_absolute_shift =
        .goal002_fixed_median(absolute_shift),
      maximum_absolute_shift = max(absolute_shift),
      .groups = "drop"
    )
  four_sensitivity_nonclean <- any(
    four_sensitivity$pair_nonclean
  )
  criterion_33 <- .goal002_criterion(
    33L,
    sum(
      sensitivity_by_profile$planned == 9L &
        sensitivity_by_profile$median_absolute_shift <= 1
    ),
    2L,
    max(sensitivity_by_profile$median_absolute_shift),
    "median absolute shift <= 1 in each four-year sensitivity profile",
    !four_sensitivity_nonclean &&
      nrow(sensitivity_by_profile) == 2L &&
      all(sensitivity_by_profile$planned == 9L) &&
      all(sensitivity_by_profile$median_absolute_shift <= 1),
    paste0(
      "Largest profile median absolute shift is ",
      format(max(
        sensitivity_by_profile$median_absolute_shift
      )),
      "; non-clean pair present: ",
      four_sensitivity_nonclean,
      "."
    )
  )
  maximum_shift <- max(four_sensitivity$absolute_shift)
  criterion_34 <- .goal002_criterion(
    34L,
    sum(four_sensitivity$absolute_shift <= 3),
    18L,
    maximum_shift,
    "no four-year sensitivity shift > 3 species",
    !four_sensitivity_nonclean &&
      nrow(four_sensitivity) == 18L &&
      maximum_shift <= 3,
    paste0(
      "Maximum four-year sensitivity shift is ",
      format(maximum_shift),
      "; non-clean pair present: ",
      four_sensitivity_nonclean,
      "."
    )
  )

  six_sensitivity <- dplyr::filter(
    sensitivity_shift,
    n_occasions == 26L
  )
  six_month_sensitivity_summary <- tibble::tibble(
    planned_n = as.integer(nrow(six_sensitivity)),
    clean_pair_n = as.integer(sum(!six_sensitivity$pair_nonclean)),
    median_absolute_shift = .goal002_fixed_median(
      six_sensitivity$absolute_shift
    ),
    maximum_absolute_shift = max(
      six_sensitivity$absolute_shift
    )
  )
  criterion_35 <- .goal002_criterion(
    35L,
    nrow(six_sensitivity),
    18L,
    six_month_sensitivity_summary$clean_pair_n,
    "report six-month sensitivity without a hard stability threshold",
    nrow(six_sensitivity) == 18L,
    paste0(
      "Six-month sensitivity retains ",
      nrow(six_sensitivity),
      " planned pairs and ",
      six_month_sensitivity_summary$clean_pair_n,
      " clean pairs; no hard threshold applied."
    )
  )

  result <- c(
    stats::setNames(
      list(
        criterion_19,
        criterion_20,
        criterion_21,
        criterion_22,
        criterion_23,
        criterion_24,
        criterion_25,
        criterion_26,
        criterion_27,
        criterion_28,
        criterion_29,
        criterion_30,
        criterion_31,
        criterion_32,
        criterion_33,
        criterion_34,
        criterion_35
      ),
      paste0("criterion_", 19:35)
    ),
    list(
      primary_gate_values = primary,
      sensitivity_gate_values = sensitivity_shift,
      four_year_coverage_by_cell = coverage_by_cell,
      clean_primary_by_cell = clean_by_cell,
      four_year_sensitivity_by_profile =
        sensitivity_by_profile,
      six_month_primary_summary = six_month_primary_summary,
      six_month_sensitivity_summary =
        six_month_sensitivity_summary
    )
  )
  result
}

goal002_parse_pilot_args <- function(args) {
  valid <- is.character(args) &&
    identical(length(args), 2L) &&
    identical(args[[1L]], "--phase") &&
    args[[2L]] %in% c("development", "frozen")
  if (!valid) {
    .stop_invalid_goal002_pilot(paste0(
      "Usage: Rscript scripts/run_goal002_pilot.R ",
      "--phase development|frozen"
    ))
  }
  args[[2L]]
}

.goal002_valid_sha256 <- function(x) {
  is.character(x) &&
    length(x) == 1L &&
    !is.na(x) &&
    grepl("^[0-9a-f]{64}$", x)
}

.goal002_validate_terminal_record <- function(
  record,
  manifest_row,
  manifest_hash,
  freeze_hash
) {
  if (!is.list(record)) {
    .stop_invalid_goal002_pilot(
      "terminal record must be a named list."
    )
  }
  missing <- setdiff(
    c(
      .goal002_terminal_fields,
      "manifest_hash",
      "freeze_hash"
    ),
    names(record)
  )
  if (length(missing) > 0L) {
    .stop_invalid_goal002_pilot(
      paste0(
        "terminal record is incomplete: ",
        paste(missing, collapse = ", "),
        "."
      )
    )
  }
  for (field in .goal002_manifest_fields) {
    expected <- manifest_row[[field]][[1L]]
    if (!identical(record[[field]], expected)) {
      .stop_invalid_goal002_pilot(
        paste0("terminal record altered manifest field ", field, ".")
      )
    }
  }
  if (!identical(record$manifest_hash, manifest_hash) ||
      !identical(record$freeze_hash, freeze_hash)) {
    .stop_invalid_goal002_pilot(
      "terminal record hash does not match the active protocol."
    )
  }
  if (!.goal002_valid_sha256(record$data_hash) ||
      !.goal002_valid_sha256(record$model_hash)) {
    .stop_invalid_goal002_pilot(
      "terminal record has an invalid data or model hash."
    )
  }
  status <- record$terminal_status
  if (!is.character(status) ||
      length(status) != 1L ||
      is.na(status) ||
      !status %in% .goal002_terminal_statuses) {
    .stop_invalid_goal002_pilot(
      "terminal record has an invalid status."
    )
  }
  if (!is.logical(record$rescue_used) ||
      length(record$rescue_used) != 1L ||
      is.na(record$rescue_used) ||
      !identical(
        record$rescue_used,
        !identical(status, "primary_clean")
      )) {
    .stop_invalid_goal002_pilot(
      "terminal record rescue status is inconsistent."
    )
  }
  .goal002_pilot_scalar_integer(
    record$observed_richness,
    "terminal observed_richness",
    upper = 30L
  )
  if (!.goal002_nonempty_path(record$primary_attempt_path) ||
      !.goal002_nonempty_path(record$summary_path) ||
      (record$rescue_used &&
        !.goal002_nonempty_path(record$rescue_attempt_path)) ||
      (!record$rescue_used &&
        !(is.character(record$rescue_attempt_path) &&
          length(record$rescue_attempt_path) == 1L &&
          is.na(record$rescue_attempt_path)))) {
    .stop_invalid_goal002_pilot(
      "terminal record attempt or summary paths are incomplete."
    )
  }
  if (!is.numeric(record$elapsed_seconds) ||
      length(record$elapsed_seconds) != 1L ||
      is.na(record$elapsed_seconds) ||
      !is.finite(record$elapsed_seconds) ||
      record$elapsed_seconds < 0) {
    .stop_invalid_goal002_pilot(
      "terminal record elapsed_seconds is invalid."
    )
  }
  TRUE
}

goal002_terminal_action <- function(
  run_dir,
  manifest_row,
  manifest_hash,
  freeze_hash = NA_character_
) {
  .goal002_pilot_scalar_text(run_dir, "run_dir")
  if (!tibble::is_tibble(manifest_row) ||
      nrow(manifest_row) != 1L ||
      !identical(names(manifest_row), .goal002_manifest_fields)) {
    .stop_invalid_goal002_pilot(
      "manifest_row must be one canonical manifest row."
    )
  }
  if (!.goal002_valid_sha256(manifest_hash)) {
    .stop_invalid_goal002_pilot("manifest_hash is invalid.")
  }
  if (!(is.character(freeze_hash) &&
    length(freeze_hash) == 1L &&
    (is.na(freeze_hash) || .goal002_valid_sha256(freeze_hash)))) {
    .stop_invalid_goal002_pilot("freeze_hash is invalid.")
  }

  if (!file.exists(run_dir) && !dir.exists(run_dir)) {
    return("run")
  }
  if (!dir.exists(run_dir)) {
    .stop_invalid_goal002_pilot(
      "run path exists but is not a directory."
    )
  }
  terminal_path <- file.path(run_dir, "terminal.rds")
  if (!file.exists(terminal_path)) {
    .stop_invalid_goal002_pilot(
      "run directory is partial; refusing to overwrite it."
    )
  }
  record <- tryCatch(
    readRDS(terminal_path),
    error = function(e) {
      .stop_invalid_goal002_pilot(
        "terminal record is unreadable; refusing overwrite."
      )
    }
  )
  .goal002_validate_terminal_record(
    record,
    manifest_row,
    manifest_hash,
    freeze_hash
  )
  "skip"
}

.goal002_atomic_save_rds <- function(value, path) {
  if (file.exists(path) || dir.exists(path)) {
    .stop_invalid_goal002_pilot(
      paste0("immutable output already exists: ", path)
    )
  }
  directory <- dirname(path)
  if (!dir.exists(directory) &&
      !dir.create(directory, recursive = TRUE, showWarnings = FALSE)) {
    .stop_invalid_goal002_pilot(
      paste0("could not create output directory: ", directory)
    )
  }
  temporary <- tempfile(
    pattern = paste0(".", basename(path), "-"),
    tmpdir = directory
  )
  on.exit(unlink(temporary, force = TRUE), add = TRUE)
  saveRDS(value, temporary, version = 3L)
  if (!file.rename(temporary, path)) {
    .stop_invalid_goal002_pilot(
      paste0("could not atomically publish ", path, ".")
    )
  }
  invisible(path)
}

.goal002_atomic_write_csv <- function(value, path) {
  directory <- dirname(path)
  if (!dir.exists(directory) &&
      !dir.create(directory, recursive = TRUE, showWarnings = FALSE)) {
    .stop_invalid_goal002_pilot(
      paste0("could not create output directory: ", directory)
    )
  }
  temporary <- tempfile(
    pattern = paste0(".", basename(path), "-"),
    tmpdir = directory
  )
  on.exit(unlink(temporary, force = TRUE), add = TRUE)
  utils::write.csv(
    value,
    temporary,
    row.names = FALSE,
    quote = TRUE,
    na = ""
  )
  if (!file.rename(temporary, path)) {
    .stop_invalid_goal002_pilot(
      paste0("could not atomically update ", path, ".")
    )
  }
  invisible(path)
}

.goal002_read_manifest <- function(project_root, phase) {
  path <- file.path(
    project_root,
    "config",
    paste0("goal002_", phase, "_manifest.csv")
  )
  if (!file.exists(path)) {
    .stop_invalid_goal002_pilot(
      paste0("missing ", phase, " manifest: ", path)
    )
  }
  manifest <- tibble::as_tibble(utils::read.csv(
    path,
    stringsAsFactors = FALSE,
    check.names = FALSE
  ))
  validate_goal002_manifest(manifest, phase)
  manifest
}

.goal002_freeze_value <- function(freeze, key) {
  index <- match(key, freeze$key)
  if (is.na(index)) NULL else freeze$value[[index]]
}

.goal002_git_commit_exists <- function(project_root, commit) {
  if (!is.character(commit) ||
      length(commit) != 1L ||
      is.na(commit) ||
      !grepl("^[0-9a-f]{40}$", commit)) {
    return(FALSE)
  }
  status <- suppressWarnings(system2(
    "git",
    c("-C", project_root, "cat-file", "-e", paste0(commit, "^{commit}")),
    stdout = FALSE,
    stderr = FALSE
  ))
  identical(status, 0L)
}

.goal002_scoring_contract_hash <- function() {
  functions <- c(
    "lower_bound_prior_pmf",
    "discrete_richness_summary",
    "ranked_probability_score",
    "goal002_gate_values",
    "evaluate_goal002_gates"
  )
  value <- lapply(functions, function(name) {
    fn <- get(name, mode = "function", inherits = TRUE)
    list(
      name = name,
      formals = formals(fn),
      body = body(fn)
    )
  })
  .goal002_pilot_hash(value)
}

.goal002_verify_freeze <- function(
  project_root,
  manifest,
  manifest_hash
) {
  freeze_path <- file.path(
    project_root,
    "config",
    "goal002_freeze.csv"
  )
  if (!file.exists(freeze_path)) {
    .stop_invalid_goal002_pilot(
      "frozen dispatch requires config/goal002_freeze.csv."
    )
  }
  freeze <- tibble::as_tibble(utils::read.csv(
    freeze_path,
    stringsAsFactors = FALSE,
    check.names = FALSE
  ))
  if (!identical(names(freeze), c("key", "value")) ||
      nrow(freeze) == 0L ||
      !is.character(freeze$key) ||
      !is.character(freeze$value) ||
      anyNA(freeze) ||
      any(!nzchar(freeze$key)) ||
      any(!nzchar(freeze$value)) ||
      anyDuplicated(freeze$key)) {
    .stop_invalid_goal002_pilot(
      "freeze record must have unique, complete key/value rows."
    )
  }
  frozen_hash <- .goal002_freeze_value(
    freeze,
    "frozen_manifest_hash"
  )
  if (!identical(frozen_hash, manifest_hash)) {
    .stop_invalid_goal002_pilot(
      "freeze record frozen manifest hash does not match."
    )
  }

  required_keys <- c(
    "implementation_git_commit",
    "audit_git_commit",
    "audit_verdict",
    "prior_decision_git_commit",
    "stan_source_sha256",
    "prior_profile_ids",
    "prior_profiles_hash",
    "sampler_profile_ids",
    "sampler_profiles_hash",
    "diagnostic_thresholds_hash",
    "scoring_contract_hash",
    "development_manifest_hash",
    "frozen_manifest_hash",
    "cmdstanr_version",
    "cmdstan_version",
    "r_version",
    "freeze_time_utc"
  )
  missing <- setdiff(required_keys, freeze$key)
  if (length(missing) > 0L) {
    .stop_invalid_goal002_pilot(
      paste0(
        "freeze record is missing keys: ",
        paste(missing, collapse = ", "),
        "."
      )
    )
  }
  commit_keys <- c(
    "implementation_git_commit",
    "audit_git_commit",
    "prior_decision_git_commit"
  )
  if (any(!vapply(
    commit_keys,
    function(key) {
      .goal002_git_commit_exists(
        project_root,
        .goal002_freeze_value(freeze, key)
      )
    },
    logical(1)
  ))) {
    .stop_invalid_goal002_pilot(
      "freeze record contains an unavailable Git commit."
    )
  }
  if (!.goal002_freeze_value(freeze, "audit_verdict") %in%
      c("READY", "READY WITH CORRECTIONS")) {
    .stop_invalid_goal002_pilot(
      "freeze record audit verdict does not permit execution."
    )
  }

  stan_hash <- digest::digest(
    file = file.path(project_root, "stan", "flexirich_g.stan"),
    algo = "sha256",
    serialize = FALSE
  )
  if (!identical(
    .goal002_freeze_value(freeze, "stan_source_sha256"),
    stan_hash
  )) {
    .stop_invalid_goal002_pilot(
      "freeze record Stan source hash does not match."
    )
  }
  r_paths <- sort(list.files(
    file.path(project_root, "R"),
    pattern = "\\.R$",
    full.names = FALSE
  ))
  r_keys <- paste0("r_source_sha256:R/", r_paths)
  if (!setequal(
    freeze$key[startsWith(freeze$key, "r_source_sha256:")],
    r_keys
  )) {
    .stop_invalid_goal002_pilot(
      "freeze record R source hash inventory does not match."
    )
  }
  for (index in seq_along(r_paths)) {
    current <- digest::digest(
      file = file.path(project_root, "R", r_paths[[index]]),
      algo = "sha256",
      serialize = FALSE
    )
    if (!identical(
      .goal002_freeze_value(freeze, r_keys[[index]]),
      current
    )) {
      .stop_invalid_goal002_pilot(
        paste0("freeze record R source hash differs: ", r_paths[[index]])
      )
    }
  }

  profiles <- goal002_prior_profiles()
  samplers <- goal002_sampler_profiles()
  expected_values <- c(
    prior_profile_ids = paste(
      vapply(profiles, `[[`, character(1), "profile_id"),
      collapse = ","
    ),
    prior_profiles_hash = .goal002_pilot_hash(profiles),
    sampler_profile_ids = paste(
      vapply(samplers, `[[`, character(1), "profile_id"),
      collapse = ","
    ),
    sampler_profiles_hash = .goal002_pilot_hash(samplers),
    diagnostic_thresholds_hash =
      .goal002_pilot_hash(goal002_diagnostic_thresholds()),
    scoring_contract_hash = .goal002_scoring_contract_hash()
  )
  for (key in names(expected_values)) {
    if (!identical(
      .goal002_freeze_value(freeze, key),
      expected_values[[key]]
    )) {
      .stop_invalid_goal002_pilot(
        paste0("freeze record ", key, " does not match.")
      )
    }
  }

  development <- .goal002_read_manifest(
    project_root,
    "development"
  )
  if (!identical(
    .goal002_freeze_value(freeze, "development_manifest_hash"),
    .goal002_manifest_hash(development, "development")
  )) {
    .stop_invalid_goal002_pilot(
      "freeze record development manifest hash does not match."
    )
  }
  if (!identical(
    .goal002_freeze_value(freeze, "cmdstanr_version"),
    as.character(utils::packageVersion("cmdstanr"))
  ) ||
      !identical(
        .goal002_freeze_value(freeze, "cmdstan_version"),
        as.character(cmdstanr::cmdstan_version())
      ) ||
      !identical(
        .goal002_freeze_value(freeze, "r_version"),
        as.character(getRversion())
      )) {
    .stop_invalid_goal002_pilot(
      "freeze record runtime versions do not match."
    )
  }
  freeze_hash <- .goal002_pilot_hash(freeze)
  list(record = freeze, freeze_hash = freeze_hash)
}

.goal002_relative_to <- function(path, project_root) {
  root <- paste0(
    normalizePath(project_root, mustWork = TRUE),
    .Platform$file.sep
  )
  absolute <- normalizePath(path, mustWork = TRUE)
  if (!startsWith(absolute, root)) {
    .stop_invalid_goal002_pilot(
      "pilot output escaped the project root."
    )
  }
  substring(absolute, nchar(root) + 1L)
}

.goal002_execute_manifest_row <- function(
  row,
  run_dir,
  manifest_hash,
  freeze_hash,
  project_root
) {
  config <- flexirich_sim_config(
    candidate_pool_size = 30L,
    true_richness = row$true_richness,
    n_cameras = 9L,
    n_occasions = row$n_occasions,
    occasion_days = 7L,
    seed = row$simulation_seed
  )
  simulation <- simulate_flexirich_g(config)
  data <- sim_to_flexirich_g_data(simulation)
  profile <- goal002_prior_profiles()[[row$prior_profile]]
  fit <- fit_flexirich_g(
    data = data,
    seed = row$fit_seed,
    prior_profile = profile,
    output_dir = run_dir,
    allow_rescue = TRUE
  )
  summary <- summarise_flexirich_g(
    fit,
    species_ids = data$candidate_ids
  )
  summary_path <- file.path(run_dir, "summary.rds")
  fit_path <- file.path(run_dir, "fit.rds")
  .goal002_atomic_save_rds(summary, summary_path)
  .goal002_atomic_save_rds(fit, fit_path)

  elapsed <- sum(vapply(
    fit$attempts,
    function(attempt) attempt$elapsed_seconds,
    numeric(1)
  ))
  terminal <- c(
    as.list(row),
    list(
      terminal_status = fit$terminal_status,
      rescue_used = fit$rescue_used,
      observed_richness = as.integer(sum(fit$detected_ever)),
      data_hash = fit$data_hash,
      model_hash = fit$model_source_hash,
      primary_attempt_path = .goal002_relative_to(
        file.path(run_dir, "primary"),
        project_root
      ),
      rescue_attempt_path = if (fit$rescue_used) {
        .goal002_relative_to(
          file.path(run_dir, "rescue"),
          project_root
        )
      } else {
        NA_character_
      },
      summary_path = .goal002_relative_to(
        summary_path,
        project_root
      ),
      elapsed_seconds = elapsed,
      manifest_hash = manifest_hash,
      freeze_hash = freeze_hash,
      posterior_pmf = if (is.null(summary$richness)) {
        NULL
      } else {
        summary$richness$pmf
      }
    )
  )
  terminal
}

.goal002_terminal_status_row <- function(record, action) {
  values <- record[c(
    .goal002_terminal_fields,
    "manifest_hash",
    "freeze_hash"
  )]
  values$action <- action
  tibble::as_tibble(values)
}

dispatch_goal002_pilot <- function(
  phase,
  project_root = .goal002_project_root(),
  run_row = NULL
) {
  phase <- goal002_parse_pilot_args(c("--phase", phase))
  project_root <- normalizePath(project_root, mustWork = TRUE)
  manifest <- .goal002_read_manifest(project_root, phase)
  manifest_hash <- .goal002_manifest_hash(manifest, phase)
  freeze_hash <- NA_character_
  if (identical(phase, "frozen")) {
    freeze <- .goal002_verify_freeze(
      project_root,
      manifest,
      manifest_hash
    )
    freeze_hash <- freeze$freeze_hash
  }
  if (is.null(run_row)) {
    run_row <- function(
      row,
      run_dir,
      manifest_hash,
      freeze_hash
    ) {
      .goal002_execute_manifest_row(
        row,
        run_dir,
        manifest_hash,
        freeze_hash,
        project_root
      )
    }
  }
  if (!is.function(run_row)) {
    .stop_invalid_goal002_pilot("run_row must be a function.")
  }

  phase_dir <- file.path(
    project_root,
    "outputs",
    "goal002",
    phase
  )
  dir.create(phase_dir, recursive = TRUE, showWarnings = FALSE)
  statuses <- vector("list", nrow(manifest))
  for (index in seq_len(nrow(manifest))) {
    active_manifest <- .goal002_read_manifest(
      project_root,
      phase
    )
    active_manifest_hash <- .goal002_manifest_hash(
      active_manifest,
      phase
    )
    if (!identical(active_manifest_hash, manifest_hash)) {
      .stop_invalid_goal002_pilot(
        "manifest hash changed during dispatch."
      )
    }
    if (identical(phase, "frozen")) {
      active_freeze <- .goal002_verify_freeze(
        project_root,
        active_manifest,
        active_manifest_hash
      )
      if (!identical(active_freeze$freeze_hash, freeze_hash)) {
        .stop_invalid_goal002_pilot(
          "freeze hash changed during dispatch."
        )
      }
    }
    row <- manifest[index, ]
    run_dir <- file.path(phase_dir, row$run_id)
    action <- goal002_terminal_action(
      run_dir,
      row,
      manifest_hash,
      freeze_hash
    )
    if (identical(action, "skip")) {
      record <- readRDS(file.path(run_dir, "terminal.rds"))
      statuses[[index]] <- .goal002_terminal_status_row(
        record,
        "skipped"
      )
      next
    }

    record <- run_row(
      row,
      run_dir,
      manifest_hash,
      freeze_hash
    )
    if (!dir.exists(run_dir) &&
        !dir.create(run_dir, recursive = TRUE, showWarnings = FALSE)) {
      .stop_invalid_goal002_pilot(
        paste0("runner did not create run directory ", run_dir, ".")
      )
    }
    .goal002_validate_terminal_record(
      record,
      row,
      manifest_hash,
      freeze_hash
    )
    .goal002_atomic_save_rds(
      record,
      file.path(run_dir, "terminal.rds")
    )
    statuses[[index]] <- .goal002_terminal_status_row(
      record,
      "completed"
    )
  }
  status_table <- dplyr::bind_rows(statuses)
  .goal002_atomic_write_csv(
    status_table,
    file.path(phase_dir, "run-status.csv")
  )
  status_table
}
