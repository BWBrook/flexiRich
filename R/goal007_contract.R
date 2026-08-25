.goal007_stop <- function(message) {
  stop(message, call. = FALSE)
}

.goal007_q975 <- stats::qnorm(0.975)

#' Convert a multiplicative 95% factor to a Gaussian log-scale SD
#'
#' @param factor Multiplicative factor greater than one.
#'
#' @return Log-scale standard deviation.
goal007_contrast_sd <- function(factor) {
  valid <- is.numeric(factor) && !is.logical(factor) && length(factor) == 1L &&
    !is.na(factor) && is.finite(factor) && factor > 1
  if (!valid) {
    .goal007_stop("factor must be one finite number greater than one.")
  }
  log(factor) / .goal007_q975
}

#' Frozen Goal007 calibration-model candidates
goal007_expected_models <- function() {
  tibble::tibble(
    model_code = 1:3,
    model_id = c("independent", "shared_F5", "shared_F3"),
    model_family = c("independent", "shared_shift", "shared_shift"),
    contrast_factor = c(NA_real_, 5, 3),
    contrast_sd = c(
      NA_real_,
      goal007_contrast_sd(5),
      goal007_contrast_sd(3)
    ),
    selection_priority = c(NA_integer_, 1L, 2L),
    eligible_for_selection = c(FALSE, TRUE, TRUE)
  )
}

#' Frozen Goal007 Task 2 rate profiles
goal007_expected_profiles <- function() {
  tibble::tribble(
    ~profile_code, ~profile_id, ~routine_rate, ~occasional_rate,
    ~common_shift, ~contrast_deviation, ~screen_role,
    1L, "nominal", 0.0020, 0.0005000, 0, 0, "core",
    2L, "common_lower", 0.0010, 0.0002500, -log(2), 0, "core",
    3L, "common_upper", 0.0040, 0.0010000, log(2), 0, "core",
    4L, "compressed", 0.0015, 0.0007500, log(0.75), log(2), "core",
    5L, "expanded", 0.0015, 0.0001875, log(0.75), -log(2), "core",
    6L, "no_separation", 0.0015, 0.0015000, log(0.75), log(4), "stress"
  )
}

#' Frozen Goal007 Task 2 paired calibration datasets
goal007_expected_task2_datasets <- function() {
  profiles <- goal007_expected_profiles()
  tidyr::crossing(
    profile_code = profiles$profile_code,
    replicate = seq_len(10L)
  ) |>
    dplyr::left_join(profiles, by = "profile_code") |>
    dplyr::mutate(
      dataset_id = sprintf("g007t2-%s-r%02d", profile_id, replicate),
      calibration_start_index = 1L,
      calibration_end_index = 52L,
      candidate_pool_size = 50L,
      routine_candidates = 44L,
      occasional_candidates = 6L,
      true_members = 50L,
      log_rate_sd = 1,
      camera_sd = 0.35,
      simulation_seed = as.integer(
        710000000L + 100L * profile_code + replicate
      )
    ) |>
    dplyr::arrange(profile_code, replicate) |>
    dplyr::select(
      dataset_id,
      profile_id,
      profile_code,
      screen_role,
      replicate,
      calibration_start_index,
      calibration_end_index,
      candidate_pool_size,
      routine_candidates,
      occasional_candidates,
      true_members,
      routine_rate,
      occasional_rate,
      common_shift,
      contrast_deviation,
      log_rate_sd,
      camera_sd,
      simulation_seed
    )
}

#' Frozen Goal007 Task 2 fit schedule
goal007_expected_task2_fits <- function(datasets = goal007_expected_task2_datasets()) {
  models <- goal007_expected_models()
  tidyr::crossing(
    dataset_id = datasets$dataset_id,
    model_code = models$model_code
  ) |>
    dplyr::left_join(models, by = "model_code") |>
    dplyr::left_join(
      datasets[c("dataset_id", "profile_code", "replicate")],
      by = "dataset_id"
    ) |>
    dplyr::mutate(
      fit_id = paste(dataset_id, model_id, sep = "--"),
      fit_seed = as.integer(
        720000000L + 1000000L * model_code +
          100L * profile_code + replicate
      )
    ) |>
    dplyr::arrange(match(dataset_id, datasets$dataset_id), model_code) |>
    dplyr::select(
      fit_id,
      dataset_id,
      model_code,
      model_id,
      model_family,
      contrast_factor,
      contrast_sd,
      profile_code,
      replicate,
      fit_seed
    )
}

