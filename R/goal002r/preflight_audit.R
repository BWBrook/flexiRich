goal002r_preflight_posterior_states <- function(
  posterior_state_file = goal002r_preflight_contract()$posterior_state_file,
  case_file = goal002r_preflight_contract()$case_file
) {
  resolve_evidence_path <- function(path) {
    if (file.exists(path)) return(path)
    file.path(goal002r_project_root(), path)
  }
  posterior_state_file <- resolve_evidence_path(posterior_state_file)
  case_file <- resolve_evidence_path(case_file)
  if (!file.exists(posterior_state_file) || !file.exists(case_file)) {
    .goal002r_stop("Preflight consultation evidence is incomplete.")
  }
  states <- tibble::as_tibble(utils::read.csv(
    posterior_state_file,
    check.names = FALSE
  ))
  cases <- tibble::as_tibble(utils::read.csv(
    case_file,
    check.names = FALSE
  ))
  state_columns <- c(
    "case_id", "check_source", "posterior_row", "log_B", "sigma_alpha"
  )
  case_columns <- c("case_id", "candidate_pool_size", "observed_richness")
  if (!all(state_columns %in% names(states)) ||
      !all(case_columns %in% names(cases))) {
    .goal002r_stop("Preflight consultation evidence has an invalid schema.")
  }
  pairs <- dplyr::distinct(states, case_id, posterior_row)
  if (nrow(states) != 750L || nrow(pairs) != 750L) {
    .goal002r_stop("Preflight evidence must contain 750 unique posterior states.")
  }
  cases <- dplyr::select(
    cases,
    case_id,
    candidate_pool_size,
    observed_richness
  )
  if (anyDuplicated(cases$case_id)) {
    .goal002r_stop("Preflight case evidence contains duplicate cases.")
  }
  states <- dplyr::left_join(states, cases, by = "case_id")
  if (anyNA(states$candidate_pool_size) || anyNA(states$observed_richness)) {
    .goal002r_stop("Preflight posterior states contain an unknown case.")
  }
  states |>
    dplyr::transmute(
      case_id,
      check_source,
      posterior_row = as.integer(posterior_row),
      a = log_B,
      sigma_alpha,
      U = as.integer(candidate_pool_size - observed_richness)
    )
}

goal002r_preflight_domain_grid <- function() {
  tidyr::crossing(
    a = seq(-8, 10, length.out = 61L),
    sigma_alpha = seq(0, 5.5, length.out = 61L)
  ) |>
    dplyr::mutate(U = 29L)
}

.goal002r_preflight_metrics <- c(
  "target_error",
  "scaled_a_error",
  "scaled_sigma_error",
  "scaled_log_sigma_error"
)

.goal002r_preflight_metric_values <- function(
  candidate,
  reference,
  U,
  sigma_alpha
) {
  contract <- goal002r_preflight_contract()
  derivative_a_error <- abs(
    candidate[["derivative_a"]] - reference[["derivative_a"]]
  )
  derivative_sigma_error <- abs(
    candidate[["derivative_sigma"]] - reference[["derivative_sigma"]]
  )
  c(
    target_error = U * abs(
      candidate[["log_m0"]] - reference[["log_m0"]]
    ),
    scaled_a_error = contract$gradient_scales[["a"]] * U *
      derivative_a_error,
    scaled_sigma_error = contract$gradient_scales[["sigma"]] * U *
      derivative_sigma_error,
    scaled_log_sigma_error = contract$gradient_scales[["log_sigma"]] * U *
      sigma_alpha * derivative_sigma_error
  )
}

.goal002r_preflight_state_id <- function(source, index, a, sigma_alpha) {
  sprintf(
    "%s row %d (a=%.8g, sigma_alpha=%.8g)",
    source,
    index,
    a,
    sigma_alpha
  )
}

.goal002r_preflight_oracle_failure <- function(pair, state_id) {
  contract <- goal002r_preflight_contract()
  if (!all(is.finite(pair))) {
    .goal002r_stop(paste0("Non-finite preflight oracle result at ", state_id, "."))
  }
  failures <- c(
    value_agreement = pair[["value_agreement"]] >
      contract$reference_agreement,
    derivative_a_mixed = pair[["derivative_a_mixed_pass"]] != 1,
    derivative_sigma_mixed = pair[["derivative_sigma_mixed_pass"]] != 1,
    scaled_reference_a = pair[["scaled_reference_a_uncertainty"]] >
      contract$reference_scaled_uncertainty,
    scaled_reference_sigma = pair[["scaled_reference_sigma_uncertainty"]] >
      contract$reference_scaled_uncertainty,
    tail_relative_bound = pair[["maximum_tail_relative_bound"]] >
      contract$tail_relative_bound,
    expansion_change = pair[["maximum_expansion_change"]] >
      contract$tail_stability
  )
  if (any(failures)) {
    .goal002r_stop(paste0(
      "Preflight oracle failure at ", state_id, ": ",
      paste(names(failures)[failures], collapse = ", "), "."
    ))
  }
}

