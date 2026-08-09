#!/usr/bin/env Rscript

## Goal002R oracle-stability adjudication, Version 2.
## This is a deliberately isolated, one-state diagnostic.  It is not part of
## the production or full-preflight call graph.

script_args <- commandArgs(trailingOnly = FALSE)
script_arg <- script_args[grepl("^--file=", script_args)]
if (length(script_arg) != 1L) {
  stop("The adjudication runner must be invoked by Rscript.", call. = FALSE)
}
script_path <- normalizePath(sub("^--file=", "", script_arg), mustWork = TRUE)
project_root <- normalizePath(file.path(dirname(script_path), ".."), mustWork = TRUE)
expected_script_path <- normalizePath(
  file.path(project_root, "scripts", "run_goal002r_oracle_stability_adjudication.R"),
  mustWork = FALSE
)
if (!identical(script_path, expected_script_path)) {
  stop("The adjudication runner must be executed from its committed project path.", call. = FALSE)
}

## The only numerical failures that may be classified as oracle
## certification failures.  Everything else remains an implementation failure.
signal_numerical_error <- function(predicate, message) {
  condition <- structure(
    list(message = message, call = NULL, predicate = predicate),
    class = c("goal002r_adjudication_numerical_error", "error", "condition")
  )
  stop(condition)
}

## Frozen constants: do not turn these into command-line options.
adjudication_version <- "2"
a_frozen <- 10
sigma_frozen <- 0.01356952703481304
unseen_frozen <- 29L
rel_tolerances <- c(1e-10, 1e-12)
initial_scales <- 8
tail_relative_limit <- 1e-14
tail_max_expansions <- 20L
coverage_names <- c("certified", "expanded", "further_expanded")
richardson_start <- 1e-5
richardson_j <- 0:8
richardson_convergence <- 2.5e-6
reference_agreement <- 1e-8
reference_relative_slope <- 1e-10
derivative_sanity_limit <- 1e-5
decision_scaled_limit <- 1e-4
value_scaled_limit <- 5e-4
gradient_scales <- c(a = 1.5, sigma = 0.85, log_sigma = 1.2)
scale_a <- unseen_frozen * gradient_scales[["a"]]
scale_sigma <- unseen_frozen * max(
  gradient_scales[["sigma"]],
  gradient_scales[["log_sigma"]] * sigma_frozen
)

primitive_order <- c(
  "denominator", "numerator_a", "sigma_positive", "sigma_negative"
)
coverage_offsets <- stats::setNames(0:2, coverage_names)

is_finite_scalar <- function(x) {
  is.numeric(x) && length(x) == 1L && is.finite(x)
}

log_add_local <- function(x, y) {
  larger <- max(x, y)
  if (!is.finite(larger)) return(larger)
  larger + log(exp(x - larger) + exp(y - larger))
}

signed_difference_local <- function(positive, negative) {
  value <- if (positive >= negative) {
    exp(positive) * (-expm1(negative - positive))
  } else {
    -exp(negative) * (-expm1(positive - negative))
  }
  if (!is_finite_scalar(value)) {
    signal_numerical_error(
      "nonfinite_reconstruction",
      "Signed primitive reconstruction was non-finite."
    )
  }
  value
}

safe_score_local <- function(z, a, sigma_alpha, offset, inverse) {
  log_t <- a + sigma_alpha * z
  limit <- log(.Machine$double.xmax) - 4
  base <- -z + offset + inverse
  if (log_t > limit) {
    return(-sign(sigma_alpha) * .Machine$double.xmax / 4)
  }
  score <- base - sigma_alpha * exp(log_t)
  if (!is_finite_scalar(score)) {
    signal_numerical_error("nonfinite_score", "Oracle score was non-finite.")
  }
  score
}

mode_local <- function(score, curvature, domain) {
  bound <- 1
  epsilon <- sqrt(.Machine$double.eps)
  if (identical(domain, "whole")) {
    lower <- -bound
    upper <- bound
    left_expansions <- 0L
    right_expansions <- 0L
    while (score(lower) <= 0 && left_expansions < 64L) {
      lower <- lower * 2
      left_expansions <- left_expansions + 1L
    }
    while (score(upper) >= 0 && right_expansions < 64L) {
      upper <- upper * 2
      right_expansions <- right_expansions + 1L
    }
  } else if (identical(domain, "positive")) {
    lower <- epsilon
    upper <- bound
    right_expansions <- 0L
    while (score(upper) >= 0 && right_expansions < 64L) {
      upper <- upper * 2
      right_expansions <- right_expansions + 1L
    }
  } else if (identical(domain, "negative")) {
    lower <- -bound
    upper <- -epsilon
    left_expansions <- 0L
    while (score(lower) <= 0 && left_expansions < 64L) {
      lower <- lower * 2
      left_expansions <- left_expansions + 1L
    }
  } else {
    stop("Unknown primitive domain.", call. = FALSE)
  }
  lower_score <- score(lower)
  upper_score <- score(upper)
  if (!is_finite_scalar(lower_score) || !is_finite_scalar(upper_score) ||
      lower_score <= 0 || upper_score >= 0) {
    signal_numerical_error("invalid_mode_bracket", "Oracle mode was not bracketed.")
  }
  root <- stats::uniroot(
    score,
    interval = c(lower, upper),
    tol = 1e-12,
    maxiter = 100L
  )$root
  mode_curvature <- curvature(root)
  if (!is_finite_scalar(root) || !is_finite_scalar(mode_curvature) ||
      mode_curvature >= 0) {
    signal_numerical_error(
      "invalid_mode_curvature",
      "Oracle mode or curvature was invalid."
    )
  }
  list(mode = root, scale = 1 / sqrt(-mode_curvature))
}

integral_once_local <- function(
  log_kernel, mode, scale, lower_y, upper_y, rel_tol
) {
  modal_log_kernel <- log_kernel(mode)
  if (!is_finite_scalar(modal_log_kernel)) {
    signal_numerical_error(
      "nonfinite_integrand",
      "Modal log-kernel value was non-finite."
    )
  }
  integrand <- function(y) {
    value <- exp(log_kernel(mode + scale * y) - modal_log_kernel)
    if (any(!is.finite(value))) {
      signal_numerical_error("nonfinite_integrand", "Oracle integrand was non-finite.")
    }
    value
  }
  left <- stats::integrate(
    integrand, lower = lower_y, upper = 0,
    rel.tol = rel_tol, abs.tol = rel_tol,
    subdivisions = 1000L, stop.on.error = FALSE
  )
  if (!identical(left$message, "OK")) {
    signal_numerical_error(
      "integrate_not_ok",
      paste0("Left primitive integration did not complete normally: ", left$message)
    )
  }
  right <- stats::integrate(
    integrand, lower = 0, upper = upper_y,
    rel.tol = rel_tol, abs.tol = rel_tol,
    subdivisions = 1000L, stop.on.error = FALSE
  )
  if (!identical(right$message, "OK")) {
    signal_numerical_error(
      "integrate_not_ok",
      paste0("Right primitive integration did not complete normally: ", right$message)
    )
  }
  enclosed <- left$value + right$value
  abs_error <- left$abs.error + right$abs.error
  if (!is_finite_scalar(enclosed) || enclosed <= 0 ||
      !is_finite_scalar(abs_error) || abs_error < 0) {
    signal_numerical_error(
      "invalid_primitive",
      "Enclosed primitive or integration error was invalid."
    )
  }
  log_factor <- log(scale) + log(enclosed)
  log_integral <- modal_log_kernel + log_factor
  if (!is_finite_scalar(log_factor) || !is_finite_scalar(log_integral)) {
    signal_numerical_error(
      "invalid_primitive",
      "Primitive log-integral was non-finite."
    )
  }
  list(
    log_integral = log_integral,
    anchor = modal_log_kernel,
    log_factor = log_factor,
    anchored_integral = enclosed,
    integrate_abs_error = abs_error,
    q = abs_error / enclosed,
    integrate_messages = c(left$message, right$message),
    lower_y = lower_y,
    upper_y = upper_y
  )
}

