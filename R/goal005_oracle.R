.goal005_stop <- function(message) {
  stop(message, call. = FALSE)
}

goal005_candidate_oracle_prior <- function() {
  list(
    oracle_id = "candidate_rate_exact_v1",
    omega_alpha = 1,
    omega_beta = 1,
    sigma_camera_scale = 0.75
  )
}

.goal005_candidate_oracle_hash <- function(source_data_hash, alpha_fixed) {
  digest::digest(
    list(
      source_data_hash = source_data_hash,
      oracle_id = goal005_candidate_oracle_prior()$oracle_id,
      alpha_fixed = alpha_fixed
    ),
    algo = "sha256",
    serialize = TRUE
  )
}

.validate_goal005_candidate_oracle_data <- function(data) {
  required <- c(
    "candidate_ids", "camera_ids", "detected_ever", "alpha_fixed",
    "stan_data", "source_data", "oracle_id", "data_hash"
  )
  if (!is.list(data) || !identical(names(data), required)) {
    .goal005_stop("data must be canonical Goal005 candidate-oracle data.")
  }
  source_valid <- tryCatch({
    validate_flexirich_g_data(data$source_data)
    TRUE
  }, error = function(e) FALSE)
  prior <- goal005_candidate_oracle_prior()
  expected_stan <- if (source_valid) {
    c(
      data$source_data$stan_data,
      list(
        omega_alpha = prior$omega_alpha,
        omega_beta = prior$omega_beta,
        alpha_fixed = data$alpha_fixed,
        sigma_camera_scale = prior$sigma_camera_scale
      )
    )
  } else {
    NULL
  }
  expected_hash <- if (source_valid) {
    .goal005_candidate_oracle_hash(
      data$source_data$data_hash,
      data$alpha_fixed
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
    is.integer(data$detected_ever) &&
    identical(data$detected_ever, data$source_data$stan_data$detected_ever) &&
    is.numeric(data$alpha_fixed) &&
    !is.logical(data$alpha_fixed) &&
    length(data$alpha_fixed) == C &&
    !anyNA(data$alpha_fixed) &&
    all(is.finite(data$alpha_fixed)) &&
    is.list(data$stan_data) &&
    identical(data$stan_data, expected_stan) &&
    identical(data$oracle_id, prior$oracle_id) &&
    is.character(data$data_hash) &&
    length(data$data_hash) == 1L &&
    !is.na(data$data_hash) &&
    grepl("^[0-9a-f]{64}$", data$data_hash) &&
    identical(data$data_hash, expected_hash)
  if (!valid) {
    .goal005_stop("data must be canonical Goal005 candidate-oracle data.")
  }
  invisible(TRUE)
}

#' Prepare data for the Goal005 exact candidate-rate oracle
prepare_goal005_candidate_oracle_data <- function(data, candidate_log_rates) {
  validate_flexirich_g_data(data)
  valid_rates <- is.numeric(candidate_log_rates) &&
    !is.logical(candidate_log_rates) &&
    !is.null(names(candidate_log_rates)) &&
    length(candidate_log_rates) == length(data$candidate_ids) &&
    !anyNA(candidate_log_rates) &&
    all(is.finite(candidate_log_rates)) &&
    !anyNA(names(candidate_log_rates)) &&
    !anyDuplicated(names(candidate_log_rates)) &&
    setequal(names(candidate_log_rates), data$candidate_ids)
  if (!valid_rates) {
    .goal005_stop(paste0(
      "candidate_log_rates must be a finite named vector whose names ",
      "exactly match the candidate IDs."
    ))
  }
  prior <- goal005_candidate_oracle_prior()
  alpha_fixed <- as.numeric(candidate_log_rates[
    match(data$candidate_ids, names(candidate_log_rates))
  ])
  stan_data <- c(
    data$stan_data,
    list(
      omega_alpha = prior$omega_alpha,
      omega_beta = prior$omega_beta,
      alpha_fixed = alpha_fixed,
      sigma_camera_scale = prior$sigma_camera_scale
    )
  )
  result <- list(
    candidate_ids = data$candidate_ids,
    camera_ids = data$camera_ids,
    detected_ever = data$stan_data$detected_ever,
    alpha_fixed = alpha_fixed,
    stan_data = stan_data,
    source_data = data,
    oracle_id = prior$oracle_id,
    data_hash = .goal005_candidate_oracle_hash(
      data$data_hash,
      alpha_fixed
    )
  )
  .validate_goal005_candidate_oracle_data(result)
  result
}

#' Independent R conditionals for the exact candidate-rate oracle
goal005_candidate_oracle_conditionals <- function(
  data,
  expected_core_members,
  camera_effect
) {
  .validate_goal005_candidate_oracle_data(data)
  C <- length(data$candidate_ids)
  J <- length(data$camera_ids)
  valid <- is.numeric(expected_core_members) &&
    !is.logical(expected_core_members) &&
    length(expected_core_members) == 1L &&
    !is.na(expected_core_members) &&
    is.finite(expected_core_members) &&
    expected_core_members > 0 &&
    expected_core_members < C &&
    is.numeric(camera_effect) &&
    !is.logical(camera_effect) &&
    length(camera_effect) == J &&
    !anyNA(camera_effect) &&
    all(is.finite(camera_effect)) &&
    abs(sum(camera_effect)) <=
      1e-10 * (1 + sum(abs(camera_effect)))
  if (!valid) {
    .goal005_stop(paste0(
      "expected_core_members must be in (0, C), with one finite ",
      "sum-zero camera effect per camera."
    ))
  }
  omega <- expected_core_members / C
  member_ll <- member_log_likelihood(
    data$source_data,
    data$alpha_fixed,
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

#' Compile the Goal005 exact candidate-rate oracle
compile_goal005_candidate_oracle_model <- function(force_recompile = FALSE) {
  .goal003_compile_model(
    stan_file = file.path("stan", "goal005_candidate_oracle.stan"),
    cache_id = "candidate-oracle",
    executable_stem = "goal005-candidate-oracle",
    output_namespace = "goal005",
    force_recompile = force_recompile
  )
}

.goal005_candidate_oracle_monitored_variables <- function(data) {
  .validate_goal005_candidate_oracle_data(data)
  c(
    "expected_core_members", "omega", "sigma_camera",
    "expected_richness", "camera_effect"
  )
}

#' Fit the Goal005 exact candidate-rate oracle
fit_goal005_candidate_oracle <- function(
  data,
  seed,
  output_dir,
  rescue = TRUE,
  refresh = 100L
) {
  .validate_goal005_candidate_oracle_data(data)
  valid_seed <- is.numeric(seed) &&
    !is.logical(seed) &&
    length(seed) == 1L &&
    !is.na(seed) &&
    is.finite(seed) &&
    seed == trunc(seed) &&
    seed >= 1 &&
    seed < .Machine$integer.max
  valid_refresh <- is.numeric(refresh) &&
    !is.logical(refresh) &&
    length(refresh) == 1L &&
    !is.na(refresh) &&
    is.finite(refresh) &&
    refresh == trunc(refresh) &&
    refresh >= 0 &&
    refresh <= .Machine$integer.max
  if (!valid_seed || !valid_refresh ||
      !is.logical(rescue) || length(rescue) != 1L || is.na(rescue)) {
    .goal005_stop("Goal005 candidate-oracle fit controls are invalid.")
  }
  absolute_output <- .goal003_prepare_output_directory(
    output_dir,
    output_namespace = "goal005"
  )
  model <- compile_goal005_candidate_oracle_model()
  profiles <- goal003_flexirich_sampler_profiles()
  thresholds <- goal003_flexirich_diagnostic_thresholds()
  monitored <- .goal005_candidate_oracle_monitored_variables(data)
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
    prior = goal005_candidate_oracle_prior(),
    output_dir = absolute_output,
    attempts = attempts
  )
}

.goal005_terminal_candidate_oracle_fit <- function(result) {
  valid <- is.list(result) &&
    identical(
      names(result),
      c("terminal_status", "data", "prior", "output_dir", "attempts")
    ) &&
    result$terminal_status %in% c("primary_clean", "rescue_clean")
  if (!valid) {
    .goal005_stop(
      "result must contain a terminal-clean Goal005 candidate-oracle fit."
    )
  }
  attempt <- if (identical(result$terminal_status, "primary_clean")) {
    "primary"
  } else {
    "rescue"
  }
  result$attempts[[attempt]]$fit
}

#' Summarise candidate-oracle posterior draws
summarise_goal005_candidate_oracle_draws <- function(
  q_member_draws,
  camera_effect_draws,
  data,
  future_active_days = NULL
) {
  .validate_goal005_candidate_oracle_data(data)
  D <- if (is.matrix(q_member_draws)) nrow(q_member_draws) else 0L
  alpha_draws <- matrix(
    rep(data$alpha_fixed, each = D),
    nrow = D,
    ncol = length(data$alpha_fixed)
  )
  posterior <- summarise_goal003_flexirich_draws(
    q_member_draws = q_member_draws,
    alpha_draws = alpha_draws,
    camera_effect_draws = camera_effect_draws,
    candidate_ids = data$candidate_ids,
    camera_ids = data$camera_ids,
    detected_ever = data$detected_ever,
    future_active_days = future_active_days
  )
  prior <- goal005_candidate_oracle_prior()
  prior_richness <- goal004_beta_binomial_pmf(
    candidate_count = length(data$candidate_ids),
    alpha = prior$omega_alpha,
    beta = prior$omega_beta
  )
  candidate_membership <- tibble::tibble(
    candidate_id = data$candidate_ids,
    alpha_fixed = data$alpha_fixed,
    training_detected = data$detected_ever == 1L,
    prior_membership_probability = prior$omega_alpha /
      (prior$omega_alpha + prior$omega_beta),
    posterior_membership_probability =
      posterior$grid_identity$membership_probability
  ) |>
    dplyr::mutate(
      membership_probability_movement =
        posterior_membership_probability - prior_membership_probability
    )
  future_pmf <- if (is.null(posterior$new_species_count_pmf)) {
    NULL
  } else {
    posterior$new_species_count_pmf |>
      dplyr::rename(future_discoveries = new_species_count)
  }
  future_identity <- if (is.null(posterior$future_identity)) {
    NULL
  } else {
    candidate_membership |>
      dplyr::select(candidate_id, training_detected) |>
      dplyr::mutate(
        future_first_detection_probability =
          posterior$future_identity$future_first_detection_probability
      )
  }
  list(
    posterior_richness_pmf = posterior$richness_pmf,
    posterior_richness_summary = .goal004_pmf_summary(
      posterior$richness_pmf,
      "richness"
    ),
    prior_richness_pmf = prior_richness,
    prior_richness_summary = .goal004_pmf_summary(
      prior_richness,
      "richness"
    ),
    candidate_membership = candidate_membership,
    future_discovery_pmf = future_pmf,
    future_identity = future_identity
  )
}

#' Predict richness from a clean candidate-oracle fit
predict_goal005_candidate_oracle <- function(result, future_effort = NULL) {
  fit <- .goal005_terminal_candidate_oracle_fit(result)
  data <- result$data
  .validate_goal005_candidate_oracle_data(data)
  C <- length(data$candidate_ids)
  J <- length(data$camera_ids)
  q_names <- sprintf("q_member[%d]", seq_len(C))
  camera_names <- sprintf("camera_effect[%d]", seq_len(J))
  draws <- posterior::as_draws_matrix(fit$draws(
    variables = c("q_member", "camera_effect")
  ))
  required <- c(q_names, camera_names)
  if (length(setdiff(required, colnames(draws))) > 0L) {
    .goal005_stop(
      "The candidate-oracle fit is missing posterior prediction variables."
    )
  }
  future_active_days <- if (is.null(future_effort)) {
    NULL
  } else {
    .goal003_future_active_days(future_effort, data$camera_ids)
  }
  summarise_goal005_candidate_oracle_draws(
    q_member_draws = as.matrix(draws[, q_names, drop = FALSE]),
    camera_effect_draws = as.matrix(
      draws[, camera_names, drop = FALSE]
    ),
    data = data,
    future_active_days = future_active_days
  )
}
