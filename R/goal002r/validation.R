.goal002r_reference_log_integrand <- function(
  z,
  zero_history,
  mu_alpha,
  sigma_alpha,
  camera_effect
) {
  camera <- unname(camera_effect[zero_history$camera_id])
  vapply(z, function(value) {
    log_likelihood <- -sum(
      zero_history$n_trials * zero_history$active_days *
        exp(mu_alpha + sigma_alpha * value + camera)
    )
    stats::dnorm(value, log = TRUE) + log_likelihood
  }, numeric(1))
}

goal002r_reference_log_m0 <- function(
  zero_history,
  mu_alpha,
  sigma_alpha,
  camera_effect,
  tail_drop = 40,
  rel_tol = 1e-11
) {
  if (!tibble::is_tibble(zero_history) ||
      !identical(names(zero_history), c("camera_id", "active_days", "n_trials"))) {
    .goal002r_stop("zero_history has an invalid reference-integration contract.")
  }
  mu_alpha <- .goal002r_scalar(mu_alpha, "mu_alpha")
  sigma_alpha <- .goal002r_scalar(sigma_alpha, "sigma_alpha", lower = 0)
  if (!is.numeric(camera_effect) || is.null(names(camera_effect)) ||
      any(!is.finite(camera_effect))) {
    .goal002r_stop("camera_effect must be a named finite vector.")
  }
  if (nrow(zero_history) == 0L || sigma_alpha == 0) {
    return(list(
      log_m0 = if (nrow(zero_history) == 0L) 0 else
        sum(zero_history$n_trials *
          (-zero_history$active_days * exp(mu_alpha +
            camera_effect[zero_history$camera_id]))),
      lower = NA_real_,
      upper = NA_real_,
      relative_error = 0
    ))
  }
  log_integrand <- function(z) .goal002r_reference_log_integrand(
    z,
    zero_history,
    mu_alpha,
    sigma_alpha,
    camera_effect
  )
  lower <- -8
  upper <- 8
  mode <- stats::optimize(
    function(value) -log_integrand(value),
    interval = c(lower, upper)
  )$minimum
  anchor <- log_integrand(mode)
  repeat {
    tail_values <- log_integrand(c(lower, upper))
    if (all(anchor - tail_values >= tail_drop)) break
    lower <- lower * 1.5
    upper <- upper * 1.5
    if (lower < -128 || upper > 128) {
      .goal002r_stop("Reference integration could not bound both tails.")
    }
    mode <- stats::optimize(
      function(value) -log_integrand(value),
      interval = c(lower, upper)
    )$minimum
    anchor <- log_integrand(mode)
  }
  integral <- stats::integrate(
    function(z) exp(log_integrand(z) - anchor),
    lower = lower,
    upper = upper,
    rel.tol = rel_tol,
    abs.tol = 0,
    subdivisions = 5000L,
    stop.on.error = TRUE
  )
  relative_error <- integral$abs.error / integral$value
  if (!is.finite(relative_error) || relative_error > rel_tol * 10) {
    .goal002r_stop("Reference integration error exceeded its tolerance.")
  }
  list(
    log_m0 = as.numeric(log(integral$value) + anchor),
    lower = lower,
    upper = upper,
    relative_error = as.numeric(relative_error)
  )
}

goal002r_certify_quadrature <- function(
  zero_history,
  mu_alpha,
  sigma_alpha,
  camera_effect,
  candidate_orders = goal002r_contract()$quadrature_orders,
  reference_order = goal002r_contract()$quadrature_reference,
  tolerance = goal002r_contract()$log_integral_tolerance
) {
  candidate_orders <- as.integer(candidate_orders)
  if (length(candidate_orders) == 0L || any(candidate_orders < 1L) ||
      anyDuplicated(candidate_orders)) {
    .goal002r_stop("candidate_orders must be unique positive integers.")
  }
  reference <- goal002r_reference_log_m0(
    zero_history,
    mu_alpha,
    sigma_alpha,
    camera_effect
  )
  reference_quadrature <- goal002r_log_m0(
    zero_history,
    mu_alpha,
    sigma_alpha,
    camera_effect,
    rule = goal002r_gauss_hermite_rule(reference_order)
  )
  reference_error <- abs(reference_quadrature - reference$log_m0)
  candidate_values <- vapply(
    candidate_orders,
    function(order) goal002r_log_m0(
      zero_history,
      mu_alpha,
      sigma_alpha,
      camera_effect,
      rule = goal002r_gauss_hermite_rule(order)
    ),
    numeric(1)
  )
  errors <- abs(candidate_values - reference$log_m0)
  passed <- is.finite(errors) & errors <= tolerance
  selected <- if (reference_error <= tolerance && any(passed)) {
    candidate_orders[which(passed)[1L]]
  } else {
    NA_integer_
  }
  list(
    reference = reference,
    reference_quadrature = reference_quadrature,
    reference_error = reference_error,
    candidates = tibble::tibble(
      order = candidate_orders,
      log_m0 = candidate_values,
      absolute_error = errors,
      passed = passed
    ),
    selected_order = selected,
    tolerance = tolerance
  )
}

