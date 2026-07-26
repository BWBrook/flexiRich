.goal002_prior_schema_version <- "1.0.0"

.goal002_prior_effort_fields <- c(
  "schema_version",
  "seed",
  "candidate_pool_size",
  "n_cameras",
  "n_occasions",
  "prefix_occasions",
  "occasion_days",
  "effort_hash",
  "effort_weekly"
)

.goal002_prior_draw_fields <- c(
  "schema_version",
  "profile_id",
  "profile",
  "profile_hash",
  "effort_hash",
  "effort_seed",
  "simulation_seed",
  "n_draws",
  "candidate_pool_size",
  "n_cameras",
  "n_occasions",
  "prefix_occasions",
  "occasion_days",
  "rng_kind",
  "rng_normal_kind",
  "rng_sample_kind",
  "omega",
  "mu_alpha",
  "sigma_alpha",
  "sigma_camera",
  "alpha",
  "camera_effect",
  "eta",
  "rate",
  "p1",
  "p7",
  "detect_probability_26",
  "detect_probability_208",
  "richness",
  "observed_26",
  "observed_208",
  "log_likelihood_26",
  "log_likelihood_208",
  "richness_pmf"
)

.goal002_prior_assessment_fields <- c(
  "schema_version",
  "profile_id",
  "profile_hash",
  "effort_hash",
  "simulation_seed",
  "n_draws",
  "rules",
  "automatic_rejected",
  "automatic_outcome"
)

.stop_invalid_goal002_prior <- function(message) {
  stop(message, call. = FALSE)
}

.goal002_hash <- function(value) {
  digest::digest(value, algo = "sha256", serialize = TRUE)
}

.goal002_profile_hash <- function(profile) {
  .goal002_hash(validate_goal002_profile(profile, type = "prior"))
}

.goal002_effort_hash <- function(effort) {
  .goal002_hash(list(
    schema_version = effort$schema_version,
    seed = effort$seed,
    candidate_pool_size = effort$candidate_pool_size,
    n_cameras = effort$n_cameras,
    n_occasions = effort$n_occasions,
    prefix_occasions = effort$prefix_occasions,
    occasion_days = effort$occasion_days,
    effort_weekly = effort$effort_weekly
  ))
}

.goal002_valid_hash <- function(x) {
  is.character(x) &&
    length(x) == 1L &&
    !is.na(x) &&
    grepl("^[0-9a-f]{64}$", x)
}

.goal002_prior_scalar_integer <- function(x, name, lower = 0L) {
  .goal002_assert_integer(
    x,
    name,
    lower = lower,
    upper = .Machine$integer.max
  )
}

goal002_prior_rules <- function() {
  list(
    n_draws = 10000L,
    candidate_pool_size = 30L,
    n_cameras = 9L,
    n_occasions = 208L,
    prefix_occasions = 26L,
    pmf_tolerance = 1e-12,
    max_observed_mass = 0.95,
    min_partial_probability = 0.05,
    quantiles = c(
      0,
      0.001,
      0.01,
      0.05,
      0.5,
      0.95,
      0.99,
      0.999,
      1
    )
  )
}

goal002_prior_effort <- function(seed) {
  seed <- .goal002_prior_scalar_integer(seed, "seed")
  rules <- goal002_prior_rules()
  config <- flexirich_sim_config(
    candidate_pool_size = rules$candidate_pool_size,
    n_cameras = rules$n_cameras,
    n_occasions = rules$n_occasions,
    occasion_days = 7L,
    seed = seed
  )
  effort_daily <- simulate_daily_effort(config)
  effort_weekly <- aggregate_weekly_effort(effort_daily, config)

  result <- list(
    schema_version = .goal002_prior_schema_version,
    seed = seed,
    candidate_pool_size = rules$candidate_pool_size,
    n_cameras = rules$n_cameras,
    n_occasions = rules$n_occasions,
    prefix_occasions = rules$prefix_occasions,
    occasion_days = 7L,
    effort_hash = "",
    effort_weekly = effort_weekly
  )
  result$effort_hash <- .goal002_effort_hash(result)
  class(result) <- c("goal002_prior_effort", "list")
  validate_goal002_prior_effort(result)
  result
}

validate_goal002_prior_effort <- function(effort) {
  if (!is.list(effort) ||
      !identical(class(effort), c("goal002_prior_effort", "list")) ||
      !identical(names(attributes(effort)), c("names", "class")) ||
      !identical(names(effort), .goal002_prior_effort_fields)) {
    .stop_invalid_goal002_prior(
      "effort must be a canonical goal002_prior_effort object."
    )
  }

  rules <- goal002_prior_rules()
  expected_scalars <- list(
    candidate_pool_size = rules$candidate_pool_size,
    n_cameras = rules$n_cameras,
    n_occasions = rules$n_occasions,
    prefix_occasions = rules$prefix_occasions,
    occasion_days = 7L
  )
  if (!identical(effort$schema_version, .goal002_prior_schema_version)) {
    .stop_invalid_goal002_prior("effort has an invalid schema_version.")
  }
  .goal002_prior_scalar_integer(effort$seed, "effort$seed")
  for (field in names(expected_scalars)) {
    if (!identical(effort[[field]], expected_scalars[[field]])) {
      .stop_invalid_goal002_prior(
        paste0("effort$", field, " does not match the frozen contract.")
      )
    }
  }
  if (!.goal002_valid_hash(effort$effort_hash)) {
    .stop_invalid_goal002_prior("effort$effort_hash is invalid.")
  }

  expected_fields <- c(
    "camera_id",
    "occasion_id",
    "occasion_start",
    "occasion_end",
    "active_days"
  )
  weekly <- effort$effort_weekly
  expected_rows <- rules$n_cameras * rules$n_occasions
  if (!tibble::is_tibble(weekly) ||
      !identical(names(weekly), expected_fields) ||
      nrow(weekly) != expected_rows ||
      !is.character(weekly$camera_id) ||
      !is.character(weekly$occasion_id) ||
      !inherits(weekly$occasion_start, "Date") ||
      !inherits(weekly$occasion_end, "Date") ||
      !is.integer(weekly$active_days) ||
      anyNA(weekly) ||
      any(weekly$active_days < 0L | weekly$active_days > 7L)) {
    .stop_invalid_goal002_prior(
      "effort$effort_weekly has an invalid table contract."
    )
  }

  expected_cameras <- sprintf("cam_%02d", seq_len(rules$n_cameras))
  expected_occasions <- sprintf(
    "occ_%03d",
    seq_len(rules$n_occasions)
  )
  expected_start <- as.Date("2019-06-01") +
    rep(
      (seq_len(rules$n_occasions) - 1L) * 7L,
      times = rules$n_cameras
    )
  expected_end <- expected_start + 6L
  if (!identical(
    weekly$camera_id,
    rep(expected_cameras, each = rules$n_occasions)
  ) ||
      !identical(
        weekly$occasion_id,
        rep(expected_occasions, times = rules$n_cameras)
      ) ||
      !identical(weekly$occasion_start, expected_start) ||
      !identical(weekly$occasion_end, expected_end)) {
    .stop_invalid_goal002_prior(
      "effort$effort_weekly is not in frozen canonical order."
    )
  }

  if (!identical(.goal002_effort_hash(effort), effort$effort_hash)) {
    .stop_invalid_goal002_prior(
      "effort$effort_hash does not match the canonical effort data."
    )
  }
  TRUE
}

