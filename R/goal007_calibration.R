#' Derive routine and occasional locations from shared-shift parameters
#'
#' @param common_shift Common absolute shift from both base locations.
#' @param contrast_deviation Deviation from the base occasional--routine
#'   contrast.
#' @param base_location Named routine and occasional base locations.
#'
#' @return Named routine and occasional class locations.
goal007_class_locations <- function(
  common_shift,
  contrast_deviation,
  base_location = goal007_model_contract()$base_location
) {
  scalar <- function(value) {
    is.numeric(value) && !is.logical(value) && length(value) == 1L &&
      !is.na(value) && is.finite(value)
  }
  valid_base <- is.numeric(base_location) && length(base_location) == 2L &&
    identical(names(base_location), c("routine", "occasional")) &&
    !anyNA(base_location) && all(is.finite(base_location))
  if (!scalar(common_shift) || !scalar(contrast_deviation) || !valid_base) {
    .goal007_stop("Invalid Goal007 shared-shift parameters.")
  }
  c(
    routine = base_location[["routine"]] + common_shift,
    occasional = base_location[["occasional"]] + common_shift +
      contrast_deviation
  )
}

goal007_prior_bridge_metrics <- function() {
  model <- goal007_model_contract()
  candidates <- goal007_expected_models() |>
    dplyr::filter(eligible_for_selection)
  rows <- lapply(seq_len(nrow(candidates)), function(index) {
    candidate <- candidates[index, ]
    linear_map <- matrix(c(1, 1, 0, 1), nrow = 2L)
    primitive <- diag(c(
      model$common_shift_sd^2,
      candidate$contrast_sd^2
    ))
    matrix_covariance <- linear_map %*% primitive %*% t(linear_map)
    direct_covariance <- matrix(c(
      model$common_shift_sd^2,
      model$common_shift_sd^2,
      model$common_shift_sd^2,
      model$common_shift_sd^2 + candidate$contrast_sd^2
    ), nrow = 2L)
    tibble::tibble(
      model_id = candidate$model_id,
      factor_error = abs(
        exp(.goal007_q975 * candidate$contrast_sd) -
          candidate$contrast_factor
      ),
      covariance_error = max(abs(matrix_covariance - direct_covariance))
    )
  }) |>
    dplyr::bind_rows()
  tibble::tibble(
    maximum_transform_error = max(rows$factor_error),
    maximum_covariance_error = max(rows$covariance_error),
    transform_tolerance = 1e-12,
    covariance_tolerance = 1e-12,
    passed = maximum_transform_error <= transform_tolerance &
      maximum_covariance_error <= covariance_tolerance
  )
}

.goal007_shared_model_row <- function(model_id) {
  selected <- .goal007_selected_model(model_id)
  if (!identical(selected$model_family, "shared_shift")) {
    .goal007_stop("Goal007 shared calibration requires a shared-shift model.")
  }
  selected
}

.goal007_base_calibration_profile <- function() {
  model <- goal007_model_contract()
  tibble::tibble(
    calibration_profile = "goal007_primary",
    profile_code = 1L,
    class_prior_sd = model$common_shift_sd,
    log_rate_sd = model$log_rate_sd,
    excluded_camera_id = NA_character_,
    excluded_start_index = NA_integer_,
    excluded_end_index = NA_integer_,
    routine_prior_mean = unname(model$base_location[["routine"]]),
    occasional_prior_mean = unname(model$base_location[["occasional"]]),
    camera_sd_scale = model$camera_sd_scale,
    calibration_start_index = 1L,
    calibration_end_index = 52L,
    fit_seed = 1L
  )
}

#' Prepare the Goal007 shared-shift selection-calibration likelihood
#'
#' @param source_data Canonical histories covering the calibration period.
#' @param encounter_class Named routine/occasional class for every candidate.
#' @param model_id Either `shared_F5` or `shared_F3`.
#' @param quadrature_order Fixed Gauss--Hermite order.
#'
#' @return Internal shared-shift calibration data without synthetic truth.
prepare_goal007_calibration_data <- function(
  source_data,
  encounter_class,
  model_id,
  quadrature_order = 64L
) {
  model_row <- .goal007_shared_model_row(model_id)
  base <- prepare_goal006_calibration_data(
    source_data,
    encounter_class,
    .goal007_base_calibration_profile(),
    quadrature_order
  )
  stan_data <- base$stan_data
  stan_data$class_prior_mean <- NULL
  stan_data$class_prior_sd <- NULL
  stan_data$base_location <- unname(goal007_model_contract()$base_location)
  stan_data$common_shift_sd <- goal007_model_contract()$common_shift_sd
  stan_data$contrast_sd <- model_row$contrast_sd[[1L]]
  result <- list(
    base_data = base,
    model_spec = model_row,
    stan_data = stan_data,
    model_id = goal007_model_contract()$calibration_model_id,
    data_hash = digest::digest(
      list(
        base_hash = base$data_hash,
        model_spec = model_row,
        base_location = stan_data$base_location,
        common_shift_sd = stan_data$common_shift_sd,
        contrast_sd = stan_data$contrast_sd
      ),
      algo = "sha256",
      serialize = TRUE
    )
  )
  validate_goal007_calibration_data(result)
  result
}

