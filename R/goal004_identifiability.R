.goal004_stop <- function(message) {
  stop(message, call. = FALSE)
}

.goal004_log_sum_exp <- function(x) {
  maximum <- max(x)
  if (!is.finite(maximum)) {
    return(maximum)
  }
  maximum + log(sum(exp(x - maximum)))
}

.goal004_trapezoid_weights <- function(x) {
  if (!is.numeric(x) || length(x) < 2L || anyNA(x) ||
      any(!is.finite(x)) || is.unsorted(x, strictly = TRUE)) {
    .goal004_stop("Quadrature points must be finite and strictly increasing.")
  }
  intervals <- diff(x)
  if (!isTRUE(all.equal(
    intervals,
    rep(intervals[[1L]], length(intervals)),
    tolerance = 1e-12
  ))) {
    .goal004_stop("Quadrature points must be equally spaced.")
  }
  weights <- rep(intervals[[1L]], length(x))
  weights[c(1L, length(weights))] <- weights[c(1L, length(weights))] / 2
  weights
}

.goal004_normalize_log_weights <- function(log_weights) {
  normalizer <- .goal004_log_sum_exp(log_weights)
  if (!is.finite(normalizer)) {
    .goal004_stop("The numerical grid has no finite probability mass.")
  }
  weights <- exp(log_weights - normalizer)
  weights / sum(weights)
}

.goal004_weighted_quantile <- function(x, weights, probabilities) {
  cumulative <- cumsum(weights / sum(weights))
  vapply(probabilities, function(probability) {
    index <- which(cumulative >= probability)[[1L]]
    x[[index]]
  }, numeric(1))
}

.goal004_crps <- function(x, weights, truth) {
  weights <- weights / sum(weights)
  before_weight <- cumsum(weights) - weights
  before_value <- cumsum(weights * x) - weights * x
  first_term <- sum(weights * abs(x - truth))
  half_pairwise <- sum(weights * (x * before_weight - before_value))
  first_term - half_pairwise
}

.goal004_js_divergence <- function(first, second) {
  first <- first / sum(first)
  second <- second / sum(second)
  middle <- (first + second) / 2
  contribution <- function(value, reference) {
    keep <- value > 0
    sum(value[keep] * log(value[keep] / reference[keep]))
  }
  0.5 * contribution(first, middle) +
    0.5 * contribution(second, middle)
}

#' Goal004 Task 1 encounter-rate prior profiles
goal004_task1_rate_priors <- function() {
  list(
    goal003_wide = list(
      location = log(0.02),
      scale = 1.5
    ),
    centred_broad = list(
      location = log(0.002),
      scale = 1
    ),
    centred_moderate = list(
      location = log(0.002),
      scale = 0.5
    )
  )
}

#' Fixed numerical grids for the Goal004 Task 1 screen
goal004_task1_grid <- function(candidate_count) {
  if (length(candidate_count) != 1L || is.na(candidate_count) ||
      candidate_count < 1L || candidate_count != as.integer(candidate_count)) {
    .goal004_stop("candidate_count must be one positive whole number.")
  }
  list(
    membership = seq(0, as.integer(candidate_count), by = 0.25),
    log_rate = seq(log(1e-5), log(0.1), length.out = 241L)
  )
}

.goal004_log_membership_prior <- function(
  membership,
  candidate_count,
  prior = c("uniform", "truncated_exponential"),
  scale = NULL
) {
  prior <- match.arg(prior)
  inside <- membership >= 0 & membership <= candidate_count
  density <- rep(-Inf, length(membership))
  if (identical(prior, "uniform")) {
    density[inside] <- -log(candidate_count)
    return(density)
  }
  if (is.null(scale) || length(scale) != 1L || !is.finite(scale) ||
      scale <= 0) {
    .goal004_stop("scale must be positive for the exponential prior.")
  }
  log_normalizer <- log1p(-exp(-candidate_count / scale))
  density[inside] <- -log(scale) - membership[inside] / scale -
    log_normalizer
  density
}

