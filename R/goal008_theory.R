# Goal008 cheap theoretical diagnostics.

.goal008_stop <- function(message) {
  stop(message, call. = FALSE)
}

.goal008_scalar <- function(x, name, lower = -Inf, strict_lower = FALSE) {
  valid <- is.numeric(x) && length(x) == 1L && !is.na(x) && is.finite(x)
  if (valid) {
    valid <- if (strict_lower) x > lower else x >= lower
  }
  if (!valid) {
    .goal008_stop(paste0(name, " is invalid."))
  }
  as.numeric(x)
}

#' Normal-normal information check for repeated versus fresh species
#'
#' The generating mean is estimated from calibration and target measurements.
#' Repeated measurements share a latent species deviation; fresh-species
#' measurements do not. The function reports exact Gaussian interval coverage
#' and a seeded Monte Carlo check of those formulae.
goal008_gaussian_dependence <- function(
  n_species = 6L,
  tau = 1,
  sigma_calibration = 0.5,
  sigma_target = 0.5,
  level = 0.9,
  n_simulation = 100000L,
  seed = 812008L
) {
  n_species <- as.integer(.goal008_scalar(
    n_species, "n_species", lower = 2
  ))
  tau <- .goal008_scalar(tau, "tau", lower = 0, strict_lower = TRUE)
  sigma_calibration <- .goal008_scalar(
    sigma_calibration, "sigma_calibration", lower = 0,
    strict_lower = TRUE
  )
  sigma_target <- .goal008_scalar(
    sigma_target, "sigma_target", lower = 0, strict_lower = TRUE
  )
  level <- .goal008_scalar(level, "level", lower = 0, strict_lower = TRUE)
  if (level >= 1) {
    .goal008_stop("level must be less than one.")
  }
  n_simulation <- as.integer(.goal008_scalar(
    n_simulation, "n_simulation", lower = 1000
  ))
  seed <- as.integer(.goal008_scalar(seed, "seed", lower = 1))

  variance_calibration <- tau^2 + sigma_calibration^2
  variance_target <- tau^2 + sigma_target^2
  covariance_repeated <- tau^2
  repeated_covariance <- matrix(
    c(
      variance_calibration, covariance_repeated,
      covariance_repeated, variance_target
    ),
    nrow = 2L
  )
  unit <- rep(1, 2L)
  repeated_precision <- as.numeric(
    t(unit) %*% solve(repeated_covariance, unit)
  )
  repeated_variance <- 1 / (n_species * repeated_precision)
  repeated_weights <- as.numeric(
    solve(repeated_covariance, unit) / repeated_precision
  )

  fresh_precision <- 1 / variance_calibration + 1 / variance_target
  reported_fresh_variance <- 1 / (n_species * fresh_precision)
  fresh_weights <- c(
    1 / variance_calibration,
    1 / variance_target
  ) / fresh_precision
  true_repeated_variance_under_fresh_weights <- as.numeric(
    t(fresh_weights) %*% repeated_covariance %*% fresh_weights /
      n_species
  )
  z_value <- stats::qnorm((1 + level) / 2)
  coverage_repeated_as_fresh <- 2 * stats::pnorm(
    z_value * sqrt(
      reported_fresh_variance /
        true_repeated_variance_under_fresh_weights
    )
  ) - 1

  old_rng_kind <- RNGkind()
  old_seed_exists <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (old_seed_exists) {
    old_seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  }
  on.exit({
    do.call(RNGkind, as.list(old_rng_kind))
    if (old_seed_exists) {
      assign(".Random.seed", old_seed, envir = .GlobalEnv)
    } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".Random.seed", envir = .GlobalEnv)
    }
  }, add = TRUE)
  RNGkind(
    kind = "Mersenne-Twister",
    normal.kind = "Inversion",
    sample.kind = "Rejection"
  )
  set.seed(seed)

  repeated_correct_hits <- logical(n_simulation)
  repeated_fresh_hits <- logical(n_simulation)
  fresh_fresh_hits <- logical(n_simulation)
  chunk_size <- 5000L
  starts <- seq.int(1L, n_simulation, by = chunk_size)
  for (start in starts) {
    count <- min(chunk_size, n_simulation - start + 1L)
    alpha <- matrix(
      stats::rnorm(count * n_species, sd = tau),
      nrow = count
    )
    calibration <- alpha + matrix(
      stats::rnorm(count * n_species, sd = sigma_calibration),
      nrow = count
    )
    target <- alpha + matrix(
      stats::rnorm(count * n_species, sd = sigma_target),
      nrow = count
    )
    calibration_mean <- rowMeans(calibration)
    target_mean <- rowMeans(target)
    repeated_estimate <-
      repeated_weights[[1L]] * calibration_mean +
      repeated_weights[[2L]] * target_mean
    fresh_estimate <-
      fresh_weights[[1L]] * calibration_mean +
      fresh_weights[[2L]] * target_mean
    rows <- start:(start + count - 1L)
    repeated_correct_hits[rows] <- abs(repeated_estimate) <=
      z_value * sqrt(repeated_variance)
    repeated_fresh_hits[rows] <- abs(fresh_estimate) <=
      z_value * sqrt(reported_fresh_variance)

    fresh_target <- matrix(
      stats::rnorm(count * n_species, sd = tau),
      nrow = count
    ) + matrix(
      stats::rnorm(count * n_species, sd = sigma_target),
      nrow = count
    )
    genuinely_fresh_estimate <-
      fresh_weights[[1L]] * calibration_mean +
      fresh_weights[[2L]] * rowMeans(fresh_target)
    fresh_fresh_hits[rows] <- abs(genuinely_fresh_estimate) <=
      z_value * sqrt(reported_fresh_variance)
  }

  exact <- c(level, coverage_repeated_as_fresh, level)
  empirical <- c(
    mean(repeated_correct_hits),
    mean(repeated_fresh_hits),
    mean(fresh_fresh_hits)
  )
  coverage <- data.frame(
    scenario = c(
      "same_species_correct_covariance",
      "same_species_treated_as_fresh",
      "fresh_species_correct_independence"
    ),
    exact_coverage = exact,
    simulated_coverage = empirical,
    monte_carlo_se = sqrt(empirical * (1 - empirical) / n_simulation),
    reported_se = c(
      sqrt(repeated_variance),
      sqrt(reported_fresh_variance),
      sqrt(reported_fresh_variance)
    ),
    true_sampling_se = c(
      sqrt(repeated_variance),
      sqrt(true_repeated_variance_under_fresh_weights),
      sqrt(reported_fresh_variance)
    ),
    information_per_species = c(
      repeated_precision,
      fresh_precision,
      fresh_precision
    ),
    stringsAsFactors = FALSE
  )

  posterior_variance_alpha <- 1 / (
    1 / tau^2 + 1 / sigma_calibration^2 + 1 / sigma_target^2
  )
  finite_set <- data.frame(
    quantity = c(
      "sampling_sd_realised_mean_around_generating_mean",
      "posterior_sd_realised_mean_given_paired_data_and_known_mu",
      "sampling_sd_single_species_around_generating_mean"
    ),
    value = c(
      tau / sqrt(n_species),
      sqrt(posterior_variance_alpha / n_species),
      tau
    ),
    stringsAsFactors = FALSE
  )

  list(
    coverage = coverage,
    finite_set = finite_set,
    parameters = data.frame(
      n_species = n_species,
      tau = tau,
      sigma_calibration = sigma_calibration,
      sigma_target = sigma_target,
      generating_mean = 0,
      location_prior = "flat",
      interval_level = level,
      n_simulation = n_simulation,
      seed = seed,
      rng_kind = "Mersenne-Twister",
      normal_kind = "Inversion",
      sample_kind = "Rejection",
      stringsAsFactors = FALSE
    )
  )
}