goal007_expected_task3_rate_profiles <- function() {
  goal007_expected_profiles() |>
    dplyr::filter(profile_id %in% c(
      "nominal", "common_lower", "compressed", "expanded"
    )) |>
    dplyr::mutate(rate_profile_code = dplyr::row_number()) |>
    dplyr::select(
      rate_profile_code,
      profile_id,
      routine_rate,
      occasional_rate,
      common_shift,
      contrast_deviation
    )
}

goal007_expected_task3_richness <- function() {
  .goal005_task2_expected_scenarios() |>
    dplyr::transmute(
      richness_code = as.integer(scenario_order),
      richness_id = sub("^aligned_", "", scenario_id),
      true_richness,
      routine_members,
      occasional_members
    )
}

#' Frozen Goal007 Task 3 effort windows
goal007_expected_task3_windows <- function(folds) {
  starts <- tibble::tibble(
    replicate = seq_len(4L),
    forecast_start_index = c(81L, 105L, 129L, 149L)
  )
  folds |>
    dplyr::filter(
      training_occasions %in% c(12L, 16L, 26L),
      forecast_start_index %in% starts$forecast_start_index
    ) |>
    dplyr::inner_join(starts, by = "forecast_start_index") |>
    dplyr::mutate(
      duration_code = match(training_occasions, c(12L, 16L, 26L))
    ) |>
    dplyr::arrange(replicate, duration_code) |>
    dplyr::select(
      replicate,
      duration_code,
      training_occasions,
      train_start_index,
      train_end_index,
      forecast_start_index,
      forecast_end_index,
      target_active_station_days,
      target_active_stations,
      target_zero_effort_station_weeks,
      forecast_active_station_days,
      forecast_active_stations,
      forecast_zero_effort_station_weeks
    )
}

#' Frozen Goal007 Task 3 ecological datasets
goal007_expected_task3_datasets <- function() {
  rates <- goal007_expected_task3_rate_profiles()
  richness <- goal007_expected_task3_richness()
  tidyr::crossing(
    rate_profile_code = rates$rate_profile_code,
    richness_code = richness$richness_code,
    replicate = seq_len(4L)
  ) |>
    dplyr::left_join(rates, by = "rate_profile_code") |>
    dplyr::left_join(richness, by = "richness_code") |>
    dplyr::mutate(
      stream_id = sprintf(
        "g007t3-%s-stream-r%02d",
        profile_id,
        replicate
      ),
      dataset_id = sprintf(
        "g007t3-%s-%s-r%02d",
        profile_id,
        richness_id,
        replicate
      ),
      calibration_start_index = 1L,
      calibration_end_index = 52L,
      forecast_start_index = c(81L, 105L, 129L, 149L)[replicate],
      forecast_occasions = 4L,
      candidate_pool_size = 50L,
      log_rate_sd = 1,
      calibration_camera_sd = 0.35,
      target_camera_sd = 0.35,
      persistent_species_rates = TRUE,
      simulation_seed = as.integer(
        730000000L + 100L * rate_profile_code + replicate
      )
    ) |>
    dplyr::arrange(rate_profile_code, richness_code, replicate) |>
    dplyr::select(
      dataset_id,
      stream_id,
      rate_profile_code,
      profile_id,
      richness_code,
      richness_id,
      replicate,
      true_richness,
      routine_members,
      occasional_members,
      routine_rate,
      occasional_rate,
      common_shift,
      contrast_deviation,
      calibration_start_index,
      calibration_end_index,
      forecast_start_index,
      forecast_occasions,
      candidate_pool_size,
      log_rate_sd,
      calibration_camera_sd,
      target_camera_sd,
      persistent_species_rates,
      simulation_seed
    )
}

