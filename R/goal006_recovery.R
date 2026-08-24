#' Deterministic Goal006 likelihood-bridge metrics
goal006_likelihood_bridge_metrics <- function() {
  quadrature <- goal006_gauss_hermite(64L)
  cases <- tidyr::crossing(
    class_location = log(c(0.00025, 0.0005, 0.001, 0.002, 0.004)),
    log_rate_sd = c(0.75, 1, 1.25)
  )
  active_days <- c(310, 280, 260, 240)
  camera_effect <- c(-0.3, -0.1, 0.1, 0.3)
  step <- 1e-5
  errors <- lapply(seq_len(nrow(cases)), function(index) {
    row <- cases[index, ]
    reference <- goal006_selection_reference(
      row$class_location,
      row$log_rate_sd,
      active_days,
      camera_effect
    )
    f <- function(shift) {
      goal006_selection_log_probability(
        row$class_location + shift,
        row$log_rate_sd,
        active_days,
        camera_effect,
        quadrature
      )
    }
    tibble::tibble(
      value_error = abs(f(0) - reference$log_probability),
      gradient_error = abs(
        (f(step) - f(-step)) / (2 * step) -
          reference$gradient_class_location
      )
    )
  }) |>
    dplyr::bind_rows()
  tibble::tibble(
    maximum_value_error = max(errors$value_error),
    maximum_gradient_error = max(errors$gradient_error),
    value_tolerance = 1e-8,
    gradient_tolerance = 1e-5,
    passed = maximum_value_error <= value_tolerance &
      maximum_gradient_error <= gradient_tolerance
  )
}

.goal006_terminal_attempt <- function(result) {
  name <- if (result$terminal_status == "primary_clean") {
    "primary"
  } else if (result$terminal_status == "rescue_clean") {
    "rescue"
  } else {
    names(result$attempts)[[length(result$attempts)]]
  }
  list(name = name, value = result$attempts[[name]])
}

#' Compact recovery evidence from one Goal006 calibration fit
summarise_goal006_calibration_recovery <- function(
  simulation_row,
  simulation,
  result
) {
  terminal <- .goal006_terminal_attempt(result)
  metrics <- terminal$value$diagnostics$metrics
  if (is.null(metrics)) {
    metrics <- list(
      divergences = NA_integer_,
      treedepth_hits = NA_integer_,
      min_ebfmi = NA_real_,
      max_rhat = NA_real_,
      min_bulk_ess = NA_real_,
      min_tail_ess = NA_real_
    )
  }
  clean <- result$terminal_status %in% c("primary_clean", "rescue_clean")
  status <- tibble::tibble(
    simulation_id = simulation_row$simulation_id,
    profile_id = simulation_row$profile_id,
    replicate = as.integer(simulation_row$replicate),
    simulation_seed = as.integer(simulation_row$simulation_seed),
    fit_seed = as.integer(simulation_row$fit_seed),
    detected_species = simulation$audit$detected_species,
    detected_routine = as.integer(result$data$class_counts[["routine"]]),
    detected_occasional = as.integer(
      result$data$class_counts[["occasional"]]
    ),
    terminal_status = result$terminal_status,
    terminal_clean = clean,
    terminal_attempt = terminal$name,
    n_attempts = as.integer(length(result$attempts)),
    elapsed_seconds = sum(vapply(
      result$attempts,
      function(attempt) attempt$elapsed_seconds,
      numeric(1)
    )),
    divergences = metrics$divergences,
    treedepth_hits = metrics$treedepth_hits,
    min_ebfmi = metrics$min_ebfmi,
    max_rhat = metrics$max_rhat,
    min_bulk_ess = metrics$min_bulk_ess,
    min_tail_ess = metrics$min_tail_ess,
    reasons = paste(terminal$value$diagnostics$reasons, collapse = "; ")
  )
  class_order <- c("routine", "occasional")
  recovery <- tibble::tibble(
    simulation_id = simulation_row$simulation_id,
    profile_id = simulation_row$profile_id,
    replicate = as.integer(simulation_row$replicate),
    encounter_class = class_order,
    true_location = unname(simulation$truth$class_location[class_order]),
    posterior_mean = NA_real_,
    posterior_median = NA_real_,
    lower_90 = NA_real_,
    upper_90 = NA_real_,
    error = NA_real_,
    covered_90 = FALSE,
    terminal_clean = clean
  )
  if (clean) {
    draws <- as.matrix(.goal006_calibration_draws(result))
    recovery$posterior_mean <- colMeans(draws)
    recovery$posterior_median <- apply(draws, 2L, stats::median)
    recovery$lower_90 <- apply(draws, 2L, stats::quantile, probs = 0.05)
    recovery$upper_90 <- apply(draws, 2L, stats::quantile, probs = 0.95)
    recovery$error <- recovery$posterior_median - recovery$true_location
    recovery$covered_90 <- recovery$lower_90 <= recovery$true_location &
      recovery$upper_90 >= recovery$true_location
  }
  list(status = status, recovery = recovery)
}

