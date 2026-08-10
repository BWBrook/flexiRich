if (!dir.exists("R") ||
    !file.exists(file.path("config", "goal003_candidate_pool.csv"))) {
  stop("Run this script from the flexiRich repository root.", call. = FALSE)
}

for (path in sort(list.files(
  "R",
  pattern = "\\.R$",
  full.names = TRUE
))) {
  source(path, local = FALSE)
}

input_path <- file.path("outputs", "goal003", "judbury_inputs.rds")
if (!file.exists(input_path)) {
  stop(
    "Build the pinned Judbury inputs before running Goal003 baselines.",
    call. = FALSE
  )
}
input <- readRDS(input_path)
if (!is.list(input) || !identical(names(input), c("weekly", "metadata"))) {
  stop("Goal003 Judbury inputs have an invalid schema.", call. = FALSE)
}

output_dir <- file.path("outputs", "goal003", "baselines-task2-v1")
if (file.exists(output_dir) || dir.exists(output_dir)) {
  stop("Goal003 Task 2 baseline output already exists.", call. = FALSE)
}
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

durations <- c(4L, 26L, 52L, 153L)
occasion_ids <- input$weekly$occasion_calendar$occasion_id
incidence_rows <- list()
curve_rows <- list()
richness_pmf_rows <- list()
prospective_rows <- list()
count_pmf_rows <- list()
identity_rows <- list()
diagnostic_rows <- list()