.goal008_elementary_symmetric <- function(weights) {
  result <- c(1, rep(0, length(weights)))
  completed <- 0L
  for (weight in weights) {
    completed <- completed + 1L
    indices <- seq.int(completed + 1L, 2L, by = -1L)
    result[indices] <- result[indices] + weight * result[indices - 1L]
  }
  result
}

.goal008_validate_pool <- function(detected, detection_probability, a, b) {
  valid <- is.numeric(detected) && is.numeric(detection_probability) &&
    length(detected) == length(detection_probability) &&
    length(detected) > 0L && !anyNA(detected) &&
    all(detected %in% c(0, 1)) && !anyNA(detection_probability) &&
    all(is.finite(detection_probability)) &&
    all(detection_probability >= 0 & detection_probability <= 1) &&
    !any(detected == 1 & detection_probability == 0)
  if (!valid) {
    .goal008_stop(
      paste0(
        "detected and detection_probability must define a fixed candidate ",
        "pool; an observed detection cannot have zero probability."
      )
    )
  }
  a <- .goal008_scalar(a, "a", lower = 0, strict_lower = TRUE)
  b <- .goal008_scalar(b, "b", lower = 0, strict_lower = TRUE)
  list(
    detected = as.integer(detected),
    detection_probability = as.numeric(detection_probability),
    a = a,
    b = b
  )
}

