goal002r_preflight_contract <- function() {
  list(
    orders = c(256L, 512L),
    a_bounds = c(-8, 10),
    sigma_bounds = c(0, 5.5),
    grid_size = 61L,
    max_unseen = 29L,
    search_starts = 12L,
    reference_tolerances = c(1e-10, 1e-12),
    reference_agreement = 1e-8,
    finite_difference_tolerance = 1e-5,
    value_gate = 5e-4,
    gradient_max_gate = 1e-2,
    gradient_rms_gate = 1e-3,
    selection_headroom = 0.5,
    gradient_scales = c(a = 1.5, sigma = 0.85, log_sigma = 1.2),
    posterior_state_file = file.path(
      "docs", "consultations", "goal002r-next-step", "evidence",
      "numerical-screen-states.csv"
    ),
    case_file = file.path(
      "docs", "consultations", "goal002r-next-step", "evidence",
      "case-results.csv"
    ),
    output_component = "decision-scale-preflight"
  )
}

.goal002r_preflight_log_sum_exp <- function(x) {
  anchor <- max(x)
  if (!is.finite(anchor)) return(anchor)
  anchor + log(sum(exp(x - anchor)))
}

.goal002r_preflight_log_hermite <- function(x, degree) {
  previous <- 1
  if (degree == 0L) return(0)
  current <- x
  log_scale <- 0
  if (degree == 1L) return(log(abs(current)))

  for (k in seq_len(degree - 1L)) {
    next_value <- (
      x * current - sqrt(k) * previous
    ) / sqrt(k + 1)
    magnitude <- max(abs(c(previous, current, next_value)))
    if (magnitude > 1e100 || (magnitude > 0 && magnitude < 1e-100)) {
      previous <- previous / magnitude
      current <- current / magnitude
      next_value <- next_value / magnitude
      log_scale <- log_scale + log(magnitude)
    }
    previous <- current
    current <- next_value
  }
  log(abs(current)) + log_scale
}

.goal002r_preflight_order <- function(order) {
  order <- .goal002r_scalar(order, "order", lower = 1)
  if (order != trunc(order) ||
      !order %in% goal002r_preflight_contract()$orders) {
    .goal002r_stop("Preflight order must be exactly 256 or 512.")
  }
  as.integer(order)
}

goal002r_preflight_rule <- function(order) {
  order <- .goal002r_preflight_order(order)
  jacobi <- matrix(0, nrow = order, ncol = order)
  off_diagonal <- sqrt(seq_len(order - 1L))
  jacobi[cbind(seq_len(order - 1L), seq_len(order - 1L) + 1L)] <-
    off_diagonal
  jacobi[cbind(seq_len(order - 1L) + 1L, seq_len(order - 1L))] <-
    off_diagonal
  node <- sort(eigen(
    jacobi,
    symmetric = TRUE,
    only.values = TRUE
  )$values)
  log_weight <- -log(order) - 2 * vapply(
    node,
    .goal002r_preflight_log_hermite,
    numeric(1),
    degree = order - 1L
  )
  log_weight <- log_weight -
    .goal002r_preflight_log_sum_exp(log_weight)
  tibble::tibble(node = node, log_weight = log_weight)
}

goal002r_preflight_rule_checks <- function(rule, order) {
  order <- .goal002r_preflight_order(order)
  expected_moments <- c(`0` = 1, `2` = 1, `4` = 3, `6` = 15, `8` = 105, `10` = 945)
  weights <- exp(rule$log_weight)
  moments <- vapply(
    as.integer(names(expected_moments)),
    function(power) sum(weights * rule$node^power),
    numeric(1)
  )
  check <- c(
    "node_symmetry",
    "log_weight_symmetry",
    "normalisation",
    paste0("moment_", names(expected_moments))
  )
  observed <- c(
    max(abs(rule$node + rev(rule$node))),
    max(abs(rule$log_weight - rev(rule$log_weight))),
    abs(sum(weights) - 1),
    abs(moments - unname(expected_moments))
  )
  threshold <- c(rep(5e-10, 2L), 1e-12, rep(1e-11, length(moments)))
  tibble::tibble(
    order = rep(order, length(check)),
    check = check,
    observed = observed,
    threshold = threshold,
    passed = observed <= threshold
  )
}

