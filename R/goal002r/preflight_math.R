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
    mode_initial_bound = 1,
    mode_max_expansions = 64L,
    tail_initial_scales = 8,
    tail_max_expansions = 20L,
    tail_relative_bound = 1e-14,
    tail_stability = 1e-9,
    richardson_max_halvings = 8L,
    richardson_convergence = 2.5e-6,
    reference_relative_slope = 1e-10,
    reference_scaled_uncertainty = 1e-4,
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

.goal002r_preflight_safe_score <- function(z, a, sigma_alpha, offset, inverse) {
  log_t <- a + sigma_alpha * z
  limit <- log(.Machine$double.xmax) - 4
  base <- -z + offset + inverse
  if (log_t > limit) {
    return(-sign(sigma_alpha) * .Machine$double.xmax / 4)
  }
  score <- base - sigma_alpha * exp(log_t)
  if (!is.finite(score)) {
    .goal002r_stop("Oracle score evaluation was non-finite.")
  }
  score
}

.goal002r_preflight_mode <- function(score, curvature, domain) {
  contract <- goal002r_preflight_contract()
  bound <- contract$mode_initial_bound
  epsilon <- sqrt(.Machine$double.eps)
  if (domain == "whole") {
    lower <- -bound
    upper <- bound
    left_expansions <- 0L
    right_expansions <- 0L
    while (score(lower) <= 0 &&
           left_expansions < contract$mode_max_expansions) {
      lower <- lower * 2
      left_expansions <- left_expansions + 1L
    }
    while (score(upper) >= 0 &&
           right_expansions < contract$mode_max_expansions) {
      upper <- upper * 2
      right_expansions <- right_expansions + 1L
    }
  } else if (domain == "positive") {
    lower <- epsilon
    upper <- bound
    right_expansions <- 0L
    while (score(upper) >= 0 &&
           right_expansions < contract$mode_max_expansions) {
      upper <- upper * 2
      right_expansions <- right_expansions + 1L
    }
  } else {
    lower <- -bound
    upper <- -epsilon
    left_expansions <- 0L
    while (score(lower) <= 0 &&
           left_expansions < contract$mode_max_expansions) {
      lower <- lower * 2
      left_expansions <- left_expansions + 1L
    }
  }
  lower_score <- score(lower)
  upper_score <- score(upper)
  if (!is.finite(lower_score) || !is.finite(upper_score) ||
      lower_score <= 0 || upper_score >= 0) {
    .goal002r_stop("Oracle mode could not be bracketed.")
  }
  mode <- stats::uniroot(
    score,
    interval = c(lower, upper),
    tol = 1e-12,
    maxiter = 100L
  )$root
  mode_curvature <- curvature(mode)
  if (!is.finite(mode) || !is.finite(mode_curvature) ||
      mode_curvature >= 0) {
    .goal002r_stop("Oracle mode or curvature was invalid.")
  }
  list(mode = mode, scale = 1 / sqrt(-mode_curvature))
}

.goal002r_preflight_log_add <- function(x, y) {
  larger <- max(x, y)
  larger + log(exp(x - larger) + exp(y - larger))
}

.goal002r_preflight_integral_once <- function(
  log_kernel,
  mode,
  scale,
  lower_y,
  upper_y,
  rel_tol
) {
  modal_log_kernel <- log_kernel(mode)
  integrand <- function(y) {
    value <- exp(log_kernel(mode + scale * y) - modal_log_kernel)
    if (any(!is.finite(value))) {
      .goal002r_stop("Oracle integrand was non-finite.")
    }
    value
  }
  left <- stats::integrate(
    integrand,
    lower = lower_y,
    upper = 0,
    rel.tol = rel_tol,
    abs.tol = rel_tol,
    subdivisions = 1000L,
    stop.on.error = TRUE
  )$value
  right <- stats::integrate(
    integrand,
    lower = 0,
    upper = upper_y,
    rel.tol = rel_tol,
    abs.tol = rel_tol,
    subdivisions = 1000L,
    stop.on.error = TRUE
  )$value
  enclosed <- left + right
  if (!is.finite(enclosed) || enclosed <= 0) {
    .goal002r_stop("Oracle integral was invalid.")
  }
  log_factor <- log(scale) + log(enclosed)
  list(
    log_integral = modal_log_kernel + log_factor,
    anchor = modal_log_kernel,
    log_factor = log_factor
  )
}