goal002r_preflight_audit <- function(states, source) {
  if (!tibble::is_tibble(states) ||
      !all(c("a", "sigma_alpha", "U") %in% names(states))) {
    .goal002r_stop("states must be a tibble containing a, sigma_alpha, and U.")
  }
  if (!is.character(source) || length(source) != 1L ||
      is.na(source) || !nzchar(source)) {
    .goal002r_stop("source must be one non-empty string.")
  }
  contract <- goal002r_preflight_contract()
  valid_u <- is.finite(states$U) & states$U == trunc(states$U) &
    states$U >= 0 & states$U <= contract$max_unseen
  if (nrow(states) == 0L || !all(valid_u)) {
    .goal002r_stop("states must contain whole U values from 0 to 29.")
  }
  rules <- stats::setNames(
    lapply(contract$orders, goal002r_preflight_rule),
    contract$orders
  )
  rows <- lapply(seq_len(nrow(states)), function(index) {
    a <- states$a[index]
    sigma_alpha <- states$sigma_alpha[index]
    U <- as.integer(states$U[index])
    state_id <- .goal002r_preflight_state_id(source, index, a, sigma_alpha)
    pair <- goal002r_preflight_reference_pair(a, sigma_alpha)
    .goal002r_preflight_oracle_failure(pair, state_id)
    reference <- pair[c("log_m0", "derivative_a", "derivative_sigma")]
    order_rows <- lapply(seq_along(contract$orders), function(order_index) {
      order <- contract$orders[order_index]
      candidate <- goal002r_preflight_gh(
        a,
        sigma_alpha,
        rules[[as.character(order)]]
      )
      if (!all(is.finite(candidate))) {
        .goal002r_stop(paste0(
          "Non-finite preflight candidate result for order ", order,
          " at ", state_id, "."
        ))
      }
      metrics <- .goal002r_preflight_metric_values(
        candidate,
        reference,
        U,
        sigma_alpha
      )
      tibble::tibble(
        source = source,
        state_index = as.integer(index),
        order = order,
        candidate_log_m0 = candidate[["log_m0"]],
        candidate_derivative_a = candidate[["derivative_a"]],
        candidate_derivative_sigma = candidate[["derivative_sigma"]],
        reference_log_m0 = reference[["log_m0"]],
        reference_derivative_a = reference[["derivative_a"]],
        reference_derivative_sigma = reference[["derivative_sigma"]],
        target_error = metrics[["target_error"]],
        scaled_a_error = metrics[["scaled_a_error"]],
        scaled_sigma_error = metrics[["scaled_sigma_error"]],
        scaled_log_sigma_error = metrics[["scaled_log_sigma_error"]],
        value_agreement = pair[["value_agreement"]],
        derivative_a_agreement = pair[["derivative_a_agreement"]],
        derivative_sigma_agreement = pair[["derivative_sigma_agreement"]],
        derivative_a_mixed_limit = 1e-8 + 1e-10 *
          abs(reference[["derivative_a"]]),
        derivative_sigma_mixed_limit = 1e-8 + 1e-10 *
          abs(reference[["derivative_sigma"]]),
        derivative_a_mixed_pass = pair[["derivative_a_agreement"]] <=
          1e-8 + 1e-10 * abs(reference[["derivative_a"]]),
        derivative_sigma_mixed_pass = pair[["derivative_sigma_agreement"]] <=
          1e-8 + 1e-10 * abs(reference[["derivative_sigma"]]),
        scaled_reference_a_uncertainty = contract$max_unseen * 1.5 *
          pair[["derivative_a_agreement"]],
        scaled_reference_sigma_uncertainty = contract$max_unseen *
          max(0.85, 1.2 * sigma_alpha) *
          pair[["derivative_sigma_agreement"]],
        tail_relative_bound = pair[["maximum_tail_relative_bound"]],
        expansion_change = pair[["maximum_expansion_change"]]
      )
    })
    state <- states[index, , drop = FALSE]
    dplyr::bind_cols(
      state[rep(1L, length(order_rows)), , drop = FALSE],
      dplyr::bind_rows(order_rows)
    )
  })
  result <- dplyr::bind_rows(rows)
  numeric <- result[vapply(result, is.numeric, logical(1))]
  if (!all(is.finite(unlist(numeric)))) {
    .goal002r_stop("Preflight audit produced a non-finite result.")
  }
  result
}

