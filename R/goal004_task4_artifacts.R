.goal004_task4_write_prior_forecasts <- function(manifest, staging) {
  forecast <- goal004_task4_prior_forecasts(
    n_draws = 50000L,
    seed = 40042L,
    manifest = manifest
  )
  saveRDS(forecast, file.path(staging, "prior-forecasts.rds"), version = 3)
  .goal003_task4_write_csv(
    forecast$effort_windows,
    file.path(staging, "effort-windows.csv")
  )
  .goal003_task4_write_csv(
    forecast$predictive_summary,
    file.path(staging, "predictive-summary.csv")
  )
  .goal003_task4_write_csv(
    tibble::enframe(
      forecast$task2_anchor_max_abs_error,
      name = "anchor_metric",
      value = "max_abs_error"
    ),
    file.path(staging, "task2-anchor-check.csv")
  )
  writeLines(
    c(
      "status=COMPLETE",
      "seed=40042",
      "draws=50000",
      "task2_anchor_max_abs_error=0",
      "empirical_outcomes_used=false"
    ),
    file.path(staging, "completion-status.txt")
  )
}
.goal004_task4_dataset_profiles <- function(dataset_id, manifest) {
  profiles <- manifest$fits |>
    dplyr::filter(
      .data$dataset_id == .env$dataset_id,
      method == "goal004"
    ) |>
    dplyr::pull(prior_profile) |>
    unique()
  if (!"primary" %in% profiles) {
    profiles <- c("primary", profiles)
  }
  profiles
}

.goal004_task4_write_dataset <- function(
  dataset_row,
  manifest,
  prior_forecasts,
  staging
) {
  simulation <- simulate_goal004_task4_dataset(dataset_row, manifest)
  baseline <- evaluate_goal003_task4_baselines(simulation)
  prior <- lapply(
    .goal004_task4_dataset_profiles(dataset_row$dataset_id[[1L]], manifest),
    function(profile) {
      score_goal004_task4_prior(
        dataset_row,
        simulation$truth,
        prior_forecasts,
        profile_id = profile
      )
    }
  )
  prior_richness <- dplyr::bind_rows(lapply(prior, `[[`, "richness"))
  prior_discovery <- dplyr::bind_rows(lapply(prior, `[[`, "discovery"))
  prior_membership <- dplyr::bind_rows(lapply(prior, `[[`, "membership"))

  saveRDS(simulation, file.path(staging, "simulation.rds"), version = 3)
  .goal003_task4_write_csv(
    simulation$truth$species,
    file.path(staging, "truth-species.csv")
  )
  .goal003_task4_write_csv(
    simulation$truth$cameras,
    file.path(staging, "truth-cameras.csv")
  )
  .goal003_task4_write_csv(
    baseline$point_predictions,
    file.path(staging, "baseline-point-predictions.csv")
  )
  .goal003_task4_write_csv(
    baseline$richness_scores,
    file.path(staging, "baseline-richness-scores.csv")
  )
  .goal003_task4_write_csv(
    baseline$discovery_scores,
    file.path(staging, "baseline-discovery-scores.csv")
  )
  .goal003_task4_write_csv(
    prior_richness,
    file.path(staging, "prior-richness-scores.csv")
  )
  .goal003_task4_write_csv(
    prior_discovery,
    file.path(staging, "prior-discovery-scores.csv")
  )
  .goal003_task4_write_csv(
    prior_membership,
    file.path(staging, "prior-membership-scores.csv")
  )
  status <- dplyr::bind_cols(
    dataset_row,
    tibble::tibble(
      observed_richness = simulation$truth$observed_richness,
      true_new_species = simulation$truth$true_new_species,
      training_active_camera_days =
        simulation$audit$training_active_camera_days,
      forecast_active_camera_days =
        simulation$audit$forecast_active_camera_days,
      training_data_hash = simulation$training_data$data_hash,
      prior_profiles_scored = length(prior)
    )
  )
  .goal003_task4_write_csv(status, file.path(staging, "dataset-status.csv"))
  required <- c(
    "simulation.rds", "truth-species.csv", "truth-cameras.csv",
    "baseline-point-predictions.csv", "baseline-richness-scores.csv",
    "baseline-discovery-scores.csv", "prior-richness-scores.csv",
    "prior-discovery-scores.csv", "prior-membership-scores.csv",
    "dataset-status.csv"
  )
  if (any(!file.exists(file.path(staging, required))) ||
      nrow(prior_richness) != length(prior)) {
    .goal004_task4_stop("Goal004 Task 4 dataset readback failed.")
  }
  writeLines(
    c(
      "status=COMPLETE",
      paste0("dataset_id=", dataset_row$dataset_id),
      paste0("simulation_seed=", dataset_row$simulation_seed),
      "empirical_outcomes_used=false"
    ),
    file.path(staging, "completion-status.txt")
  )
}

