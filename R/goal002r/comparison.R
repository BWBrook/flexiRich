.goal002r_validate_candidate_pool_size <- function(candidate_pool_size) {
  if (!is.numeric(candidate_pool_size) || length(candidate_pool_size) != 1L ||
      is.na(candidate_pool_size) || !is.finite(candidate_pool_size) ||
      candidate_pool_size < 0 ||
      candidate_pool_size != trunc(candidate_pool_size)) {
    .goal002r_stop("candidate_pool_size must be one non-negative integer.")
  }
  as.integer(candidate_pool_size)
}

.goal002r_validate_comparison_pmf <- function(
  pmf,
  label,
  candidate_pool_size
) {
  if (!tibble::is_tibble(pmf) ||
      !identical(names(pmf), c("richness", "probability")) ||
      nrow(pmf) == 0L) {
    .goal002r_stop(paste0(label, " PMF has an invalid table contract."))
  }
  if (!is.numeric(pmf$richness) || anyNA(pmf$richness) ||
      any(!is.finite(pmf$richness)) ||
      any(pmf$richness != trunc(pmf$richness)) ||
      any(pmf$richness < 0 | pmf$richness > candidate_pool_size)) {
    .goal002r_stop(paste0(label, " PMF has invalid richness support."))
  }
  if (anyDuplicated(pmf$richness)) {
    .goal002r_stop(paste0(label, " PMF richness values must be unique."))
  }
  if (!is.numeric(pmf$probability) || anyNA(pmf$probability) ||
      any(!is.finite(pmf$probability)) || any(pmf$probability < 0) ||
      abs(sum(pmf$probability) - 1) > 1e-12) {
    .goal002r_stop(paste0(label, " PMF must be non-negative and normalised."))
  }
  pmf
}

goal002r_align_pmf <- function(
  baseline,
  collapsed,
  candidate_pool_size
) {
  candidate_pool_size <- .goal002r_validate_candidate_pool_size(
    candidate_pool_size
  )
  baseline <- .goal002r_validate_comparison_pmf(
    baseline,
    "baseline",
    candidate_pool_size
  )
  collapsed <- .goal002r_validate_comparison_pmf(
    collapsed,
    "collapsed",
    candidate_pool_size
  )
  support <- 0:candidate_pool_size
  baseline_probability <- rep(0, length(support))
  collapsed_probability <- rep(0, length(support))
  baseline_probability[match(baseline$richness, support)] <-
    baseline$probability
  collapsed_probability[match(collapsed$richness, support)] <-
    collapsed$probability
  tibble::tibble(
    richness = support,
    baseline_probability = baseline_probability,
    collapsed_probability = collapsed_probability
  )
}

goal002r_compare_pmf <- function(
  baseline,
  collapsed,
  candidate_pool_size
) {
  aligned <- goal002r_align_pmf(
    baseline,
    collapsed,
    candidate_pool_size
  )
  baseline_summary <- goal002r_richness_summary(tibble::tibble(
    richness = aligned$richness,
    probability = aligned$baseline_probability
  ))
  collapsed_summary <- goal002r_richness_summary(tibble::tibble(
    richness = aligned$richness,
    probability = aligned$collapsed_probability
  ))
  total_variation <- 0.5 * sum(abs(
    aligned$baseline_probability - aligned$collapsed_probability
  ))
  mean_difference <- abs(
    baseline_summary$mean - collapsed_summary$mean
  )
  median_difference <- abs(
    baseline_summary$median - collapsed_summary$median
  )
  interval_difference <- abs(
    baseline_summary$interval_90 - collapsed_summary$interval_90
  )
  tibble::tibble(
    total_variation = total_variation,
    baseline_mean = baseline_summary$mean,
    collapsed_mean = collapsed_summary$mean,
    absolute_mean_difference = mean_difference,
    baseline_median = baseline_summary$median,
    collapsed_median = collapsed_summary$median,
    absolute_median_difference = as.integer(median_difference),
    baseline_lower_90 = baseline_summary$interval_90[[1L]],
    collapsed_lower_90 = collapsed_summary$interval_90[[1L]],
    absolute_lower_90_difference = as.integer(interval_difference[[1L]]),
    baseline_upper_90 = baseline_summary$interval_90[[2L]],
    collapsed_upper_90 = collapsed_summary$interval_90[[2L]],
    absolute_upper_90_difference = as.integer(interval_difference[[2L]]),
    passed = total_variation <= 0.05 &&
      mean_difference <= 0.25 &&
      median_difference <= 1 &&
      all(interval_difference <= 1)
  )
}