.goal002_member_log_likelihood <- function(observed, probability, member) {
  if (!any(member)) {
    return(0)
  }
  observed <- observed[member]
  probability <- probability[member]
  detected <- observed == 1L
  contributions <- numeric(length(probability))
  contributions[detected] <- log(probability[detected])
  contributions[!detected] <- log1p(-probability[!detected])
  sum(contributions)
}

simulate_goal002_prior <- function(profile, effort, n_draws, seed) {
  profile <- validate_goal002_profile(profile, type = "prior")
  validate_goal002_prior_effort(effort)
  n_draws <- .goal002_assert_integer(
    n_draws,
    "n_draws",
    lower = 1L,
    upper = goal002_prior_rules()$n_draws
  )
  seed <- .goal002_prior_scalar_integer(seed, "seed")
  rules <- goal002_prior_rules()
  C <- rules$candidate_pool_size
  J <- rules$n_cameras

  weekly_effort <- matrix(
    effort$effort_weekly$active_days,
    nrow = J,
    ncol = rules$n_occasions,
    byrow = TRUE
  )
  cumulative_effort_26 <- rowSums(
    weekly_effort[, seq_len(rules$prefix_occasions), drop = FALSE]
  )
  cumulative_effort_208 <- rowSums(weekly_effort)
  Q <- .sum_zero_basis(J)

  generated <- .with_sim_rng(seed, {
    withr::with_seed(seed, {
      omega <- numeric(n_draws)
      mu_alpha <- numeric(n_draws)
      sigma_alpha <- numeric(n_draws)
      sigma_camera <- numeric(n_draws)
      alpha <- matrix(0, nrow = n_draws, ncol = C)
      camera_effect <- matrix(0, nrow = n_draws, ncol = J)
      eta <- array(0, dim = c(n_draws, C, J))
      rate <- array(0, dim = c(n_draws, C, J))
      p1 <- array(0, dim = c(n_draws, C, J))
      p7 <- array(0, dim = c(n_draws, C, J))
      detect_probability_26 <- matrix(
        0,
        nrow = n_draws,
        ncol = C
      )
      detect_probability_208 <- matrix(
        0,
        nrow = n_draws,
        ncol = C
      )
      richness <- integer(n_draws)
      observed_26 <- integer(n_draws)
      observed_208 <- integer(n_draws)
      log_likelihood_26 <- numeric(n_draws)
      log_likelihood_208 <- numeric(n_draws)

      for (draw in seq_len(n_draws)) {
        omega[draw] <- stats::rbeta(
          1L,
          profile$omega_alpha,
          profile$omega_beta
        )
        mu_alpha[draw] <- stats::rnorm(
          1L,
          profile$mu_alpha_location,
          profile$mu_alpha_scale
        )
        sigma_alpha[draw] <- abs(stats::rnorm(
          1L,
          0,
          profile$sigma_alpha_scale
        ))
        sigma_camera[draw] <- abs(stats::rnorm(
          1L,
          0,
          profile$sigma_camera_scale
        ))

        alpha_draw <- mu_alpha[draw] +
          sigma_alpha[draw] * stats::rnorm(C)
        camera_draw <- as.numeric(
          sigma_camera[draw] * Q %*% stats::rnorm(J - 1L)
        )
        eta_draw <- outer(alpha_draw, camera_draw, "+")
        rate_draw <- exp(eta_draw)
        p1_draw <- -expm1(-rate_draw)
        p7_draw <- -expm1(-7 * rate_draw)
        probability_26 <- -expm1(
          -as.numeric(rate_draw %*% cumulative_effort_26)
        )
        probability_208 <- -expm1(
          -as.numeric(rate_draw %*% cumulative_effort_208)
        )

        member <- stats::rbinom(C, 1L, omega[draw]) == 1L
        shared_uniform <- stats::runif(C)
        state_26 <- as.integer(
          member & shared_uniform < probability_26
        )
        state_208 <- as.integer(
          member & shared_uniform < probability_208
        )

        alpha[draw, ] <- alpha_draw
        camera_effect[draw, ] <- camera_draw
        eta[draw, , ] <- eta_draw
        rate[draw, , ] <- rate_draw
        p1[draw, , ] <- p1_draw
        p7[draw, , ] <- p7_draw
        detect_probability_26[draw, ] <- probability_26
        detect_probability_208[draw, ] <- probability_208
        richness[draw] <- as.integer(sum(member))
        observed_26[draw] <- as.integer(sum(state_26))
        observed_208[draw] <- as.integer(sum(state_208))
        log_likelihood_26[draw] <- .goal002_member_log_likelihood(
          state_26,
          probability_26,
          member
        )
        log_likelihood_208[draw] <- .goal002_member_log_likelihood(
          state_208,
          probability_208,
          member
        )
      }

      list(
        omega = omega,
        mu_alpha = mu_alpha,
        sigma_alpha = sigma_alpha,
        sigma_camera = sigma_camera,
        alpha = alpha,
        camera_effect = camera_effect,
        eta = eta,
        rate = rate,
        p1 = p1,
        p7 = p7,
        detect_probability_26 = detect_probability_26,
        detect_probability_208 = detect_probability_208,
        richness = richness,
        observed_26 = observed_26,
        observed_208 = observed_208,
        log_likelihood_26 = log_likelihood_26,
        log_likelihood_208 = log_likelihood_208
      )
    })
  })

  richness_pmf <- lower_bound_prior_pmf(
    candidate_pool_size = C,
    observed_richness = 0L,
    omega_alpha = profile$omega_alpha,
    omega_beta = profile$omega_beta
  )
  result <- c(
    list(
      schema_version = .goal002_prior_schema_version,
      profile_id = profile$profile_id,
      profile = profile,
      profile_hash = .goal002_profile_hash(profile),
      effort_hash = effort$effort_hash,
      effort_seed = effort$seed,
      simulation_seed = seed,
      n_draws = n_draws,
      candidate_pool_size = C,
      n_cameras = J,
      n_occasions = rules$n_occasions,
      prefix_occasions = rules$prefix_occasions,
      occasion_days = 7L,
      rng_kind = unname(.sim_rng_algorithms[["kind"]]),
      rng_normal_kind = unname(.sim_rng_algorithms[["normal.kind"]]),
      rng_sample_kind = unname(.sim_rng_algorithms[["sample.kind"]])
    ),
    generated,
    list(richness_pmf = richness_pmf)
  )
  class(result) <- c("goal002_prior_draws", "list")
  validate_goal002_prior_draws(result)
  result
}

