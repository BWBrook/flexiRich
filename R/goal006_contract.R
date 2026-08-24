.goal006_stop <- function(message) {
  stop(message, call. = FALSE)
}

.goal006_candidate_hash <-
  "60c8900c1904bafa34340e8ea7e2a44fc819836f76746fc7ee80c484166608db"
.goal006_effort_hash <-
  "d46655701ba0427264fc40a4a568b2ee350a34e9683b1cf1daa3d67ceeaeede9"

.goal006_source_receipts <- function() {
  tibble::tribble(
    ~source_id, ~relative_path, ~sha256,
    "observations", "data/jc_obs.csv",
    "deafe2af080726aa8b3ec67baca70f7f9c45b18acbfc56ceed39cb353eab5ae0",
    "operation", "data/jc_op.csv",
    "28222586fa232fccc46bfab5e8c07e0c453f07387ebe4eb95b9a90e4687033a3",
    "taxonomy", "data/jc_taxa.csv",
    "7abcc6ff7fd49d3130b29589dc552ff45d00a8a7dfeb355d1ac61c7eb35ea18a",
    "site_mapping",
    "docs/goals/009-analysis-site-vertical-slice/judbury_analysis_site_mapping.csv",
    "6490d7f7021e5c727b9be1c7d6dfbf44ba50a1ef5b0396c66e1dd813a9c77083",
    "event_protocol", "R/custom_funcs.R",
    "9bd5ea8508867a52dc58635b5023a9cdd8ae3fa89a7666af2555fb1579432866",
    "time_protocol", "R/time_utils.R",
    "ec7901a10024e9833194426701a3ed7a3ef29e9cd6daf0bb9e4d405932b08067"
  )
}

#' Verify the immutable Judbury source receipts without reading outcomes
#'
#' Goal006 treats the six content hashes as authority. The current Git commit
#' of the separate read-only checkout is recorded for provenance, but is not a
#' requirement when every analysis-relevant file still matches its receipt.
#'
#' @param source_root Read-only `camtrap-workflow` checkout.
#'
#' @return Source receipt table with the currently observed Git commit.
verify_goal006_source_receipts <- function(
  source_root = "/home/bwbrook/git/camtrap-workflow"
) {
  if (!is.character(source_root) || length(source_root) != 1L ||
      is.na(source_root) || !dir.exists(source_root)) {
    .goal006_stop("source_root must name the read-only camtrap-workflow checkout.")
  }
  source_root <- normalizePath(source_root, mustWork = TRUE)
  receipts <- .goal006_source_receipts()
  actual <- vapply(receipts$relative_path, function(relative_path) {
    path <- file.path(source_root, relative_path)
    if (!file.exists(path)) {
      .goal006_stop(paste0("Missing Judbury source: ", relative_path, "."))
    }
    digest::digest(file = path, algo = "sha256", serialize = FALSE)
  }, character(1))
  if (!identical(unname(actual), receipts$sha256)) {
    failed <- receipts$relative_path[actual != receipts$sha256]
    .goal006_stop(paste0(
      "Judbury source receipt mismatch: ",
      paste(failed, collapse = ", "),
      "."
    ))
  }
  head <- suppressWarnings(system2(
    "git",
    c("-C", source_root, "rev-parse", "HEAD"),
    stdout = TRUE,
    stderr = TRUE
  ))
  if (length(head) != 1L || !grepl("^[0-9a-f]{40}$", head)) {
    .goal006_stop("Could not record the camtrap-workflow Git commit.")
  }
  receipts |>
    dplyr::mutate(
      observed_sha256 = unname(actual),
      observed_git_commit = head
    )
}

