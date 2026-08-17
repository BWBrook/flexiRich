.goal004_task4_window_id <- function(dataset_row) {
  if (!inherits(dataset_row, "data.frame") || nrow(dataset_row) != 1L ||
      !all(c("train_occasions", "replicate") %in% names(dataset_row))) {
    .goal004_task4_stop("One Task 4 dataset row is required.")
  }
  sprintf(
    "g004_%02dw_r%02d",
    dataset_row$train_occasions[[1L]],
    dataset_row$replicate[[1L]]
  )
}

.goal004_task4_membership_table <- function(probability, truth) {
  .goal003_task4_validate_truth(truth)
  expected <- truth$species$species_id
  if (!tibble::is_tibble(probability) ||
      !all(c("species_id", "membership_probability") %in% names(probability)) ||
      !identical(probability$species_id, expected) ||
      !is.numeric(probability$membership_probability) ||
      anyNA(probability$membership_probability) ||
      any(!is.finite(probability$membership_probability)) ||
      any(probability$membership_probability < 0 |
        probability$membership_probability > 1)) {
    .goal004_task4_stop("Candidate membership probabilities are invalid.")
  }
  probability
}

#' Score candidate-pool membership for one Task 4 prediction
score_goal004_task4_membership <- function(
  dataset_id,
  fit_id,
  method,
  run_role,
  terminal_clean,
  truth,
  candidate_probability = NULL
) {
  dataset_id <- .goal003_task4_validate_text(dataset_id, "dataset_id")
  fit_id <- .goal003_task4_validate_text(
    fit_id,
    "fit_id",
    allow_missing = TRUE
  )
  method <- .goal003_task4_validate_text(method, "method")
  run_role <- .goal003_task4_validate_text(run_role, "run_role")
  terminal_clean <- .goal003_task4_validate_flag(
    terminal_clean,
    "terminal_clean"
  )
  .goal003_task4_validate_truth(truth)
  available <- terminal_clean && !is.null(candidate_probability)
  all_brier <- NA_real_
  unseen_brier <- NA_real_
  if (available) {
    candidate_probability <- .goal004_task4_membership_table(
      candidate_probability,
      truth
    )
    observed <- as.numeric(truth$species$member)
    squared <- (candidate_probability$membership_probability - observed)^2
    unseen <- !truth$species$training_detected
    all_brier <- mean(squared)
    unseen_brier <- mean(squared[unseen])
  }
  tibble::tibble(
    dataset_id = dataset_id,
    fit_id = fit_id,
    method = method,
    run_role = run_role,
    terminal_clean = terminal_clean,
    prediction_available = available,
    true_richness = truth$true_richness,
    all_candidate_brier = all_brier,
    unseen_candidate_brier = unseen_brier,
    n_candidates = as.integer(nrow(truth$species)),
    n_unseen_candidates = as.integer(sum(!truth$species$training_detected))
  )
}

.goal004_task4_prior_prediction <- function(
  dataset_row,
  truth,
  prior_forecasts,
  profile_id
) {
  window_id <- .goal004_task4_window_id(dataset_row)
  richness <- prior_forecasts$richness_pmf |>
    dplyr::filter(profile_id == .env$profile_id) |>
    dplyr::select(richness, probability)
  discovery <- prior_forecasts$predictive_pmf |>
    dplyr::filter(
      profile_id == .env$profile_id,
      window_id == .env$window_id,
      outcome == "future_discoveries"
    ) |>
    dplyr::transmute(
      new_species_count = as.integer(value),
      probability
    )
  identity <- prior_forecasts$candidate_prediction |>
    dplyr::filter(
      profile_id == .env$profile_id,
      window_id == .env$window_id
    ) |>
    dplyr::arrange(candidate_id) |>
    dplyr::transmute(
      species_id = candidate_id,
      training_detected = truth$species$training_detected,
      future_first_detection_probability
    )
  valid <- nrow(richness) == 51L && nrow(discovery) == 51L &&
    nrow(identity) == 50L &&
    identical(identity$species_id, truth$species$species_id)
  if (!valid) {
    .goal004_task4_stop("A matching no-data prior forecast is unavailable.")
  }
  list(richness = richness, discovery = discovery, identity = identity)
}

#' Score the matching no-data prior for one Task 4 dataset
score_goal004_task4_prior <- function(
  dataset_row,
  truth,
  prior_forecasts,
  profile_id = "primary"
) {
  prediction <- .goal004_task4_prior_prediction(
    dataset_row,
    truth,
    prior_forecasts,
    profile_id
  )
  scores <- score_goal003_task4_prediction(
    dataset_id = dataset_row$dataset_id[[1L]],
    fit_id = NA_character_,
    method = "goal004_prior",
    run_role = "prior_only",
    terminal_clean = TRUE,
    truth = truth,
    richness_pmf = prediction$richness,
    new_species_count_pmf = prediction$discovery,
    future_identity = prediction$identity
  )
  prior_membership <- tibble::tibble(
    species_id = truth$species$species_id,
    membership_probability = rep(0.5, nrow(truth$species))
  )
  membership <- score_goal004_task4_membership(
    dataset_id = dataset_row$dataset_id[[1L]],
    fit_id = NA_character_,
    method = "goal004_prior",
    run_role = "prior_only",
    terminal_clean = TRUE,
    truth = truth,
    candidate_probability = prior_membership
  )
  list(
    richness = dplyr::mutate(
      scores$richness,
      prior_profile = profile_id,
      pool_profile = "core_50",
      candidate_pool_size = 50L
    ),
    discovery = dplyr::mutate(
      scores$discovery,
      prior_profile = profile_id,
      pool_profile = "core_50",
      candidate_pool_size = 50L
    ),
    membership = dplyr::mutate(
      membership,
      prior_profile = profile_id,
      pool_profile = "core_50",
      candidate_pool_size = 50L
    )
  )
}

#' Adapt a fitted prediction to the shared Task 4 scoring contract
score_goal004_task4_fit <- function(
  fit_row,
  truth,
  terminal_clean,
  richness_pmf = NULL,
  discovery_pmf = NULL,
  future_identity = NULL,
  membership_probability = NULL
) {
  if (!inherits(fit_row, "data.frame") || nrow(fit_row) != 1L ||
      !identical(names(fit_row), .goal004_task4_fit_fields)) {
    .goal004_task4_stop("One frozen Task 4 fit row is required.")
  }
  scores <- score_goal003_task4_prediction(
    dataset_id = fit_row$dataset_id[[1L]],
    fit_id = fit_row$fit_id[[1L]],
    method = fit_row$method[[1L]],
    run_role = fit_row$run_role[[1L]],
    terminal_clean = terminal_clean,
    truth = truth,
    richness_pmf = richness_pmf,
    new_species_count_pmf = discovery_pmf,
    future_identity = future_identity
  )
  membership <- score_goal004_task4_membership(
    dataset_id = fit_row$dataset_id[[1L]],
    fit_id = fit_row$fit_id[[1L]],
    method = fit_row$method[[1L]],
    run_role = fit_row$run_role[[1L]],
    terminal_clean = terminal_clean,
    truth = truth,
    candidate_probability = membership_probability
  )
  context <- fit_row[c(
    "prior_profile", "pool_profile", "candidate_pool_size"
  )]
  list(
    richness = dplyr::bind_cols(scores$richness, context),
    discovery = dplyr::bind_cols(scores$discovery, context),
    membership = dplyr::bind_cols(membership, context)
  )
}
