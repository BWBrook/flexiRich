#' Independently replay Goal005 Task 4 profile gates from compact pairs
replay_goal005_task4_profile_gates <- function(pairs) {
  required <- c(
    "dataset_id", "information_level", "train_occasions", "replicate",
    "true_richness_manifest", "terminal_clean", "prediction_available",
    "point_estimate", "absolute_error", "model_rps", "prior_rps",
    "interval_90_covered", "interval_90_width"
  )
  profiles <- c("unbiased", "down_0.8", "up_1.25")
  valid <- inherits(pairs, "data.frame") &&
    all(required %in% names(pairs)) && nrow(pairs) == 108L &&
    setequal(unique(pairs$information_level), profiles) &&
    identical(unique(pairs$train_occasions), 12L)
  if (!valid) {
    .goal005_stop("Goal005 Task 4 audit pairs differ from the frozen contract.")
  }
  lapply(profiles, function(profile) {
    .goal005_task2_replay_cell(pairs, profile, 12L)
  }) |>
    dplyr::bind_rows()
}

.goal005_task4_replay_shifts <- function(pairs) {
  common <- c(
    "dataset_id", "true_richness_manifest", "replicate",
    "terminal_clean", "prediction_available", "point_estimate"
  )
  baseline <- pairs[pairs$information_level == "unbiased", common]
  names(baseline)[names(baseline) == "terminal_clean"] <-
    "unbiased_terminal_clean"
  names(baseline)[names(baseline) == "prediction_available"] <-
    "unbiased_prediction_available"
  names(baseline)[names(baseline) == "point_estimate"] <-
    "unbiased_point_estimate"
  rows <- lapply(c("down_0.8", "up_1.25"), function(profile) {
    biased <- pairs[pairs$information_level == profile, c(
      "information_level", common
    )]
    names(biased)[names(biased) == "information_level"] <- "bias_profile"
    names(biased)[names(biased) == "terminal_clean"] <-
      "biased_terminal_clean"
    names(biased)[names(biased) == "prediction_available"] <-
      "biased_prediction_available"
    names(biased)[names(biased) == "point_estimate"] <-
      "biased_point_estimate"
    joined <- merge(
      biased,
      baseline,
      by = c("dataset_id", "true_richness_manifest", "replicate"),
      all = TRUE,
      sort = FALSE
    )
    joined$proper_pair <- with(
      joined,
      biased_terminal_clean & unbiased_terminal_clean &
        biased_prediction_available & unbiased_prediction_available &
        is.finite(biased_point_estimate) &
        is.finite(unbiased_point_estimate)
    )
    joined$absolute_posterior_mean_shift <- ifelse(
      joined$proper_pair,
      abs(joined$biased_point_estimate - joined$unbiased_point_estimate),
      NA_real_
    )
    tibble::as_tibble(joined)
  })
  dplyr::bind_rows(rows) |>
    dplyr::arrange(
      match(bias_profile, c("down_0.8", "up_1.25")),
      dataset_id
    )
}

