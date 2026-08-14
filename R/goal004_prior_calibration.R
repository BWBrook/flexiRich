.goal004_task2_core_calibration <- function(
  profiles,
  candidates,
  effort,
  base
) {
  core_columns <- seq_len(nrow(candidates))
  richness_pmf <- lapply(seq_len(nrow(profiles)), function(index) {
    profile <- profiles[index, ]
    goal004_beta_binomial_pmf(
      nrow(candidates),
      profile$omega_alpha,
      profile$omega_beta
    ) |>
      dplyr::mutate(
        profile_id = profile$profile_id,
        role = profile$role,
        .before = 1L
      )
  }) |>
    dplyr::bind_rows()
  candidate_membership <- tidyr::crossing(
    profiles |>
      dplyr::select(profile_id, role, omega_alpha, omega_beta),
    candidates
  ) |>
    dplyr::mutate(
      prior_membership_probability = omega_alpha / (omega_alpha + omega_beta)
    )

  summaries <- list()
  pmfs <- list()
  candidate_predictions <- list()
  primary_predictions <- list()
  bounds <- numeric()
  output_index <- 0L
  for (profile_index in seq_len(nrow(profiles))) {
    profile <- profiles[profile_index, ]
    omega <- stats::qbeta(
      base$omega_uniform,
      profile$omega_alpha,
      profile$omega_beta
    )
    membership <- base$membership_uniform[, core_columns, drop = FALSE] < omega
    rate <- .goal004_task2_rate_draws(
      candidates,
      profile,
      base,
      core_columns
    )
    camera_effect <- .goal004_task2_camera_effect(
      base,
      profile$camera_sd_scale
    )
    for (window_index in seq_len(nrow(effort$summary))) {
      window_id <- effort$summary$window_id[[window_index]]
      window <- effort$cells |>
        dplyr::filter(window_id == .env$window_id)
      uniforms <- .goal004_task2_detection_uniforms(base, window_index)
      prediction <- .goal004_task2_window_prediction(
        membership = membership,
        membership_probability = omega,
        rate = rate,
        camera_effect = camera_effect,
        effort = window,
        uniforms = lapply(
          uniforms,
          function(value) value[, core_columns, drop = FALSE]
        )
      )
      tables <- .goal004_task2_prediction_tables(
        prediction = prediction,
        profile = profile,
        candidates = candidates,
        window = window,
        pool = "primary_50",
        component = "core"
      )
      output_index <- output_index + 1L
      summaries[[output_index]] <- tables$summary
      pmfs[[output_index]] <- tables$pmf
      candidate_predictions[[output_index]] <- tables$candidate
      bounds <- c(
        bounds,
        prediction$observed_richness - prediction$realised_richness,
        prediction$future_discoveries -
          (prediction$realised_richness - prediction$observed_richness)
      )
      if (identical(profile$profile_id, "primary")) {
        primary_predictions[[window_id]] <- prediction
      }
    }
  }
  list(
    richness_pmf = richness_pmf,
    candidate_membership = candidate_membership,
    predictive_summary = dplyr::bind_rows(summaries),
    predictive_pmf = dplyr::bind_rows(pmfs),
    candidate_prediction = dplyr::bind_rows(candidate_predictions),
    primary_predictions = primary_predictions,
    bounds = bounds
  )
}

.goal004_task2_total_prediction_tables <- function(prediction, window) {
  summary <- lapply(names(prediction), function(outcome) {
    .goal004_task2_distribution_summary(prediction[[outcome]]) |>
      dplyr::mutate(outcome = outcome, .before = 1L)
  }) |>
    dplyr::bind_rows() |>
    dplyr::mutate(
      profile_id = "broader_106",
      role = "pool_sensitivity",
      pool = "broader_106",
      component = "total",
      window_id = window$window_id[[1L]],
      train_occasions = window$train_occasions[[1L]],
      effort_label = window$effort_label[[1L]],
      training_active_camera_days = sum(window$active_days_training),
      future_active_camera_days = sum(window$active_days_future),
      .before = 1L
    )
  pmf <- lapply(names(prediction), function(outcome) {
    .goal004_task2_empirical_pmf(prediction[[outcome]], upper = 106L) |>
      dplyr::mutate(outcome = outcome, .before = 1L)
  }) |>
    dplyr::bind_rows() |>
    dplyr::mutate(
      profile_id = "broader_106",
      pool = "broader_106",
      component = "total",
      window_id = window$window_id[[1L]],
      .before = 1L
    )
  list(summary = summary, pmf = pmf)
}