goal002r_preflight_gh <- function(a, sigma_alpha, rule) {
  contract <- goal002r_preflight_contract()
  a <- .goal002r_scalar(
    a,
    "a",
    lower = contract$a_bounds[1],
    upper = contract$a_bounds[2]
  )
  sigma_alpha <- .goal002r_scalar(
    sigma_alpha,
    "sigma_alpha",
    lower = contract$sigma_bounds[1],
    upper = contract$sigma_bounds[2]
  )
  if (sigma_alpha == 0) {
    value <- -exp(a)
    return(c(
      log_m0 = value,
      derivative_a = value,
      derivative_sigma = 0
    ))
  }

  log_t <- a + sigma_alpha * rule$node
  t_value <- exp(log_t)
  log_terms <- rule$log_weight - t_value
  log_m0 <- .goal002r_preflight_log_sum_exp(log_terms)
  normalised <- exp(log_terms - log_m0)
  weighted_t <- normalised * t_value
  c(
    log_m0 = log_m0,
    derivative_a = -sum(weighted_t),
    derivative_sigma = -sum(rule$node * weighted_t)
  )
}

.goal002r_preflight_anchored_integral <- function(
  log_kernel,
  lower,
  upper,
  rel_tol
) {
  optimum <- stats::optimize(
    log_kernel,
    interval = c(lower, upper),
    maximum = TRUE
  )
  anchor <- log_kernel(optimum$maximum)
  anchored <- stats::integrate(
    function(z) exp(log_kernel(z) - anchor),
    lower = lower,
    upper = upper,
    rel.tol = rel_tol,
    abs.tol = 0
  )$value
  anchor + log(anchored)
}

.goal002r_preflight_reference_core <- function(a, sigma_alpha, rel_tol) {
  if (sigma_alpha == 0) {
    value <- -exp(a)
    return(c(
      log_m0 = value,
      derivative_a = value,
      derivative_sigma = 0
    ))
  }

  log_denominator <- function(z) {
    log_t <- a + sigma_alpha * z
    stats::dnorm(z, log = TRUE) - exp(log_t)
  }
  log_numerator_a <- function(z) {
    log_denominator(z) + a + sigma_alpha * z
  }
  log_numerator_sigma <- function(z) {
    log_numerator_a(z) + log(abs(z))
  }
  anchored_integral <- function(log_kernel, lower, upper) {
    .goal002r_preflight_anchored_integral(
      log_kernel,
      lower,
      upper,
      rel_tol
    )
  }

  log_denominator_integral <- anchored_integral(log_denominator, -12, 12)
  log_numerator_a_integral <- anchored_integral(
    log_numerator_a,
    -12,
    12
  )
  log_numerator_sigma_positive <- anchored_integral(
    log_numerator_sigma,
    0,
    12
  )
  log_numerator_sigma_negative <- anchored_integral(
    log_numerator_sigma,
    -12,
    0
  )
  numerator_sigma_over_denominator <-
    exp(log_numerator_sigma_positive - log_denominator_integral) -
    exp(log_numerator_sigma_negative - log_denominator_integral)
  c(
    log_m0 = log_denominator_integral,
    derivative_a = -exp(
      log_numerator_a_integral - log_denominator_integral
    ),
    derivative_sigma = -numerator_sigma_over_denominator
  )
}

goal002r_preflight_reference <- function(a, sigma_alpha, rel_tol) {
  contract <- goal002r_preflight_contract()
  a <- .goal002r_scalar(
    a,
    "a",
    lower = contract$a_bounds[1],
    upper = contract$a_bounds[2]
  )
  sigma_alpha <- .goal002r_scalar(
    sigma_alpha,
    "sigma_alpha",
    lower = contract$sigma_bounds[1],
    upper = contract$sigma_bounds[2]
  )
  rel_tol <- .goal002r_scalar(rel_tol, "rel_tol", lower = 0)
  if (rel_tol == 0) {
    .goal002r_stop("rel_tol must be positive.")
  }
  .goal002r_preflight_reference_core(a, sigma_alpha, rel_tol)
}

