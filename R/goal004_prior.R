.goal004_task2_stop <- function(message) {
  stop(message, call. = FALSE)
}

.goal004_task2_profile_fields <- c(
  "profile_id",
  "profile_order",
  "role",
  "omega_alpha",
  "omega_beta",
  "routine_median_rate",
  "occasional_median_rate",
  "log_rate_sd",
  "class_blur_probability",
  "camera_sd_scale"
)

#' Frozen broader-pool sensitivity prior for the 56 fringe candidates
goal004_task2_fringe_prior <- function() {
  list(
    membership_expected_count_scale = 5,
    routine_median_rate = 0.002,
    rare_median_rate = 0.0002,
    log_rate_sd = 1
  )
}

#' Read and validate the frozen Goal004 Task 2 prior profiles
read_goal004_task2_profiles <- function(
  path = file.path(
    .goal003_project_root(),
    "config",
    "goal004_task2_priors.csv"
  )
) {
  if (!file.exists(path)) {
    .goal004_task2_stop("The Goal004 Task 2 prior profile file is missing.")
  }
  profiles <- tibble::as_tibble(utils::read.csv(
    path,
    stringsAsFactors = FALSE,
    check.names = FALSE
  ))
  expected_ids <- c(
    "primary",
    "rate_lower",
    "rate_higher",
    "spread_wider",
    "class_blur",
    "membership_regularised"
  )
  numeric_fields <- setdiff(
    .goal004_task2_profile_fields,
    c("profile_id", "role")
  )
  valid <- identical(names(profiles), .goal004_task2_profile_fields) &&
    nrow(profiles) == length(expected_ids) &&
    identical(profiles$profile_id, expected_ids) &&
    identical(profiles$profile_order, seq_along(expected_ids)) &&
    identical(profiles$role, c("primary", rep("sensitivity", 5L))) &&
    all(vapply(profiles[numeric_fields], is.numeric, logical(1))) &&
    !anyNA(profiles) &&
    all(is.finite(as.matrix(profiles[numeric_fields]))) &&
    all(profiles$omega_alpha > 0) &&
    all(profiles$omega_beta > 0) &&
    all(profiles$routine_median_rate > 0) &&
    all(profiles$occasional_median_rate > 0) &&
    all(profiles$log_rate_sd > 0) &&
    all(profiles$class_blur_probability >= 0) &&
    all(profiles$class_blur_probability <= 0.5) &&
    all(profiles$camera_sd_scale > 0)
  if (!valid) {
    .goal004_task2_stop("The Goal004 Task 2 prior profiles are invalid.")
  }
  profiles
}

#' Map the reviewed Goal003 candidate worksheet to Goal004 Task 2 strata
goal004_task2_candidate_mapping <- function(
  path = file.path(
    .goal003_project_root(),
    "config",
    "goal003_candidate_pool.csv"
  )
) {
  if (!file.exists(path)) {
    .goal004_task2_stop("The reviewed candidate worksheet is missing.")
  }
  candidates <- tibble::as_tibble(utils::read.csv(
    path,
    stringsAsFactors = FALSE,
    check.names = FALSE
  ))
  required <- c(
    "taxon_class",
    "scientific_name",
    "common_name",
    "jcr_gamma_pool",
    "camera_encounter_class",
    "primary_pool",
    "broader_pool"
  )
  if (!all(required %in% names(candidates)) ||
      anyNA(candidates[required]) ||
      anyDuplicated(candidates$scientific_name)) {
    .goal004_task2_stop("The reviewed candidate worksheet is invalid.")
  }
  select_mapping <- function(value, component) {
    value |>
      dplyr::transmute(
        candidate_id = scientific_name,
        common_name,
        taxon_class,
        encounter_class = camera_encounter_class,
        pool_component = component
      ) |>
      dplyr::arrange(candidate_id)
  }
  core <- candidates |>
    dplyr::filter(primary_pool == "include") |>
    select_mapping("core")
  fringe <- candidates |>
    dplyr::filter(
      broader_pool == "include",
      primary_pool != "include"
    ) |>
    select_mapping("fringe")
  valid <- nrow(core) == 50L &&
    nrow(fringe) == 56L &&
    !anyDuplicated(core$candidate_id) &&
    !anyDuplicated(fringe$candidate_id) &&
    length(intersect(core$candidate_id, fringe$candidate_id)) == 0L &&
    identical(
      as.integer(table(core$encounter_class)[c("routine", "occasional")]),
      c(44L, 6L)
    ) &&
    identical(
      as.integer(table(fringe$encounter_class)[c("routine", "rare")]),
      c(3L, 53L)
    ) &&
    all(candidates$jcr_gamma_pool[
      candidates$primary_pool == "include"
    ] == "include")
  if (!valid) {
    .goal004_task2_stop("The frozen Goal004 candidate mapping has changed.")
  }
  list(core = core, fringe = fringe)
}

