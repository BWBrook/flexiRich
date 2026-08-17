.goal004_nested_stop <- function(message) {
  stop(message, call. = FALSE)
}

.goal004_nested_expand_source <- function(source_data, fringe_ids) {
  validate_flexirich_g_data(source_data)
  first <- source_data$candidate_ids[[1L]]
  effort <- source_data$observed |>
    dplyr::filter(species_id == .env$first) |>
    dplyr::select(camera_id, occasion_id, active_days)
  fringe_detection <- tidyr::crossing(
    species_id = fringe_ids,
    effort
  ) |>
    dplyr::mutate(
      detected = dplyr::if_else(active_days > 0L, 0L, NA_integer_)
    ) |>
    dplyr::select(species_id, camera_id, occasion_id, detected)
  detection <- dplyr::bind_rows(
    source_data$observed |>
      dplyr::select(species_id, camera_id, occasion_id, detected),
    fringe_detection
  )
  prepare_flexirich_g_data(
    tibble::tibble(species_id = c(source_data$candidate_ids, fringe_ids)),
    effort,
    detection
  )
}

.goal004_nested_stan_extras <- function(expanded, mapping) {
  core_index <- match(mapping$core$candidate_id, expanded$candidate_ids)
  fringe_index <- match(mapping$fringe$candidate_id, expanded$candidate_ids)
  class <- c(
    stats::setNames(
      mapping$core$encounter_class,
      mapping$core$candidate_id
    ),
    stats::setNames(
      mapping$fringe$encounter_class,
      mapping$fringe$candidate_id
    )
  )[expanded$candidate_ids]
  location <- dplyr::case_when(
    class == "routine" ~ log(0.002),
    class == "occasional" ~ log(0.0005),
    class == "rare" ~ log(0.0002),
    .default = NA_real_
  )
  list(
    C_core = as.integer(nrow(mapping$core)),
    C_fringe = as.integer(nrow(mapping$fringe)),
    core_index = as.integer(core_index),
    fringe_index = as.integer(fringe_index),
    core_omega_alpha = 1,
    core_omega_beta = 1,
    fringe_expected_count_scale = 5,
    alpha_location = unname(location),
    log_rate_sd = 1,
    sigma_camera_scale = 0.75
  )
}

.goal004_nested_hash <- function(source_hash, mapping, stan_extras) {
  digest::digest(
    list(
      source_data_hash = source_hash,
      core = mapping$core,
      fringe = mapping$fringe,
      prior = stan_extras[setdiff(
        names(stan_extras),
        c("core_index", "fringe_index")
      )]
    ),
    algo = "sha256",
    serialize = TRUE
  )
}

