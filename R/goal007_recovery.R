.goal007_fit_independent_calibration <- function(
  data,
  seed,
  output_dir,
  refresh
) {
  .validate_goal006_calibration_data(data)
  absolute_output <- .goal003_prepare_output_directory(
    output_dir,
    output_namespace = "goal007"
  )
  attempts <- .goal004_task4_run_attempts(
    model = compile_goal006_calibration_model(),
    stan_data = data$stan_data,
    profiles = goal003_flexirich_sampler_profiles(),
    thresholds = goal003_flexirich_diagnostic_thresholds(),
    monitored = .goal006_calibration_monitored_variables(data),
    seed = as.integer(seed),
    output_dir = absolute_output,
    refresh = as.integer(refresh)
  )
  list(
    terminal_status = attempts$terminal_status,
    data = data,
    output_dir = absolute_output,
    attempts = attempts$attempts
  )
}

.goal007_fit_task2_row <- function(
  fit_row,
  simulation,
  output_dir,
  refresh
) {
  if (identical(fit_row$model_id, "independent")) {
    data <- prepare_goal006_calibration_data(
      simulation$source_data,
      simulation$encounter_class,
      .goal007_base_calibration_profile()
    )
    fit <- .goal007_fit_independent_calibration(
      data,
      fit_row$fit_seed,
      output_dir,
      refresh
    )
  } else {
    data <- prepare_goal007_calibration_data(
      simulation$source_data,
      simulation$encounter_class,
      fit_row$model_id
    )
    fit <- fit_goal007_calibration(
      data,
      fit_row$fit_seed,
      output_dir,
      refresh
    )
  }
  fit
}

.goal007_terminal_attempt <- function(result) {
  name <- if (result$terminal_status == "primary_clean") {
    "primary"
  } else if (result$terminal_status == "rescue_clean") {
    "rescue"
  } else {
    names(result$attempts)[[length(result$attempts)]]
  }
  list(name = name, value = result$attempts[[name]])
}

.goal007_class_draws <- function(result, model_id) {
  if (identical(model_id, "independent")) {
    .goal006_calibration_draws(result)
  } else {
    .goal007_calibration_draws(result)
  }
}

.goal007_fit_class_counts <- function(result, model_id) {
  if (identical(model_id, "independent")) {
    result$data$class_counts
  } else {
    result$data$base_data$class_counts
  }
}

.goal007_artifact_pass <- function(result, model_id, data_hash, fit_seed) {
  if (identical(model_id, "independent") ||
      !result$terminal_status %in% c("primary_clean", "rescue_clean")) {
    return(NA)
  }
  artifact <- make_goal007_calibration_artifact(
    result,
    source_hashes = tibble::tibble(
      source_id = "synthetic_data",
      sha256 = data_hash
    ),
    fit_seed = fit_seed
  )
  checks <- artifact$approximation_checks
  model <- goal007_model_contract()
  checks$max_quantile_error <= model$artifact_quantile_tolerance &&
    checks$radial_ks_distance <= model$artifact_radial_tolerance &&
    checks$max_abs_skewness <= model$artifact_skew_tolerance
}

