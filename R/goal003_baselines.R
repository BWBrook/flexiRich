.goal003_baseline_stop <- function(message) {
  stop(message, call. = FALSE)
}

.goal003_flag <- function(x, name) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    .goal003_baseline_stop(paste0(name, " must be exactly TRUE or FALSE."))
  }
  x
}

.validate_goal003_incidence_sample <- function(sample) {
  required <- c(
    "candidate_ids", "sample_ids", "incidence", "incidence_frequency",
    "n_sampling_units", "observed_richness", "frequency_counts",
    "complete_only"
  )
  if (!is.list(sample) || !identical(names(sample), required)) {
    .goal003_baseline_stop(
      "sample must be a canonical Goal003 incidence sample."
    )
  }
  C <- length(sample$candidate_ids)
  T <- length(sample$sample_ids)
  valid <- is.character(sample$candidate_ids) &&
    length(sample$candidate_ids) > 0L &&
    !anyNA(sample$candidate_ids) &&
    !anyDuplicated(sample$candidate_ids) &&
    is.character(sample$sample_ids) &&
    length(sample$sample_ids) > 0L &&
    !anyNA(sample$sample_ids) &&
    !anyDuplicated(sample$sample_ids) &&
    is.matrix(sample$incidence) &&
    identical(dim(sample$incidence), c(C, T)) &&
    is.integer(sample$incidence) &&
    !anyNA(sample$incidence) &&
    all(sample$incidence %in% c(0L, 1L)) &&
    is.integer(sample$incidence_frequency) &&
    length(sample$incidence_frequency) == C &&
    identical(
      sample$incidence_frequency,
      as.integer(rowSums(sample$incidence))
    ) &&
    identical(sample$n_sampling_units, as.integer(T)) &&
    identical(
      sample$observed_richness,
      as.integer(sum(sample$incidence_frequency > 0L))
    ) &&
    is.integer(sample$frequency_counts) &&
    identical(names(sample$frequency_counts), paste0("Q", 1:4)) &&
    identical(
      unname(sample$frequency_counts),
      vapply(
        1:4,
        function(k) as.integer(sum(sample$incidence_frequency == k)),
        integer(1)
      )
    ) &&
    is.logical(sample$complete_only) &&
    length(sample$complete_only) == 1L &&
    !is.na(sample$complete_only)
  if (!valid) {
    .goal003_baseline_stop(
      "sample must be a canonical Goal003 incidence sample."
    )
  }
  invisible(TRUE)
}

#' Construct the incidence sample used by Goal003 classical baselines
#'
#' @param data A canonical `flexirich_g_data` object.
#' @param complete_only If `FALSE`, retain every positive-effort camera-week.
#'   If `TRUE`, retain only camera-weeks with seven active days.
#'
#' @return A compact list containing the species-by-camera-week incidence
#'   matrix and its first four incidence-frequency counts.
make_goal003_incidence_sample <- function(data, complete_only = FALSE) {
  validate_flexirich_g_data(data)
  complete_only <- .goal003_flag(complete_only, "complete_only")

  first_species <- data$candidate_ids[[1L]]
  units <- data$observed |>
    dplyr::filter(species_id == first_species) |>
    dplyr::filter(if (complete_only) active_days == 7L else active_days > 0L) |>
    dplyr::select(camera_id, occasion_id)
  if (nrow(units) == 0L) {
    .goal003_baseline_stop(
      "The selected incidence sample contains no eligible camera-weeks."
    )
  }

  sampled <- data$observed |>
    dplyr::filter(if (complete_only) active_days == 7L else active_days > 0L)
  incidence <- matrix(
    sampled$detected,
    nrow = length(data$candidate_ids),
    byrow = TRUE,
    dimnames = list(
      data$candidate_ids,
      paste(units$camera_id, units$occasion_id, sep = "::")
    )
  )
  storage.mode(incidence) <- "integer"
  incidence_frequency <- as.integer(rowSums(incidence))
  frequency_counts <- stats::setNames(
    vapply(
      1:4,
      function(k) as.integer(sum(incidence_frequency == k)),
      integer(1)
    ),
    paste0("Q", 1:4)
  )

  result <- list(
    candidate_ids = data$candidate_ids,
    sample_ids = colnames(incidence),
    incidence = incidence,
    incidence_frequency = incidence_frequency,
    n_sampling_units = as.integer(ncol(incidence)),
    observed_richness = as.integer(sum(incidence_frequency > 0L)),
    frequency_counts = frequency_counts,
    complete_only = complete_only
  )
  .validate_goal003_incidence_sample(result)
  result
}

