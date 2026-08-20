.goal005_task2_audit_row <- function(
  level,
  duration,
  gate_id,
  metric,
  stratum,
  value,
  threshold,
  comparison,
  numerator,
  denominator,
  passed
) {
  tibble::tibble(
    information_level = level,
    train_occasions = as.integer(duration),
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

.goal005_task2_audit_gain <- function(model, prior) {
  keep <- is.finite(model) & is.finite(prior)
  if (!any(keep) || mean(prior[keep]) <= 0) {
    return(NA_real_)
  }
  1 - mean(model[keep]) / mean(prior[keep])
}

.goal005_task2_replay_cell <- function(pairs, level, duration) {
  selected <- pairs |>
    dplyr::filter(
      information_level == .env$level,
      train_occasions == .env$duration
    ) |>
    dplyr::mutate(
      replay_clean = terminal_clean & prediction_available,
      replay_bias = point_estimate - true_richness_manifest,
      replay_proper = replay_clean & is.finite(model_rps) &
        is.finite(prior_rps),
      replay_coverage = replay_clean &
        dplyr::coalesce(interval_90_covered, FALSE),
      replay_catastrophic = !replay_clean | !is.finite(absolute_error) |
        absolute_error >= 12.5
    )
  rows <- list()
  add <- function(...) {
    rows[[length(rows) + 1L]] <<- .goal005_task2_audit_row(...)
  }
  clean <- sum(selected$terminal_clean)
  add(
    level, duration, "clean-total", "terminal-clean fits", "all",
    clean, 35, "at_least", clean, 36L,
    nrow(selected) == 36L && clean >= 35L
  )
  for (richness in c(10L, 25L, 40L)) {
    cell <- dplyr::filter(
      selected,
      true_richness_manifest == .env$richness
    )
    clean_cell <- sum(cell$terminal_clean)
    add(
      level, duration, "clean-cell", "terminal-clean fits",
      paste0("R", richness), clean_cell, 11, "at_least",
      clean_cell, 12L, nrow(cell) == 12L && clean_cell >= 11L
    )
  }
  extremes <- selected |>
    dplyr::filter(
      true_richness_manifest %in% c(10L, 40L),
      replay_clean,
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
  separation <- if (nrow(extremes) > 0L) {
    stats::median(extremes$separation)
  } else {
    NA_real_
  }
  add(
    level, duration, "high-low-separation",
    "median paired high-minus-low posterior mean", "R40-R10",
    separation, 27, "at_least", nrow(extremes), 12L,
    nrow(extremes) >= 11L && is.finite(separation) && separation >= 27
  )
  for (richness in c(10L, 25L, 40L)) {
    cell <- selected |>
      dplyr::filter(
        true_richness_manifest == .env$richness,
        replay_clean,
        is.finite(replay_bias)
      )
    bias <- if (nrow(cell) > 0L) stats::median(cell$replay_bias) else NA_real_
    add(
      level, duration, "bias-cell", "absolute median signed bias",
      paste0("R", richness), abs(bias), 3, "at_most", nrow(cell), 12L,
      nrow(cell) >= 11L && is.finite(bias) && abs(bias) <= 3
    )
  }
  pooled <- dplyr::filter(selected, replay_proper)
  gain <- .goal005_task2_audit_gain(pooled$model_rps, pooled$prior_rps)
  add(
    level, duration, "rps-gain-pooled", "mean RPS gain over no-data prior",
    "all", gain, 0.4, "at_least", nrow(pooled), 36L,
    nrow(pooled) >= 35L && is.finite(gain) && gain >= 0.4
  )
  for (richness in c(10L, 25L, 40L)) {
    cell <- dplyr::filter(
      selected,
      true_richness_manifest == .env$richness,
      replay_proper
    )
    gain <- .goal005_task2_audit_gain(cell$model_rps, cell$prior_rps)
    add(
      level, duration, "rps-gain-cell", "mean RPS gain over no-data prior",
      paste0("R", richness), gain, 0, "at_least", nrow(cell), 12L,
      nrow(cell) >= 11L && is.finite(gain) && gain >= 0
    )
  }
  for (richness in c(10L, 25L, 40L)) {
    cell <- dplyr::filter(
      selected,
      true_richness_manifest == .env$richness
    )
    covered <- sum(cell$replay_coverage)
    add(
      level, duration, "coverage-cell",
      "fixed-denominator 90% interval coverage", paste0("R", richness),
      covered / 12, 10 / 12, "at_least", covered, 12L,
      nrow(cell) == 12L && covered >= 10L
    )
  }
  widths <- selected |>
    dplyr::filter(replay_clean, is.finite(interval_90_width))
  width <- if (nrow(widths) > 0L) {
    stats::median(widths$interval_90_width)
  } else {
    NA_real_
  }
  add(
    level, duration, "interval-width", "median 90% interval width", "all",
    width, 25, "at_most", nrow(widths), 36L,
    nrow(widths) >= 35L && is.finite(width) && width <= 25
  )
  catastrophic <- sum(selected$replay_catastrophic)
  add(
    level, duration, "catastrophic-or-nonclean",
    "terminal non-clean or absolute error at least 12.5", "all",
    catastrophic, 2, "fewer_than", catastrophic, 36L,
    nrow(selected) == 36L && catastrophic < 2L
  )
  dplyr::bind_rows(rows)
}

#' Independently replay Goal005 Task 2 gates from compact fit/prior pairs
replay_goal005_task2_gates <- function(pairs) {
  required <- c(
    "information_level", "train_occasions", "replicate",
    "true_richness_manifest", "terminal_clean", "prediction_available",
    "point_estimate", "absolute_error", "model_rps", "prior_rps",
    "interval_90_covered", "interval_90_width"
  )
  valid <- inherits(pairs, "data.frame") &&
    all(required %in% names(pairs)) && nrow(pairs) == 360L &&
    setequal(unique(pairs$information_level), c("C0", "I0")) &&
    setequal(unique(pairs$train_occasions), c(4L, 8L, 12L, 16L, 26L))
  if (!valid) {
    .goal005_stop("Goal005 audit pairs differ from the frozen contract.")
  }
  lapply(c("C0", "I0"), function(level) {
    lapply(c(4L, 8L, 12L, 16L, 26L), function(duration) {
      .goal005_task2_replay_cell(pairs, level, duration)
    })
  }) |>
    unlist(recursive = FALSE) |>
    dplyr::bind_rows()
}

.goal005_task2_numeric_match <- function(x, y, tolerance = 1e-12) {
  (is.na(x) & is.na(y)) |
    (is.finite(x) & is.finite(y) & abs(x - y) <= tolerance)
}

.goal005_task2_compare_gates <- function(replayed, recorded) {
  keys <- c(
    "information_level", "train_occasions", "gate_id", "stratum"
  )
  if (!inherits(recorded, "data.frame") || nrow(recorded) != 170L ||
      anyDuplicated(recorded[keys]) || anyDuplicated(replayed[keys])) {
    .goal005_stop("Goal005 recorded gates have an invalid key contract.")
  }
  comparison <- replayed |>
    dplyr::rename_with(~ paste0(.x, "_replayed"), -dplyr::all_of(keys)) |>
    dplyr::full_join(
      recorded |>
        dplyr::rename_with(
          ~ paste0(.x, "_recorded"),
          -dplyr::all_of(keys)
        ),
      by = keys
    ) |>
    dplyr::mutate(
      metric_match = metric_replayed == metric_recorded,
      value_match = .goal005_task2_numeric_match(
        value_replayed,
        value_recorded
      ),
      threshold_match = .goal005_task2_numeric_match(
        threshold_replayed,
        threshold_recorded
      ),
      comparison_match = comparison_replayed == comparison_recorded,
      numerator_match = .goal005_task2_numeric_match(
        numerator_replayed,
        numerator_recorded
      ),
      denominator_match = denominator_replayed == denominator_recorded,
      passed_match = passed_replayed == passed_recorded,
      all_match = metric_match & value_match & threshold_match &
        comparison_match & numerator_match & denominator_match & passed_match
    )
  comparison
}

.goal005_task2_replay_decision <- function(gates) {
  summary <- gates |>
    dplyr::summarise(
      n_gates = dplyr::n(),
      n_passed = sum(passed),
      passed = all(passed),
      .by = c(information_level, train_occasions)
    ) |>
    dplyr::arrange(train_occasions, information_level)
  pruning <- summary |>
    dplyr::select(information_level, train_occasions, passed) |>
    tidyr::pivot_wider(
      names_from = information_level,
      values_from = passed,
      names_prefix = "pass_"
    ) |>
    dplyr::arrange(train_occasions) |>
    dplyr::mutate(
      task3_path = dplyr::case_when(
        !pass_I0 ~ "CLOSED_ORACLE_FAIL",
        !pass_C0 ~ "CANDIDATE_CALIBRATION_REQUIRED",
        .default = "CLASS_CALIBRATION_ELIGIBLE"
      )
    )
  list(duration_summary = summary, pruning = pruning)
}

#' Audit one completed Goal005 Task 2 compact evidence directory
audit_goal005_task2_results <- function(output_dir, expected_commit = NULL) {
  output_dir <- normalizePath(output_dir, mustWork = TRUE)
  root_status <- readLines(
    file.path(output_dir, "completion-status.txt"),
    warn = FALSE
  )
  result_status <- readLines(
    file.path(output_dir, "results", "completion-status.txt"),
    warn = FALSE
  )
  metadata <- readRDS(file.path(output_dir, "run-metadata.rds"))
  if (is.null(expected_commit)) {
    expected_commit <- metadata$git_commit
  }
  valid_status <- "status=TASK2_COMPLETE" %in% root_status &&
    "status=TASK2_COMPLETE" %in% result_status &&
    "empirical_outcomes_used=false" %in% root_status &&
    "empirical_outcomes_used=false" %in% result_status &&
    identical(metadata$git_commit, expected_commit) &&
    identical(metadata$empirical_outcomes_used, FALSE) &&
    !file.exists(file.path(output_dir, "execution-stop.txt"))
  if (!valid_status) {
    .goal005_stop("Goal005 Task 2 is not a valid completed frozen run.")
  }
  result_dir <- file.path(output_dir, "results")
  pairs <- tibble::as_tibble(utils::read.csv(
    file.path(result_dir, "information-ceiling-pairs.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  ))
  pairs$train_occasions <- as.integer(pairs$train_occasions)
  pairs$replicate <- as.integer(pairs$replicate)
  pairs$true_richness_manifest <- as.integer(pairs$true_richness_manifest)
  for (field in c(
    "terminal_clean", "prediction_available", "interval_90_covered"
  )) {
    pairs[[field]] <- as.logical(pairs[[field]])
  }
  recorded <- tibble::as_tibble(utils::read.csv(
    file.path(result_dir, "information-ceiling-gates.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  ))
  recorded$train_occasions <- as.integer(recorded$train_occasions)
  recorded$denominator <- as.integer(recorded$denominator)
  recorded$passed <- as.logical(recorded$passed)
  replayed <- replay_goal005_task2_gates(pairs)
  comparison <- .goal005_task2_compare_gates(replayed, recorded)
  if (nrow(comparison) != 170L || !all(comparison$all_match)) {
    .goal005_stop("Goal005 Task 2 independent gate replay disagrees.")
  }
  decision <- .goal005_task2_replay_decision(replayed)
  artifact_paths <- c(
    file.path(result_dir, c(
      "information-ceiling-pairs.csv", "information-ceiling-gates.csv",
      "duration-summary.csv", "task3-pruning.csv", "integrity-check.csv"
    )),
    file.path(output_dir, c(
      "completion-status.txt", "run-metadata.rds", "source-hashes.csv"
    ))
  )
  list(
    run_commit = expected_commit,
    replayed_gates = replayed,
    gate_comparison = comparison,
    duration_summary = decision$duration_summary,
    pruning = decision$pruning,
    artifact_hashes = tibble::tibble(
      path = substring(artifact_paths, nchar(output_dir) + 2L),
      sha256 = vapply(artifact_paths, function(path) {
        digest::digest(file = path, algo = "sha256", serialize = FALSE)
      }, character(1))
    )
  )
}