#' Summarise one Goal007 Task 2 fit against both recovery targets
summarise_goal007_task2_fit <- function(fit_row, dataset_row, simulation, result) {
  terminal <- .goal007_terminal_attempt(result)
  metrics <- terminal$value$diagnostics$metrics
  if (is.null(metrics)) {
    metrics <- list(
      divergences = NA_integer_,
      treedepth_hits = NA_integer_,
      min_ebfmi = NA_real_,
      max_rhat = NA_real_,
      min_bulk_ess = NA_real_,
      min_tail_ess = NA_real_
    )
  }
  clean <- result$terminal_status %in% c("primary_clean", "rescue_clean")
  class_counts <- .goal007_fit_class_counts(result, fit_row$model_id)
  artifact_pass <- .goal007_artifact_pass(
    result,
    fit_row$model_id,
    simulation$audit$data_hash,
    fit_row$fit_seed
  )
  status <- tibble::tibble(
    fit_id = fit_row$fit_id,
    dataset_id = fit_row$dataset_id,
    model_id = fit_row$model_id,
    profile_id = dataset_row$profile_id,
    screen_role = dataset_row$screen_role,
    replicate = as.integer(dataset_row$replicate),
    simulation_seed = as.integer(dataset_row$simulation_seed),
    fit_seed = as.integer(fit_row$fit_seed),
    detected_species = simulation$audit$detected_species,
    detected_routine = as.integer(class_counts[["routine"]]),
    detected_occasional = as.integer(class_counts[["occasional"]]),
    terminal_status = result$terminal_status,
    terminal_clean = clean,
    terminal_attempt = terminal$name,
    n_attempts = as.integer(length(result$attempts)),
    elapsed_seconds = sum(vapply(
      result$attempts,
      function(attempt) attempt$elapsed_seconds,
      numeric(1)
    )),
    divergences = metrics$divergences,
    treedepth_hits = metrics$treedepth_hits,
    min_ebfmi = metrics$min_ebfmi,
    max_rhat = metrics$max_rhat,
    min_bulk_ess = metrics$min_bulk_ess,
    min_tail_ess = metrics$min_tail_ess,
    artifact_pass = artifact_pass,
    reasons = paste(terminal$value$diagnostics$reasons, collapse = "; ")
  )
  class_order <- c("routine", "occasional")
  finite_location <- simulation$truth$species |>
    dplyr::summarise(location = mean(alpha), .by = encounter_class)
  finite_location <- stats::setNames(
    finite_location$location,
    finite_location$encounter_class
  )
  recovery <- tibble::tibble(
    fit_id = fit_row$fit_id,
    dataset_id = fit_row$dataset_id,
    model_id = fit_row$model_id,
    profile_id = dataset_row$profile_id,
    screen_role = dataset_row$screen_role,
    replicate = as.integer(dataset_row$replicate),
    encounter_class = class_order,
    generating_location = unname(
      simulation$truth$class_location[class_order]
    ),
    finite_location = unname(finite_location[class_order]),
    posterior_median = NA_real_,
    lower_90 = NA_real_,
    upper_90 = NA_real_,
    generator_error = NA_real_,
    finite_error = NA_real_,
    generator_covered_90 = FALSE,
    terminal_clean = clean
  )
  if (clean) {
    draws <- as.matrix(.goal007_class_draws(result, fit_row$model_id))
    recovery$posterior_median <- apply(draws, 2L, stats::median)
    recovery$lower_90 <- apply(draws, 2L, stats::quantile, probs = 0.05)
    recovery$upper_90 <- apply(draws, 2L, stats::quantile, probs = 0.95)
    recovery$generator_error <- recovery$posterior_median -
      recovery$generating_location
    recovery$finite_error <- recovery$posterior_median -
      recovery$finite_location
    recovery$generator_covered_90 <-
      recovery$lower_90 <= recovery$generating_location &
      recovery$upper_90 >= recovery$generating_location
  }
  list(status = status, recovery = recovery)
}

.goal007_task2_gate_row <- function(gate, model_id, value, numerator = NA_real_) {
  comparison <- gate$comparison[[1L]]
  threshold <- gate$threshold[[1L]]
  passed <- switch(
    comparison,
    at_most = value <= threshold,
    at_least = value >= threshold,
    equal = value == threshold,
    strictly_greater = value > threshold,
    .goal007_stop("Unknown Goal007 gate comparison.")
  )
  tibble::tibble(
    stage = gate$stage,
    gate_id = gate$gate_id,
    model_id = model_id,
    value = as.numeric(value),
    threshold = threshold,
    comparison = comparison,
    numerator = as.numeric(numerator),
    denominator = gate$denominator,
    passed = isTRUE(passed)
  )
}