.goal002r_preflight_primitive <- function(
  log_kernel,
  score,
  curvature,
  domain,
  rel_tol,
  initial_scales
) {
  contract <- goal002r_preflight_contract()
  location <- .goal002r_preflight_mode(score, curvature, domain)
  mode <- location$mode
  scale <- location$scale
  bounded_left <- identical(domain, "positive")
  bounded_right <- identical(domain, "negative")

  evaluate <- function(expansions) {
    distance <- initial_scales * 2^expansions
    lower_y <- if (bounded_left) -mode / scale else -distance
    upper_y <- if (bounded_right) -mode / scale else distance
    integral <- .goal002r_preflight_integral_once(
      log_kernel,
      mode,
      scale,
      lower_y,
      upper_y,
      rel_tol
    )
    log_bounds <- numeric(0)
    if (!bounded_left) {
      lower <- mode + scale * lower_y
      lower_score <- score(lower)
      if (!is.finite(lower_score) || lower_score <= 0) {
        .goal002r_stop("Oracle left-tail score was invalid.")
      }
      log_bounds <- c(
        log_bounds,
        log_kernel(lower) - log(lower_score)
      )
    }
    if (!bounded_right) {
      upper <- mode + scale * upper_y
      upper_score <- score(upper)
      if (!is.finite(upper_score) || upper_score >= 0) {
        .goal002r_stop("Oracle right-tail score was invalid.")
      }
      log_bounds <- c(
        log_bounds,
        log_kernel(upper) - log(-upper_score)
      )
    }
    if (any(!is.finite(log_bounds))) {
      .goal002r_stop("Oracle tail bound was non-finite.")
    }
    log_bound <- if (length(log_bounds) == 1L) {
      log_bounds
    } else {
      .goal002r_preflight_log_add(log_bounds[1], log_bounds[2])
    }
    relative_bound <- exp(log_bound - integral$log_integral)
    if (!is.finite(relative_bound)) {
      .goal002r_stop("Oracle relative tail bound was non-finite.")
    }
    c(integral, list(relative_bound = relative_bound))
  }

  expansions <- 0L
  first <- evaluate(expansions)
  while (first$relative_bound > contract$tail_relative_bound &&
         expansions < contract$tail_max_expansions) {
    expansions <- expansions + 1L
    first <- evaluate(expansions)
  }
  if (first$relative_bound > contract$tail_relative_bound ||
      expansions >= contract$tail_max_expansions) {
    .goal002r_stop("Oracle tail certification did not converge.")
  }
  expanded <- evaluate(expansions + 1L)
  list(
    first = first,
    expanded = expanded,
    relative_bound = first$relative_bound,
    expansions = expansions + 1L
  )
}

.goal002r_preflight_signed_difference <- function(positive, negative) {
  if (positive >= negative) {
    exp(positive) * (-expm1(negative - positive))
  } else {
    -exp(negative) * (-expm1(positive - negative))
  }
}

.goal002r_preflight_combine_primitives <- function(log_integrals) {
  denominator <- log_integrals[["denominator"]]
  log_ratio <- function(numerator) {
    (numerator$anchor - denominator$anchor) +
      (numerator$log_factor - denominator$log_factor)
  }
  log_denominator <- denominator$log_integral
  sigma_ratio <- .goal002r_preflight_signed_difference(
    log_ratio(log_integrals[["sigma_positive"]]),
    log_ratio(log_integrals[["sigma_negative"]])
  )
  c(
    log_m0 = log_denominator,
    derivative_a = -exp(log_ratio(log_integrals[["numerator_a"]])),
    derivative_sigma = -sigma_ratio
  )
}