.goal002r_shared_draw_statistics <- function(draws, variables, label) {
  if (!is.matrix(draws) || !is.numeric(draws) || nrow(draws) < 4L ||
      is.null(colnames(draws))) {
    .goal002r_stop(paste0(
      label,
      " draws must be a named numeric matrix with at least four rows."
    ))
  }
  missing <- setdiff(variables, colnames(draws))
  if (length(missing) > 0L) {
    .goal002r_stop(paste0(
      label,
      " draws are missing: ",
      paste(missing, collapse = ", "),
      "."
    ))
  }
  selected <- posterior::subset_draws(
    posterior::as_draws_matrix(draws),
    variable = variables
  )
  if (anyNA(selected) || any(!is.finite(selected))) {
    .goal002r_stop(paste0(label, " draws contain missing or non-finite values."))
  }
  summary <- posterior::summarise_draws(
    selected,
    mean,
    sd,
    mcse = posterior::mcse_mean
  )
  summary$mcse[summary$sd == 0] <- 0
  mcse <- summary$mcse
  if (any(!is.finite(mcse))) {
    .goal002r_stop(paste0(label, " draws produced non-finite MCSE values."))
  }
  tibble::tibble(
    parameter = summary$variable,
    mean = summary$mean,
    sd = summary$sd,
    mcse = mcse
  )
}

goal002r_compare_shared_draws <- function(
  baseline_draws,
  collapsed_draws,
  camera_count
) {
  camera_count <- .goal002r_validate_candidate_pool_size(camera_count)
  if (camera_count < 1L) {
    .goal002r_stop("camera_count must be a positive integer.")
  }
  variables <- c(
    "omega",
    "mu_alpha",
    "sigma_alpha",
    "sigma_camera",
    sprintf("camera_effect[%d]", seq_len(camera_count))
  )
  baseline <- .goal002r_shared_draw_statistics(
    baseline_draws,
    variables,
    "baseline"
  )
  collapsed <- .goal002r_shared_draw_statistics(
    collapsed_draws,
    variables,
    "collapsed"
  )
  pooled_sd <- sqrt((baseline$sd^2 + collapsed$sd^2) / 2)
  combined_mcse <- sqrt(baseline$mcse^2 + collapsed$mcse^2)
  threshold <- 0.1 * pooled_sd + 3 * combined_mcse
  difference <- abs(baseline$mean - collapsed$mean)
  tibble::tibble(
    parameter = variables,
    baseline_mean = baseline$mean,
    collapsed_mean = collapsed$mean,
    absolute_mean_difference = difference,
    baseline_sd = baseline$sd,
    collapsed_sd = collapsed$sd,
    pooled_sd = pooled_sd,
    baseline_mcse = baseline$mcse,
    collapsed_mcse = collapsed$mcse,
    combined_mcse = combined_mcse,
    threshold = threshold,
    passed = difference <= threshold
  )
}

.goal002r_validate_result_table <- function(
  table,
  label,
  required,
  case_ids,
  unique_case = FALSE
) {
  if (!tibble::is_tibble(table) || !all(required %in% names(table))) {
    .goal002r_stop(paste0(label, " has an invalid table contract."))
  }
  if (!is.character(table$case_id) || anyNA(table$case_id) ||
      any(!nzchar(table$case_id)) ||
      any(!table$case_id %in% case_ids)) {
    .goal002r_stop(paste0(label, " contains invalid case identifiers."))
  }
  if (unique_case && anyDuplicated(table$case_id)) {
    .goal002r_stop(paste0(label, " must contain at most one row per case."))
  }
  table
}

.goal002r_same_cases <- function(observed, expected) {
  length(observed) == length(expected) &&
    setequal(observed, expected) &&
    !anyDuplicated(observed)
}