.goal007_task2_metrics <- function(status, recovery, model_id) {
  model_status <- status |>
    dplyr::filter(.data$model_id == .env$model_id)
  model_recovery <- recovery |>
    dplyr::filter(.data$model_id == .env$model_id)
  core <- model_recovery |>
    dplyr::filter(screen_role == "core")
  core_status <- model_status |>
    dplyr::filter(screen_role == "core")
  stress <- model_recovery |>
    dplyr::filter(screen_role == "stress")
  stress_status <- model_status |>
    dplyr::filter(screen_role == "stress")
  catastrophic <- function(rows, statuses) {
    rows |>
      dplyr::summarise(
        tail_error = any(
          abs(generator_error) > log(3) |
            abs(finite_error) > log(3),
          na.rm = TRUE
        ),
        .by = dataset_id
      ) |>
      dplyr::left_join(
        statuses[c("dataset_id", "terminal_clean")],
        by = "dataset_id"
      ) |>
      dplyr::mutate(failed = !terminal_clean | tail_error)
  }
  list(
    status = model_status,
    recovery = model_recovery,
    core = core,
    stress = stress,
    clean_total = sum(model_status$terminal_clean),
    clean_profile = model_status |>
      dplyr::summarise(value = sum(terminal_clean), .by = profile_id),
    bias_profile = core |>
      dplyr::summarise(
        value = stats::median(generator_error, na.rm = TRUE),
        .by = c(profile_id, encounter_class)
      ),
    generator_rmse = core |>
      dplyr::summarise(
        value = sqrt(mean(generator_error^2, na.rm = TRUE)),
        .by = encounter_class
      ),
    finite_rmse = core |>
      dplyr::summarise(
        value = sqrt(mean(finite_error^2, na.rm = TRUE)),
        .by = encounter_class
      ),
    coverage = core |>
      dplyr::summarise(
        value = sum(generator_covered_90),
        .by = encounter_class
      ),
    coverage_profile = core |>
      dplyr::summarise(
        value = sum(generator_covered_90),
        .by = c(profile_id, encounter_class)
      ),
    catastrophic = catastrophic(core, core_status),
    stress_bias = stress |>
      dplyr::filter(encounter_class == "occasional") |>
      dplyr::summarise(value = stats::median(generator_error, na.rm = TRUE)),
    stress_coverage = stress |>
      dplyr::filter(encounter_class == "occasional") |>
      dplyr::summarise(value = sum(generator_covered_90)),
    stress_catastrophic = catastrophic(stress, stress_status),
    artifact_total = sum(model_status$artifact_pass %in% TRUE),
    artifact_profile = model_status |>
      dplyr::summarise(
        value = sum(artifact_pass %in% TRUE),
        .by = profile_id
      )
  )
}

.goal007_metric_by_class <- function(table, class) {
  table$value[table$encounter_class == class]
}