.goal002r_preflight_reference_core <- function(
  a,
  sigma_alpha,
  rel_tol,
  initial_scales = goal002r_preflight_contract()$tail_initial_scales
) {
  if (sigma_alpha == 0) {
    exact <- c(
      log_m0 = -exp(a),
      derivative_a = -exp(a),
      derivative_sigma = 0
    )
    attr(exact, "tail_relative_bound") <- 0
    attr(exact, "expansion_change") <- 0
    attr(exact, "tail_expansions") <- 0L
    return(exact)
  }

  log_denominator <- function(z) {
    log_t <- a + sigma_alpha * z
    t <- exp(pmin(log_t, log(.Machine$double.xmax) - 4))
    stats::dnorm(z, log = TRUE) - t
  }
  log_numerator_a <- function(z) {
    log_denominator(z) + a + sigma_alpha * z
  }
  log_sigma_magnitude <- function(z) {
    log_numerator_a(z) + log(abs(z))
  }
  score_denominator <- function(z) {
    .goal002r_preflight_safe_score(z, a, sigma_alpha, 0, 0)
  }
  score_numerator_a <- function(z) {
    .goal002r_preflight_safe_score(
      z,
      a,
      sigma_alpha,
      sigma_alpha,
      0
    )
  }
  score_sigma_magnitude <- function(z) {
    .goal002r_preflight_safe_score(
      z,
      a,
      sigma_alpha,
      sigma_alpha,
      1 / z
    )
  }
  curvature_common <- function(z) {
    log_t <- a + sigma_alpha * z
    curvature <- -1 - sigma_alpha^2 * exp(log_t)
    if (!is.finite(curvature)) {
      .goal002r_stop("Oracle curvature was non-finite.")
    }
    curvature
  }
  curvature_sigma <- function(z) curvature_common(z) - 1 / z^2

  primitives <- list(
    denominator = .goal002r_preflight_primitive(
      log_denominator,
      score_denominator,
      curvature_common,
      "whole",
      rel_tol,
      initial_scales
    ),
    numerator_a = .goal002r_preflight_primitive(
      log_numerator_a,
      score_numerator_a,
      curvature_common,
      "whole",
      rel_tol,
      initial_scales
    ),
    sigma_positive = .goal002r_preflight_primitive(
      log_sigma_magnitude,
      score_sigma_magnitude,
      curvature_sigma,
      "positive",
      rel_tol,
      initial_scales
    ),
    sigma_negative = .goal002r_preflight_primitive(
      log_sigma_magnitude,
      score_sigma_magnitude,
      curvature_sigma,
      "negative",
      rel_tol,
      initial_scales
    )
  )
  first <- lapply(primitives, `[[`, "first")
  expanded <- lapply(primitives, `[[`, "expanded")
  first_value <- .goal002r_preflight_combine_primitives(first)
  expanded_value <- .goal002r_preflight_combine_primitives(expanded)
  output_changes <- abs(first_value - expanded_value)
  expansion_change <- max(output_changes)
  if (any(!is.finite(expanded_value)) || !is.finite(expansion_change) ||
      expansion_change > goal002r_preflight_contract()$tail_stability) {
    .goal002r_stop(paste0(
      "Oracle expansion stability check failed: change = ",
      format(expansion_change, digits = 17),
      "; component changes = ",
      paste(format(output_changes, digits = 17), collapse = ", "),
      "; primitive log changes = ",
      paste(format(vapply(
        names(first),
        function(name) abs(
          first[[name]]$log_integral - expanded[[name]]$log_integral
        ),
        numeric(1)
      ), digits = 17), collapse = ", "),
      "."
    ))
  }
  attr(expanded_value, "tail_relative_bound") <- max(vapply(
    primitives,
    `[[`,
    numeric(1),
    "relative_bound"
  ))
  attr(expanded_value, "expansion_change") <- expansion_change
  attr(expanded_value, "tail_expansions") <- max(vapply(
    primitives,
    `[[`,
    integer(1),
    "expansions"
  ))
  expanded_value
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
  contract <- goal002r_preflight_contract()
  tolerance <- goal002r_preflight_contract()$reference_tolerances
  loose <- goal002r_preflight_reference(
    a,
    sigma_alpha,
    tolerance[1]
  )
  strict <- goal002r_preflight_reference(
    a,
    sigma_alpha,
    tolerance[2]
  )
  value_agreement <- abs(strict[["log_m0"]] - loose[["log_m0"]])
  derivative_a_agreement <- abs(
    strict[["derivative_a"]] - loose[["derivative_a"]]
  )
  derivative_sigma_agreement <- abs(
    strict[["derivative_sigma"]] - loose[["derivative_sigma"]]
  )
  derivative_a_mixed_limit <- contract$reference_agreement +
    contract$reference_relative_slope * abs(strict[["derivative_a"]])
  derivative_sigma_mixed_limit <- contract$reference_agreement +
    contract$reference_relative_slope * abs(strict[["derivative_sigma"]])
  scaled_reference_a_uncertainty <- contract$max_unseen *
    contract$gradient_scales[["a"]] * derivative_a_agreement
  scaled_reference_sigma_uncertainty <- contract$max_unseen * max(
    contract$gradient_scales[["sigma"]],
    contract$gradient_scales[["log_sigma"]] * sigma_alpha
  ) * derivative_sigma_agreement
  c(
    strict,
    value_agreement = value_agreement,
    derivative_a_agreement = derivative_a_agreement,
    derivative_sigma_agreement = derivative_sigma_agreement,
    derivative_a_mixed_limit = derivative_a_mixed_limit,
    derivative_sigma_mixed_limit = derivative_sigma_mixed_limit,
    derivative_a_mixed_pass = as.numeric(
      derivative_a_agreement <= derivative_a_mixed_limit
    ),
    derivative_sigma_mixed_pass = as.numeric(
      derivative_sigma_agreement <= derivative_sigma_mixed_limit
    ),
    scaled_reference_a_uncertainty = scaled_reference_a_uncertainty,
    scaled_reference_sigma_uncertainty = scaled_reference_sigma_uncertainty,
    scaled_reference_a_pass = as.numeric(
      scaled_reference_a_uncertainty <= contract$reference_scaled_uncertainty
    ),
    scaled_reference_sigma_pass = as.numeric(
      scaled_reference_sigma_uncertainty <=
        contract$reference_scaled_uncertainty
    ),
    maximum_tail_relative_bound = max(
      attr(loose, "tail_relative_bound"),
      attr(strict, "tail_relative_bound")
    ),
    maximum_expansion_change = max(
      attr(loose, "expansion_change"),
      attr(strict, "expansion_change")
    ),
    maximum_tail_expansions = max(
      attr(loose, "tail_expansions"),
      attr(strict, "tail_expansions")
    )
  )
}