for (duration in durations) {
  training_ids <- occasion_ids[seq_len(duration)]
  analysis_data <- prepare_goal003_analysis_window(
    input$weekly,
    training_ids
  )
  incidence_primary <- make_goal003_incidence_sample(analysis_data)
  incidence_complete <- make_goal003_incidence_sample(
    analysis_data,
    complete_only = TRUE
  )
  for (sample in list(incidence_primary, incidence_complete)) {
    basis <- if (sample$complete_only) "complete_7_day" else "positive_effort"
    incidence_rows[[length(incidence_rows) + 1L]] <-
      estimate_goal003_incidence_richness(sample) |>
      dplyr::mutate(
        training_occasions = duration,
        sample_basis = basis,
        .before = 1L
      )
  }

  inext <- estimate_goal003_inext_curve(incidence_primary)
  curve_rows[[length(curve_rows) + 1L]] <- inext$curve |>
    dplyr::mutate(training_occasions = duration, .before = 1L)
  incidence_rows[[length(incidence_rows) + 1L]] <- tibble::tibble(
    training_occasions = duration,
    sample_basis = "positive_effort",
    method = "inext_asymptotic",
    eligible = TRUE,
    reason = NA_character_,
    raw_estimate = inext$asymptotic$raw_estimate,
    estimate = inext$asymptotic$estimate,
    exceeded_pool = inext$asymptotic$exceeded_pool,
    candidate_pool_size = length(incidence_primary$candidate_ids),
    observed_richness = incidence_primary$observed_richness,
    n_sampling_units = incidence_primary$n_sampling_units,
    Q1 = incidence_primary$frequency_counts[["Q1"]],
    Q2 = incidence_primary$frequency_counts[["Q2"]],
    Q3 = incidence_primary$frequency_counts[["Q3"]],
    Q4 = incidence_primary$frequency_counts[["Q4"]],
    complete_only = FALSE
  )

  observed_pmf <- goal003_observed_richness_pmf(incidence_primary)
  lower_pmf <- goal003_lower_bound_prior_pmf(incidence_primary)
  richness_pmf_rows[[length(richness_pmf_rows) + 1L]] <-
    observed_pmf |>
    dplyr::mutate(
      training_occasions = duration,
      method = "observed",
      .before = 1L
    )
  richness_pmf_rows[[length(richness_pmf_rows) + 1L]] <-
    lower_pmf |>
    dplyr::mutate(
      training_occasions = duration,
      method = "lower_bound_prior",
      .before = 1L
    )

  occupancy_data <- prepare_goal003_occupancy_data(analysis_data)
  occupancy_fit <- fit_goal003_occupancy(
    occupancy_data,
    seed = 300300L + duration,
    output_dir = file.path(
      output_dir,
      "occupancy_fits",
      paste0("weeks_", duration)
    ),
    rescue = TRUE,
    refresh = 0L
  )
  terminal_attempt <- if (
    identical(occupancy_fit$terminal_status, "primary_clean")
  ) {
    occupancy_fit$attempts$primary
  } else if (identical(occupancy_fit$terminal_status, "rescue_clean")) {
    occupancy_fit$attempts$rescue
  } else {
    occupancy_fit$attempts[[length(occupancy_fit$attempts)]]
  }
  terminal_metrics <- terminal_attempt$diagnostics$metrics
  if (is.null(terminal_metrics)) {
    terminal_metrics <- list(
      divergences = NA_integer_,
      treedepth_hits = NA_integer_,
      min_ebfmi = NA_real_,
      max_rhat = NA_real_,
      min_bulk_ess = NA_real_,
      min_tail_ess = NA_real_
    )
  }
  diagnostic_rows[[length(diagnostic_rows) + 1L]] <- tibble::tibble(
    training_occasions = duration,
    terminal_status = occupancy_fit$terminal_status,
    terminal_attempt_id = .env$terminal_attempt$attempt_id,
    elapsed_seconds = .env$terminal_attempt$elapsed_seconds,
    divergences = .env$terminal_metrics$divergences,
    treedepth_hits = .env$terminal_metrics$treedepth_hits,
    min_ebfmi = .env$terminal_metrics$min_ebfmi,
    max_rhat = .env$terminal_metrics$max_rhat,
    min_bulk_ess = .env$terminal_metrics$min_bulk_ess,
    min_tail_ess = .env$terminal_metrics$min_tail_ess,
    reasons = paste(
      .env$terminal_attempt$diagnostics$reasons,
      collapse = "; "
    )
  )
  occupancy_clean <- !identical(
    occupancy_fit$terminal_status,
    "final_nonclean"
  )

  has_future <- duration + 4L <= length(occasion_ids)
  future_ids <- if (has_future) {
    occasion_ids[duration + seq_len(4L)]
  } else {
    character()
  }
  future_effort <- if (has_future) {
    input$weekly$effort_weekly |>
      dplyr::filter(occasion_id %in% future_ids)
  } else {
    NULL
  }
  occupancy_prediction <- if (occupancy_clean) {
    predict_goal003_occupancy(occupancy_fit, future_effort)
  } else {
    NULL
  }
  if (occupancy_clean) {
    richness_pmf_rows[[length(richness_pmf_rows) + 1L]] <-
      occupancy_prediction$richness_pmf |>
      dplyr::mutate(
        training_occasions = duration,
        method = "community_occupancy",
        .before = 1L
      )
  }

  if (has_future) {
    observed_prediction <- predict_goal003_observed_new_species(
      incidence_primary
    )
    future_sampling_units <- as.integer(sum(future_effort$active_days > 0L))
    inext_prediction <- predict_goal003_inext_new_species(
      incidence_primary,
      future_sampling_units
    )
    prospective_rows[[length(prospective_rows) + 1L]] <- tibble::tibble(
      training_occasions = duration,
      forecast_occasions = 4L,
      method = c("observed", "inext"),
      eligible = c(TRUE, inext_prediction$eligible),
      reason = c(NA_character_, inext_prediction$reason),
      expected_new_species = c(
        0,
        inext_prediction$expected_new_species
      )
    )
    occupancy_reason <- if (occupancy_clean) {
      NA_character_
    } else {
      paste(terminal_attempt$diagnostics$reasons, collapse = "; ")
    }
    occupancy_expected <- if (occupancy_clean) {
      sum(
        occupancy_prediction$future_identity$
          future_first_detection_probability
      )
    } else {
      NA_real_
    }
    prospective_rows[[length(prospective_rows) + 1L]] <- tibble::tibble(
      training_occasions = duration,
      forecast_occasions = 4L,
      method = "community_occupancy",
      eligible = occupancy_clean,
      reason = occupancy_reason,
      expected_new_species = occupancy_expected
    )
    count_pmf_rows[[length(count_pmf_rows) + 1L]] <-
      observed_prediction$new_species_count_pmf |>
      dplyr::mutate(
        training_occasions = duration,
        method = "observed",
        .before = 1L
      )
    identity_rows[[length(identity_rows) + 1L]] <-
      observed_prediction$future_identity |>
      dplyr::mutate(
        training_occasions = duration,
        method = "observed",
        .before = 1L
      )
    if (occupancy_clean) {
      count_pmf_rows[[length(count_pmf_rows) + 1L]] <-
        occupancy_prediction$new_species_count_pmf |>
        dplyr::mutate(
          training_occasions = duration,
          method = "community_occupancy",
          .before = 1L
        )
      identity_rows[[length(identity_rows) + 1L]] <-
        occupancy_prediction$future_identity |>
        dplyr::mutate(
          training_occasions = duration,
          method = "community_occupancy",
          .before = 1L
        )
    }
  }
}

tables <- list(
  incidence_estimates = dplyr::bind_rows(incidence_rows),
  inext_curves = dplyr::bind_rows(curve_rows),
  richness_pmfs = dplyr::bind_rows(richness_pmf_rows),
  prospective_expected = dplyr::bind_rows(prospective_rows),
  prospective_count_pmfs = dplyr::bind_rows(count_pmf_rows),
  prospective_identity = dplyr::bind_rows(identity_rows),
  occupancy_diagnostics = dplyr::bind_rows(diagnostic_rows)
)
for (name in names(tables)) {
  utils::write.csv(
    tables[[name]],
    file.path(output_dir, paste0(name, ".csv")),
    row.names = FALSE,
    na = ""
  )
}
saveRDS(
  list(
    input_metadata = input$metadata,
    baseline_contract = "goal003-baseline-contract/1.0",
    iNEXT_version = as.character(utils::packageVersion("iNEXT")),
    durations = durations,
    tables = tables
  ),
  file.path(output_dir, "baseline_results.rds"),
  version = 3
)

cat(
  "Goal003 Task 2 cumulative baselines: PASS\n",
  "Output: ", normalizePath(output_dir, mustWork = TRUE), "\n",
  "Occupancy terminal states: ",
  paste(tables$occupancy_diagnostics$terminal_status, collapse = ", "),
  "\n",
  sep = ""
)
