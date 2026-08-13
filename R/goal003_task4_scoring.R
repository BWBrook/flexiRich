.goal003_task4_scoring_stop <- function(message) {
  stop(message, call. = FALSE)
}

.goal003_task4_validate_truth <- function(truth) {
  required <- c(
    "scenario_id", "true_richness", "observed_richness",
    "true_new_species", "species", "cameras"
  )
  species_fields <- c(
    "species_id", "member", "latent_normal", "alpha", "guild",
    "season_phase", "training_detected", "future_detected",
    "future_first_detection"
  )
  valid <- is.list(truth) &&
    identical(names(truth), required) &&
    is.character(truth$scenario_id) &&
    length(truth$scenario_id) == 1L &&
    !is.na(truth$scenario_id) &&
    tibble::is_tibble(truth$species) &&
    identical(names(truth$species), species_fields) &&
    nrow(truth$species) > 0L &&
    is.character(truth$species$species_id) &&
    !anyNA(truth$species$species_id) &&
    !anyDuplicated(truth$species$species_id) &&
    is.logical(truth$species$member) &&
    is.logical(truth$species$training_detected) &&
    is.logical(truth$species$future_detected) &&
    is.logical(truth$species$future_first_detection) &&
    !anyNA(truth$species$member) &&
    !anyNA(truth$species$training_detected) &&
    !anyNA(truth$species$future_detected) &&
    !anyNA(truth$species$future_first_detection) &&
    identical(
      truth$species$future_first_detection,
      !truth$species$training_detected & truth$species$future_detected
    ) &&
    identical(truth$true_richness, as.integer(sum(truth$species$member))) &&
    identical(
      truth$observed_richness,
      as.integer(sum(truth$species$training_detected))
    ) &&
    identical(
      truth$true_new_species,
      as.integer(sum(truth$species$future_first_detection))
    )
  if (!valid) {
    .goal003_task4_scoring_stop("truth must be canonical Task 4 truth.")
  }
  invisible(TRUE)
}

.goal003_task4_validate_text <- function(value, name, allow_missing = FALSE) {
  valid <- is.character(value) && length(value) == 1L &&
    (if (allow_missing) is.na(value) || nzchar(value) else
      !is.na(value) && nzchar(value))
  if (!valid) {
    .goal003_task4_scoring_stop(paste0(name, " has an invalid identifier."))
  }
  value
}

.goal003_task4_validate_flag <- function(value, name) {
  if (!is.logical(value) || length(value) != 1L || is.na(value)) {
    .goal003_task4_scoring_stop(paste0(name, " must be TRUE or FALSE."))
  }
  value
}

.goal003_task4_score_pmf <- function(pmf, truth, support_name) {
  if (!tibble::is_tibble(pmf) ||
      !identical(names(pmf), c(support_name, "probability"))) {
    .goal003_task4_scoring_stop("A Task 4 PMF has an invalid schema.")
  }
  renamed <- tibble::tibble(
    richness = as.integer(pmf[[support_name]]),
    probability = as.numeric(pmf$probability)
  )
  validated <- .validate_richness_pmf(renamed)
  if (truth > validated$candidate_pool_size) {
    .goal003_task4_scoring_stop("Truth falls outside a Task 4 PMF support.")
  }
  summary <- discrete_richness_summary(renamed, levels = 0.9)
  interval <- summary$intervals[["90"]]
  probability_at_truth <- renamed$probability[[truth + 1L]]
  list(
    point_estimate = summary$mean,
    absolute_error = abs(summary$mean - truth),
    rps = ranked_probability_score(renamed, truth),
    log_score = if (probability_at_truth == 0) Inf else
      -log(probability_at_truth),
    interval_90_lower = interval[["lower"]],
    interval_90_upper = interval[["upper"]],
    interval_90_covered = truth >= interval[["lower"]] &&
      truth <= interval[["upper"]],
    interval_90_width = as.numeric(interval[["upper"]] - interval[["lower"]])
  )
}