.goal007_selected_model <- function(selected_model_id) {
  valid <- is.character(selected_model_id) && length(selected_model_id) == 1L &&
    !is.na(selected_model_id)
  models <- goal007_expected_models()
  selected <- models[
    valid & models$model_id == selected_model_id &
      models$eligible_for_selection,
  ]
  if (nrow(selected) != 1L) {
    .goal007_stop("selected_model_id must be shared_F5 or shared_F3.")
  }
  selected
}

#' Frozen Goal007 Task 3 calibration-fit branch
goal007_expected_task3_calibration_fits <- function(
  selected_model_id,
  datasets = goal007_expected_task3_datasets()
) {
  models <- goal007_expected_models()
  selected <- .goal007_selected_model(selected_model_id)
  branch_models <- models[models$model_id %in% c("independent", selected$model_id), ]
  tidyr::crossing(
    dataset_id = datasets$dataset_id,
    model_code = branch_models$model_code
  ) |>
    dplyr::left_join(branch_models, by = "model_code") |>
    dplyr::left_join(
      datasets[c(
        "dataset_id", "rate_profile_code", "richness_code", "replicate"
      )],
      by = "dataset_id"
    ) |>
    dplyr::mutate(
      fit_id = paste(dataset_id, model_id, "calibration", sep = "--"),
      fit_seed = as.integer(
        740000000L + 1000000L * model_code +
          10000L * rate_profile_code +
          100L * richness_code + replicate
      )
    ) |>
    dplyr::arrange(match(dataset_id, datasets$dataset_id), model_code) |>
    dplyr::select(
      fit_id,
      dataset_id,
      model_code,
      model_id,
      rate_profile_code,
      richness_code,
      replicate,
      fit_seed
    )
}

#' Frozen Goal007 Task 3 target-fit branch
goal007_expected_task3_target_fits <- function(
  selected_model_id,
  datasets = goal007_expected_task3_datasets(),
  windows
) {
  if (missing(windows)) {
    contract <- read_goal006_task1_contract(verify_external = FALSE)
    windows <- goal007_expected_task3_windows(contract$folds)
  }
  models <- goal007_expected_models()
  selected <- .goal007_selected_model(selected_model_id)
  branch_models <- models[models$model_id %in% c("independent", selected$model_id), ]
  tidyr::crossing(
    dataset_id = datasets$dataset_id,
    model_code = branch_models$model_code,
    duration_code = sort(unique(windows$duration_code))
  ) |>
    dplyr::left_join(branch_models, by = "model_code") |>
    dplyr::left_join(
      datasets[c(
        "dataset_id", "rate_profile_code", "richness_code", "replicate"
      )],
      by = "dataset_id"
    ) |>
    dplyr::left_join(
      windows[c("replicate", "duration_code", "training_occasions")],
      by = c("replicate", "duration_code")
    ) |>
    dplyr::mutate(
      fit_id = paste0(
        dataset_id,
        "--", sprintf("%02dw", training_occasions),
        "--", model_id,
        "--target"
      ),
      fit_seed = as.integer(
        750000000L + 10000000L * model_code +
          100000L * duration_code +
          10000L * rate_profile_code +
          100L * richness_code + replicate
      )
    ) |>
    dplyr::arrange(
      match(dataset_id, datasets$dataset_id),
      duration_code,
      model_code
    ) |>
    dplyr::select(
      fit_id,
      dataset_id,
      model_code,
      model_id,
      duration_code,
      training_occasions,
      rate_profile_code,
      richness_code,
      replicate,
      fit_seed
    )
}

.goal007_gate <- function(
  stage,
  gate_id,
  scope,
  metric,
  comparison,
  threshold,
  denominator = NA_real_,
  required = TRUE
) {
  tibble::tibble(
    stage,
    gate_id,
    scope,
    metric,
    comparison,
    threshold = as.numeric(threshold),
    denominator = as.numeric(denominator),
    required_for_advance = required
  )
}

