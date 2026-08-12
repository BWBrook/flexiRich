.goal003_occupancy_stop <- function(message) {
  stop(message, call. = FALSE)
}

#' Frozen Goal003 conventional-occupancy priors
goal003_occupancy_prior <- function() {
  list(
    profile_id = "goal003-occupancy-primary-v1",
    mu_psi_location = stats::qlogis(0.1),
    mu_psi_scale = 1,
    sigma_psi_scale = 1,
    mu_log_rate_location = log(0.02),
    mu_log_rate_scale = 1.5,
    sigma_log_rate_scale = 1
  )
}

#' Frozen Goal003 conventional-occupancy sampler profiles
goal003_occupancy_sampler_profiles <- function() {
  list(
    primary = list(
      profile_id = "goal003-occupancy-primary-sampler-v1",
      chains = 4L,
      parallel_chains = 4L,
      iter_warmup = 1000L,
      iter_sampling = 1000L,
      adapt_delta = 0.90,
      max_treedepth = 12L
    ),
    rescue = list(
      profile_id = "goal003-occupancy-rescue-sampler-v1",
      chains = 4L,
      parallel_chains = 4L,
      iter_warmup = 1500L,
      iter_sampling = 1500L,
      adapt_delta = 0.999,
      max_treedepth = 15L
    )
  )
}

goal003_occupancy_diagnostic_thresholds <- function() {
  list(
    max_divergences = 0L,
    max_treedepth_hits = 0L,
    min_ebfmi = 0.3,
    max_rhat = 1.01,
    min_bulk_ess = 400,
    min_tail_ess = 400
  )
}

.validate_goal003_occupancy_data <- function(data) {
  required <- c(
    "candidate_ids", "camera_ids", "detected_ever",
    "site_detected_ever", "stan_data", "data_hash"
  )
  if (!is.list(data) || !identical(names(data), required)) {
    .goal003_occupancy_stop(
      "data must be canonical Goal003 occupancy data."
    )
  }
  C <- length(data$candidate_ids)
  J <- length(data$camera_ids)
  site <- data$site_detected_ever
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
    is.matrix(site) &&
    is.integer(site) &&
    identical(dim(site), c(C, J)) &&
    all(site %in% c(0L, 1L)) &&
    identical(data$detected_ever, as.integer(rowSums(site) > 0L)) &&
    is.list(data$stan_data) &&
    identical(data$stan_data$C, as.integer(C)) &&
    identical(data$stan_data$J, as.integer(J)) &&
    identical(data$stan_data$site_detected_ever, site) &&
    is.character(data$data_hash) &&
    length(data$data_hash) == 1L &&
    grepl("^[0-9a-f]{64}$", data$data_hash)
  if (!valid) {
    .goal003_occupancy_stop(
      "data must be canonical Goal003 occupancy data."
    )
  }
  invisible(TRUE)
}

#' Prepare the conventional multispecies occupancy comparator
#'
#' @param data A canonical `flexirich_g_data` training object.
#'
#' @return The compact grouped Stan input and candidate/site detection states.
prepare_goal003_occupancy_data <- function(data) {
  validate_flexirich_g_data(data)
  C <- length(data$candidate_ids)
  J <- length(data$camera_ids)
  site_detected_ever <- matrix(
    0L,
    nrow = C,
    ncol = J,
    dimnames = list(data$candidate_ids, data$camera_ids)
  )
  detected_rows <- data$observed |>
    dplyr::filter(detected == 1L) |>
    dplyr::distinct(species_id, camera_id)
  if (nrow(detected_rows) > 0L) {
    site_detected_ever[cbind(
      match(detected_rows$species_id, data$candidate_ids),
      match(detected_rows$camera_id, data$camera_ids)
    )] <- 1L
  }
  storage.mode(site_detected_ever) <- "integer"
  prior <- goal003_occupancy_prior()
  grouped <- data$grouped
  stan_data <- list(
    C = as.integer(C),
    J = as.integer(J),
    G = as.integer(nrow(grouped)),
    species_index = as.integer(match(
      grouped$species_id,
      data$candidate_ids
    )),
    camera_index = as.integer(match(
      grouped$camera_id,
      data$camera_ids
    )),
    active_days = grouped$active_days,
    n_trials = grouped$n_trials,
    n_detected = grouped$n_detected,
    site_detected_ever = site_detected_ever,
    mu_psi_location = prior$mu_psi_location,
    mu_psi_scale = prior$mu_psi_scale,
    sigma_psi_scale = prior$sigma_psi_scale,
    mu_log_rate_location = prior$mu_log_rate_location,
    mu_log_rate_scale = prior$mu_log_rate_scale,
    sigma_log_rate_scale = prior$sigma_log_rate_scale
  )
  result <- list(
    candidate_ids = data$candidate_ids,
    camera_ids = data$camera_ids,
    detected_ever = as.integer(rowSums(site_detected_ever) > 0L),
    site_detected_ever = site_detected_ever,
    stan_data = stan_data,
    data_hash = digest::digest(
      list(
        source_data_hash = data$data_hash,
        stan_data = stan_data,
        prior_profile_id = prior$profile_id
      ),
      algo = "sha256",
      serialize = TRUE
    )
  )
  .validate_goal003_occupancy_data(result)
  result
}