.goal004_log_rate_prior <- function(log_rate, prior_id) {
  specification <- goal004_task1_rate_priors()[[prior_id]]
  if (is.null(specification)) {
    .goal004_stop("Unknown Goal004 Task 1 encounter-rate prior.")
  }
  stats::dnorm(
    log_rate,
    mean = specification$location,
    sd = specification$scale,
    log = TRUE
  )
}

#' Expected candidate-history log likelihood
#'
#' This is the expected log likelihood described in the frozen Goal004 Task 1
#' design. It is evaluated over expected membership and log encounter-rate
#' grids using exact positive-effort camera-week cells.
goal004_task1_expected_log_likelihood <- function(
  membership,
  log_rate,
  candidate_count,
  truth_membership,
  truth_rate,
  effort
) {
  valid <- is.numeric(membership) && length(membership) > 0L &&
    !anyNA(membership) && all(is.finite(membership)) &&
    all(membership >= 0 & membership <= candidate_count) &&
    is.numeric(log_rate) && length(log_rate) > 0L &&
    !anyNA(log_rate) && all(is.finite(log_rate)) &&
    length(candidate_count) == 1L && is.finite(candidate_count) &&
    candidate_count >= 1 && candidate_count == trunc(candidate_count) &&
    length(truth_membership) == 1L && is.finite(truth_membership) &&
    truth_membership >= 0 && truth_membership <= candidate_count &&
    length(truth_rate) == 1L && is.finite(truth_rate) && truth_rate > 0 &&
    is.numeric(effort) && length(effort) > 0L && !anyNA(effort) &&
    all(is.finite(effort)) && all(effort >= 0)
  if (!valid) {
    .goal004_stop("Invalid expected-likelihood inputs.")
  }

  effort <- effort[effort > 0]
  if (length(effort) == 0L) {
    .goal004_stop("At least one positive-effort cell is required.")
  }
  rate <- exp(log_rate)
  truth_probability <- -expm1(-effort * truth_rate)
  truth_detected <- truth_membership *
    -expm1(-sum(effort) * truth_rate)
  truth_cell_detections <- truth_membership * truth_probability

  hazard <- outer(effort, rate)
  log_probability <- log(-expm1(-hazard))
  log_non_detection <- -hazard
  history_term <- colSums(
    truth_cell_detections * log_probability +
      (truth_detected - truth_cell_detections) * log_non_detection
  )
  cumulative_detection <- -expm1(-sum(effort) * rate)
  membership_probability <- membership / candidate_count

  if (truth_detected == 0) {
    positive_term <- rep(0, length(membership))
  } else {
    positive_term <- rep(-Inf, length(membership))
    positive <- membership_probability > 0
    positive_term[positive] <-
      truth_detected * log(membership_probability[positive])
  }

  likelihood <- outer(positive_term, rep(1, length(log_rate))) +
    outer(rep(1, length(membership)), history_term) +
    (candidate_count - truth_detected) *
      log1p(-outer(membership_probability, cumulative_detection))

  attr(likelihood, "expected_detected") <- truth_detected
  likelihood
}

.goal004_profile_diagnostics <- function(
  likelihood,
  membership,
  log_rate
) {
  profile_membership <- apply(likelihood, 1L, max)
  profile_rate <- apply(likelihood, 2L, max)
  maximum <- max(likelihood)
  membership_support <- membership[profile_membership >= maximum - 2]
  rate_support <- exp(log_rate[profile_rate >= maximum - 2])
  list(
    membership_low = min(membership_support),
    membership_high = max(membership_support),
    membership_span = diff(range(membership_support)),
    rate_low = min(rate_support),
    rate_high = max(rate_support),
    rate_ratio = max(rate_support) / min(rate_support),
    boundary_maximum = any(which(likelihood == maximum, arr.ind = TRUE)[, 1L] %in%
      c(1L, length(membership))) ||
      any(which(likelihood == maximum, arr.ind = TRUE)[, 2L] %in%
        c(1L, length(log_rate)))
  )
}