.goal002_validate_draw_array <- function(
  value,
  name,
  expected_dim,
  integer = FALSE
) {
  valid_type <- if (integer) {
    is.integer(value)
  } else {
    is.double(value)
  }
  if (!valid_type || !identical(dim(value), expected_dim)) {
    .stop_invalid_goal002_prior(
      paste0("draws$", name, " has an invalid type or dimensions.")
    )
  }
  invisible(TRUE)
}

.goal002_validate_draw_provenance <- function(draws) {
  expected_effort <- goal002_prior_effort(draws$effort_seed)
  if (!identical(draws$effort_hash, expected_effort$effort_hash)) {
    .stop_invalid_goal002_prior(
      "draws effort provenance does not link effort_seed to effort_hash."
    )
  }

  expected_pmf <- lower_bound_prior_pmf(
    candidate_pool_size = draws$candidate_pool_size,
    observed_richness = 0L,
    omega_alpha = draws$profile$omega_alpha,
    omega_beta = draws$profile$omega_beta
  )
  pmf <- draws$richness_pmf
  pmf_is_rule_valid <- identical(
    pmf$richness,
    seq.int(0L, draws$candidate_pool_size)
  ) &&
    all(is.finite(pmf$probability)) &&
    all(pmf$probability >= 0) &&
    abs(sum(pmf$probability) - 1) <=
      goal002_prior_rules()$pmf_tolerance
  if (pmf_is_rule_valid && !identical(pmf, expected_pmf)) {
    .stop_invalid_goal002_prior(
      "draws analytical beta-binomial PMF does not match the profile."
    )
  }

  expected_effort
}

.goal002_validate_finite_draw_identities <- function(draws, effort) {
  identity_fields <- c(
    "alpha",
    "camera_effect",
    "eta",
    "rate",
    "p1",
    "p7",
    "detect_probability_26",
    "detect_probability_208"
  )
  if (any(vapply(
    identity_fields,
    function(field) any(!is.finite(draws[[field]])),
    logical(1)
  ))) {
    return(invisible(TRUE))
  }

  rules <- goal002_prior_rules()
  weekly_effort <- matrix(
    effort$effort_weekly$active_days,
    nrow = rules$n_cameras,
    ncol = rules$n_occasions,
    byrow = TRUE
  )
  effort_26 <- rowSums(
    weekly_effort[, seq_len(rules$prefix_occasions), drop = FALSE]
  )
  effort_208 <- rowSums(weekly_effort)

  for (draw in seq_len(draws$n_draws)) {
    camera_effect <- draws$camera_effect[draw, ]
    if (abs(sum(camera_effect)) > 1e-12) {
      .stop_invalid_goal002_prior(
        "draws$camera_effect does not satisfy the sum-zero contract."
      )
    }
    expected_eta <- outer(
      draws$alpha[draw, ],
      camera_effect,
      "+"
    )
    if (!identical(draws$eta[draw, , ], expected_eta)) {
      .stop_invalid_goal002_prior(
        "draws$eta does not equal alpha plus camera_effect."
      )
    }
    expected_rate <- exp(expected_eta)
    if (!identical(draws$rate[draw, , ], expected_rate)) {
      .stop_invalid_goal002_prior(
        "draws$rate does not equal exp(eta)."
      )
    }
    if (!identical(
      draws$p1[draw, , ],
      -expm1(-expected_rate)
    )) {
      .stop_invalid_goal002_prior(
        "draws$p1 does not match the one-day encounter probability."
      )
    }
    if (!identical(
      draws$p7[draw, , ],
      -expm1(-7 * expected_rate)
    )) {
      .stop_invalid_goal002_prior(
        "draws$p7 does not match the seven-day encounter probability."
      )
    }
    expected_26 <- -expm1(
      -as.numeric(expected_rate %*% effort_26)
    )
    if (!identical(
      draws$detect_probability_26[draw, ],
      expected_26
    )) {
      .stop_invalid_goal002_prior(
        paste0(
          "draws$detect_probability_26 does not match cumulative ",
          "prefix effort."
        )
      )
    }
    expected_208 <- -expm1(
      -as.numeric(expected_rate %*% effort_208)
    )
    if (!identical(
      draws$detect_probability_208[draw, ],
      expected_208
    )) {
      .stop_invalid_goal002_prior(
        paste0(
          "draws$detect_probability_208 does not match cumulative ",
          "full effort."
        )
      )
    }
  }
  invisible(TRUE)
}

validate_goal002_prior_draws <- function(draws) {
  if (!is.list(draws) ||
      !identical(class(draws), c("goal002_prior_draws", "list")) ||
      !identical(names(attributes(draws)), c("names", "class")) ||
      !identical(names(draws), .goal002_prior_draw_fields)) {
    .stop_invalid_goal002_prior(
      "draws must be a canonical goal002_prior_draws object."
    )
  }
  if (!identical(draws$schema_version, .goal002_prior_schema_version)) {
    .stop_invalid_goal002_prior("draws has an invalid schema_version.")
  }

  profile <- validate_goal002_profile(draws$profile, type = "prior")
  if (!identical(draws$profile_id, profile$profile_id) ||
      !.goal002_valid_hash(draws$profile_hash) ||
      !identical(draws$profile_hash, .goal002_profile_hash(profile))) {
    .stop_invalid_goal002_prior("draws has invalid profile provenance.")
  }
  if (!.goal002_valid_hash(draws$effort_hash)) {
    .stop_invalid_goal002_prior("draws$effort_hash is invalid.")
  }

  n_draws <- .goal002_prior_scalar_integer(
    draws$n_draws,
    "draws$n_draws",
    lower = 1L
  )
  .goal002_prior_scalar_integer(draws$effort_seed, "draws$effort_seed")
  .goal002_prior_scalar_integer(
    draws$simulation_seed,
    "draws$simulation_seed"
  )
  rules <- goal002_prior_rules()
  expected_scalars <- list(
    candidate_pool_size = rules$candidate_pool_size,
    n_cameras = rules$n_cameras,
    n_occasions = rules$n_occasions,
    prefix_occasions = rules$prefix_occasions,
    occasion_days = 7L
  )
  for (field in names(expected_scalars)) {
    if (!identical(draws[[field]], expected_scalars[[field]])) {
      .stop_invalid_goal002_prior(
        paste0("draws$", field, " does not match the frozen contract.")
      )
    }
  }
  expected_rng <- list(
    rng_kind = unname(.sim_rng_algorithms[["kind"]]),
    rng_normal_kind = unname(.sim_rng_algorithms[["normal.kind"]]),
    rng_sample_kind = unname(.sim_rng_algorithms[["sample.kind"]])
  )
  for (field in names(expected_rng)) {
    if (!identical(draws[[field]], expected_rng[[field]])) {
      .stop_invalid_goal002_prior(
        paste0("draws$", field, " does not match the canonical RNG.")
      )
    }
  }

  for (field in c(
    "omega",
    "mu_alpha",
    "sigma_alpha",
    "sigma_camera",
    "log_likelihood_26",
    "log_likelihood_208"
  )) {
    if (!is.double(draws[[field]]) ||
        length(draws[[field]]) != n_draws ||
        !is.null(dim(draws[[field]]))) {
      .stop_invalid_goal002_prior(
        paste0("draws$", field, " has an invalid vector contract.")
      )
    }
  }
  for (field in c("richness", "observed_26", "observed_208")) {
    if (!is.integer(draws[[field]]) ||
        length(draws[[field]]) != n_draws ||
        !is.null(dim(draws[[field]]))) {
      .stop_invalid_goal002_prior(
        paste0("draws$", field, " has an invalid vector contract.")
      )
    }
  }

  C <- rules$candidate_pool_size
  J <- rules$n_cameras
  .goal002_validate_draw_array(
    draws$alpha,
    "alpha",
    c(n_draws, C)
  )
  .goal002_validate_draw_array(
    draws$camera_effect,
    "camera_effect",
    c(n_draws, J)
  )
  for (field in c("eta", "rate", "p1", "p7")) {
    .goal002_validate_draw_array(
      draws[[field]],
      field,
      c(n_draws, C, J)
    )
  }
  for (field in c(
    "detect_probability_26",
    "detect_probability_208"
  )) {
    .goal002_validate_draw_array(
      draws[[field]],
      field,
      c(n_draws, C)
    )
  }

  pmf <- draws$richness_pmf
  if (!tibble::is_tibble(pmf) ||
      !identical(names(pmf), c("richness", "probability")) ||
      !is.integer(pmf$richness) ||
      !is.double(pmf$probability) ||
      nrow(pmf) != C + 1L) {
    .stop_invalid_goal002_prior(
      "draws$richness_pmf has an invalid table contract."
    )
  }
  expected_effort <- .goal002_validate_draw_provenance(draws)
  .goal002_validate_finite_draw_identities(draws, expected_effort)
  TRUE
}

