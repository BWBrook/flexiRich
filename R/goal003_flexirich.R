.goal003_flexirich_stop <- function(message) {
  stop(message, call. = FALSE)
}

#' Frozen Goal003 FlexiRich prior profiles
goal003_flexirich_prior_profiles <- function() {
  primary <- list(
    profile_id = "goal003-flexirich-primary-v1",
    omega_alpha = 1,
    omega_beta = 1,
    mu_alpha_location = log(0.02),
    mu_alpha_scale = 1.5,
    sigma_alpha_scale = 1,
    sigma_camera_scale = 0.75
  )
  membership_regularised <- primary
  membership_regularised$profile_id <-
    "goal003-flexirich-membership-regularised-v1"
  membership_regularised$omega_alpha <- 2
  membership_regularised$omega_beta <- 2
  mu_alpha_wide <- primary
  mu_alpha_wide$profile_id <- "goal003-flexirich-mu-alpha-wide-v1"
  mu_alpha_wide$mu_alpha_scale <- 2
  tail_wide <- primary
  tail_wide$profile_id <- "goal003-flexirich-tail-wide-v1"
  tail_wide$sigma_alpha_scale <- 1.5
  list(
    primary = primary,
    membership_regularised = membership_regularised,
    mu_alpha_wide = mu_alpha_wide,
    tail_wide = tail_wide
  )
}

#' Frozen Goal003 FlexiRich sampler profiles
goal003_flexirich_sampler_profiles <- function() {
  list(
    primary = list(
      profile_id = "goal003-flexirich-primary-sampler-v1",
      chains = 4L,
      parallel_chains = 4L,
      iter_warmup = 1000L,
      iter_sampling = 1000L,
      adapt_delta = 0.90,
      max_treedepth = 12L
    ),
    rescue = list(
      profile_id = "goal003-flexirich-rescue-sampler-v1",
      chains = 4L,
      parallel_chains = 4L,
      iter_warmup = 1500L,
      iter_sampling = 1500L,
      adapt_delta = 0.999,
      max_treedepth = 15L
    )
  )
}

goal003_flexirich_diagnostic_thresholds <- function() {
  list(
    max_divergences = 0L,
    max_treedepth_hits = 0L,
    min_ebfmi = 0.3,
    max_rhat = 1.01,
    min_bulk_ess = 400,
    min_tail_ess = 400
  )
}

.validate_goal003_flexirich_data <- function(data) {
  required <- c(
    "candidate_ids", "camera_ids", "detected_ever", "stan_data",
    "source_data", "prior_id", "data_hash"
  )
  if (!is.list(data) || !identical(names(data), required)) {
    .goal003_flexirich_stop("data must be canonical Goal003 FlexiRich data.")
  }
  C <- length(data$candidate_ids)
  J <- length(data$camera_ids)
  stan <- data$stan_data
  prior <- goal003_flexirich_prior_profiles()[[data$prior_id]]
  expected_stan <- if (is.null(prior) || !is.list(data$source_data)) {
    NULL
  } else {
    c(
      data$source_data$stan_data,
      prior[setdiff(names(prior), "profile_id")]
    )
  }
  expected_hash <- if (is.null(prior) || !is.list(data$source_data)) {
    NA_character_
  } else {
    digest::digest(
      list(
        source_data_hash = data$source_data$data_hash,
        prior_profile_id = prior$profile_id
      ),
      algo = "sha256",
      serialize = TRUE
    )
  }
  valid <- is.character(data$candidate_ids) &&
    C > 0L &&
    !anyNA(data$candidate_ids) &&
    !anyDuplicated(data$candidate_ids) &&
    is.character(data$camera_ids) &&
    J > 0L &&
    !anyNA(data$camera_ids) &&
    !anyDuplicated(data$camera_ids) &&
    is.integer(data$detected_ever) &&
    length(data$detected_ever) == C &&
    all(data$detected_ever %in% c(0L, 1L)) &&
    is.list(stan) &&
    identical(stan, expected_stan) &&
    !is.null(prior) &&
    is.character(data$data_hash) &&
    length(data$data_hash) == 1L &&
    grepl("^[0-9a-f]{64}$", data$data_hash) &&
    identical(data$data_hash, expected_hash)
  if (!valid) {
    .goal003_flexirich_stop("data must be canonical Goal003 FlexiRich data.")
  }
  validate_flexirich_g_data(data$source_data)
  invisible(TRUE)
}