#' Evaluate one exchangeable Goal004 Task 1 surface
goal004_task1_exchangeable_surface <- function(
  candidate_count,
  truth_membership,
  truth_rate,
  effort,
  rate_prior_id
) {
  grid <- goal004_task1_grid(candidate_count)
  membership <- grid$membership
  log_rate <- grid$log_rate
  likelihood <- goal004_task1_expected_log_likelihood(
    membership,
    log_rate,
    candidate_count,
    truth_membership,
    truth_rate,
    effort
  )
  membership_weights <- .goal004_trapezoid_weights(membership)
  rate_weights <- .goal004_trapezoid_weights(log_rate)
  log_membership_prior <- .goal004_log_membership_prior(
    membership,
    candidate_count,
    "uniform"
  )
  log_rate_prior <- .goal004_log_rate_prior(log_rate, rate_prior_id)
  prior_membership <- .goal004_normalize_log_weights(
    log_membership_prior + log(membership_weights)
  )
  log_posterior <- likelihood +
    outer(log_membership_prior + log(membership_weights),
          rep(1, length(log_rate))) +
    outer(rep(1, length(membership)),
          log_rate_prior + log(rate_weights))
  posterior <- .goal004_normalize_log_weights(log_posterior)
  marginal_membership <- rowSums(posterior)
  marginal_rate <- colSums(posterior)
  membership_mean <- sum(membership * marginal_membership)
  log_rate_mean <- sum(log_rate * marginal_rate)
  membership_sd <- sqrt(sum(
    marginal_membership * (membership - membership_mean)^2
  ))
  log_rate_sd <- sqrt(sum(marginal_rate * (log_rate - log_rate_mean)^2))
  covariance <- sum(
    posterior * outer(
      membership - membership_mean,
      log_rate - log_rate_mean
    )
  )
  correlation <- if (membership_sd > 0 && log_rate_sd > 0) {
    covariance / (membership_sd * log_rate_sd)
  } else {
    NA_real_
  }
  quantiles <- .goal004_weighted_quantile(
    membership,
    marginal_membership,
    c(0.05, 0.5, 0.95)
  )
  prior_mean <- sum(membership * prior_membership)
  prior_sd <- sqrt(sum(prior_membership * (membership - prior_mean)^2))
  prior_crps <- .goal004_crps(
    membership,
    prior_membership,
    truth_membership
  )
  posterior_crps <- .goal004_crps(
    membership,
    marginal_membership,
    truth_membership
  )
  profile <- .goal004_profile_diagnostics(
    likelihood,
    membership,
    log_rate
  )

  summary <- tibble::tibble(
    model = "exchangeable",
    candidate_count = as.integer(candidate_count),
    core_count = as.integer(candidate_count),
    fringe_count = 0L,
    fringe_prior_scale = NA_real_,
    fringe_rate_multiplier = NA_real_,
    truth_membership = truth_membership,
    truth_rate = truth_rate,
    expected_detected = attr(likelihood, "expected_detected"),
    rate_prior_id = rate_prior_id,
    prior_membership_mean = prior_mean,
    prior_membership_sd = prior_sd,
    posterior_membership_mean = membership_mean,
    posterior_membership_sd = membership_sd,
    posterior_membership_q05 = quantiles[[1L]],
    posterior_membership_median = quantiles[[2L]],
    posterior_membership_q95 = quantiles[[3L]],
    posterior_geometric_rate = exp(log_rate_mean),
    posterior_log_rate_sd = log_rate_sd,
    posterior_membership_log_rate_correlation = correlation,
    membership_js_divergence = .goal004_js_divergence(
      prior_membership,
      marginal_membership
    ),
    prior_membership_crps = prior_crps,
    posterior_membership_crps = posterior_crps,
    crps_improvement = (prior_crps - posterior_crps) / prior_crps,
    profile_membership_low = profile$membership_low,
    profile_membership_high = profile$membership_high,
    profile_membership_span = profile$membership_span,
    profile_rate_low = profile$rate_low,
    profile_rate_high = profile$rate_high,
    profile_rate_ratio = profile$rate_ratio,
    likelihood_boundary_maximum = profile$boundary_maximum,
    posterior_core_mean = membership_mean,
    posterior_fringe_mean = 0,
    posterior_total_mean = membership_mean,
    posterior_total_sd = membership_sd,
    prior_fringe_mean = 0,
    fringe_mean_reduction = NA_real_,
    fringe_crps_improvement = NA_real_
  )

  list(
    summary = summary,
    membership = membership,
    log_rate = log_rate,
    relative_log_likelihood = likelihood - max(likelihood),
    marginal_membership = marginal_membership,
    marginal_rate = marginal_rate
  )
}