#' Score one Task 4 richness and discovery prediction
score_goal003_task4_prediction <- function(
  dataset_id,
  fit_id,
  method,
  run_role,
  terminal_clean,
  truth,
  richness_pmf = NULL,
  new_species_count_pmf = NULL,
  future_identity = NULL
) {
  dataset_id <- .goal003_task4_validate_text(dataset_id, "dataset_id")
  fit_id <- .goal003_task4_validate_text(
    fit_id,
    "fit_id",
    allow_missing = TRUE
  )
  method <- .goal003_task4_validate_text(method, "method")
  run_role <- .goal003_task4_validate_text(run_role, "run_role")
  terminal_clean <- .goal003_task4_validate_flag(
    terminal_clean,
    "terminal_clean"
  )
  .goal003_task4_validate_truth(truth)

  available <- terminal_clean && !is.null(richness_pmf)
  richness_score <- if (available) {
    .goal003_task4_score_pmf(
      richness_pmf,
      truth$true_richness,
      "richness"
    )
  } else {
    list(
      point_estimate = NA_real_,
      absolute_error = NA_real_,
      rps = NA_real_,
      log_score = NA_real_,
      interval_90_lower = NA_integer_,
      interval_90_upper = NA_integer_,
      interval_90_covered = FALSE,
      interval_90_width = NA_real_
    )
  }
  richness <- tibble::tibble(
    dataset_id = dataset_id,
    fit_id = fit_id,
    method = method,
    run_role = run_role,
    terminal_clean = terminal_clean,
    prediction_available = available,
    true_richness = truth$true_richness,
    point_estimate = richness_score$point_estimate,
    absolute_error = richness_score$absolute_error,
    rps = richness_score$rps,
    log_score = richness_score$log_score,
    interval_90_lower = richness_score$interval_90_lower,
    interval_90_upper = richness_score$interval_90_upper,
    interval_90_covered = richness_score$interval_90_covered,
    interval_90_width = richness_score$interval_90_width
  )

  unseen <- !truth$species$training_detected
  count_available <- terminal_clean && !is.null(new_species_count_pmf)
  count_score <- if (count_available) {
    .goal003_task4_score_pmf(
      new_species_count_pmf,
      truth$true_new_species,
      "new_species_count"
    )
  } else {
    list(point_estimate = NA_real_, absolute_error = NA_real_, rps = NA_real_)
  }
  identity_available <- terminal_clean && !is.null(future_identity)
  identity_brier <- NA_real_
  if (identity_available) {
    expected_fields <- c(
      "species_id", "training_detected",
      "future_first_detection_probability"
    )
    valid_identity <- tibble::is_tibble(future_identity) &&
      identical(names(future_identity), expected_fields) &&
      identical(future_identity$species_id, truth$species$species_id) &&
      identical(
        future_identity$training_detected,
        truth$species$training_detected
      ) &&
      is.numeric(future_identity$future_first_detection_probability) &&
      !anyNA(future_identity$future_first_detection_probability) &&
      all(is.finite(future_identity$future_first_detection_probability)) &&
      all(future_identity$future_first_detection_probability >= 0 &
        future_identity$future_first_detection_probability <= 1)
    if (!valid_identity) {
      .goal003_task4_scoring_stop(
        "future_identity differs from the Task 4 truth universe."
      )
    }
    if (any(unseen)) {
      identity_brier <- mean((
        future_identity$future_first_detection_probability[unseen] -
          as.numeric(truth$species$future_first_detection[unseen])
      )^2)
    }
  }
  discovery <- tibble::tibble(
    dataset_id = dataset_id,
    fit_id = fit_id,
    method = method,
    run_role = run_role,
    terminal_clean = terminal_clean,
    prediction_available = count_available,
    identity_prediction_available = identity_available,
    true_new_species = truth$true_new_species,
    expected_new_species = count_score$point_estimate,
    absolute_error = count_score$absolute_error,
    count_rps = count_score$rps,
    identity_brier = identity_brier,
    n_unseen_candidates = as.integer(sum(unseen))
  )
  list(richness = richness, discovery = discovery)
}