.goal002_count_invalid_draw_values <- function(draws) {
  invalid <- 0
  finite_fields <- c(
    "omega",
    "mu_alpha",
    "sigma_alpha",
    "sigma_camera",
    "alpha",
    "camera_effect",
    "eta",
    "rate",
    "p1",
    "p7",
    "detect_probability_26",
    "detect_probability_208",
    "richness",
    "observed_26",
    "observed_208",
    "log_likelihood_26",
    "log_likelihood_208"
  )
  for (field in finite_fields) {
    invalid <- invalid + sum(!is.finite(draws[[field]]))
  }

  invalid <- invalid +
    sum(draws$omega < 0 | draws$omega > 1, na.rm = TRUE) +
    sum(draws$sigma_alpha < 0, na.rm = TRUE) +
    sum(draws$sigma_camera < 0, na.rm = TRUE) +
    sum(draws$rate < 0, na.rm = TRUE)
  for (field in c(
    "p1",
    "p7",
    "detect_probability_26",
    "detect_probability_208"
  )) {
    invalid <- invalid +
      sum(draws[[field]] < 0 | draws[[field]] > 1, na.rm = TRUE)
  }
  as.numeric(invalid)
}

.goal002_order_violation_count <- function(draws) {
  values <- c(
    draws$richness,
    draws$observed_26,
    draws$observed_208
  )
  if (any(!is.finite(values))) {
    return(Inf)
  }
  sum(
    draws$observed_26 < 0L |
      draws$observed_208 < 0L |
      draws$richness < 0L |
      draws$observed_26 > draws$observed_208 |
      draws$observed_208 > draws$richness |
      draws$richness > draws$candidate_pool_size
  )
}

.goal002_pmf_error <- function(pmf, candidate_pool_size) {
  expected_support <- seq.int(0L, candidate_pool_size)
  valid <- identical(pmf$richness, expected_support) &&
    length(pmf$probability) == candidate_pool_size + 1L &&
    all(is.finite(pmf$probability)) &&
    all(pmf$probability >= 0)
  if (!valid) {
    return(Inf)
  }
  abs(sum(pmf$probability) - 1)
}

.goal002_max_empirical_mass <- function(x) {
  if (length(x) == 0L || any(!is.finite(x))) {
    return(Inf)
  }
  as.numeric(max(tabulate(match(x, unique(x)))) / length(x))
}

.goal002_partial_probability <- function(observed, richness, C) {
  if (length(observed) == 0L ||
      length(observed) != length(richness) ||
      any(!is.finite(observed)) ||
      any(!is.finite(richness))) {
    return(0)
  }
  eligible <- richness > 1L & richness < C
  if (!any(eligible)) {
    return(0)
  }
  mean(
    observed[eligible] > 0L &
      observed[eligible] < richness[eligible]
  )
}

assess_goal002_prior <- function(
  draws,
  tolerance = goal002_prior_rules()$pmf_tolerance
) {
  validate_goal002_prior_draws(draws)
  rules <- goal002_prior_rules()
  valid_tolerance <- is.numeric(tolerance) &&
    !is.logical(tolerance) &&
    length(tolerance) == 1L &&
    !is.na(tolerance) &&
    is.finite(tolerance) &&
    identical(as.numeric(tolerance), rules$pmf_tolerance)
  if (!valid_tolerance) {
    .stop_invalid_goal002_prior(
      "tolerance must equal the frozen PMF tolerance of 1e-12."
    )
  }

  statistic <- c(
    .goal002_count_invalid_draw_values(draws),
    .goal002_order_violation_count(draws),
    .goal002_pmf_error(
      draws$richness_pmf,
      draws$candidate_pool_size
    ),
    .goal002_max_empirical_mass(draws$observed_26),
    .goal002_max_empirical_mass(draws$observed_208),
    .goal002_partial_probability(
      draws$observed_26,
      draws$richness,
      draws$candidate_pool_size
    ),
    .goal002_partial_probability(
      draws$observed_208,
      draws$richness,
      draws$candidate_pool_size
    )
  )
  threshold <- c(
    0,
    0,
    rules$pmf_tolerance,
    rules$max_observed_mass,
    rules$max_observed_mass,
    rules$min_partial_probability,
    rules$min_partial_probability
  )
  comparison <- c("<=", "<=", "<=", "<", "<", ">=", ">=")
  passed <- c(
    statistic[1L] <= threshold[1L],
    statistic[2L] <= threshold[2L],
    statistic[3L] <= threshold[3L],
    statistic[4L] < threshold[4L],
    statistic[5L] < threshold[5L],
    statistic[6L] >= threshold[6L],
    statistic[7L] >= threshold[7L]
  )
  rule_table <- tibble::tibble(
    rule_id = c(
      "finite_draws",
      "nested_richness_bounds",
      "richness_pmf",
      "max_observed_mass_26",
      "max_observed_mass_208",
      "min_partial_probability_26",
      "min_partial_probability_208"
    ),
    statistic = as.numeric(statistic),
    threshold = as.numeric(threshold),
    comparison = comparison,
    passed = as.logical(passed),
    automatic_outcome = ifelse(
      passed,
      "not_rejected_automatically",
      "rejected_automatically"
    )
  )
  rejected <- any(!rule_table$passed)

  list(
    schema_version = .goal002_prior_schema_version,
    profile_id = draws$profile_id,
    profile_hash = draws$profile_hash,
    effort_hash = draws$effort_hash,
    simulation_seed = draws$simulation_seed,
    n_draws = draws$n_draws,
    rules = rule_table,
    automatic_rejected = rejected,
    automatic_outcome = if (rejected) {
      "rejected_automatically"
    } else {
      "not_rejected_automatically"
    }
  )
}