.goal006_read_candidate_classes <- function(root) {
  path <- file.path(root, "config", "goal003_candidate_pool.csv")
  if (!file.exists(path) || !identical(
    digest::digest(file = path, algo = "sha256", serialize = FALSE),
    .goal006_candidate_hash
  )) {
    .goal006_stop("The frozen Goal006 candidate-pool receipt changed.")
  }
  pool <- tibble::as_tibble(utils::read.csv(
    path,
    stringsAsFactors = FALSE,
    check.names = FALSE
  ))
  candidates <- pool |>
    dplyr::filter(primary_pool == "include") |>
    dplyr::transmute(
      candidate_id = scientific_name,
      taxon_class,
      encounter_class = camera_encounter_class
    ) |>
    dplyr::arrange(candidate_id)
  valid <- nrow(pool) == 198L &&
    nrow(candidates) == 50L &&
    !anyDuplicated(candidates$candidate_id) &&
    all(candidates$encounter_class %in% c("routine", "occasional")) &&
    identical(
      as.integer(table(candidates$encounter_class)[c("occasional", "routine")]),
      c(6L, 44L)
    )
  if (!valid) {
    .goal006_stop("The Goal006 primary candidate classes changed.")
  }
  candidates
}

.goal006_read_effort <- function(root) {
  path <- file.path(root, "config", "goal003_task4_effort_template.csv")
  if (!file.exists(path) || !identical(
    digest::digest(file = path, algo = "sha256", serialize = FALSE),
    .goal006_effort_hash
  )) {
    .goal006_stop("The frozen Goal006 effort-template receipt changed.")
  }
  effort <- tibble::as_tibble(utils::read.csv(
    path,
    stringsAsFactors = FALSE,
    check.names = FALSE
  ))
  effort$occasion_index <- as.integer(effort$occasion_index)
  effort$active_days <- as.integer(effort$active_days)
  valid <- identical(
    names(effort),
    c("camera_id", "occasion_index", "active_days")
  ) &&
    nrow(effort) == 9L * 153L &&
    length(unique(effort$camera_id)) == 9L &&
    identical(sort(unique(effort$occasion_index)), seq_len(153L)) &&
    all(effort$active_days %in% 0:7) &&
    sum(effort$active_days) == 7644L &&
    sum(effort$active_days == 0L) == 266L &&
    !anyDuplicated(effort[c("camera_id", "occasion_index")])
  if (!valid) {
    .goal006_stop("The Goal006 effort template failed its frozen audit.")
  }
  effort
}

.goal006_calendar <- function() {
  origin <- as.Date("2019-06-05")
  tibble::tibble(
    occasion_id = sprintf("occ_%03d", seq_len(153L)),
    occasion_index = seq_len(153L),
    start_date = origin + 7L * (seq_len(153L) - 1L),
    end_date = origin + 7L * seq_len(153L) - 1L
  )
}

.goal006_window_effort <- function(effort, start, end) {
  selected <- effort |>
    dplyr::filter(occasion_index >= start, occasion_index <= end)
  by_camera <- selected |>
    dplyr::summarise(active_days = sum(active_days), .by = camera_id)
  c(
    active_station_days = sum(selected$active_days),
    active_stations = sum(by_camera$active_days > 0L),
    zero_effort_station_weeks = sum(selected$active_days == 0L)
  )
}