goal002r_preflight_derivative_checks <- function(states) {
  if (!tibble::is_tibble(states) ||
      !identical(names(states), c("a", "sigma_alpha"))) {
    .goal002r_stop("states must contain exactly a and sigma_alpha.")
  }
  contract <- goal002r_preflight_contract()
  tolerance <- contract$finite_difference_tolerance
  rel_tol <- contract$reference_tolerances[2]
  richardson <- function(a, sigma_alpha, parameter, initial_step) {
    value <- function(offset) {
      a_value <- a
      sigma_value <- sigma_alpha
      if (parameter == "a") {
        a_value <- a_value + offset
      } else {
        sigma_value <- sigma_value + offset
      }
      .goal002r_preflight_reference_core(
        a_value,
        sigma_value,
        rel_tol
      )[["log_m0"]]
    }
    steps <- initial_step / 2^(0:contract$richardson_max_halvings)
    centred <- vapply(
      steps,
      function(step) (value(step) - value(-step)) / (2 * step),
      numeric(1)
    )
    estimates <- (
      4 * centred[-1L] - centred[-length(centred)]
    ) / 3
    differences <- abs(diff(estimates))
    accepted <- which(differences <= contract$richardson_convergence)[1]
    if (is.na(accepted)) {
      return(list(
        estimate = estimates[length(estimates)],
        refinements = contract$richardson_max_halvings,
        converged = FALSE
      ))
    }
    estimate_index <- accepted + 1L
    list(
      estimate = estimates[estimate_index],
      refinements = as.integer(estimate_index),
      converged = TRUE
    )
  }
  rows <- lapply(seq_len(nrow(states)), function(index) {
    a <- states$a[index]
    sigma_alpha <- states$sigma_alpha[index]
    analytic <- goal002r_preflight_reference(
      a,
      sigma_alpha,
      rel_tol
    )
    h_a <- 1e-5
    h_sigma <- max(1e-5, sigma_alpha * 1e-5)
    check_a <- richardson(a, sigma_alpha, "a", h_a)
    if (sigma_alpha == 0) {
      positive <- .goal002r_preflight_reference_core(
        a,
        1e-5,
        rel_tol
      )[["log_m0"]]
      negative <- .goal002r_preflight_reference_core(
        a,
        -1e-5,
        rel_tol
      )[["log_m0"]]
      check_sigma <- list(
        estimate = analytic[["derivative_sigma"]],
        refinements = 0L,
        converged = TRUE,
        evenness = abs(positive - negative),
        method = "exact_evenness"
      )
    } else {
      check_sigma <- richardson(a, sigma_alpha, "sigma_alpha", h_sigma)
      check_sigma$evenness <- NA_real_
      check_sigma$method <- "richardson"
    }
    estimates <- c(check_a$estimate, check_sigma$estimate)
    analytic <- unname(analytic[c("derivative_a", "derivative_sigma")])
    absolute_error <- abs(analytic - estimates)
    observed <- c(absolute_error[1], if (sigma_alpha == 0) {
      check_sigma$evenness
    } else {
      absolute_error[2]
    })
    thresholds <- c(tolerance, if (sigma_alpha == 0) 1e-12 else tolerance)
    converged <- c(check_a$converged, check_sigma$converged)
    zero_derivative <- sigma_alpha != 0 || analytic[2] == 0
    passed <- converged & observed <= thresholds & c(TRUE, zero_derivative)
    tibble::tibble(
      a = rep(a, 2L),
      sigma_alpha = rep(sigma_alpha, 2L),
      parameter = c("a", "sigma_alpha"),
      method = c("richardson", check_sigma$method),
      analytic = analytic,
      estimate = estimates,
      absolute_error = absolute_error,
      observed = observed,
      threshold = thresholds,
      refinements = c(check_a$refinements, check_sigma$refinements),
      converged = converged,
      passed = passed
    )
  })
  do.call(rbind, rows)
}