#' Prepare data for the Goal003 FlexiRich candidate
prepare_goal003_flexirich_data <- function(data, prior_id = "primary") {
  validate_flexirich_g_data(data)
  priors <- goal003_flexirich_prior_profiles()
  if (!is.character(prior_id) ||
      length(prior_id) != 1L ||
      is.na(prior_id) ||
      !prior_id %in% names(priors)) {
    .goal003_flexirich_stop(
      "prior_id must name one frozen Goal003 FlexiRich prior profile."
    )
  }
  prior <- priors[[prior_id]]
  stan_data <- c(
    data$stan_data,
    prior[setdiff(names(prior), "profile_id")]
  )
  result <- list(
    candidate_ids = data$candidate_ids,
    camera_ids = data$camera_ids,
    detected_ever = data$stan_data$detected_ever,
    stan_data = stan_data,
    source_data = data,
    prior_id = prior_id,
    data_hash = digest::digest(
      list(
        source_data_hash = data$data_hash,
        prior_profile_id = prior$profile_id
      ),
      algo = "sha256",
      serialize = TRUE
    )
  )
  .validate_goal003_flexirich_data(result)
  result
}

#' R reference calculation for Goal003 FlexiRich membership probabilities
goal003_flexirich_conditionals <- function(
  data,
  omega,
  alpha,
  camera_effect
) {
  .validate_goal003_flexirich_data(data)
  C <- length(data$candidate_ids)
  J <- length(data$camera_ids)
  valid <- is.numeric(omega) &&
    !is.logical(omega) &&
    length(omega) == 1L &&
    !is.na(omega) &&
    is.finite(omega) &&
    omega > 0 &&
    omega < 1 &&
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
    .goal003_flexirich_stop(paste0(
      "omega must be in (0, 1), with one finite alpha per candidate and ",
      "one finite camera effect per camera."
    ))
  }
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
    member_ll = member_ll,
    q_member = q_member,
    expected_richness = sum(q_member)
  )
}

#' Compile the Goal003 FlexiRich candidate model
compile_goal003_flexirich_model <- function(force_recompile = FALSE) {
  .goal003_compile_model(
    stan_file = file.path("stan", "goal003_flexirich.stan"),
    cache_id = "flexirich",
    executable_stem = "goal003-flexirich",
    force_recompile = force_recompile
  )
}

.goal003_detection_from_log_hazard <- function(log_hazard) {
  result <- numeric(length(log_hazard))
  underflow <- log_hazard < log(.Machine$double.xmin)
  overflow <- log_hazard > log(.Machine$double.xmax)
  regular <- !(underflow | overflow)
  result[underflow] <- exp(log_hazard[underflow])
  result[overflow] <- 1
  if (any(regular)) {
    result[regular] <- -expm1(-exp(log_hazard[regular]))
  }
  result
}

.goal003_future_detection_probability <- function(
  alpha_draws,
  camera_effect_draws,
  future_active_days
) {
  D <- nrow(alpha_draws)
  C <- ncol(alpha_draws)
  active <- future_active_days > 0
  if (!any(active)) {
    return(matrix(0, nrow = D, ncol = C))
  }
  log_effort <- log(future_active_days[active])
  camera <- camera_effect_draws[, active, drop = FALSE]
  probability <- matrix(NA_real_, nrow = D, ncol = C)
  for (i in seq_len(C)) {
    terms <- sweep(camera, 1L, alpha_draws[, i], "+")
    terms <- sweep(terms, 2L, log_effort, "+")
    log_hazard <- apply(terms, 1L, function(x) {
      anchor <- max(x)
      anchor + log(sum(exp(x - anchor)))
    })
    probability[, i] <- .goal003_detection_from_log_hazard(log_hazard)
  }
  probability
}