#' Exact beta-binomial prior PMF for finite-pool richness
goal004_beta_binomial_pmf <- function(candidate_count, alpha, beta) {
  valid <- length(candidate_count) == 1L &&
    is.numeric(candidate_count) &&
    is.finite(candidate_count) &&
    candidate_count >= 1L &&
    candidate_count == trunc(candidate_count) &&
    length(alpha) == 1L && is.finite(alpha) && alpha > 0 &&
    length(beta) == 1L && is.finite(beta) && beta > 0
  if (!valid) {
    .goal004_task2_stop("Invalid beta-binomial prior parameters.")
  }
  richness <- 0:as.integer(candidate_count)
  log_probability <- lchoose(candidate_count, richness) +
    lbeta(richness + alpha, candidate_count - richness + beta) -
    lbeta(alpha, beta)
  probability <- exp(log_probability)
  probability <- probability / sum(probability)
  tibble::tibble(richness = richness, probability = probability)
}

.goal004_task2_truncated_exponential <- function(uniform, upper, scale) {
  if (!is.numeric(uniform) || anyNA(uniform) ||
      any(uniform < 0 | uniform > 1) ||
      length(upper) != 1L || !is.finite(upper) || upper <= 0 ||
      length(scale) != 1L || !is.finite(scale) || scale <= 0) {
    .goal004_task2_stop("Invalid truncated-exponential inputs.")
  }
  -scale * log1p(-uniform * (1 - exp(-upper / scale)))
}

.goal004_task2_distribution_summary <- function(values) {
  quantiles <- stats::quantile(
    values,
    probs = c(0.05, 0.5, 0.95),
    names = FALSE,
    type = 8
  )
  tibble::tibble(
    mean = mean(values),
    sd = stats::sd(values),
    q05 = quantiles[[1L]],
    median = quantiles[[2L]],
    q95 = quantiles[[3L]],
    minimum = min(values),
    maximum = max(values),
    mcse_mean = stats::sd(values) / sqrt(length(values))
  )
}

.goal004_task2_empirical_pmf <- function(values, upper) {
  counts <- tabulate(as.integer(values) + 1L, nbins = upper + 1L)
  tibble::tibble(
    value = 0:upper,
    probability = counts / length(values)
  )
}

#' Exact representative training and forecast effort for Goal004 Task 2
goal004_task2_effort_windows <- function(manifest) {
  representatives <- goal004_task1_effort_windows(manifest)$representatives |>
    dplyr::arrange(
      train_occasions,
      match(effort_label, c("minimum", "lower_median", "maximum"))
    )
  cells <- lapply(seq_len(nrow(representatives)), function(index) {
    window <- representatives[index, ]
    training_start <- window$effort_block_start
    future_start <- training_start + window$train_occasions
    by_camera <- manifest$effort |>
      dplyr::filter(
        occasion_index >= training_start,
        occasion_index < future_start + 4L
      ) |>
      dplyr::mutate(
        phase = dplyr::if_else(
          occasion_index < future_start,
          "training",
          "future"
        )
      ) |>
      dplyr::summarise(
        active_camera_days = sum(active_days),
        .by = c(camera_id, phase)
      ) |>
      tidyr::pivot_wider(
        names_from = phase,
        values_from = active_camera_days,
        values_fill = 0,
        names_prefix = "active_days_"
      ) |>
      dplyr::arrange(camera_id) |>
      dplyr::mutate(
        window_id = sprintf(
          "%02dw_%s",
          window$train_occasions,
          window$effort_label
        ),
        train_occasions = window$train_occasions,
        effort_label = window$effort_label,
        effort_replicate = window$replicate,
        effort_block_start = training_start,
        .before = 1L
      )
    if (nrow(by_camera) != 9L ||
        anyNA(by_camera[c(
          "active_days_training",
          "active_days_future"
        )])) {
      .goal004_task2_stop("A representative effort window is incomplete.")
    }
    by_camera
  }) |>
    dplyr::bind_rows()
  summary <- cells |>
    dplyr::summarise(
      training_active_camera_days = sum(active_days_training),
      future_active_camera_days = sum(active_days_future),
      .by = c(
        window_id,
        train_occasions,
        effort_label,
        effort_replicate,
        effort_block_start
      )
    )
  if (nrow(summary) != 6L || nrow(cells) != 54L ||
      !identical(
        summary$training_active_camera_days,
        c(28L, 224L, 252L, 790L, 1210L, 1570L)
      )) {
    .goal004_task2_stop("The Goal004 Task 2 effort windows have changed.")
  }
  list(summary = summary, cells = cells)
}