.goal006_gate_row <- function(gate, value, numerator = NA_real_) {
  comparison <- gate$comparison[[1L]]
  threshold <- gate$threshold[[1L]]
  passed <- switch(
    comparison,
    at_most = value <= threshold,
    at_least = value >= threshold,
    strictly_less = value < threshold,
    equal = value == threshold,
    .goal006_stop("Unknown Goal006 gate comparison.")
  )
  tibble::tibble(
    gate_id = gate$gate_id,
    metric = gate$metric,
    value = as.numeric(value),
    threshold = threshold,
    comparison = comparison,
    numerator = as.numeric(numerator),
    denominator = gate$denominator,
    passed = isTRUE(passed)
  )
}

#' Apply the frozen Goal006 Task 2 recovery gates
evaluate_goal006_task2_gates <- function(
  manifest,
  fit_status,
  recovery,
  bridge = goal006_likelihood_bridge_metrics()
) {
  task2 <- goal006_expected_gates() |>
    dplyr::filter(stage == "task2")
  valid <- inherits(manifest, "data.frame") && nrow(manifest) == 30L &&
    inherits(fit_status, "data.frame") && nrow(fit_status) == 30L &&
    inherits(recovery, "data.frame") && nrow(recovery) == 60L &&
    setequal(fit_status$simulation_id, manifest$simulation_id) &&
    all(table(recovery$simulation_id) == 2L) &&
    setequal(recovery$simulation_id, manifest$simulation_id) &&
    identical(sort(unique(recovery$encounter_class)),
      c("occasional", "routine")) &&
    inherits(bridge, "data.frame") && nrow(bridge) == 1L
  if (!valid) {
    .goal006_stop("Goal006 Task 2 evidence is incomplete.")
  }
  clean_total <- sum(fit_status$terminal_clean)
  clean_profile <- fit_status |>
    dplyr::summarise(value = sum(terminal_clean), .by = profile_id)
  profile_bias <- recovery |>
    dplyr::summarise(
      value = stats::median(error, na.rm = TRUE),
      .by = c(profile_id, encounter_class)
    )
  rmse <- recovery |>
    dplyr::summarise(
      value = sqrt(mean(error^2, na.rm = TRUE)),
      .by = encounter_class
    )
  coverage <- recovery |>
    dplyr::summarise(value = sum(covered_90), .by = encounter_class)
  coverage_profile <- recovery |>
    dplyr::summarise(
      value = sum(covered_90),
      .by = c(profile_id, encounter_class)
    )
  catastrophic <- recovery |>
    dplyr::summarise(
      failed = !all(terminal_clean) ||
        any(abs(error) > log(3), na.rm = TRUE),
      .by = simulation_id
    )
  value_for <- function(id) {
    gate <- task2[task2$gate_id == id, ]
    switch(
      id,
      "T2-likelihood-value" = .goal006_gate_row(
        gate,
        bridge$maximum_value_error
      ),
      "T2-likelihood-gradient" = .goal006_gate_row(
        gate,
        bridge$maximum_gradient_error
      ),
      "T2-clean" = .goal006_gate_row(gate, clean_total, clean_total),
      "T2-clean-profile" = .goal006_gate_row(
        gate,
        min(clean_profile$value),
        min(clean_profile$value)
      ),
      "T2-routine-bias" = .goal006_gate_row(
        gate,
        max(abs(profile_bias$value[
          profile_bias$encounter_class == "routine"
        ]))
      ),
      "T2-occasional-bias" = .goal006_gate_row(
        gate,
        max(abs(profile_bias$value[
          profile_bias$encounter_class == "occasional"
        ]))
      ),
      "T2-routine-rmse" = .goal006_gate_row(
        gate,
        rmse$value[rmse$encounter_class == "routine"]
      ),
      "T2-occasional-rmse" = .goal006_gate_row(
        gate,
        rmse$value[rmse$encounter_class == "occasional"]
      ),
      "T2-routine-coverage" = .goal006_gate_row(
        gate,
        coverage$value[coverage$encounter_class == "routine"],
        coverage$value[coverage$encounter_class == "routine"]
      ),
      "T2-occasional-coverage" = .goal006_gate_row(
        gate,
        coverage$value[coverage$encounter_class == "occasional"],
        coverage$value[coverage$encounter_class == "occasional"]
      ),
      "T2-class-coverage-profile" = .goal006_gate_row(
        gate,
        min(coverage_profile$value),
        min(coverage_profile$value)
      ),
      "T2-catastrophic" = .goal006_gate_row(
        gate,
        sum(catastrophic$failed),
        sum(catastrophic$failed)
      ),
      .goal006_stop("Unknown frozen Goal006 Task 2 gate.")
    )
  }
  gates <- lapply(task2$gate_id, value_for) |>
    dplyr::bind_rows()
  list(
    gates = gates,
    clean_by_profile = clean_profile,
    bias_by_profile = profile_bias,
    rmse_by_class = rmse,
    coverage_by_class = coverage,
    coverage_by_profile = coverage_profile,
    catastrophic = catastrophic,
    decision = if (all(gates$passed)) "TASK2_PASS" else "TASK2_RECOVERY_FAIL"
  )
}