.goal002_safe_quantile <- function(x, probabilities) {
  if (length(x) == 0L || any(!is.finite(x))) {
    return(rep(NA_real_, length(probabilities)))
  }
  as.numeric(stats::quantile(
    x,
    probs = probabilities,
    names = FALSE,
    type = 7L
  ))
}

.goal002_safe_frequency <- function(condition) {
  if (length(condition) == 0L || anyNA(condition)) {
    return(NA_real_)
  }
  mean(condition)
}

.goal002_validate_assessment <- function(assessment, draws) {
  if (!is.list(assessment) ||
      !identical(names(assessment), .goal002_prior_assessment_fields)) {
    .stop_invalid_goal002_prior(
      "assessment has an invalid component contract."
    )
  }
  provenance_matches <- identical(
    assessment$schema_version,
    draws$schema_version
  ) &&
    identical(assessment$profile_id, draws$profile_id) &&
    identical(assessment$profile_hash, draws$profile_hash) &&
    identical(assessment$effort_hash, draws$effort_hash) &&
    identical(assessment$simulation_seed, draws$simulation_seed) &&
    identical(assessment$n_draws, draws$n_draws)
  if (!provenance_matches) {
    .stop_invalid_goal002_prior(
      "assessment and draws provenance do not match."
    )
  }

  expected_rule_fields <- c(
    "rule_id",
    "statistic",
    "threshold",
    "comparison",
    "passed",
    "automatic_outcome"
  )
  if (!tibble::is_tibble(assessment$rules) ||
      !identical(names(assessment$rules), expected_rule_fields) ||
      nrow(assessment$rules) != 7L ||
      !is.character(assessment$rules$rule_id) ||
      !is.double(assessment$rules$statistic) ||
      !is.double(assessment$rules$threshold) ||
      !is.character(assessment$rules$comparison) ||
      !is.logical(assessment$rules$passed) ||
      !is.character(assessment$rules$automatic_outcome) ||
      anyNA(assessment$rules$passed) ||
      !is.logical(assessment$automatic_rejected) ||
      length(assessment$automatic_rejected) != 1L ||
      is.na(assessment$automatic_rejected) ||
      !is.character(assessment$automatic_outcome) ||
      length(assessment$automatic_outcome) != 1L ||
      is.na(assessment$automatic_outcome)) {
    .stop_invalid_goal002_prior(
      "assessment has an invalid automatic-rule contract."
    )
  }
  expected <- assess_goal002_prior(draws)
  if (!identical(assessment, expected)) {
    .stop_invalid_goal002_prior(
      "assessment does not exactly match the supplied draws."
    )
  }
  TRUE
}

goal002_prior_report <- function(draws, assessment) {
  validate_goal002_prior_draws(draws)
  .goal002_validate_assessment(assessment, draws)
  probabilities <- goal002_prior_rules()$quantiles
  quantile_inputs <- list(
    eta = as.vector(draws$eta),
    rate = as.vector(draws$rate),
    p1 = as.vector(draws$p1),
    p7 = as.vector(draws$p7),
    richness = draws$richness,
    observed_26 = draws$observed_26,
    observed_208 = draws$observed_208
  )
  quantiles <- dplyr::bind_rows(lapply(
    names(quantile_inputs),
    function(variable) {
      values <- .goal002_safe_quantile(
        quantile_inputs[[variable]],
        probabilities
      )
      tibble::tibble(
        variable = variable,
        probability = probabilities,
        value = values
      )
    }
  ))

  boundaries <- tibble::tibble(
    variable = c(
      "richness",
      "richness",
      "observed_26",
      "observed_26",
      "observed_208",
      "observed_208"
    ),
    boundary = c(
      "zero",
      "candidate_pool",
      "zero",
      "equals_richness",
      "zero",
      "equals_richness"
    ),
    frequency = c(
      .goal002_safe_frequency(draws$richness == 0L),
      .goal002_safe_frequency(
        draws$richness == draws$candidate_pool_size
      ),
      .goal002_safe_frequency(draws$observed_26 == 0L),
      .goal002_safe_frequency(
        draws$observed_26 == draws$richness
      ),
      .goal002_safe_frequency(draws$observed_208 == 0L),
      .goal002_safe_frequency(
        draws$observed_208 == draws$richness
      )
    )
  )

  saturation_inputs <- list(
    p1 = draws$p1,
    p7 = draws$p7,
    detect_probability_26 = draws$detect_probability_26,
    detect_probability_208 = draws$detect_probability_208
  )
  saturation <- dplyr::bind_rows(lapply(
    names(saturation_inputs),
    function(variable) {
      value <- saturation_inputs[[variable]]
      tibble::tibble(
        variable = rep(variable, 2L),
        boundary = c("floating_zero", "floating_one"),
        frequency = c(
          .goal002_safe_frequency(value == 0),
          .goal002_safe_frequency(value == 1)
        )
      )
    }
  ))

  list(
    schema_version = .goal002_prior_schema_version,
    profile_id = draws$profile_id,
    profile = draws$profile,
    profile_hash = draws$profile_hash,
    effort_hash = draws$effort_hash,
    effort_seed = draws$effort_seed,
    simulation_seed = draws$simulation_seed,
    n_draws = draws$n_draws,
    quantile_type = 7L,
    automatic_outcome = assessment$automatic_outcome,
    assessment = assessment$rules,
    richness_pmf = draws$richness_pmf,
    quantiles = quantiles,
    boundary_frequencies = boundaries,
    saturation_frequencies = saturation
  )
}

.goal002_prior_profile_stubs <- function() {
  c(
    primary = "primary",
    sensitivity_membership = "sensitivity-membership",
    sensitivity_tail = "sensitivity-tail"
  )
}

.goal002_prior_expected_inventory <- function(include_index = TRUE) {
  profile_suffix <- c(
    "assessment.csv",
    "boundary-frequencies.csv",
    "profile.csv",
    "quantiles.csv",
    "report.rds",
    "richness-pmf.csv",
    "saturation-frequencies.csv"
  )
  inventory <- c(
    "automatic-assessment.csv",
    "effort-provenance.csv",
    "effort-weekly.csv",
    "effort.rds",
    "run-manifest.csv",
    as.vector(outer(
      unname(.goal002_prior_profile_stubs()),
      profile_suffix,
      paste,
      sep = "-"
    ))
  )
  if (include_index) {
    inventory <- c(inventory, "prior-check-index.rds")
  }
  sort(inventory)
}