#' Construct the frozen Goal006 temporal folds using effort only
#'
#' @param effort Frozen nine-station weekly effort table.
#'
#' @return Ninety nested target histories paired to 18 disjoint forecasts.
goal006_expected_folds <- function(effort) {
  folds <- make_goal003_temporal_folds(
    .goal006_calendar(),
    training_occasions = c(4L, 8L, 12L, 16L, 26L),
    forecast_occasions = 4L
  ) |>
    dplyr::filter(
      forecast_start_index >= 81L,
      forecast_start_index <= 149L
    )
  target_effort <- t(vapply(seq_len(nrow(folds)), function(index) {
    .goal006_window_effort(
      effort,
      folds$train_start_index[[index]],
      folds$train_end_index[[index]]
    )
  }, numeric(3)))
  forecast_effort <- t(vapply(seq_len(nrow(folds)), function(index) {
    .goal006_window_effort(
      effort,
      folds$forecast_start_index[[index]],
      folds$forecast_end_index[[index]]
    )
  }, numeric(3)))
  names_target <- paste0("target_", colnames(target_effort))
  names_forecast <- paste0("forecast_", colnames(forecast_effort))

  result <- folds |>
    dplyr::mutate(
      analysis_id = sprintf(
        "g006-%02dw-f%03d",
        training_occasions,
        forecast_start_index
      ),
      forecast_id = sprintf(
        "g006-forecast-%03d-%03d",
        forecast_start_index,
        forecast_end_index
      ),
      duration_role = ifelse(
        training_occasions %in% c(4L, 8L),
        "negative_control",
        "eligible"
      )
    ) |>
    dplyr::select(
      analysis_id,
      forecast_id,
      duration_role,
      dplyr::everything()
    ) |>
    dplyr::bind_cols(
      stats::setNames(tibble::as_tibble(target_effort), names_target),
      stats::setNames(tibble::as_tibble(forecast_effort), names_forecast)
    ) |>
    dplyr::mutate(
      dplyr::across(
        dplyr::ends_with(c("days", "stations", "weeks")),
        as.integer
      )
    ) |>
    dplyr::arrange(training_occasions, forecast_start_index)

  valid <- nrow(result) == 90L &&
    !anyDuplicated(result$analysis_id) &&
    length(unique(result$forecast_id)) == 18L &&
    identical(sort(unique(result$training_occasions)), c(4L, 8L, 12L, 16L, 26L)) &&
    all(table(result$training_occasions) == 18L) &&
    identical(sort(unique(result$forecast_start_index)), seq(81L, 149L, 4L)) &&
    all(result$train_end_index + 1L == result$forecast_start_index) &&
    all(result$forecast_end_index - result$forecast_start_index == 3L) &&
    length(unique(result$uncertainty_block_id)) == 6L
  if (!valid) {
    .goal006_stop("The Goal006 fold construction differs from its frozen design.")
  }
  result
}

.goal006_read_folds <- function(root, effort) {
  path <- file.path(root, "config", "goal006_validation_folds.csv")
  if (!file.exists(path)) {
    .goal006_stop("The Goal006 fold manifest is missing.")
  }
  folds <- tibble::as_tibble(utils::read.csv(
    path,
    stringsAsFactors = FALSE,
    check.names = FALSE
  ))
  date_fields <- c(
    "train_start_date", "train_end_date", "forecast_start_date",
    "forecast_end_date", "forecast_midpoint"
  )
  integer_fields <- c(
    "training_occasions", "forecast_occasions", "train_start_index",
    "train_end_index", "forecast_start_index", "forecast_end_index",
    "season_year", "target_active_station_days", "target_active_stations",
    "target_zero_effort_station_weeks", "forecast_active_station_days",
    "forecast_active_stations", "forecast_zero_effort_station_weeks"
  )
  folds[date_fields] <- lapply(folds[date_fields], as.Date)
  folds[integer_fields] <- lapply(folds[integer_fields], as.integer)
  expected <- goal006_expected_folds(effort)
  if (!identical(folds, expected)) {
    .goal006_stop("The Goal006 fold manifest changed.")
  }
  folds
}

goal006_expected_synthetic_manifest <- function() {
  profiles <- tibble::tribble(
    ~profile_id, ~profile_code, ~routine_rate, ~occasional_rate,
    "nominal", 1L, 0.0020, 0.00050,
    "lower", 2L, 0.0010, 0.00025,
    "compressed", 3L, 0.0015, 0.00075
  )
  tidyr::crossing(profile_code = profiles$profile_code, replicate = 1:10) |>
    dplyr::left_join(profiles, by = "profile_code") |>
    dplyr::mutate(
      simulation_id = sprintf("g006t2-%s-r%02d", profile_id, replicate),
      calibration_start_index = 1L,
      calibration_end_index = 52L,
      candidate_pool_size = 50L,
      routine_candidates = 44L,
      occasional_candidates = 6L,
      true_members = 50L,
      log_rate_sd = 1,
      camera_sd = 0.35,
      simulation_seed = as.integer(610000000L + 100L * profile_code + replicate),
      fit_seed = as.integer(620000000L + 100L * profile_code + replicate)
    ) |>
    dplyr::arrange(profile_code, replicate) |>
    dplyr::select(
      simulation_id,
      profile_id,
      profile_code,
      replicate,
      calibration_start_index,
      calibration_end_index,
      candidate_pool_size,
      routine_candidates,
      occasional_candidates,
      true_members,
      routine_rate,
      occasional_rate,
      log_rate_sd,
      camera_sd,
      simulation_seed,
      fit_seed
    )
}

