goal005_class_calibration_prior <- function() {
  list(
    model_id = "class_location_calibration_v1",
    omega_alpha = 1,
    omega_beta = 1,
    log_rate_sd = 1,
    sigma_camera_scale = 0.75
  )
}

.goal005_class_calibration_hash <- function(
  source_data_hash,
  candidate_ids,
  encounter_class,
  location_estimate,
  calibration_sd
) {
  digest::digest(
    list(
      source_data_hash = source_data_hash,
      candidate_ids = candidate_ids,
      encounter_class = encounter_class,
      location_estimate = location_estimate,
      calibration_sd = calibration_sd,
      prior = goal005_class_calibration_prior()
    ),
    algo = "sha256",
    serialize = TRUE
  )
}

.validate_goal005_class_calibration_data <- function(data) {
  required <- c(
    "candidate_ids", "camera_ids", "encounter_class", "class_index",
    "detected_ever", "location_estimate", "calibration_sd", "stan_data",
    "source_data", "model_id", "data_hash"
  )
  if (!is.list(data) || !identical(names(data), required)) {
    .goal005_stop("data must be canonical Goal005 class-calibration data.")
  }
  source_valid <- tryCatch({
    validate_flexirich_g_data(data$source_data)
    TRUE
  }, error = function(e) FALSE)
  prior <- goal005_class_calibration_prior()
  expected_class_index <- match(
    data$encounter_class,
    c("routine", "occasional")
  )
  expected_stan <- if (source_valid) {
    c(
      data$source_data$stan_data,
      list(
        omega_alpha = prior$omega_alpha,
        omega_beta = prior$omega_beta,
        class_index = as.integer(expected_class_index),
        location_estimate = as.numeric(data$location_estimate),
        calibration_sd = as.numeric(data$calibration_sd),
        log_rate_sd = prior$log_rate_sd,
        sigma_camera_scale = prior$sigma_camera_scale
      )
    )
  } else {
    NULL
  }
  expected_hash <- if (source_valid) {
    .goal005_class_calibration_hash(
      data$source_data$data_hash,
      data$candidate_ids,
      data$encounter_class,
      data$location_estimate,
      data$calibration_sd
    )
  } else {
    NA_character_
  }
  C <- length(data$candidate_ids)
  J <- length(data$camera_ids)
  valid <- source_valid &&
    C > 0L &&
    J > 0L &&
    is.character(data$candidate_ids) &&
    identical(data$candidate_ids, data$source_data$candidate_ids) &&
    is.character(data$camera_ids) &&
    identical(data$camera_ids, data$source_data$camera_ids) &&
    is.character(data$encounter_class) &&
    length(data$encounter_class) == C &&
    !anyNA(data$encounter_class) &&
    all(data$encounter_class %in% c("routine", "occasional")) &&
    is.integer(data$class_index) &&
    identical(data$class_index, as.integer(expected_class_index)) &&
    is.integer(data$detected_ever) &&
    identical(data$detected_ever, data$source_data$stan_data$detected_ever) &&
    is.numeric(data$location_estimate) &&
    !is.logical(data$location_estimate) &&
    identical(names(data$location_estimate), c("routine", "occasional")) &&
    length(data$location_estimate) == 2L &&
    !anyNA(data$location_estimate) &&
    all(is.finite(data$location_estimate)) &&
    is.numeric(data$calibration_sd) &&
    !is.logical(data$calibration_sd) &&
    length(data$calibration_sd) == 1L &&
    !is.na(data$calibration_sd) &&
    is.finite(data$calibration_sd) &&
    data$calibration_sd > 0 &&
    is.list(data$stan_data) &&
    identical(data$stan_data, expected_stan) &&
    identical(data$model_id, prior$model_id) &&
    is.character(data$data_hash) &&
    length(data$data_hash) == 1L &&
    !is.na(data$data_hash) &&
    grepl("^[0-9a-f]{64}$", data$data_hash) &&
    identical(data$data_hash, expected_hash)
  if (!valid) {
    .goal005_stop("data must be canonical Goal005 class-calibration data.")
  }
  invisible(TRUE)
}