primitive_local <- function(
  log_kernel, score, curvature, domain, rel_tol
) {
  location <- mode_local(score, curvature, domain)
  bounded_left <- identical(domain, "positive")
  bounded_right <- identical(domain, "negative")
  evaluate <- function(expansion) {
    distance <- initial_scales * 2^expansion
    lower_y <- if (bounded_left) -location$mode / location$scale else -distance
    upper_y <- if (bounded_right) -location$mode / location$scale else distance
    integral <- integral_once_local(
      log_kernel, location$mode, location$scale,
      lower_y, upper_y, rel_tol
    )
    log_bounds <- numeric(0)
    if (!bounded_left) {
      lower <- location$mode + location$scale * lower_y
      lower_score <- score(lower)
      if (!is_finite_scalar(lower_score) || lower_score <= 0) {
        signal_numerical_error("invalid_tail_score", "Oracle left-tail score was invalid.")
      }
      log_bounds <- c(log_bounds, log_kernel(lower) - log(lower_score))
    }
    if (!bounded_right) {
      upper <- location$mode + location$scale * upper_y
      upper_score <- score(upper)
      if (!is_finite_scalar(upper_score) || upper_score >= 0) {
        signal_numerical_error("invalid_tail_score", "Oracle right-tail score was invalid.")
      }
      log_bounds <- c(log_bounds, log_kernel(upper) - log(-upper_score))
    }
    if (any(!is.finite(log_bounds))) {
      signal_numerical_error("invalid_tail_bound", "Oracle tail bound was non-finite.")
    }
    log_bound <- if (length(log_bounds) == 1L) {
      log_bounds
    } else {
      log_add_local(log_bounds[[1L]], log_bounds[[2L]])
    }
    relative_bound <- exp(log_bound - integral$log_integral)
    if (!is_finite_scalar(relative_bound) || relative_bound < 0) {
      signal_numerical_error("invalid_tail_bound", "Oracle relative tail bound was invalid.")
    }
    c(
      integral,
      list(
        relative_tail_bound = relative_bound,
        mode = location$mode,
        local_scale = location$scale,
        e_level = as.integer(expansion)
      )
    )
  }

  certified <- NULL
  e_cert <- NA_integer_
  for (expansion in 0:tail_max_expansions) {
    result <- evaluate(expansion)
    if (result$relative_tail_bound <= tail_relative_limit) {
      certified <- result
      e_cert <- as.integer(expansion)
      break
    }
  }
  if (is.null(certified)) {
    signal_numerical_error(
      "tail_not_certified",
      "Oracle tail did not certify within inclusive expansion budget."
    )
  }
  expanded <- evaluate(e_cert + 1L)
  further <- evaluate(e_cert + 2L)
  list(
    e_cert = e_cert,
    levels = list(certified = certified, expanded = expanded,
                  further_expanded = further),
    mode = location$mode,
    local_scale = location$scale
  )
}

make_kernels <- function(a, sigma_alpha) {
  log_denominator <- function(z) {
    log_t <- a + sigma_alpha * z
    t <- exp(pmin(log_t, log(.Machine$double.xmax) - 4))
    stats::dnorm(z, log = TRUE) - t
  }
  log_numerator_a <- function(z) log_denominator(z) + a + sigma_alpha * z
  log_sigma_magnitude <- function(z) log_numerator_a(z) + log(abs(z))
  score_denominator <- function(z) safe_score_local(z, a, sigma_alpha, 0, 0)
  score_numerator_a <- function(z) {
    safe_score_local(z, a, sigma_alpha, sigma_alpha, 0)
  }
  score_sigma_magnitude <- function(z) {
    safe_score_local(z, a, sigma_alpha, sigma_alpha, 1 / z)
  }
  curvature_common <- function(z) {
    log_t <- a + sigma_alpha * z
    curvature <- -1 - sigma_alpha^2 * exp(log_t)
    if (!is_finite_scalar(curvature)) {
      signal_numerical_error("invalid_mode_curvature", "Oracle curvature was non-finite.")
    }
    curvature
  }
  curvature_sigma <- function(z) curvature_common(z) - 1 / z^2
  list(
    denominator = list(
      log_kernel = log_denominator, score = score_denominator,
      curvature = curvature_common, domain = "whole"
    ),
    numerator_a = list(
      log_kernel = log_numerator_a, score = score_numerator_a,
      curvature = curvature_common, domain = "whole"
    ),
    sigma_positive = list(
      log_kernel = log_sigma_magnitude, score = score_sigma_magnitude,
      curvature = curvature_sigma, domain = "positive"
    ),
    sigma_negative = list(
      log_kernel = log_sigma_magnitude, score = score_sigma_magnitude,
      curvature = curvature_sigma, domain = "negative"
    )
  )
}

evaluate_primitives <- function(a, sigma_alpha, rel_tol) {
  kernels <- make_kernels(a, sigma_alpha)
  lapply(kernels, function(kernel) {
    primitive_local(
      kernel$log_kernel, kernel$score, kernel$curvature,
      kernel$domain, rel_tol
    )
  })
}

combine_primitives_local <- function(levels) {
  denominator <- levels[["denominator"]]
  log_ratio <- function(numerator) {
    (numerator$anchor - denominator$anchor) +
      (numerator$log_factor - denominator$log_factor)
  }
  log_denominator <- denominator$log_integral
  positive_log_ratio <- log_ratio(levels[["sigma_positive"]])
  negative_log_ratio <- log_ratio(levels[["sigma_negative"]])
  p_value <- exp(positive_log_ratio)
  n_value <- exp(negative_log_ratio)
  d_sigma <- -signed_difference_local(positive_log_ratio, negative_log_ratio)
  d_a <- -exp(log_ratio(levels[["numerator_a"]]))
  values <- c(log_m0 = log_denominator, derivative_a = d_a,
              derivative_sigma = d_sigma)
  if (any(!is.finite(values)) || !is_finite_scalar(p_value) ||
      !is_finite_scalar(n_value)) {
    signal_numerical_error(
      "nonfinite_reconstruction",
      "Primitive reconstruction produced a non-finite output."
    )
  }
  list(
    values = values, P = p_value, N = n_value,
    positive_log_ratio = positive_log_ratio,
    negative_log_ratio = negative_log_ratio
  )
}

relative_error <- function(level) level$integrate_abs_error / level$anchored_integral