.goal004_task4_run_attempts <- function(
  model,
  stan_data,
  profiles,
  thresholds,
  monitored,
  seed,
  output_dir,
  refresh
) {
  primary <- .goal003_model_attempt(
    model = model,
    stan_data = stan_data,
    sampler_profile = profiles$primary,
    diagnostic_thresholds = thresholds,
    monitored_variables = monitored,
    seed = as.integer(seed),
    output_dir = file.path(output_dir, "primary"),
    attempt_id = "primary",
    refresh = as.integer(refresh)
  )
  attempts <- list(primary = primary)
  rescue <- NULL
  if (!isTRUE(primary$diagnostics$clean)) {
    rescue <- .goal003_model_attempt(
      model = model,
      stan_data = stan_data,
      sampler_profile = profiles$rescue,
      diagnostic_thresholds = thresholds,
      monitored_variables = monitored,
      seed = as.integer(seed) + 1L,
      output_dir = file.path(output_dir, "rescue"),
      attempt_id = "rescue",
      refresh = as.integer(refresh)
    )
    attempts$rescue <- rescue
  }
  list(
    terminal_status = .goal003_terminal_status(primary, rescue),
    attempts = attempts
  )
}

.goal004_task4_fit_model <- function(data, fit_row, output_dir, refresh) {
  method <- fit_row$method[[1L]]
  if (identical(method, "goal004")) {
    prepared <- prepare_goal004_flexirich_data(
      data,
      stats::setNames(
        goal004_task2_candidate_mapping()$core$encounter_class,
        goal004_task2_candidate_mapping()$core$candidate_id
      ),
      profile_id = fit_row$prior_profile[[1L]]
    )
    model <- compile_goal004_flexirich_model()
    profiles <- goal003_flexirich_sampler_profiles()
    thresholds <- goal003_flexirich_diagnostic_thresholds()
    monitored <- .goal004_flexirich_monitored_variables(prepared)
    extras <- list(profile = goal004_flexirich_profile(prepared$profile_id))
  } else if (identical(method, "goal003")) {
    prepared <- prepare_goal003_flexirich_data(data, prior_id = "primary")
    model <- compile_goal003_flexirich_model()
    profiles <- goal003_flexirich_sampler_profiles()
    thresholds <- goal003_flexirich_diagnostic_thresholds()
    monitored <- .goal003_flexirich_monitored_variables(prepared)
    extras <- list(prior = goal003_flexirich_prior_profiles()$primary)
  } else if (identical(method, "occupancy")) {
    prepared <- prepare_goal003_occupancy_data(data)
    model <- compile_goal003_occupancy_model()
    profiles <- goal003_occupancy_sampler_profiles()
    thresholds <- goal003_occupancy_diagnostic_thresholds()
    monitored <- c("mu_psi", "sigma_psi", "mu_log_rate", "sigma_log_rate")
    extras <- list(prior = goal003_occupancy_prior())
  } else if (identical(method, "goal004_nested")) {
    prepared <- prepare_goal004_nested_data(data)
    model <- compile_goal004_nested_model()
    profiles <- goal003_flexirich_sampler_profiles()
    thresholds <- goal003_flexirich_diagnostic_thresholds()
    monitored <- .goal004_nested_monitored_variables(prepared)
    extras <- list()
  } else {
    .goal004_task4_stop("The Goal004 fit manifest names an unknown method.")
  }
  if (any(c("truth", "member", "true_richness") %in% names(prepared))) {
    .goal004_task4_stop("Synthetic truth entered fitted Goal004 data.")
  }
  attempt <- .goal004_task4_run_attempts(
    model,
    prepared$stan_data,
    profiles,
    thresholds,
    monitored,
    fit_row$fit_seed[[1L]],
    output_dir,
    refresh
  )
  result <- c(
    list(
      terminal_status = attempt$terminal_status,
      data = prepared
    ),
    extras,
    list(output_dir = output_dir, attempts = attempt$attempts)
  )
  if (identical(method, "goal004_nested")) {
    expected_names <- c("terminal_status", "data", "output_dir", "attempts")
  } else {
    expected_names <- if (identical(method, "goal004")) {
      c("terminal_status", "data", "profile", "output_dir", "attempts")
    } else {
      c("terminal_status", "data", "prior", "output_dir", "attempts")
    }
  }
  if (!identical(names(result), expected_names)) {
    .goal004_task4_stop("A Goal004 Task 4 fit result has an invalid contract.")
  }
  result
}