.validate_goal004_nested_data <- function(data) {
  required <- c(
    "candidate_ids", "core_ids", "fringe_ids", "camera_ids",
    "core_index", "fringe_index", "encounter_class", "detected_ever",
    "stan_data", "source_data", "expanded_data", "data_hash"
  )
  if (!is.list(data) || !identical(names(data), required)) {
    .goal004_nested_stop("data must be canonical Goal004 nested data.")
  }
  mapping <- tryCatch(
    goal004_task2_candidate_mapping(),
    error = function(e) NULL
  )
  source_valid <- tryCatch({
    validate_flexirich_g_data(data$source_data)
    TRUE
  }, error = function(e) FALSE)
  expanded_valid <- tryCatch({
    validate_flexirich_g_data(data$expanded_data)
    TRUE
  }, error = function(e) FALSE)
  expected_extras <- if (!is.null(mapping) && expanded_valid) {
    .goal004_nested_stan_extras(data$expanded_data, mapping)
  } else {
    NULL
  }
  expected_hash <- if (!is.null(expected_extras) && source_valid) {
    .goal004_nested_hash(data$source_data$data_hash, mapping, expected_extras)
  } else {
    NA_character_
  }
  valid <- !is.null(mapping) && source_valid && expanded_valid &&
    identical(data$core_ids, mapping$core$candidate_id) &&
    identical(data$fringe_ids, mapping$fringe$candidate_id) &&
    identical(data$candidate_ids, data$expanded_data$candidate_ids) &&
    identical(data$camera_ids, data$expanded_data$camera_ids) &&
    identical(data$core_index, expected_extras$core_index) &&
    identical(data$fringe_index, expected_extras$fringe_index) &&
    identical(
      data$encounter_class,
      c(
        stats::setNames(
          mapping$core$encounter_class,
          mapping$core$candidate_id
        ),
        stats::setNames(
          mapping$fringe$encounter_class,
          mapping$fringe$candidate_id
        )
      )[data$candidate_ids] |>
        unname()
    ) &&
    identical(data$detected_ever, data$expanded_data$stan_data$detected_ever) &&
    identical(data$stan_data, c(data$expanded_data$stan_data, expected_extras)) &&
    length(intersect(data$core_ids, data$fringe_ids)) == 0L &&
    length(c(data$core_index, data$fringe_index)) ==
      length(data$candidate_ids) &&
    setequal(c(data$core_index, data$fringe_index), seq_along(data$candidate_ids)) &&
    is.character(data$data_hash) &&
    length(data$data_hash) == 1L &&
    grepl("^[0-9a-f]{64}$", data$data_hash) &&
    identical(data$data_hash, expected_hash)
  if (!valid) {
    .goal004_nested_stop("data must be canonical Goal004 nested data.")
  }
  invisible(TRUE)
}

#' Prepare the Goal004 independent core-fringe diagnostic
prepare_goal004_nested_data <- function(source_data) {
  validate_flexirich_g_data(source_data)
  mapping <- goal004_task2_candidate_mapping()
  if (!identical(source_data$candidate_ids, mapping$core$candidate_id)) {
    .goal004_nested_stop(
      "Nested data require the frozen 50-candidate core in canonical order."
    )
  }
  expanded <- .goal004_nested_expand_source(
    source_data,
    mapping$fringe$candidate_id
  )
  extras <- .goal004_nested_stan_extras(expanded, mapping)
  class <- c(
    stats::setNames(
      mapping$core$encounter_class,
      mapping$core$candidate_id
    ),
    stats::setNames(
      mapping$fringe$encounter_class,
      mapping$fringe$candidate_id
    )
  )[expanded$candidate_ids]
  result <- list(
    candidate_ids = expanded$candidate_ids,
    core_ids = mapping$core$candidate_id,
    fringe_ids = mapping$fringe$candidate_id,
    camera_ids = expanded$camera_ids,
    core_index = extras$core_index,
    fringe_index = extras$fringe_index,
    encounter_class = unname(class),
    detected_ever = expanded$stan_data$detected_ever,
    stan_data = c(expanded$stan_data, extras),
    source_data = source_data,
    expanded_data = expanded,
    data_hash = .goal004_nested_hash(
      source_data$data_hash,
      mapping,
      extras
    )
  )
  .validate_goal004_nested_data(result)
  result
}

#' Independent R conditionals for the Goal004 nested model
goal004_nested_conditionals <- function(
  data,
  expected_core_members,
  expected_fringe_members,
  alpha,
  camera_effect
) {
  .validate_goal004_nested_data(data)
  C_core <- length(data$core_ids)
  C_fringe <- length(data$fringe_ids)
  J <- length(data$camera_ids)
  valid_count <- function(value, upper) {
    is.numeric(value) && !is.logical(value) && length(value) == 1L &&
      !is.na(value) && is.finite(value) && value > 0 && value < upper
  }
  valid <- valid_count(expected_core_members, C_core) &&
    valid_count(expected_fringe_members, C_fringe) &&
    is.numeric(alpha) && !is.logical(alpha) &&
    length(alpha) == length(data$candidate_ids) &&
    !anyNA(alpha) && all(is.finite(alpha)) &&
    is.numeric(camera_effect) && !is.logical(camera_effect) &&
    length(camera_effect) == J && !anyNA(camera_effect) &&
    all(is.finite(camera_effect)) &&
    abs(sum(camera_effect)) <= 1e-10 * (1 + sum(abs(camera_effect)))
  if (!valid) {
    .goal004_nested_stop("Nested conditional inputs are invalid.")
  }
  member_ll <- member_log_likelihood(
    data$expanded_data,
    alpha,
    camera_effect
  )
  omega_core <- expected_core_members / C_core
  omega_fringe <- expected_fringe_members / C_fringe
  q_core <- conditional_membership_probability(
    member_ll[data$core_index],
    data$detected_ever[data$core_index],
    omega_core
  )
  q_fringe <- conditional_membership_probability(
    member_ll[data$fringe_index],
    data$detected_ever[data$fringe_index],
    omega_fringe
  )
  list(
    omega_core = omega_core,
    omega_fringe = omega_fringe,
    member_ll = member_ll,
    q_core = q_core,
    q_fringe = q_fringe,
    expected_core_richness = sum(q_core),
    expected_fringe_richness = sum(q_fringe),
    expected_total_richness = sum(q_core) + sum(q_fringe)
  )
}