.goal004_task2_broader_calibration <- function(
  primary_profile,
  candidates,
  effort,
  base,
  primary_predictions
) {
  fringe_columns <- nrow(candidates$core) + seq_len(nrow(candidates$fringe))
  fringe_prior <- goal004_task2_fringe_prior()
  fringe_expected_richness <- .goal004_task2_truncated_exponential(
    base$fringe_uniform,
    upper = nrow(candidates$fringe),
    scale = fringe_prior$membership_expected_count_scale
  )
  fringe_probability <- fringe_expected_richness / nrow(candidates$fringe)
  fringe_membership <-
    base$membership_uniform[, fringe_columns, drop = FALSE] < fringe_probability
  fringe_rate <- .goal004_task2_fringe_rate_draws(
    candidates$fringe,
    base,
    fringe_columns
  )
  camera_effect <- .goal004_task2_camera_effect(
    base,
    primary_profile$camera_sd_scale
  )
  core_richness <- primary_predictions[[1L]]$realised_richness
  fringe_richness <- as.integer(rowSums(fringe_membership))
  richness <- .goal004_task2_richness_tables(
    draws = list(
      core = core_richness,
      fringe = fringe_richness,
      total = core_richness + fringe_richness
    ),
    profile_id = "broader_106",
    role = "pool_sensitivity",
    pool = "broader_106"
  )

  summaries <- list()
  pmfs <- list()
  candidate_predictions <- list()
  bounds <- numeric()
  output_index <- 0L
  candidate_index <- 0L
  table_profile <- primary_profile
  table_profile$profile_id <- "broader_106"
  table_profile$role <- "pool_sensitivity"
  for (window_index in seq_len(nrow(effort$summary))) {
    window_id <- effort$summary$window_id[[window_index]]
    window <- effort$cells |>
      dplyr::filter(window_id == .env$window_id)
    uniforms <- .goal004_task2_detection_uniforms(base, window_index)
    fringe <- .goal004_task2_window_prediction(
      membership = fringe_membership,
      membership_probability = fringe_probability,
      rate = fringe_rate,
      camera_effect = camera_effect,
      effort = window,
      uniforms = lapply(
        uniforms,
        function(value) value[, fringe_columns, drop = FALSE]
      )
    )
    core <- primary_predictions[[window_id]]
    total <- list(
      observed_richness = core$observed_richness + fringe$observed_richness,
      future_discoveries =
        core$future_discoveries + fringe$future_discoveries
    )
    bounds <- c(
      bounds,
      total$observed_richness -
        (core$realised_richness + fringe$realised_richness),
      total$future_discoveries -
        (core$realised_richness + fringe$realised_richness -
          total$observed_richness)
    )

    for (component in c("core", "fringe")) {
      prediction <- if (component == "core") core else fringe
      mapping <- if (component == "core") candidates$core else candidates$fringe
      tables <- .goal004_task2_prediction_tables(
        prediction = prediction,
        profile = table_profile,
        candidates = mapping,
        window = window,
        pool = "broader_106",
        component = component
      )
      output_index <- output_index + 1L
      candidate_index <- candidate_index + 1L
      summaries[[output_index]] <- tables$summary
      pmfs[[output_index]] <- tables$pmf
      candidate_predictions[[candidate_index]] <- tables$candidate
    }
    total_tables <- .goal004_task2_total_prediction_tables(total, window)
    output_index <- output_index + 1L
    summaries[[output_index]] <- total_tables$summary
    pmfs[[output_index]] <- total_tables$pmf
  }
  list(
    richness_summary = richness$summary,
    richness_pmf = richness$pmf,
    predictive_summary = dplyr::bind_rows(summaries),
    predictive_pmf = dplyr::bind_rows(pmfs),
    candidate_prediction = dplyr::bind_rows(candidate_predictions),
    bounds = bounds
  )
}