#' Prepare finite external class-location calibration for Goal005
prepare_goal005_class_calibration_data <- function(
  data,
  encounter_class,
  location_estimate,
  calibration_sd
) {
  validate_flexirich_g_data(data)
  valid_class <- is.character(encounter_class) &&
    !is.null(names(encounter_class)) &&
    length(encounter_class) == length(data$candidate_ids) &&
    !anyNA(encounter_class) &&
    !anyNA(names(encounter_class)) &&
    !anyDuplicated(names(encounter_class)) &&
    setequal(names(encounter_class), data$candidate_ids) &&
    all(encounter_class %in% c("routine", "occasional"))
  valid_location <- is.numeric(location_estimate) &&
    !is.logical(location_estimate) &&
    length(location_estimate) == 2L &&
    !anyNA(location_estimate) &&
    all(is.finite(location_estimate)) &&
    identical(names(location_estimate), c("routine", "occasional"))
  valid_sd <- is.numeric(calibration_sd) &&
    !is.logical(calibration_sd) &&
    length(calibration_sd) == 1L &&
    !is.na(calibration_sd) &&
    is.finite(calibration_sd) &&
    calibration_sd > 0
  if (!valid_class || !valid_location || !valid_sd) {
    .goal005_stop(paste0(
      "Class calibration requires candidate-aligned classes, finite named ",
      "routine/occasional locations, and a positive calibration SD."
    ))
  }
  prior <- goal005_class_calibration_prior()
  aligned_class <- unname(encounter_class[
    match(data$candidate_ids, names(encounter_class))
  ])
  location_estimate <- as.numeric(location_estimate)
  names(location_estimate) <- c("routine", "occasional")
  class_index <- as.integer(match(
    aligned_class,
    c("routine", "occasional")
  ))
  stan_data <- c(
    data$stan_data,
    list(
      omega_alpha = prior$omega_alpha,
      omega_beta = prior$omega_beta,
      class_index = class_index,
      location_estimate = as.numeric(location_estimate),
      calibration_sd = as.numeric(calibration_sd),
      log_rate_sd = prior$log_rate_sd,
      sigma_camera_scale = prior$sigma_camera_scale
    )
  )
  result <- list(
    candidate_ids = data$candidate_ids,
    camera_ids = data$camera_ids,
    encounter_class = aligned_class,
    class_index = class_index,
    detected_ever = data$stan_data$detected_ever,
    location_estimate = location_estimate,
    calibration_sd = as.numeric(calibration_sd),
    stan_data = stan_data,
    source_data = data,
    model_id = prior$model_id,
    data_hash = .goal005_class_calibration_hash(
      data$data_hash,
      data$candidate_ids,
      aligned_class,
      location_estimate,
      as.numeric(calibration_sd)
    )
  )
  .validate_goal005_class_calibration_data(result)
  result
}

#' Independent Goal005 class-calibration likelihood conditionals
goal005_class_calibration_conditionals <- function(
  data,
  expected_core_members,
  alpha,
  camera_effect
) {
  .validate_goal005_class_calibration_data(data)
  C <- length(data$candidate_ids)
  J <- length(data$camera_ids)
  valid <- is.numeric(expected_core_members) &&
    !is.logical(expected_core_members) &&
    length(expected_core_members) == 1L &&
    !is.na(expected_core_members) &&
    is.finite(expected_core_members) &&
    expected_core_members > 0 &&
    expected_core_members < C &&
    is.numeric(alpha) &&
    !is.logical(alpha) &&
    length(alpha) == C &&
    !anyNA(alpha) &&
    all(is.finite(alpha)) &&
    is.numeric(camera_effect) &&
    !is.logical(camera_effect) &&
    length(camera_effect) == J &&
    !anyNA(camera_effect) &&
    all(is.finite(camera_effect)) &&
    abs(sum(camera_effect)) <= 1e-10 * (1 + sum(abs(camera_effect)))
  if (!valid) {
    .goal005_stop(paste0(
      "Conditionals require a count in (0, C), one finite candidate rate, ",
      "and one sum-zero camera effect per camera."
    ))
  }
  omega <- expected_core_members / C
  member_ll <- member_log_likelihood(
    data$source_data,
    as.numeric(alpha),
    as.numeric(camera_effect)
  )
  q_member <- conditional_membership_probability(
    member_ll,
    data$detected_ever,
    omega
  )
  list(
    omega = omega,
    member_ll = member_ll,
    q_member = q_member,
    expected_richness = sum(q_member)
  )
}

#' Compile the Goal005 finite class-calibration model
compile_goal005_class_calibration_model <- function(force_recompile = FALSE) {
  .goal003_compile_model(
    stan_file = file.path("stan", "goal005_class_calibration.stan"),
    cache_id = "class-calibration",
    executable_stem = "goal005-class-calibration",
    output_namespace = "goal005",
    force_recompile = force_recompile
  )
}

.goal005_class_calibration_monitored_variables <- function(data) {
  .validate_goal005_class_calibration_data(data)
  c(
    "expected_core_members", "omega", "class_location", "sigma_camera",
    "expected_richness", "alpha", "camera_effect"
  )
}

