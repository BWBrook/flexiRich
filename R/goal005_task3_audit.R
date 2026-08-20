#' Independently replay Goal005 Task 3 gates from compact fit/prior pairs
replay_goal005_task3_gates <- function(pairs) {
  required <- c(
    "information_level", "precision_code", "train_occasions", "replicate",
    "true_richness_manifest", "terminal_clean", "prediction_available",
    "point_estimate", "absolute_error", "model_rps", "prior_rps",
    "interval_90_covered", "interval_90_width"
  )
  levels <- c("C0", "F1.10", "F1.25", "F1.50", "F2", "F3", "F5")
  valid <- inherits(pairs, "data.frame") &&
    all(required %in% names(pairs)) && nrow(pairs) == 756L &&
    setequal(unique(pairs$information_level), levels) &&
    setequal(unique(pairs$precision_code), seq_along(levels)) &&
    setequal(unique(pairs$train_occasions), c(12L, 16L, 26L))
  if (!valid) {
    .goal005_stop("Goal005 Task 3 audit pairs differ from the frozen contract.")
  }
  lapply(levels, function(level) {
    lapply(c(12L, 16L, 26L), function(duration) {
      .goal005_task2_replay_cell(pairs, level, duration)
    })
  }) |>
    unlist(recursive = FALSE) |>
    dplyr::bind_rows()
}

.goal005_task3_compare_gates <- function(replayed, recorded) {
  keys <- c(
    "information_level", "train_occasions", "gate_id", "stratum"
  )
  if (!inherits(recorded, "data.frame") || nrow(recorded) != 357L ||
      nrow(replayed) != 357L || anyDuplicated(recorded[keys]) ||
      anyDuplicated(replayed[keys])) {
    .goal005_stop("Goal005 Task 3 recorded gates have an invalid contract.")
  }
  replayed |>
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
}

.goal005_task3_replay_frontier <- function(gates, levels) {
  level_order <- c("C0", "F1.10", "F1.25", "F1.50", "F2", "F3", "F5")
  valid_levels <- inherits(levels, "data.frame") && nrow(levels) == 7L &&
    identical(levels$precision_id, level_order) &&
    identical(as.integer(levels$precision_code), seq_along(level_order))
  if (!valid_levels) {
    .goal005_stop("Goal005 Task 3 audit levels differ from the frozen grid.")
  }
  summary <- gates |>
    dplyr::summarise(
      n_gates = dplyr::n(),
      n_passed = sum(passed),
      cell_pass = dplyr::n() == 17L && all(passed),
      .by = c(information_level, train_occasions)
    ) |>
    dplyr::left_join(
      levels[c(
        "precision_id", "precision_code", "multiplicative_factor",
        "calibration_sd"
      )],
      by = c("information_level" = "precision_id")
    ) |>
    dplyr::arrange(train_occasions, precision_code) |>
    dplyr::group_by(train_occasions) |>
    dplyr::mutate(prefix_pass = cummin(as.integer(cell_pass)) == 1L) |>
    dplyr::ungroup()
  frontier <- lapply(c(12L, 16L, 26L), function(duration) {
    selected <- dplyr::filter(summary, train_occasions == .env$duration)
    c0_pass <- nrow(selected) == 7L && isTRUE(selected$cell_pass[[1L]])
    finite <- dplyr::filter(selected, precision_code > 1L, prefix_pass)
    decision <- if (!c0_pass) {
      "FRESH_ORACLE_FAIL"
    } else if (nrow(finite) == 0L) {
      "ORACLE_ONLY"
    } else {
      "CLASS_FRONTIER_FOUND"
    }
    coarsest <- if (nrow(finite) > 0L && c0_pass) finite[nrow(finite), ] else NULL
    tibble::tibble(
      train_occasions = duration,
      c0_pass = c0_pass,
      finite_raw_passes = sum(
        selected$precision_code > 1L & selected$cell_pass
      ),
      finite_prefix_passes = if (c0_pass) nrow(finite) else 0L,
      coarsest_precision = if (is.null(coarsest)) {
        NA_character_
      } else {
        coarsest$information_level[[1L]]
      },
      coarsest_factor = if (is.null(coarsest)) {
        NA_real_
      } else {
        coarsest$multiplicative_factor[[1L]]
      },
      decision = decision
    )
  }) |>
    dplyr::bind_rows()
  list(precision_summary = summary, frontier = frontier)
}

