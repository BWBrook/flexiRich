.goal010_spatial_stop <- function(message) {
  stop(message, call. = FALSE)
}

.goal010_scalar_positive <- function(x, name) {
  valid <- is.numeric(x) &&
    !is.logical(x) &&
    length(x) == 1L &&
    !is.na(x) &&
    is.finite(x) &&
    x > 0
  if (!valid) {
    .goal010_spatial_stop(paste0(name, " must be one finite positive number."))
  }
  as.numeric(x)
}

.goal010_spatial_hash <- function(base_hash, interaction_scale) {
  digest::digest(
    list(
      goal003_data_hash = base_hash,
      interaction_scale = interaction_scale
    ),
    algo = "sha256",
    serialize = TRUE
  )
}

.validate_goal010_spatial_data <- function(data) {
  required <- c(
    "candidate_ids", "camera_ids", "detected_ever", "stan_data",
    "source_data", "prior_id", "interaction_scale", "data_hash"
  )
  source_valid <- if (is.list(data)) {
    tryCatch({
      validate_flexirich_g_data(data$source_data)
      TRUE
    }, error = function(error) FALSE)
  } else {
    FALSE
  }
  prior <- if (source_valid && is.character(data$prior_id) &&
      length(data$prior_id) == 1L && !is.na(data$prior_id)) {
    goal003_flexirich_prior_profiles()[[data$prior_id]]
  } else {
    NULL
  }
  expected_base <- if (!is.null(prior)) {
    tryCatch(
      prepare_goal003_flexirich_data(data$source_data, data$prior_id),
      error = function(error) NULL
    )
  } else {
    NULL
  }
  expected_stan <- if (!is.null(expected_base)) {
    stan <- expected_base$stan_data
    stan$interaction_scale <- data$interaction_scale
    stan
  } else {
    NULL
  }
  expected_hash <- if (!is.null(expected_base)) {
    .goal010_spatial_hash(expected_base$data_hash, data$interaction_scale)
  } else {
    NA_character_
  }
  C <- if (is.list(data)) length(data$candidate_ids) else 0L
  J <- if (is.list(data)) length(data$camera_ids) else 0L
  valid <- source_valid &&
    !is.null(expected_base) &&
    is.list(data) &&
    identical(names(data), required) &&
    is.character(data$candidate_ids) &&
    identical(data$candidate_ids, expected_base$candidate_ids) &&
    is.character(data$camera_ids) &&
    identical(data$camera_ids, expected_base$camera_ids) &&
    is.integer(data$detected_ever) &&
    identical(data$detected_ever, expected_base$detected_ever) &&
    C > 0L &&
    J > 0L &&
    is.numeric(data$interaction_scale) &&
    !is.logical(data$interaction_scale) &&
    length(data$interaction_scale) == 1L &&
    !is.na(data$interaction_scale) &&
    is.finite(data$interaction_scale) &&
    data$interaction_scale > 0 &&
    is.list(data$stan_data) &&
    identical(data$stan_data, expected_stan) &&
    is.character(data$data_hash) &&
    length(data$data_hash) == 1L &&
    grepl("^[0-9a-f]{64}$", data$data_hash) &&
    identical(data$data_hash, expected_hash)
  if (!valid) {
    .goal010_spatial_stop("data must be canonical Goal010 spatial data.")
  }
  invisible(TRUE)
}

#' Return the normalized sum-to-zero basis used by the Goal003 camera effects.
goal010_interaction_basis <- function(J) {
  valid <- is.numeric(J) &&
    !is.logical(J) &&
    length(J) == 1L &&
    !is.na(J) &&
    is.finite(J) &&
    J == trunc(J) &&
    J >= 1
  if (!valid) {
    .goal010_spatial_stop("J must be one positive integer.")
  }
  J <- as.integer(J)
  Q <- .sum_zero_basis(J)
  if (J == 1L) {
    return(Q)
  }
  sqrt(J / (J - 1)) * Q
}