goal002r_preflight_select <- function(criteria) {
  required <- c("order", "full_pass", "headroom_pass")
  if (!tibble::is_tibble(criteria) ||
      !all(required %in% names(criteria)) ||
      anyDuplicated(criteria$order)) {
    .goal002r_stop("criteria must contain one row per preflight order.")
  }
  order_256 <- criteria[criteria$order == 256L, , drop = FALSE]
  order_512 <- criteria[criteria$order == 512L, , drop = FALSE]
  if (nrow(order_256) != 1L || nrow(order_512) != 1L) {
    .goal002r_stop("criteria must contain orders 256 and 512.")
  }
  if (isTRUE(order_256$headroom_pass)) return("SELECT_256")
  if (isTRUE(order_512$full_pass)) return("SELECT_512")
  "CLOSE"
}

.goal002r_preflight_metric_at <- function(
  a,
  sigma_alpha,
  order,
  rule,
  metric
) {
  state_id <- .goal002r_preflight_state_id(
    paste0("search order ", order, " ", metric),
    1L,
    a,
    sigma_alpha
  )
  pair <- goal002r_preflight_reference_pair(a, sigma_alpha)
  .goal002r_preflight_oracle_failure(pair, state_id)
  candidate <- goal002r_preflight_gh(a, sigma_alpha, rule)
  if (!all(is.finite(candidate))) {
    .goal002r_stop(paste0("Non-finite preflight search result at ", state_id, "."))
  }
  values <- .goal002r_preflight_metric_values(
    candidate,
    pair,
    goal002r_preflight_contract()$max_unseen,
    sigma_alpha
  )
  value <- unname(values[[metric]])
  if (!is.finite(value)) {
    .goal002r_stop("Preflight search metric was non-finite.")
  }
  value
}

.goal002r_preflight_evaluator_stop <- function(
  error,
  order,
  metric,
  a,
  sigma_alpha
) {
  message <- sprintf(
    paste0(
      "Preflight evaluator failure for order %d, metric %s at ",
      "a=%.16g, sigma_alpha=%.16g: %s"
    ),
    order,
    metric,
    a,
    sigma_alpha,
    conditionMessage(error)
  )
  condition <- structure(
    list(message = message, call = NULL, parent = error),
    class = c("goal002r_preflight_evaluator_error", "error", "condition")
  )
  stop(condition)
}

.goal002r_preflight_search_value <- function(par, order, rule, metric) {
  tryCatch(
    .goal002r_preflight_metric_at(par[1], par[2], order, rule, metric),
    error = function(error) {
      if (inherits(error, "goal002r_preflight_evaluator_error")) {
        stop(error)
      }
      .goal002r_preflight_evaluator_stop(
        error,
        order,
        metric,
        par[1],
        par[2]
      )
    }
  )
}

.goal002r_preflight_optim <- function(start, objective, lower, upper) {
  stats::optim(
    par = start,
    fn = objective,
    method = "L-BFGS-B",
    lower = lower,
    upper = upper
  )
}

