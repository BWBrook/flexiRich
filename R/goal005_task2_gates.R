.goal005_task2_exact_ids <- function(observed, expected) {
  length(observed) == length(expected) && !anyNA(observed) &&
    !anyDuplicated(observed) && setequal(observed, expected)
}

.goal005_task2_gate_row <- function(
  information_level,
  train_occasions,
  gate_id,
  metric,
  stratum,
  value,
  threshold,
  comparison,
  numerator = NA_real_,
  denominator = NA_integer_,
  passed = FALSE
) {
  tibble::tibble(
    information_level = information_level,
    train_occasions = as.integer(train_occasions),
    gate_id = gate_id,
    metric = metric,
    stratum = stratum,
    value = as.numeric(value),
    threshold = as.numeric(threshold),
    comparison = comparison,
    numerator = as.numeric(numerator),
    denominator = as.integer(denominator),
    passed = isTRUE(passed)
  )
}

.goal005_task2_gain <- function(model, prior) {
  keep <- is.finite(model) & is.finite(prior)
  if (!any(keep) || mean(prior[keep]) <= 0) {
    return(NA_real_)
  }
  1 - mean(model[keep]) / mean(prior[keep])
}

.goal005_task2_pairs <- function(manifest, fit_status, richness) {
  context <- manifest$datasets |>
    dplyr::select(
      dataset_id,
      pair_id,
      true_richness_manifest = true_richness,
      train_occasions,
      replicate,
      training_active_camera_days,
      active_camera_count
    )
  base <- manifest$fits |>
    dplyr::left_join(context, by = "dataset_id")
  status <- fit_status |>
    dplyr::select(
      fit_id,
      terminal_status,
      status_terminal_clean = terminal_clean,
      elapsed_seconds
    )
  model <- richness |>
    dplyr::filter(!is.na(fit_id)) |>
    dplyr::select(
      fit_id,
      score_terminal_clean = terminal_clean,
      prediction_available,
      true_richness_score = true_richness,
      point_estimate,
      absolute_error,
      model_rps = rps,
      interval_90_covered,
      interval_90_width
    )
  prior <- richness |>
    dplyr::filter(method == "goal005_prior", run_role == "prior_only") |>
    dplyr::select(
      dataset_id,
      prior_true_richness = true_richness,
      prior_point_estimate = point_estimate,
      prior_rps = rps
    )
  base |>
    dplyr::left_join(status, by = "fit_id") |>
    dplyr::left_join(model, by = "fit_id") |>
    dplyr::left_join(prior, by = "dataset_id") |>
    dplyr::mutate(
      terminal_clean = dplyr::coalesce(status_terminal_clean, FALSE),
      prediction_available = dplyr::coalesce(prediction_available, FALSE),
      signed_bias = point_estimate - true_richness_manifest,
      proper_pair = terminal_clean & prediction_available &
        is.finite(model_rps) & is.finite(prior_rps),
      fixed_coverage = terminal_clean & prediction_available &
        dplyr::coalesce(interval_90_covered, FALSE),
      catastrophic_or_nonclean = !terminal_clean | !prediction_available |
        !is.finite(absolute_error) | absolute_error >= 12.5
    )
}