goal002r_preflight_reference_pair <- function(a, sigma_alpha) {
  tolerance <- goal002r_preflight_contract()$reference_tolerances
  loose <- goal002r_preflight_reference(a, sigma_alpha, tolerance[1])
  strict <- goal002r_preflight_reference(a, sigma_alpha, tolerance[2])
  c(
    strict,
    value_agreement = abs(strict[["log_m0"]] - loose[["log_m0"]]),
    derivative_a_agreement = abs(
      strict[["derivative_a"]] - loose[["derivative_a"]]
    ),
    derivative_sigma_agreement = abs(
      strict[["derivative_sigma"]] - loose[["derivative_sigma"]]
    )
  )
}

goal002r_preflight_finite_difference_checks <- function(states) {
  if (!tibble::is_tibble(states) ||
      !identical(names(states), c("a", "sigma_alpha"))) {
    .goal002r_stop("states must contain exactly a and sigma_alpha.")
  }
  tolerance <- goal002r_preflight_contract()$finite_difference_tolerance
  rel_tol <- goal002r_preflight_contract()$reference_tolerances[2]
  rows <- lapply(seq_len(nrow(states)), function(index) {
    a <- states$a[index]
    sigma_alpha <- states$sigma_alpha[index]
    analytic <- goal002r_preflight_reference(
      a,
      sigma_alpha,
      rel_tol
    )
    value <- function(a_value, sigma_value) {
      .goal002r_preflight_reference_core(
        a_value,
        sigma_value,
        rel_tol
      )[["log_m0"]]
    }
    h_a <- 1e-5
    h_sigma <- max(1e-5, sigma_alpha * 1e-5)
    finite_difference_a <- (
      value(a + h_a, sigma_alpha) -
      value(a - h_a, sigma_alpha)
    ) / (2 * h_a)
    if (sigma_alpha - h_sigma < 0) {
      finite_difference_sigma <- (
        value(a, sigma_alpha + h_sigma) -
        value(a, sigma_alpha)
      ) / h_sigma
    } else {
      finite_difference_sigma <- (
        value(a, sigma_alpha + h_sigma) -
        value(a, sigma_alpha - h_sigma)
      ) / (2 * h_sigma)
    }
    finite_difference <- c(finite_difference_a, finite_difference_sigma)
    analytic <- unname(analytic[c("derivative_a", "derivative_sigma")])
    absolute_error <- abs(analytic - finite_difference)
    tibble::tibble(
      a = rep(a, 2L),
      sigma_alpha = rep(sigma_alpha, 2L),
      parameter = c("a", "sigma_alpha"),
      analytic = analytic,
      finite_difference = finite_difference,
      absolute_error = absolute_error,
      passed = absolute_error <= tolerance
    )
  })
  do.call(rbind, rows)
}

goal002r_preflight_algebra_checks <- function() {
  zero_history <- tibble::tribble(
    ~camera_id, ~active_days, ~n_trials,
    "cam_01", 1L, 4L,
    "cam_01", 5L, 2L,
    "cam_02", 2L, 3L
  )
  camera_effect <- c(cam_01 = -0.2, cam_02 = 0.2)
  mu_alpha <- log(0.001)
  sigma_values <- c(0, 0.4, 1.1, 2)
  rule <- goal002r_preflight_rule(256L)
  exposure <- zero_history$active_days * zero_history$n_trials
  camera <- unname(camera_effect[zero_history$camera_id])
  a <- mu_alpha + .goal002r_preflight_log_sum_exp(log(exposure) + camera)

  results <- lapply(sigma_values, function(sigma_alpha) {
    rowwise_terms <- rule$log_weight - vapply(rule$node, function(node) {
      sum(exposure * exp(mu_alpha + sigma_alpha * node + camera))
    }, numeric(1))
    rowwise_log_m0 <- .goal002r_preflight_log_sum_exp(rowwise_terms)
    reduced_log_m0 <- goal002r_preflight_gh(
      a = a,
      sigma_alpha = sigma_alpha,
      rule = rule
    )[["log_m0"]]
    absolute_error <- abs(rowwise_log_m0 - reduced_log_m0)
    tibble::tibble(
      sigma_alpha = sigma_alpha,
      rowwise_log_m0 = rowwise_log_m0,
      reduced_log_m0 = reduced_log_m0,
      absolute_error = absolute_error,
      passed = absolute_error <= 1e-12
    )
  })
  do.call(rbind, results)
}