#' Evaluate one core-fringe Goal004 Task 1 surface
goal004_task1_stratified_surface <- function(
  truth_membership,
  truth_rate,
  effort,
  rate_prior_id,
  fringe_prior_scale,
  fringe_rate_multiplier,
  core_count = 50L,
  fringe_count = 56L
) {
  if (length(fringe_rate_multiplier) != 1L ||
      !is.finite(fringe_rate_multiplier) || fringe_rate_multiplier <= 0) {
    .goal004_stop("fringe_rate_multiplier must be positive.")
  }
  core_grid <- goal004_task1_grid(core_count)
  fringe_grid <- goal004_task1_grid(fringe_count)
  if (!identical(core_grid$log_rate, fringe_grid$log_rate)) {
    .goal004_stop("Core and fringe rate grids differ.")
  }
  log_rate <- core_grid$log_rate
  core_membership <- core_grid$membership
  fringe_membership <- fringe_grid$membership
  core_likelihood <- goal004_task1_expected_log_likelihood(
    core_membership,
    log_rate,
    core_count,
    truth_membership,
    truth_rate,
    effort
  )
  fringe_likelihood <- goal004_task1_expected_log_likelihood(
    fringe_membership,
    log_rate + log(fringe_rate_multiplier),
    fringe_count,
    0,
    truth_rate * fringe_rate_multiplier,
    effort
  )

  core_weights <- .goal004_trapezoid_weights(core_membership)
  fringe_weights <- .goal004_trapezoid_weights(fringe_membership)
  rate_weights <- .goal004_trapezoid_weights(log_rate)
  core_log_prior <- .goal004_log_membership_prior(
    core_membership,
    core_count,
    "uniform"
  )
  fringe_log_prior <- .goal004_log_membership_prior(
    fringe_membership,
    fringe_count,
    "truncated_exponential",
    fringe_prior_scale
  )
  rate_log_prior <- .goal004_log_rate_prior(log_rate, rate_prior_id)
  core_prior <- .goal004_normalize_log_weights(
    core_log_prior + log(core_weights)
  )
  fringe_prior <- .goal004_normalize_log_weights(
    fringe_log_prior + log(fringe_weights)
  )

  core_log_mass <- core_likelihood +
    outer(core_log_prior + log(core_weights), rep(1, length(log_rate)))
  fringe_log_mass <- fringe_likelihood +
    outer(fringe_log_prior + log(fringe_weights), rep(1, length(log_rate)))
  core_log_normalizer <- apply(core_log_mass, 2L, .goal004_log_sum_exp)
  fringe_log_normalizer <- apply(fringe_log_mass, 2L, .goal004_log_sum_exp)
  rate_marginal <- .goal004_normalize_log_weights(
    rate_log_prior + log(rate_weights) + core_log_normalizer +
      fringe_log_normalizer
  )
  core_conditional <- exp(sweep(
    core_log_mass,
    2L,
    core_log_normalizer,
    FUN = "-"
  ))
  fringe_conditional <- exp(sweep(
    fringe_log_mass,
    2L,
    fringe_log_normalizer,
    FUN = "-"
  ))
  core_marginal <- as.vector(core_conditional %*% rate_marginal)
  fringe_marginal <- as.vector(fringe_conditional %*% rate_marginal)
  core_marginal <- core_marginal / sum(core_marginal)
  fringe_marginal <- fringe_marginal / sum(fringe_marginal)

  conditional_core_mean <- colSums(core_conditional * core_membership)
  conditional_fringe_mean <- colSums(
    fringe_conditional * fringe_membership
  )
  conditional_core_second <- colSums(
    core_conditional * core_membership^2
  )
  conditional_fringe_second <- colSums(
    fringe_conditional * fringe_membership^2
  )
  core_mean <- sum(core_membership * core_marginal)
  fringe_mean <- sum(fringe_membership * fringe_marginal)
  total_mean <- core_mean + fringe_mean
  total_second <- sum(rate_marginal * (
    conditional_core_second + conditional_fringe_second +
      2 * conditional_core_mean * conditional_fringe_mean
  ))
  total_sd <- sqrt(max(0, total_second - total_mean^2))
  core_sd <- sqrt(sum(core_marginal * (core_membership - core_mean)^2))
  log_rate_mean <- sum(log_rate * rate_marginal)
  log_rate_sd <- sqrt(sum(
    rate_marginal * (log_rate - log_rate_mean)^2
  ))
  core_rate_covariance <- sum(
    rate_marginal * conditional_core_mean * log_rate
  ) - core_mean * log_rate_mean
  core_rate_correlation <- if (core_sd > 0 && log_rate_sd > 0) {
    core_rate_covariance / (core_sd * log_rate_sd)
  } else {
    NA_real_
  }
  core_quantiles <- .goal004_weighted_quantile(
    core_membership,
    core_marginal,
    c(0.05, 0.5, 0.95)
  )
  core_prior_mean <- sum(core_membership * core_prior)
  core_prior_sd <- sqrt(sum(
    core_prior * (core_membership - core_prior_mean)^2
  ))
  fringe_prior_mean <- sum(fringe_membership * fringe_prior)
  core_prior_crps <- .goal004_crps(
    core_membership,
    core_prior,
    truth_membership
  )
  core_posterior_crps <- .goal004_crps(
    core_membership,
    core_marginal,
    truth_membership
  )
  fringe_prior_crps <- .goal004_crps(fringe_membership, fringe_prior, 0)
  fringe_posterior_crps <- .goal004_crps(
    fringe_membership,
    fringe_marginal,
    0
  )
  profile <- .goal004_profile_diagnostics(
    core_likelihood,
    core_membership,
    log_rate
  )

  summary <- tibble::tibble(
    model = "core_fringe",
    candidate_count = as.integer(core_count + fringe_count),
    core_count = as.integer(core_count),
    fringe_count = as.integer(fringe_count),
    fringe_prior_scale = fringe_prior_scale,
    fringe_rate_multiplier = fringe_rate_multiplier,
    truth_membership = truth_membership,
    truth_rate = truth_rate,
    expected_detected = attr(core_likelihood, "expected_detected"),
    rate_prior_id = rate_prior_id,
    prior_membership_mean = core_prior_mean,
    prior_membership_sd = core_prior_sd,
    posterior_membership_mean = core_mean,
    posterior_membership_sd = core_sd,
    posterior_membership_q05 = core_quantiles[[1L]],
    posterior_membership_median = core_quantiles[[2L]],
    posterior_membership_q95 = core_quantiles[[3L]],
    posterior_geometric_rate = exp(log_rate_mean),
    posterior_log_rate_sd = log_rate_sd,
    posterior_membership_log_rate_correlation = core_rate_correlation,
    membership_js_divergence = .goal004_js_divergence(
      core_prior,
      core_marginal
    ),
    prior_membership_crps = core_prior_crps,
    posterior_membership_crps = core_posterior_crps,
    crps_improvement = (core_prior_crps - core_posterior_crps) /
      core_prior_crps,
    profile_membership_low = profile$membership_low,
    profile_membership_high = profile$membership_high,
    profile_membership_span = profile$membership_span,
    profile_rate_low = profile$rate_low,
    profile_rate_high = profile$rate_high,
    profile_rate_ratio = profile$rate_ratio,
    likelihood_boundary_maximum = profile$boundary_maximum,
    posterior_core_mean = core_mean,
    posterior_fringe_mean = fringe_mean,
    posterior_total_mean = total_mean,
    posterior_total_sd = total_sd,
    prior_fringe_mean = fringe_prior_mean,
    fringe_mean_reduction = 1 - fringe_mean / fringe_prior_mean,
    fringe_crps_improvement =
      (fringe_prior_crps - fringe_posterior_crps) / fringe_prior_crps
  )

  list(
    summary = summary,
    core_membership = core_membership,
    fringe_membership = fringe_membership,
    log_rate = log_rate,
    marginal_core = core_marginal,
    marginal_fringe = fringe_marginal,
    marginal_rate = rate_marginal
  )
}