.goal005_task2_integrity <- function(manifest, fit_status, richness, pairs) {
  fit_scores <- dplyr::filter(richness, !is.na(fit_id))
  prior_scores <- dplyr::filter(
    richness,
    method == "goal005_prior",
    run_role == "prior_only"
  )
  required_status <- c(
    .goal005_task2_fit_fields,
    "terminal_status", "terminal_clean", "elapsed_seconds"
  )
  required_scores <- c(
    "dataset_id", "fit_id", "method", "run_role", "information_level",
    "prior_profile", "pool_profile", "candidate_pool_size",
    "terminal_clean", "prediction_available", "true_richness",
    "point_estimate", "absolute_error", "rps", "interval_90_covered",
    "interval_90_width"
  )
  schemas <- inherits(fit_status, "data.frame") &&
    all(required_status %in% names(fit_status)) &&
    inherits(richness, "data.frame") &&
    all(required_scores %in% names(richness))
  ids <- schemas && nrow(manifest$datasets) == 180L &&
    nrow(manifest$fits) == 360L && nrow(pairs) == 360L &&
    .goal005_task2_exact_ids(
      fit_status$fit_id,
      manifest$fits$fit_id
    ) &&
    .goal005_task2_exact_ids(
      fit_scores$fit_id,
      manifest$fits$fit_id
    ) &&
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
    all(is.finite(pairs$prior_rps))
  passed <- isTRUE(schemas && ids && coherent)
  tibble::tibble(
    check_id = "complete-frozen-evidence",
    expected_datasets = 180L,
    observed_datasets = if (is.list(manifest)) nrow(manifest$datasets) else NA_integer_,
    expected_fits = 360L,
    observed_fit_status = if (inherits(fit_status, "data.frame")) nrow(fit_status) else NA_integer_,
    observed_fit_scores = if (inherits(fit_scores, "data.frame")) nrow(fit_scores) else NA_integer_,
    observed_prior_scores = if (inherits(prior_scores, "data.frame")) nrow(prior_scores) else NA_integer_,
    passed = passed
  )
}

.goal005_task2_cell_gates <- function(selected, information_level, duration) {
  gates <- list()
  add <- function(...) {
    gates[[length(gates) + 1L]] <<- .goal005_task2_gate_row(...)
  }
  clean <- sum(selected$terminal_clean)
  add(
    information_level, duration, "clean-total", "terminal-clean fits",
    "all", clean, 35, "at_least", clean, 36L,
    nrow(selected) == 36L && clean >= 35L
  )
  for (richness in c(10L, 25L, 40L)) {
    cell <- dplyr::filter(
      selected,
      true_richness_manifest == .env$richness
    )
    clean_cell <- sum(cell$terminal_clean)
    add(
      information_level, duration, "clean-cell", "terminal-clean fits",
      paste0("R", richness), clean_cell, 11, "at_least",
      clean_cell, 12L, nrow(cell) == 12L && clean_cell >= 11L
    )
  }

  separation <- selected |>
    dplyr::filter(
      true_richness_manifest %in% c(10L, 40L),
      terminal_clean,
      prediction_available,
      is.finite(point_estimate)
    ) |>
    dplyr::select(replicate, true_richness_manifest, point_estimate) |>
    tidyr::pivot_wider(
      names_from = true_richness_manifest,
      values_from = point_estimate,
      names_prefix = "R"
    ) |>
    dplyr::filter(is.finite(R10), is.finite(R40)) |>
    dplyr::mutate(separation = R40 - R10)
  median_separation <- if (nrow(separation) > 0L) {
    stats::median(separation$separation)
  } else {
    NA_real_
  }
  add(
    information_level, duration, "high-low-separation",
    "median paired high-minus-low posterior mean", "R40-R10",
    median_separation, 27, "at_least", nrow(separation), 12L,
    nrow(separation) >= 11L && is.finite(median_separation) &&
      median_separation >= 27
  )

  for (richness in c(10L, 25L, 40L)) {
    cell <- selected |>
      dplyr::filter(
        true_richness_manifest == .env$richness,
        terminal_clean,
        prediction_available,
        is.finite(signed_bias)
      )
    median_bias <- if (nrow(cell) > 0L) stats::median(cell$signed_bias) else NA_real_
    add(
      information_level, duration, "bias-cell",
      "absolute median signed bias", paste0("R", richness),
      abs(median_bias), 3, "at_most", nrow(cell), 12L,
      nrow(cell) >= 11L && is.finite(median_bias) && abs(median_bias) <= 3
    )
  }

  pooled <- dplyr::filter(selected, proper_pair)
  pooled_gain <- .goal005_task2_gain(pooled$model_rps, pooled$prior_rps)
  add(
    information_level, duration, "rps-gain-pooled",
    "mean RPS gain over no-data prior", "all",
    pooled_gain, 0.4, "at_least", nrow(pooled), 36L,
    nrow(pooled) >= 35L && is.finite(pooled_gain) && pooled_gain >= 0.4
  )
  for (richness in c(10L, 25L, 40L)) {
    cell <- dplyr::filter(
      selected,
      true_richness_manifest == .env$richness,
      proper_pair
    )
    gain <- .goal005_task2_gain(cell$model_rps, cell$prior_rps)
    add(
      information_level, duration, "rps-gain-cell",
      "mean RPS gain over no-data prior", paste0("R", richness),
      gain, 0, "at_least", nrow(cell), 12L,
      nrow(cell) >= 11L && is.finite(gain) && gain >= 0
    )
  }

  for (richness in c(10L, 25L, 40L)) {
    cell <- dplyr::filter(
      selected,
      true_richness_manifest == .env$richness
    )
    covered <- sum(cell$fixed_coverage)
    add(
      information_level, duration, "coverage-cell",
      "fixed-denominator 90% interval coverage", paste0("R", richness),
      covered / 12, 10 / 12, "at_least", covered, 12L,
      nrow(cell) == 12L && covered >= 10L
    )
  }

  width <- selected |>
    dplyr::filter(
      terminal_clean,
      prediction_available,
      is.finite(interval_90_width)
    )
  median_width <- if (nrow(width) > 0L) {
    stats::median(width$interval_90_width)
  } else {
    NA_real_
  }
  add(
    information_level, duration, "interval-width",
    "median 90% interval width", "all", median_width, 25, "at_most",
    nrow(width), 36L,
    nrow(width) >= 35L && is.finite(median_width) && median_width <= 25
  )
  catastrophic <- sum(selected$catastrophic_or_nonclean)
  add(
    information_level, duration, "catastrophic-or-nonclean",
    "terminal non-clean or absolute error at least 12.5", "all",
    catastrophic, 2, "fewer_than", catastrophic, 36L,
    nrow(selected) == 36L && catastrophic < 2L
  )
  dplyr::bind_rows(gates)
}

