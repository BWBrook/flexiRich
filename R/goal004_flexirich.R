.goal004_flexirich_stop <- function(message) {
  stop(message, call. = FALSE)
}

#' Return one frozen Goal004 fixed-class prior profile
goal004_flexirich_profile <- function(profile_id = "primary") {
  profiles <- read_goal004_task2_profiles()
  if (!is.character(profile_id) ||
      length(profile_id) != 1L ||
      is.na(profile_id) ||
      !profile_id %in% profiles$profile_id) {
    .goal004_flexirich_stop(
      "profile_id must name one frozen Goal004 Task 2 profile."
    )
  }
  as.list(profiles[match(profile_id, profiles$profile_id), , drop = FALSE])
}

.goal004_routine_weight <- function(encounter_class, blur_probability) {
  valid <- is.character(encounter_class) &&
    length(encounter_class) > 0L &&
    !anyNA(encounter_class) &&
    all(encounter_class %in% c("routine", "occasional")) &&
    is.numeric(blur_probability) &&
    !is.logical(blur_probability) &&
    length(blur_probability) == 1L &&
    !is.na(blur_probability) &&
    is.finite(blur_probability) &&
    blur_probability >= 0 &&
    blur_probability <= 0.5
  if (!valid) {
    .goal004_flexirich_stop(
      "Encounter classes or the class-blur probability are invalid."
    )
  }
  as.numeric(ifelse(
    encounter_class == "routine",
    1 - blur_probability,
    blur_probability
  ))
}

.goal004_profile_stan_data <- function(profile, encounter_class) {
  list(
    omega_alpha = as.numeric(profile$omega_alpha),
    omega_beta = as.numeric(profile$omega_beta),
    routine_location = log(as.numeric(profile$routine_median_rate)),
    occasional_location = log(as.numeric(profile$occasional_median_rate)),
    log_rate_sd = as.numeric(profile$log_rate_sd),
    routine_weight = .goal004_routine_weight(
      encounter_class,
      as.numeric(profile$class_blur_probability)
    ),
    sigma_camera_scale = as.numeric(profile$camera_sd_scale)
  )
}

.goal004_flexirich_hash <- function(
  source_data_hash,
  candidate_ids,
  encounter_class,
  profile
) {
  digest::digest(
    list(
      source_data_hash = source_data_hash,
      candidate_ids = candidate_ids,
      encounter_class = encounter_class,
      profile = profile
    ),
    algo = "sha256",
    serialize = TRUE
  )
}

.validate_goal004_flexirich_data <- function(data) {
  required <- c(
    "candidate_ids", "camera_ids", "encounter_class", "routine_weight",
    "detected_ever", "stan_data", "source_data", "profile_id", "data_hash"
  )
  if (!is.list(data) || !identical(names(data), required)) {
    .goal004_flexirich_stop("data must be canonical Goal004 FlexiRich data.")
  }
  source_valid <- tryCatch({
    validate_flexirich_g_data(data$source_data)
    TRUE
  }, error = function(e) FALSE)
  profile <- tryCatch(
    goal004_flexirich_profile(data$profile_id),
    error = function(e) NULL
  )
  C <- length(data$candidate_ids)
  J <- length(data$camera_ids)
  expected_weights <- if (is.null(profile)) {
    NULL
  } else {
    .goal004_routine_weight(
      data$encounter_class,
      as.numeric(profile$class_blur_probability)
    )
  }
  expected_stan <- if (is.null(profile) || !source_valid) {
    NULL
  } else {
    c(
      data$source_data$stan_data,
      .goal004_profile_stan_data(profile, data$encounter_class)
    )
  }
  expected_hash <- if (is.null(profile) || !source_valid) {
    NA_character_
  } else {
    .goal004_flexirich_hash(
      data$source_data$data_hash,
      data$candidate_ids,
      data$encounter_class,
      profile
    )
  }
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
    is.numeric(data$routine_weight) &&
    !is.logical(data$routine_weight) &&
    identical(data$routine_weight, expected_weights) &&
    is.integer(data$detected_ever) &&
    identical(data$detected_ever, data$source_data$stan_data$detected_ever) &&
    is.list(data$stan_data) &&
    identical(data$stan_data, expected_stan) &&
    !is.null(profile) &&
    is.character(data$data_hash) &&
    length(data$data_hash) == 1L &&
    !is.na(data$data_hash) &&
    grepl("^[0-9a-f]{64}$", data$data_hash) &&
    identical(data$data_hash, expected_hash)
  if (!valid) {
    .goal004_flexirich_stop("data must be canonical Goal004 FlexiRich data.")
  }
  invisible(TRUE)
}