goal006_expected_calibration_fits <- function(effort) {
  cameras <- sort(unique(effort$camera_id), method = "radix")
  base <- tibble::tribble(
    ~calibration_profile, ~profile_code, ~class_prior_sd, ~log_rate_sd,
    "primary", 1L, 1.5, 1.00,
    "prior_wide", 2L, 3.0, 1.00,
    "spread_lower", 3L, 1.5, 0.75,
    "spread_upper", 4L, 1.5, 1.25
  ) |>
    dplyr::mutate(
      excluded_camera_id = NA_character_,
      excluded_start_index = NA_integer_,
      excluded_end_index = NA_integer_
    )
  loso <- tibble::tibble(
    calibration_profile = paste0("loso_", cameras),
    profile_code = 10L + seq_along(cameras),
    class_prior_sd = 1.5,
    log_rate_sd = 1,
    excluded_camera_id = cameras,
    excluded_start_index = NA_integer_,
    excluded_end_index = NA_integer_
  )
  temporal <- tibble::tibble(
    calibration_profile = sprintf("leave_quarter_%d", 1:4),
    profile_code = 21:24,
    class_prior_sd = 1.5,
    log_rate_sd = 1,
    excluded_camera_id = NA_character_,
    excluded_start_index = c(1L, 14L, 27L, 40L),
    excluded_end_index = c(13L, 26L, 39L, 52L)
  )
  dplyr::bind_rows(base, loso, temporal) |>
    dplyr::mutate(
      routine_prior_mean = log(0.002),
      occasional_prior_mean = log(0.0005),
      camera_sd_scale = 0.75,
      calibration_start_index = 1L,
      calibration_end_index = 52L,
      fit_seed = as.integer(630000000L + 1000L * profile_code)
    ) |>
    dplyr::arrange(profile_code)
}

goal006_expected_target_fits <- function(folds) {
  primary <- tidyr::crossing(
    analysis_id = folds$analysis_id,
    profile_code = 1:2
  ) |>
    dplyr::mutate(
      method = ifelse(profile_code == 1L, "flexirich", "occupancy"),
      fit_profile = ifelse(
        profile_code == 1L,
        "primary",
        "occupancy_fixed"
      )
    )
  sensitivities <- tidyr::crossing(
    analysis_id = folds$analysis_id[folds$duration_role == "eligible"],
    profile_code = 3L
  ) |>
    dplyr::mutate(
      method = "flexirich",
      fit_profile = "calibration_envelope_artifact"
    )
  dplyr::bind_rows(primary, sensitivities) |>
    dplyr::left_join(
      folds[c(
        "analysis_id", "training_occasions", "forecast_start_index",
        "duration_role"
      )],
      by = "analysis_id"
    ) |>
    dplyr::mutate(
      fit_id = paste(analysis_id, method, fit_profile, sep = "--"),
      fit_seed = as.integer(
        640000000L + 1000000L * profile_code +
          1000L * training_occasions + forecast_start_index
      )
    ) |>
    dplyr::arrange(
      training_occasions,
      forecast_start_index,
      profile_code
    ) |>
    dplyr::select(
      fit_id,
      analysis_id,
      duration_role,
      method,
      fit_profile,
      profile_code,
      training_occasions,
      forecast_start_index,
      fit_seed
    )
}

goal006_sampler_contract <- function() {
  list(
    profiles = goal003_flexirich_sampler_profiles(),
    diagnostics = goal003_flexirich_diagnostic_thresholds(),
    rescue_attempts = 1L
  )
}