.goal004_task2_base_draws <- function(
  n_draws,
  max_candidates,
  n_cameras,
  seed
) {
  valid_integer <- function(x, lower) {
    is.numeric(x) && length(x) == 1L && is.finite(x) &&
      x == trunc(x) && x >= lower && x <= .Machine$integer.max
  }
  if (!valid_integer(n_draws, 1L) ||
      !valid_integer(max_candidates, 1L) ||
      !valid_integer(n_cameras, 2L) ||
      !valid_integer(seed, 0L)) {
    .goal004_task2_stop("Invalid Goal004 Task 2 simulation dimensions.")
  }
  set.seed(as.integer(seed))
  n_draws <- as.integer(n_draws)
  max_candidates <- as.integer(max_candidates)
  n_cameras <- as.integer(n_cameras)
  Q <- .sum_zero_basis(n_cameras)
  sigma_standard <- abs(stats::rnorm(n_draws))
  z_camera <- matrix(
    stats::rnorm(n_draws * (n_cameras - 1L)),
    nrow = n_draws
  )
  list(
    n_draws = n_draws,
    max_candidates = max_candidates,
    n_cameras = n_cameras,
    omega_uniform = stats::runif(n_draws),
    fringe_uniform = stats::runif(n_draws),
    membership_uniform = matrix(
      stats::runif(n_draws * max_candidates),
      nrow = n_draws
    ),
    rate_z = matrix(
      stats::rnorm(n_draws * max_candidates),
      nrow = n_draws
    ),
    class_uniform = matrix(
      stats::runif(n_draws * max_candidates),
      nrow = n_draws
    ),
    sigma_camera_standard = sigma_standard,
    camera_standard = z_camera %*% t(Q),
    detection_seed = as.integer(seed + 100000L)
  )
}

.goal004_task2_detection_uniforms <- function(base, window_index) {
  set.seed(as.integer(base$detection_seed + 10L * window_index))
  list(
    training = matrix(
      stats::runif(base$n_draws * base$max_candidates),
      nrow = base$n_draws
    ),
    future = matrix(
      stats::runif(base$n_draws * base$max_candidates),
      nrow = base$n_draws
    )
  )
}

.goal004_task2_rate_draws <- function(
  candidates,
  profile,
  base,
  columns
) {
  classes <- candidates$encounter_class
  if (!all(classes %in% c("routine", "occasional"))) {
    .goal004_task2_stop("Core encounter classes are invalid.")
  }
  routine <- matrix(
    rep(classes == "routine", each = base$n_draws),
    nrow = base$n_draws
  )
  if (profile$class_blur_probability > 0) {
    swap <- base$class_uniform[, columns, drop = FALSE] <
      profile$class_blur_probability
    routine <- routine != swap
  }
  location <- ifelse(
    routine,
    log(profile$routine_median_rate),
    log(profile$occasional_median_rate)
  )
  exp(location + profile$log_rate_sd *
    base$rate_z[, columns, drop = FALSE])
}

.goal004_task2_fringe_rate_draws <- function(candidates, base, columns) {
  if (!all(candidates$encounter_class %in% c("routine", "rare"))) {
    .goal004_task2_stop("Fringe encounter classes are invalid.")
  }
  prior <- goal004_task2_fringe_prior()
  location <- ifelse(
    matrix(
      rep(candidates$encounter_class == "routine", each = base$n_draws),
      nrow = base$n_draws
    ),
    log(prior$routine_median_rate),
    log(prior$rare_median_rate)
  )
  exp(location + prior$log_rate_sd *
    base$rate_z[, columns, drop = FALSE])
}