primitive_rows_for <- function(a, sigma_alpha, rel_tol) {
  primitives <- evaluate_primitives(a, sigma_alpha, rel_tol)
  rows <- vector("list", length(primitive_order) * length(coverage_names))
  row_index <- 0L
  for (coverage in coverage_names) {
    for (primitive in primitive_order) {
      row_index <- row_index + 1L
      current <- primitives[[primitive]]$levels[[coverage]]
      e_cert <- primitives[[primitive]]$e_cert
      previous <- if (coverage == "certified") NULL else
        primitives[[primitive]]$levels[[coverage_names[[coverage_offsets[[coverage]]]]]]
      certified <- primitives[[primitive]]$levels[["certified"]]
      row <- list(
        primitive = primitive,
        rel_tol = rel_tol,
        coverage = coverage,
        e_cert = e_cert,
        e_level = current$e_level,
        mode = current$mode,
        local_scale = current$local_scale,
        lower_z = current$mode + current$local_scale * current$lower_y,
        upper_z = current$mode + current$local_scale * current$upper_y,
        log_integral = current$log_integral,
        anchored_integral = current$anchored_integral,
        integrate_abs_error = current$integrate_abs_error,
        q = current$q,
        relative_tail_bound = current$relative_tail_bound,
        delta_log_previous = NA_real_,
        E_log_previous = NA_real_,
        delta_log_certified = NA_real_,
        E_log_certified = NA_real_
      )
      if (!is.null(previous)) {
        row$delta_log_previous <- abs(current$log_integral - previous$log_integral)
        row$E_log_previous <- 4 * (
          relative_error(current) + relative_error(previous) +
            current$relative_tail_bound + previous$relative_tail_bound
        ) + 32 * .Machine$double.eps * (
          1 + max(abs(current$log_integral), abs(previous$log_integral))
        )
      }
      if (coverage != "certified") {
        row$delta_log_certified <- abs(current$log_integral - certified$log_integral)
        row$E_log_certified <- 4 * (
          relative_error(current) + relative_error(certified) +
            current$relative_tail_bound + certified$relative_tail_bound
        ) + 32 * .Machine$double.eps * (
          1 + max(abs(current$log_integral), abs(certified$log_integral))
        )
      }
      rows[[row_index]] <- row
    }
  }
  list(
    primitives = primitives,
    rows = rows,
    integration_ok = all(vapply(
      primitives,
      function(primitive) all(vapply(
        primitive$levels,
        function(level) all(level$integrate_messages == "OK"),
        logical(1)
      )),
      logical(1)
    ))
  )
}

as_primitive_table <- function(row_lists) {
  table <- as.data.frame(do.call(rbind, lapply(row_lists, as.data.frame)),
                         stringsAsFactors = FALSE)
  table <- table[order(
    match(table$rel_tol, rel_tolerances),
    match(table$coverage, coverage_names),
    match(table$primitive, primitive_order)
  ), , drop = FALSE]
  rownames(table) <- NULL
  table
}

envelope_log_value <- function(level) {
  4 * (relative_error(level) + level$relative_tail_bound) +
    32 * .Machine$double.eps * (1 + abs(level$log_integral))
}

make_signed_summary <- function(primitives, rel_tol, coverage) {
  levels <- lapply(primitives, `[[`, "levels")
  levels <- lapply(levels, `[[`, coverage)
  combined <- combine_primitives_local(levels)
  denominator <- levels[["denominator"]]
  q_d <- relative_error(denominator)
  q_a <- relative_error(levels[["numerator_a"]])
  q_p <- relative_error(levels[["sigma_positive"]])
  q_n <- relative_error(levels[["sigma_negative"]])
  r_d <- denominator$relative_tail_bound
  r_a <- levels[["numerator_a"]]$relative_tail_bound
  r_p <- levels[["sigma_positive"]]$relative_tail_bound
  r_n <- levels[["sigma_negative"]]$relative_tail_bound
  d_a <- combined$values[["derivative_a"]]
  d_sigma <- combined$values[["derivative_sigma"]]
  p_value <- combined$P
  n_value <- combined$N
  kappa <- (p_value + n_value) / abs(p_value - n_value)
  list(
    row_type = "signed_summary", rel_tol = rel_tol, coverage = coverage, j = NA_integer_,
    rho = NA_real_,
    log_m0 = combined$values[["log_m0"]], b_D = envelope_log_value(denominator),
    derivative_a = d_a, derivative_sigma = d_sigma, P = p_value, N = n_value,
    kappa_cancel = kappa, lost_decimal_digits = log10(kappa),
    E_int_a = 4 * (q_a + q_d) * abs(d_a),
    E_tail_a = (r_a + r_d) * abs(d_a),
    E_arith_a = 16 * .Machine$double.eps * abs(d_a),
    E_int_sigma = 4 * (q_p * p_value + q_n * n_value + q_d * abs(d_sigma)),
    E_tail_sigma = r_p * p_value + r_n * n_value + r_d * abs(d_sigma),
    E_arith_sigma = 16 * .Machine$double.eps *
      (p_value + n_value + abs(d_sigma)),
    B_a = 4 * (q_a + q_d) * abs(d_a) + (r_a + r_d) * abs(d_a) +
      16 * .Machine$double.eps * abs(d_a),
    B_sigma = 4 * (q_p * p_value + q_n * n_value + q_d * abs(d_sigma)) +
      r_p * p_value + r_n * n_value + r_d * abs(d_sigma) +
      16 * .Machine$double.eps * (p_value + n_value + abs(d_sigma))
  )
}

## Cache denominator-only evaluations by exact input tuple.  The key is only
## an implementation optimisation; each distinct value still uses its own
## mode, certification endpoint, and two prescribed expansions.
denominator_cache <- new.env(parent = emptyenv())
denominator_only <- function(a, sigma_alpha, rel_tol, coverage) {
  key <- paste(formatC(a, digits = 17, format = "fg"),
               formatC(sigma_alpha, digits = 17, format = "fg"),
               formatC(rel_tol, digits = 17, format = "fg"), coverage, sep = "|")
  if (exists(key, envir = denominator_cache, inherits = FALSE)) {
    return(get(key, envir = denominator_cache, inherits = FALSE))
  }
  kernel <- make_kernels(a, sigma_alpha)[["denominator"]]
  primitive <- primitive_local(
    kernel$log_kernel, kernel$score, kernel$curvature,
    kernel$domain, rel_tol
  )
  level <- primitive$levels[[coverage]]
  result <- list(log_m0 = level$log_integral, b_D = envelope_log_value(level))
  assign(key, result, envir = denominator_cache)
  result
}