.goal002r_preflight_reference_states <- function() {
  dplyr::bind_rows(
    tidyr::crossing(
      a = seq(-8, 10, length.out = 61L),
      sigma_alpha = seq(0, 5.5, length.out = 61L)
    ),
    tibble::tibble(
      a = 10,
      sigma_alpha = c(1e-2, 1e-3, 1e-4, 1e-5, 1e-6)
    )
  ) |>
    dplyr::distinct(a, sigma_alpha)
}

.goal002r_preflight_reference_precheck_row <- function(
  a,
  sigma_alpha,
  pair
) {
  contract <- goal002r_preflight_contract()
  finite <- all(is.finite(pair))
  value_pass <- pair[["value_agreement"]] <= contract$reference_agreement
  tail_pass <- pair[["maximum_tail_relative_bound"]] <=
    contract$tail_relative_bound
  stability_pass <- pair[["maximum_expansion_change"]] <=
    contract$tail_stability
  passed <- finite && value_pass &&
    pair[["derivative_a_mixed_pass"]] == 1 &&
    pair[["derivative_sigma_mixed_pass"]] == 1 &&
    pair[["scaled_reference_a_pass"]] == 1 &&
    pair[["scaled_reference_sigma_pass"]] == 1 &&
    tail_pass && stability_pass
  tibble::tibble(
    a = a,
    sigma_alpha = sigma_alpha,
    strict_log_m0 = pair[["log_m0"]],
    strict_derivative_a = pair[["derivative_a"]],
    strict_derivative_sigma = pair[["derivative_sigma"]],
    delta_value = pair[["value_agreement"]],
    delta_a = pair[["derivative_a_agreement"]],
    delta_sigma = pair[["derivative_sigma_agreement"]],
    derivative_a_mixed_limit = pair[["derivative_a_mixed_limit"]],
    derivative_sigma_mixed_limit = pair[["derivative_sigma_mixed_limit"]],
    derivative_a_mixed_pass = pair[["derivative_a_mixed_pass"]] == 1,
    derivative_sigma_mixed_pass =
      pair[["derivative_sigma_mixed_pass"]] == 1,
    scaled_reference_a_uncertainty =
      pair[["scaled_reference_a_uncertainty"]],
    scaled_reference_sigma_uncertainty =
      pair[["scaled_reference_sigma_uncertainty"]],
    scaled_reference_a_pass = pair[["scaled_reference_a_pass"]] == 1,
    scaled_reference_sigma_pass = pair[["scaled_reference_sigma_pass"]] == 1,
    maximum_tail_relative_bound =
      pair[["maximum_tail_relative_bound"]],
    maximum_expansion_change = pair[["maximum_expansion_change"]],
    maximum_tail_expansions = as.integer(
      pair[["maximum_tail_expansions"]]
    ),
    passed = passed
  )
}