.goal003_chao2 <- function(T, S_obs, Q1, Q2) {
  if (T < 2L) {
    return(NA_real_)
  }
  unseen <- if (Q2 > 0L) {
    Q1^2 / (2 * Q2)
  } else {
    Q1 * (Q1 - 1) / 2
  }
  S_obs + ((T - 1) / T) * unseen
}

.goal003_ichao2 <- function(T, chao2, Q1, Q2, Q3, Q4) {
  if (T < 4L || !is.finite(chao2)) {
    return(NA_real_)
  }
  if (Q4 > 0L) {
    correction <- ((T - 3) / (4 * T)) * (Q3 / Q4) * max(
      Q1 - ((T - 3) / (2 * (T - 1))) * (Q2 * Q3 / Q4),
      0
    )
  } else {
    correction <- ((T - 3) / (4 * T)) * Q3 * max(
      Q1 - ((T - 3) / (2 * (T - 1))) * Q2 * Q3,
      0
    )
  }
  chao2 + correction
}

#' Estimate observed richness, Chao2, and iChao2 from one incidence sample
#'
#' Raw Chao estimates are retained even when they exceed the known candidate
#' pool. The primary estimate is capped at the finite pool size.
#'
#' @param sample Output from `make_goal003_incidence_sample()`.
#'
#' @return A three-row tibble with estimator eligibility and incidence-tail
#'   diagnostics.
estimate_goal003_incidence_richness <- function(sample) {
  .validate_goal003_incidence_sample(sample)
  T <- sample$n_sampling_units
  C <- as.integer(length(sample$candidate_ids))
  S_obs <- sample$observed_richness
  Q <- sample$frequency_counts
  chao2 <- .goal003_chao2(T, S_obs, Q[["Q1"]], Q[["Q2"]])
  ichao2 <- .goal003_ichao2(
    T,
    chao2,
    Q[["Q1"]],
    Q[["Q2"]],
    Q[["Q3"]],
    Q[["Q4"]]
  )
  raw <- c(as.numeric(S_obs), chao2, ichao2)
  eligible <- is.finite(raw)

  tibble::tibble(
    method = c("observed", "chao2", "ichao2"),
    eligible = eligible,
    reason = c(
      NA_character_,
      if (T < 2L) "requires at least two sampling units" else NA_character_,
      if (T < 4L) "requires at least four sampling units" else NA_character_
    ),
    raw_estimate = raw,
    estimate = ifelse(eligible, pmin(raw, C), NA_real_),
    exceeded_pool = ifelse(eligible, raw > C, NA),
    candidate_pool_size = C,
    observed_richness = S_obs,
    n_sampling_units = T,
    Q1 = unname(Q[["Q1"]]),
    Q2 = unname(Q[["Q2"]]),
    Q3 = unname(Q[["Q3"]]),
    Q4 = unname(Q[["Q4"]]),
    complete_only = sample$complete_only
  )
}

#' Return the observed-richness point-mass PMF
#'
#' @param sample Output from `make_goal003_incidence_sample()`.
#'
#' @return A richness PMF over the exact finite support `0:C`.
goal003_observed_richness_pmf <- function(sample) {
  .validate_goal003_incidence_sample(sample)
  C <- length(sample$candidate_ids)
  probability <- numeric(C + 1L)
  probability[sample$observed_richness + 1L] <- 1
  tibble::tibble(
    richness = seq.int(0L, C),
    probability = probability
  )
}