#' R reference calculation for occupancy conditional probabilities
#'
#' @param data Output from `prepare_goal003_occupancy_data()`.
#' @param psi Candidate-specific camera-use probabilities.
#' @param rate Candidate-specific encounter hazards per active day.
#'
#' @return Site and grid conditional-use probabilities plus member log
#'   likelihoods.
goal003_occupancy_conditionals <- function(data, psi, rate) {
  .validate_goal003_occupancy_data(data)
  C <- length(data$candidate_ids)
  J <- length(data$camera_ids)
  valid <- is.numeric(psi) &&
    !is.logical(psi) &&
    length(psi) == C &&
    !anyNA(psi) &&
    all(is.finite(psi)) &&
    all(psi > 0 & psi < 1) &&
    is.numeric(rate) &&
    !is.logical(rate) &&
    length(rate) == C &&
    !anyNA(rate) &&
    all(is.finite(rate)) &&
    all(rate > 0)
  if (!valid) {
    .goal003_occupancy_stop(
      "psi must be in (0, 1) and rate must be positive, one per candidate."
    )
  }
  psi <- as.numeric(psi)
  rate <- as.numeric(rate)
  grouped <- data$stan_data
  member_ll <- matrix(0, nrow = C, ncol = J)
  if (grouped$G > 0L) {
    log_rate <- log(rate[grouped$species_index])
    log_detect <- log_detect_probability(log_rate, grouped$active_days)
    log_nondetect <- log_nondetect_probability(
      log_rate,
      grouped$active_days
    )
    contribution <- numeric(grouped$G)
    detected <- grouped$n_detected > 0L
    nondetected <- grouped$n_trials - grouped$n_detected > 0L
    contribution[detected] <- contribution[detected] +
      grouped$n_detected[detected] * log_detect[detected]
    contribution[nondetected] <- contribution[nondetected] +
      (grouped$n_trials[nondetected] - grouped$n_detected[nondetected]) *
      log_nondetect[nondetected]
    for (g in seq_len(grouped$G)) {
      i <- grouped$species_index[[g]]
      j <- grouped$camera_index[[g]]
      member_ll[i, j] <- member_ll[i, j] + contribution[[g]]
    }
  }
  q_site <- matrix(
    stats::plogis(stats::qlogis(psi) + member_ll),
    nrow = C,
    ncol = J
  )
  q_site[data$site_detected_ever == 1L] <- 1
  q_grid <- 1 - apply(1 - q_site, 1L, prod)
  dimnames(member_ll) <- list(data$candidate_ids, data$camera_ids)
  dimnames(q_site) <- list(data$candidate_ids, data$camera_ids)
  names(q_grid) <- data$candidate_ids
  list(member_ll = member_ll, q_site = q_site, q_grid = q_grid)
}