.goal002r_preflight_first_reference_failure <- function(result) {
  contract <- goal002r_preflight_contract()
  for (index in seq_len(nrow(result))) {
    criteria <- list(
      delta_value = c(
        result$delta_value[index],
        contract$reference_agreement
      ),
      delta_a = c(
        result$delta_a[index],
        result$derivative_a_mixed_limit[index]
      ),
      delta_sigma = c(
        result$delta_sigma[index],
        result$derivative_sigma_mixed_limit[index]
      ),
      scaled_reference_a_uncertainty = c(
        result$scaled_reference_a_uncertainty[index],
        contract$reference_scaled_uncertainty
      ),
      scaled_reference_sigma_uncertainty = c(
        result$scaled_reference_sigma_uncertainty[index],
        contract$reference_scaled_uncertainty
      ),
      maximum_tail_relative_bound = c(
        result$maximum_tail_relative_bound[index],
        contract$tail_relative_bound
      ),
      maximum_expansion_change = c(
        result$maximum_expansion_change[index],
        contract$tail_stability
      )
    )
    for (criterion in names(criteria)) {
      values <- criteria[[criterion]]
      if (!is.finite(values[1]) || values[1] > values[2]) {
        return(tibble::tibble(
          a = result$a[index],
          sigma_alpha = result$sigma_alpha[index],
          criterion = criterion,
          observed = values[1],
          threshold = values[2]
        ))
      }
    }
  }
  tibble::tibble(
    a = numeric(0),
    sigma_alpha = numeric(0),
    criterion = character(0),
    observed = numeric(0),
    threshold = numeric(0)
  )
}

goal002r_preflight_reference_precheck <- function() {
  states <- .goal002r_preflight_reference_states()
  if (nrow(states) != 3726L) {
    .goal002r_stop("Reference precheck state construction was invalid.")
  }
  rows <- lapply(seq_len(nrow(states)), function(index) {
    a <- states$a[index]
    sigma_alpha <- states$sigma_alpha[index]
    pair <- tryCatch(
      goal002r_preflight_reference_pair(a, sigma_alpha),
      error = function(error) {
        .goal002r_stop(paste0(
          "Reference precheck oracle error at a = ",
          format(a, digits = 17),
          ", sigma_alpha = ",
          format(sigma_alpha, digits = 17),
          ": ",
          conditionMessage(error)
        ))
      }
    )
    .goal002r_preflight_reference_precheck_row(a, sigma_alpha, pair)
  })
  result <- dplyr::bind_rows(rows)
  if (nrow(result) != 3726L) {
    .goal002r_stop("Reference precheck did not complete every state.")
  }
  if (any(!result$passed)) {
    failure <- .goal002r_preflight_first_reference_failure(result)
    message(
      "first failing state: a = ",
      format(failure$a, digits = 17),
      ", sigma_alpha = ",
      format(failure$sigma_alpha, digits = 17),
      "; criterion = ",
      failure$criterion,
      "; observed = ",
      format(failure$observed, digits = 17),
      "; threshold = ",
      format(failure$threshold, digits = 17)
    )
  }
  result
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