goal006_model_contract <- function() {
  list(
    calibration_model_id = "selection_adjusted_class_location_v1",
    target_model_id = "finite_pool_joint_class_calibration_v1",
    class_order = c("routine", "occasional"),
    class_prior_mean = c(
      routine = log(0.002),
      occasional = log(0.0005)
    ),
    class_prior_sd = 1.5,
    log_rate_sd = 1,
    camera_sd_scale = 0.75,
    omega_alpha = 1,
    omega_beta = 1,
    lower_reference = 26L,
    candidate_pool_size = 50L,
    block_bootstrap_draws = 9999L,
    block_bootstrap_seed = 6006L
  )
}

goal006_expected_gates <- function() {
  gate <- function(
    stage, gate_id, metric, comparison, threshold, denominator, applies_to
  ) {
    tibble::tibble(
      stage = stage,
      gate_id = gate_id,
      metric = metric,
      comparison = comparison,
      threshold = as.numeric(threshold),
      denominator = as.numeric(denominator),
      applies_to = applies_to,
      required_for_advance = TRUE
    )
  }
  dplyr::bind_rows(
    gate("task2", "T2-likelihood-value", "maximum absolute log-likelihood bridge error", "at_most", 1e-8, NA, "deterministic bridge cases"),
    gate("task2", "T2-likelihood-gradient", "maximum absolute gradient bridge error", "at_most", 1e-5, NA, "deterministic bridge cases"),
    gate("task2", "T2-clean", "terminal-clean synthetic fits", "at_least", 29, 30, "all profiles"),
    gate("task2", "T2-clean-profile", "terminal-clean synthetic fits per profile", "at_least", 9, 10, "each profile"),
    gate("task2", "T2-routine-bias", "maximum absolute median routine-location bias", "at_most", 0.35, NA, "across profiles"),
    gate("task2", "T2-occasional-bias", "maximum absolute median occasional-location bias", "at_most", 0.50, NA, "across profiles"),
    gate("task2", "T2-routine-rmse", "pooled routine-location RMSE", "at_most", 0.60, NA, "all profiles"),
    gate("task2", "T2-occasional-rmse", "pooled occasional-location RMSE", "at_most", 0.80, NA, "all profiles"),
    gate("task2", "T2-routine-coverage", "fixed-denominator routine 90% interval coverage", "at_least", 25, 30, "all profiles"),
    gate("task2", "T2-occasional-coverage", "fixed-denominator occasional 90% interval coverage", "at_least", 25, 30, "all profiles"),
    gate("task2", "T2-class-coverage-profile", "fixed-denominator class 90% interval coverage per profile", "at_least", 8, 10, "each class and profile"),
    gate("task2", "T2-catastrophic", "non-clean or factor-three class-location errors", "strictly_less", 2, 30, "all profiles"),
    gate("task3", "T3-primary-clean", "terminal-clean primary calibration fit", "equal", 1, 1, "primary"),
    gate("task3", "T3-sensitivity-clean", "terminal-clean sensitivity calibration fits", "equal", 16, 16, "wide, spread, LOSO, and temporal"),
    gate("task3", "T3-detected-per-class", "detected calibration species per encounter class", "at_least", 3, NA, "each class"),
    gate("task3", "T3-primary-F", "maximum marginal 95% class uncertainty factor", "at_most", 2.00, NA, "primary"),
    gate("task3", "T3-wide-shift", "maximum absolute class-location shift from primary", "at_most", log(1.5), NA, "wide prior"),
    gate("task3", "T3-wide-F", "maximum marginal 95% class uncertainty factor", "at_most", 2.25, NA, "wide prior"),
    gate("task3", "T3-spread-shift", "maximum absolute class-location shift from primary", "at_most", log(1.5), NA, "spread endpoints"),
    gate("task3", "T3-spread-F", "maximum marginal 95% class uncertainty factor", "at_most", 2.50, NA, "spread endpoints"),
    gate("task3", "T3-LOSO-shift", "maximum absolute class-location shift from primary", "at_most", log(1.5), NA, "nine LOSO fits"),
    gate("task3", "T3-LOSO-F", "maximum marginal 95% class uncertainty factor", "at_most", 2.50, NA, "nine LOSO fits"),
    gate("task3", "T3-temporal-shift", "maximum absolute class-location shift from primary", "at_most", log(1.5), NA, "four leave-quarter-out fits"),
    gate("task3", "T3-temporal-F", "maximum marginal 95% class uncertainty factor", "at_most", 2.50, NA, "four leave-quarter-out fits"),
    gate("task3", "T3-Gaussian-quantiles", "maximum Gaussian versus empirical marginal quantile error", "at_most", 0.10, NA, "2.5%, 50%, and 97.5%"),
    gate("task3", "T3-Gaussian-radial", "Mahalanobis-radius KS distance from chi-square(2)", "at_most", 0.10, NA, "primary artifact"),
    gate("task3", "T3-Gaussian-skew", "maximum absolute marginal skewness", "at_most", 0.50, NA, "primary artifact"),
    gate("task4", "T4-primary-clean", "terminal-clean primary FlexiRich fits", "equal", 18, 18, "each eligible duration"),
    gate("task4", "T4-sensitivity-clean", "terminal-clean sensitivity FlexiRich fits", "equal", 18, 18, "calibration envelope at each eligible duration"),
    gate("task4", "T4-positive-folds", "forecast folds with at least one new species", "at_least", 4, 18, "each eligible duration"),
    gate("task4", "T4-positive-identities", "future-first-detection outcomes", "at_least", 5, NA, "each eligible duration"),
    gate("task4", "T4-count-skill", "mean count-RPS skill versus selected benchmark", "at_least", 0.10, NA, "each eligible duration"),
    gate("task4", "T4-count-skill-lower", "95% block-bootstrap lower count-skill bound", "at_least", -0.05, NA, "each eligible duration"),
    gate("task4", "T4-count-bias", "absolute mean expected-minus-observed new count", "at_most", 0.50, NA, "each eligible duration"),
    gate("task4", "T4-count-coverage", "fixed-denominator 90% count interval coverage", "at_least", 14, 18, "each eligible duration"),
    gate("task4", "T4-finite-log-score", "finite future-count log scores", "equal", 18, 18, "each eligible duration"),
    gate("task4", "T4-identity-ratio", "mean identity-Brier ratio to selected benchmark", "at_most", 1.05, NA, "each eligible duration"),
    gate("task4", "T4-identity-ratio-upper", "95% block-bootstrap upper identity-Brier ratio", "at_most", 1.05, NA, "each eligible duration"),
    gate("task4", "T4-block-deterioration", "season-year blocks with count RPS more than 25% worse", "equal", 0, 6, "each eligible duration"),
    gate("task4", "T4-reference-compatible", "90% richness intervals with upper bound at least 26", "at_least", 16, 18, "each eligible duration"),
    gate("task4", "T4-mean-ceiling-mass", "mean posterior mass at richness 50", "at_most", 0.05, NA, "each eligible duration"),
    gate("task4", "T4-max-ceiling-mass", "maximum posterior mass at richness 50", "at_most", 0.20, NA, "each eligible duration"),
    gate("task4", "T4-sensitivity-median", "median absolute posterior-mean richness shift", "at_most", 3, NA, "calibration envelope at each eligible duration"),
    gate("task4", "T4-sensitivity-max", "maximum absolute posterior-mean richness shift", "at_most", 8, NA, "calibration envelope at each eligible duration"),
    gate("task4", "T4-duration-median", "median absolute posterior-mean shift from 26 weeks", "at_most", 3, NA, "12 and 16 weeks"),
    gate("task4", "T4-duration-max", "maximum absolute posterior-mean shift from 26 weeks", "at_most", 8, NA, "12 and 16 weeks"),
    gate("task5", "T5-full-clean", "terminal-clean full-record calibration fit", "equal", 1, 1, "153-week refit"),
    gate("task5", "T5-full-F", "maximum marginal 95% class uncertainty factor", "at_most", 2.00, NA, "153-week refit"),
    gate("task5", "T5-location-shift", "maximum absolute full versus first-year class-location shift", "at_most", log(1.5), NA, "both classes"),
    gate("task5", "T5-Gaussian-quantiles", "maximum Gaussian versus empirical marginal quantile error", "at_most", 0.10, NA, "153-week artifact")
  )
}