#' Summarise all frozen Goal003 Task 4 effort windows for Goal004
goal004_task1_effort_windows <- function(manifest) {
  if (!is.list(manifest) ||
      !all(c("datasets", "effort") %in% names(manifest))) {
    .goal004_stop("manifest must contain frozen datasets and effort.")
  }
  windows <- manifest$datasets |>
    dplyr::distinct(
      train_occasions,
      replicate,
      effort_block_start
    ) |>
    dplyr::arrange(train_occasions, replicate)
  audit <- lapply(seq_len(nrow(windows)), function(index) {
    window <- windows[index, ]
    cells <- manifest$effort |>
      dplyr::filter(
        occasion_index >= window$effort_block_start,
        occasion_index < window$effort_block_start + window$train_occasions
      )
    tibble::tibble(
      train_occasions = window$train_occasions,
      replicate = window$replicate,
      effort_block_start = window$effort_block_start,
      total_cells = nrow(cells),
      sampled_cells = sum(cells$active_days > 0L),
      zero_effort_cells = sum(cells$active_days == 0L),
      active_camera_days = sum(cells$active_days)
    )
  }) |>
    dplyr::bind_rows()
  if (nrow(audit) != 60L ||
      !identical(sort(unique(audit$train_occasions)), c(4L, 26L))) {
    .goal004_stop("The frozen effort-window audit is incomplete.")
  }

  representatives <- lapply(c(4L, 26L), function(duration) {
    candidates <- audit |>
      dplyr::filter(train_occasions == duration) |>
      dplyr::arrange(
        active_camera_days,
        effort_block_start,
        replicate
      )
    minimum <- candidates[1L, ]
    median <- candidates[15L, ]
    maximum <- candidates |>
      dplyr::filter(active_camera_days == max(active_camera_days)) |>
      dplyr::arrange(effort_block_start, replicate) |>
      dplyr::slice(1L)
    dplyr::bind_rows(
      dplyr::mutate(minimum, effort_label = "minimum"),
      dplyr::mutate(median, effort_label = "lower_median"),
      dplyr::mutate(maximum, effort_label = "maximum")
    )
  }) |>
    dplyr::bind_rows() |>
    dplyr::select(effort_label, dplyr::everything())
  audit <- audit |>
    dplyr::left_join(
      representatives |>
        dplyr::select(
          train_occasions,
          replicate,
          effort_block_start,
          effort_label
        ),
      by = c("train_occasions", "replicate", "effort_block_start")
    ) |>
    dplyr::mutate(representative = !is.na(effort_label))
  list(audit = audit, representatives = representatives)
}