.goal004_task4_adapt_prediction <- function(method, prediction) {
  if (is.null(prediction)) {
    return(list(
      richness = NULL,
      discovery = NULL,
      future_identity = NULL,
      membership = NULL
    ))
  }
  if (identical(method, "goal004")) {
    return(list(
      richness = prediction$posterior_richness_pmf,
      discovery = prediction$future_discovery_pmf |>
        dplyr::rename(new_species_count = future_discoveries),
      future_identity = prediction$future_identity |>
        dplyr::transmute(
          species_id = candidate_id,
          training_detected,
          future_first_detection_probability
        ),
      membership = prediction$candidate_membership |>
        dplyr::transmute(
          species_id = candidate_id,
          membership_probability = posterior_membership_probability
        )
    ))
  }
  if (identical(method, "goal003")) {
    return(list(
      richness = prediction$richness_pmf,
      discovery = prediction$new_species_count_pmf,
      future_identity = prediction$future_identity,
      membership = prediction$grid_identity |>
        dplyr::select(species_id, membership_probability)
    ))
  }
  if (identical(method, "occupancy")) {
    return(list(
      richness = prediction$richness_pmf,
      discovery = prediction$new_species_count_pmf,
      future_identity = prediction$future_identity,
      membership = prediction$grid_identity |>
        dplyr::transmute(
          species_id,
          membership_probability = grid_use_probability
        )
    ))
  }
  list(
    richness = prediction$core_richness_pmf,
    discovery = NULL,
    future_identity = NULL,
    membership = prediction$core_membership |>
      dplyr::select(species_id, membership_probability)
  )
}

.goal004_task4_predict_fit <- function(fit, fit_row, future_effort) {
  if (identical(fit$terminal_status, "final_nonclean")) {
    return(NULL)
  }
  switch(
    fit_row$method[[1L]],
    goal004 = predict_goal004_flexirich(fit, future_effort),
    goal003 = predict_goal003_flexirich(fit, future_effort),
    occupancy = predict_goal003_occupancy(fit, future_effort),
    goal004_nested = predict_goal004_nested(fit),
    .goal004_task4_stop("Unknown Goal004 Task 4 prediction method.")
  )
}

.goal004_task4_compress_sampler_csv <- function(staging) {
  paths <- list.files(
    file.path(staging, "sampler"),
    pattern = "[.]csv$",
    recursive = TRUE,
    full.names = TRUE
  )
  if (length(paths) == 0L) {
    return(invisible(character()))
  }
  gzip <- Sys.which("gzip")
  if (!nzchar(gzip)) {
    .goal004_task4_stop("gzip is required for raw CmdStan evidence.")
  }
  status <- vapply(paths, function(path) {
    system2(gzip, c("-f", "--", path), stdout = FALSE, stderr = FALSE)
  }, integer(1))
  compressed <- paste0(paths, ".gz")
  if (any(status != 0L) || any(!file.exists(compressed))) {
    .goal004_task4_stop("A raw CmdStan CSV could not be compressed.")
  }
  invisible(compressed)
}

