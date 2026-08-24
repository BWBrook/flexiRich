.goal006_log_sum_exp <- function(x) {
  maximum <- max(x)
  maximum + log(sum(exp(x - maximum)))
}

#' Fixed Gauss--Hermite rule for standard-normal expectations
#'
#' @param order Number of quadrature nodes.
#'
#' @return Nodes for the exp(-x^2) rule and weights normalised to one.
goal006_gauss_hermite <- function(order = 64L) {
  valid <- is.numeric(order) && !is.logical(order) && length(order) == 1L &&
    !is.na(order) && is.finite(order) && order == trunc(order) && order >= 8L
  if (!valid) {
    .goal006_stop("quadrature order must be one integer of at least eight.")
  }
  order <- as.integer(order)
  jacobi <- matrix(0, nrow = order, ncol = order)
  off_diagonal <- sqrt(seq_len(order - 1L) / 2)
  jacobi[cbind(seq_len(order - 1L), 2:order)] <- off_diagonal
  jacobi[cbind(2:order, seq_len(order - 1L))] <- off_diagonal
  decomposition <- eigen(jacobi, symmetric = TRUE)
  index <- order(decomposition$values)
  nodes <- decomposition$values[index]
  hermite_previous <- rep(1, order)
  hermite_current <- 2 * nodes
  if (order > 2L) {
    for (degree in 2:(order - 1L)) {
      hermite_next <- 2 * nodes * hermite_current -
        2 * (degree - 1L) * hermite_previous
      hermite_previous <- hermite_current
      hermite_current <- hermite_next
    }
  }
  log_weights <- (order - 1) * log(2) + lgamma(order + 1) -
    2 * log(order) - 2 * log(abs(hermite_current))
  log_weights <- log_weights - .goal006_log_sum_exp(log_weights)
  weights <- exp(log_weights)
  list(
    order = order,
    node = as.numeric(nodes),
    weight = as.numeric(weights),
    log_weight = as.numeric(log_weights)
  )
}

.goal006_log_detection <- function(log_hazard) {
  result <- log(-expm1(-exp(pmin(log_hazard, 709))))
  result[log_hazard > 20] <- 0
  result[log_hazard < -700] <- log_hazard[log_hazard < -700]
  result
}

#' Probability that a member enters the detected calibration sample
#'
#' @param class_location Mean member log encounter rate for one class.
#' @param log_rate_sd Fixed between-species log-rate standard deviation.
#' @param total_active_days Active days for each retained camera.
#' @param camera_effect Sum-zero camera effects.
#' @param quadrature A rule returned by [goal006_gauss_hermite()].
#'
#' @return Log detection-at-least-once probability.
goal006_selection_log_probability <- function(
  class_location,
  log_rate_sd,
  total_active_days,
  camera_effect,
  quadrature = goal006_gauss_hermite()
) {
  scalar <- function(x) {
    is.numeric(x) && !is.logical(x) && length(x) == 1L &&
      !is.na(x) && is.finite(x)
  }
  valid <- scalar(class_location) && scalar(log_rate_sd) && log_rate_sd > 0 &&
    is.numeric(total_active_days) && !is.logical(total_active_days) &&
    length(total_active_days) > 0L && !anyNA(total_active_days) &&
    all(is.finite(total_active_days)) && all(total_active_days >= 0) &&
    sum(total_active_days) > 0 && is.numeric(camera_effect) &&
    !is.logical(camera_effect) &&
    length(camera_effect) == length(total_active_days) &&
    !anyNA(camera_effect) && all(is.finite(camera_effect)) &&
    is.list(quadrature) &&
    all(c("order", "node", "weight", "log_weight") %in% names(quadrature))
  if (!valid) {
    .goal006_stop("Invalid Goal006 selection-probability arguments.")
  }
  total_hazard <- sum(total_active_days * exp(camera_effect))
  alpha <- class_location + sqrt(2) * log_rate_sd * quadrature$node
  .goal006_log_sum_exp(
    quadrature$log_weight +
      .goal006_log_detection(log(total_hazard) + alpha)
  )
}