#' Numerically exact prior PMF for realised fringe richness
goal004_nested_fringe_prior_pmf <- function(
  candidate_count = 56L,
  scale = 5
) {
  valid <- length(candidate_count) == 1L &&
    is.numeric(candidate_count) && is.finite(candidate_count) &&
    candidate_count == trunc(candidate_count) && candidate_count >= 1L &&
    length(scale) == 1L && is.numeric(scale) &&
    is.finite(scale) && scale > 0
  if (!valid) {
    .goal004_nested_stop("Fringe prior-PMF inputs are invalid.")
  }
  candidate_count <- as.integer(candidate_count)
  normalizer <- 1 - exp(-candidate_count / scale)
  probability <- vapply(0:candidate_count, function(k) {
    stats::integrate(
      function(expected_count) {
        stats::dbinom(
          k,
          size = candidate_count,
          prob = expected_count / candidate_count
        ) * stats::dexp(expected_count, rate = 1 / scale) / normalizer
      },
      lower = 0,
      upper = candidate_count,
      rel.tol = 1e-10,
      stop.on.error = TRUE
    )$value
  }, numeric(1))
  probability <- probability / sum(probability)
  tibble::tibble(
    richness = 0:candidate_count,
    probability = probability
  )
}

#' Compile the Goal004 independent core-fringe diagnostic
compile_goal004_nested_model <- function(force_recompile = FALSE) {
  .goal003_compile_model(
    stan_file = file.path("stan", "goal004_nested_flexirich.stan"),
    cache_id = "nested-flexirich",
    executable_stem = "goal004-nested-flexirich",
    output_namespace = "goal004",
    force_recompile = force_recompile
  )
}

.goal004_nested_monitored_variables <- function(data) {
  .validate_goal004_nested_data(data)
  c(
    "expected_core_members", "expected_fringe_members",
    "omega_core", "omega_fringe", "sigma_camera",
    "expected_core_richness", "expected_fringe_richness",
    "expected_total_richness", "alpha", "camera_effect"
  )
}

#' Fit the Goal004 independent core-fringe diagnostic
fit_goal004_nested <- function(
  data,
  seed,
  output_dir,
  rescue = TRUE,
  refresh = 100L
) {
  .validate_goal004_nested_data(data)
  valid_seed <- is.numeric(seed) && !is.logical(seed) &&
    length(seed) == 1L && !is.na(seed) && is.finite(seed) &&
    seed == trunc(seed) && seed >= 1 && seed < .Machine$integer.max
  valid_refresh <- is.numeric(refresh) && !is.logical(refresh) &&
    length(refresh) == 1L && !is.na(refresh) && is.finite(refresh) &&
    refresh == trunc(refresh) && refresh >= 0 &&
    refresh <= .Machine$integer.max
  if (!valid_seed || !valid_refresh || !is.logical(rescue) ||
      length(rescue) != 1L || is.na(rescue)) {
    .goal004_nested_stop("Nested fit controls are invalid.")
  }
  absolute_output <- .goal003_prepare_output_directory(
    output_dir,
    output_namespace = "goal004"
  )
  model <- compile_goal004_nested_model()
  profiles <- goal003_flexirich_sampler_profiles()
  thresholds <- goal003_flexirich_diagnostic_thresholds()
  monitored <- .goal004_nested_monitored_variables(data)
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
    output_dir = absolute_output,
    attempts = attempts
  )
}