#' Fit the Goal005 finite class-calibration model
fit_goal005_class_calibration <- function(
  data,
  seed,
  output_dir,
  rescue = TRUE,
  refresh = 100L
) {
  .validate_goal005_class_calibration_data(data)
  valid_seed <- is.numeric(seed) && !is.logical(seed) &&
    length(seed) == 1L && !is.na(seed) && is.finite(seed) &&
    seed == trunc(seed) && seed >= 1 && seed < .Machine$integer.max
  valid_refresh <- is.numeric(refresh) && !is.logical(refresh) &&
    length(refresh) == 1L && !is.na(refresh) && is.finite(refresh) &&
    refresh == trunc(refresh) && refresh >= 0 &&
    refresh <= .Machine$integer.max
  if (!valid_seed || !valid_refresh || !is.logical(rescue) ||
      length(rescue) != 1L || is.na(rescue)) {
    .goal005_stop("Goal005 class-calibration fit controls are invalid.")
  }
  absolute_output <- .goal003_prepare_output_directory(
    output_dir,
    output_namespace = "goal005"
  )
  model <- compile_goal005_class_calibration_model()
  profiles <- goal003_flexirich_sampler_profiles()
  thresholds <- goal003_flexirich_diagnostic_thresholds()
  monitored <- .goal005_class_calibration_monitored_variables(data)
  primary <- .goal003_model_attempt(
    model = model,
    stan_data = data$stan_data,
    sampler_profile = profiles$primary,
    diagnostic_thresholds = thresholds,
    monitored_variables = monitored,
    seed = as.integer(seed),
    output_dir = file.path(absolute_output, "primary"),
    attempt_id = "primary",
    refresh = as.integer(refresh)
  )
  attempts <- list(primary = primary)
  rescue_attempt <- NULL
  if (!isTRUE(primary$diagnostics$clean) && rescue) {
    rescue_attempt <- .goal003_model_attempt(
      model = model,
      stan_data = data$stan_data,
      sampler_profile = profiles$rescue,
      diagnostic_thresholds = thresholds,
      monitored_variables = monitored,
      seed = as.integer(seed) + 1L,
      output_dir = file.path(absolute_output, "rescue"),
      attempt_id = "rescue",
      refresh = as.integer(refresh)
    )
    attempts$rescue <- rescue_attempt
  }
  list(
    terminal_status = .goal003_terminal_status(primary, rescue_attempt),
    data = data,
    prior = goal005_class_calibration_prior(),
    output_dir = absolute_output,
    attempts = attempts
  )
}

.goal005_terminal_class_calibration_fit <- function(result) {
  valid <- is.list(result) &&
    identical(
      names(result),
      c("terminal_status", "data", "prior", "output_dir", "attempts")
    ) &&
    result$terminal_status %in% c("primary_clean", "rescue_clean")
  if (!valid) {
    .goal005_stop(
      "result must contain a terminal-clean Goal005 class-calibration fit."
    )
  }
  attempt <- if (identical(result$terminal_status, "primary_clean")) {
    "primary"
  } else {
    "rescue"
  }
  result$attempts[[attempt]]$fit
}

#' Predict richness from a clean Goal005 class-calibration fit
predict_goal005_class_calibration <- function(result) {
  fit <- .goal005_terminal_class_calibration_fit(result)
  data <- result$data
  .validate_goal005_class_calibration_data(data)
  C <- length(data$candidate_ids)
  J <- length(data$camera_ids)
  q_names <- sprintf("q_member[%d]", seq_len(C))
  alpha_names <- sprintf("alpha[%d]", seq_len(C))
  camera_names <- sprintf("camera_effect[%d]", seq_len(J))
  draws <- posterior::as_draws_matrix(fit$draws(
    variables = c("q_member", "alpha", "camera_effect")
  ))
  required <- c(q_names, alpha_names, camera_names)
  if (length(setdiff(required, colnames(draws))) > 0L) {
    .goal005_stop(
      "The class-calibration fit is missing posterior prediction variables."
    )
  }
  posterior <- summarise_goal003_flexirich_draws(
    q_member_draws = as.matrix(draws[, q_names, drop = FALSE]),
    alpha_draws = as.matrix(draws[, alpha_names, drop = FALSE]),
    camera_effect_draws = as.matrix(
      draws[, camera_names, drop = FALSE]
    ),
    candidate_ids = data$candidate_ids,
    camera_ids = data$camera_ids,
    detected_ever = data$detected_ever,
    future_active_days = NULL
  )
  list(
    posterior_richness_pmf = posterior$richness_pmf,
    posterior_richness_summary = .goal004_pmf_summary(
      posterior$richness_pmf,
      "richness"
    )
  )
}