#' Validate internal Goal007 shared-shift calibration data
validate_goal007_calibration_data <- function(data) {
  required <- c("base_data", "model_spec", "stan_data", "model_id", "data_hash")
  base_valid <- tryCatch({
    .validate_goal006_calibration_data(data$base_data)
    TRUE
  }, error = function(error) FALSE)
  expected_model <- tryCatch(
    .goal007_shared_model_row(data$model_spec$model_id[[1L]]),
    error = function(error) NULL
  )
  forbidden <- c(
    "class_prior_mean", "class_prior_sd", "truth", "member", "omega",
    "q_member"
  )
  valid <- is.list(data) && identical(names(data), required) && base_valid &&
    inherits(data$model_spec, "data.frame") && nrow(data$model_spec) == 1L &&
    !is.null(expected_model) && identical(data$model_spec, expected_model) &&
    is.list(data$stan_data) &&
    identical(data$stan_data$D, data$base_data$stan_data$D) &&
    identical(data$stan_data$J, data$base_data$stan_data$J) &&
    identical(data$stan_data$class_index, data$base_data$class_index) &&
    !any(forbidden %in% names(data$stan_data)) &&
    identical(
      data$stan_data$base_location,
      unname(goal007_model_contract()$base_location)
    ) &&
    identical(
      data$stan_data$common_shift_sd,
      goal007_model_contract()$common_shift_sd
    ) &&
    identical(data$stan_data$contrast_sd, data$model_spec$contrast_sd[[1L]]) &&
    identical(data$model_id, goal007_model_contract()$calibration_model_id) &&
    is.character(data$data_hash) && length(data$data_hash) == 1L &&
    grepl("^[0-9a-f]{64}$", data$data_hash)
  if (!valid) {
    .goal007_stop("data must be canonical Goal007 shared calibration data.")
  }
  invisible(TRUE)
}

#' Independent Goal007 likelihood terms for the Stan/R bridge
goal007_calibration_likelihood_terms <- function(
  data,
  common_shift,
  contrast_deviation,
  alpha,
  camera_effect
) {
  validate_goal007_calibration_data(data)
  locations <- goal007_class_locations(
    common_shift,
    contrast_deviation,
    stats::setNames(
      data$stan_data$base_location,
      c("routine", "occasional")
    )
  )
  terms <- goal006_calibration_likelihood_terms(
    data$base_data,
    unname(locations),
    alpha,
    camera_effect
  )
  c(list(class_location = locations), terms)
}

#' Compile the Goal007 shared-shift calibration model
compile_goal007_calibration_model <- function(force_recompile = FALSE) {
  .goal003_compile_model(
    stan_file = file.path("stan", "goal007_shared_shift_calibration.stan"),
    cache_id = "shared-shift-calibration",
    executable_stem = "goal007-shared-shift-calibration",
    output_namespace = "goal007",
    force_recompile = force_recompile
  )
}

.goal007_calibration_monitored_variables <- function(data) {
  validate_goal007_calibration_data(data)
  c(
    "common_shift", "contrast_deviation", "class_location",
    "sigma_camera", "alpha", "camera_effect"
  )
}