#' Summarise conventional-occupancy posterior probability draws
#'
#' @param q_site_draws Numeric array with dimensions draw, candidate, camera.
#' @param rate_draws Numeric matrix with one encounter-rate column per
#'   candidate.
#' @param candidate_ids Candidate names in array order.
#' @param camera_ids Camera names in array order.
#' @param detected_ever Integer 0/1 vector identifying candidates observed in
#'   training.
#' @param future_active_days Named non-negative camera-day totals for the
#'   realised forecast block. If `NULL`, prospective outputs are omitted.
#'
#' @return Exact posterior-mixture grid-richness and prospective-discovery
#'   summaries.
summarise_goal003_occupancy_draws <- function(
  q_site_draws,
  rate_draws,
  candidate_ids,
  camera_ids,
  detected_ever,
  future_active_days = NULL
) {
  dimensions <- dim(q_site_draws)
  D <- if (length(dimensions) == 3L) dimensions[[1L]] else 0L
  C <- length(candidate_ids)
  J <- length(camera_ids)
  valid <- is.numeric(q_site_draws) &&
    identical(dimensions, c(D, C, J)) &&
    D > 0L &&
    !anyNA(q_site_draws) &&
    all(is.finite(q_site_draws)) &&
    all(q_site_draws >= 0 & q_site_draws <= 1) &&
    is.matrix(rate_draws) &&
    is.numeric(rate_draws) &&
    identical(dim(rate_draws), c(D, C)) &&
    !anyNA(rate_draws) &&
    all(is.finite(rate_draws)) &&
    all(rate_draws > 0) &&
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
    all(detected_ever %in% c(0L, 1L))
  if (!valid) {
    .goal003_occupancy_stop(
      "Occupancy posterior draws or identifiers have an invalid contract."
    )
  }

  q_grid <- matrix(NA_real_, nrow = D, ncol = C)
  for (i in seq_len(C)) {
    q_grid[, i] <- 1 - apply(1 - q_site_draws[, i, , drop = FALSE], 1L, prod)
  }
  richness_pmf <- .goal003_mean_poisson_binomial(q_grid)
  grid_identity <- tibble::tibble(
    species_id = candidate_ids,
    training_detected = detected_ever == 1L,
    grid_use_probability = colMeans(q_grid)
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
    .goal003_occupancy_stop(paste0(
      "future_active_days must be a named non-negative whole-number ",
      "vector in camera_ids order."
    ))
  }
  discovery <- matrix(0, nrow = D, ncol = C)
  unseen <- detected_ever == 0L
  for (i in which(unseen)) {
    for (j in seq_len(J)) {
      encounter <- -expm1(-future_active_days[[j]] * rate_draws[, i])
      if (j == 1L) {
        no_discovery <- 1 - q_site_draws[, i, j] * encounter
      } else {
        no_discovery <- no_discovery *
          (1 - q_site_draws[, i, j] * encounter)
      }
    }
    discovery[, i] <- 1 - no_discovery
  }
  new_species_count_pmf <- .goal003_mean_poisson_binomial(discovery[, unseen, drop = FALSE])
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

#' Compile the frozen Goal003 conventional-occupancy model
#'
#' Compilation is cached by Stan-source hash beneath ignored Goal003 outputs;
#' no compiler artefact is written beside the tracked source.
compile_goal003_occupancy_model <- function(force_recompile = FALSE) {
  .goal003_compile_model(
    stan_file = file.path("stan", "goal003_community_occupancy.stan"),
    cache_id = "occupancy",
    executable_stem = "goal003-community-occupancy",
    force_recompile = force_recompile
  )
}

#' Fit the Goal003 conventional multispecies occupancy comparator
#'
#' @param data Output from `prepare_goal003_occupancy_data()`.
#' @param seed Positive integer seed.
#' @param output_dir New directory beneath `outputs/goal003`.
#' @param rescue Whether to make the one prespecified rescue attempt after a
#'   non-clean primary fit.
#' @param refresh CmdStan progress refresh interval.
#'
#' @return A terminal fit record containing one or two attempts.
fit_goal003_occupancy <- function(
  data,
  seed,
  output_dir,
  rescue = TRUE,
  refresh = 100L
) {
  .validate_goal003_occupancy_data(data)
  valid_seed <- is.numeric(seed) &&
    !is.logical(seed) &&
    length(seed) == 1L &&
    !is.na(seed) &&
    is.finite(seed) &&
    seed == trunc(seed) &&
    seed >= 1 &&
    seed < .Machine$integer.max
  if (!valid_seed) {
    .goal003_occupancy_stop("seed must be one positive representable integer.")
  }
  seed <- as.integer(seed)
  if (!is.character(output_dir) ||
      length(output_dir) != 1L ||
      is.na(output_dir) ||
      !nzchar(output_dir)) {
    .goal003_occupancy_stop("output_dir must be one non-empty path.")
  }
  if (!is.logical(rescue) || length(rescue) != 1L || is.na(rescue)) {
    .goal003_occupancy_stop("rescue must be exactly TRUE or FALSE.")
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
    .goal003_occupancy_stop(
      "refresh must be one non-negative representable integer."
    )
  }
  root <- .goal003_project_root()
  boundary <- normalizePath(
    file.path(root, "outputs", "goal003"),
    mustWork = FALSE
  )
  absolute_output <- normalizePath(
    if (startsWith(output_dir, "/")) output_dir else file.path(root, output_dir),
    mustWork = FALSE
  )
  if (!startsWith(absolute_output, paste0(boundary, .Platform$file.sep))) {
    .goal003_occupancy_stop(
      "output_dir must be a new directory beneath outputs/goal003."
    )
  }
  if (file.exists(absolute_output) || dir.exists(absolute_output)) {
    .goal003_occupancy_stop("output_dir must not already exist.")
  }
  dir.create(absolute_output, recursive = TRUE, showWarnings = FALSE)

  model <- compile_goal003_occupancy_model()
  profiles <- goal003_occupancy_sampler_profiles()
  monitored <- c("mu_psi", "sigma_psi", "mu_log_rate", "sigma_log_rate")
  thresholds <- goal003_occupancy_diagnostic_thresholds()
  primary <- .goal003_model_attempt(
    model = model,
    stan_data = data$stan_data,
    sampler_profile = profiles$primary,
    diagnostic_thresholds = thresholds,
    monitored_variables = monitored,
    seed = seed,
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
      seed = seed + 1L,
      output_dir = file.path(absolute_output, "rescue"),
      attempt_id = "rescue",
      refresh = as.integer(refresh)
    )
    attempts$rescue <- rescue_attempt
  }
  list(
    terminal_status = .goal003_terminal_status(primary, rescue_attempt),
    data = data,
    prior = goal003_occupancy_prior(),
    output_dir = absolute_output,
    attempts = attempts
  )
}