#' Exact finite-pool richness posterior with shared omega integrated out
#'
#' Candidate membership is Bernoulli(omega), omega has a Beta(a,b) prior,
#' and a member is detected with its fixed candidate probability q_i. The
#' elementary-symmetric-polynomial calculation integrates omega exactly.
goal008_finite_pool_pmf <- function(
  detected,
  detection_probability,
  a = 1,
  b = 1
) {
  input <- .goal008_validate_pool(
    detected, detection_probability, a, b
  )
  detected <- input$detected
  q <- input$detection_probability
  a <- input$a
  b <- input$b
  candidate_count <- length(detected)
  detected_count <- sum(detected)
  missed_weights <- 1 - q[detected == 0L]
  unseen_count <- length(missed_weights)
  symmetric <- .goal008_elementary_symmetric(missed_weights)
  additional <- 0:unseen_count
  log_weight <- log(symmetric) + lbeta(
    a + detected_count + additional,
    b + unseen_count - additional
  )
  finite <- is.finite(log_weight)
  probability <- numeric(length(log_weight))
  probability[finite] <- exp(
    log_weight[finite] - max(log_weight[finite])
  )
  probability <- probability / sum(probability)
  data.frame(
    richness = detected_count + additional,
    probability = probability,
    stringsAsFactors = FALSE
  )
}

#' Independent small-pool enumeration for the finite-pool PMF
goal008_finite_pool_pmf_bruteforce <- function(
  detected,
  detection_probability,
  a = 1,
  b = 1,
  maximum_unseen = 20L
) {
  input <- .goal008_validate_pool(
    detected, detection_probability, a, b
  )
  unseen <- which(input$detected == 0L)
  if (length(unseen) > maximum_unseen) {
    .goal008_stop("Brute-force enumeration is restricted to small pools.")
  }
  detected_count <- sum(input$detected)
  if (length(unseen) == 0L) {
    return(data.frame(
      richness = detected_count,
      probability = 1,
      stringsAsFactors = FALSE
    ))
  }
  states <- 0:(2^length(unseen) - 1)
  membership <- vapply(
    seq_along(unseen) - 1L,
    function(bit) bitwAnd(states, bitwShiftL(1L, bit)) > 0L,
    logical(length(states))
  )
  if (length(unseen) == 1L) {
    membership <- matrix(membership, ncol = 1L)
  }
  additional <- rowSums(membership)
  missed_weight <- 1 - input$detection_probability[unseen]
  log_detection <- vapply(
    seq_len(nrow(membership)),
    function(row) {
      selected <- membership[row, ]
      if (!any(selected)) 0 else sum(log(missed_weight[selected]))
    },
    numeric(1)
  )
  log_weight <- log_detection + lbeta(
    input$a + detected_count + additional,
    input$b + length(unseen) - additional
  )
  probability <- exp(log_weight - max(log_weight))
  probability <- probability / sum(probability)
  pooled <- rowsum(
    probability,
    group = detected_count + additional,
    reorder = TRUE
  )
  data.frame(
    richness = as.integer(rownames(pooled)),
    probability = as.numeric(pooled),
    row.names = NULL
  )
}

#' Summaries of the exact shared-omega finite-pool posterior
goal008_finite_pool_summary <- function(pmf, a = 1, b = 1) {
  valid <- is.data.frame(pmf) && identical(
    names(pmf), c("richness", "probability")
  ) && all(pmf$probability >= 0) &&
    abs(sum(pmf$probability) - 1) <= 1e-12
  if (!valid) {
    .goal008_stop("pmf is invalid.")
  }
  a <- .goal008_scalar(a, "a", lower = 0, strict_lower = TRUE)
  b <- .goal008_scalar(b, "b", lower = 0, strict_lower = TRUE)
  candidate_count <- max(pmf$richness)
  total <- a + b + candidate_count
  omega_mean_by_richness <- (a + pmf$richness) / total
  omega_second_by_richness <-
    (a + pmf$richness) * (a + pmf$richness + 1) /
    (total * (total + 1))
  cdf <- cumsum(pmf$probability)
  quantile <- function(probability) {
    pmf$richness[which(cdf >= probability)[[1L]]]
  }
  data.frame(
    expected_richness = sum(pmf$richness * pmf$probability),
    richness_sd = sqrt(
      sum((pmf$richness^2) * pmf$probability) -
        sum(pmf$richness * pmf$probability)^2
    ),
    richness_lower_90 = quantile(0.05),
    richness_median = quantile(0.5),
    richness_upper_90 = quantile(0.95),
    posterior_mean_omega = sum(
      omega_mean_by_richness * pmf$probability
    ),
    posterior_sd_omega = sqrt(
      sum(omega_second_by_richness * pmf$probability) -
        sum(omega_mean_by_richness * pmf$probability)^2
    )
  )
}