goal002r_preflight_search_maxima <- function(domain_audit) {
  metrics <- .goal002r_preflight_metrics
  required <- c("order", "a", "sigma_alpha", "U", metrics)
  if (!tibble::is_tibble(domain_audit) ||
      !all(required %in% names(domain_audit))) {
    .goal002r_stop("domain_audit lacks preflight search columns.")
  }
  contract <- goal002r_preflight_contract()
  if (!all(domain_audit$U == contract$max_unseen)) {
    .goal002r_stop("domain_audit must use the maximum unseen richness.")
  }
  rules <- stats::setNames(
    lapply(contract$orders, goal002r_preflight_rule),
    contract$orders
  )
  results <- list()
  result_index <- 0L
  for (order in contract$orders) {
    order_rows <- domain_audit[domain_audit$order == order, , drop = FALSE]
    if (nrow(order_rows) < contract$search_starts) {
      .goal002r_stop("Each preflight order requires at least 12 search starts.")
    }
    rule <- rules[[as.character(order)]]
    for (metric in metrics) {
      starts <- order_rows[order(
        -order_rows[[metric]],
        order_rows$a,
        order_rows$sigma_alpha
      ), , drop = FALSE]
      starts <- starts[seq_len(contract$search_starts), , drop = FALSE]
      attempts <- lapply(seq_len(nrow(starts)), function(index) {
        start <- c(starts$a[index], starts$sigma_alpha[index])
        fit <- tryCatch(
          .goal002r_preflight_optim(
            start = start,
            objective = function(par) {
              -.goal002r_preflight_search_value(par, order, rule, metric)
            },
            lower = c(contract$a_bounds[1], contract$sigma_bounds[1]),
            upper = c(contract$a_bounds[2], contract$sigma_bounds[2])
          ),
          error = function(error) {
            if (inherits(error, "goal002r_preflight_evaluator_error")) {
              stop(error)
            }
            NULL
          }
        )
        if (is.null(fit)) return(NULL)
        observed <- tryCatch(
          .goal002r_preflight_search_value(fit$par, order, rule, metric),
          error = function(error) {
            if (inherits(error, "goal002r_preflight_evaluator_error")) {
              stop(error)
            }
            NA_real_
          }
        )
        if (!is.finite(observed)) return(NULL)
        tibble::tibble(
          order = order,
          metric = metric,
          a = fit$par[1],
          sigma_alpha = fit$par[2],
          observed = observed,
          convergence = as.integer(fit$convergence)
        )
      })
      attempts <- dplyr::bind_rows(attempts)
      if (nrow(attempts) == 0L) {
        .goal002r_stop(paste0(
          "All 12 maxima searches failed for order ", order,
          " and ", metric, "."
        ))
      }
      result_index <- result_index + 1L
      results[[result_index]] <- attempts[which.max(attempts$observed), ]
    }
  }
  dplyr::bind_rows(results)
}

goal002r_preflight_criteria <- function(
  posterior_audit,
  domain_audit,
  maxima
) {
  metrics <- .goal002r_preflight_metrics
  audit_required <- c(
    "order", metrics, "value_agreement", "derivative_a_mixed_pass",
    "derivative_sigma_mixed_pass", "scaled_reference_a_uncertainty",
    "scaled_reference_sigma_uncertainty", "tail_relative_bound",
    "expansion_change"
  )
  maxima_required <- c("order", "metric", "observed")
  if (!tibble::is_tibble(posterior_audit) ||
      !tibble::is_tibble(domain_audit) ||
      !all(audit_required %in% names(posterior_audit)) ||
      !all(audit_required %in% names(domain_audit)) ||
      !tibble::is_tibble(maxima) ||
      !all(maxima_required %in% names(maxima))) {
    .goal002r_stop("Preflight criteria inputs have an invalid schema.")
  }
  contract <- goal002r_preflight_contract()
  expected_keys <- tidyr::crossing(
    order = contract$orders,
    metric = metrics
  ) |>
    dplyr::arrange(order, metric)
  maxima_keys <- maxima |>
    dplyr::select(order, metric) |>
    dplyr::arrange(order, metric)
  maxima_valid <- nrow(maxima) == nrow(expected_keys) &&
    !anyDuplicated(maxima[c("order", "metric")]) &&
    identical(maxima_keys, expected_keys) &&
    is.numeric(maxima$observed) && all(is.finite(maxima$observed))
  if (!maxima_valid) {
    .goal002r_stop(
      "Preflight criteria require exactly one finite maximum per order and metric."
    )
  }
  audit <- dplyr::bind_rows(posterior_audit, domain_audit)
  rows <- lapply(contract$orders, function(order) {
    order_audit <- audit[audit$order == order, , drop = FALSE]
    order_maxima <- maxima[maxima$order == order, , drop = FALSE]
    if (nrow(order_audit) == 0L) {
      .goal002r_stop("Preflight criteria require both complete order audits.")
    }
    searched_target <- order_maxima$observed[
      order_maxima$metric == "target_error"
    ]
    searched_gradient <- order_maxima$observed[
      order_maxima$metric %in% metrics[-1L]
    ]
    gradient_values <- c(
      order_audit$scaled_a_error,
      order_audit$scaled_sigma_error,
      order_audit$scaled_log_sigma_error
    )
    maximum_target <- max(order_audit$target_error, searched_target)
    maximum_gradient <- max(gradient_values, searched_gradient)
    rms_gradient <- sqrt(mean(gradient_values^2))
    maximum_value_agreement <- max(order_audit$value_agreement)
    all_reference_derivative_mixed_pass <- all(
      order_audit$derivative_a_mixed_pass,
      order_audit$derivative_sigma_mixed_pass
    )
    maximum_scaled_reference_uncertainty <- max(
      order_audit$scaled_reference_a_uncertainty,
      order_audit$scaled_reference_sigma_uncertainty
    )
    maximum_tail_relative_bound <- max(order_audit$tail_relative_bound)
    maximum_expansion_change <- max(order_audit$expansion_change)
    full_pass <- maximum_target <= contract$value_gate &&
      maximum_gradient < contract$gradient_max_gate &&
      rms_gradient < contract$gradient_rms_gate &&
      maximum_value_agreement <= contract$reference_agreement &&
      all_reference_derivative_mixed_pass &&
      maximum_scaled_reference_uncertainty <=
        contract$reference_scaled_uncertainty &&
      maximum_tail_relative_bound <= contract$tail_relative_bound &&
      maximum_expansion_change <= contract$tail_stability
    headroom_pass <- full_pass &&
      maximum_target <= contract$selection_headroom * contract$value_gate &&
      maximum_gradient <= contract$selection_headroom *
        contract$gradient_max_gate &&
      rms_gradient <= contract$selection_headroom *
        contract$gradient_rms_gate
    tibble::tibble(
      order = order,
      maximum_target = maximum_target,
      maximum_gradient = maximum_gradient,
      rms_gradient = rms_gradient,
      maximum_value_agreement = maximum_value_agreement,
      all_reference_derivative_mixed_pass =
        all_reference_derivative_mixed_pass,
      maximum_scaled_reference_uncertainty =
        maximum_scaled_reference_uncertainty,
      maximum_tail_relative_bound = maximum_tail_relative_bound,
      maximum_expansion_change = maximum_expansion_change,
      full_pass = full_pass,
      headroom_pass = headroom_pass
    )
  })
  dplyr::bind_rows(rows)
}