goal002r_sampler_health <- function(
  fit,
  thresholds = goal002r_default_health_thresholds()
) {
  .goal002r_validate_fit(fit)
  if (!is.list(thresholds)) {
    .goal002r_stop("thresholds must be a Goal002R threshold list.")
  }
  thresholds <- goal002r_default_health_thresholds(
    max_divergences = thresholds$max_divergences,
    max_treedepth_hits = thresholds$max_treedepth_hits,
    min_ebfmi = thresholds$min_ebfmi,
    max_rhat = thresholds$max_rhat,
    min_bulk_ess = thresholds$min_bulk_ess,
    min_tail_ess = thresholds$min_tail_ess
  )
  if (is.null(fit$backend) ||
      !is.function(fit$backend$diagnostic_summary) ||
      !is.function(fit$backend$summary)) {
    .goal002r_stop("Fit backend does not expose CmdStan sampler diagnostics.")
  }
  diagnostic <- fit$backend$diagnostic_summary()
  variables <- c(
    "omega", "mu_alpha", "sigma_alpha", "sigma_camera",
    "q_unseen", "expected_richness"
  )
  summary <- fit$backend$summary(variables)
  required_summary <- c("variable", "rhat", "ess_bulk", "ess_tail")
  if (!all(required_summary %in% names(summary)) ||
      nrow(summary) != length(variables)) {
    .goal002r_stop("CmdStan sampler summary has an unexpected schema.")
  }
  divergences <- sum(diagnostic$num_divergent)
  treedepth_hits <- sum(diagnostic$num_max_treedepth)
  min_ebfmi <- min(diagnostic$ebfmi)
  max_rhat <- max(summary$rhat)
  min_bulk_ess <- min(summary$ess_bulk)
  min_tail_ess <- min(summary$ess_tail)
  metrics <- c(
    divergences = divergences,
    treedepth_hits = treedepth_hits,
    min_ebfmi = min_ebfmi,
    max_rhat = max_rhat,
    min_bulk_ess = min_bulk_ess,
    min_tail_ess = min_tail_ess
  )
  passed <- all(is.finite(metrics)) &&
    divergences <= thresholds$max_divergences &&
    treedepth_hits <= thresholds$max_treedepth_hits &&
    min_ebfmi >= thresholds$min_ebfmi &&
    max_rhat <= thresholds$max_rhat &&
    min_bulk_ess >= thresholds$min_bulk_ess &&
    min_tail_ess >= thresholds$min_tail_ess
  message <- paste0(
    "divergences=", divergences,
    ", max_treedepth_hits=", treedepth_hits,
    ", min_ebfmi=", format(min_ebfmi, digits = 4),
    ", max_rhat=", format(max_rhat, digits = 4),
    ", min_bulk_ess=", format(min_bulk_ess, digits = 4),
    ", min_tail_ess=", format(min_tail_ess, digits = 4)
  )
  list(
    passed = isTRUE(passed),
    message = message,
    thresholds = thresholds,
    metrics = as.list(metrics)
  )
}

goal002r_validate_fit_health <- function(
  fit,
  thresholds = goal002r_default_health_thresholds()
) {
  .goal002r_validate_fit(fit)
  draws <- fit$draws
  required <- c(
    "omega", "mu_alpha", "sigma_alpha", "sigma_camera",
    "q_unseen", "S_grid", "expected_richness"
  )
  if (!all(required %in% colnames(draws)) ||
      anyNA(draws[, required, drop = FALSE]) ||
      any(!is.finite(draws[, required, drop = FALSE]))) {
    .goal002r_stop("Fit draws contain missing or non-finite health variables.")
  }
  data <- fit$data
  candidate_pool_size <- length(data$candidate_ids)
  observed_richness <- length(data$detected_ids)
  if (any(draws[, "omega"] < 0 | draws[, "omega"] > 1) ||
      any(draws[, "q_unseen"] < 0 | draws[, "q_unseen"] > 1) ||
      any(draws[, "S_grid"] != trunc(draws[, "S_grid"])) ||
      any(draws[, "S_grid"] < observed_richness | draws[, "S_grid"] > candidate_pool_size) ||
      any(abs(draws[, "expected_richness"] -
        observed_richness - length(data$unseen_ids) * draws[, "q_unseen"]) > 1e-10)) {
    .goal002r_stop("Fit draws violate richness support or reconstruction invariants.")
  }
  sampler_health <- fit$health
  if (is.null(sampler_health)) {
    sampler_health <- goal002r_sampler_health(fit, thresholds = thresholds)
  }
  if (!isTRUE(sampler_health$passed)) {
    .goal002r_stop(
      paste0("CmdStan sampler-health gate failed: ", sampler_health$message)
    )
  }
  TRUE
}
