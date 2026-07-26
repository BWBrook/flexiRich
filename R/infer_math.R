.stop_invalid_infer_math <- function(message) {
  stop(message, call. = FALSE)
}

.validate_math_numeric <- function(
  x,
  name,
  expected_length = NULL,
  allow_negative_infinity = FALSE
) {
  valid_type <- is.numeric(x) &&
    !is.complex(x) &&
    !is.logical(x)
  valid_values <- valid_type &&
    !anyNA(x) &&
    !any(is.nan(x)) &&
    !any(x == Inf) &&
    (allow_negative_infinity || all(is.finite(x)))
  valid_length <- is.null(expected_length) ||
    length(x) == expected_length

  if (!valid_type || !valid_values) {
    allowed <- if (allow_negative_infinity) {
      "finite numeric values or -Inf"
    } else {
      "finite numeric values"
    }
    .stop_invalid_infer_math(paste0(name, " must contain ", allowed, "."))
  }
  if (!valid_length) {
    .stop_invalid_infer_math(paste0(
      name,
      " must have length ",
      expected_length,
      "."
    ))
  }

  as.numeric(x)
}

.validate_hazard_inputs <- function(log_rate, active_days) {
  log_rate <- .validate_math_numeric(log_rate, "log_rate")
  valid_effort_type <- is.numeric(active_days) &&
    !is.complex(active_days) &&
    !is.logical(active_days)
  valid_effort <- valid_effort_type &&
    !anyNA(active_days) &&
    all(is.finite(active_days)) &&
    all(active_days == trunc(active_days)) &&
    all(active_days >= 0)

  if (!valid_effort_type ||
      anyNA(active_days) ||
      any(!is.finite(active_days))) {
    .stop_invalid_infer_math(
      "active_days must contain finite, non-negative whole numbers."
    )
  }
  if (any(active_days != trunc(active_days))) {
    .stop_invalid_infer_math(
      "active_days must contain whole numbers."
    )
  }
  if (any(active_days < 0)) {
    .stop_invalid_infer_math(
      "active_days must contain non-negative values."
    )
  }
  if (!valid_effort) {
    .stop_invalid_infer_math(
      "active_days must contain finite, non-negative whole numbers."
    )
  }

  n_rate <- length(log_rate)
  n_effort <- length(active_days)
  conformable <- n_rate == n_effort ||
    (n_rate == 1L && n_effort > 0L) ||
    (n_effort == 1L && n_rate > 0L)
  if (!conformable) {
    .stop_invalid_infer_math(paste0(
      "log_rate and active_days lengths must match, unless one ",
      "input is scalar."
    ))
  }

  result_length <- max(n_rate, n_effort)
  list(
    log_rate = rep(log_rate, length.out = result_length),
    active_days = rep(as.numeric(active_days), length.out = result_length)
  )
}

log_detect_probability <- function(log_rate, active_days) {
  inputs <- .validate_hazard_inputs(log_rate, active_days)
  result <- rep(-Inf, length(inputs$log_rate))
  sampled <- inputs$active_days > 0
  if (!any(sampled)) {
    return(result)
  }

  log_hazard <- log(inputs$active_days[sampled]) +
    inputs$log_rate[sampled]
  sampled_result <- numeric(length(log_hazard))
  underflow <- log_hazard < log(.Machine$double.xmin)
  overflow <- log_hazard > log(.Machine$double.xmax)
  regular <- !(underflow | overflow)

  sampled_result[underflow] <- log_hazard[underflow]
  sampled_result[overflow] <- 0
  if (any(regular)) {
    hazard <- exp(log_hazard[regular])
    sampled_result[regular] <- log(-expm1(-hazard))
  }
  result[sampled] <- sampled_result
  result
}

log_nondetect_probability <- function(log_rate, active_days) {
  inputs <- .validate_hazard_inputs(log_rate, active_days)
  result <- numeric(length(inputs$log_rate))
  sampled <- inputs$active_days > 0
  if (!any(sampled)) {
    return(result)
  }

  log_hazard <- log(inputs$active_days[sampled]) +
    inputs$log_rate[sampled]
  sampled_result <- numeric(length(log_hazard))
  overflow <- log_hazard > log(.Machine$double.xmax)
  sampled_result[overflow] <- -Inf
  sampled_result[!overflow] <- -exp(log_hazard[!overflow])
  result[sampled] <- sampled_result
  result
}

.member_log_likelihood_grouped <- function(
  grouped,
  candidate_ids,
  camera_ids,
  alpha,
  camera_effect
) {
  if (nrow(grouped) == 0L) {
    return(stats::setNames(numeric(length(candidate_ids)), candidate_ids))
  }

  canonical_order <- order(
    match(grouped$species_id, candidate_ids),
    match(grouped$camera_id, camera_ids),
    grouped$active_days,
    grouped$n_trials,
    grouped$n_detected,
    method = "radix"
  )
  grouped <- grouped[canonical_order, , drop = FALSE]
  species_index <- match(grouped$species_id, candidate_ids)
  camera_index <- match(grouped$camera_id, camera_ids)
  linear_predictor <- alpha[species_index] +
    camera_effect[camera_index]
  log_detect <- log_detect_probability(
    linear_predictor,
    grouped$active_days
  )
  log_nondetect <- log_nondetect_probability(
    linear_predictor,
    grouped$active_days
  )

  contribution <- numeric(nrow(grouped))
  detected <- grouped$n_detected > 0L
  nondetected <- grouped$n_trials > grouped$n_detected
  contribution[detected] <- grouped$n_detected[detected] *
    log_detect[detected]
  contribution[nondetected] <- contribution[nondetected] +
    (grouped$n_trials[nondetected] -
      grouped$n_detected[nondetected]) *
    log_nondetect[nondetected]

  result <- stats::setNames(numeric(length(candidate_ids)), candidate_ids)
  summed <- rowsum(
    contribution,
    group = grouped$species_id,
    reorder = FALSE
  )
  result[match(rownames(summed), candidate_ids)] <- summed[, 1L]
  result
}

