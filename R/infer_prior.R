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