#' Summarise Goal003 FlexiRich posterior probability draws
summarise_goal003_flexirich_draws <- function(
  q_member_draws,
  alpha_draws,
  camera_effect_draws,
  candidate_ids,
  camera_ids,
  detected_ever,
  future_active_days = NULL
) {
  D <- if (is.matrix(q_member_draws)) nrow(q_member_draws) else 0L
  C <- length(candidate_ids)
  J <- length(camera_ids)
  valid <- is.matrix(q_member_draws) &&
    is.numeric(q_member_draws) &&
    identical(dim(q_member_draws), c(D, C)) &&
    D > 0L &&
    !anyNA(q_member_draws) &&
    all(is.finite(q_member_draws)) &&
    all(q_member_draws >= 0 & q_member_draws <= 1) &&
    is.matrix(alpha_draws) &&
    is.numeric(alpha_draws) &&
    identical(dim(alpha_draws), c(D, C)) &&
    !anyNA(alpha_draws) &&
    all(is.finite(alpha_draws)) &&
    is.matrix(camera_effect_draws) &&
    is.numeric(camera_effect_draws) &&
    identical(dim(camera_effect_draws), c(D, J)) &&
    !anyNA(camera_effect_draws) &&
    all(is.finite(camera_effect_draws)) &&
    is.character(candidate_ids) &&
    C > 0L &&
    !anyNA(candidate_ids) &&
    !anyDuplicated(candidate_ids) &&
    is.character(camera_ids) &&
    J > 0L &&
    !anyNA(camera_ids) &&
    !anyDuplicated(camera_ids) &&
    is.integer(detected_ever) &&
    length(detected_ever) == C &&
    all(detected_ever %in% c(0L, 1L)) &&
    all(
      abs(rowSums(camera_effect_draws)) <=
        1e-10 * (1 + rowSums(abs(camera_effect_draws)))
    ) &&
    all(q_member_draws[, detected_ever == 1L, drop = FALSE] == 1)
  if (!valid) {
    .goal003_flexirich_stop(
      "FlexiRich posterior draws or identifiers have an invalid contract."
    )
  }

  richness_pmf <- .goal003_mean_poisson_binomial(q_member_draws)
  grid_identity <- tibble::tibble(
    species_id = candidate_ids,
    training_detected = detected_ever == 1L,
    membership_probability = colMeans(q_member_draws)
  )
  if (is.null(future_active_days)) {
    return(list(
      richness_pmf = richness_pmf,
      grid_identity = grid_identity,
      new_species_count_pmf = NULL,
      future_identity = NULL
    ))
  }
  valid_future <- is.numeric(future_active_days) &&
    !is.logical(future_active_days) &&
    length(future_active_days) == J &&
    !is.null(names(future_active_days)) &&
    identical(names(future_active_days), camera_ids) &&
    !anyNA(future_active_days) &&
    all(is.finite(future_active_days)) &&
    all(future_active_days >= 0) &&
    all(future_active_days == trunc(future_active_days))
  if (!valid_future) {
    .goal003_flexirich_stop(paste0(
      "future_active_days must be a named non-negative whole-number ",
      "vector in camera_ids order."
    ))
  }
  encounter <- .goal003_future_detection_probability(
    alpha_draws,
    camera_effect_draws,
    future_active_days
  )
  discovery <- q_member_draws * encounter
  discovery[, detected_ever == 1L] <- 0
  unseen <- detected_ever == 0L
  new_species_count_pmf <- .goal003_mean_poisson_binomial(
    discovery[, unseen, drop = FALSE]
  )
  names(new_species_count_pmf)[[1L]] <- "new_species_count"
  future_identity <- tibble::tibble(
    species_id = candidate_ids,
    training_detected = detected_ever == 1L,
    future_first_detection_probability = colMeans(discovery)
  )
  list(
    richness_pmf = richness_pmf,
    grid_identity = grid_identity,
    new_species_count_pmf = new_species_count_pmf,
    future_identity = future_identity
  )
}

.goal003_flexirich_monitored_variables <- function(data) {
  .validate_goal003_flexirich_data(data)
  c(
    "omega", "mu_alpha", "sigma_alpha", "sigma_camera",
    "expected_richness", "alpha", "camera_effect"
  )
}

#' Fit the Goal003 FlexiRich candidate
fit_goal003_flexirich <- function(
  data,
  seed,
  output_dir,
  rescue = TRUE,
  refresh = 100L
) {
  .validate_goal003_flexirich_data(data)
  valid_seed <- is.numeric(seed) &&
    !is.logical(seed) &&
    length(seed) == 1L &&
    !is.na(seed) &&
    is.finite(seed) &&
    seed == trunc(seed) &&
    seed >= 1 &&
    seed < .Machine$integer.max
  if (!valid_seed) {
    .goal003_flexirich_stop(
      "seed must be one positive representable integer."
    )
  }
  if (!is.logical(rescue) || length(rescue) != 1L || is.na(rescue)) {
    .goal003_flexirich_stop("rescue must be exactly TRUE or FALSE.")
  }
  valid_refresh <- is.numeric(refresh) &&
    !is.logical(refresh) &&
    length(refresh) == 1L &&
    !is.na(refresh) &&
    is.finite(refresh) &&
    refresh == trunc(refresh) &&
    refresh >= 0 &&
    refresh <= .Machine$integer.max
  if (!valid_refresh) {
    .goal003_flexirich_stop(
      "refresh must be one non-negative representable integer."
    )
  }
  absolute_output <- .goal003_prepare_output_directory(output_dir)
  model <- compile_goal003_flexirich_model()
  profiles <- goal003_flexirich_sampler_profiles()
  thresholds <- goal003_flexirich_diagnostic_thresholds()
  monitored <- .goal003_flexirich_monitored_variables(data)
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
    prior = goal003_flexirich_prior_profiles()[[data$prior_id]],
    output_dir = absolute_output,
    attempts = attempts
  )
}

