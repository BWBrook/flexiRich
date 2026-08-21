.goal005_task4_integrity <- function(manifest, fit_status, richness, pairs) {
  fit_scores <- dplyr::filter(richness, !is.na(fit_id))
  prior_scores <- dplyr::filter(
    richness,
    method == "goal005_prior",
    run_role == "prior_only"
  )
  schemas <- inherits(fit_status, "data.frame") &&
    all(c(
      .goal005_task3_fit_fields,
      "terminal_status", "terminal_clean", "elapsed_seconds"
    ) %in% names(fit_status)) &&
    inherits(richness, "data.frame") &&
    all(c(
      "dataset_id", "fit_id", "method", "run_role", "information_level",
      "prior_profile", "pool_profile", "candidate_pool_size",
      "terminal_clean", "prediction_available", "true_richness",
      "point_estimate", "absolute_error", "rps", "interval_90_covered",
      "interval_90_width"
    ) %in% names(richness))
  ids <- schemas &&
    nrow(manifest$datasets) == 36L &&
    nrow(manifest$fits) == 108L &&
    nrow(pairs) == 108L &&
    .goal005_task2_exact_ids(fit_status$fit_id, manifest$fits$fit_id) &&
    .goal005_task2_exact_ids(fit_scores$fit_id, manifest$fits$fit_id) &&
    .goal005_task2_exact_ids(
      prior_scores$dataset_id,
      manifest$datasets$dataset_id
    )
  coherent <- ids &&
    all(!is.na(pairs$status_terminal_clean)) &&
    all(!is.na(pairs$score_terminal_clean)) &&
    identical(pairs$status_terminal_clean, pairs$score_terminal_clean) &&
    all(pairs$true_richness_score == pairs$true_richness_manifest) &&
    all(pairs$prior_true_richness == pairs$true_richness_manifest) &&
    all(is.finite(pairs$prior_rps)) &&
    setequal(unique(pairs$information_level), manifest$profiles$profile_id)
  tibble::tibble(
    check_id = "complete-frozen-task4-evidence",
    expected_datasets = 36L,
    observed_datasets = nrow(manifest$datasets),
    expected_fits = 108L,
    observed_fit_status = if (inherits(fit_status, "data.frame")) {
      nrow(fit_status)
    } else {
      NA_integer_
    },
    observed_fit_scores = if (inherits(fit_scores, "data.frame")) {
      nrow(fit_scores)
    } else {
      NA_integer_
    },
    observed_prior_scores = if (inherits(prior_scores, "data.frame")) {
      nrow(prior_scores)
    } else {
      NA_integer_
    },
    passed = isTRUE(schemas && ids && coherent)
  )
}

.goal005_task4_paired_shifts <- function(pairs) {
  fields <- c(
    "dataset_id", "true_richness_manifest", "replicate",
    "terminal_clean", "prediction_available", "point_estimate"
  )
  unbiased <- pairs |>
    dplyr::filter(information_level == "unbiased") |>
    dplyr::select(dplyr::all_of(fields)) |>
    dplyr::rename_with(
      ~ paste0("unbiased_", .x),
      c("terminal_clean", "prediction_available", "point_estimate")
    )
  biased <- pairs |>
    dplyr::filter(information_level %in% c("down_0.8", "up_1.25")) |>
    dplyr::select(information_level, dplyr::all_of(fields)) |>
    dplyr::rename(
      bias_profile = information_level,
      biased_terminal_clean = terminal_clean,
      biased_prediction_available = prediction_available,
      biased_point_estimate = point_estimate
    )
  biased |>
    dplyr::left_join(
      unbiased,
      by = c("dataset_id", "true_richness_manifest", "replicate")
    ) |>
    dplyr::mutate(
      proper_pair = biased_terminal_clean & unbiased_terminal_clean &
        biased_prediction_available & unbiased_prediction_available &
        is.finite(biased_point_estimate) & is.finite(unbiased_point_estimate),
      absolute_posterior_mean_shift = ifelse(
        proper_pair,
        abs(biased_point_estimate - unbiased_point_estimate),
        NA_real_
      )
    ) |>
    dplyr::arrange(
      match(bias_profile, c("down_0.8", "up_1.25")),
      match(dataset_id, unbiased$dataset_id)
    )
}