#' Fit the Goal007 shared-shift calibration model
fit_goal007_calibration <- function(
  data,
  seed,
  output_dir,
  refresh = 100L
) {
  validate_goal007_calibration_data(data)
  valid_integer <- function(value, lower) {
    is.numeric(value) && !is.logical(value) && length(value) == 1L &&
      !is.na(value) && is.finite(value) && value == trunc(value) &&
      value >= lower && value < .Machine$integer.max
  }
  if (!valid_integer(seed, 1L) || !valid_integer(refresh, 0L)) {
    .goal007_stop("Goal007 calibration fit controls are invalid.")
  }
  absolute_output <- .goal003_prepare_output_directory(
    output_dir,
    output_namespace = "goal007"
  )
  attempts <- .goal004_task4_run_attempts(
    model = compile_goal007_calibration_model(),
    stan_data = data$stan_data,
    profiles = goal003_flexirich_sampler_profiles(),
    thresholds = goal003_flexirich_diagnostic_thresholds(),
    monitored = .goal007_calibration_monitored_variables(data),
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

.goal007_terminal_calibration_fit <- function(result) {
  valid <- is.list(result) && result$terminal_status %in%
    c("primary_clean", "rescue_clean") && is.list(result$data)
  if (!valid) {
    .goal007_stop("result must contain a terminal-clean Goal007 calibration fit.")
  }
  validate_goal007_calibration_data(result$data)
  attempt <- if (result$terminal_status == "primary_clean") "primary" else "rescue"
  result$attempts[[attempt]]$fit
}

.goal007_calibration_draws <- function(result) {
  fit <- .goal007_terminal_calibration_fit(result)
  posterior::as_draws_matrix(fit$draws(variables = "class_location"))[, 1:2]
}

#' Build a leakage-safe Goal007 aggregate calibration artifact
make_goal007_calibration_artifact <- function(result, source_hashes, fit_seed) {
  data <- result$data
  validate_goal007_calibration_data(data)
  draws <- as.matrix(.goal007_calibration_draws(result))
  class_order <- c("routine", "occasional")
  colnames(draws) <- class_order
  location_mean <- colMeans(draws)
  location_covariance <- stats::cov(draws)
  dimnames(location_covariance) <- list(class_order, class_order)
  empirical <- apply(
    draws,
    2L,
    stats::quantile,
    probs = c(0.025, 0.5, 0.975),
    names = FALSE
  )
  gaussian <- vapply(seq_len(2L), function(index) {
    stats::qnorm(
      c(0.025, 0.5, 0.975),
      mean = location_mean[index],
      sd = sqrt(location_covariance[index, index])
    )
  }, numeric(3))
  skewness <- vapply(seq_len(2L), function(index) {
    centred <- draws[, index] - location_mean[index]
    mean(centred^3) / stats::sd(draws[, index])^3
  }, numeric(1))
  radial <- stats::mahalanobis(draws, location_mean, location_covariance)
  terminal <- if (result$terminal_status == "primary_clean") "primary" else "rescue"
  artifact <- list(
    artifact_version = "goal007-calibration-artifact-v1",
    model_id = data$model_spec$model_id[[1L]],
    class_order = class_order,
    location_mean = location_mean,
    location_covariance = location_covariance,
    prior_metadata = list(
      base_location = stats::setNames(data$stan_data$base_location, class_order),
      common_shift_sd = data$stan_data$common_shift_sd,
      contrast_factor = data$model_spec$contrast_factor[[1L]],
      contrast_sd = data$stan_data$contrast_sd,
      log_rate_sd = data$stan_data$log_rate_sd,
      camera_sd_scale = data$stan_data$sigma_camera_scale
    ),
    fit_seed = as.integer(fit_seed),
    source_hashes = source_hashes,
    diagnostics = result$attempts[[terminal]]$diagnostics,
    approximation_checks = list(
      max_quantile_error = max(abs(empirical - gaussian)),
      radial_ks_distance = .goal006_radial_ks(radial),
      max_abs_skewness = max(abs(skewness))
    )
  )
  validate_goal007_calibration_artifact(artifact)
  artifact
}

#' Validate the leakage boundary of a Goal007 calibration artifact
validate_goal007_calibration_artifact <- function(artifact) {
  schema <- goal007_output_schema()$calibration_artifact
  text <- tolower(paste(capture.output(str(artifact)), collapse = " "))
  valid <- is.list(artifact) && identical(names(artifact), schema) &&
    is.character(artifact$artifact_version) &&
    identical(artifact$artifact_version, "goal007-calibration-artifact-v1") &&
    is.character(artifact$model_id) && length(artifact$model_id) == 1L &&
    artifact$model_id %in% c("shared_F5", "shared_F3") &&
    identical(artifact$class_order, c("routine", "occasional")) &&
    is.numeric(artifact$location_mean) && all(is.finite(artifact$location_mean)) &&
    identical(names(artifact$location_mean), artifact$class_order) &&
    is.matrix(artifact$location_covariance) &&
    identical(dim(artifact$location_covariance), c(2L, 2L)) &&
    all(is.finite(artifact$location_covariance)) &&
    isTRUE(all.equal(
      artifact$location_covariance,
      t(artifact$location_covariance),
      tolerance = 1e-12,
      check.attributes = FALSE
    )) &&
    all(diag(artifact$location_covariance) > 0) &&
    is.list(artifact$prior_metadata) &&
    inherits(artifact$source_hashes, "data.frame") &&
    is.numeric(artifact$fit_seed) && length(artifact$fit_seed) == 1L &&
    !is.na(artifact$fit_seed) && is.finite(artifact$fit_seed) &&
    artifact$fit_seed == trunc(artifact$fit_seed) && artifact$fit_seed >= 1L &&
    is.list(artifact$diagnostics) &&
    is.list(artifact$approximation_checks) &&
    !any(vapply(
      .goal007_forbidden_artifact_terms,
      grepl,
      logical(1),
      x = text,
      fixed = TRUE
    ))
  if (!valid) {
    .goal007_stop("The Goal007 calibration artifact violates its boundary.")
  }
  invisible(TRUE)
}
