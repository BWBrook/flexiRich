.assert_scalar_integer <- function(x, name, lower, upper = Inf) {
  valid <- length(x) == 1L && !is.na(x) && is.numeric(x) &&
    x == as.integer(x) && x >= lower && x <= upper
  if (!valid) {
    stop(name, " must be one integer in [", lower, ", ", upper, "].", call. = FALSE)
  }
  as.integer(x)
}

.assert_scalar_numeric <- function(x, name, lower = -Inf, upper = Inf) {
  valid <- length(x) == 1L && !is.na(x) && is.numeric(x) &&
    is.finite(x) && x >= lower && x <= upper
  if (!valid) {
    stop(name, " must be one finite number in [", lower, ", ", upper, "].", call. = FALSE)
  }
  as.numeric(x)
}

validate_sim_config <- function(config) {
  if (!is.list(config)) {
    stop("config must be a list.", call. = FALSE)
  }

  config$candidate_pool_size <- .assert_scalar_integer(
    config$candidate_pool_size, "candidate_pool_size", 1L
  )
  config$true_richness <- .assert_scalar_integer(
    config$true_richness, "true_richness", 0L, config$candidate_pool_size
  )
  config$n_cameras <- .assert_scalar_integer(config$n_cameras, "n_cameras", 1L)
  config$n_occasions <- .assert_scalar_integer(config$n_occasions, "n_occasions", 1L)
  config$occasion_days <- .assert_scalar_integer(config$occasion_days, "occasion_days", 1L)
  if (config$occasion_days != 7L) {
    stop("occasion_days must equal 7 in Goal 001.", call. = FALSE)
  }

  if (!inherits(config$start_date, "Date") || length(config$start_date) != 1L ||
      is.na(config$start_date)) {
    stop("start_date must be one non-missing Date.", call. = FALSE)
  }

  config$mean_log_rate <- .assert_scalar_numeric(config$mean_log_rate, "mean_log_rate")
  config$sd_log_rate <- .assert_scalar_numeric(config$sd_log_rate, "sd_log_rate", 0)
  config$sd_camera <- .assert_scalar_numeric(config$sd_camera, "sd_camera", 0)
  config$initial_operating_prob <- .assert_scalar_numeric(
    config$initial_operating_prob, "initial_operating_prob", 0, 1
  )
  config$daily_failure_prob <- .assert_scalar_numeric(
    config$daily_failure_prob, "daily_failure_prob", 0, 1
  )
  config$daily_repair_prob <- .assert_scalar_numeric(
    config$daily_repair_prob, "daily_repair_prob", 0, 1
  )
  config$seed <- .assert_scalar_integer(
    config$seed, "seed", 0L, .Machine$integer.max - 1000L
  )

  class(config) <- c("flexirich_sim_config", "list")
  config
}

flexirich_sim_config <- function(
  candidate_pool_size = 30L,
  true_richness = 20L,
  n_cameras = 9L,
  n_occasions = 208L,
  occasion_days = 7L,
  start_date = as.Date("2019-06-01"),
  mean_log_rate = log(5e-4),
  sd_log_rate = 1.25,
  sd_camera = 0.35,
  initial_operating_prob = 1,
  daily_failure_prob = 0.002,
  daily_repair_prob = 0.1,
  seed = 1L
) {
  validate_sim_config(list(
    candidate_pool_size = candidate_pool_size,
    true_richness = true_richness,
    n_cameras = n_cameras,
    n_occasions = n_occasions,
    occasion_days = occasion_days,
    start_date = start_date,
    mean_log_rate = mean_log_rate,
    sd_log_rate = sd_log_rate,
    sd_camera = sd_camera,
    initial_operating_prob = initial_operating_prob,
    daily_failure_prob = daily_failure_prob,
    daily_repair_prob = daily_repair_prob,
    seed = seed
  ))
}
