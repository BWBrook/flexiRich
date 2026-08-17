.goal004_task4_gate_row <- function(
  gate_id,
  metric,
  value,
  threshold,
  comparison,
  numerator = NA_real_,
  denominator = NA_integer_,
  passed = FALSE
) {
  tibble::tibble(
    gate_id = gate_id,
    metric = metric,
    value = as.numeric(value),
    threshold = as.numeric(threshold),
    comparison = comparison,
    numerator = as.numeric(numerator),
    denominator = as.integer(denominator),
    passed = isTRUE(passed)
  )
}

.goal004_task4_gate_value <- function(value, default = NA_real_) {
  if (length(value) == 1L && is.numeric(value) && is.finite(value)) {
    as.numeric(value)
  } else {
    default
  }
}

.goal004_task4_gate_gain <- function(model, comparator) {
  keep <- is.finite(model) & is.finite(comparator)
  if (!any(keep) || mean(comparator[keep]) <= 0) {
    return(NA_real_)
  }
  1 - mean(model[keep]) / mean(comparator[keep])
}

.goal004_task4_gate_ratio <- function(model, comparator) {
  keep <- is.finite(model) & is.finite(comparator)
  if (!any(keep) || mean(comparator[keep]) <= 0) {
    return(NA_real_)
  }
  mean(model[keep]) / mean(comparator[keep])
}

.goal004_task4_gate_context <- function(manifest, table) {
  table |>
    dplyr::left_join(
      manifest$datasets |>
        dplyr::select(
          dataset_id,
          pair_id,
          fidelity,
          true_richness_manifest = true_richness,
          train_occasions,
          replicate
        ),
      by = "dataset_id"
    )
}

.goal004_task4_gate_primary_pairs <- function(manifest, richness) {
  model <- richness |>
    dplyr::filter(method == "goal004", run_role == "primary") |>
    dplyr::transmute(
      dataset_id,
      fit_id,
      model_terminal_clean = terminal_clean,
      model_prediction_available = prediction_available,
      true_richness,
      model_point_estimate = point_estimate,
      model_absolute_error = absolute_error,
      model_rps = rps,
      model_interval_covered = interval_90_covered,
      model_interval_width = interval_90_width
    )
  prior <- richness |>
    dplyr::filter(
      method == "goal004_prior",
      run_role == "prior_only",
      prior_profile == "primary"
    ) |>
    dplyr::transmute(
      dataset_id,
      prior_point_estimate = point_estimate,
      prior_rps = rps
    )
  .goal004_task4_gate_context(
    manifest,
    dplyr::left_join(model, prior, by = "dataset_id")
  ) |>
    dplyr::mutate(
      signed_bias = model_point_estimate - true_richness,
      proper_pair = model_terminal_clean &
        is.finite(model_rps) & is.finite(prior_rps)
    )
}

.goal004_task4_gate_membership_pairs <- function(manifest, membership) {
  model <- membership |>
    dplyr::filter(method == "goal004", run_role == "primary") |>
    dplyr::transmute(
      dataset_id,
      model_terminal_clean = terminal_clean,
      model_brier = unseen_candidate_brier
    )
  prior <- membership |>
    dplyr::filter(
      method == "goal004_prior",
      run_role == "prior_only",
      prior_profile == "primary"
    ) |>
    dplyr::transmute(dataset_id, prior_brier = unseen_candidate_brier)
  .goal004_task4_gate_context(
    manifest,
    dplyr::left_join(model, prior, by = "dataset_id")
  ) |>
    dplyr::mutate(
      proper_pair = model_terminal_clean &
        is.finite(model_brier) & is.finite(prior_brier)
    )
}

.goal004_task4_gate_discovery_pairs <- function(manifest, discovery) {
  model <- discovery |>
    dplyr::filter(method == "goal004", run_role == "primary") |>
    dplyr::transmute(
      dataset_id,
      model_terminal_clean = terminal_clean,
      model_count_rps = count_rps,
      model_identity_brier = identity_brier
    )
  prior <- discovery |>
    dplyr::filter(
      method == "goal004_prior",
      run_role == "prior_only",
      prior_profile == "primary"
    ) |>
    dplyr::transmute(
      dataset_id,
      prior_count_rps = count_rps,
      prior_identity_brier = identity_brier
    )
  .goal004_task4_gate_context(
    manifest,
    dplyr::left_join(model, prior, by = "dataset_id")
  )
}