.goal005_task4_shift_gates <- function(paired_shifts) {
  rows <- lapply(c("down_0.8", "up_1.25"), function(profile) {
    selected <- dplyr::filter(
      paired_shifts,
      bias_profile == .env$profile
    )
    proper <- dplyr::filter(selected, proper_pair)
    n_proper <- nrow(proper)
    median_shift <- if (n_proper > 0L) {
      stats::median(proper$absolute_posterior_mean_shift)
    } else {
      NA_real_
    }
    maximum_shift <- if (n_proper > 0L) {
      max(proper$absolute_posterior_mean_shift)
    } else {
      NA_real_
    }
    dplyr::bind_rows(
      .goal005_task2_gate_row(
        profile, 12L, "paired-complete",
        "complete biased-unbiased posterior-mean pairs", "all",
        n_proper, 35, "at_least", n_proper, 36L,
        nrow(selected) == 36L && n_proper >= 35L
      ),
      .goal005_task2_gate_row(
        profile, 12L, "median-posterior-shift",
        "median absolute paired posterior-mean richness shift", "all",
        median_shift, 3.5, "at_most", n_proper, 36L,
        n_proper >= 35L && is.finite(median_shift) && median_shift <= 3.5
      ),
      .goal005_task2_gate_row(
        profile, 12L, "maximum-posterior-shift",
        "maximum absolute paired posterior-mean richness shift", "all",
        maximum_shift, 8, "at_most", n_proper, 36L,
        n_proper >= 35L && is.finite(maximum_shift) && maximum_shift <= 8
      )
    )
  })
  dplyr::bind_rows(rows)
}

#' Evaluate the frozen Goal005 Task 4 calibration-transfer stress
evaluate_goal005_task4_gates <- function(
  manifest,
  fit_status,
  richness,
  integrity_passed = TRUE
) {
  if (!is.logical(integrity_passed) || length(integrity_passed) != 1L ||
      is.na(integrity_passed)) {
    .goal005_stop("Goal005 Task 4 integrity flag is invalid.")
  }
  pairs <- .goal005_task2_pairs(manifest, fit_status, richness)
  integrity <- .goal005_task4_integrity(
    manifest,
    fit_status,
    richness,
    pairs
  )
  integrity$passed <- integrity$passed & integrity_passed
  profile_gates <- lapply(manifest$profiles$profile_id, function(profile) {
    selected <- dplyr::filter(
      pairs,
      information_level == .env$profile,
      train_occasions == 12L
    )
    .goal005_task2_cell_gates(selected, profile, 12L)
  }) |>
    dplyr::bind_rows()
  paired_shifts <- .goal005_task4_paired_shifts(pairs)
  shift_gates <- .goal005_task4_shift_gates(paired_shifts)
  if (!isTRUE(integrity$passed[[1L]])) {
    profile_gates$passed <- FALSE
    shift_gates$passed <- FALSE
  }
  all_gates <- dplyr::bind_rows(profile_gates, shift_gates)
  if (nrow(profile_gates) != 51L || nrow(paired_shifts) != 72L ||
      nrow(shift_gates) != 6L || nrow(all_gates) != 57L ||
      anyNA(all_gates$passed)) {
    .goal005_stop("Goal005 Task 4 gate surface is incomplete.")
  }
  profile_summary <- profile_gates |>
    dplyr::summarise(
      n_gates = dplyr::n(),
      n_passed = sum(passed),
      passed = dplyr::n() == 17L && all(passed),
      .by = information_level
    ) |>
    dplyr::arrange(match(
      information_level,
      manifest$profiles$profile_id
    ))
  unbiased_pass <- profile_summary$passed[
    profile_summary$information_level == "unbiased"
  ]
  decision <- if (!isTRUE(integrity$passed[[1L]])) {
    "INVALID_EVIDENCE"
  } else if (!isTRUE(unbiased_pass)) {
    "UNBIASED_REPLICATION_FAIL"
  } else if (all(profile_summary$passed) && all(shift_gates$passed)) {
    "TRANSFER_ROBUST"
  } else {
    "TRANSFER_SENSITIVE"
  }
  list(
    integrity = integrity,
    pairs = pairs,
    profile_gates = profile_gates,
    paired_shifts = paired_shifts,
    shift_gates = shift_gates,
    all_gates = all_gates,
    profile_summary = profile_summary,
    decision = tibble::tibble(decision = decision)
  )
}