.goal004_terminal_nested_fit <- function(result) {
  valid <- is.list(result) &&
    identical(
      names(result),
      c("terminal_status", "data", "output_dir", "attempts")
    ) &&
    result$terminal_status %in% c("primary_clean", "rescue_clean")
  if (!valid) {
    .goal004_nested_stop(
      "result must contain a terminal-clean Goal004 nested fit."
    )
  }
  attempt <- if (identical(result$terminal_status, "primary_clean")) {
    "primary"
  } else {
    "rescue"
  }
  result$attempts[[attempt]]$fit
}

#' Summarise Goal004 nested membership draws
summarise_goal004_nested_draws <- function(q_core_draws, q_fringe_draws, data) {
  .validate_goal004_nested_data(data)
  D <- if (is.matrix(q_core_draws)) nrow(q_core_draws) else 0L
  valid <- D > 0L && is.numeric(q_core_draws) &&
    identical(dim(q_core_draws), c(D, length(data$core_ids))) &&
    is.matrix(q_fringe_draws) && is.numeric(q_fringe_draws) &&
    identical(dim(q_fringe_draws), c(D, length(data$fringe_ids))) &&
    !anyNA(q_core_draws) && !anyNA(q_fringe_draws) &&
    all(is.finite(q_core_draws)) && all(is.finite(q_fringe_draws)) &&
    all(q_core_draws >= 0 & q_core_draws <= 1) &&
    all(q_fringe_draws >= 0 & q_fringe_draws <= 1)
  if (!valid) {
    .goal004_nested_stop("Nested membership draws are invalid.")
  }
  core_pmf <- .goal003_mean_poisson_binomial(q_core_draws)
  fringe_pmf <- .goal003_mean_poisson_binomial(q_fringe_draws)
  total_pmf <- .goal003_mean_poisson_binomial(cbind(
    q_core_draws,
    q_fringe_draws
  ))
  list(
    core_richness_pmf = core_pmf,
    core_richness_summary = .goal004_pmf_summary(core_pmf, "richness"),
    fringe_richness_pmf = fringe_pmf,
    fringe_richness_summary = .goal004_pmf_summary(fringe_pmf, "richness"),
    total_richness_pmf = total_pmf,
    total_richness_summary = .goal004_pmf_summary(total_pmf, "richness"),
    core_membership = tibble::tibble(
      species_id = data$core_ids,
      training_detected = data$detected_ever[data$core_index] == 1L,
      membership_probability = colMeans(q_core_draws)
    ),
    fringe_membership = tibble::tibble(
      species_id = data$fringe_ids,
      training_detected = data$detected_ever[data$fringe_index] == 1L,
      membership_probability = colMeans(q_fringe_draws)
    )
  )
}

#' Predict core, fringe, and total richness from a clean nested fit
predict_goal004_nested <- function(result) {
  fit <- .goal004_terminal_nested_fit(result)
  data <- result$data
  .validate_goal004_nested_data(data)
  core_names <- sprintf("q_core[%d]", seq_along(data$core_ids))
  fringe_names <- sprintf("q_fringe[%d]", seq_along(data$fringe_ids))
  draws <- posterior::as_draws_matrix(fit$draws(
    variables = c("q_core", "q_fringe")
  ))
  if (length(setdiff(c(core_names, fringe_names), colnames(draws))) > 0L) {
    .goal004_nested_stop("The nested fit is missing prediction variables.")
  }
  summarise_goal004_nested_draws(
    as.matrix(draws[, core_names, drop = FALSE]),
    as.matrix(draws[, fringe_names, drop = FALSE]),
    data
  )
}