.goal003_task4_point_score <- function(
  simulation,
  method,
  eligible,
  estimate
) {
  truth <- simulation$truth$true_richness
  tibble::tibble(
    dataset_id = simulation$dataset_id,
    fit_id = NA_character_,
    method = method,
    run_role = "baseline",
    terminal_clean = TRUE,
    prediction_available = eligible,
    true_richness = truth,
    point_estimate = if (eligible) estimate else NA_real_,
    absolute_error = if (eligible) abs(estimate - truth) else NA_real_,
    rps = NA_real_,
    log_score = NA_real_,
    interval_90_lower = NA_integer_,
    interval_90_upper = NA_integer_,
    interval_90_covered = FALSE,
    interval_90_width = NA_real_
  )
}

#' Evaluate deterministic Task 4 baselines for one simulated dataset
evaluate_goal003_task4_baselines <- function(simulation) {
  expected_names <- c(
    "dataset_id", "training_data", "forecast_effort", "truth", "audit"
  )
  if (!is.list(simulation) || !identical(names(simulation), expected_names)) {
    .goal003_task4_scoring_stop(
      "simulation must be one canonical Task 4 simulation."
    )
  }
  validate_flexirich_g_data(simulation$training_data)
  .goal003_task4_validate_truth(simulation$truth)
  sample <- make_goal003_incidence_sample(simulation$training_data)
  estimates <- estimate_goal003_incidence_richness(sample)
  complete_sample <- tryCatch(
    make_goal003_incidence_sample(
      simulation$training_data,
      complete_only = TRUE
    ),
    error = function(e) NULL
  )
  complete_estimates <- if (is.null(complete_sample)) {
    tibble::tibble(
      method = c("chao2_complete", "ichao2_complete"),
      eligible = FALSE,
      reason = "no complete seven-day sampling units",
      raw_estimate = NA_real_,
      estimate = NA_real_
    )
  } else {
    estimate_goal003_incidence_richness(complete_sample) |>
      dplyr::filter(method %in% c("chao2", "ichao2")) |>
      dplyr::transmute(
        method = paste0(method, "_complete"),
        eligible,
        reason,
        raw_estimate,
        estimate
      )
  }

  inext_fit <- if (sample$observed_richness == 0L) {
    NULL
  } else {
    tryCatch(
      suppressWarnings(estimate_goal003_inext_curve(sample)),
      error = function(e) NULL
    )
  }
  inext_estimate <- if (is.null(inext_fit)) NA_real_ else
    inext_fit$asymptotic$estimate[[1L]]
  point_predictions <- dplyr::bind_rows(
    estimates |>
      dplyr::transmute(
        dataset_id = simulation$dataset_id,
        method,
        eligible,
        reason,
        raw_estimate,
        estimate
      ),
    complete_estimates |>
      dplyr::mutate(dataset_id = simulation$dataset_id, .before = 1L),
    tibble::tibble(
      dataset_id = simulation$dataset_id,
      method = "inext",
      eligible = !is.null(inext_fit),
      reason = if (is.null(inext_fit)) "iNEXT unavailable" else NA_character_,
      raw_estimate = if (is.null(inext_fit)) NA_real_ else
        inext_fit$asymptotic$raw_estimate[[1L]],
      estimate = inext_estimate
    )
  )
  point_scores <- dplyr::bind_rows(lapply(
    seq_len(nrow(point_predictions)),
    function(index) {
      row <- point_predictions[index, ]
      .goal003_task4_point_score(
        simulation,
        row$method,
        row$eligible,
        row$estimate
      )
    }
  ))

  observed_prediction <- predict_goal003_observed_new_species(sample)
  observed <- score_goal003_task4_prediction(
    simulation$dataset_id,
    NA_character_,
    "observed",
    "baseline",
    TRUE,
    simulation$truth,
    goal003_observed_richness_pmf(sample),
    observed_prediction$new_species_count_pmf,
    observed_prediction$future_identity
  )
  lower <- score_goal003_task4_prediction(
    simulation$dataset_id,
    NA_character_,
    "lower_prior",
    "baseline",
    TRUE,
    simulation$truth,
    goal003_lower_bound_prior_pmf(sample)
  )
  richness_scores <- dplyr::bind_rows(
    dplyr::filter(point_scores, method != "observed"),
    observed$richness,
    lower$richness
  )

  future_units <- as.integer(sum(simulation$forecast_effort$active_days > 0L))
  inext_future <- tryCatch(
    suppressWarnings(predict_goal003_inext_new_species(sample, future_units)),
    error = function(e) tibble::tibble(
      eligible = FALSE,
      reason = conditionMessage(e),
      expected_new_species = NA_real_
    )
  )
  inext_discovery <- tibble::tibble(
    dataset_id = simulation$dataset_id,
    fit_id = NA_character_,
    method = "inext",
    run_role = "baseline",
    terminal_clean = TRUE,
    prediction_available = inext_future$eligible[[1L]],
    identity_prediction_available = FALSE,
    true_new_species = simulation$truth$true_new_species,
    expected_new_species = inext_future$expected_new_species[[1L]],
    absolute_error = if (inext_future$eligible[[1L]]) {
      abs(inext_future$expected_new_species[[1L]] -
        simulation$truth$true_new_species)
    } else {
      NA_real_
    },
    count_rps = NA_real_,
    identity_brier = NA_real_,
    n_unseen_candidates = as.integer(sum(
      !simulation$truth$species$training_detected
    ))
  )
  list(
    point_predictions = point_predictions,
    richness_scores = richness_scores,
    discovery_scores = dplyr::bind_rows(
      observed$discovery,
      inext_discovery
    )
  )
}