.goal002r_preflight_derivative_states <- function(
  posterior_audit,
  domain_audit
) {
  metrics <- .goal002r_preflight_metrics
  audit <- dplyr::bind_rows(posterior_audit, domain_audit)
  if (!all(c("a", "sigma_alpha", metrics) %in% names(audit))) {
    .goal002r_stop("Preflight audits lack derivative-state columns.")
  }
  contract <- goal002r_preflight_contract()
  anchors <- tidyr::crossing(
    a = contract$a_bounds,
    sigma_alpha = contract$sigma_bounds
  ) |>
    dplyr::bind_rows(tibble::tibble(
      a = mean(contract$a_bounds),
      sigma_alpha = mean(contract$sigma_bounds)
    ))
  scored <- tibble::tibble(
    a = audit$a,
    sigma_alpha = audit$sigma_alpha,
    discrepancy = pmax(
      audit$target_error,
      audit$scaled_a_error,
      audit$scaled_sigma_error,
      audit$scaled_log_sigma_error
    )
  ) |>
    dplyr::group_by(a, sigma_alpha) |>
    dplyr::summarise(discrepancy = max(discrepancy), .groups = "drop") |>
    dplyr::anti_join(anchors, by = c("a", "sigma_alpha")) |>
    dplyr::arrange(dplyr::desc(discrepancy), a, sigma_alpha)
  if (nrow(scored) < 5L) {
    .goal002r_stop("Preflight audits provide fewer than five derivative states.")
  }
  dplyr::bind_rows(
    anchors,
    dplyr::select(scored[seq_len(5L), , drop = FALSE], a, sigma_alpha)
  )
}

.goal002r_preflight_rule_integrity <- function() {
  contract <- goal002r_preflight_contract()
  checks <- dplyr::bind_rows(lapply(contract$orders, function(order) {
    goal002r_preflight_rule_checks(goal002r_preflight_rule(order), order)
  }))
  expected_names <- c("order", "check", "observed", "threshold", "passed")
  order_counts <- if (all(c("order", "check") %in% names(checks))) {
    table(checks$order)
  } else {
    integer()
  }
  valid <- tibble::is_tibble(checks) &&
    identical(names(checks), expected_names) &&
    nrow(checks) == 18L &&
    !anyNA(checks) &&
    identical(names(order_counts), as.character(contract$orders)) &&
    identical(as.integer(order_counts), c(9L, 9L)) &&
    !anyDuplicated(checks[c("order", "check")]) &&
    is.numeric(checks$observed) && all(is.finite(checks$observed)) &&
    is.numeric(checks$threshold) && all(is.finite(checks$threshold)) &&
    is.logical(checks$passed) && !anyNA(checks$passed) && all(checks$passed)
  if (!valid) {
    .goal002r_stop("Preflight rule integrity checks failed.")
  }
  checks
}