#' High-accuracy reference for the Goal006 selection adjustment
#'
#' This direct integral is deliberately separate from the quadrature path used
#' by Stan. It returns both the value and its analytic gradients with respect
#' to class location and log total encounter exposure.
goal006_selection_reference <- function(
  class_location,
  log_rate_sd,
  total_active_days,
  camera_effect,
  subdivisions = 1000L
) {
  total_hazard <- sum(total_active_days * exp(camera_effect))
  integrand <- function(z) {
    log_hazard <- log(total_hazard) + class_location + log_rate_sd * z
    probability <- -expm1(-exp(pmin(log_hazard, 709)))
    probability[log_hazard > 20] <- 1
    stats::dnorm(z) * probability
  }
  gradient_integrand <- function(z) {
    log_hazard <- log(total_hazard) + class_location + log_rate_sd * z
    derivative <- numeric(length(log_hazard))
    stable <- log_hazard <= 20 & log_hazard >= -745
    derivative[stable] <- exp(
      log_hazard[stable] - exp(log_hazard[stable])
    )
    stats::dnorm(z) * derivative
  }
  probability <- stats::integrate(
    integrand,
    lower = -Inf,
    upper = Inf,
    subdivisions = subdivisions,
    rel.tol = 1e-12,
    abs.tol = 1e-14,
    stop.on.error = TRUE
  )$value
  gradient <- stats::integrate(
    gradient_integrand,
    lower = -Inf,
    upper = Inf,
    subdivisions = subdivisions,
    rel.tol = 1e-12,
    abs.tol = 1e-14,
    stop.on.error = TRUE
  )$value / probability
  list(
    log_probability = log(probability),
    gradient_class_location = gradient,
    gradient_log_total_hazard = gradient
  )
}

.goal006_calibration_profile <- function(profile) {
  required <- c(
    "calibration_profile", "class_prior_sd", "log_rate_sd",
    "excluded_camera_id", "excluded_start_index", "excluded_end_index",
    "routine_prior_mean", "occasional_prior_mean", "camera_sd_scale",
    "calibration_start_index", "calibration_end_index", "fit_seed"
  )
  if (!inherits(profile, "data.frame") || nrow(profile) != 1L ||
      any(!required %in% names(profile))) {
    .goal006_stop("profile must be one Goal006 calibration-fit row.")
  }
  profile <- tibble::as_tibble(profile)
  numeric_fields <- c(
    "class_prior_sd", "log_rate_sd", "routine_prior_mean",
    "occasional_prior_mean", "camera_sd_scale"
  )
  integer_fields <- c(
    "calibration_start_index", "calibration_end_index", "fit_seed"
  )
  valid <- all(vapply(profile[numeric_fields], function(x) {
    is.numeric(x) && length(x) == 1L && !is.na(x) && is.finite(x)
  }, logical(1))) &&
    profile$class_prior_sd > 0 && profile$log_rate_sd > 0 &&
    profile$camera_sd_scale > 0 &&
    all(vapply(profile[integer_fields], function(x) {
      is.numeric(x) && length(x) == 1L && !is.na(x) && is.finite(x) &&
        x == trunc(x)
    }, logical(1))) &&
    profile$calibration_start_index >= 1L &&
    profile$calibration_end_index >= profile$calibration_start_index
  if (!valid) {
    .goal006_stop("The Goal006 calibration profile is invalid.")
  }
  profile
}

.goal006_occasion_index <- function(occasion_id) {
  valid <- is.character(occasion_id) &&
    all(grepl("^occ_[0-9]{3}$", occasion_id))
  if (!valid) {
    .goal006_stop("Goal006 occasion IDs must use the occ_NNN convention.")
  }
  as.integer(sub("^occ_", "", occasion_id))
}