richardson_sequence <- function(a, sigma_alpha, rel_tol, coverage) {
  steps <- richardson_start / 2^richardson_j
  centred <- vector("list", length(steps))
  for (index in seq_along(steps)) {
    h <- steps[[index]]
    plus <- denominator_only(a, sigma_alpha + h, rel_tol, coverage)
    minus <- denominator_only(a, sigma_alpha - h, rel_tol, coverage)
    centred[[index]] <- list(
      h = h, log_plus = plus$log_m0, log_minus = minus$log_m0,
      b_plus = plus$b_D, b_minus = minus$b_D,
      D = (plus$log_m0 - minus$log_m0) / (2 * h),
      B_D = (plus$b_D + minus$b_D) / (2 * h)
    )
  }
  rows <- vector("list", 8L)
  eligible <- logical(8L)
  for (j in 0:7) {
    coarse <- centred[[j + 1L]]
    fine <- centred[[j + 2L]]
    r_value <- (4 * fine$D - coarse$D) / 3
    b_r <- (4 * fine$B_D + coarse$B_D) / 3
    rho <- if (j == 0L) NA_real_ else abs(r_value - rows[[j]]$R_j)
    eligible[[j + 1L]] <- j >= 1L &&
      rho <= richardson_convergence &&
      rho + b_r + rows[[j]]$B_R_j <= richardson_convergence
    rows[[j + 1L]] <- list(
      row_type = "richardson", rel_tol = rel_tol, coverage = coverage,
      j = j, h_coarse = coarse$h, h_fine = fine$h,
      log_plus_coarse = coarse$log_plus, log_minus_coarse = coarse$log_minus,
      b_plus_coarse = coarse$b_plus, b_minus_coarse = coarse$b_minus,
      log_plus_fine = fine$log_plus, log_minus_fine = fine$log_minus,
      b_plus_fine = fine$b_plus, b_minus_fine = fine$b_minus,
      D_coarse = coarse$D, D_fine = fine$D, B_D_coarse = coarse$B_D,
      B_D_fine = fine$B_D, R_j = r_value, B_R_j = b_r, rho = rho,
      accepted = FALSE
    )
  }
  accepted_index <- which(eligible)[1L]
  if (!is.na(accepted_index)) rows[[accepted_index]]$accepted <- TRUE
  list(rows = rows, centred = centred, accepted_index = accepted_index)
}

derivative_table_for <- function(summaries, sequences) {
  rows <- c(summaries, unlist(lapply(sequences, `[[`, "rows"), recursive = FALSE))
  padded_rows <- lapply(rows, pad_row_to_schema, columns = expected_derivative_columns)
  table <- as.data.frame(do.call(rbind, lapply(padded_rows, as.data.frame)),
                         stringsAsFactors = FALSE)
  row_type_order <- c("signed_summary", "richardson")
  table <- table[order(
    match(table$row_type, row_type_order),
    match(table$rel_tol, rel_tolerances),
    match(table$coverage, coverage_names),
    ifelse(is.na(table$j), -1L, table$j)
  ), , drop = FALSE]
  rownames(table) <- NULL
  table
}

expected_primitive_columns <- c(
  "primitive", "rel_tol", "coverage", "e_cert", "e_level", "mode",
  "local_scale", "lower_z", "upper_z", "log_integral", "anchored_integral",
  "integrate_abs_error", "q", "relative_tail_bound", "delta_log_previous",
  "E_log_previous", "delta_log_certified", "E_log_certified"
)
expected_derivative_columns <- c(
  "row_type", "rel_tol", "coverage", "j", "h_coarse", "h_fine",
  "log_plus_coarse", "log_minus_coarse", "b_plus_coarse", "b_minus_coarse",
  "log_plus_fine", "log_minus_fine", "b_plus_fine", "b_minus_fine",
  "D_coarse", "D_fine", "B_D_coarse", "B_D_fine", "R_j", "B_R_j", "rho",
  "accepted", "log_m0", "b_D", "derivative_a", "B_a", "derivative_sigma",
  "B_sigma", "P", "N", "kappa_cancel", "lost_decimal_digits", "E_int_a",
  "E_tail_a", "E_arith_a", "E_int_sigma", "E_tail_sigma", "E_arith_sigma",
  "accepted_j", "accepted_h_fine", "accepted_R", "accepted_B_R",
  "agreement_abs", "agreement_scaled"
)

pad_row_to_schema <- function(row, columns) {
  missing <- setdiff(columns, names(row))
  for (name in missing) row[[name]] <- NA
  row[columns]
}

as_complete_derivative_table <- function(summaries, sequences) {
  accepted_info <- lapply(sequences, function(sequence) {
    index <- sequence$accepted_index
    if (is.na(index)) return(list(j = NA_integer_, h = NA_real_, R = NA_real_, B = NA_real_, rho = NA_real_))
    row <- sequence$rows[[index]]
    list(j = row$j, h = row$h_fine, R = row$R_j, B = row$B_R_j, rho = row$rho)
  })
  for (index in seq_along(summaries)) {
    accepted <- accepted_info[[index]]
    summary <- summaries[[index]]
    summary$accepted_j <- accepted$j
    summary$accepted_h_fine <- accepted$h
    summary$accepted_R <- accepted$R
    summary$accepted_B_R <- accepted$B
    summary$rho <- accepted$rho
    summary$agreement_abs <- if (is.finite(accepted$R))
      abs(summary$derivative_sigma - accepted$R) else NA_real_
    summary$agreement_scaled <- if (is.finite(accepted$R))
      scale_sigma * (summary$agreement_abs + accepted$rho +
        summary$B_sigma + accepted$B) else NA_real_
    summaries[[index]] <- summary
  }
  table <- derivative_table_for(summaries, sequences)
  missing <- setdiff(expected_derivative_columns, names(table))
  for (name in missing) table[[name]] <- NA
  table <- table[, expected_derivative_columns, drop = FALSE]
  table
}

