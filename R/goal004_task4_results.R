.goal004_task4_read_membership_scores <- function(paths) {
  .goal003_task4_read_rows(
    paths,
    character_fields = c(
      "dataset_id", "fit_id", "method", "run_role", "prior_profile",
      "pool_profile"
    ),
    logical_fields = c("terminal_clean", "prediction_available"),
    integer_fields = c(
      "true_richness", "n_candidates", "n_unseen_candidates",
      "candidate_pool_size"
    ),
    numeric_fields = c("all_candidate_brier", "unseen_candidate_brier")
  )
}

.goal004_task4_validate_aggregate <- function(
  manifest,
  dataset_status,
  fit_status,
  baseline_point,
  fit_richness,
  fit_discovery,
  fit_membership,
  prior_richness,
  prior_discovery,
  prior_membership
) {
  exact <- .goal004_task4_exact_ids
  prior_keys <- manifest$fits |>
    dplyr::filter(method == "goal004") |>
    dplyr::distinct(dataset_id, prior_profile)
  observed_prior <- prior_richness |>
    dplyr::distinct(dataset_id, prior_profile)
  valid <- exact(dataset_status$dataset_id, manifest$datasets$dataset_id) &&
    exact(fit_status$fit_id, manifest$fits$fit_id) &&
    exact(fit_richness$fit_id, manifest$fits$fit_id) &&
    exact(fit_discovery$fit_id, manifest$fits$fit_id) &&
    exact(fit_membership$fit_id, manifest$fits$fit_id) &&
    nrow(baseline_point) == 6L * 180L &&
    nrow(prior_richness) == nrow(prior_keys) &&
    nrow(prior_discovery) == nrow(prior_keys) &&
    nrow(prior_membership) == nrow(prior_keys) &&
    setequal(
      paste(observed_prior$dataset_id, observed_prior$prior_profile, sep = "\r"),
      paste(prior_keys$dataset_id, prior_keys$prior_profile, sep = "\r")
    )
  if (!valid) {
    .goal004_task4_stop(
      "Goal004 Task 4 aggregate rows differ from the frozen contract."
    )
  }
  invisible(TRUE)
}

.goal004_task4_nested_pairs <- function(
  output_dir,
  manifest,
  fit_status,
  fit_richness
) {
  nested <- manifest$fits |>
    dplyr::filter(run_role == "pool_sensitivity") |>
    dplyr::left_join(
      manifest$datasets |>
        dplyr::select(dataset_id, train_occasions, replicate),
      by = "dataset_id"
    )
  lapply(seq_len(nrow(nested)), function(index) {
    row <- nested[index, ]
    primary_id <- manifest$fits |>
      dplyr::filter(
        dataset_id == row$dataset_id,
        method == "goal004",
        run_role == "primary"
      ) |>
      dplyr::pull(fit_id)
    nested_status <- fit_status |>
      dplyr::filter(fit_id == row$fit_id)
    primary_status <- fit_status |>
      dplyr::filter(fit_id == .env$primary_id)
    nested_score <- fit_richness |>
      dplyr::filter(fit_id == row$fit_id)
    primary_score <- fit_richness |>
      dplyr::filter(fit_id == .env$primary_id)
    clean <- nested_status$terminal_clean[[1L]] &&
      primary_status$terminal_clean[[1L]]
    tv <- NA_real_
    fringe_mean <- NA_real_
    total_mean <- NA_real_
    if (clean) {
      nested_pmf <- tibble::as_tibble(utils::read.csv(
        file.path(output_dir, "fits", row$fit_id, "richness-pmf.csv"),
        check.names = FALSE
      ))
      primary_pmf <- tibble::as_tibble(utils::read.csv(
        file.path(output_dir, "fits", primary_id, "richness-pmf.csv"),
        check.names = FALSE
      ))
      if (!identical(nested_pmf$richness, primary_pmf$richness)) {
        .goal004_task4_stop("Nested and core PMF supports differ.")
      }
      tv <- goal004_total_variation(
        nested_pmf$probability,
        primary_pmf$probability
      )
      summary <- tibble::as_tibble(utils::read.csv(
        file.path(
          output_dir,
          "fits",
          row$fit_id,
          "nested-richness-summary.csv"
        ),
        check.names = FALSE
      ))
      fringe_mean <- summary$mean[summary$component == "fringe"]
      total_mean <- summary$mean[summary$component == "total"]
    }
    shift <- nested_score$point_estimate[[1L]] -
      primary_score$point_estimate[[1L]]
    tibble::tibble(
      dataset_id = row$dataset_id,
      fit_id = row$fit_id,
      primary_fit_id = primary_id,
      train_occasions = row$train_occasions,
      replicate = row$replicate,
      terminal_clean = nested_status$terminal_clean,
      primary_terminal_clean = primary_status$terminal_clean,
      core_mean_shift = shift,
      abs_core_mean_shift = abs(shift),
      core_pmf_total_variation = tv,
      fringe_posterior_mean = fringe_mean,
      total_posterior_mean = total_mean
    )
  }) |>
    dplyr::bind_rows()
}