.goal006_subset_calibration_source <- function(source_data, profile) {
  validate_flexirich_g_data(source_data)
  profile <- .goal006_calibration_profile(profile)
  observed <- source_data$observed
  occasion_index <- .goal006_occasion_index(observed$occasion_id)
  keep_occasion <- occasion_index >= profile$calibration_start_index &
    occasion_index <= profile$calibration_end_index
  if (!is.na(profile$excluded_start_index)) {
    keep_occasion <- keep_occasion & !(
      occasion_index >= profile$excluded_start_index &
        occasion_index <= profile$excluded_end_index
    )
  }
  keep_camera <- rep(TRUE, nrow(observed))
  if (!is.na(profile$excluded_camera_id)) {
    keep_camera <- observed$camera_id != profile$excluded_camera_id
  }
  selected <- observed[keep_occasion & keep_camera, ]
  if (nrow(selected) == 0L) {
    .goal006_stop("The calibration exclusion profile removed all observations.")
  }
  effort <- selected |>
    dplyr::distinct(camera_id, occasion_id, active_days)
  detections <- selected |>
    dplyr::select(species_id, camera_id, occasion_id, detected)
  prepare_flexirich_g_data(
    tibble::tibble(species_id = source_data$candidate_ids),
    effort,
    detections
  )
}

#' Prepare the detected-only Goal006 selection-calibration likelihood
#'
#' @param source_data Canonical member histories covering the calibration span.
#' @param encounter_class Named routine/occasional class for every candidate.
#' @param profile One frozen Goal006 calibration-fit row.
#' @param quadrature_order Fixed quadrature order used by Stan.
#'
#' @return Canonical internal calibration data. Candidate identities remain
#'   internal and are not part of the aggregate calibration artifact.
prepare_goal006_calibration_data <- function(
  source_data,
  encounter_class,
  profile,
  quadrature_order = 64L
) {
  validate_flexirich_g_data(source_data)
  profile <- .goal006_calibration_profile(profile)
  valid_class <- is.character(encounter_class) &&
    !is.null(names(encounter_class)) &&
    length(encounter_class) == length(source_data$candidate_ids) &&
    !anyNA(encounter_class) && !anyNA(names(encounter_class)) &&
    !anyDuplicated(names(encounter_class)) &&
    setequal(names(encounter_class), source_data$candidate_ids) &&
    all(encounter_class %in% c("routine", "occasional"))
  if (!valid_class) {
    .goal006_stop("encounter_class must align to every candidate.")
  }
  source <- .goal006_subset_calibration_source(source_data, profile)
  aligned_class <- unname(encounter_class[
    match(source$candidate_ids, names(encounter_class))
  ])
  detected <- source$stan_data$detected_ever == 1L
  detected_ids <- source$candidate_ids[detected]
  if (length(detected_ids) == 0L) {
    .goal006_stop("Calibration requires at least one detected member.")
  }
  detected_class <- aligned_class[detected]
  class_index <- match(detected_class, c("routine", "occasional"))
  grouped <- source$grouped |>
    dplyr::filter(species_id %in% detected_ids)
  effort <- source$observed |>
    dplyr::distinct(camera_id, occasion_id, active_days) |>
    dplyr::summarise(total_active_days = sum(active_days), .by = camera_id)
  effort <- effort[match(source$camera_ids, effort$camera_id), ]
  quadrature <- goal006_gauss_hermite(quadrature_order)
  stan_data <- list(
    D = as.integer(length(detected_ids)),
    J = as.integer(length(source$camera_ids)),
    B = as.integer(max(length(source$camera_ids) - 1L, 0L)),
    G = as.integer(nrow(grouped)),
    species_index = as.integer(match(grouped$species_id, detected_ids)),
    camera_index = as.integer(match(grouped$camera_id, source$camera_ids)),
    active_days = as.integer(grouped$active_days),
    n_trials = as.integer(grouped$n_trials),
    n_detected = as.integer(grouped$n_detected),
    class_index = as.integer(class_index),
    total_active_days = as.numeric(effort$total_active_days),
    Q = .sum_zero_basis(length(source$camera_ids)),
    class_prior_mean = c(
      profile$routine_prior_mean,
      profile$occasional_prior_mean
    ),
    class_prior_sd = as.numeric(profile$class_prior_sd),
    log_rate_sd = as.numeric(profile$log_rate_sd),
    sigma_camera_scale = as.numeric(profile$camera_sd_scale),
    K = quadrature$order,
    quadrature_node = quadrature$node,
    quadrature_log_weight = quadrature$log_weight
  )
  result <- list(
    detected_species_ids = detected_ids,
    camera_ids = source$camera_ids,
    encounter_class = detected_class,
    class_index = as.integer(class_index),
    class_counts = stats::setNames(
      as.integer(tabulate(class_index, nbins = 2L)),
      c("routine", "occasional")
    ),
    profile = profile,
    quadrature = quadrature,
    stan_data = stan_data,
    source_data = source,
    model_id = goal006_model_contract()$calibration_model_id,
    data_hash = digest::digest(
      list(
        source_hash = source$data_hash,
        detected_species_ids = detected_ids,
        encounter_class = detected_class,
        profile = profile,
        quadrature = quadrature
      ),
      algo = "sha256",
      serialize = TRUE
    )
  )
  .validate_goal006_calibration_data(result)
  result
}