#' Attach primary-pool reference means and pool shifts
goal004_task1_add_pool_shifts <- function(
  summary,
  core_candidate_count = 50L
) {
  keys <- c(
    "train_occasions",
    "effort_label",
    "effort_replicate",
    "effort_block_start",
    "truth_membership",
    "rate_prior_id"
  )
  required <- c(
    keys,
    "model",
    "candidate_count",
    "posterior_membership_mean",
    "posterior_total_mean"
  )
  if (!inherits(summary, "data.frame") ||
      !all(required %in% names(summary))) {
    .goal004_stop("summary does not contain the pool-shift fields.")
  }
  reference <- summary |>
    dplyr::filter(
      model == "exchangeable",
      candidate_count == .env$core_candidate_count
    ) |>
    dplyr::select(
      dplyr::all_of(keys),
      core_reference_mean = posterior_membership_mean
    )
  if (nrow(reference) == 0L || anyDuplicated(reference[keys])) {
    .goal004_stop("Primary-pool reference rows are missing or duplicated.")
  }
  joined <- summary |>
    dplyr::left_join(reference, by = keys)
  if (nrow(joined) != nrow(summary) || anyNA(joined$core_reference_mean)) {
    .goal004_stop("Primary-pool reference matching was not one-to-one.")
  }
  joined |>
    dplyr::mutate(
      core_shift_vs_primary50 = dplyr::case_when(
        model == "exchangeable" &
          candidate_count == .env$core_candidate_count ~ 0,
        model == "core_fringe" ~
          posterior_membership_mean - core_reference_mean,
        TRUE ~ NA_real_
      ),
      total_shift_vs_primary50 =
        posterior_total_mean - core_reference_mean
    )
}