.goal004_task4_sensitivity_pairs <- function(
  manifest,
  fit_status,
  fit_richness,
  prior_richness
) {
  sensitivity <- manifest$fits |>
    dplyr::filter(run_role == "prior_sensitivity") |>
    dplyr::left_join(
      manifest$datasets |>
        dplyr::select(
          dataset_id,
          fidelity,
          true_richness,
          train_occasions,
          replicate
        ),
      by = "dataset_id"
    )
  primary <- manifest$fits |>
    dplyr::filter(method == "goal004", run_role == "primary") |>
    dplyr::select(dataset_id, primary_fit_id = fit_id)
  sensitivity |>
    dplyr::left_join(primary, by = "dataset_id") |>
    dplyr::left_join(
      fit_status |>
        dplyr::select(fit_id, terminal_clean),
      by = "fit_id"
    ) |>
    dplyr::left_join(
      fit_status |>
        dplyr::select(
          primary_fit_id = fit_id,
          primary_terminal_clean = terminal_clean
        ),
      by = "primary_fit_id"
    ) |>
    dplyr::left_join(
      fit_richness |>
        dplyr::select(
          fit_id,
          sensitivity_point_estimate = point_estimate,
          sensitivity_rps = rps
        ),
      by = "fit_id"
    ) |>
    dplyr::left_join(
      fit_richness |>
        dplyr::select(
          primary_fit_id = fit_id,
          primary_point_estimate = point_estimate,
          primary_rps = rps
        ),
      by = "primary_fit_id"
    ) |>
    dplyr::left_join(
      prior_richness |>
        dplyr::select(dataset_id, prior_profile, own_prior_rps = rps),
      by = c("dataset_id", "prior_profile")
    ) |>
    dplyr::mutate(
      abs_mean_shift = abs(
        sensitivity_point_estimate - primary_point_estimate
      )
    ) |>
    dplyr::select(
      dataset_id,
      fit_id,
      prior_profile,
      fidelity,
      true_richness,
      train_occasions,
      replicate,
      terminal_clean,
      primary_terminal_clean,
      primary_point_estimate,
      sensitivity_point_estimate,
      abs_mean_shift,
      primary_rps,
      sensitivity_rps,
      own_prior_rps
    )
}

.goal004_task4_score_summary <- function(richness, discovery, membership) {
  list(
    richness = richness |>
      dplyr::summarise(
        scheduled = dplyr::n(),
        scored = sum(prediction_available),
        proper_scores = sum(is.finite(rps)),
        .by = c(method, run_role, prior_profile, pool_profile)
      ),
    discovery = discovery |>
      dplyr::summarise(
        scheduled = dplyr::n(),
        count_scores = sum(is.finite(count_rps)),
        identity_scores = sum(is.finite(identity_brier)),
        .by = c(method, run_role, prior_profile, pool_profile)
      ),
    membership = membership |>
      dplyr::summarise(
        scheduled = dplyr::n(),
        membership_scores = sum(is.finite(unseen_candidate_brier)),
        .by = c(method, run_role, prior_profile, pool_profile)
      )
  )
}