.goal004_task2_invariants <- function(
  profiles,
  candidates,
  effort,
  core,
  broader
) {
  pmf_sums <- c(
    core$richness_pmf |>
      dplyr::summarise(value = sum(probability), .by = profile_id) |>
      dplyr::pull(value),
    core$predictive_pmf |>
      dplyr::summarise(
        value = sum(probability),
        .by = c(profile_id, window_id, outcome)
      ) |>
      dplyr::pull(value),
    broader$richness_pmf |>
      dplyr::summarise(value = sum(probability), .by = component) |>
      dplyr::pull(value),
    broader$predictive_pmf |>
      dplyr::summarise(
        value = sum(probability),
        .by = c(component, window_id, outcome)
      ) |>
      dplyr::pull(value)
  )
  exact_primary <- core$richness_pmf |>
    dplyr::filter(profile_id == "primary")
  exact_mean <- sum(exact_primary$richness * exact_primary$probability)
  exact_sd <- sqrt(sum(
    (exact_primary$richness - exact_mean)^2 * exact_primary$probability
  ))
  core_richness <- core$primary_predictions[[1L]]$realised_richness
  richness_z <- abs(mean(core_richness) - exact_mean) /
    (exact_sd / sqrt(length(core_richness)))

  primary_candidate <- core$candidate_prediction |>
    dplyr::filter(profile_id == "primary") |>
    dplyr::arrange(window_id, candidate_id)
  broader_core_candidate <- broader$candidate_prediction |>
    dplyr::filter(pool_component == "core") |>
    dplyr::arrange(window_id, candidate_id)
  probability_fields <- c(
    "training_detection_probability",
    "future_first_detection_probability",
    "member_training_detection_probability",
    "member_future_first_detection_probability"
  )
  broad_core_difference <- max(abs(
    as.matrix(primary_candidate[probability_fields]) -
      as.matrix(broader_core_candidate[probability_fields])
  ))
  profile_means <- core$predictive_summary |>
    dplyr::filter(outcome == "observed_richness") |>
    dplyr::select(profile_id, window_id, mean) |>
    tidyr::pivot_wider(names_from = profile_id, values_from = mean)
  rate_ordered <- all(
    profile_means$rate_lower <= profile_means$primary &
      profile_means$primary <= profile_means$rate_higher
  )
  max_pmf_error <- max(abs(pmf_sums - 1))
  max_bound_violation <- max(c(core$bounds, broader$bounds))

  tibble::tibble(
    invariant = c(
      "profile_count",
      "core_candidate_count",
      "fringe_candidate_count",
      "effort_window_count",
      "pmf_max_abs_sum_error",
      "maximum_richness_bound_violation",
      "primary_richness_mean_mc_z",
      "broader_core_max_probability_difference",
      "rate_sensitivity_order"
    ),
    value = c(
      nrow(profiles),
      nrow(candidates$core),
      nrow(candidates$fringe),
      nrow(effort$summary),
      max_pmf_error,
      max_bound_violation,
      richness_z,
      broad_core_difference,
      as.numeric(rate_ordered)
    ),
    threshold = c(6, 50, 56, 6, 1e-12, 0, 5, 0, 1),
    comparison = c(
      "equal", "equal", "equal", "equal", "at_most", "at_most",
      "at_most", "equal", "equal"
    ),
    passed = c(
      nrow(profiles) == 6L,
      nrow(candidates$core) == 50L,
      nrow(candidates$fringe) == 56L,
      nrow(effort$summary) == 6L,
      max_pmf_error <= 1e-12,
      max_bound_violation <= 0,
      richness_z <= 5,
      broad_core_difference == 0,
      rate_ordered
    )
  )
}

#' Generate the complete Goal004 Task 2 prior-only calibration
goal004_task2_prior_only <- function(
  n_draws = 50000L,
  seed = 40042L,
  profiles = read_goal004_task2_profiles(),
  candidates = goal004_task2_candidate_mapping(),
  manifest = read_goal003_task4_manifests()
) {
  if (!is.numeric(n_draws) || length(n_draws) != 1L ||
      !is.finite(n_draws) || n_draws < 100L || n_draws != trunc(n_draws)) {
    .goal004_task2_stop("n_draws must be a whole number of at least 100.")
  }
  if (nrow(profiles) != 6L || nrow(candidates$core) != 50L ||
      nrow(candidates$fringe) != 56L) {
    .goal004_task2_stop("The Goal004 Task 2 inputs are incomplete.")
  }
  effort <- goal004_task2_effort_windows(manifest)
  base <- .goal004_task2_base_draws(
    n_draws = as.integer(n_draws),
    max_candidates = 106L,
    n_cameras = 9L,
    seed = seed
  )
  core <- .goal004_task2_core_calibration(
    profiles,
    candidates$core,
    effort,
    base
  )
  broader <- .goal004_task2_broader_calibration(
    primary_profile = profiles[profiles$profile_id == "primary", ],
    candidates = candidates,
    effort = effort,
    base = base,
    primary_predictions = core$primary_predictions
  )
  invariants <- .goal004_task2_invariants(
    profiles,
    candidates,
    effort,
    core,
    broader
  )
  if (!all(invariants$passed)) {
    .goal004_task2_stop("A Goal004 Task 2 prior-only invariant failed.")
  }

  list(
    effort_windows = effort$summary,
    effort_by_camera = effort$cells,
    core_richness_pmf = core$richness_pmf,
    core_candidate_membership = core$candidate_membership,
    core_predictive_summary = core$predictive_summary,
    core_predictive_pmf = core$predictive_pmf,
    core_candidate_prediction = core$candidate_prediction,
    broader_richness_summary = broader$richness_summary,
    broader_richness_pmf = broader$richness_pmf,
    broader_predictive_summary = broader$predictive_summary,
    broader_predictive_pmf = broader$predictive_pmf,
    broader_candidate_prediction = broader$candidate_prediction,
    invariants = invariants
  )
}