.goal002r_preflight_algebra_integrity <- function() {
  checks <- goal002r_preflight_algebra_checks()
  expected_names <- c(
    "sigma_alpha", "rowwise_log_m0", "reduced_log_m0",
    "absolute_error", "passed"
  )
  numeric_names <- expected_names[expected_names != "passed"]
  schema_valid <- tibble::is_tibble(checks) &&
    identical(names(checks), expected_names)
  numeric_valid <- schema_valid && all(vapply(
    checks[numeric_names],
    function(value) is.numeric(value) && all(is.finite(value)),
    logical(1)
  ))
  valid <- schema_valid &&
    nrow(checks) == 4L &&
    nrow(dplyr::distinct(checks, sigma_alpha)) == 4L &&
    numeric_valid &&
    is.logical(checks$passed) && !anyNA(checks$passed) && all(checks$passed)
  if (!valid) {
    .goal002r_stop("Preflight algebra integrity checks failed.")
  }
  checks
}

goal002r_preflight_run <- function() {
  rule_checks <- .goal002r_preflight_rule_integrity()
  algebra_checks <- .goal002r_preflight_algebra_integrity()
  posterior_audit <- goal002r_preflight_audit(
    goal002r_preflight_posterior_states(),
    source = "posterior"
  )
  domain_audit <- goal002r_preflight_audit(
    goal002r_preflight_domain_grid(),
    source = "domain"
  )
  maxima <- goal002r_preflight_search_maxima(domain_audit)
  criteria <- goal002r_preflight_criteria(
    posterior_audit,
    domain_audit,
    maxima
  )
  derivative_checks <- goal002r_preflight_derivative_checks(
    .goal002r_preflight_derivative_states(posterior_audit, domain_audit)
  )
  derivative_valid <- tibble::is_tibble(derivative_checks) &&
    nrow(derivative_checks) == 20L &&
    "passed" %in% names(derivative_checks) &&
    is.logical(derivative_checks$passed) &&
    !anyNA(derivative_checks$passed) &&
    all(derivative_checks$passed)
  if (!derivative_valid) {
    .goal002r_stop("Preflight derivative sanity checks failed.")
  }
  decision <- goal002r_preflight_select(criteria)
  list(
    rule_integrity = dplyr::bind_rows(
      rule_checks,
      algebra_checks,
      derivative_checks
    ),
    posterior_audit = posterior_audit,
    domain_audit = domain_audit,
    maxima = maxima,
    criteria = criteria,
    decision = decision
  )
}

goal002r_preflight_write <- function(result, output_dir) {
  paths <- stats::setNames(
    file.path(
      output_dir,
      c(
        "rule-integrity.csv",
        "posterior-state-audit.csv",
        "domain-audit.csv",
        "numerical-maxima.csv",
        "decision.txt"
      )
    ),
    c(
      "rule_integrity",
      "posterior_audit",
      "domain_audit",
      "maxima",
      "decision"
    )
  )
  if (any(file.exists(paths))) {
    .goal002r_stop("Output directory already contains approved evidence files.")
  }
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(
    result$rule_integrity,
    paths[["rule_integrity"]],
    row.names = FALSE
  )
  utils::write.csv(
    result$posterior_audit,
    paths[["posterior_audit"]],
    row.names = FALSE
  )
  utils::write.csv(
    result$domain_audit,
    paths[["domain_audit"]],
    row.names = FALSE
  )
  utils::write.csv(result$maxima, paths[["maxima"]], row.names = FALSE)
  criterion_lines <- vapply(
    seq_len(nrow(result$criteria)),
    function(index) {
      values <- vapply(
        result$criteria,
        function(column) as.character(column[[index]]),
        character(1)
      )
      paste0(
        "criterion ",
        index,
        ": ",
        paste(names(values), values, sep = "=", collapse = ", ")
      )
    },
    character(1)
  )
  writeLines(
    c(paste("decision:", result$decision), criterion_lines),
    paths[["decision"]]
  )
  paths
}