.goal002_prior_file_inventory <- function(directory) {
  relative <- .goal002_prior_expected_inventory(include_index = FALSE)
  full_path <- file.path(directory, relative)
  if (any(!file.exists(full_path)) || any(dir.exists(full_path))) {
    .stop_invalid_goal002_prior(
      "Prior evidence is missing a required compact output file."
    )
  }
  tibble::tibble(
    path = relative,
    sha256 = unname(vapply(full_path, function(path) {
      digest::digest(
        file = path,
        algo = "sha256",
        serialize = FALSE
      )
    }, character(1))),
    bytes = unname(as.double(file.info(full_path)$size))
  )
}

.goal002_prior_write_csv <- function(value, path) {
  withr::with_options(
    list(digits = 17L),
    utils::write.csv(value, path, row.names = FALSE)
  )
  invisible(path)
}

.goal002_prior_readlink <- function(path) {
  link <- Sys.readlink(path)
  if (length(link) != 1L || is.na(link) || !nzchar(link)) {
    return("")
  }
  link
}

.goal002_validate_prior_runner_inputs <- function(
  output_dir,
  effort_seed,
  prior_seed,
  n_draws,
  profile_completed
) {
  valid_output <- is.character(output_dir) &&
    length(output_dir) == 1L &&
    !is.na(output_dir) &&
    nzchar(output_dir)
  if (!valid_output) {
    .stop_invalid_goal002_prior(
      "output_dir must be one non-empty character path."
    )
  }
  effort_seed <- .goal002_prior_scalar_integer(
    effort_seed,
    "effort_seed"
  )
  n_draws <- .goal002_assert_integer(
    n_draws,
    "n_draws",
    lower = 1L,
    upper = goal002_prior_rules()$n_draws
  )
  expected_keys <- names(goal002_prior_profiles())
  valid_seeds <- is.numeric(prior_seed) &&
    !is.complex(prior_seed) &&
    !is.logical(prior_seed) &&
    identical(names(prior_seed), expected_keys) &&
    length(prior_seed) == length(expected_keys) &&
    !anyNA(prior_seed) &&
    all(is.finite(prior_seed)) &&
    all(prior_seed == trunc(prior_seed)) &&
    all(prior_seed >= 0) &&
    all(prior_seed <= .Machine$integer.max)
  if (!valid_seeds) {
    .stop_invalid_goal002_prior(
      "prior_seed must be a named integer-valued seed for each profile."
    )
  }
  prior_seed <- stats::setNames(
    as.integer(prior_seed),
    expected_keys
  )
  if (!is.null(profile_completed) && !is.function(profile_completed)) {
    .stop_invalid_goal002_prior(
      "profile_completed must be NULL or a function."
    )
  }

  parent <- dirname(output_dir)
  dir.create(parent, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(parent)) {
    .stop_invalid_goal002_prior(
      "Could not create the prior evidence parent directory."
    )
  }
  parent <- normalizePath(parent, mustWork = TRUE)
  output_dir <- file.path(parent, basename(output_dir))

  list(
    output_dir = output_dir,
    effort_seed = effort_seed,
    prior_seed = prior_seed,
    n_draws = n_draws,
    profile_completed = profile_completed
  )
}

.goal002_write_prior_evidence <- function(
  directory,
  effort_seed,
  prior_seed,
  n_draws,
  profile_completed,
  verbose
) {
  rules <- goal002_prior_rules()
  profiles <- goal002_prior_profiles()
  stubs <- .goal002_prior_profile_stubs()
  effort <- goal002_prior_effort(seed = effort_seed)

  saveRDS(
    effort,
    file.path(directory, "effort.rds"),
    version = 3L
  )
  .goal002_prior_write_csv(
    effort$effort_weekly,
    file.path(directory, "effort-weekly.csv")
  )
  .goal002_prior_write_csv(
    data.frame(
      schema_version = effort$schema_version,
      effort_seed = effort$seed,
      effort_hash = effort$effort_hash,
      candidate_pool_size = effort$candidate_pool_size,
      n_cameras = effort$n_cameras,
      n_occasions = effort$n_occasions,
      prefix_occasions = effort$prefix_occasions,
      occasion_days = effort$occasion_days,
      stringsAsFactors = FALSE
    ),
    file.path(directory, "effort-provenance.csv")
  )

  all_assessments <- vector("list", length(profiles))
  all_manifests <- vector("list", length(profiles))
  names(all_assessments) <- names(profiles)
  names(all_manifests) <- names(profiles)

  for (profile_key in names(profiles)) {
    if (verbose) {
      message("Prior-predictive profile: ", profile_key)
    }
    draws <- simulate_goal002_prior(
      profile = profiles[[profile_key]],
      effort = effort,
      n_draws = n_draws,
      seed = unname(prior_seed[[profile_key]])
    )
    assessment <- assess_goal002_prior(draws)
    report <- goal002_prior_report(draws, assessment)
    stub <- unname(stubs[[profile_key]])

    saveRDS(
      report,
      file.path(directory, paste0(stub, "-report.rds")),
      version = 3L
    )
    .goal002_prior_write_csv(
      report$assessment,
      file.path(directory, paste0(stub, "-assessment.csv"))
    )
    .goal002_prior_write_csv(
      as.data.frame(report$profile, stringsAsFactors = FALSE),
      file.path(directory, paste0(stub, "-profile.csv"))
    )
    .goal002_prior_write_csv(
      report$richness_pmf,
      file.path(directory, paste0(stub, "-richness-pmf.csv"))
    )
    .goal002_prior_write_csv(
      report$quantiles,
      file.path(directory, paste0(stub, "-quantiles.csv"))
    )
    .goal002_prior_write_csv(
      report$boundary_frequencies,
      file.path(directory, paste0(
        stub,
        "-boundary-frequencies.csv"
      ))
    )
    .goal002_prior_write_csv(
      report$saturation_frequencies,
      file.path(directory, paste0(
        stub,
        "-saturation-frequencies.csv"
      ))
    )

    all_assessments[[profile_key]] <- dplyr::mutate(
      report$assessment,
      profile_key = profile_key,
      profile_id = report$profile_id,
      .before = 1L
    )
    failed_rules <- report$assessment$rule_id[
      !report$assessment$passed
    ]
    all_manifests[[profile_key]] <- tibble::tibble(
      schema_version = report$schema_version,
      profile_key = profile_key,
      profile_id = report$profile_id,
      profile_hash = report$profile_hash,
      effort_seed = report$effort_seed,
      effort_hash = report$effort_hash,
      simulation_seed = report$simulation_seed,
      n_draws = report$n_draws,
      automatic_outcome = report$automatic_outcome,
      failed_rules = paste(failed_rules, collapse = ";")
    )

    rm(draws, assessment, report)
    invisible(gc(verbose = FALSE))
    if (!is.null(profile_completed)) {
      profile_completed(profile_key = profile_key)
    }
  }

  assessment_table <- dplyr::bind_rows(all_assessments)
  manifest <- dplyr::bind_rows(all_manifests)
  .goal002_prior_write_csv(
    assessment_table,
    file.path(directory, "automatic-assessment.csv")
  )
  .goal002_prior_write_csv(
    manifest,
    file.path(directory, "run-manifest.csv")
  )
  file_inventory <- .goal002_prior_file_inventory(directory)
  index <- list(
    schema_version = .goal002_prior_schema_version,
    rules = rules,
    effort_hash = effort$effort_hash,
    effort_seed = effort_seed,
    prior_seed = prior_seed,
    n_draws = n_draws,
    profile_keys = names(profiles),
    manifest = manifest,
    assessment = assessment_table,
    file_inventory = file_inventory
  )
  saveRDS(
    index,
    file.path(directory, "prior-check-index.rds"),
    version = 3L
  )

  list(index = index, effort = effort)
}

