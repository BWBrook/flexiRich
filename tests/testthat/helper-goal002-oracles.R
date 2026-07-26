goal002_oracle_fixture <- function(C = 4L) {
  if (!is.numeric(C) ||
      length(C) != 1L ||
      is.na(C) ||
      !is.finite(C) ||
      C != trunc(C) ||
      C < 1L ||
      C > 4L) {
    stop("C must be one whole number in [1, 4].", call. = FALSE)
  }
  C <- as.integer(C)

  candidate_pool <- tibble::tibble(
    species_id = sprintf("sp_%02d", seq_len(C))
  )
  effort_weekly <- tibble::tribble(
    ~camera_id, ~occasion_id, ~active_days,
    "cam_01", "occ_01", 1L,
    "cam_01", "occ_02", 3L,
    "cam_01", "occ_03", 0L,
    "cam_02", "occ_01", 2L,
    "cam_02", "occ_02", 7L,
    "cam_02", "occ_03", 4L
  )
  detections <- tidyr::crossing(
    species_id = candidate_pool$species_id,
    camera_id = unique(effort_weekly$camera_id),
    occasion_id = unique(effort_weekly$occasion_id)
  ) |>
    dplyr::left_join(
      effort_weekly,
      by = c("camera_id", "occasion_id")
    ) |>
    dplyr::mutate(
      detected = dplyr::case_when(
        active_days == 0L ~ NA_integer_,
        species_id == "sp_01" &
          camera_id == "cam_01" &
          occasion_id == "occ_01" ~ 1L,
        C >= 2L &
          species_id == "sp_02" &
          camera_id == "cam_02" &
          occasion_id == "occ_02" ~ 1L,
        .default = 0L
      )
    ) |>
    dplyr::select(
      species_id,
      camera_id,
      occasion_id,
      detected
    )

  data <- prepare_flexirich_g_data(
    candidate_pool,
    effort_weekly,
    detections
  )
  alpha_values <- log(c(0.03, 0.009, 0.001, 0.0002))

  list(
    data = data,
    alpha = stats::setNames(
      alpha_values[seq_len(C)],
      data$candidate_ids
    ),
    camera_effect = stats::setNames(
      c(-0.2, 0.2),
      data$camera_ids
    ),
    detected_ever = data$stan_data$detected_ever,
    inputs = list(
      candidate_pool = candidate_pool,
      effort_weekly = effort_weekly,
      detections = detections
    )
  )
}

oracle_rowwise_member_log_likelihood <- function(
  observed,
  alpha,
  camera_effect,
  candidate_ids,
  camera_ids
) {
  sampled <- observed[observed$active_days > 0L, , drop = FALSE]
  result <- stats::setNames(numeric(length(candidate_ids)), candidate_ids)

  for (species_position in seq_along(candidate_ids)) {
    species_rows <- sampled$species_id == candidate_ids[species_position]
    species_data <- sampled[species_rows, , drop = FALSE]
    contribution <- numeric(nrow(species_data))

    for (row in seq_len(nrow(species_data))) {
      camera_position <- match(
        species_data$camera_id[row],
        camera_ids
      )
      linear_predictor <- alpha[species_position] +
        camera_effect[camera_position]
      hazard <- species_data$active_days[row] *
        exp(linear_predictor)

      if (species_data$detected[row] == 1L) {
        contribution[row] <- log1p(-exp(-hazard))
      } else {
        contribution[row] <- -hazard
      }
    }
    result[species_position] <- sum(contribution)
  }

  result
}

oracle_membership_configuration_log_weights <- function(
  member_ll,
  detected_ever,
  omega
) {
  C <- length(member_ll)
  configurations <- expand.grid(
    rep(list(c(0L, 1L)), C),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  configurations[] <- lapply(configurations, as.integer)
  names(configurations) <- paste0("member_", seq_len(C))

  log_weight <- numeric(nrow(configurations))
  for (row in seq_len(nrow(configurations))) {
    membership <- as.integer(configurations[row, , drop = TRUE])
    if (any(detected_ever == 1L & membership == 0L)) {
      log_weight[row] <- -Inf
      next
    }

    membership_log_prior <- sum(stats::dbinom(
      membership,
      size = 1L,
      prob = omega,
      log = TRUE
    ))
    observation_log_likelihood <- if (any(membership == 1L)) {
      sum(member_ll[membership == 1L])
    } else {
      0
    }
    log_weight[row] <- membership_log_prior +
      observation_log_likelihood
  }

  list(
    configurations = configurations,
    log_weight = log_weight
  )
}

oracle_log_sum_exp <- function(log_weight) {
  finite_weights <- log_weight[is.finite(log_weight)]
  if (length(finite_weights) == 0L) {
    return(-Inf)
  }
  anchor <- max(finite_weights)
  anchor + log(sum(exp(finite_weights - anchor)))
}

oracle_enumerated_membership_log_likelihood <- function(
  member_ll,
  detected_ever,
  omega
) {
  enumeration <- oracle_membership_configuration_log_weights(
    member_ll,
    detected_ever,
    omega
  )
  oracle_log_sum_exp(enumeration$log_weight)
}

oracle_enumerated_membership_probability <- function(
  member_ll,
  detected_ever,
  omega
) {
  enumeration <- oracle_membership_configuration_log_weights(
    member_ll,
    detected_ever,
    omega
  )
  denominator <- oracle_log_sum_exp(enumeration$log_weight)
  result <- numeric(length(member_ll))

  for (species_position in seq_along(member_ll)) {
    is_member <- enumeration$configurations[[species_position]] == 1L
    numerator <- oracle_log_sum_exp(
      enumeration$log_weight[is_member]
    )
    result[species_position] <- exp(numerator - denominator)
  }

  stats::setNames(result, names(member_ll))
}