#' Prepare a Goal010 spatial interaction model from canonical Goal003 data.
prepare_goal010_spatial_data <- function(
  data,
  prior_id = "primary",
  interaction_scale = 0.5
) {
  validate_flexirich_g_data(data)
  interaction_scale <- .goal010_scalar_positive(
    interaction_scale,
    "interaction_scale"
  )
  base <- prepare_goal003_flexirich_data(data, prior_id)
  stan_data <- base$stan_data
  stan_data$interaction_scale <- interaction_scale
  result <- list(
    candidate_ids = base$candidate_ids,
    camera_ids = base$camera_ids,
    detected_ever = base$detected_ever,
    stan_data = stan_data,
    source_data = base$source_data,
    prior_id = base$prior_id,
    interaction_scale = interaction_scale,
    data_hash = .goal010_spatial_hash(base$data_hash, interaction_scale)
  )
  .validate_goal010_spatial_data(result)
  result
}

#' R reference likelihood and membership conditionals for Goal010.
goal010_spatial_conditionals <- function(
  data,
  omega,
  alpha,
  camera_effect,
  interaction
) {
  .validate_goal010_spatial_data(data)
  C <- length(data$candidate_ids)
  J <- length(data$camera_ids)
  valid_scalar <- is.numeric(omega) &&
    !is.logical(omega) &&
    length(omega) == 1L &&
    !is.na(omega) &&
    is.finite(omega) &&
    omega > 0 &&
    omega < 1
  valid_alpha <- is.numeric(alpha) &&
    !is.logical(alpha) &&
    length(alpha) == C &&
    !anyNA(alpha) &&
    all(is.finite(alpha))
  valid_camera <- is.numeric(camera_effect) &&
    !is.logical(camera_effect) &&
    length(camera_effect) == J &&
    !anyNA(camera_effect) &&
    all(is.finite(camera_effect)) &&
    abs(sum(camera_effect)) <=
      1e-10 * (1 + sum(abs(camera_effect)))
  valid_interaction <- is.matrix(interaction) &&
    is.numeric(interaction) &&
    !is.logical(interaction) &&
    identical(dim(interaction), c(C, J)) &&
    !anyNA(interaction) &&
    all(is.finite(interaction)) &&
    all(abs(rowSums(interaction)) <=
      1e-10 * (1 + rowSums(abs(interaction))))
  if (!valid_scalar || !valid_alpha || !valid_camera || !valid_interaction) {
    .goal010_spatial_stop(paste0(
      "omega must be in (0, 1), with finite alpha, sum-zero camera ",
      "effects, and a finite row-centered C by J interaction matrix."
    ))
  }

  alpha <- as.numeric(alpha)
  camera_effect <- as.numeric(camera_effect)
  interaction <- unname(interaction)
  grouped <- data$source_data$grouped
  member_ll <- stats::setNames(numeric(C), data$candidate_ids)
  if (nrow(grouped) > 0L) {
    for (g in seq_len(nrow(grouped))) {
      i <- match(grouped$species_id[[g]], data$candidate_ids)
      j <- match(grouped$camera_id[[g]], data$camera_ids)
      log_rate <- alpha[[i]] + camera_effect[[j]] + interaction[i, j]
      active_days <- grouped$active_days[[g]]
      detected <- grouped$n_detected[[g]]
      nondetected <- grouped$n_trials[[g]] - detected
      if (detected > 0L) {
        member_ll[[i]] <- member_ll[[i]] +
          detected * log_detect_probability(log_rate, active_days)
      }
      if (nondetected > 0L) {
        member_ll[[i]] <- member_ll[[i]] +
          nondetected * log_nondetect_probability(log_rate, active_days)
      }
    }
  }
  q_member <- conditional_membership_probability(
    member_ll,
    data$detected_ever,
    as.numeric(omega)
  )
  list(
    member_ll = member_ll,
    q_member = q_member,
    expected_richness = sum(q_member)
  )
}

