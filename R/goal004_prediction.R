.goal004_pmf_summary <- function(pmf, support_name) {
  valid <- tibble::is_tibble(pmf) &&
    identical(names(pmf), c(support_name, "probability")) &&
    is.numeric(pmf[[support_name]]) &&
    is.numeric(pmf$probability) &&
    !anyNA(pmf) &&
    all(is.finite(as.matrix(pmf))) &&
    all(pmf$probability >= 0) &&
    abs(sum(pmf$probability) - 1) <= 1e-12
  if (!valid) {
    .goal004_flexirich_stop("A Goal004 probability mass function is invalid.")
  }
  cdf <- cumsum(pmf$probability)
  quantile_value <- function(probability) {
    pmf[[support_name]][which(cdf >= probability)[[1L]]]
  }
  tibble::tibble(
    mean = sum(pmf[[support_name]] * pmf$probability),
    lower_90 = quantile_value(0.05),
    median = quantile_value(0.5),
    upper_90 = quantile_value(0.95)
  )
}

#' Summarise Goal004 posterior draws and the matching prior forecast
summarise_goal004_flexirich_draws <- function(
  q_member_draws,
  alpha_draws,
  camera_effect_draws,
  data,
  future_active_days = NULL
) {
  .validate_goal004_flexirich_data(data)
  profile <- goal004_flexirich_profile(data$profile_id)
  posterior <- summarise_goal003_flexirich_draws(
    q_member_draws = q_member_draws,
    alpha_draws = alpha_draws,
    camera_effect_draws = camera_effect_draws,
    candidate_ids = data$candidate_ids,
    camera_ids = data$camera_ids,
    detected_ever = data$detected_ever,
    future_active_days = future_active_days
  )
  prior_richness <- goal004_beta_binomial_pmf(
    candidate_count = length(data$candidate_ids),
    alpha = profile$omega_alpha,
    beta = profile$omega_beta
  )
  posterior_richness <- posterior$richness_pmf
  prior_membership <- profile$omega_alpha /
    (profile$omega_alpha + profile$omega_beta)
  candidate_membership <- tibble::tibble(
    candidate_id = data$candidate_ids,
    encounter_class = data$encounter_class,
    routine_weight = data$routine_weight,
    training_detected = data$detected_ever == 1L,
    prior_membership_probability = as.numeric(prior_membership),
    posterior_membership_probability =
      posterior$grid_identity$membership_probability
  ) |>
    dplyr::mutate(
      membership_probability_movement =
        posterior_membership_probability - prior_membership_probability
    )

  future_pmf <- NULL
  future_identity <- NULL
  if (!is.null(posterior$new_species_count_pmf)) {
    future_pmf <- posterior$new_species_count_pmf |>
      dplyr::rename(
        future_discoveries = new_species_count
      )
    future_identity <- candidate_membership |>
      dplyr::select(
        candidate_id,
        encounter_class,
        training_detected
      ) |>
      dplyr::mutate(
        future_first_detection_probability =
          posterior$future_identity$future_first_detection_probability
      )
  }

  list(
    posterior_richness_pmf = posterior_richness,
    posterior_richness_summary = .goal004_pmf_summary(
      posterior_richness,
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

#' Predict richness and future discoveries from a clean Goal004 fit
predict_goal004_flexirich <- function(result, future_effort = NULL) {
  fit <- .goal004_terminal_flexirich_fit(result)
  data <- result$data
  .validate_goal004_flexirich_data(data)
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
    .goal004_flexirich_stop(
      "The Goal004 fit is missing posterior prediction variables."
    )
  }
  future_active_days <- if (is.null(future_effort)) {
    NULL
  } else {
    .goal003_future_active_days(future_effort, data$camera_ids)
  }
  summarise_goal004_flexirich_draws(
    q_member_draws = as.matrix(draws[, q_names, drop = FALSE]),
    alpha_draws = as.matrix(draws[, alpha_names, drop = FALSE]),
    camera_effect_draws = as.matrix(
      draws[, camera_names, drop = FALSE]
    ),
    data = data,
    future_active_days = future_active_days
  )
}

goal004_total_variation <- function(first, second) {
  valid <- is.numeric(first) &&
    !is.logical(first) &&
    is.numeric(second) &&
    !is.logical(second) &&
    length(first) == length(second) &&
    length(first) > 0L &&
    !anyNA(first) &&
    !anyNA(second) &&
    all(is.finite(first)) &&
    all(is.finite(second)) &&
    all(first >= 0) &&
    all(second >= 0) &&
    abs(sum(first) - 1) <= 1e-10 &&
    abs(sum(second) - 1) <= 1e-10
  if (!valid) {
    .goal004_flexirich_stop(
      "Total-variation inputs must be aligned probability vectors."
    )
  }
  0.5 * sum(abs(first - second))
}