goal006_output_schema <- function() {
  list(
    calibration_artifact = c(
      "artifact_version", "model_id", "calibration_start_index",
      "calibration_end_index", "class_order", "location_mean",
      "location_covariance", "class_prior", "log_rate_sd",
      "source_receipts", "fit_seed", "diagnostics",
      "approximation_checks"
    ),
    metadata = c("key", "value"),
    fit_status = c(
      "fit_id", "analysis_id", "method", "fit_profile", "fit_seed",
      "terminal_status", "terminal_clean", "elapsed_seconds",
      "divergences", "treedepth_hits", "max_rhat", "min_bulk_ess",
      "min_tail_ess", "min_ebfmi"
    ),
    richness = c(
      "analysis_id", "method", "fit_profile", "observed_richness",
      "posterior_mean", "lower_90", "median", "upper_90",
      "probability_at_least_26", "probability_at_50"
    ),
    forecast_count = c(
      "analysis_id", "method", "fit_profile", "true_new_species",
      "expected_new_species", "count_rps", "count_log_score",
      "lower_90", "upper_90", "covered_90"
    ),
    forecast_identity = c(
      "analysis_id", "method", "fit_profile", "candidate_id",
      "training_detected", "future_first_detected",
      "future_first_detection_probability"
    ),
    decision_gates = c(
      "stage", "gate_id", "training_occasions", "value", "threshold",
      "comparison", "numerator", "denominator", "passed"
    )
  )
}