.goal003_terminal_flexirich_fit <- function(result) {
  if (!is.list(result) ||
      !identical(
        names(result),
        c("terminal_status", "data", "prior", "output_dir", "attempts")
      ) ||
      !result$terminal_status %in% c("primary_clean", "rescue_clean")) {
    .goal003_flexirich_stop(
      "result must contain a terminal-clean Goal003 FlexiRich fit."
    )
  }
  attempt_name <- if (identical(result$terminal_status, "primary_clean")) {
    "primary"
  } else {
    "rescue"
  }
  result$attempts[[attempt_name]]$fit
}

#' Summarise a terminal-clean FlexiRich fit and optional future effort
predict_goal003_flexirich <- function(result, future_effort = NULL) {
  fit <- .goal003_terminal_flexirich_fit(result)
  data <- result$data
  .validate_goal003_flexirich_data(data)
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
    .goal003_flexirich_stop(
      "The FlexiRich fit is missing posterior prediction variables."
    )
  }
  future_active_days <- if (is.null(future_effort)) {
    NULL
  } else {
    .goal003_future_active_days(future_effort, data$camera_ids)
  }
  summarise_goal003_flexirich_draws(
    q_member_draws = as.matrix(draws[, q_names, drop = FALSE]),
    alpha_draws = as.matrix(draws[, alpha_names, drop = FALSE]),
    camera_effect_draws = as.matrix(
      draws[, camera_names, drop = FALSE]
    ),
    candidate_ids = data$candidate_ids,
    camera_ids = data$camera_ids,
    detected_ever = data$detected_ever,
    future_active_days = future_active_days
  )
}