.validate_goal006_calibration_data <- function(data) {
  required <- c(
    "detected_species_ids", "camera_ids", "encounter_class", "class_index",
    "class_counts", "profile", "quadrature", "stan_data", "source_data",
    "model_id", "data_hash"
  )
  valid <- is.list(data) && identical(names(data), required) &&
    is.character(data$detected_species_ids) &&
    length(data$detected_species_ids) > 0L &&
    !anyNA(data$detected_species_ids) &&
    !anyDuplicated(data$detected_species_ids) &&
    is.character(data$camera_ids) && length(data$camera_ids) > 0L &&
    is.character(data$encounter_class) &&
    length(data$encounter_class) == length(data$detected_species_ids) &&
    all(data$encounter_class %in% c("routine", "occasional")) &&
    identical(
      data$class_index,
      as.integer(match(data$encounter_class, c("routine", "occasional")))
    ) &&
    is.integer(data$class_counts) &&
    identical(names(data$class_counts), c("routine", "occasional")) &&
    identical(sum(data$class_counts), length(data$detected_species_ids)) &&
    is.list(data$stan_data) &&
    identical(data$stan_data$D, as.integer(length(data$detected_species_ids))) &&
    identical(data$stan_data$J, as.integer(length(data$camera_ids))) &&
    identical(data$stan_data$class_index, data$class_index) &&
    is.character(data$model_id) &&
    identical(data$model_id, goal006_model_contract()$calibration_model_id) &&
    is.character(data$data_hash) && length(data$data_hash) == 1L &&
    grepl("^[0-9a-f]{64}$", data$data_hash)
  source_valid <- tryCatch({
    validate_flexirich_g_data(data$source_data)
    TRUE
  }, error = function(e) FALSE)
  if (!valid || !source_valid) {
    .goal006_stop("data must be canonical Goal006 calibration data.")
  }
  invisible(TRUE)
}