#' Evaluate the frozen Goal005 Task 2 duration and oracle gates
evaluate_goal005_task2_gates <- function(
  manifest,
  fit_status,
  richness,
  integrity_passed = TRUE
) {
  if (!is.list(manifest) ||
      !all(c("datasets", "fits") %in% names(manifest)) ||
      !is.logical(integrity_passed) || length(integrity_passed) != 1L ||
      is.na(integrity_passed)) {
    .goal005_stop("Invalid Goal005 Task 2 gate inputs.")
  }
  pairs <- .goal005_task2_pairs(manifest, fit_status, richness)
  integrity <- .goal005_task2_integrity(
    manifest,
    fit_status,
    richness,
    pairs
  ) |>
    dplyr::mutate(passed = passed & .env$integrity_passed)
  gates <- lapply(c("C0", "I0"), function(level) {
    lapply(c(4L, 8L, 12L, 16L, 26L), function(duration) {
      selected <- pairs |>
        dplyr::filter(
          information_level == .env$level,
          train_occasions == .env$duration
        )
      .goal005_task2_cell_gates(selected, level, duration)
    })
  }) |>
    unlist(recursive = FALSE) |>
    dplyr::bind_rows()
  duration_summary <- gates |>
    dplyr::summarise(
      n_gates = dplyr::n(),
      n_passed = sum(passed),
      passed = isTRUE(integrity$passed[[1L]]) && all(passed),
      .by = c(information_level, train_occasions)
    ) |>
    dplyr::arrange(train_occasions, information_level)
  pruning <- tidyr::pivot_wider(
    duration_summary |>
      dplyr::select(information_level, train_occasions, passed),
    names_from = information_level,
    values_from = passed,
    names_prefix = "pass_"
  ) |>
    dplyr::arrange(train_occasions) |>
    dplyr::mutate(
      task3_path = dplyr::case_when(
        !isTRUE(integrity$passed[[1L]]) ~ "INVALID_EVIDENCE",
        !pass_I0 ~ "CLOSED_ORACLE_FAIL",
        !pass_C0 ~ "CANDIDATE_CALIBRATION_REQUIRED",
        .default = "CLASS_CALIBRATION_ELIGIBLE"
      )
    )
  list(
    integrity = integrity,
    gates = gates,
    duration_summary = duration_summary,
    pruning = pruning,
    pairs = pairs
  )
}