#' Frozen Goal007 decision gates
goal007_expected_gates <- function() {
  g <- .goal007_gate
  dplyr::bind_rows(
    g("task2", "T2-transform", "deterministic", "maximum prior-transform error", "at_most", 1e-12),
    g("task2", "T2-covariance", "deterministic", "maximum implied-covariance error", "at_most", 1e-12),
    g("task2", "T2-likelihood-value", "deterministic", "maximum likelihood-value bridge error", "at_most", 1e-8),
    g("task2", "T2-likelihood-gradient", "deterministic", "maximum likelihood-gradient bridge error", "at_most", 1e-5),
    g("task2", "T2-clean", "candidate", "terminal-clean fits", "at_least", 58, 60),
    g("task2", "T2-clean-profile", "candidate_profile", "minimum terminal-clean fits", "at_least", 9, 10),
    g("task2", "T2-routine-generator-bias", "core_profile", "maximum absolute profile-median routine generator bias", "at_most", 0.35),
    g("task2", "T2-occasional-generator-bias", "core_profile", "maximum absolute profile-median occasional generator bias", "at_most", 0.50),
    g("task2", "T2-routine-generator-rmse", "core", "routine generator RMSE", "at_most", 0.60),
    g("task2", "T2-occasional-generator-rmse", "core", "occasional generator RMSE", "at_most", 0.75),
    g("task2", "T2-routine-finite-rmse", "core", "routine finite-set RMSE", "at_most", 0.60),
    g("task2", "T2-occasional-finite-rmse", "core", "occasional finite-set RMSE", "at_most", 0.75),
    g("task2", "T2-routine-coverage", "core", "routine generator 90% coverage", "at_least", 42, 50),
    g("task2", "T2-occasional-coverage", "core", "occasional generator 90% coverage", "at_least", 42, 50),
    g("task2", "T2-profile-coverage", "core_class_profile", "minimum generator 90% coverage", "at_least", 8, 10),
    g("task2", "T2-catastrophic", "core", "non-clean or factor-three composite errors", "at_most", 2, 50),
    g("task2", "T2-rare-rmse-ratio", "paired_core", "candidate-to-baseline worst occasional RMSE ratio", "at_most", 0.90),
    g("task2", "T2-rare-coverage-loss", "paired_core", "baseline-minus-candidate occasional coverage", "at_most", 2, 50),
    g("task2", "T2-catastrophic-difference", "paired_core", "candidate-minus-baseline catastrophic count", "at_most", 0, 50),
    g("task2", "T2-routine-generator-rmse-ratio", "paired_core", "candidate-to-baseline routine generator RMSE ratio", "at_most", 1.10),
    g("task2", "T2-routine-finite-rmse-ratio", "paired_core", "candidate-to-baseline routine finite-set RMSE ratio", "at_most", 1.10),
    g("task2", "T2-stress-occasional-bias", "stress", "absolute occasional profile-median generator bias", "at_most", log(2)),
    g("task2", "T2-stress-occasional-coverage", "stress", "occasional generator 90% coverage", "at_least", 7, 10),
    g("task2", "T2-stress-catastrophic", "stress", "non-clean or factor-three composite errors", "at_most", 2, 10),
    g("task2", "T2-artifact", "candidate", "artifacts passing all Gaussian checks", "at_least", 58, 60),
    g("task2", "T2-artifact-profile", "candidate_profile", "minimum artifacts passing all Gaussian checks", "at_least", 9, 10),
    g("task3", "T3-calibration-clean", "model", "terminal-clean calibration fits", "at_least", 47, 48),
    g("task3", "T3-calibration-clean-richness", "model_richness", "minimum terminal-clean calibration fits", "at_least", 15, 16),
    g("task3", "T3-calibration-clean-rate", "model_rate", "minimum terminal-clean calibration fits", "at_least", 11, 12),
    g("task3", "T3-artifact", "model", "calibration artifacts passing Gaussian checks", "at_least", 47, 48),
    g("task3", "T3-artifact-richness", "model_richness", "minimum calibration artifacts passing Gaussian checks", "at_least", 15, 16),
    g("task3", "T3-artifact-rate", "model_rate", "minimum calibration artifacts passing Gaussian checks", "at_least", 11, 12),
    g("task3", "T3-target-clean", "model_duration", "terminal-clean target fits", "at_least", 47, 48),
    g("task3", "T3-target-clean-richness", "model_duration_richness", "minimum terminal-clean target fits", "at_least", 15, 16),
    g("task3", "T3-target-clean-rate", "model_duration_rate", "minimum terminal-clean target fits", "at_least", 11, 12),
    g("task3", "T3-separation", "model_duration", "median high-minus-low posterior-mean richness", "at_least", 27),
    g("task3", "T3-bias-richness", "model_duration_richness", "maximum absolute median signed richness bias", "at_most", 3),
    g("task3", "T3-bias-rate", "model_duration_rate", "maximum absolute median signed richness bias", "at_most", 3),
    g("task3", "T3-rps-gain", "model_duration", "pooled richness RPS gain over no-data prior", "at_least", 0.40),
    g("task3", "T3-rps-gain-richness", "model_duration_richness", "minimum mean richness RPS gain over no-data prior", "strictly_greater", 0),
    g("task3", "T3-rps-gain-rate", "model_duration_rate", "minimum mean richness RPS gain over no-data prior", "strictly_greater", 0),
    g("task3", "T3-coverage-richness", "model_duration_richness", "minimum fixed-denominator 90% richness coverage", "at_least", 13, 16),
    g("task3", "T3-coverage-rate", "model_duration_rate", "minimum fixed-denominator 90% richness coverage", "at_least", 10, 12),
    g("task3", "T3-width", "model_duration", "median 90% richness interval width", "at_most", 25),
    g("task3", "T3-catastrophic", "model_duration", "non-clean or 12.5-species errors", "at_most", 2, 48),
    g("task3", "T3-baseline-rps-ratio", "candidate_duration", "candidate-to-baseline mean richness RPS ratio", "at_most", 1.05),
    g("task3", "T3-baseline-catastrophic-difference", "candidate_duration", "candidate-minus-baseline catastrophic count", "at_most", 0, 48),
    g("task3", "T3-baseline-coverage-loss", "candidate_duration", "baseline-minus-candidate richness coverage", "at_most", 2, 48),
    g("task3", "T3-count-rps-ratio", "candidate_duration", "candidate-to-baseline future-count RPS ratio", "at_most", 1.05),
    g("task3", "T3-identity-brier-ratio", "candidate_duration", "candidate-to-baseline identity-Brier ratio", "at_most", 1.05),
    g("task3", "T3-finite-count-log-score", "candidate_duration", "fraction of terminal-clean fits with finite count log score", "equal", 1),
    g("task3", "T3-earned-rps", "candidate_duration", "candidate richness RPS improvement over baseline", "at_least", 0.05, required = FALSE),
    g("task3", "T3-earned-catastrophic", "candidate_duration", "baseline-minus-candidate catastrophic count", "at_least", 1, 48, required = FALSE),
    g("task3", "T3-earned-redesign", "selected_duration", "RPS or catastrophic-improvement alternative satisfied", "equal", 1)
  )
}