#' Read and validate the complete Goal006 Task 1 contract
#'
#' @param root flexiRich repository root.
#' @param source_root Read-only `camtrap-workflow` checkout.
#' @param verify_external Whether to verify the external source hashes now.
#'
#' @return Deterministic Task 1 contract tables and content hashes.
read_goal006_task1_contract <- function(
  root = .goal003_project_root(),
  source_root = "/home/bwbrook/git/camtrap-workflow",
  verify_external = TRUE
) {
  root <- normalizePath(root, mustWork = TRUE)
  if (!is.logical(verify_external) || length(verify_external) != 1L ||
      is.na(verify_external)) {
    .goal006_stop("verify_external must be TRUE or FALSE.")
  }
  sources <- if (verify_external) {
    verify_goal006_source_receipts(source_root)
  } else {
    .goal006_source_receipts()
  }
  candidates <- .goal006_read_candidate_classes(root)
  effort <- .goal006_read_effort(root)
  folds <- .goal006_read_folds(root, effort)
  synthetic <- goal006_expected_synthetic_manifest()
  calibration_fits <- goal006_expected_calibration_fits(effort)
  target_fits <- goal006_expected_target_fits(folds)
  gates <- goal006_expected_gates()
  output_schema <- goal006_output_schema()
  model <- goal006_model_contract()
  tables <- list(
    sources = sources,
    candidates = candidates,
    effort = effort,
    folds = folds,
    synthetic = synthetic,
    calibration_fits = calibration_fits,
    target_fits = target_fits,
    gates = gates,
    output_schema = output_schema,
    model = model
  )
  stable_tables <- tables
  stable_tables$sources <- .goal006_source_receipts()
  hashes <- vapply(stable_tables, function(value) {
    digest::digest(value, algo = "sha256", serialize = TRUE)
  }, character(1))
  list(
    sources = sources,
    candidates = candidates,
    effort = effort,
    folds = folds,
    synthetic = synthetic,
    calibration_fits = calibration_fits,
    target_fits = target_fits,
    gates = gates,
    output_schema = output_schema,
    model = model,
    hashes = hashes
  )
}