.goal005_task4_replay_shift_gates <- function(shifts) {
  rows <- lapply(c("down_0.8", "up_1.25"), function(profile) {
    selected <- shifts[shifts$bias_profile == profile, ]
    values <- selected$absolute_posterior_mean_shift[selected$proper_pair]
    n_proper <- length(values)
    median_shift <- if (n_proper) stats::median(values) else NA_real_
    maximum_shift <- if (n_proper) max(values) else NA_real_
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

.goal005_task4_compare_gates <- function(replayed, recorded, expected_rows) {
  keys <- c("information_level", "train_occasions", "gate_id", "stratum")
  if (!inherits(recorded, "data.frame") ||
      nrow(recorded) != expected_rows || nrow(replayed) != expected_rows ||
      anyDuplicated(recorded[keys]) || anyDuplicated(replayed[keys])) {
    .goal005_stop("Goal005 Task 4 recorded gates have an invalid contract.")
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

.goal005_task4_replay_decision <- function(profile_gates, shift_gates) {
  profile <- profile_gates |>
    dplyr::summarise(
      passed = dplyr::n() == 17L && all(passed),
      .by = information_level
    )
  unbiased <- profile$passed[profile$information_level == "unbiased"]
  if (!isTRUE(unbiased)) {
    "UNBIASED_REPLICATION_FAIL"
  } else if (all(profile$passed) && all(shift_gates$passed)) {
    "TRANSFER_ROBUST"
  } else {
    "TRANSFER_SENSITIVE"
  }
}

#' Audit one completed Goal005 Task 4 compact evidence directory
audit_goal005_task4_results <- function(output_dir, expected_commit = NULL) {
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
  valid_status <- "status=TASK4_COMPLETE" %in% root_status &&
    "status=TASK4_COMPLETE" %in% result_status &&
    "empirical_outcomes_used=false" %in% root_status &&
    "empirical_outcomes_used=false" %in% result_status &&
    identical(metadata$git_commit, expected_commit) &&
    identical(metadata$empirical_outcomes_used, FALSE) &&
    !file.exists(file.path(output_dir, "execution-stop.txt"))
  if (!valid_status) {
    .goal005_stop("Goal005 Task 4 is not a valid completed frozen run.")
  }
  result_dir <- file.path(output_dir, "results")
  read_table <- function(name) {
    tibble::as_tibble(utils::read.csv(
      file.path(result_dir, name),
      stringsAsFactors = FALSE,
      check.names = FALSE,
      na.strings = c("", "NA")
    ))
  }
  pairs <- read_table("calibration-pairs.csv")
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
  profile_recorded <- read_table("profile-gates.csv")
  shift_recorded <- read_table("shift-gates.csv")
  for (table in c("profile_recorded", "shift_recorded")) {
    value <- get(table)
    value$train_occasions <- as.integer(value$train_occasions)
    value$denominator <- as.integer(value$denominator)
    value$passed <- as.logical(value$passed)
    assign(table, value)
  }
  recorded_decision <- read_table("decision.csv")$decision[[1L]]
  replayed_profile <- replay_goal005_task4_profile_gates(pairs)
  replayed_shifts <- .goal005_task4_replay_shifts(pairs)
  replayed_shift_gates <- .goal005_task4_replay_shift_gates(replayed_shifts)
  profile_comparison <- .goal005_task4_compare_gates(
    replayed_profile,
    profile_recorded,
    51L
  )
  shift_comparison <- .goal005_task4_compare_gates(
    replayed_shift_gates,
    shift_recorded,
    6L
  )
  replayed_decision <- .goal005_task4_replay_decision(
    replayed_profile,
    replayed_shift_gates
  )
  valid <- nrow(profile_comparison) == 51L &&
    all(profile_comparison$all_match) &&
    nrow(shift_comparison) == 6L &&
    all(shift_comparison$all_match) &&
    identical(replayed_decision, recorded_decision)
  if (!valid) {
    .goal005_stop("Goal005 Task 4 independent replay disagrees.")
  }
  artifact_paths <- c(
    file.path(result_dir, c(
      "calibration-pairs.csv", "profile-gates.csv", "paired-shifts.csv",
      "shift-gates.csv", "all-gates.csv", "profile-summary.csv",
      "decision.csv", "integrity-check.csv"
    )),
    file.path(output_dir, c(
      "completion-status.txt", "run-metadata.rds", "source-hashes.csv"
    ))
  )
  list(
    run_commit = expected_commit,
    replayed_profile_gates = replayed_profile,
    profile_comparison = profile_comparison,
    replayed_shifts = replayed_shifts,
    replayed_shift_gates = replayed_shift_gates,
    shift_comparison = shift_comparison,
    decision = tibble::tibble(decision = replayed_decision),
    artifact_hashes = tibble::tibble(
      path = substring(artifact_paths, nchar(output_dir) + 2L),
      sha256 = vapply(artifact_paths, function(path) {
        digest::digest(file = path, algo = "sha256", serialize = FALSE)
      }, character(1))
    )
  )
}