goal007_model_contract <- function() {
  list(
    calibration_model_id = "selection_adjusted_shared_shift_v1",
    target_model_id = "finite_pool_joint_gaussian_class_v1",
    class_order = c("routine", "occasional"),
    base_location = c(routine = log(0.002), occasional = log(0.0005)),
    common_shift_sd = 1.5,
    candidate_selection_order = c("shared_F5", "shared_F3"),
    log_rate_sd = 1,
    camera_sd_scale = 0.75,
    quadrature_order = 64L,
    artifact_quantile_tolerance = 0.10,
    artifact_radial_tolerance = 0.10,
    artifact_skew_tolerance = 0.50,
    eligible_durations = c(12L, 16L, 26L),
    forecast_occasions = 4L,
    duration_rule = "shortest_contiguous_suffix_ending_at_26"
  )
}

goal007_output_schema <- function() {
  list(
    calibration_artifact = c(
      "artifact_version", "model_id", "class_order", "location_mean",
      "location_covariance", "prior_metadata", "fit_seed", "source_hashes",
      "diagnostics", "approximation_checks"
    ),
    task2_fit_status = c(
      "fit_id", "dataset_id", "model_id", "fit_seed", "terminal_status",
      "terminal_clean", "elapsed_seconds", "divergences",
      "treedepth_hits", "max_rhat", "min_bulk_ess", "min_tail_ess",
      "min_ebfmi"
    ),
    task2_recovery = c(
      "fit_id", "dataset_id", "model_id", "profile_id", "screen_role",
      "encounter_class", "generating_location", "finite_location",
      "posterior_median", "lower_90", "upper_90", "generator_error",
      "finite_error", "generator_covered_90", "terminal_clean"
    ),
    task3_richness = c(
      "fit_id", "dataset_id", "model_id", "training_occasions",
      "true_richness", "observed_richness", "posterior_mean", "median",
      "lower_90", "upper_90", "covered_90", "richness_rps"
    ),
    task3_forecast_count = c(
      "fit_id", "dataset_id", "model_id", "training_occasions",
      "true_new_species", "expected_new_species", "count_rps",
      "count_log_score"
    ),
    task3_forecast_identity = c(
      "fit_id", "dataset_id", "model_id", "training_occasions",
      "candidate_id", "training_detected", "future_first_detected",
      "future_first_detection_probability"
    ),
    decision_gates = c(
      "stage", "gate_id", "model_id", "training_occasions", "value",
      "threshold", "comparison", "numerator", "denominator", "passed"
    )
  )
}