.goal002r_paired_case_ids <- function() {
  c(
    "small-easy",
    "small-unseen",
    "standard-short-low",
    "standard-short-high",
    "standard-long-medium",
    "historical-hard"
  )
}

goal002r_comparison_decision <- function(
  case_results,
  pmf_results,
  parameter_results,
  quadrature_results
) {
  required_case <- c(
    "case_id",
    "camera_count",
    "supported",
    "historical_stress",
    "baseline_primary_clean",
    "collapsed_primary_clean",
    "baseline_terminal_clean",
    "collapsed_terminal_clean",
    "baseline_primary_seconds",
    "collapsed_primary_seconds"
  )
  if (!tibble::is_tibble(case_results) || nrow(case_results) == 0L ||
      !all(required_case %in% names(case_results)) ||
      !is.character(case_results$case_id) || anyNA(case_results$case_id) ||
      any(!nzchar(case_results$case_id)) || anyDuplicated(case_results$case_id)) {
    .goal002r_stop("case_results has an invalid table contract.")
  }
  expected_case_ids <- .goal002r_paired_case_ids()
  if (any(!case_results$case_id %in% expected_case_ids)) {
    .goal002r_stop("case_results contains an unknown comparison case.")
  }
  if (!is.numeric(case_results$camera_count) ||
      anyNA(case_results$camera_count) ||
      any(!is.finite(case_results$camera_count)) ||
      any(case_results$camera_count < 1) ||
      any(case_results$camera_count != trunc(case_results$camera_count))) {
    .goal002r_stop("case_results camera counts must be positive integers.")
  }
  logical_columns <- c(
    "supported",
    "historical_stress",
    "baseline_primary_clean",
    "collapsed_primary_clean",
    "baseline_terminal_clean",
    "collapsed_terminal_clean"
  )
  if (any(!vapply(
    case_results[logical_columns],
    function(column) is.logical(column) && !anyNA(column),
    logical(1)
  ))) {
    .goal002r_stop("case_results status columns must be complete logicals.")
  }
  runtime_columns <- c(
    "baseline_primary_seconds",
    "collapsed_primary_seconds"
  )
  if (any(!vapply(
    case_results[runtime_columns],
    function(column) is.numeric(column) && !anyNA(column) &&
      all(is.finite(column)) && all(column > 0),
    logical(1)
  ))) {
    .goal002r_stop("case_results runtimes must be finite and positive.")
  }
  case_ids <- case_results$case_id
  pmf_results <- .goal002r_validate_result_table(
    pmf_results,
    "pmf_results",
    c("case_id", "support_valid", "passed"),
    case_ids,
    unique_case = TRUE
  )
  parameter_results <- .goal002r_validate_result_table(
    parameter_results,
    "parameter_results",
    c("case_id", "parameter", "passed"),
    case_ids
  )
  quadrature_results <- .goal002r_validate_result_table(
    quadrature_results,
    "quadrature_results",
    c("case_id", "draw_index", "passed"),
    case_ids
  )
  if (any(!vapply(
    list(
      pmf_results$support_valid,
      pmf_results$passed,
      parameter_results$passed,
      quadrature_results$passed
    ),
    function(column) is.logical(column) && !anyNA(column),
    logical(1)
  )) || !is.character(parameter_results$parameter) ||
      anyNA(parameter_results$parameter) ||
      any(!nzchar(parameter_results$parameter)) ||
      anyDuplicated(parameter_results[c("case_id", "parameter")]) ||
      !is.numeric(quadrature_results$draw_index) ||
      anyNA(quadrature_results$draw_index) ||
      any(!is.finite(quadrature_results$draw_index)) ||
      any(quadrature_results$draw_index !=
        trunc(quadrature_results$draw_index)) ||
      anyDuplicated(quadrature_results[c("case_id", "draw_index")])) {
    .goal002r_stop("Comparison result flags or parameter identifiers are invalid.")
  }

  supported <- case_results$supported
  paired_clean <- supported &
    case_results$baseline_terminal_clean &
    case_results$collapsed_terminal_clean
  collapsed_clean <- supported & case_results$collapsed_terminal_clean
  paired_ids <- case_ids[paired_clean]
  collapsed_clean_ids <- case_ids[collapsed_clean]
  pmf_complete <- .goal002r_same_cases(pmf_results$case_id, paired_ids)
  parameter_complete <- length(paired_ids) > 0L && all(vapply(
    paired_ids,
    function(id) {
      camera_count <- case_results$camera_count[case_ids == id]
      required <- c(
        "omega",
        "mu_alpha",
        "sigma_alpha",
        "sigma_camera",
        sprintf("camera_effect[%d]", seq_len(camera_count))
      )
      setequal(
        parameter_results$parameter[parameter_results$case_id == id],
        required
      )
    },
    logical(1)
  )) && setequal(unique(parameter_results$case_id), paired_ids)
  quadrature_complete <-
    setequal(unique(quadrature_results$case_id), collapsed_clean_ids) &&
    all(vapply(collapsed_clean_ids, function(id) {
      identical(
        sort(as.integer(quadrature_results$draw_index[
          quadrature_results$case_id == id
        ])),
        seq_len(25L)
      )
    }, logical(1)))

  baseline_primary_clean <- sum(
    supported & case_results$baseline_primary_clean
  )
  collapsed_primary_clean <- sum(
    supported & case_results$collapsed_primary_clean
  )
  baseline_terminal_clean <- sum(
    supported & case_results$baseline_terminal_clean
  )
  collapsed_terminal_clean <- sum(
    supported & case_results$collapsed_terminal_clean
  )
  runtime_ratio <- case_results$collapsed_primary_seconds[supported] /
    case_results$baseline_primary_seconds[supported]
  median_runtime_ratio <- stats::median(runtime_ratio)
  stress <- supported & case_results$historical_stress

  criterion <- c(
    "all_cases_supported",
    "quadrature_checks",
    "richness_support",
    "pmf_fidelity",
    "shared_parameter_fidelity",
    "collapsed_terminal_clean",
    "historical_stress_clean",
    "primary_geometry_not_worse",
    "terminal_geometry_not_worse",
    "runtime_acceptable"
  )
  observed <- c(
    sum(supported),
    sum(quadrature_results$passed),
    sum(pmf_results$support_valid),
    sum(pmf_results$passed),
    sum(parameter_results$passed),
    collapsed_terminal_clean,
    sum(case_results$collapsed_terminal_clean[stress]),
    collapsed_primary_clean - baseline_primary_clean,
    collapsed_terminal_clean - baseline_terminal_clean,
    median_runtime_ratio
  )
  requirement <- c(
    paste0("= ", length(expected_case_ids)),
    paste0("= ", 25L * length(collapsed_clean_ids)),
    paste0("= ", length(paired_ids)),
    paste0("= ", length(paired_ids)),
    "all shared parameters in every paired-clean case",
    paste0("= ", sum(supported)),
    paste0("= ", sum(stress)),
    ">= 0",
    ">= 0",
    "<= 2"
  )
  passed <- c(
    setequal(case_ids, expected_case_ids) && all(supported),
    quadrature_complete && all(quadrature_results$passed),
    pmf_complete && all(pmf_results$support_valid),
    length(paired_ids) > 0L && pmf_complete && all(pmf_results$passed),
    parameter_complete && all(parameter_results$passed),
    collapsed_terminal_clean == sum(supported),
    any(stress) && all(case_results$collapsed_terminal_clean[stress]),
    collapsed_primary_clean >= baseline_primary_clean,
    collapsed_terminal_clean >= baseline_terminal_clean,
    is.finite(median_runtime_ratio) && median_runtime_ratio <= 2
  )
  criteria <- tibble::tibble(
    criterion = criterion,
    observed = observed,
    requirement = requirement,
    passed = passed
  )

  hard_failure <- any(!quadrature_results$passed) ||
    any(!pmf_results$support_valid) ||
    any(!pmf_results$passed) ||
    any(!parameter_results$passed) ||
    collapsed_primary_clean < baseline_primary_clean ||
    collapsed_terminal_clean < baseline_terminal_clean
  decision <- if (all(criteria$passed)) {
    "RETAIN"
  } else if (hard_failure) {
    "REJECT"
  } else {
    "REVISE"
  }
  list(decision = decision, criteria = criteria)
}