#' Return the observed-richness prospective null forecast
#'
#' The observed baseline asserts saturation: zero future discoveries and zero
#' future-first-detection probability for every training-unseen candidate.
#'
#' @param sample Output from `make_goal003_incidence_sample()`.
#'
#' @return A point-mass new-species-count PMF and candidate probabilities.
predict_goal003_observed_new_species <- function(sample) {
  .validate_goal003_incidence_sample(sample)
  unseen_capacity <- length(sample$candidate_ids) - sample$observed_richness
  probability <- numeric(unseen_capacity + 1L)
  probability[[1L]] <- 1
  list(
    new_species_count_pmf = tibble::tibble(
      new_species_count = seq.int(0L, unseen_capacity),
      probability = probability
    ),
    future_identity = tibble::tibble(
      species_id = sample$candidate_ids,
      training_detected = sample$incidence_frequency > 0L,
      future_first_detection_probability = 0
    )
  )
}

#' Return the frozen Goal003 lower-bound-conditioned prior
#'
#' @param sample Output from `make_goal003_incidence_sample()`.
#'
#' @return The exact beta-binomial total-richness PMF over `0:C`.
goal003_lower_bound_prior_pmf <- function(sample) {
  .validate_goal003_incidence_sample(sample)
  lower_bound_prior_pmf(
    candidate_pool_size = length(sample$candidate_ids),
    observed_richness = sample$observed_richness,
    omega_alpha = 1,
    omega_beta = 1
  )
}

.goal003_check_inext <- function() {
  if (!requireNamespace("iNEXT", quietly = TRUE)) {
    .goal003_baseline_stop(
      "iNEXT 3.0.2 is required; restore the project renv library."
    )
  }
  version <- as.character(utils::packageVersion("iNEXT"))
  if (!identical(version, "3.0.2")) {
    .goal003_baseline_stop(paste0(
      "Goal003 requires iNEXT 3.0.2; installed version is ",
      version,
      "."
    ))
  }
  invisible(version)
}

.goal003_inext_table <- function(table, basis, candidate_pool_size) {
  required <- c("t", "Method", "Order.q", "qD")
  if (!is.data.frame(table) || any(!required %in% names(table))) {
    .goal003_baseline_stop(
      "iNEXT returned an unexpected curve schema."
    )
  }
  coverage <- if ("SC" %in% names(table)) table$SC else rep(NA_real_, nrow(table))
  result <- tibble::tibble(
    basis = basis,
    sample_size = as.integer(table$t),
    coverage = as.numeric(coverage),
    method = tolower(as.character(table$Method)),
    raw_estimate = as.numeric(table$qD),
    estimate = pmin(as.numeric(table$qD), candidate_pool_size),
    exceeded_pool = as.numeric(table$qD) > candidate_pool_size
  )
  if (anyNA(result$sample_size) ||
      any(result$sample_size < 1L) ||
      anyNA(result$coverage) ||
      any(!is.finite(result$coverage)) ||
      any(result$coverage < 0 | result$coverage > 1) ||
      anyNA(result$raw_estimate) ||
      any(!is.finite(result$raw_estimate))) {
    .goal003_baseline_stop(
      "iNEXT returned non-finite or out-of-range curve values."
    )
  }
  result
}