.goal004_task4_exact_ids <- function(observed, expected) {
  length(observed) == length(expected) && !anyNA(observed) &&
    !anyDuplicated(observed) && setequal(observed, expected)
}

#' Evaluate the frozen Goal004 Task 4 development gates
evaluate_goal004_task4_gates <- function(
  manifest,
  fit_status,
  richness,
  discovery,
  membership,
  nested_pairs,
  sensitivity_pairs,
  integrity_passed = TRUE
) {
  required_manifest <- c("datasets", "fits")
  if (!is.list(manifest) ||
      !all(required_manifest %in% names(manifest)) ||
      !is.logical(integrity_passed) || length(integrity_passed) != 1L ||
      is.na(integrity_passed)) {
    .goal004_task4_stop("Invalid Goal004 Task 4 gate inputs.")
  }
  required <- list(
    fit_status = c(
      "fit_id", "dataset_id", "method", "run_role", "prior_profile",
      "terminal_clean", "elapsed_seconds"
    ),
    richness = c(
      "dataset_id", "fit_id", "method", "run_role", "prior_profile",
      "terminal_clean", "prediction_available", "true_richness",
      "point_estimate", "absolute_error", "rps", "interval_90_covered",
      "interval_90_width"
    ),
    discovery = c(
      "dataset_id", "fit_id", "method", "run_role", "prior_profile",
      "terminal_clean", "count_rps", "identity_brier"
    ),
    membership = c(
      "dataset_id", "fit_id", "method", "run_role", "prior_profile",
      "terminal_clean", "unseen_candidate_brier"
    ),
    nested_pairs = c(
      "dataset_id", "fit_id", "train_occasions", "replicate",
      "terminal_clean", "primary_terminal_clean", "abs_core_mean_shift",
      "core_pmf_total_variation"
    ),
    sensitivity_pairs = c(
      "dataset_id", "fit_id", "prior_profile", "fidelity",
      "true_richness", "train_occasions", "replicate",
      "terminal_clean", "primary_terminal_clean",
      "primary_point_estimate", "sensitivity_point_estimate",
      "abs_mean_shift", "primary_rps", "sensitivity_rps",
      "own_prior_rps"
    )
  )
  supplied <- list(
    fit_status = fit_status,
    richness = richness,
    discovery = discovery,
    membership = membership,
    nested_pairs = nested_pairs,
    sensitivity_pairs = sensitivity_pairs
  )
  valid_schema <- all(vapply(names(required), function(name) {
    inherits(supplied[[name]], "data.frame") &&
      all(required[[name]] %in% names(supplied[[name]]))
  }, logical(1)))
  if (!valid_schema) {
    .goal004_task4_stop("A Goal004 Task 4 gate table has an invalid schema.")
  }

  gates <- list()
  add <- function(...) {
    gates[[length(gates) + 1L]] <<- .goal004_task4_gate_row(...)
  }
  fit_richness <- dplyr::filter(richness, !is.na(fit_id))
  fit_discovery <- dplyr::filter(discovery, !is.na(fit_id))
  fit_membership <- dplyr::filter(membership, !is.na(fit_id))
  expected_sensitivity <- manifest$fits |>
    dplyr::filter(run_role == "prior_sensitivity") |>
    dplyr::pull(fit_id)
  expected_nested <- manifest$fits |>
    dplyr::filter(run_role == "pool_sensitivity") |>
    dplyr::pull(fit_id)
  integrity <- integrity_passed &&
    nrow(manifest$datasets) == 180L && nrow(manifest$fits) == 750L &&
    .goal004_task4_exact_ids(fit_status$fit_id, manifest$fits$fit_id) &&
    .goal004_task4_exact_ids(fit_richness$fit_id, manifest$fits$fit_id) &&
    .goal004_task4_exact_ids(fit_discovery$fit_id, manifest$fits$fit_id) &&
    .goal004_task4_exact_ids(fit_membership$fit_id, manifest$fits$fit_id) &&
    .goal004_task4_exact_ids(nested_pairs$fit_id, expected_nested) &&
    .goal004_task4_exact_ids(
      sensitivity_pairs$fit_id,
      expected_sensitivity
    )
  add(
    "G01-integrity", "complete frozen evidence contract",
    as.numeric(integrity), 1, "equal", as.numeric(integrity), 1L,
    integrity
  )

  status <- .goal004_task4_gate_context(manifest, fit_status)
  clean_total <- function(method, run_role, profile = NULL) {
    selected <- status |>
      dplyr::filter(
        .data$method == .env$method,
        .data$run_role == .env$run_role
      )
    if (!is.null(profile)) {
      selected <- dplyr::filter(
        selected,
        prior_profile == .env$profile
      )
    }
    c(sum(selected$terminal_clean), nrow(selected))
  }
  for (definition in list(
    c("goal004-primary", "goal004", "primary", NA, 171),
    c("goal003-primary", "goal003", "primary", NA, 171),
    c("occupancy-primary", "occupancy", "primary", NA, 171),
    c("nested", "goal004_nested", "pool_sensitivity", NA, 29)
  )) {
    count <- clean_total(
      definition[[2L]],
      definition[[3L]],
      if (is.na(definition[[4L]])) NULL else definition[[4L]]
    )
    threshold <- as.numeric(definition[[5L]])
    add(
      paste0("G02-clean-", definition[[1L]]),
      "terminal-clean scheduled fits", count[[1L]], threshold,
      "at_least", count[[1L]], count[[2L]], count[[1L]] >= threshold
    )
  }
  primary_cells <- status |>
    dplyr::filter(method == "goal004", run_role == "primary") |>
    dplyr::summarise(
      clean = sum(terminal_clean),
      scheduled = dplyr::n(),
      .by = c(fidelity, true_richness_manifest, train_occasions)
    )
  for (index in seq_len(nrow(primary_cells))) {
    cell <- primary_cells[index, ]
    add(
      sprintf(
        "G02-clean-cell-%s-R%02d-%02dw",
        cell$fidelity,
        cell$true_richness_manifest,
        cell$train_occasions
      ),
      "terminal-clean fits in primary cell",
      cell$clean, 8, "at_least", cell$clean, cell$scheduled,
      cell$clean >= 8
    )
  }
  for (profile in c(
    "rate_lower", "rate_higher", "spread_wider",
    "membership_regularised"
  )) {
    count <- clean_total("goal004", "prior_sensitivity", profile)
    add(
      paste0("G02-clean-sensitivity-", profile),
      "terminal-clean sensitivity fits", count[[1L]], 29, "at_least",
      count[[1L]], count[[2L]], count[[1L]] >= 29
    )
  }
  count <- clean_total("goal004", "prior_sensitivity", "class_blur")
  add(
    "G02-clean-sensitivity-class_blur",
    "terminal-clean class-blur fits", count[[1L]], 57, "at_least",
    count[[1L]], count[[2L]], count[[1L]] >= 57
  )

  primary <- .goal004_task4_gate_primary_pairs(manifest, richness)
  separation <- function(table, fidelity, duration) {
    selected <- table |>
      dplyr::filter(
        .data$fidelity == .env$fidelity,
        train_occasions == .env$duration,
        true_richness %in% c(10L, 40L),
        model_terminal_clean
      )
    low <- selected |>
      dplyr::filter(true_richness == 10L) |>
      dplyr::select(replicate, low = model_point_estimate)
    high <- selected |>
      dplyr::filter(true_richness == 40L) |>
      dplyr::select(replicate, high = model_point_estimate)
    values <- dplyr::inner_join(high, low, by = "replicate") |>
      dplyr::mutate(separation = high - low) |>
      dplyr::pull(separation)
    list(value = if (length(values)) stats::median(values) else NA_real_, n = length(values))
  }
  learning_gate <- function(duration, prefix, separation_limit, bias_limit,
                            rps_gain_limit, width_limit) {
    sep <- separation(primary, "aligned", duration)
    add(
      paste0(prefix, "-separation"), "median high-minus-low separation",
      sep$value, separation_limit, "at_least", NA_real_, sep$n,
      is.finite(sep$value) && sep$value >= separation_limit
    )
    cells <- primary |>
      dplyr::filter(
        fidelity == "aligned",
        train_occasions == .env$duration
      ) |>
      dplyr::summarise(
        median_signed_bias = if (any(model_terminal_clean)) {
          stats::median(signed_bias[model_terminal_clean], na.rm = TRUE)
        } else NA_real_,
        coverage = sum(model_terminal_clean & model_interval_covered),
        median_width = if (any(model_terminal_clean)) {
          stats::median(model_interval_width[model_terminal_clean], na.rm = TRUE)
        } else NA_real_,
        scheduled = dplyr::n(),
        .by = true_richness
      )
    for (index in seq_len(nrow(cells))) {
      cell <- cells[index, ]
      bias_value <- abs(cell$median_signed_bias)
      add(
        sprintf("%s-bias-R%02d", prefix, cell$true_richness),
        "absolute median signed bias", bias_value, bias_limit, "at_most",
        NA_real_, cell$scheduled,
        is.finite(bias_value) && bias_value <= bias_limit
      )
      add(
        sprintf("%s-coverage-R%02d", prefix, cell$true_richness),
        "fixed-denominator 90% coverage", cell$coverage, 8, "at_least",
        cell$coverage, cell$scheduled, cell$coverage >= 8
      )
      add(
        sprintf("%s-width-R%02d", prefix, cell$true_richness),
        "median 90% interval width", cell$median_width, width_limit,
        "at_most", NA_real_, sum(
          primary$fidelity == "aligned" &
            primary$train_occasions == duration &
            primary$true_richness == cell$true_richness &
            primary$model_terminal_clean
        ),
        is.finite(cell$median_width) && cell$median_width <= width_limit
      )
    }
    paired <- primary |>
      dplyr::filter(
        fidelity == "aligned",
        train_occasions == .env$duration,
        proper_pair
      )
    gain <- .goal004_task4_gate_gain(paired$model_rps, paired$prior_rps)
    add(
      paste0(prefix, "-pooled-rps-gain"),
      "pooled richness RPS gain over matching prior", gain,
      rps_gain_limit, "at_least", NA_real_, nrow(paired),
      is.finite(gain) && gain >= rps_gain_limit
    )
    cell_gain <- paired |>
      dplyr::summarise(
        gain = .goal004_task4_gate_gain(model_rps, prior_rps),
        scored = dplyr::n(),
        .by = true_richness
      )
    for (index in seq_len(nrow(cell_gain))) {
      cell <- cell_gain[index, ]
      add(
        sprintf("%s-rps-nonnegative-R%02d", prefix, cell$true_richness),
        "cell richness RPS gain over matching prior", cell$gain, 0,
        "at_least", NA_real_, cell$scored,
        is.finite(cell$gain) && cell$gain >= 0
      )
    }
  }
  learning_gate(4L, "G03-aligned-04w", 20, 7.5, 0.20, 40)
  learning_gate(26L, "G04-aligned-26w", 27, 3, 0.40, 25)

  for (fidelity in c("weak_signal", "ten_percent_flipped")) {
    for (duration in c(4L, 26L)) {
      prefix <- sprintf("G05-%s-%02dw", fidelity, duration)
      sep <- separation(primary, fidelity, duration)
      limit <- if (duration == 4L) 15 else 24
      add(
        paste0(prefix, "-separation"),
        "median high-minus-low separation", sep$value, limit, "at_least",
        NA_real_, sep$n, is.finite(sep$value) && sep$value >= limit
      )
      selected <- primary |>
        dplyr::filter(
          .data$fidelity == .env$fidelity,
          train_occasions == .env$duration
        )
      coverage <- selected |>
        dplyr::summarise(
          covered = sum(model_terminal_clean & model_interval_covered),
          scheduled = dplyr::n(),
          .by = true_richness
        )
      for (index in seq_len(nrow(coverage))) {
        cell <- coverage[index, ]
        add(
          sprintf("%s-coverage-R%02d", prefix, cell$true_richness),
          "fixed-denominator 90% coverage", cell$covered, 7, "at_least",
          cell$covered, cell$scheduled, cell$covered >= 7
        )
      }
      paired <- dplyr::filter(selected, proper_pair)
      ratio <- .goal004_task4_gate_ratio(paired$model_rps, paired$prior_rps)
      add(
        paste0(prefix, "-prior-rps-ratio"),
        "mean richness RPS ratio to matching prior", ratio, 1.05,
        "at_most", NA_real_, nrow(paired),
        is.finite(ratio) && ratio <= 1.05
      )
    }
  }
  misspecified <- primary |>
    dplyr::filter(fidelity %in% c("weak_signal", "ten_percent_flipped"))
  catastrophic <- sum(
    !misspecified$model_terminal_clean |
      (is.finite(misspecified$model_absolute_error) &
        misspecified$model_absolute_error >= 12.5)
  )
  add(
    "G05-catastrophic-or-nonclean", "catastrophic or non-clean fits",
    catastrophic, 6, "fewer_than", catastrophic, nrow(misspecified),
    nrow(misspecified) == 120L && catastrophic < 6
  )

  membership_pairs <- .goal004_task4_gate_membership_pairs(
    manifest,
    membership
  )
  for (duration in c(4L, 26L)) {
    selected <- membership_pairs |>
      dplyr::filter(
        fidelity == "aligned",
        train_occasions == .env$duration,
        proper_pair
      )
    gain <- .goal004_task4_gate_gain(
      selected$model_brier,
      selected$prior_brier
    )
    limit <- if (duration == 4L) 0.05 else 0.15
    add(
      sprintf("G06-aligned-membership-%02dw", duration),
      "unseen-candidate Brier gain over 0.25 prior", gain, limit,
      "at_least", NA_real_, nrow(selected),
      is.finite(gain) && gain >= limit
    )
  }
  for (fidelity in c("weak_signal", "ten_percent_flipped")) {
    for (duration in c(4L, 26L)) {
      selected <- membership_pairs |>
        dplyr::filter(
          .data$fidelity == .env$fidelity,
          train_occasions == .env$duration,
          proper_pair
        )
      value <- if (nrow(selected)) mean(selected$model_brier) else NA_real_
      add(
        sprintf("G06-%s-membership-%02dw", fidelity, duration),
        "mean unseen-candidate Brier", value, 0.25 * 1.05,
        "at_most", NA_real_, nrow(selected),
        is.finite(value) && value <= 0.25 * 1.05
      )
    }
  }

  discovery_pairs <- .goal004_task4_gate_discovery_pairs(
    manifest,
    discovery
  )
  for (duration in c(4L, 26L)) {
    selected <- discovery_pairs |>
      dplyr::filter(
        fidelity == "aligned",
        train_occasions == .env$duration,
        model_terminal_clean,
        is.finite(model_count_rps),
        is.finite(prior_count_rps)
      )
    ratio <- .goal004_task4_gate_ratio(
      selected$model_count_rps,
      selected$prior_count_rps
    )
    add(
      sprintf("G07-discovery-count-%02dw", duration),
      "future-discovery count RPS ratio to prior", ratio, 1,
      "strictly_less", NA_real_, nrow(selected),
      is.finite(ratio) && ratio < 1
    )
    identity <- dplyr::filter(
      selected,
      is.finite(model_identity_brier),
      is.finite(prior_identity_brier)
    )
    gain <- .goal004_task4_gate_gain(
      identity$model_identity_brier,
      identity$prior_identity_brier
    )
    add(
      sprintf("G07-discovery-identity-%02dw", duration),
      "future-identity Brier gain over prior", gain, 0.05,
      "at_least", NA_real_, nrow(identity),
      is.finite(gain) && gain >= 0.05
    )
  }

  for (duration in c(4L, 26L)) {
    base <- primary |>
      dplyr::filter(
        fidelity == "aligned",
        train_occasions == .env$duration,
        model_terminal_clean,
        is.finite(model_rps)
      ) |>
      dplyr::select(dataset_id, model_rps)
    for (comparator in c("goal003", "occupancy")) {
      other <- richness |>
        dplyr::filter(
          method == .env$comparator,
          run_role == "primary",
          terminal_clean,
          is.finite(rps)
        ) |>
        dplyr::select(dataset_id, comparator_rps = rps)
      paired <- dplyr::inner_join(base, other, by = "dataset_id")
      ratio <- .goal004_task4_gate_ratio(
        paired$model_rps,
        paired$comparator_rps
      )
      limit <- if (duration == 4L && comparator == "goal003") 0.90 else 1.05
      add(
        sprintf("G08-%s-%02dw", comparator, duration),
        "Goal004 richness RPS ratio to comparator", ratio, limit,
        "at_most", NA_real_, nrow(paired),
        is.finite(ratio) && ratio <= limit
      )
    }
  }

  for (duration in c(4L, 26L)) {
    paired <- nested_pairs |>
      dplyr::filter(
        train_occasions == .env$duration,
        terminal_clean,
        primary_terminal_clean
      )
    values <- list(
      median_shift = c(
        if (nrow(paired)) stats::median(paired$abs_core_mean_shift) else NA_real_,
        0.5,
        "at_most"
      ),
      median_tv = c(
        if (nrow(paired)) stats::median(paired$core_pmf_total_variation) else NA_real_,
        0.05,
        "at_most"
      ),
      maximum_shift = c(
        if (nrow(paired)) max(paired$abs_core_mean_shift) else NA_real_,
        2,
        "at_most"
      ),
      maximum_tv = c(
        if (nrow(paired)) max(paired$core_pmf_total_variation) else NA_real_,
        0.15,
        "at_most"
      )
    )
    for (name in names(values)) {
      value <- as.numeric(values[[name]][[1L]])
      limit <- as.numeric(values[[name]][[2L]])
      add(
        sprintf("G09-nested-%s-%02dw", name, duration),
        gsub("_", " ", name), value, limit, "at_most", NA_real_,
        nrow(paired), is.finite(value) && value <= limit
      )
    }
  }

  stable_profiles <- c(
    spread_wider = 1,
    class_blur = 1,
    membership_regularised = 1,
    rate_lower = 3.5,
    rate_higher = 3.5
  )
  maximum_limits <- c(
    spread_wider = 3,
    class_blur = 3,
    membership_regularised = 3,
    rate_lower = 8,
    rate_higher = 8
  )
  for (profile in names(stable_profiles)) {
    for (duration in c(4L, 26L)) {
      paired <- sensitivity_pairs |>
        dplyr::filter(
          prior_profile == .env$profile,
          fidelity == "aligned",
          train_occasions == .env$duration,
          terminal_clean,
          primary_terminal_clean
        )
      median_shift <- if (nrow(paired)) {
        stats::median(paired$abs_mean_shift)
      } else NA_real_
      maximum_shift <- if (nrow(paired)) max(paired$abs_mean_shift) else NA_real_
      add(
        sprintf("G10-%s-median-shift-%02dw", profile, duration),
        "median absolute posterior-mean shift", median_shift,
        stable_profiles[[profile]], "at_most", NA_real_, nrow(paired),
        is.finite(median_shift) && median_shift <= stable_profiles[[profile]]
      )
      add(
        sprintf("G10-%s-maximum-shift-%02dw", profile, duration),
        "maximum absolute posterior-mean shift", maximum_shift,
        maximum_limits[[profile]], "at_most", NA_real_, nrow(paired),
        is.finite(maximum_shift) && maximum_shift <= maximum_limits[[profile]]
      )
    }
  }
  for (profile in c("rate_lower", "rate_higher")) {
    selected <- sensitivity_pairs |>
      dplyr::filter(
        prior_profile == .env$profile,
        fidelity == "aligned",
        train_occasions == 4L,
        terminal_clean,
        primary_terminal_clean
      )
    low <- selected |>
      dplyr::filter(true_richness == 10L) |>
      dplyr::select(replicate, low = sensitivity_point_estimate)
    high <- selected |>
      dplyr::filter(true_richness == 40L) |>
      dplyr::select(replicate, high = sensitivity_point_estimate)
    difference <- dplyr::inner_join(high, low, by = "replicate") |>
      dplyr::mutate(value = high - low) |>
      dplyr::pull(value)
    separation_value <- if (length(difference)) {
      stats::median(difference)
    } else NA_real_
    add(
      paste0("G10-", profile, "-04w-separation"),
      "median high-minus-low separation", separation_value, 15,
      "at_least", NA_real_, length(difference),
      is.finite(separation_value) && separation_value >= 15
    )
    gain <- .goal004_task4_gate_gain(
      selected$sensitivity_rps,
      selected$own_prior_rps
    )
    add(
      paste0("G10-", profile, "-04w-own-prior-gain"),
      "four-week richness RPS gain over own prior", gain, 0,
      "strictly_greater", NA_real_, nrow(selected),
      is.finite(gain) && gain > 0
    )
  }
  for (duration in c(4L, 26L)) {
    paired <- sensitivity_pairs |>
      dplyr::filter(
        prior_profile == "class_blur",
        fidelity == "ten_percent_flipped",
        train_occasions == .env$duration,
        terminal_clean,
        primary_terminal_clean
      )
    ratio <- .goal004_task4_gate_ratio(
      paired$sensitivity_rps,
      paired$primary_rps
    )
    add(
      sprintf("G10-class_blur-flipped-rps-%02dw", duration),
      "class-blur RPS ratio to primary fit", ratio, 1.05,
      "at_most", NA_real_, nrow(paired),
      is.finite(ratio) && ratio <= 1.05
    )
  }

  primary_runtime <- status |>
    dplyr::filter(
      method == "goal004",
      run_role == "primary",
      terminal_clean
    )
  median_runtime <- if (nrow(primary_runtime)) {
    stats::median(primary_runtime$elapsed_seconds)
  } else NA_real_
  p95_runtime <- if (nrow(primary_runtime)) {
    as.numeric(stats::quantile(
      primary_runtime$elapsed_seconds,
      0.95,
      names = FALSE,
      type = 7
    ))
  } else NA_real_
  add(
    "G11-runtime-median", "median Goal004 runtime seconds",
    median_runtime, 300, "at_most", NA_real_, nrow(primary_runtime),
    is.finite(median_runtime) && median_runtime <= 300
  )
  add(
    "G11-runtime-p95", "95th-percentile Goal004 runtime seconds",
    p95_runtime, 900, "strictly_less", NA_real_, nrow(primary_runtime),
    is.finite(p95_runtime) && p95_runtime < 900
  )
  runtime_goal004 <- primary_runtime |>
    dplyr::select(dataset_id, goal004_seconds = elapsed_seconds)
  runtime_occupancy <- status |>
    dplyr::filter(
      method == "occupancy",
      run_role == "primary",
      terminal_clean
    ) |>
    dplyr::select(dataset_id, occupancy_seconds = elapsed_seconds)
  runtime_pair <- dplyr::inner_join(
    runtime_goal004,
    runtime_occupancy,
    by = "dataset_id"
  ) |>
    dplyr::filter(occupancy_seconds > 0) |>
    dplyr::mutate(ratio = goal004_seconds / occupancy_seconds)
  runtime_ratio <- if (nrow(runtime_pair)) {
    stats::median(runtime_pair$ratio)
  } else NA_real_
  add(
    "G11-runtime-ratio", "median runtime ratio to occupancy",
    runtime_ratio, 3, "at_most", NA_real_, nrow(runtime_pair),
    is.finite(runtime_ratio) && runtime_ratio <= 3
  )

  list(
    gates = dplyr::bind_rows(gates),
    primary_pairs = primary,
    nested_pairs = tibble::as_tibble(nested_pairs),
    sensitivity_pairs = tibble::as_tibble(sensitivity_pairs)
  )
}