validate_tables <- function(primitive_table, derivative_table) {
  if (!identical(names(primitive_table), expected_primitive_columns) ||
      nrow(primitive_table) != 24L ||
      !identical(names(derivative_table), expected_derivative_columns) ||
      nrow(derivative_table) != 54L) return(FALSE)
  primitive_tol <- match(primitive_table$rel_tol, rel_tolerances)
  primitive_coverage <- match(primitive_table$coverage, coverage_names)
  primitive_factor <- match(primitive_table$primitive, primitive_order)
  if (anyNA(c(primitive_tol, primitive_coverage, primitive_factor)) ||
      any(primitive_table$e_cert < 0L | primitive_table$e_cert > tail_max_expansions) ||
      any(primitive_table$e_level != primitive_table$e_cert + primitive_coverage - 1L)) return(FALSE)
  expected_primitive_keys <- data.frame(
    rel_tol = rep(seq_along(rel_tolerances), each = length(coverage_names) * length(primitive_order)),
    coverage = rep(rep(seq_along(coverage_names), each = length(primitive_order)), length(rel_tolerances)),
    primitive = rep(seq_along(primitive_order), length(rel_tolerances) * length(coverage_names))
  )
  primitive_keys <- data.frame(
    rel_tol = primitive_tol, coverage = primitive_coverage, primitive = primitive_factor
  )
  primitive_order_index <- order(primitive_tol, primitive_coverage, primitive_factor)
  if (!identical(primitive_order_index, seq_len(nrow(primitive_table))) ||
      !identical(primitive_keys, expected_primitive_keys)) return(FALSE)
  derivative_row_type <- match(derivative_table$row_type, c("signed_summary", "richardson"))
  derivative_tol <- match(derivative_table$rel_tol, rel_tolerances)
  derivative_coverage <- match(derivative_table$coverage, coverage_names)
  if (anyNA(c(derivative_row_type, derivative_tol, derivative_coverage))) return(FALSE)
  signed <- derivative_table[derivative_table$row_type == "signed_summary", , drop = FALSE]
  rich <- derivative_table[derivative_table$row_type == "richardson", , drop = FALSE]
  if (nrow(signed) != 6L || nrow(rich) != 48L ||
      any(!is.na(signed$j)) || any(!is.na(rich$j) & (rich$j < 0L | rich$j > 7L))) return(FALSE)
  expected_signed_keys <- data.frame(
    rel_tol = rep(seq_along(rel_tolerances), each = length(coverage_names)),
    coverage = rep(seq_along(coverage_names), length(rel_tolerances))
  )
  signed_keys <- data.frame(
    rel_tol = match(signed$rel_tol, rel_tolerances),
    coverage = match(signed$coverage, coverage_names)
  )
  signed_order_index <- order(signed_keys$rel_tol, signed_keys$coverage)
  if (!identical(signed_order_index, seq_len(nrow(signed))) ||
      !identical(signed_keys, expected_signed_keys)) return(FALSE)
  rich_keys <- data.frame(
    rel_tol = match(rich$rel_tol, rel_tolerances),
    coverage = match(rich$coverage, coverage_names), j = rich$j
  )
  expected_rich_keys <- data.frame(
    rel_tol = rep(seq_along(rel_tolerances), each = length(coverage_names) * 8L),
    coverage = rep(rep(seq_along(coverage_names), each = 8L), length(rel_tolerances)),
    j = rep(0:7, length(rel_tolerances) * length(coverage_names))
  )
  rich_order_index <- order(rich_keys$rel_tol, rich_keys$coverage, rich_keys$j)
  if (!identical(rich_order_index, seq_len(nrow(rich))) ||
      !identical(rich_keys, expected_rich_keys)) return(FALSE)
  signed_na_columns <- c(
    "h_coarse", "h_fine", "log_plus_coarse", "log_minus_coarse",
    "b_plus_coarse", "b_minus_coarse", "log_plus_fine", "log_minus_fine",
    "b_plus_fine", "b_minus_fine", "D_coarse", "D_fine", "B_D_coarse",
    "B_D_fine", "R_j", "B_R_j", "accepted"
  )
  rich_na_columns <- c(
    "log_m0", "b_D", "derivative_a", "B_a", "derivative_sigma", "B_sigma",
    "P", "N", "kappa_cancel", "lost_decimal_digits", "E_int_a", "E_tail_a",
    "E_arith_a", "E_int_sigma", "E_tail_sigma", "E_arith_sigma", "accepted_j",
    "accepted_h_fine", "accepted_R", "accepted_B_R", "agreement_abs",
    "agreement_scaled"
  )
  if (!all(vapply(signed[, signed_na_columns, drop = FALSE], function(x) all(is.na(x)), logical(1))) ||
      !all(vapply(rich[, rich_na_columns, drop = FALSE], function(x) all(is.na(x)), logical(1)))) return(FALSE)
  rich <- derivative_table[derivative_table$row_type == "richardson", , drop = FALSE]
  accepted_counts <- aggregate(
    accepted ~ rel_tol + coverage, rich, sum
  )
  if (nrow(accepted_counts) != 6L || any(accepted_counts$accepted != 1L)) return(FALSE)
  finite_primitive <- unlist(primitive_table[, c(
    "e_cert", "e_level", "mode", "local_scale", "lower_z", "upper_z",
    "log_integral", "anchored_integral", "integrate_abs_error", "q",
    "relative_tail_bound"
  )])
  if (any(!is.finite(finite_primitive))) return(FALSE)
  if (any(primitive_table$q < 0 | primitive_table$relative_tail_bound < 0) ||
      any(!is.finite(primitive_table$delta_log_previous[!is.na(primitive_table$delta_log_previous)])) ||
      any(!is.finite(primitive_table$E_log_previous[!is.na(primitive_table$E_log_previous)])) ||
      any(!is.finite(primitive_table$delta_log_certified[!is.na(primitive_table$delta_log_certified)])) ||
      any(!is.finite(primitive_table$E_log_certified[!is.na(primitive_table$E_log_certified)]))) return(FALSE)
  certified_rows <- primitive_table$coverage == "certified"
  noncertified_rows <- !certified_rows
  if (any(!is.na(primitive_table$delta_log_previous[certified_rows])) ||
      any(!is.na(primitive_table$E_log_previous[certified_rows])) ||
      any(!is.na(primitive_table$delta_log_certified[certified_rows])) ||
      any(!is.na(primitive_table$E_log_certified[certified_rows])) ||
      any(is.na(primitive_table$delta_log_previous[noncertified_rows])) ||
      any(is.na(primitive_table$E_log_previous[noncertified_rows])) ||
      any(is.na(primitive_table$delta_log_certified[noncertified_rows])) ||
      any(is.na(primitive_table$E_log_certified[noncertified_rows]))) return(FALSE)
  rich_numeric <- c(
    "j", "h_coarse", "h_fine", "log_plus_coarse", "log_minus_coarse",
    "b_plus_coarse", "b_minus_coarse", "log_plus_fine", "log_minus_fine",
    "b_plus_fine", "b_minus_fine", "D_coarse", "D_fine", "B_D_coarse",
    "B_D_fine", "R_j", "B_R_j"
  )
  if (any(!is.finite(unlist(derivative_table[
    derivative_table$row_type == "richardson", rich_numeric
  ])))) return(FALSE)
  if (any(!is.finite(unlist(signed[, c(
    "log_m0", "b_D", "derivative_a", "B_a", "derivative_sigma", "B_sigma",
    "P", "N", "kappa_cancel", "lost_decimal_digits", "accepted_j",
    "accepted_h_fine", "accepted_R", "accepted_B_R", "agreement_abs",
    "agreement_scaled"
  )])))) return(FALSE)
  if (any(!is.finite(signed$b_D)) || any(signed$b_D < 0) ||
      any(!is.finite(signed$B_a)) || any(signed$B_a < 0) ||
      any(!is.finite(signed$B_sigma)) || any(signed$B_sigma < 0) ||
      any(primitive_table$integrate_abs_error < 0) ||
      any(!is.finite(primitive_table$q)) || any(primitive_table$q < 0) ||
      any(!is.finite(primitive_table$relative_tail_bound)) ||
      any(primitive_table$relative_tail_bound < 0)) return(FALSE)
  if (anyNA(rich$accepted) || !is.logical(rich$accepted) ||
      any(!is.na(rich$rho[rich$j == 0L])) || any(is.na(rich$rho[rich$j > 0L])) ||
      any(!is.na(rich$rho) & rich$rho < 0) ||
      any(is.na(signed$rho)) || any(!is.finite(signed$rho)) ||
      any(signed$rho < 0) || any(!is.finite(signed$accepted_R)) ||
      any(!is.finite(signed$accepted_B_R)) ||
      any(!is.finite(signed$agreement_abs)) ||
      any(!is.finite(signed$agreement_scaled))) return(FALSE)
  if (any(!is.finite(unlist(rich[, c(
    "b_plus_coarse", "b_minus_coarse", "b_plus_fine", "b_minus_fine",
    "B_D_coarse", "B_D_fine", "B_R_j"
  )]))) || any(unlist(rich[, c(
    "b_plus_coarse", "b_minus_coarse", "b_plus_fine", "b_minus_fine",
    "B_D_coarse", "B_D_fine", "B_R_j"
  )]) < 0)) return(FALSE)
  TRUE
}