#' Apply the prespecified Goal004 Task 1 decision checkpoint
goal004_task1_decision <- function(summary) {
  required <- c(
    "model", "candidate_count", "fringe_prior_scale",
    "fringe_rate_multiplier", "truth_membership", "rate_prior_id",
    "train_occasions", "effort_label", "posterior_membership_mean",
    "posterior_total_mean", "crps_improvement", "fringe_mean_reduction",
    "core_shift_vs_primary50", "total_shift_vs_primary50"
  )
  if (!inherits(summary, "data.frame") ||
      !all(required %in% names(summary))) {
    .goal004_stop("summary does not contain the Task 1 decision fields.")
  }
  checkpoint <- summary |>
    dplyr::filter(
      train_occasions == 4L,
      effort_label == "lower_median",
      rate_prior_id == "centred_broad"
    )
  core <- checkpoint |>
    dplyr::filter(model == "exchangeable", candidate_count == 50L) |>
    dplyr::arrange(truth_membership)
  if (!identical(core$truth_membership, c(10, 25, 40))) {
    .goal004_stop("The three core checkpoint rows are missing.")
  }
  separation <- core$posterior_membership_mean[[3L]] -
    core$posterior_membership_mean[[1L]]
  mean_gain <- mean(core$crps_improvement)
  minimum_gain <- min(core$crps_improvement)

  broad <- checkpoint |>
    dplyr::filter(
      model == "core_fringe",
      fringe_prior_scale == 5,
      fringe_rate_multiplier == 0.1
    ) |>
    dplyr::arrange(truth_membership)
  if (!identical(broad$truth_membership, c(10, 25, 40))) {
    .goal004_stop("The three broad-pool checkpoint rows are missing.")
  }
  maximum_core_shift <- max(abs(broad$core_shift_vs_primary50))
  maximum_total_shift <- max(abs(broad$total_shift_vs_primary50))
  minimum_fringe_reduction <- min(broad$fringe_mean_reduction)

  metrics <- tibble::tibble(
    checkpoint = c(rep("core", 3L), rep("broad_pool", 3L)),
    metric = c(
      "high_low_posterior_mean_separation",
      "mean_crps_improvement",
      "minimum_crps_improvement",
      "maximum_absolute_core_shift",
      "maximum_absolute_total_shift",
      "minimum_fringe_mean_reduction"
    ),
    observed = c(
      separation,
      mean_gain,
      minimum_gain,
      maximum_core_shift,
      maximum_total_shift,
      minimum_fringe_reduction
    ),
    comparison = c(">=", ">=", ">=", "<=", "<=", ">="),
    threshold = c(15, 0.20, 0, 2, 3, 0.25),
    pass = c(
      separation >= 15,
      mean_gain >= 0.20,
      minimum_gain >= 0,
      maximum_core_shift <= 2,
      maximum_total_shift <= 3,
      minimum_fringe_reduction >= 0.25
    )
  )
  core_pass <- all(metrics$pass[metrics$checkpoint == "core"])
  broad_pass <- all(metrics$pass[metrics$checkpoint == "broad_pool"])
  status <- if (core_pass && broad_pass) {
    "PROCEED"
  } else if (core_pass) {
    "CORE_ONLY"
  } else {
    "STOP"
  }
  list(status = status, metrics = metrics, broad_rows = broad)
}