.goal004_task4_aggregate <- function(output_dir, manifest) {
  dataset_dirs <- file.path(output_dir, "datasets", manifest$datasets$dataset_id)
  fit_dirs <- file.path(output_dir, "fits", manifest$fits$fit_id)
  dataset_status <- .goal003_task4_read_rows(file.path(
    dataset_dirs,
    "dataset-status.csv"
  ))
  fit_status <- .goal003_task4_read_rows(
    file.path(fit_dirs, "fit-status.csv"),
    character_fields = c(
      "fit_id", "dataset_id", "method", "run_role", "prior_profile",
      "pool_profile", "terminal_status", "terminal_attempt", "reasons"
    ),
    logical_fields = "terminal_clean",
    integer_fields = c(
      "candidate_pool_size", "fit_seed", "n_attempts", "divergences",
      "treedepth_hits"
    ),
    numeric_fields = c(
      "elapsed_seconds", "min_ebfmi", "max_rhat", "min_bulk_ess",
      "min_tail_ess"
    )
  )
  baseline_point <- .goal003_task4_read_rows(
    file.path(dataset_dirs, "baseline-point-predictions.csv"),
    character_fields = c("dataset_id", "method", "reason"),
    logical_fields = "eligible",
    numeric_fields = c("raw_estimate", "estimate")
  )
  baseline_richness <- .goal003_task4_read_richness_scores(file.path(
    dataset_dirs,
    "baseline-richness-scores.csv"
  ))
  baseline_discovery <- .goal003_task4_read_discovery_scores(file.path(
    dataset_dirs,
    "baseline-discovery-scores.csv"
  ))
  prior_richness <- .goal003_task4_read_richness_scores(file.path(
    dataset_dirs,
    "prior-richness-scores.csv"
  ))
  prior_discovery <- .goal003_task4_read_discovery_scores(file.path(
    dataset_dirs,
    "prior-discovery-scores.csv"
  ))
  prior_membership <- .goal004_task4_read_membership_scores(file.path(
    dataset_dirs,
    "prior-membership-scores.csv"
  ))
  fit_richness <- .goal003_task4_read_richness_scores(file.path(
    fit_dirs,
    "richness-score.csv"
  ))
  fit_discovery <- .goal003_task4_read_discovery_scores(file.path(
    fit_dirs,
    "discovery-score.csv"
  ))
  fit_membership <- .goal004_task4_read_membership_scores(file.path(
    fit_dirs,
    "membership-score.csv"
  ))
  .goal004_task4_validate_aggregate(
    manifest,
    dataset_status,
    fit_status,
    baseline_point,
    fit_richness,
    fit_discovery,
    fit_membership,
    prior_richness,
    prior_discovery,
    prior_membership
  )
  richness <- dplyr::bind_rows(
    baseline_richness,
    prior_richness,
    fit_richness
  )
  discovery <- dplyr::bind_rows(
    baseline_discovery,
    prior_discovery,
    fit_discovery
  )
  membership <- dplyr::bind_rows(prior_membership, fit_membership)
  nested_pairs <- .goal004_task4_nested_pairs(
    output_dir,
    manifest,
    fit_status,
    fit_richness
  )
  sensitivity_pairs <- .goal004_task4_sensitivity_pairs(
    manifest,
    fit_status,
    fit_richness,
    prior_richness
  )
  gates <- evaluate_goal004_task4_gates(
    manifest,
    fit_status,
    richness,
    discovery,
    membership,
    nested_pairs,
    sensitivity_pairs,
    integrity_passed = TRUE
  )
  list(
    dataset_status = dataset_status,
    fit_status = fit_status,
    baseline_point = baseline_point,
    richness = richness,
    discovery = discovery,
    membership = membership,
    score_summary = .goal004_task4_score_summary(
      richness,
      discovery,
      membership
    ),
    gates = gates
  )
}

.goal004_task4_write_results <- function(results, staging) {
  tables <- list(
    "dataset-status.csv" = results$dataset_status,
    "fit-status.csv" = results$fit_status,
    "baseline-point-predictions.csv" = results$baseline_point,
    "richness-scores.csv" = results$richness,
    "discovery-scores.csv" = results$discovery,
    "membership-scores.csv" = results$membership,
    "richness-score-summary.csv" = results$score_summary$richness,
    "discovery-score-summary.csv" = results$score_summary$discovery,
    "membership-score-summary.csv" = results$score_summary$membership,
    "primary-prior-pairs.csv" = results$gates$primary_pairs,
    "nested-pool-pairs.csv" = results$gates$nested_pairs,
    "prior-sensitivity-pairs.csv" = results$gates$sensitivity_pairs,
    "development-gates.csv" = results$gates$gates
  )
  for (name in names(tables)) {
    .goal003_task4_write_csv(tables[[name]], file.path(staging, name))
  }
  restored <- utils::read.csv(
    file.path(staging, "development-gates.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  if (nrow(restored) != nrow(results$gates$gates) ||
      anyNA(restored$passed)) {
    .goal004_task4_stop("Goal004 Task 4 result readback failed.")
  }
  status <- if (all(results$gates$gates$passed)) {
    "TASK4_PASS"
  } else {
    "TASK4_STOP"
  }
  writeLines(
    c(
      paste0("status=", status),
      "rows_complete=true",
      "empirical_outcomes_used=false"
    ),
    file.path(staging, "completion-status.txt")
  )
}