.goal002_prior_read_manifest <- function(path) {
  utils::read.csv(
    path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = "__GOAL002_NO_NA__",
    colClasses = c(
      "character",
      "character",
      "character",
      "character",
      "integer",
      "character",
      "integer",
      "integer",
      "character",
      "character"
    )
  )
}

.goal002_prior_read_assessment <- function(path) {
  utils::read.csv(
    path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = "__GOAL002_NO_NA__",
    colClasses = c(
      "character",
      "character",
      "character",
      "numeric",
      "numeric",
      "character",
      "logical",
      "character"
    )
  )
}

validate_goal002_prior_output <- function(output_dir) {
  valid_path <- is.character(output_dir) &&
    length(output_dir) == 1L &&
    !is.na(output_dir) &&
    dir.exists(output_dir)
  if (!valid_path) {
    .stop_invalid_goal002_prior(
      "output_dir must identify a complete prior evidence directory."
    )
  }
  actual_inventory <- sort(list.files(
    output_dir,
    recursive = TRUE,
    all.files = TRUE,
    no.. = TRUE
  ))
  expected_inventory <- .goal002_prior_expected_inventory()
  if (!identical(actual_inventory, expected_inventory)) {
    .stop_invalid_goal002_prior(
      "Prior evidence does not have the exact expected file inventory."
    )
  }

  index <- readRDS(file.path(output_dir, "prior-check-index.rds"))
  expected_index_fields <- c(
    "schema_version",
    "rules",
    "effort_hash",
    "effort_seed",
    "prior_seed",
    "n_draws",
    "profile_keys",
    "manifest",
    "assessment",
    "file_inventory"
  )
  if (!is.list(index) ||
      !identical(names(index), expected_index_fields) ||
      !identical(index$schema_version, .goal002_prior_schema_version) ||
      !identical(index$rules, goal002_prior_rules()) ||
      !.goal002_valid_hash(index$effort_hash)) {
    .stop_invalid_goal002_prior(
      "Prior evidence aggregate index has an invalid contract."
    )
  }
  runner <- .goal002_validate_prior_runner_inputs(
    output_dir = output_dir,
    effort_seed = index$effort_seed,
    prior_seed = index$prior_seed,
    n_draws = index$n_draws,
    profile_completed = NULL
  )
  profiles <- goal002_prior_profiles()
  if (!identical(index$profile_keys, names(profiles))) {
    .stop_invalid_goal002_prior(
      "Prior evidence aggregate index has invalid profile keys."
    )
  }
  expected_effort <- goal002_prior_effort(runner$effort_seed)
  if (!identical(index$effort_hash, expected_effort$effort_hash)) {
    .stop_invalid_goal002_prior(
      "Prior evidence aggregate index has invalid effort provenance."
    )
  }

  expected_manifest_fields <- c(
    "schema_version",
    "profile_key",
    "profile_id",
    "profile_hash",
    "effort_seed",
    "effort_hash",
    "simulation_seed",
    "n_draws",
    "automatic_outcome",
    "failed_rules"
  )
  expected_assessment_fields <- c(
    "profile_key",
    "profile_id",
    "rule_id",
    "statistic",
    "threshold",
    "comparison",
    "passed",
    "automatic_outcome"
  )
  if (!tibble::is_tibble(index$manifest) ||
      !identical(names(index$manifest), expected_manifest_fields) ||
      nrow(index$manifest) != length(profiles) ||
      !tibble::is_tibble(index$assessment) ||
      !identical(names(index$assessment), expected_assessment_fields) ||
      nrow(index$assessment) != 7L * length(profiles)) {
    .stop_invalid_goal002_prior(
      "Prior evidence aggregate tables have an invalid contract."
    )
  }
  manifest_csv <- .goal002_prior_read_manifest(
    file.path(output_dir, "run-manifest.csv")
  )
  assessment_csv <- .goal002_prior_read_assessment(
    file.path(output_dir, "automatic-assessment.csv")
  )
  manifest_matches <- isTRUE(all.equal(
    as.data.frame(index$manifest),
    manifest_csv,
    tolerance = 1e-15,
    check.attributes = TRUE
  ))
  assessment_matches <- isTRUE(all.equal(
    as.data.frame(index$assessment),
    assessment_csv,
    tolerance = 1e-15,
    check.attributes = TRUE
  ))
  if (!manifest_matches || !assessment_matches) {
    .stop_invalid_goal002_prior(
      "Prior evidence aggregate CSVs do not match the index."
    )
  }

  expected_file_inventory <- .goal002_prior_file_inventory(output_dir)
  if (!identical(index$file_inventory, expected_file_inventory)) {
    .stop_invalid_goal002_prior(
      "Prior evidence file hashes do not match the aggregate index."
    )
  }

  stubs <- .goal002_prior_profile_stubs()
  for (profile_key in names(profiles)) {
    row <- index$manifest[
      index$manifest$profile_key == profile_key,
      ,
      drop = FALSE
    ]
    expected_profile <- profiles[[profile_key]]
    expected_hash <- .goal002_profile_hash(expected_profile)
    expected_seed <- unname(runner$prior_seed[[profile_key]])
    valid_row <- nrow(row) == 1L &&
      identical(row$schema_version[[1L]], .goal002_prior_schema_version) &&
      identical(row$profile_id[[1L]], expected_profile$profile_id) &&
      identical(row$profile_hash[[1L]], expected_hash) &&
      identical(row$effort_seed[[1L]], runner$effort_seed) &&
      identical(row$effort_hash[[1L]], expected_effort$effort_hash) &&
      identical(row$simulation_seed[[1L]], expected_seed) &&
      identical(row$n_draws[[1L]], runner$n_draws) &&
      row$automatic_outcome[[1L]] %in% c(
        "not_rejected_automatically",
        "rejected_automatically"
      )
    if (!valid_row) {
      .stop_invalid_goal002_prior(
        "Prior evidence manifest provenance is invalid."
      )
    }

    report <- readRDS(file.path(
      output_dir,
      paste0(unname(stubs[[profile_key]]), "-report.rds")
    ))
    report_rules <- index$assessment[
      index$assessment$profile_key == profile_key,
      setdiff(names(index$assessment), c("profile_key", "profile_id")),
      drop = FALSE
    ]
    report_valid <- is.list(report) &&
      identical(report$profile, expected_profile) &&
      identical(report$profile_hash, expected_hash) &&
      identical(report$effort_hash, expected_effort$effort_hash) &&
      identical(report$effort_seed, runner$effort_seed) &&
      identical(report$simulation_seed, expected_seed) &&
      identical(report$n_draws, runner$n_draws) &&
      identical(report$automatic_outcome, row$automatic_outcome[[1L]]) &&
      identical(report$assessment, report_rules) &&
      identical(
        report$richness_pmf,
        lower_bound_prior_pmf(
          candidate_pool_size = goal002_prior_rules()$candidate_pool_size,
          observed_richness = 0L,
          omega_alpha = expected_profile$omega_alpha,
          omega_beta = expected_profile$omega_beta
        )
      )
    if (!report_valid) {
      .stop_invalid_goal002_prior(
        "Prior evidence report does not match aggregate provenance."
      )
    }
  }
  TRUE
}