#' Independent likelihood terms for the Goal006 Stan/R bridge
goal006_calibration_likelihood_terms <- function(
  data,
  class_location,
  alpha,
  camera_effect
) {
  .validate_goal006_calibration_data(data)
  D <- length(data$detected_species_ids)
  J <- length(data$camera_ids)
  valid <- is.numeric(class_location) && length(class_location) == 2L &&
    !anyNA(class_location) && all(is.finite(class_location)) &&
    is.numeric(alpha) && length(alpha) == D && !anyNA(alpha) &&
    all(is.finite(alpha)) && is.numeric(camera_effect) &&
    length(camera_effect) == J && !anyNA(camera_effect) &&
    all(is.finite(camera_effect)) &&
    abs(sum(camera_effect)) <= 1e-10 * (1 + sum(abs(camera_effect)))
  if (!valid) {
    .goal006_stop("Invalid parameters for Goal006 likelihood terms.")
  }
  grouped <- data$source_data$grouped |>
    dplyr::filter(species_id %in% data$detected_species_ids)
  log_hazard <- log(grouped$active_days) +
    alpha[match(grouped$species_id, data$detected_species_ids)] +
    camera_effect[match(grouped$camera_id, data$camera_ids)]
  history <- numeric(D)
  contribution <- numeric(nrow(grouped))
  detected <- grouped$n_detected > 0L
  not_detected <- grouped$n_trials > grouped$n_detected
  contribution[detected] <- grouped$n_detected[detected] *
    .goal006_log_detection(log_hazard[detected])
  contribution[not_detected] <- contribution[not_detected] +
    (grouped$n_trials[not_detected] - grouped$n_detected[not_detected]) *
      -exp(pmin(log_hazard[not_detected], 710))
  history_sum <- rowsum(
    contribution,
    match(grouped$species_id, data$detected_species_ids),
    reorder = FALSE
  )
  history[as.integer(rownames(history_sum))] <- history_sum[, 1L]
  selection <- vapply(seq_len(2L), function(h) {
    goal006_selection_log_probability(
      class_location[h],
      data$stan_data$log_rate_sd,
      data$stan_data$total_active_days,
      camera_effect,
      data$quadrature
    )
  }, numeric(1))
  list(
    history_log_likelihood = history,
    log_selection_probability = selection,
    selection_adjusted_log_likelihood =
      sum(history - selection[data$class_index])
  )
}

#' Compile the Goal006 selection-adjusted calibration model
compile_goal006_calibration_model <- function(force_recompile = FALSE) {
  .goal003_compile_model(
    stan_file = file.path("stan", "goal006_selection_calibration.stan"),
    cache_id = "selection-calibration",
    executable_stem = "goal006-selection-calibration",
    output_namespace = "goal006",
    force_recompile = force_recompile
  )
}

.goal006_calibration_monitored_variables <- function(data) {
  .validate_goal006_calibration_data(data)
  c("class_location", "sigma_camera", "alpha", "camera_effect")
}