span_with_envelopes <- function(values, envelopes) {
  max_index <- which.max(values)[1L]
  min_index <- which.min(values)[1L]
  max(values) - min(values) + envelopes[[max_index]] + envelopes[[min_index]]
}

evaluate_stable_criteria <- function(primitive_table, derivative_table) {
  signed <- derivative_table[derivative_table$row_type == "signed_summary", , drop = FALSE]
  rich <- derivative_table[derivative_table$row_type == "richardson", , drop = FALSE]
  status <- stats::setNames(rep("PASS", 11L), paste0("S", sprintf("%02d", 1:11),
                                                        c("_finite_tail", "_integrate_ok",
                                                          "_primitive_log_compatible", "_value_resolution",
                                                          "_a_resolution", "_sigma_resolution",
                                                          "_analytic_uncertainty", "_richardson_convergence",
                                                          "_richardson_uncertainty", "_independent_agreement",
                                                          "_richardson_span")))
  finite_ok <- all(is.finite(as.matrix(primitive_table[, c(
    "mode", "local_scale", "lower_z", "upper_z", "log_integral",
    "anchored_integral", "integrate_abs_error", "q", "relative_tail_bound"
  )]))) && all(is.finite(as.matrix(signed[, c(
    "log_m0", "b_D", "derivative_a", "B_a", "derivative_sigma", "B_sigma",
    "P", "N", "kappa_cancel", "lost_decimal_digits"
  )])))
  status[[1L]] <- if (finite_ok &&
                         all(primitive_table$relative_tail_bound <= tail_relative_limit)) "PASS" else "FAIL"
  status[[2L]] <- if (isTRUE(attr(primitive_table, "integration_ok"))) "PASS" else "FAIL"
  transition_ok <- all(primitive_table$delta_log_previous <= primitive_table$E_log_previous |
                         is.na(primitive_table$delta_log_previous)) &&
    all(primitive_table$delta_log_certified <= primitive_table$E_log_certified |
          is.na(primitive_table$delta_log_certified))
  status[[3L]] <- if (transition_ok) "PASS" else "FAIL"
  value_raw <- max(signed$log_m0) - min(signed$log_m0)
  value_span <- span_with_envelopes(signed$log_m0, signed$b_D)
  status[[4L]] <- if (all(signed$b_D <= 1e-8) && value_span <= 1e-8 &&
                         unseen_frozen * value_span <= value_scaled_limit) "PASS" else "FAIL"
  a_limit <- reference_agreement + reference_relative_slope * max(abs(signed$derivative_a))
  a_raw <- max(signed$derivative_a) - min(signed$derivative_a)
  a_span <- span_with_envelopes(signed$derivative_a, signed$B_a)
  status[[5L]] <- if (a_raw <= a_limit && a_span <= a_limit &&
                         scale_a * a_span <= decision_scaled_limit) "PASS" else "FAIL"
  sigma_limit <- reference_agreement + reference_relative_slope * max(abs(signed$derivative_sigma))
  sigma_raw <- max(signed$derivative_sigma) - min(signed$derivative_sigma)
  sigma_span <- span_with_envelopes(signed$derivative_sigma, signed$B_sigma)
  status[[6L]] <- if (sigma_raw <= sigma_limit && sigma_span <= sigma_limit &&
                         scale_sigma * sigma_span <= decision_scaled_limit) "PASS" else "FAIL"
  status[[7L]] <- if (all(scale_a * signed$B_a <= decision_scaled_limit) &&
                         all(scale_sigma * signed$B_sigma <= decision_scaled_limit)) "PASS" else "FAIL"
  accepted <- rich[rich$accepted, , drop = FALSE]
  status[[8L]] <- if (nrow(accepted) == 6L) "PASS" else "FAIL"
  status[[9L]] <- if (nrow(accepted) == 6L &&
                         all(scale_sigma * accepted$B_R_j <= decision_scaled_limit)) "PASS" else "FAIL"
  agreement_ok <- nrow(accepted) == 6L && all(
    signed$agreement_abs <= derivative_sanity_limit &
      signed$agreement_scaled <= decision_scaled_limit
  )
  status[[10L]] <- if (agreement_ok) "PASS" else "FAIL"
  accepted_r <- signed$accepted_R
  accepted_b <- signed$accepted_B_R
  status[[11L]] <- if (all(is.finite(accepted_r)) &&
                          span_with_envelopes(accepted_r, accepted_b) * scale_sigma <= decision_scaled_limit) "PASS" else "FAIL"
  list(status = status, raw = list(
    value_raw = value_raw, a_raw = a_raw, sigma_raw = sigma_raw,
    agreement_abs = signed$agreement_abs,
    agreement_scaled_raw = scale_sigma * (signed$agreement_abs + signed$rho),
    richardson_span_raw = if (all(is.finite(accepted_r))) max(accepted_r) - min(accepted_r) else Inf
  ))
}

run_external <- function(command, args) {
  stdout_path <- tempfile("goal002r-adjudication-stdout-")
  stderr_path <- tempfile("goal002r-adjudication-stderr-")
  on.exit(unlink(c(stdout_path, stderr_path)), add = TRUE)
  status <- system2(command, args, stdout = stdout_path, stderr = stderr_path)
  if (is.null(status)) status <- 0L
  output <- c(
    if (file.exists(stdout_path)) readLines(stdout_path, warn = FALSE) else character(),
    if (file.exists(stderr_path)) readLines(stderr_path, warn = FALSE) else character()
  )
  list(status = as.integer(status), output = output)
}

sha256_file <- function(path) {
  result <- run_external("sha256sum", path)
  if (result$status != 0L || length(result$output) != 1L) {
    stop(paste(result$output, collapse = "\n"), call. = FALSE)
  }
  fields <- strsplit(result$output[[1L]], "[[:space:]]+")[[1L]]
  if (length(fields) < 2L || !grepl("^[0-9a-f]{64}$", fields[[1L]])) {
    stop("sha256sum returned an invalid digest.", call. = FALSE)
  }
  fields[[1L]]
}

source_paths <- c(
  runner = script_path,
  config = file.path(project_root, "R", "goal002r", "config.R"),
  math = file.path(project_root, "R", "goal002r", "math.R"),
  preflight_math = file.path(project_root, "R", "goal002r", "preflight_math.R")
)
source_paths_rel <- c(
  runner = "scripts/run_goal002r_oracle_stability_adjudication.R",
  config = "R/goal002r/config.R",
  math = "R/goal002r/math.R",
  preflight_math = "R/goal002r/preflight_math.R"
)