#' Missed-detection examples with equal mean log rate
goal008_missed_probability_examples <- function(
  mean_log_rate = log(0.02),
  log_rate_contrast = 1.5,
  effort = c(10, 25, 50, 100)
) {
  mean_log_rate <- .goal008_scalar(mean_log_rate, "mean_log_rate")
  log_rate_contrast <- .goal008_scalar(
    log_rate_contrast, "log_rate_contrast", lower = 0,
    strict_lower = TRUE
  )
  if (!is.numeric(effort) || anyNA(effort) ||
      any(!is.finite(effort)) || any(effort <= 0)) {
    .goal008_stop("effort must contain positive finite values.")
  }
  fixed <- exp(-effort * exp(mean_log_rate))
  mixture <- 0.5 * exp(
    -effort * exp(mean_log_rate - log_rate_contrast)
  ) + 0.5 * exp(
    -effort * exp(mean_log_rate + log_rate_contrast)
  )
  data.frame(
    effort = rep(as.numeric(effort), each = 2L),
    distribution = rep(
      c("point_mass", "symmetric_two_point"),
      times = length(effort)
    ),
    mean_log_rate = mean_log_rate,
    log_rate_sd = rep(c(0, log_rate_contrast), times = length(effort)),
    missed_probability = as.vector(rbind(fixed, mixture)),
    stringsAsFactors = FALSE
  )
}

#' Fixed-total-effort seasonal availability counterexample
goal008_seasonal_allocation_examples <- function(
  encounter_rate = 0.02,
  total_effort = 60
) {
  encounter_rate <- .goal008_scalar(
    encounter_rate, "encounter_rate", lower = 0, strict_lower = TRUE
  )
  total_effort <- .goal008_scalar(
    total_effort, "total_effort", lower = 0, strict_lower = TRUE
  )
  schedules <- data.frame(
    schedule = c("balanced", "season_A_concentrated", "season_B_concentrated"),
    effort_A = c(total_effort / 2, total_effort, 0),
    effort_B = c(total_effort / 2, 0, total_effort),
    stringsAsFactors = FALSE
  )
  availability <- data.frame(
    availability = c("year_round", "season_A_only", "season_B_only"),
    available_A = c(1, 1, 0),
    available_B = c(1, 0, 1),
    stringsAsFactors = FALSE
  )
  result <- merge(schedules, availability, by = NULL)
  result$effective_effort <- with(
    result,
    effort_A * available_A + effort_B * available_B
  )
  result$total_effort <- total_effort
  result$missed_probability <- exp(
    -encounter_rate * result$effective_effort
  )
  result[c(
    "schedule", "availability", "effort_A", "effort_B",
    "total_effort", "effective_effort", "missed_probability"
  )]
}

.goal008_write_csv <- function(x, path) {
  utils::write.csv(x, path, row.names = FALSE, na = "")
}