.goal004_task4_validate_fit_readback <- function(staging, clean) {
  required <- c(
    "fit-status.csv", "richness-score.csv", "discovery-score.csv",
    "membership-score.csv"
  )
  if (any(!file.exists(file.path(staging, required)))) {
    .goal004_task4_stop("Goal004 compact fit evidence is incomplete.")
  }
  counts <- vapply(required, function(file) {
    nrow(utils::read.csv(file.path(staging, file), check.names = FALSE))
  }, integer(1))
  if (any(counts != 1L)) {
    .goal004_task4_stop("Goal004 compact fit evidence failed readback.")
  }
  if (clean) {
    path <- file.path(staging, "richness-pmf.csv")
    if (!file.exists(path)) {
      .goal004_task4_stop("A clean Goal004 fit lacks its richness PMF.")
    }
    pmf <- utils::read.csv(path, check.names = FALSE)
    if (abs(sum(pmf$probability) - 1) > 1e-10) {
      .goal004_task4_stop("A Goal004 richness PMF failed readback.")
    }
  }
  invisible(TRUE)
}

.goal004_task4_write_fit <- function(
  fit_row,
  simulation,
  staging,
  refresh
) {
  sampler_dir <- file.path(staging, "sampler")
  fit <- .goal004_task4_fit_model(
    simulation$training_data,
    fit_row,
    sampler_dir,
    refresh
  )
  clean <- fit$terminal_status %in% c("primary_clean", "rescue_clean")
  raw_prediction <- .goal004_task4_predict_fit(
    fit,
    fit_row,
    simulation$forecast_effort
  )
  prediction <- .goal004_task4_adapt_prediction(
    fit_row$method[[1L]],
    raw_prediction
  )
  scores <- score_goal004_task4_fit(
    fit_row,
    simulation$truth,
    terminal_clean = clean,
    richness_pmf = prediction$richness,
    discovery_pmf = prediction$discovery,
    future_identity = prediction$future_identity,
    membership_probability = prediction$membership
  )
  status <- .goal003_task4_fit_status(fit_row, fit)
  .goal003_task4_write_csv(status, file.path(staging, "fit-status.csv"))
  .goal003_task4_write_csv(
    scores$richness,
    file.path(staging, "richness-score.csv")
  )
  .goal003_task4_write_csv(
    scores$discovery,
    file.path(staging, "discovery-score.csv")
  )
  .goal003_task4_write_csv(
    scores$membership,
    file.path(staging, "membership-score.csv")
  )
  if (clean) {
    .goal003_task4_write_csv(
      prediction$richness,
      file.path(staging, "richness-pmf.csv")
    )
    .goal003_task4_write_csv(
      prediction$membership,
      file.path(staging, "candidate-membership.csv")
    )
    if (!is.null(prediction$discovery)) {
      .goal003_task4_write_csv(
        prediction$discovery,
        file.path(staging, "new-species-count-pmf.csv")
      )
      .goal003_task4_write_csv(
        prediction$future_identity,
        file.path(staging, "future-detection-probabilities.csv")
      )
    }
    if (identical(fit_row$method[[1L]], "goal004_nested")) {
      .goal003_task4_write_csv(
        raw_prediction$fringe_richness_pmf,
        file.path(staging, "fringe-richness-pmf.csv")
      )
      .goal003_task4_write_csv(
        raw_prediction$total_richness_pmf,
        file.path(staging, "total-richness-pmf.csv")
      )
      .goal003_task4_write_csv(
        raw_prediction$fringe_membership,
        file.path(staging, "fringe-membership.csv")
      )
      nested_summary <- dplyr::bind_rows(
        dplyr::mutate(
          raw_prediction$core_richness_summary,
          component = "core",
          .before = 1L
        ),
        dplyr::mutate(
          raw_prediction$fringe_richness_summary,
          component = "fringe",
          .before = 1L
        ),
        dplyr::mutate(
          raw_prediction$total_richness_summary,
          component = "total",
          .before = 1L
        )
      )
      .goal003_task4_write_csv(
        nested_summary,
        file.path(staging, "nested-richness-summary.csv")
      )
    }
  }
  .goal003_task4_write_fit_summary(fit, staging)
  .goal004_task4_validate_fit_readback(staging, clean)
  .goal004_task4_compress_sampler_csv(staging)
  writeLines(
    c(
      "status=COMPLETE",
      paste0("fit_id=", fit_row$fit_id),
      paste0("terminal_status=", fit$terminal_status),
      paste0("fit_seed=", fit_row$fit_seed),
      "empirical_outcomes_used=false"
    ),
    file.path(staging, "completion-status.txt")
  )
}