.goal005_task3_frontier_match <- function(replayed, recorded) {
  keys <- "train_occasions"
  joined <- replayed |>
    dplyr::rename_with(~ paste0(.x, "_replayed"), -dplyr::all_of(keys)) |>
    dplyr::full_join(
      recorded |>
        dplyr::rename_with(
          ~ paste0(.x, "_recorded"),
          -dplyr::all_of(keys)
        ),
      by = keys
    )
  joined |>
    dplyr::mutate(
      c0_match = c0_pass_replayed == c0_pass_recorded,
      raw_match = finite_raw_passes_replayed == finite_raw_passes_recorded,
      prefix_match = finite_prefix_passes_replayed ==
        finite_prefix_passes_recorded,
      precision_match = dplyr::coalesce(
        coarsest_precision_replayed == coarsest_precision_recorded,
        is.na(coarsest_precision_replayed) &
          is.na(coarsest_precision_recorded)
      ),
      factor_match = .goal005_task2_numeric_match(
        coarsest_factor_replayed,
        coarsest_factor_recorded
      ),
      decision_match = decision_replayed == decision_recorded,
      all_match = c0_match & raw_match & prefix_match & precision_match &
        factor_match & decision_match
    )
}

#' Audit one completed Goal005 Task 3 compact evidence directory
audit_goal005_task3_results <- function(output_dir, expected_commit = NULL) {
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
  valid_status <- "status=TASK3_COMPLETE" %in% root_status &&
    "status=TASK3_COMPLETE" %in% result_status &&
    "empirical_outcomes_used=false" %in% root_status &&
    "empirical_outcomes_used=false" %in% result_status &&
    identical(metadata$git_commit, expected_commit) &&
    identical(metadata$empirical_outcomes_used, FALSE) &&
    !file.exists(file.path(output_dir, "execution-stop.txt"))
  if (!valid_status) {
    .goal005_stop("Goal005 Task 3 is not a valid completed frozen run.")
  }
  result_dir <- file.path(output_dir, "results")
  pairs <- tibble::as_tibble(utils::read.csv(
    file.path(result_dir, "calibration-pairs.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  ))
  for (field in c(
    "precision_code", "train_occasions", "replicate",
    "true_richness_manifest"
  )) {
    pairs[[field]] <- as.integer(pairs[[field]])
  }
  for (field in c(
    "terminal_clean", "prediction_available", "interval_90_covered"
  )) {
    pairs[[field]] <- as.logical(pairs[[field]])
  }
  recorded_gates <- tibble::as_tibble(utils::read.csv(
    file.path(result_dir, "calibration-gates.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  ))
  recorded_gates$train_occasions <- as.integer(
    recorded_gates$train_occasions
  )
  recorded_gates$denominator <- as.integer(recorded_gates$denominator)
  recorded_gates$passed <- as.logical(recorded_gates$passed)
  levels <- tibble::as_tibble(utils::read.csv(
    file.path(
      output_dir,
      "manifests",
      "goal005_task3_calibration_levels.csv"
    ),
    stringsAsFactors = FALSE,
    check.names = FALSE
  ))
  recorded_frontier <- tibble::as_tibble(utils::read.csv(
    file.path(result_dir, "frontier-summary.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = c("", "NA")
  ))
  recorded_frontier$train_occasions <- as.integer(
    recorded_frontier$train_occasions
  )
  recorded_frontier$finite_raw_passes <- as.integer(
    recorded_frontier$finite_raw_passes
  )
  recorded_frontier$finite_prefix_passes <- as.integer(
    recorded_frontier$finite_prefix_passes
  )
  recorded_frontier$c0_pass <- as.logical(recorded_frontier$c0_pass)

  replayed_gates <- replay_goal005_task3_gates(pairs)
  gate_comparison <- .goal005_task3_compare_gates(
    replayed_gates,
    recorded_gates
  )
  replayed <- .goal005_task3_replay_frontier(replayed_gates, levels)
  frontier_comparison <- .goal005_task3_frontier_match(
    replayed$frontier,
    recorded_frontier
  )
  if (nrow(gate_comparison) != 357L ||
      !all(gate_comparison$all_match) ||
      nrow(frontier_comparison) != 3L ||
      !all(frontier_comparison$all_match)) {
    .goal005_stop("Goal005 Task 3 independent replay disagrees.")
  }
  artifact_paths <- c(
    file.path(result_dir, c(
      "calibration-pairs.csv", "calibration-gates.csv",
      "precision-summary.csv", "frontier-summary.csv", "integrity-check.csv"
    )),
    file.path(output_dir, c(
      "completion-status.txt", "run-metadata.rds", "source-hashes.csv"
    ))
  )
  list(
    run_commit = expected_commit,
    replayed_gates = replayed_gates,
    gate_comparison = gate_comparison,
    precision_summary = replayed$precision_summary,
    frontier = replayed$frontier,
    frontier_comparison = frontier_comparison,
    artifact_hashes = tibble::tibble(
      path = substring(artifact_paths, nchar(output_dir) + 2L),
      sha256 = vapply(artifact_paths, function(path) {
        digest::digest(file = path, algo = "sha256", serialize = FALSE)
      }, character(1))
    )
  )
}