check_sources_clean <- function() {
  tracked_result <- run_external(
    "git", c("-C", project_root, "ls-files", "--error-unmatch", unname(source_paths_rel))
  )
  tracked <- tracked_result$output[grepl("^[^:]+$", tracked_result$output)]
  if (tracked_result$status != 0L ||
      !identical(sort(tracked), sort(unname(source_paths_rel)))) {
    stop("X02 failed: adjudication files are not exactly tracked.", call. = FALSE)
  }
  for (path in unname(source_paths_rel)) {
    head_result <- run_external(
      "git", c("-C", project_root, "cat-file", "-e", paste0("HEAD:", path))
    )
    if (head_result$status != 0L) {
      stop("X02 failed: adjudication file is absent from HEAD.", call. = FALSE)
    }
  }
  dirty_worktree <- run_external(
    "git", c("-C", project_root, "diff", "--quiet", "--", unname(source_paths_rel))
  )
  dirty_index <- run_external(
    "git", c("-C", project_root, "diff", "--cached", "--quiet", "--", unname(source_paths_rel))
  )
  if (dirty_worktree$status != 0L || dirty_index$status != 0L) {
    stop("X02 failed: adjudication sources are dirty or Git reported an error.", call. = FALSE)
  }
}

final_dir <- file.path(project_root, "outputs", "goal002r", "oracle-stability-adjudication-v2")
staging_dir <- file.path(project_root, "outputs", "goal002r", ".oracle-stability-adjudication-v2.staging")

write_decision <- function(path, outcome, first_decisive, x_status, s_status,
                           b_status = "NOT_REACHED", c_status = "NOT_REACHED",
                           provenance = NULL, csv_hashes = NULL) {
  lines <- c(
    paste0("adjudication_version=", adjudication_version),
    paste0("timestamp_utc=", format(Sys.time(), tz = "UTC", usetz = TRUE)),
    paste0("outcome=", outcome),
    paste0("disposition=", if (outcome %in% c("B", "C")) "CLOSE" else "PLAN_ONLY"),
    paste0("first_decisive_identifier=", first_decisive),
    paste0("a=", format(a_frozen, digits = 17)),
    paste0("sigma_alpha=", format(sigma_frozen, digits = 17)),
    paste0("U=", unseen_frozen),
    paste0("rel_tolerances=", paste(format(rel_tolerances, digits = 17), collapse = ",")),
    paste0("initial_scales=", initial_scales),
    paste0("tail_relative_limit=", tail_relative_limit),
    paste0("tail_max_expansions=", tail_max_expansions),
    paste0("coverage_names=", paste(coverage_names, collapse = ",")),
    paste0("richardson_start=", richardson_start),
    paste0("richardson_j=", paste(richardson_j, collapse = ":")),
    paste0("richardson_convergence=", richardson_convergence),
    paste0("reference_agreement=", reference_agreement),
    paste0("reference_relative_slope=", reference_relative_slope),
    paste0("derivative_sanity_limit=", derivative_sanity_limit),
    paste0("decision_scaled_limit=", decision_scaled_limit),
    paste0("value_scaled_limit=", value_scaled_limit),
    paste0("gradient_scale_a=", gradient_scales[["a"]]),
    paste0("gradient_scale_sigma=", gradient_scales[["sigma"]]),
    paste0("gradient_scale_log_sigma=", gradient_scales[["log_sigma"]]),
    paste0("scale_a=", scale_a),
    paste0("scale_sigma=", scale_sigma),
    paste0("historical_stop_order=", 256L),
    paste0("historical_stop_search=target_error"),
    paste0("historical_stop_derivative_sigma_change=", 1.0477378964424133e-09),
    paste0("historical_stop_absolute_limit=", 1e-9),
    paste0("historical_stop_log_m0_change=0"),
    paste0("historical_stop_derivative_a_change=0"),
    paste0("historical_stop_primitive_log_changes=0,0,0,0"),
    paste0("historical_stop_evidence_exists=FALSE"),
    paste0("historical_stop_order_decision_exists=FALSE")
  )
  for (name in names(x_status)) lines <- c(lines, paste0(name, "=", x_status[[name]]))
  for (name in names(s_status)) lines <- c(lines, paste0(name, "=", s_status[[name]]))
  lines <- c(lines, paste0("B00_numerical_certification=", b_status),
             paste0("C00_implementation_failure=", c_status))
  if (!is.null(provenance)) {
    lines <- c(lines,
      paste0("R.version.string=", provenance$r_version),
      paste0("R.version.platform=", provenance$r_platform),
      paste0("double.eps=", provenance$double_eps),
      paste0("git_head=", provenance$git_head))
    for (name in names(provenance$hashes)) lines <- c(lines, paste0("sha256_", name, "=", provenance$hashes[[name]]))
  }
  if (!is.null(csv_hashes)) for (name in names(csv_hashes)) lines <- c(lines, paste0("sha256_", name, "=", csv_hashes[[name]]))
  writeLines(lines, path, useBytes = TRUE)
}

publish_decision_only <- function(outcome, first_decisive, x_status, s_status,
                                  b_status, c_status, provenance) {
  dir.create(staging_dir, recursive = TRUE, showWarnings = FALSE)
  decision_tmp <- file.path(staging_dir, "decision.txt.tmp")
  write_decision(decision_tmp, outcome, first_decisive, x_status, s_status,
                 b_status, c_status, provenance)
  if (!file.rename(decision_tmp, file.path(staging_dir, "decision.txt"))) {
    stop("X05 failed: decision publication failed.", call. = FALSE)
  }
  if (!file.rename(staging_dir, final_dir)) stop("X05 failed: final publication failed.", call. = FALSE)
}

publish_complete <- function(primitive_table, derivative_table, outcome,
                             first_decisive, x_status, s_status,
                             b_status, c_status, provenance) {
  dir.create(staging_dir, recursive = TRUE, showWarnings = FALSE)
  primitive_tmp <- file.path(staging_dir, "primitive-stability.csv.tmp")
  derivative_tmp <- file.path(staging_dir, "derivative-stability.csv.tmp")
  utils::write.csv(primitive_table, primitive_tmp, row.names = FALSE, na = "NA")
  utils::write.csv(derivative_table, derivative_tmp, row.names = FALSE, na = "NA")
  primitive_check <- utils::read.csv(primitive_tmp, check.names = FALSE, stringsAsFactors = FALSE)
  derivative_check <- utils::read.csv(derivative_tmp, check.names = FALSE, stringsAsFactors = FALSE)
  if (!validate_tables(primitive_check, derivative_check)) {
    stop("X05 failed: written evidence did not pass read-back validation.", call. = FALSE)
  }
  primitive_hash <- sha256_file(primitive_tmp)
  derivative_hash <- sha256_file(derivative_tmp)
  if (!file.rename(primitive_tmp, file.path(staging_dir, "primitive-stability.csv")) ||
      !file.rename(derivative_tmp, file.path(staging_dir, "derivative-stability.csv"))) {
    stop("X05 failed: evidence publication failed.", call. = FALSE)
  }
  decision_tmp <- file.path(staging_dir, "decision.txt.tmp")
  write_decision(
    decision_tmp, outcome, first_decisive, x_status, s_status,
    b_status, c_status, provenance,
    c(primitive_stability_csv = primitive_hash,
      derivative_stability_csv = derivative_hash)
  )
  if (!file.rename(decision_tmp, file.path(staging_dir, "decision.txt"))) {
    stop("X05 failed: decision publication failed.", call. = FALSE)
  }
  if (!file.rename(staging_dir, final_dir)) stop("X05 failed: final publication failed.", call. = FALSE)
}