.goal004_task2_camera_effect <- function(base, camera_sd_scale) {
  effect <- sweep(
    base$camera_standard,
    1L,
    base$sigma_camera_standard * camera_sd_scale,
    "*"
  )
  if (!all(is.finite(effect)) || max(abs(rowSums(effect))) > 1e-12) {
    .goal004_task2_stop("The Goal004 camera-effect draws are invalid.")
  }
  effect
}

.goal004_task2_window_prediction <- function(
  membership,
  membership_probability,
  rate,
  camera_effect,
  effort,
  uniforms
) {
  training_scale <- as.vector(
    exp(camera_effect) %*% effort$active_days_training
  )
  future_scale <- as.vector(
    exp(camera_effect) %*% effort$active_days_future
  )
  q_training <- -expm1(-sweep(rate, 1L, training_scale, "*"))
  q_future <- -expm1(-sweep(rate, 1L, future_scale, "*"))
  training_detected <- membership & uniforms$training < q_training
  future_discovered <- membership & !training_detected &
    uniforms$future < q_future
  if (!all(is.finite(q_training)) || !all(is.finite(q_future)) ||
      any(q_training < 0 | q_training > 1) ||
      any(q_future < 0 | q_future > 1)) {
    .goal004_task2_stop("Non-finite Goal004 detection probabilities.")
  }
  list(
    membership_probability = membership_probability,
    realised_richness = as.integer(rowSums(membership)),
    observed_richness = as.integer(rowSums(training_detected)),
    future_discoveries = as.integer(rowSums(future_discovered)),
    candidate_training_probability = colMeans(
      q_training * membership_probability
    ),
    candidate_future_probability = colMeans(
      (1 - q_training) * q_future * membership_probability
    ),
    candidate_member_training_probability = colMeans(q_training),
    candidate_member_future_probability = colMeans(
      (1 - q_training) * q_future
    )
  )
}

.goal004_task2_prediction_tables <- function(
  prediction,
  profile,
  candidates,
  window,
  pool,
  component
) {
  outcomes <- c("observed_richness", "future_discoveries")
  summary <- lapply(outcomes, function(outcome) {
    .goal004_task2_distribution_summary(prediction[[outcome]]) |>
      dplyr::mutate(outcome = outcome, .before = 1L)
  }) |>
    dplyr::bind_rows() |>
    dplyr::mutate(
      profile_id = profile$profile_id,
      role = profile$role,
      pool = pool,
      component = component,
      window_id = window$window_id[[1L]],
      train_occasions = window$train_occasions[[1L]],
      effort_label = window$effort_label[[1L]],
      training_active_camera_days = sum(window$active_days_training),
      future_active_camera_days = sum(window$active_days_future),
      .before = 1L
    )
  upper <- nrow(candidates)
  pmf <- lapply(outcomes, function(outcome) {
    .goal004_task2_empirical_pmf(prediction[[outcome]], upper) |>
      dplyr::mutate(outcome = outcome, .before = 1L)
  }) |>
    dplyr::bind_rows() |>
    dplyr::mutate(
      profile_id = profile$profile_id,
      pool = pool,
      component = component,
      window_id = window$window_id[[1L]],
      .before = 1L
    )
  candidate <- candidates |>
    dplyr::mutate(
      profile_id = profile$profile_id,
      pool = pool,
      window_id = window$window_id[[1L]],
      prior_membership_probability =
        mean(prediction$membership_probability),
      training_detection_probability =
        prediction$candidate_training_probability,
      future_first_detection_probability =
        prediction$candidate_future_probability,
      member_training_detection_probability =
        prediction$candidate_member_training_probability,
      member_future_first_detection_probability =
        prediction$candidate_member_future_probability,
      .before = 1L
    )
  list(summary = summary, pmf = pmf, candidate = candidate)
}

.goal004_task2_richness_tables <- function(draws, profile_id, role, pool) {
  components <- names(draws)
  summary <- lapply(components, function(component) {
    .goal004_task2_distribution_summary(draws[[component]]) |>
      dplyr::mutate(
        profile_id = profile_id,
        role = role,
        pool = pool,
        component = component,
        .before = 1L
      )
  }) |>
    dplyr::bind_rows()
  pmf <- lapply(components, function(component) {
    .goal004_task2_empirical_pmf(
      draws[[component]],
      upper = switch(component, core = 50L, fringe = 56L, total = 106L)
    ) |>
      dplyr::mutate(
        profile_id = profile_id,
        pool = pool,
        component = component,
        .before = 1L
      )
  }) |>
    dplyr::bind_rows()
  list(summary = summary, pmf = pmf)
}