.goal003_task4_gate_row <- function(
  gate_id,
  metric,
  value,
  threshold,
  comparison,
  numerator,
  denominator,
  passed
) {
  tibble::tibble(
    gate_id = gate_id,
    metric = metric,
    value = as.numeric(value),
    threshold = as.numeric(threshold),
    comparison = comparison,
    numerator = as.numeric(numerator),
    denominator = as.integer(denominator),
    passed = isTRUE(passed)
  )
}

.goal003_task4_primary_scores <- function(manifest, richness_scores) {
  scheduled <- manifest$fits |>
    dplyr::filter(
      method == "flexirich",
      run_role == "primary",
      prior_profile == "primary",
      pool_profile == "primary_50"
    ) |>
    dplyr::left_join(
      manifest$datasets |>
        dplyr::select(
          dataset_id,
          scenario_id,
          scenario_class,
          train_occasions,
          replicate
        ),
      by = "dataset_id"
    )
  scores <- richness_scores |>
    dplyr::filter(method == "flexirich", run_role == "primary")
  joined <- scheduled |>
    dplyr::left_join(
      scores |>
        dplyr::select(
          fit_id,
          terminal_clean,
          prediction_available,
          true_richness,
          point_estimate,
          absolute_error,
          rps,
          interval_90_covered
        ),
      by = "fit_id"
    )
  if (nrow(joined) != 300L || anyNA(joined$terminal_clean)) {
    .goal003_task4_scoring_stop(
      "Primary FlexiRich scores do not cover all scheduled datasets."
    )
  }
  joined
}