.goal007_forbidden_artifact_terms <- c(
  "candidate", "species", "history", "detected", "membership",
  "individual_rate", "alpha"
)

#' Read the complete outcome-free Goal007 Task 1 contract
#'
#' @param verify_external Verify the frozen external source receipts without
#'   reading empirical outcomes.
#'
#' @return Deterministic Goal007 tables, branch schedules, and hashes.
read_goal007_task1_contract <- function(verify_external = FALSE) {
  base <- read_goal006_task1_contract(verify_external = verify_external)
  models <- goal007_expected_models()
  profiles <- goal007_expected_profiles()
  task2_datasets <- goal007_expected_task2_datasets()
  task2_fits <- goal007_expected_task2_fits(task2_datasets)
  task3_rate_profiles <- goal007_expected_task3_rate_profiles()
  task3_richness <- goal007_expected_task3_richness()
  task3_windows <- goal007_expected_task3_windows(base$folds)
  task3_datasets <- goal007_expected_task3_datasets()
  task3_branches <- stats::setNames(lapply(
    c("shared_F5", "shared_F3"),
    function(model_id) {
      list(
        calibration_fits = goal007_expected_task3_calibration_fits(
          model_id,
          task3_datasets
        ),
        target_fits = goal007_expected_task3_target_fits(
          model_id,
          task3_datasets,
          task3_windows
        )
      )
    }
  ), c("shared_F5", "shared_F3"))
  gates <- goal007_expected_gates()
  model <- goal007_model_contract()
  output_schema <- goal007_output_schema()
  tables <- list(
    sources = base$sources,
    candidates = base$candidates,
    effort = base$effort,
    models = models,
    profiles = profiles,
    task2_datasets = task2_datasets,
    task2_fits = task2_fits,
    task3_rate_profiles = task3_rate_profiles,
    task3_richness = task3_richness,
    task3_windows = task3_windows,
    task3_datasets = task3_datasets,
    task3_branches = task3_branches,
    gates = gates,
    model = model,
    output_schema = output_schema
  )
  stable <- tables
  stable$sources <- .goal006_source_receipts()
  hashes <- vapply(stable, function(value) {
    digest::digest(value, algo = "sha256", serialize = TRUE)
  }, character(1))
  c(tables, list(hashes = hashes))
}