#' Apply the frozen Goal007 Task 2 candidate gates
evaluate_goal007_task2_gates <- function(
  contract,
  fit_status,
  recovery,
  prior_bridge = goal007_prior_bridge_metrics(),
  likelihood_bridge = goal006_likelihood_bridge_metrics()
) {
  valid <- is.list(contract) && nrow(contract$task2_datasets) == 60L &&
    nrow(contract$task2_fits) == 180L &&
    inherits(fit_status, "data.frame") && nrow(fit_status) == 180L &&
    inherits(recovery, "data.frame") && nrow(recovery) == 360L &&
    setequal(fit_status$fit_id, contract$task2_fits$fit_id) &&
    all(table(recovery$fit_id) == 2L) &&
    setequal(recovery$fit_id, contract$task2_fits$fit_id) &&
    isTRUE(prior_bridge$passed) && isTRUE(likelihood_bridge$passed)
  if (!valid) {
    .goal007_stop("Goal007 Task 2 evidence is incomplete.")
  }
  task2 <- contract$gates |>
    dplyr::filter(stage == "task2")
  baseline <- .goal007_task2_metrics(fit_status, recovery, "independent")
  candidate_ids <- contract$model$candidate_selection_order

  evaluate_candidate <- function(model_id) {
    metrics <- .goal007_task2_metrics(fit_status, recovery, model_id)
    gate_value <- function(id) {
      gate <- task2[task2$gate_id == id, ]
      value <- switch(
        id,
        "T2-transform" = prior_bridge$maximum_transform_error,
        "T2-covariance" = prior_bridge$maximum_covariance_error,
        "T2-likelihood-value" = likelihood_bridge$maximum_value_error,
        "T2-likelihood-gradient" = likelihood_bridge$maximum_gradient_error,
        "T2-clean" = metrics$clean_total,
        "T2-clean-profile" = min(metrics$clean_profile$value),
        "T2-routine-generator-bias" = max(abs(metrics$bias_profile$value[
          metrics$bias_profile$encounter_class == "routine"
        ])),
        "T2-occasional-generator-bias" = max(abs(metrics$bias_profile$value[
          metrics$bias_profile$encounter_class == "occasional"
        ])),
        "T2-routine-generator-rmse" = .goal007_metric_by_class(
          metrics$generator_rmse, "routine"
        ),
        "T2-occasional-generator-rmse" = .goal007_metric_by_class(
          metrics$generator_rmse, "occasional"
        ),
        "T2-routine-finite-rmse" = .goal007_metric_by_class(
          metrics$finite_rmse, "routine"
        ),
        "T2-occasional-finite-rmse" = .goal007_metric_by_class(
          metrics$finite_rmse, "occasional"
        ),
        "T2-routine-coverage" = .goal007_metric_by_class(
          metrics$coverage, "routine"
        ),
        "T2-occasional-coverage" = .goal007_metric_by_class(
          metrics$coverage, "occasional"
        ),
        "T2-profile-coverage" = min(metrics$coverage_profile$value),
        "T2-catastrophic" = sum(metrics$catastrophic$failed),
        "T2-rare-rmse-ratio" = max(
          .goal007_metric_by_class(metrics$generator_rmse, "occasional"),
          .goal007_metric_by_class(metrics$finite_rmse, "occasional")
        ) / max(
          .goal007_metric_by_class(baseline$generator_rmse, "occasional"),
          .goal007_metric_by_class(baseline$finite_rmse, "occasional")
        ),
        "T2-rare-coverage-loss" =
          .goal007_metric_by_class(baseline$coverage, "occasional") -
          .goal007_metric_by_class(metrics$coverage, "occasional"),
        "T2-catastrophic-difference" =
          sum(metrics$catastrophic$failed) -
          sum(baseline$catastrophic$failed),
        "T2-routine-generator-rmse-ratio" =
          .goal007_metric_by_class(metrics$generator_rmse, "routine") /
          .goal007_metric_by_class(baseline$generator_rmse, "routine"),
        "T2-routine-finite-rmse-ratio" =
          .goal007_metric_by_class(metrics$finite_rmse, "routine") /
          .goal007_metric_by_class(baseline$finite_rmse, "routine"),
        "T2-stress-occasional-bias" = abs(metrics$stress_bias$value),
        "T2-stress-occasional-coverage" = metrics$stress_coverage$value,
        "T2-stress-catastrophic" = sum(metrics$stress_catastrophic$failed),
        "T2-artifact" = metrics$artifact_total,
        "T2-artifact-profile" = min(metrics$artifact_profile$value),
        .goal007_stop("Unknown Goal007 Task 2 gate.")
      )
      numerator <- if (is.finite(gate$denominator)) value else NA_real_
      .goal007_task2_gate_row(gate, model_id, value, numerator)
    }
    gates <- lapply(task2$gate_id, gate_value) |>
      dplyr::bind_rows()
    list(gates = gates, metrics = metrics)
  }
  evaluated <- stats::setNames(lapply(candidate_ids, evaluate_candidate), candidate_ids)
  gates <- dplyr::bind_rows(lapply(evaluated, `[[`, "gates"))
  eligibility <- gates |>
    dplyr::summarise(
      gates_passed = sum(passed),
      gates_total = dplyr::n(),
      eligible = all(passed),
      .by = model_id
    ) |>
    dplyr::mutate(
      selection_priority = match(model_id, candidate_ids)
    ) |>
    dplyr::arrange(selection_priority)
  selected <- eligibility$model_id[eligibility$eligible][1L]
  if (length(selected) == 0L || is.na(selected)) {
    selected <- NA_character_
  }
  list(
    gates = gates,
    eligibility = eligibility,
    selected_model_id = selected,
    decision = if (is.na(selected)) "TASK2_STOP" else "TASK2_PASS",
    baseline_metrics = baseline,
    candidate_metrics = lapply(evaluated, `[[`, "metrics")
  )
}