#' Evaluate the frozen Goal003 Task 4 screening gates
evaluate_goal003_task4_gates <- function(
  manifest,
  fit_status,
  richness_scores
) {
  validate_goal003_task4_manifests(
    manifest$scenarios,
    manifest$datasets,
    manifest$fits,
    manifest$effort
  )
  if (!is.data.frame(fit_status) || !is.data.frame(richness_scores)) {
    .goal003_task4_scoring_stop(
      "fit_status and richness_scores must be complete Task 4 tables."
    )
  }
  primary <- .goal003_task4_primary_scores(manifest, richness_scores)
  primary_status <- fit_status |>
    dplyr::filter(
      method == "flexirich",
      run_role == "primary",
      prior_profile == "primary",
      pool_profile == "primary_50"
    )
  if (nrow(primary_status) != 300L || anyNA(primary_status$terminal_clean)) {
    .goal003_task4_scoring_stop(
      "fit_status does not cover all primary FlexiRich fits."
    )
  }

  cells <- primary |>
    dplyr::summarise(
      scheduled = dplyr::n(),
      terminal_clean = sum(terminal_clean),
      coverage = mean(interval_90_covered),
      median_absolute_error = stats::median(
        absolute_error[terminal_clean & prediction_available],
        na.rm = TRUE
      ),
      .by = c(scenario_id, scenario_class, train_occasions)
    )
  gates <- list()
  add_gate <- function(...) {
    gates[[length(gates) + 1L]] <<- .goal003_task4_gate_row(...)
  }
  add_gate(
    "execution_oracles",
    "oracle_pass",
    1,
    1,
    "==",
    1,
    1L,
    TRUE
  )

  n_clean <- sum(primary_status$terminal_clean)
  add_gate(
    "primary_clean_overall", "terminal_clean_fraction",
    n_clean / 300, 0.95, ">=", n_clean, 300L, n_clean >= 285L
  )
  for (index in seq_len(nrow(cells))) {
    cell <- cells[index, ]
    suffix <- sprintf(
      "%s-%02dw",
      cell$scenario_id,
      cell$train_occasions
    )
    add_gate(
      paste0("primary_clean-", suffix),
      "terminal_clean_fraction",
      cell$terminal_clean / cell$scheduled,
      0.90,
      ">=",
      cell$terminal_clean,
      cell$scheduled,
      cell$terminal_clean >= 27L
    )
  }

  matched <- dplyr::filter(cells, scenario_class == "matched")
  pooled <- primary |>
    dplyr::filter(scenario_class == "matched") |>
    dplyr::summarise(
      coverage = mean(interval_90_covered),
      covered = sum(interval_90_covered),
      scheduled = dplyr::n(),
      .by = train_occasions
    )
  for (index in seq_len(nrow(pooled))) {
    row <- pooled[index, ]
    add_gate(
      sprintf("matched_coverage_pooled-%02dw", row$train_occasions),
      "fixed_denominator_coverage",
      row$coverage,
      0.85,
      "0.85_to_0.95",
      row$covered,
      row$scheduled,
      row$coverage >= 0.85 && row$coverage <= 0.95
    )
  }
  for (index in seq_len(nrow(matched))) {
    row <- matched[index, ]
    add_gate(
      sprintf(
        "matched_coverage-%s-%02dw",
        row$scenario_id,
        row$train_occasions
      ),
      "fixed_denominator_coverage",
      row$coverage,
      0.80,
      ">=",
      round(row$coverage * row$scheduled),
      row$scheduled,
      row$coverage >= 0.80
    )
  }

  matched_ids <- manifest$datasets$dataset_id[
    manifest$datasets$scenario_class == "matched"
  ]
  score_method <- function(method_id) {
    richness_scores |>
      dplyr::filter(
        dataset_id %in% matched_ids,
        .data$method == .env$method_id,
        if (method_id %in% c("flexirich", "occupancy")) {
          run_role == "primary"
        } else {
          TRUE
        }
      )
  }
  flex_all <- richness_scores |>
    dplyr::filter(
      method == "flexirich",
      run_role == "primary",
      terminal_clean,
      prediction_available
    )
  flex <- score_method("flexirich") |>
    dplyr::filter(terminal_clean, prediction_available)
  observed <- score_method("observed")
  lower <- score_method("lower_prior")
  occupancy <- score_method("occupancy") |>
    dplyr::filter(terminal_clean, prediction_available)
  paired_metric <- function(left, right, field) {
    pair <- left |>
      dplyr::select(dataset_id, left = dplyr::all_of(field)) |>
      dplyr::inner_join(
        right |>
          dplyr::select(dataset_id, right = dplyr::all_of(field)),
        by = "dataset_id"
      )
    c(
      left = stats::median(pair$left),
      right = stats::median(pair$right),
      n = nrow(pair)
    )
  }
  mae_observed <- paired_metric(flex, observed, "absolute_error")
  rps_observed <- paired_metric(flex, observed, "rps")
  rps_lower <- paired_metric(flex, lower, "rps")
  rps_occupancy <- paired_metric(flex, occupancy, "rps")
  add_gate(
    "matched_mae_vs_observed", "median_absolute_error_ratio",
    mae_observed[["left"]] / max(mae_observed[["right"]], .Machine$double.eps),
    1, "<=", NA_real_, mae_observed[["n"]],
    mae_observed[["left"]] <= mae_observed[["right"]]
  )
  add_gate(
    "matched_rps_vs_lower_prior", "median_rps_ratio",
    rps_lower[["left"]] / max(rps_lower[["right"]], .Machine$double.eps),
    1, "<", NA_real_, rps_lower[["n"]],
    rps_lower[["left"]] < rps_lower[["right"]]
  )
  add_gate(
    "matched_rps_vs_observed", "median_rps_ratio",
    rps_observed[["left"]] / max(rps_observed[["right"]], .Machine$double.eps),
    1.05, "<=", NA_real_, rps_observed[["n"]],
    rps_observed[["left"]] <= 1.05 * rps_observed[["right"]]
  )
  add_gate(
    "matched_rps_vs_occupancy", "median_rps_ratio",
    rps_occupancy[["left"]] /
      max(rps_occupancy[["right"]], .Machine$double.eps),
    1.05, "<=", NA_real_, rps_occupancy[["n"]],
    rps_occupancy[["left"]] <= 1.05 * rps_occupancy[["right"]]
  )

  misspecified <- dplyr::filter(cells, scenario_class == "misspecified")
  for (index in seq_len(nrow(misspecified))) {
    row <- misspecified[index, ]
    suffix <- sprintf("%s-%02dw", row$scenario_id, row$train_occasions)
    add_gate(
      paste0("misspecified_coverage-", suffix),
      "fixed_denominator_coverage",
      row$coverage,
      0.75,
      ">=",
      round(row$coverage * row$scheduled),
      row$scheduled,
      row$coverage >= 0.75
    )
    ids <- manifest$datasets$dataset_id[
      manifest$datasets$scenario_id == row$scenario_id &
        manifest$datasets$train_occasions == row$train_occasions
    ]
    f <- dplyr::filter(flex_all, dataset_id %in% ids)
    o <- dplyr::filter(richness_scores, dataset_id %in% ids, method == "observed")
    paired <- paired_metric(f, o, "absolute_error")
    add_gate(
      paste0("misspecified_mae-", suffix),
      "median_absolute_error_ratio",
      paired[["left"]] / max(paired[["right"]], .Machine$double.eps),
      1.10,
      "<=",
      NA_real_,
      paired[["n"]],
      paired[["left"]] <= 1.10 * paired[["right"]]
    )
  }

  catastrophic <- flex$point_estimate - flex$true_richness >= 12.5
  add_gate(
    "catastrophic_overestimate", "catastrophic_fraction",
    mean(catastrophic), 0.01, "<", sum(catastrophic), length(catastrophic),
    mean(catastrophic) < 0.01
  )

  primary_estimate <- richness_scores |>
    dplyr::filter(
      method == "flexirich",
      run_role == "primary",
      terminal_clean,
      prediction_available
    ) |>
    dplyr::select(dataset_id, primary_estimate = point_estimate)
  sensitivity_pairs <- richness_scores |>
    dplyr::filter(
      method == "flexirich",
      run_role %in% c("prior_sensitivity", "pool_sensitivity"),
      terminal_clean,
      prediction_available
    ) |>
    dplyr::inner_join(primary_estimate, by = "dataset_id") |>
    dplyr::mutate(
      sensitivity_id = dplyr::if_else(
        run_role == "prior_sensitivity",
        prior_profile,
        pool_profile
      ),
      absolute_shift = abs(point_estimate - primary_estimate)
    )
  expected_sensitivities <- tibble::tibble(
    sensitivity_id = c(
      "membership_regularised",
      "mu_alpha_wide",
      "tail_wide",
      "broader_106"
    )
  )
  sensitivity_summary <- sensitivity_pairs |>
    dplyr::summarise(
      median_shift = stats::median(absolute_shift),
      maximum_shift = max(absolute_shift),
      n_pairs = dplyr::n(),
      .by = sensitivity_id
    ) |>
    dplyr::right_join(expected_sensitivities, by = "sensitivity_id") |>
    dplyr::mutate(n_pairs = dplyr::coalesce(n_pairs, 0L))
  for (index in seq_len(nrow(sensitivity_summary))) {
    row <- sensitivity_summary[index, ]
    add_gate(
      paste0("sensitivity_median-", row$sensitivity_id),
      "median_absolute_shift",
      row$median_shift,
      1,
      "<=",
      NA_real_,
      row$n_pairs,
      is.finite(row$median_shift) && row$n_pairs == 60L &&
        row$median_shift <= 1
    )
    add_gate(
      paste0("sensitivity_maximum-", row$sensitivity_id),
      "maximum_absolute_shift",
      row$maximum_shift,
      3,
      "<=",
      NA_real_,
      row$n_pairs,
      is.finite(row$maximum_shift) && row$n_pairs == 60L &&
        row$maximum_shift <= 3
    )
  }

  runtime <- fit_status |>
    dplyr::filter(run_role == "primary", terminal_clean) |>
    dplyr::select(dataset_id, method, elapsed_seconds) |>
    tidyr::pivot_wider(names_from = method, values_from = elapsed_seconds) |>
    dplyr::filter(!is.na(flexirich), !is.na(occupancy))
  ratios <- runtime$flexirich / runtime$occupancy
  median_ratio <- if (length(ratios) == 0L) NA_real_ else
    stats::median(ratios)
  add_gate(
    "runtime_ratio", "median_runtime_ratio", median_ratio, 3,
    "<=", NA_real_, length(ratios),
    is.finite(median_ratio) && median_ratio <= 3
  )
  flex_runtime <- primary_status$elapsed_seconds[primary_status$terminal_clean]
  median_runtime <- if (length(flex_runtime) == 0L) NA_real_ else
    stats::median(flex_runtime)
  p95_runtime <- if (length(flex_runtime) == 0L) NA_real_ else
    unname(stats::quantile(flex_runtime, 0.95, type = 8))
  add_gate(
    "runtime_median", "median_seconds", median_runtime, 300, "<=",
    NA_real_, length(flex_runtime),
    is.finite(median_runtime) && median_runtime <= 300
  )
  add_gate(
    "runtime_p95", "p95_seconds", p95_runtime, 900, "<",
    NA_real_, length(flex_runtime), is.finite(p95_runtime) && p95_runtime < 900
  )

  list(
    gates = dplyr::bind_rows(gates),
    cell_summary = cells,
    sensitivity_pairs = sensitivity_pairs
  )
}