member_log_likelihood <- function(data, alpha, camera_effect) {
  validate_flexirich_g_data(data)
  alpha <- .validate_math_numeric(
    alpha,
    "alpha",
    expected_length = data$stan_data$C
  )
  camera_effect <- .validate_math_numeric(
    camera_effect,
    "camera_effect",
    expected_length = data$stan_data$J
  )

  .member_log_likelihood_grouped(
    data$grouped,
    data$candidate_ids,
    data$camera_ids,
    alpha,
    camera_effect
  )
}

.validate_membership_inputs <- function(
  member_ll,
  detected_ever,
  omega
) {
  member_names <- names(member_ll)
  member_ll <- .validate_math_numeric(
    member_ll,
    "member_ll",
    allow_negative_infinity = TRUE
  )
  if (length(detected_ever) != length(member_ll)) {
    .stop_invalid_infer_math(
      "member_ll and detected_ever must have the same length."
    )
  }
  valid_detected_type <- (is.numeric(detected_ever) &&
    !is.complex(detected_ever)) ||
    is.logical(detected_ever)
  valid_detected <- valid_detected_type &&
    !anyNA(detected_ever) &&
    all(detected_ever %in% c(0, 1))
  if (!valid_detected) {
    .stop_invalid_infer_math(
      "detected_ever must contain binary 0/1 values."
    )
  }
  valid_omega <- is.numeric(omega) &&
    !is.complex(omega) &&
    !is.logical(omega) &&
    length(omega) == 1L &&
    !is.na(omega) &&
    is.finite(omega) &&
    omega >= 0 &&
    omega <= 1
  if (!valid_omega) {
    .stop_invalid_infer_math(
      "omega must be one finite numeric value in [0, 1]."
    )
  }

  list(
    member_ll = stats::setNames(member_ll, member_names),
    detected_ever = as.integer(detected_ever),
    omega = as.numeric(omega)
  )
}

.log_add_exp_pair <- function(x, y) {
  if (x == -Inf) {
    return(y)
  }
  if (y == -Inf) {
    return(x)
  }
  anchor <- max(x, y)
  anchor + log(exp(x - anchor) + exp(y - anchor))
}

marginal_membership_log_likelihood <- function(
  member_ll,
  detected_ever,
  omega
) {
  inputs <- .validate_membership_inputs(
    member_ll,
    detected_ever,
    omega
  )
  detected <- inputs$detected_ever == 1L

  if (inputs$omega == 0) {
    if (any(detected)) {
      return(-Inf)
    }
    return(0)
  }
  if (inputs$omega == 1) {
    return(sum(inputs$member_ll))
  }

  detected_term <- sum(
    log(inputs$omega) + inputs$member_ll[detected]
  )
  zero_term <- vapply(
    inputs$member_ll[!detected],
    function(ell) {
      .log_add_exp_pair(
        log1p(-inputs$omega),
        log(inputs$omega) + ell
      )
    },
    numeric(1)
  )
  detected_term + sum(zero_term)
}

conditional_membership_probability <- function(
  member_ll,
  detected_ever,
  omega
) {
  inputs <- .validate_membership_inputs(
    member_ll,
    detected_ever,
    omega
  )
  detected <- inputs$detected_ever == 1L
  result <- numeric(length(inputs$member_ll))

  if (inputs$omega == 1) {
    result[] <- 1
  } else if (inputs$omega > 0) {
    result <- stats::plogis(
      stats::qlogis(inputs$omega) + inputs$member_ll
    )
  }
  result[detected] <- 1
  stats::setNames(result, names(inputs$member_ll))
}

poisson_binomial_pmf <- function(probabilities) {
  valid <- is.numeric(probabilities) &&
    !is.complex(probabilities) &&
    !is.logical(probabilities) &&
    !anyNA(probabilities) &&
    all(is.finite(probabilities)) &&
    all(probabilities >= 0 & probabilities <= 1)
  if (!valid) {
    .stop_invalid_infer_math(
      "probabilities must be finite values in [0, 1]."
    )
  }

  probabilities <- as.numeric(probabilities)
  pmf <- 1
  for (probability in probabilities) {
    pmf <- c(pmf * (1 - probability), 0) +
      c(0, pmf * probability)
  }
  total <- sum(pmf)
  if (!is.finite(total) || total <= 0) {
    .stop_invalid_infer_math(
      "Poisson-binomial recurrence did not produce a finite PMF."
    )
  }
  pmf <- pmf / total
  stats::setNames(pmf, as.character(0:length(probabilities)))
}