#' Run and render the complete cheap Goal008 theory tranche
run_goal008_theory <- function(
  output_dir = file.path("outputs", "goal008", "theory-v2")
) {
  if (dir.exists(output_dir) || file.exists(output_dir)) {
    .goal008_stop("Goal008 theory output already exists.")
  }
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  gaussian <- goal008_gaussian_dependence()

  detected <- c(1L, 1L, rep(0L, 6L))
  detection_probability <- c(0.85, 0.70, 0.55, 0.40, 0.25, 0.12, 0.08, 0.04)
  pool <- goal008_finite_pool_pmf(
    detected, detection_probability, a = 1, b = 1
  )
  brute <- goal008_finite_pool_pmf_bruteforce(
    detected, detection_probability, a = 1, b = 1
  )
  pool_check <- merge(
    pool, brute, by = "richness", suffixes = c("_exact", "_bruteforce")
  )
  pool_check$absolute_error <- abs(
    pool_check$probability_exact - pool_check$probability_bruteforce
  )
  pool_summary <- goal008_finite_pool_summary(pool)
  pool_summary$maximum_bruteforce_error <- max(pool_check$absolute_error)
  pool_summary$candidate_count <- length(detected)
  pool_summary$detected_count <- sum(detected)
  zero_visibility <- goal008_finite_pool_pmf(rep(0L, 6L), rep(0, 6L))
  zero_visibility_brute <- goal008_finite_pool_pmf_bruteforce(
    rep(0L, 6L), rep(0, 6L)
  )
  perfect_visibility <- goal008_finite_pool_pmf(
    c(1L, 0L), c(0.8, 1)
  )
  impossible_detection_rejected <- inherits(
    try(goal008_finite_pool_pmf(c(1L, 0L), c(0, 0.5)), silent = TRUE),
    "try-error"
  )
  boundary_controls <- data.frame(
    control = c(
      "zero_visibility_uniform_beta_binomial",
      "zero_visibility_matches_enumeration",
      "perfectly_visible_undetected_membership_mass",
      "detected_with_zero_probability_rejected"
    ),
    observed = c(
      max(abs(zero_visibility$probability - 1 / 7)),
      max(abs(
        zero_visibility$probability - zero_visibility_brute$probability
      )),
      perfect_visibility$probability[perfect_visibility$richness == 2L],
      as.numeric(impossible_detection_rejected)
    ),
    expected = c(0, 0, 0, 1),
    tolerance = c(1e-14, 1e-14, 0, 0),
    stringsAsFactors = FALSE
  )
  boundary_controls$passed <- abs(
    boundary_controls$observed - boundary_controls$expected
  ) <= boundary_controls$tolerance

  missed <- goal008_missed_probability_examples()
  seasonal <- goal008_seasonal_allocation_examples()

  .goal008_write_csv(
    gaussian$coverage,
    file.path(output_dir, "gaussian-dependence-coverage.csv")
  )
  .goal008_write_csv(
    gaussian$finite_set,
    file.path(output_dir, "gaussian-finite-set.csv")
  )
  .goal008_write_csv(
    gaussian$parameters,
    file.path(output_dir, "gaussian-parameters.csv")
  )
  .goal008_write_csv(
    pool,
    file.path(output_dir, "finite-pool-richness-pmf.csv")
  )
  .goal008_write_csv(
    pool_summary,
    file.path(output_dir, "finite-pool-summary.csv")
  )
  .goal008_write_csv(
    pool_check,
    file.path(output_dir, "finite-pool-bruteforce-check.csv")
  )
  .goal008_write_csv(
    boundary_controls,
    file.path(output_dir, "finite-pool-boundary-controls.csv")
  )
  .goal008_write_csv(
    data.frame(
      candidate = seq_along(detected),
      detected = detected,
      detection_probability = detection_probability
    ),
    file.path(output_dir, "finite-pool-input.csv")
  )
  .goal008_write_csv(
    missed,
    file.path(output_dir, "mean-log-rate-missed-probability.csv")
  )
  .goal008_write_csv(
    seasonal,
    file.path(output_dir, "seasonal-allocation.csv")
  )

  grDevices::pdf(
    file.path(output_dir, "gaussian-dependence-coverage.pdf"),
    width = 7, height = 4.5
  )
  graphics::par(mar = c(8, 4, 1, 1))
  colours <- c("#2166AC", "#B2182B", "#4D9221")
  graphics::barplot(
    100 * gaussian$coverage$simulated_coverage,
    names.arg = c("Repeated:\ncorrect", "Repeated:\nas fresh", "Fresh:\ncorrect"),
    col = colours, ylim = c(0, 100), las = 1,
    ylab = "Empirical coverage (%)"
  )
  graphics::abline(
    h = 100 * gaussian$parameters$interval_level,
    lty = 2, col = "grey30"
  )
  grDevices::dev.off()

  grDevices::pdf(
    file.path(output_dir, "finite-pool-richness-pmf.pdf"),
    width = 7, height = 4.5
  )
  graphics::plot(
    pool$richness, pool$probability, type = "h", lwd = 8,
    lend = "butt", col = "#2166AC", xlab = "Reference-pool richness",
    ylab = "Posterior probability", ylim = c(0, max(pool$probability) * 1.08)
  )
  graphics::points(pool$richness, pool$probability, pch = 16)
  grDevices::dev.off()

  grDevices::pdf(
    file.path(output_dir, "missed-probability-counterexamples.pdf"),
    width = 8, height = 4.5
  )
  graphics::par(mfrow = c(1, 2), mar = c(4, 4, 2, 1))
  fixed <- missed[missed$distribution == "point_mass", ]
  mixture <- missed[missed$distribution == "symmetric_two_point", ]
  graphics::plot(
    fixed$effort, fixed$missed_probability, type = "b", pch = 16,
    ylim = range(missed$missed_probability), xlab = "Effort",
    ylab = "Probability of no detection", main = "Same mean log rate"
  )
  graphics::lines(
    mixture$effort, mixture$missed_probability,
    type = "b", pch = 17, col = "#B2182B"
  )
  graphics::legend(
    "topright", c("Point mass", "Two-point mixture"),
    pch = c(16, 17), col = c("black", "#B2182B"), bty = "n"
  )
  seasonal_subset <- seasonal[
    seasonal$availability != "year_round",
  ]
  seasonal_matrix <- xtabs(
    missed_probability ~ availability + schedule,
    data = seasonal_subset
  )
  colnames(seasonal_matrix) <- c("Balanced", "All in A", "All in B")
  graphics::barplot(
    seasonal_matrix, beside = TRUE,
    col = c("#2166AC", "#B2182B"), ylim = c(0, 1.18),
    ylab = "Probability of no detection", xlab = "Effort schedule",
    main = "Same total effort", las = 1
  )
  graphics::legend(
    "top", c("Available in A", "Available in B"),
    fill = c("#2166AC", "#B2182B"), bty = "n", cex = 0.8,
    horiz = TRUE
  )
  grDevices::dev.off()

  git_commit <- tryCatch(
    system2("git", c("rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE),
    error = function(error) NA_character_
  )
  git_status <- tryCatch(
    system2("git", c("status", "--porcelain"), stdout = TRUE, stderr = FALSE),
    error = function(error) NA_character_
  )
  source_paths <- c(
    file.path("R", "goal008_theory.R"),
    file.path("scripts", "run_goal008_theory.R")
  )
  source_hashes <- vapply(
    source_paths,
    function(path) {
      digest::digest(file = path, algo = "sha256", serialize = FALSE)
    },
    character(1)
  )
  provenance <- data.frame(
    field = c(
      "generated_utc", "r_version", "base_git_commit", "working_tree_clean",
      "theory_source_sha256", "runner_source_sha256", "simulation_seed",
      "simulation_replicates", "generating_mean", "location_prior",
      "rng_kind", "normal_kind", "sample_kind", "empirical_outcomes_used",
      "stan_used"
    ),
    value = c(
      format(Sys.time(), tz = "UTC", usetz = TRUE),
      R.version.string,
      git_commit[[1L]],
      as.character(length(git_status) == 0L),
      source_hashes[[1L]],
      source_hashes[[2L]],
      gaussian$parameters$seed,
      gaussian$parameters$n_simulation,
      gaussian$parameters$generating_mean,
      gaussian$parameters$location_prior,
      gaussian$parameters$rng_kind,
      gaussian$parameters$normal_kind,
      gaussian$parameters$sample_kind,
      "false",
      "false"
    ),
    stringsAsFactors = FALSE
  )
  .goal008_write_csv(provenance, file.path(output_dir, "provenance.csv"))
  writeLines(
    c(
      "status=THEORY_COMPLETE",
      paste0(
        "maximum_bruteforce_error=",
        format(max(pool_check$absolute_error), scientific = TRUE)
      ),
      paste0(
        "same_species_as_fresh_exact_coverage=",
        format(gaussian$coverage$exact_coverage[[2L]], digits = 8)
      ),
      paste0("finite_pool_boundary_controls_pass=", all(boundary_controls$passed)),
      "empirical_outcomes_used=false",
      "stan_used=false"
    ),
    file.path(output_dir, "completion-status.txt")
  )
  invisible(list(
    gaussian = gaussian,
    finite_pool = pool,
    finite_pool_check = pool_check,
    finite_pool_boundary_controls = boundary_controls,
    missed_probability = missed,
    seasonal_allocation = seasonal,
    provenance = provenance
  ))
}