## Execution-integrity checks precede the first numerical evaluation.
x_status <- stats::setNames(rep("PASS", 5L), paste0("X0", 1:5))
if (file.exists(final_dir) || file.exists(staging_dir)) {
  x_status[["X01"]] <- "FAIL"
  stop("X01 failed: final or staging output already exists; no attempt made.", call. = FALSE)
}
check_sources_clean()
git_head_result <- run_external("git", c("-C", project_root, "rev-parse", "HEAD"))
git_head <- git_head_result$output[grepl("^[0-9a-f]{40}$", git_head_result$output)]
if (git_head_result$status != 0L || length(git_head) != 1L) {
  stop("X03 failed: Git HEAD unavailable or malformed.", call. = FALSE)
}
provenance <- list(
  r_version = R.version.string,
  r_platform = R.version$platform,
  double_eps = .Machine$double.eps,
  git_head = git_head[[1L]],
  hashes = vapply(source_paths, sha256_file, character(1))
)
x_status[["X03"]] <- "PASS"

## Source the three inert Goal002R modules only after X01--X03 have passed.
source(file.path(project_root, "R", "goal002r", "config.R"), local = .GlobalEnv)
source(file.path(project_root, "R", "goal002r", "math.R"), local = .GlobalEnv)
source(file.path(project_root, "R", "goal002r", "preflight_math.R"), local = .GlobalEnv)

run_attempt <- function() {
  primitive_lists <- list()
  integration_ok <- logical()
  signed_lists <- list()
  sequences <- list()
  sequence_keys <- character()
  for (rel_tol in rel_tolerances) {
    primitive_result <- primitive_rows_for(a_frozen, sigma_frozen, rel_tol)
    primitive_lists <- c(primitive_lists, primitive_result$rows)
    integration_ok <- c(integration_ok, primitive_result$integration_ok)
    for (coverage in coverage_names) {
      key <- paste(rel_tol, coverage, sep = "|")
      signed_lists[[key]] <- make_signed_summary(
        primitive_result$primitives, rel_tol, coverage
      )
      sequence <- richardson_sequence(a_frozen, sigma_frozen, rel_tol, coverage)
      sequences[[key]] <- sequence
      sequence_keys <- c(sequence_keys, key)
    }
  }
  primitive_table <- as_primitive_table(primitive_lists)
  attr(primitive_table, "integration_ok") <- all(integration_ok)
  signed <- signed_lists[sequence_keys]
  derivative_table <- as_complete_derivative_table(signed, sequences[sequence_keys])
  x_status[["X04"]] <<- if (validate_tables(primitive_table, derivative_table)) "PASS" else "FAIL"
  if (x_status[["X04"]] != "PASS") {
    return(list(kind = "X04", primitive = primitive_table, derivative = derivative_table,
                criteria = NULL, first = "X04_in_memory_schema"))
  }
  criteria <- evaluate_stable_criteria(primitive_table, derivative_table)
  raw <- criteria$raw
  raw_failure <- NULL
  if (criteria$status[["S03_primitive_log_compatible"]] == "FAIL") raw_failure <- "S03_primitive_log_compatible"
  if (is.null(raw_failure) && criteria$status[["S04_value_resolution"]] == "FAIL" &&
      (raw$value_raw > 1e-8 || unseen_frozen * raw$value_raw > value_scaled_limit)) raw_failure <- "S04_value_resolution"
  if (is.null(raw_failure) && criteria$status[["S05_a_resolution"]] == "FAIL") {
    a_limit <- reference_agreement + reference_relative_slope * max(abs(derivative_table$derivative_a[derivative_table$row_type == "signed_summary"]))
    if (raw$a_raw > a_limit || scale_a * raw$a_raw > decision_scaled_limit) raw_failure <- "S05_a_resolution"
  }
  if (is.null(raw_failure) && criteria$status[["S06_sigma_resolution"]] == "FAIL") {
    sigma_limit <- reference_agreement + reference_relative_slope * max(abs(derivative_table$derivative_sigma[derivative_table$row_type == "signed_summary"]))
    if (raw$sigma_raw > sigma_limit || scale_sigma * raw$sigma_raw > decision_scaled_limit) raw_failure <- "S06_sigma_resolution"
  }
  if (is.null(raw_failure) && criteria$status[["S10_independent_agreement"]] == "FAIL" &&
      (any(raw$agreement_abs > derivative_sanity_limit, na.rm = TRUE) ||
       any(raw$agreement_scaled_raw > decision_scaled_limit, na.rm = TRUE))) raw_failure <- "S10_independent_agreement"
  if (is.null(raw_failure) && criteria$status[["S11_richardson_span"]] == "FAIL" &&
      scale_sigma * raw$richardson_span_raw > decision_scaled_limit) raw_failure <- "S11_richardson_span"
  if (!is.null(raw_failure)) {
    return(list(kind = "B", primitive = primitive_table, derivative = derivative_table,
                criteria = criteria, first = raw_failure))
  }
  failed <- names(criteria$status)[criteria$status == "FAIL"]
  if (length(failed) > 0L) {
    return(list(kind = "C", primitive = primitive_table, derivative = derivative_table,
                criteria = criteria, first = failed[[1L]]))
  }
  list(kind = "A", primitive = primitive_table, derivative = derivative_table,
       criteria = criteria, first = NA_character_)
}

## A typed numerical condition is B; all other errors are C.  This is the
## only broad top-level catch: predicate-level numerical checks above remain
## explicitly typed, while ordinary coding/I/O errors cannot be relabelled.
attempt <- tryCatch(
  run_attempt(),
  goal002r_adjudication_numerical_error = function(error) {
    list(kind = "B00", primitive = NULL, derivative = NULL, criteria = NULL,
         first = "B00_numerical_certification", error = error)
  },
  error = function(error) {
    list(kind = "C00", primitive = NULL, derivative = NULL, criteria = NULL,
         first = "C00_implementation_failure", error = error)
  }
)

if (attempt$kind %in% c("B00", "C00", "X04")) {
  if (attempt$kind == "X04") {
    publish_decision_only(
      "C", attempt$first, x_status,
      stats::setNames(rep("NOT_REACHED", 11L), paste0("S", sprintf("%02d", 1:11))),
      "NOT_REACHED", "FAIL", provenance
    )
  } else if (attempt$kind == "B00") {
    x_status[["X04"]] <- "NOT_REACHED"
    publish_decision_only("B", attempt$first, x_status,
                          stats::setNames(rep("NOT_REACHED", 11L), paste0("S", sprintf("%02d", 1:11))),
                          "FAIL", "NOT_REACHED", provenance)
  } else {
    x_status[["X04"]] <- "NOT_REACHED"
    publish_decision_only("C", attempt$first, x_status,
                          stats::setNames(rep("NOT_REACHED", 11L), paste0("S", sprintf("%02d", 1:11))),
                          "NOT_REACHED", "FAIL", provenance)
  }
} else {
  x_status[["X04"]] <- "PASS"
  stable <- attempt$criteria$status
  outcome <- attempt$kind
  first <- if (outcome == "A") "NONE" else attempt$first
  b_status <- if (outcome == "B") "FAIL" else "NOT_REACHED"
  c_status <- if (outcome == "C") "FAIL" else "NOT_REACHED"
  publish_complete(
    attempt$primitive, attempt$derivative, outcome, first,
    x_status, stable, b_status, c_status, provenance
  )
}