#' Prepare the Goal004 fixed-class core model data
prepare_goal004_flexirich_data <- function(
  data,
  encounter_class,
  profile_id = "primary"
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
  if (!valid_class) {
    .goal004_flexirich_stop(paste0(
      "encounter_class must be a named routine/occasional vector whose ",
      "names exactly match the candidate IDs."
    ))
  }
  profile <- goal004_flexirich_profile(profile_id)
  aligned_class <- unname(encounter_class[
    match(data$candidate_ids, names(encounter_class))
  ])
  profile_stan <- .goal004_profile_stan_data(profile, aligned_class)
  result <- list(
    candidate_ids = data$candidate_ids,
    camera_ids = data$camera_ids,
    encounter_class = aligned_class,
    routine_weight = profile_stan$routine_weight,
    detected_ever = data$stan_data$detected_ever,
    stan_data = c(data$stan_data, profile_stan),
    source_data = data,
    profile_id = profile_id,
    data_hash = .goal004_flexirich_hash(
      data$data_hash,
      data$candidate_ids,
      aligned_class,
      profile
    )
  )
  .validate_goal004_flexirich_data(result)
  result
}

#' Independent R conditionals for the Goal004 fixed-class model
goal004_flexirich_conditionals <- function(
  data,
  expected_core_members,
  alpha,
  camera_effect
) {
  .validate_goal004_flexirich_data(data)
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
    abs(sum(camera_effect)) <=
      1e-10 * (1 + sum(abs(camera_effect)))
  if (!valid) {
    .goal004_flexirich_stop(paste0(
      "expected_core_members must be in (0, C), with one finite alpha ",
      "per candidate and one sum-zero camera effect per camera."
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

#' Compile the Goal004 fixed-class model
compile_goal004_flexirich_model <- function(force_recompile = FALSE) {
  .goal003_compile_model(
    stan_file = file.path("stan", "goal004_flexirich.stan"),
    cache_id = "flexirich",
    executable_stem = "goal004-flexirich",
    output_namespace = "goal004",
    force_recompile = force_recompile
  )
}

.goal004_flexirich_monitored_variables <- function(data) {
  .validate_goal004_flexirich_data(data)
  c(
    "expected_core_members", "omega", "sigma_camera",
    "expected_richness", "alpha", "camera_effect"
  )
}

#' Fit the Goal004 fixed-class model
fit_goal004_flexirich <- function(
  data,
  seed,
  output_dir,
  rescue = TRUE,
  refresh = 100L
) {
  .validate_goal004_flexirich_data(data)
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
  if (!valid_seed ||
      !valid_refresh ||
      !is.logical(rescue) ||
      length(rescue) != 1L ||
      is.na(rescue)) {
    .goal004_flexirich_stop("Fit controls are invalid.")
  }
  absolute_output <- .goal003_prepare_output_directory(
    output_dir,
    output_namespace = "goal004"
  )
  model <- compile_goal004_flexirich_model()
  profiles <- goal003_flexirich_sampler_profiles()
  thresholds <- goal003_flexirich_diagnostic_thresholds()
  monitored <- .goal004_flexirich_monitored_variables(data)
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
    profile = goal004_flexirich_profile(data$profile_id),
    output_dir = absolute_output,
    attempts = attempts
  )
}

.goal004_terminal_flexirich_fit <- function(result) {
  valid <- is.list(result) &&
    identical(
      names(result),
      c("terminal_status", "data", "profile", "output_dir", "attempts")
    ) &&
    result$terminal_status %in% c("primary_clean", "rescue_clean")
  if (!valid) {
    .goal004_flexirich_stop(
      "result must contain a terminal-clean Goal004 FlexiRich fit."
    )
  }
  attempt <- if (identical(result$terminal_status, "primary_clean")) {
    "primary"
  } else {
    "rescue"
  }
  result$attempts[[attempt]]$fit
}