.goal002_prior_directory_signature <- function(path) {
  relative <- .goal002_prior_expected_inventory()
  stats::setNames(vapply(relative, function(file) {
    digest::digest(
      file = file.path(path, file),
      algo = "sha256",
      serialize = FALSE
    )
  }, character(1)), relative)
}

.goal002_publish_prior_evidence <- function(staging, output_dir) {
  parent <- dirname(output_dir)
  base <- basename(output_dir)
  existing_link <- .goal002_prior_readlink(output_dir)
  existing_entry <- file.exists(output_dir) ||
    dir.exists(output_dir) ||
    nzchar(existing_link)
  if (existing_entry && !nzchar(existing_link)) {
    .stop_invalid_goal002_prior(paste0(
      "Existing output_dir is a real directory, not an atomic evidence ",
      "symlink; it was left unchanged."
    ))
  }
  if (nzchar(existing_link)) {
    if (!dir.exists(output_dir)) {
      .stop_invalid_goal002_prior(
        "Existing prior evidence symlink is broken."
      )
    }
    resolved_existing <- normalizePath(output_dir, mustWork = TRUE)
    valid_existing_target <- identical(dirname(resolved_existing), parent) &&
      startsWith(
        basename(resolved_existing),
        paste0(".", base, "-version-")
      )
    if (!valid_existing_target) {
      .stop_invalid_goal002_prior(
        "Existing prior evidence symlink target is outside its contract."
      )
    }
    validate_goal002_prior_output(output_dir)
  }

  index_hash <- digest::digest(
    file = file.path(staging, "prior-check-index.rds"),
    algo = "sha256",
    serialize = FALSE
  )
  version_dir <- file.path(
    parent,
    paste0(".", base, "-version-", index_hash)
  )
  created_version <- FALSE
  if (dir.exists(version_dir)) {
    validate_goal002_prior_output(version_dir)
    if (!identical(
      .goal002_prior_directory_signature(staging),
      .goal002_prior_directory_signature(version_dir)
    )) {
      .stop_invalid_goal002_prior(
        "Prior evidence version hash collision has inconsistent content."
      )
    }
    unlink(staging, recursive = TRUE, force = TRUE)
  } else {
    if (!file.rename(staging, version_dir)) {
      .stop_invalid_goal002_prior(
        "Could not move validated prior evidence into its version directory."
      )
    }
    created_version <- TRUE
    tryCatch(
      validate_goal002_prior_output(version_dir),
      error = function(error) {
        unlink(version_dir, recursive = TRUE, force = TRUE)
        stop(error)
      }
    )
  }

  temporary_link <- tempfile(
    pattern = paste0(".", base, "-link-"),
    tmpdir = parent
  )
  on.exit(unlink(temporary_link, force = TRUE), add = TRUE)
  if (!file.symlink(basename(version_dir), temporary_link)) {
    if (created_version) {
      unlink(version_dir, recursive = TRUE, force = TRUE)
    }
    .stop_invalid_goal002_prior(
      "Could not create the atomic prior evidence pointer."
    )
  }
  if (!file.rename(temporary_link, output_dir)) {
    if (created_version) {
      unlink(version_dir, recursive = TRUE, force = TRUE)
    }
    .stop_invalid_goal002_prior(
      "Could not atomically publish the prior evidence pointer."
    )
  }

  if (nzchar(existing_link)) {
    old_target <- normalizePath(
      file.path(parent, existing_link),
      mustWork = FALSE
    )
    new_target <- normalizePath(version_dir, mustWork = TRUE)
    if (!identical(old_target, new_target) &&
        identical(dirname(old_target), parent) &&
        startsWith(
          basename(old_target),
          paste0(".", base, "-version-")
        )) {
      unlink(old_target, recursive = TRUE, force = TRUE)
    }
  }

  list(
    output_dir = output_dir,
    publication_target = .goal002_prior_readlink(output_dir),
    index_hash = index_hash
  )
}

run_goal002_prior_checks <- function(
  output_dir,
  effort_seed,
  prior_seed,
  n_draws = goal002_prior_rules()$n_draws,
  profile_completed = NULL,
  verbose = FALSE
) {
  inputs <- .goal002_validate_prior_runner_inputs(
    output_dir,
    effort_seed,
    prior_seed,
    n_draws,
    profile_completed
  )
  output_dir <- inputs$output_dir
  parent <- dirname(output_dir)
  base <- basename(output_dir)
  existing_link <- .goal002_prior_readlink(output_dir)
  existing_entry <- file.exists(output_dir) ||
    dir.exists(output_dir) ||
    nzchar(existing_link)
  if (existing_entry && !nzchar(existing_link)) {
    .stop_invalid_goal002_prior(paste0(
      "Existing output_dir is a real directory, not an atomic evidence ",
      "symlink; it was left unchanged."
    ))
  }

  staging <- tempfile(
    pattern = paste0(".", base, "-staging-"),
    tmpdir = parent
  )
  if (!dir.create(staging, recursive = FALSE, showWarnings = FALSE)) {
    .stop_invalid_goal002_prior(
      "Could not create a fresh prior evidence staging directory."
    )
  }
  on.exit({
    if (nzchar(staging) && dir.exists(staging)) {
      unlink(staging, recursive = TRUE, force = TRUE)
    }
  }, add = TRUE)

  generated <- .goal002_write_prior_evidence(
    directory = staging,
    effort_seed = inputs$effort_seed,
    prior_seed = inputs$prior_seed,
    n_draws = inputs$n_draws,
    profile_completed = inputs$profile_completed,
    verbose = isTRUE(verbose)
  )
  validate_goal002_prior_output(staging)
  publication <- .goal002_publish_prior_evidence(staging, output_dir)
  staging <- ""

  index <- generated$index
  list(
    output_dir = publication$output_dir,
    publication_target = publication$publication_target,
    index_hash = publication$index_hash,
    manifest = index$manifest,
    assessment = index$assessment,
    automatic_rejected = any(
      index$manifest$automatic_outcome == "rejected_automatically"
    )
  )
}