#' Compute the frozen Goal003 incidence accumulation and coverage curves
#'
#' @param sample Output from `make_goal003_incidence_sample()`.
#' @param endpoint Largest sample size. It must be between the observed sample
#'   size and twice that size.
#'
#' @return A list containing normalized size- and coverage-based curves and
#'   the q=0 asymptotic estimate returned by iNEXT.
estimate_goal003_inext_curve <- function(sample, endpoint = NULL) {
  .validate_goal003_incidence_sample(sample)
  .goal003_check_inext()
  T <- sample$n_sampling_units
  if (sample$observed_richness == 0L) {
    .goal003_baseline_stop(
      "iNEXT requires at least one species detected in the incidence sample."
    )
  }
  if (is.null(endpoint)) {
    endpoint <- 2L * T
  }
  valid_endpoint <- is.numeric(endpoint) &&
    !is.logical(endpoint) &&
    length(endpoint) == 1L &&
    !is.na(endpoint) &&
    is.finite(endpoint) &&
    endpoint == trunc(endpoint) &&
    endpoint >= T &&
    endpoint <= 2L * T
  if (!valid_endpoint) {
    .goal003_baseline_stop(
      "endpoint must be one whole number from T through 2T."
    )
  }
  endpoint <- as.integer(endpoint)
  observed <- sample$incidence[
    sample$incidence_frequency > 0L,
    ,
    drop = FALSE
  ]
  fit <- iNEXT::iNEXT(
    list(Goal003 = observed),
    q = 0,
    datatype = "incidence_raw",
    size = seq_len(endpoint),
    se = FALSE
  )
  C <- length(sample$candidate_ids)
  size_based <- .goal003_inext_table(
    fit$iNextEst$size_based,
    "sample_size",
    C
  )
  coverage_based <- .goal003_inext_table(
    fit$iNextEst$coverage_based,
    "coverage",
    C
  ) |>
    dplyr::arrange(coverage, sample_size)
  asymptotic_row <- fit$AsyEst[
    fit$AsyEst$Diversity == "Species richness",
    ,
    drop = FALSE
  ]
  if (nrow(asymptotic_row) != 1L ||
      !is.finite(asymptotic_row$Estimator[[1L]])) {
    .goal003_baseline_stop(
      "iNEXT did not return one finite asymptotic species-richness estimate."
    )
  }
  raw_asymptotic <- as.numeric(asymptotic_row$Estimator[[1L]])

  list(
    curve = dplyr::bind_rows(size_based, coverage_based),
    asymptotic = tibble::tibble(
      raw_estimate = raw_asymptotic,
      estimate = min(raw_asymptotic, C),
      exceeded_pool = raw_asymptotic > C
    ),
    metadata = list(
      package = "iNEXT",
      version = "3.0.2",
      order_q = 0,
      datatype = "incidence_raw",
      n_sampling_units = T,
      endpoint = endpoint,
      candidate_pool_size = as.integer(C)
    )
  )
}

#' Predict expected new detections from the Goal003 iNEXT curve
#'
#' @param sample Output from `make_goal003_incidence_sample()`.
#' @param future_sampling_units Number of positive-effort camera-weeks in the
#'   realised forecast block.
#'
#' @return A one-row eligibility and expected-discovery summary. No PMF or
#'   identity probabilities are implied.
predict_goal003_inext_new_species <- function(sample, future_sampling_units) {
  .validate_goal003_incidence_sample(sample)
  valid_future <- is.numeric(future_sampling_units) &&
    !is.logical(future_sampling_units) &&
    length(future_sampling_units) == 1L &&
    !is.na(future_sampling_units) &&
    is.finite(future_sampling_units) &&
    future_sampling_units == trunc(future_sampling_units) &&
    future_sampling_units >= 0
  if (!valid_future) {
    .goal003_baseline_stop(
      "future_sampling_units must be one non-negative whole number."
    )
  }
  future_sampling_units <- as.integer(future_sampling_units)
  target <- sample$n_sampling_units + future_sampling_units
  eligible <- sample$observed_richness > 0L &&
    target <= 2L * sample$n_sampling_units
  if (!eligible) {
    reason <- if (sample$observed_richness == 0L) {
      "requires at least one observed species"
    } else {
      "target exceeds twice the training sample size"
    }
    return(tibble::tibble(
      eligible = FALSE,
      reason = reason,
      training_sampling_units = sample$n_sampling_units,
      future_sampling_units = future_sampling_units,
      target_sampling_units = target,
      expected_new_species = NA_real_
    ))
  }
  if (future_sampling_units == 0L) {
    expected_new <- 0
  } else {
    result <- estimate_goal003_inext_curve(sample, endpoint = target)
    target_row <- result$curve |>
      dplyr::filter(
        basis == "sample_size",
        sample_size == target
      )
    if (nrow(target_row) != 1L) {
      .goal003_baseline_stop(
        "iNEXT did not return the requested prospective sample size."
      )
    }
    expected_new <- max(
      target_row$estimate[[1L]] - sample$observed_richness,
      0
    )
  }
  tibble::tibble(
    eligible = TRUE,
    reason = NA_character_,
    training_sampling_units = sample$n_sampling_units,
    future_sampling_units = future_sampling_units,
    target_sampling_units = target,
    expected_new_species = expected_new
  )
}