#' Extract named posterior draws from a Goal010 CmdStan fit.
goal010_extract_draws <- function(fit, data) {
  .validate_goal010_spatial_data(data)
  draws_method <- if (is.list(fit) || is.environment(fit)) {
    tryCatch(fit$draws, error = function(error) NULL)
  } else {
    NULL
  }
  if (!is.function(draws_method)) {
    .goal010_spatial_stop("fit must provide a draws() method.")
  }
  C <- length(data$candidate_ids)
  J <- length(data$camera_ids)
  variables <- c(
    "q_member", "alpha", "camera_effect", "interaction",
    "station_log_rate"
  )
  raw <- tryCatch(draws_method(variables = variables), error = function(error) {
    tryCatch(draws_method(), error = function(error) NULL)
  })
  if (is.null(raw)) {
    .goal010_spatial_stop("fit$draws() could not return Goal010 draws.")
  }
  draws <- if (is.matrix(raw) || is.data.frame(raw)) {
    as.matrix(raw)
  } else {
    tryCatch(
      as.matrix(posterior::as_draws_matrix(raw)),
      error = function(error) {
        .goal010_spatial_stop(
          "fit$draws() must return a named posterior draw matrix."
        )
      }
    )
  }
  if (!is.numeric(draws) || nrow(draws) < 1L ||
      is.null(colnames(draws)) || anyNA(colnames(draws))) {
    .goal010_spatial_stop("Goal010 draws must be a non-empty named matrix.")
  }
  vector_names <- list(
    q_member = sprintf("q_member[%d]", seq_len(C)),
    alpha = sprintf("alpha[%d]", seq_len(C)),
    camera_effect = sprintf("camera_effect[%d]", seq_len(J))
  )
  array_names <- function(prefix) {
    unlist(lapply(seq_len(J), function(j) {
      sprintf("%s[%d,%d]", prefix, seq_len(C), j)
    }), use.names = FALSE)
  }
  required <- c(
    unlist(vector_names, use.names = FALSE),
    array_names("interaction"),
    array_names("station_log_rate")
  )
  missing <- setdiff(required, colnames(draws))
  if (length(missing) > 0L) {
    .goal010_spatial_stop(paste0(
      "Goal010 draws are missing named variables: ",
      paste(missing, collapse = ", "),
      "."
    ))
  }
  extract_vector <- function(names) {
    result <- matrix(as.numeric(draws[, names, drop = FALSE]),
                     nrow = nrow(draws), ncol = length(names))
    if (anyNA(result) || any(!is.finite(result))) {
      .goal010_spatial_stop("Goal010 draws must contain finite values.")
    }
    unname(result)
  }
  extract_array <- function(prefix) {
    result <- array(
      NA_real_,
      dim = c(nrow(draws), C, J)
    )
    for (j in seq_len(J)) {
      for (i in seq_len(C)) {
        name <- sprintf("%s[%d,%d]", prefix, i, j)
        result[, i, j] <- as.numeric(draws[, name])
      }
    }
    if (anyNA(result) || any(!is.finite(result))) {
      .goal010_spatial_stop("Goal010 draws must contain finite values.")
    }
    result
  }
  q_member <- extract_vector(vector_names$q_member)
  if (any(q_member < 0 | q_member > 1)) {
    .goal010_spatial_stop("q_member draws must lie in [0, 1].")
  }
  list(
    q_member = q_member,
    alpha = extract_vector(vector_names$alpha),
    camera_effect = extract_vector(vector_names$camera_effect),
    interaction = extract_array("interaction"),
    station_log_rate = extract_array("station_log_rate"),
    candidate_ids = data$candidate_ids,
    camera_ids = data$camera_ids
  )
}

#' Return the variables required for Goal010 posterior monitoring.
goal010_monitored_variables <- function(data) {
  .validate_goal010_spatial_data(data)
  c(
    "omega", "mu_alpha", "sigma_alpha", "sigma_camera",
    "sigma_interaction", "expected_richness", "alpha", "camera_effect",
    "interaction", "station_log_rate"
  )
}
