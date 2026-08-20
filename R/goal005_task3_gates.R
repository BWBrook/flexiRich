.goal005_task3_integrity <- function(manifest, fit_status, richness, pairs) {
  fit_scores <- dplyr::filter(richness, !is.na(fit_id))
  prior_scores <- dplyr::filter(
    richness,
    method == "goal005_prior",
    run_role == "prior_only"
  )
  required_status <- c(
    .goal005_task3_fit_fields,
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
  ids <- schemas &&
    nrow(manifest$datasets) == 108L &&
    nrow(manifest$fits) == 756L &&
    nrow(pairs) == 756L &&
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
    all(pairs$information_level %in% manifest$levels$precision_id) &&
    all(is.finite(pairs$multiplicative_factor)) &&
    all(is.finite(pairs$calibration_sd))
  passed <- isTRUE(schemas && ids && coherent)
  tibble::tibble(
    check_id = "complete-frozen-task3-evidence",
    expected_datasets = 108L,
    observed_datasets = if (is.list(manifest)) {
      nrow(manifest$datasets)
    } else {
      NA_integer_
    },
    expected_fits = 756L,
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
    passed = passed
  )
}

.goal005_task3_precision_summary <- function(manifest, gates) {
  raw <- gates |>
    dplyr::summarise(
      n_gates = dplyr::n(),
      n_passed = sum(passed),
      cell_pass = dplyr::n() == 17L && all(passed),
      .by = c(information_level, train_occasions)
    ) |>
    dplyr::left_join(
      manifest$levels,
      by = c("information_level" = "precision_id")
    ) |>
    dplyr::arrange(train_occasions, precision_code) |>
    dplyr::group_by(train_occasions) |>
    dplyr::mutate(
      prefix_pass = cummin(as.integer(cell_pass)) == 1L
    ) |>
    dplyr::ungroup()
  raw |>
    dplyr::select(
      information_level,
      precision_code,
      multiplicative_factor,
      calibration_sd,
      train_occasions,
      n_gates,
      n_passed,
      cell_pass,
      prefix_pass
    )
}

.goal005_task3_frontier <- function(precision_summary, integrity_passed) {
  rows <- lapply(c(12L, 16L, 26L), function(duration) {
    selected <- precision_summary |>
      dplyr::filter(train_occasions == .env$duration) |>
      dplyr::arrange(precision_code)
    c0_pass <- nrow(selected) == 7L &&
      identical(selected$information_level[[1L]], "C0") &&
      isTRUE(selected$cell_pass[[1L]])
    finite <- selected |>
      dplyr::filter(precision_code > 1L, prefix_pass)
    status <- if (!isTRUE(integrity_passed)) {
      "INVALID_EVIDENCE"
    } else if (!c0_pass) {
      "FRESH_ORACLE_FAIL"
    } else if (nrow(finite) == 0L) {
      "ORACLE_ONLY"
    } else {
      "CLASS_FRONTIER_FOUND"
    }
    coarsest <- if (identical(status, "CLASS_FRONTIER_FOUND")) {
      finite[nrow(finite), ]
    } else {
      NULL
    }
    tibble::tibble(
      train_occasions = duration,
      c0_pass = c0_pass,
      finite_raw_passes = sum(selected$precision_code > 1L & selected$cell_pass),
      finite_prefix_passes = nrow(finite),
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
      decision = status
    )
  })
  dplyr::bind_rows(rows)
}

#' Evaluate the frozen Goal005 Task 3 class-calibration frontier
evaluate_goal005_task3_gates <- function(
  manifest,
  fit_status,
  richness,
  integrity_passed = TRUE
) {
  if (!is.logical(integrity_passed) || length(integrity_passed) != 1L ||
      is.na(integrity_passed)) {
    .goal005_stop("Goal005 Task 3 integrity flag is invalid.")
  }
  pairs <- .goal005_task2_pairs(manifest, fit_status, richness)
  integrity <- .goal005_task3_integrity(
    manifest,
    fit_status,
    richness,
    pairs
  )
  integrity$passed <- integrity$passed & integrity_passed
  gate_rows <- lapply(c(12L, 16L, 26L), function(duration) {
    lapply(manifest$levels$precision_id, function(level) {
      selected <- pairs |>
        dplyr::filter(
          train_occasions == .env$duration,
          information_level == .env$level
        )
      .goal005_task2_cell_gates(selected, level, duration)
    })
  }) |>
    unlist(recursive = FALSE)
  gates <- dplyr::bind_rows(gate_rows)
  if (!isTRUE(integrity$passed[[1L]])) {
    gates$passed <- FALSE
  }
  if (nrow(gates) != 357L || anyNA(gates$passed)) {
    .goal005_stop("Goal005 Task 3 gate table is incomplete.")
  }
  precision_summary <- .goal005_task3_precision_summary(manifest, gates)
  frontier <- .goal005_task3_frontier(
    precision_summary,
    integrity$passed[[1L]]
  )
  list(
    integrity = integrity,
    pairs = pairs,
    gates = gates,
    precision_summary = precision_summary,
    frontier = frontier
  )
}