#' Fit the Goal006 selection-adjusted calibration model
fit_goal006_calibration <- function(
  data,
  seed,
  output_dir,
  refresh = 100L
) {
  .validate_goal006_calibration_data(data)
  valid_seed <- is.numeric(seed) && !is.logical(seed) && length(seed) == 1L &&
    !is.na(seed) && is.finite(seed) && seed == trunc(seed) && seed >= 1L &&
    seed < .Machine$integer.max
  valid_refresh <- is.numeric(refresh) && !is.logical(refresh) &&
    length(refresh) == 1L && !is.na(refresh) && is.finite(refresh) &&
    refresh == trunc(refresh) && refresh >= 0L
  if (!valid_seed || !valid_refresh) {
    .goal006_stop("Goal006 calibration fit controls are invalid.")
  }
  absolute_output <- .goal003_prepare_output_directory(
    output_dir,
    output_namespace = "goal006"
  )
  profiles <- goal003_flexirich_sampler_profiles()
  attempts <- .goal004_task4_run_attempts(
    model = compile_goal006_calibration_model(),
    stan_data = data$stan_data,
    profiles = profiles,
    thresholds = goal003_flexirich_diagnostic_thresholds(),
    monitored = .goal006_calibration_monitored_variables(data),
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

.goal006_terminal_calibration_fit <- function(result) {
  valid <- is.list(result) && result$terminal_status %in%
    c("primary_clean", "rescue_clean")
  if (!valid) {
    .goal006_stop("result must contain a terminal-clean Goal006 calibration fit.")
  }
  attempt <- if (result$terminal_status == "primary_clean") "primary" else "rescue"
  result$attempts[[attempt]]$fit
}

.goal006_calibration_draws <- function(result) {
  fit <- .goal006_terminal_calibration_fit(result)
  posterior::as_draws_matrix(fit$draws(variables = "class_location"))[, 1:2]
}

.goal006_radial_ks <- function(x) {
  x <- sort(x)
  n <- length(x)
  fitted <- stats::pchisq(x, df = 2)
  max(c(seq_len(n) / n - fitted, fitted - (seq_len(n) - 1) / n))
}

#' Build the leakage-safe aggregate calibration artifact
make_goal006_calibration_artifact <- function(
  result,
  source_receipts,
  fit_seed
) {
  data <- result$data
  .validate_goal006_calibration_data(data)
  draws <- as.matrix(.goal006_calibration_draws(result))
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
  gaussian <- vapply(seq_len(2L), function(h) {
    stats::qnorm(
      c(0.025, 0.5, 0.975),
      mean = location_mean[h],
      sd = sqrt(location_covariance[h, h])
    )
  }, numeric(3))
  skewness <- vapply(seq_len(2L), function(h) {
    centred <- draws[, h] - location_mean[h]
    mean(centred^3) / stats::sd(draws[, h])^3
  }, numeric(1))
  radial <- stats::mahalanobis(draws, location_mean, location_covariance)
  terminal <- if (result$terminal_status == "primary_clean") "primary" else "rescue"
  diagnostics <- result$attempts[[terminal]]$diagnostics
  artifact <- list(
    artifact_version = "goal006-calibration-artifact-v1",
    model_id = data$model_id,
    calibration_start_index = as.integer(
      data$profile$calibration_start_index
    ),
    calibration_end_index = as.integer(data$profile$calibration_end_index),
    class_order = class_order,
    location_mean = location_mean,
    location_covariance = location_covariance,
    class_prior = list(
      mean = stats::setNames(data$stan_data$class_prior_mean, class_order),
      sd = data$stan_data$class_prior_sd,
      camera_sd_scale = data$stan_data$sigma_camera_scale
    ),
    log_rate_sd = data$stan_data$log_rate_sd,
    source_receipts = source_receipts,
    fit_seed = as.integer(fit_seed),
    diagnostics = diagnostics,
    approximation_checks = list(
      max_quantile_error = max(abs(empirical - gaussian)),
      radial_ks_distance = .goal006_radial_ks(radial),
      max_abs_skewness = max(abs(skewness))
    )
  )
  validate_goal006_calibration_artifact(artifact)
  artifact
}

#' Validate the Goal006 aggregate-artifact boundary
validate_goal006_calibration_artifact <- function(artifact) {
  schema <- goal006_output_schema()$calibration_artifact
  prohibited <- c("candidate", "species", "detection", "membership", "alpha")
  text <- tolower(paste(capture.output(str(artifact)), collapse = " "))
  valid <- is.list(artifact) && identical(names(artifact), schema) &&
    identical(artifact$class_order, c("routine", "occasional")) &&
    is.numeric(artifact$location_mean) &&
    identical(names(artifact$location_mean), artifact$class_order) &&
    is.matrix(artifact$location_covariance) &&
    identical(dim(artifact$location_covariance), c(2L, 2L)) &&
    is.numeric(artifact$fit_seed) && length(artifact$fit_seed) == 1L &&
    !any(vapply(prohibited, grepl, logical(1), x = text, fixed = TRUE))
  if (!valid) {
    .goal006_stop("The Goal006 calibration artifact violates its boundary.")
  }
  invisible(TRUE)
}