.goal003_terminal_occupancy_fit <- function(result) {
  if (!is.list(result) ||
      !identical(
        names(result),
        c("terminal_status", "data", "prior", "output_dir", "attempts")
      ) ||
      !result$terminal_status %in% c("primary_clean", "rescue_clean")) {
    .goal003_occupancy_stop(
      "result must contain a terminal-clean Goal003 occupancy fit."
    )
  }
  attempt_name <- if (identical(result$terminal_status, "primary_clean")) {
    "primary"
  } else {
    "rescue"
  }
  result$attempts[[attempt_name]]$fit
}

#' Summarise a terminal-clean occupancy fit and optional future effort
#'
#' @param result Output from `fit_goal003_occupancy()`.
#' @param future_effort Optional realised forecast effort with canonical weekly
#'   effort fields.
#'
#' @return Exact posterior-mixture richness and prospective summaries.
predict_goal003_occupancy <- function(result, future_effort = NULL) {
  fit <- .goal003_terminal_occupancy_fit(result)
  data <- result$data
  .validate_goal003_occupancy_data(data)
  C <- length(data$candidate_ids)
  J <- length(data$camera_ids)
  q_names <- unlist(lapply(seq_len(C), function(i) {
    sprintf("q_site[%d,%d]", i, seq_len(J))
  }), use.names = FALSE)
  rate_names <- sprintf("rate[%d]", seq_len(C))
  draws <- posterior::as_draws_matrix(fit$draws(
    variables = c("q_site", "rate")
  ))
  missing <- setdiff(c(q_names, rate_names), colnames(draws))
  if (length(missing) > 0L) {
    .goal003_occupancy_stop(
      "The occupancy fit is missing posterior prediction variables."
    )
  }
  D <- nrow(draws)
  q_site <- array(NA_real_, dim = c(D, C, J))
  for (i in seq_len(C)) {
    for (j in seq_len(J)) {
      q_site[, i, j] <- draws[, sprintf("q_site[%d,%d]", i, j)]
    }
  }
  rate <- as.matrix(draws[, rate_names, drop = FALSE])
  future_active_days <- if (is.null(future_effort)) {
    NULL
  } else {
    .goal003_future_active_days(future_effort, data$camera_ids)
  }
  summarise_goal003_occupancy_draws(
    q_site,
    rate,
    data$candidate_ids,
    data$camera_ids,
    data$detected_ever,
    future_active_days
  )
}