#' Simulate from one frozen Goal003 FlexiRich prior profile
simulate_goal003_flexirich_prior <- function(
  profile_id,
  n_draws,
  seed,
  candidate_pool_size = 50L,
  n_cameras = 9L
) {
  profiles <- goal003_flexirich_prior_profiles()
  valid_integer <- function(x, lower) {
    is.numeric(x) &&
      !is.logical(x) &&
      length(x) == 1L &&
      !is.na(x) &&
      is.finite(x) &&
      x == trunc(x) &&
      x >= lower &&
      x <= .Machine$integer.max
  }
  if (!is.character(profile_id) ||
      length(profile_id) != 1L ||
      is.na(profile_id) ||
      !profile_id %in% names(profiles)) {
    .goal003_flexirich_stop(
      "profile_id must name one frozen Goal003 FlexiRich prior profile."
    )
  }
  if (!valid_integer(n_draws, 1L) ||
      !valid_integer(seed, 0L) ||
      !valid_integer(candidate_pool_size, 1L) ||
      !valid_integer(n_cameras, 1L)) {
    .goal003_flexirich_stop(
      "Prior simulation dimensions and seed must be representable integers."
    )
  }
  n_draws <- as.integer(n_draws)
  seed <- as.integer(seed)
  C <- as.integer(candidate_pool_size)
  J <- as.integer(n_cameras)
  prior <- profiles[[profile_id]]
  set.seed(seed)

  omega <- stats::rbeta(n_draws, prior$omega_alpha, prior$omega_beta)
  mu_alpha <- stats::rnorm(
    n_draws,
    prior$mu_alpha_location,
    prior$mu_alpha_scale
  )
  sigma_alpha <- abs(stats::rnorm(n_draws, 0, prior$sigma_alpha_scale))
  sigma_camera <- abs(stats::rnorm(n_draws, 0, prior$sigma_camera_scale))
  alpha <- matrix(stats::rnorm(n_draws * C), nrow = n_draws)
  alpha <- sweep(alpha, 1L, sigma_alpha, "*")
  alpha <- sweep(alpha, 1L, mu_alpha, "+")
  membership <- matrix(
    stats::rbinom(
      n_draws * C,
      size = 1L,
      prob = rep(omega, times = C)
    ),
    nrow = n_draws
  )
  Q <- .sum_zero_basis(J)
  if (J == 1L) {
    camera_effect <- matrix(0, nrow = n_draws, ncol = 1L)
  } else {
    z_camera <- matrix(stats::rnorm(n_draws * (J - 1L)), nrow = n_draws)
    camera_effect <- z_camera %*% t(Q)
    camera_effect <- sweep(camera_effect, 1L, sigma_camera, "*")
  }

  daily_hazard <- matrix(0, nrow = n_draws, ncol = C)
  rate_values <- numeric(n_draws * C * J)
  offset <- 0L
  for (j in seq_len(J)) {
    eta <- sweep(alpha, 1L, camera_effect[, j], "+")
    rate <- exp(eta)
    daily_hazard <- daily_hazard + rate
    index <- offset + seq_len(n_draws * C)
    rate_values[index] <- as.vector(rate)
    offset <- offset + n_draws * C
  }
  p_detect_4 <- -expm1(-28 * daily_hazard)
  p_detect_26 <- -expm1(-182 * daily_hazard)
  uniform <- matrix(stats::runif(n_draws * C), nrow = n_draws)
  true_richness <- rowSums(membership)
  observed_4 <- rowSums(membership == 1L & uniform < p_detect_4)
  observed_26 <- rowSums(membership == 1L & uniform < p_detect_26)
  invisible_26 <- rowSums(membership == 1L & p_detect_26 < 0.05)

  summarise_distribution <- function(metric, values) {
    quantiles <- stats::quantile(
      values,
      probs = c(0.025, 0.5, 0.975),
      names = FALSE,
      type = 8
    )
    tibble::tibble(
      metric = metric,
      mean = mean(values),
      sd = if (length(values) == 1L) 0 else stats::sd(values),
      q025 = quantiles[[1L]],
      median = quantiles[[2L]],
      q975 = quantiles[[3L]],
      minimum = min(values),
      maximum = max(values)
    )
  }
  one_day <- -expm1(-rate_values)
  seven_day <- -expm1(-7 * rate_values)
  invisible_fraction <- ifelse(
    true_richness == 0L,
    0,
    invisible_26 / true_richness
  )
  distribution_summary <- dplyr::bind_rows(
    summarise_distribution("omega", omega),
    summarise_distribution("mu_alpha", mu_alpha),
    summarise_distribution("sigma_alpha", sigma_alpha),
    summarise_distribution("sigma_camera", sigma_camera),
    summarise_distribution("camera_effect", as.vector(camera_effect)),
    summarise_distribution("encounter_rate_per_camera_day", rate_values),
    summarise_distribution("one_day_detection_probability", one_day),
    summarise_distribution("seven_day_detection_probability", seven_day),
    summarise_distribution("true_richness", true_richness),
    summarise_distribution("observed_richness_4", observed_4),
    summarise_distribution("observed_richness_26", observed_26),
    summarise_distribution("invisible_members_26", invisible_26),
    summarise_distribution(
      "invisible_member_fraction_26",
      invisible_fraction
    )
  )
  all_finite <- all(is.finite(omega)) &&
    all(is.finite(mu_alpha)) &&
    all(is.finite(sigma_alpha)) &&
    all(is.finite(sigma_camera)) &&
    all(is.finite(alpha)) &&
    all(is.finite(camera_effect)) &&
    all(is.finite(rate_values)) &&
    all(is.finite(p_detect_4)) &&
    all(is.finite(p_detect_26))
  max_camera_sum <- max(abs(rowSums(camera_effect)))
  max_nesting_violation <- max(observed_4 - observed_26)
  max_truth_violation <- max(observed_26 - true_richness)
  invariants <- tibble::tibble(
    invariant = c(
      "all_values_finite",
      "max_abs_camera_effect_sum",
      "max_observed_nesting_violation",
      "max_observed_truth_violation"
    ),
    value = c(
      as.numeric(all_finite),
      max_camera_sum,
      max_nesting_violation,
      max_truth_violation
    ),
    threshold = c(1, 1e-12, 0, 0),
    passed = c(
      all_finite,
      max_camera_sum < 1e-12,
      max_nesting_violation <= 0,
      max_truth_violation <= 0
    )
  )
  list(
    profile_id = prior$profile_id,
    draws = tibble::tibble(
      draw = seq_len(n_draws),
      omega = omega,
      true_richness = as.integer(true_richness),
      observed_richness_4 = as.integer(observed_4),
      observed_richness_26 = as.integer(observed_26),
      invisible_members_26 = as.integer(invisible_26),
      invisible_member_fraction_26 = invisible_fraction
    ),
    distribution_summary = distribution_summary,
    invariants = invariants
  )
}
