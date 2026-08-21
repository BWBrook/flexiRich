.goal005_task4_profile_fields <- c(
  "profile_id",
  "profile_code",
  "calibration_bias_log",
  "median_rate_multiplier",
  "multiplicative_factor",
  "calibration_sd"
)

.goal005_task4_calibration_fields <- c(
  "calibration_id",
  "profile_id",
  "profile_code",
  "replicate",
  "calibration_bias_log",
  "median_rate_multiplier",
  "multiplicative_factor",
  "calibration_sd",
  "routine_location_estimate",
  "occasional_location_estimate",
  "calibration_seed"
)

.goal005_task4_expected_profiles <- function() {
  delta <- log(1.25)
  tibble::tibble(
    profile_id = c("unbiased", "down_0.8", "up_1.25"),
    profile_code = 1:3,
    calibration_bias_log = c(0, -delta, delta),
    median_rate_multiplier = c(1, 0.8, 1.25),
    multiplicative_factor = 3,
    calibration_sd = log(3) / stats::qnorm(0.975)
  ) |>
    dplyr::mutate(profile_code = as.integer(profile_code)) |>
    dplyr::select(dplyr::all_of(.goal005_task4_profile_fields))
}

.goal005_task4_expected_datasets <- function() {
  .goal005_task2_expected_datasets() |>
    dplyr::filter(train_occasions == 12L) |>
    dplyr::mutate(
      dataset_id = sub("^g005t2-", "g005t4-", dataset_id),
      pair_id = sprintf("g005t4-pair-r%02d", replicate),
      simulation_seed = as.integer(680000000L + replicate)
    ) |>
    dplyr::arrange(
      match(scenario_id, c("aligned_low", "aligned_mid", "aligned_high")),
      replicate
    ) |>
    dplyr::select(dplyr::all_of(.goal005_task2_dataset_fields))
}

.goal005_task4_calibration_z <- function(replicate) {
  seed <- as.integer(690000000L + replicate)
  value <- .with_sim_rng(seed, stats::rnorm(2L))
  names(value) <- c("routine", "occasional")
  value
}

.goal005_task4_expected_calibrations <- function(profiles) {
  true_location <- c(
    routine = log(0.002),
    occasional = log(0.0005)
  )
  rows <- lapply(seq_len(12L), function(replicate) {
    z <- .goal005_task4_calibration_z(replicate)
    profiles |>
      dplyr::transmute(
        calibration_id = sprintf(
          "g005t4-r%02d-%s",
          replicate,
          profile_id
        ),
        profile_id,
        profile_code,
        replicate = as.integer(replicate),
        calibration_bias_log,
        median_rate_multiplier,
        multiplicative_factor,
        calibration_sd,
        routine_location_estimate = true_location[["routine"]] +
          calibration_sd * z[["routine"]] + calibration_bias_log,
        occasional_location_estimate = true_location[["occasional"]] +
          calibration_sd * z[["occasional"]] + calibration_bias_log,
        calibration_seed = as.integer(690000000L + replicate)
      )
  })
  dplyr::bind_rows(rows) |>
    dplyr::arrange(replicate, profile_code) |>
    dplyr::select(dplyr::all_of(.goal005_task4_calibration_fields))
}

.goal005_task4_fit_seed <- function(profile_code, scenario_order, replicate) {
  as.integer(
    780000000L +
      1000000L * profile_code +
      10000L * scenario_order +
      1200L +
      replicate
  )
}

.goal005_task4_expected_fits <- function(datasets, calibrations) {
  scenarios <- .goal005_task2_expected_scenarios()
  context <- datasets |>
    dplyr::left_join(
      scenarios[c("scenario_id", "scenario_order")],
      by = "scenario_id"
    )
  tidyr::crossing(
    dataset_id = context$dataset_id,
    profile_code = sort(unique(calibrations$profile_code))
  ) |>
    dplyr::left_join(
      context[c("dataset_id", "scenario_order", "replicate")],
      by = "dataset_id"
    ) |>
    dplyr::left_join(
      calibrations,
      by = c("replicate", "profile_code")
    ) |>
    dplyr::mutate(
      fit_id = paste(dataset_id, profile_id, sep = "--"),
      method = "goal005_class_calibration",
      run_role = "calibration_transfer_stress",
      information_level = profile_id,
      precision_code = profile_code,
      prior_profile = "class_location_calibration_v1",
      pool_profile = "core_50",
      candidate_pool_size = 50L,
      fit_seed = .goal005_task4_fit_seed(
        profile_code,
        scenario_order,
        replicate
      )
    ) |>
    dplyr::arrange(match(dataset_id, context$dataset_id), profile_code) |>
    dplyr::select(dplyr::all_of(.goal005_task3_fit_fields))
}

validate_goal005_task4_manifest <- function(manifest) {
  required <- c(
    "scenarios", "profiles", "datasets", "calibrations", "fits", "effort",
    "hashes"
  )
  if (!is.list(manifest) || !identical(names(manifest), required)) {
    .goal005_stop("Goal005 Task 4 manifest has an invalid structure.")
  }
  expected_profiles <- .goal005_task4_expected_profiles()
  expected_datasets <- .goal005_task4_expected_datasets()
  expected_calibrations <- .goal005_task4_expected_calibrations(
    expected_profiles
  )
  expected_fits <- .goal005_task4_expected_fits(
    expected_datasets,
    expected_calibrations
  )
  valid <- identical(manifest$scenarios, .goal005_task2_expected_scenarios()) &&
    isTRUE(all.equal(
      manifest$profiles,
      expected_profiles,
      tolerance = 1e-14,
      check.attributes = TRUE
    )) &&
    identical(manifest$datasets, expected_datasets) &&
    isTRUE(all.equal(
      manifest$calibrations,
      expected_calibrations,
      tolerance = 1e-14,
      check.attributes = TRUE
    )) &&
    isTRUE(all.equal(
      manifest$fits,
      expected_fits,
      tolerance = 1e-14,
      check.attributes = TRUE
    )) &&
    nrow(manifest$datasets) == 36L &&
    nrow(manifest$calibrations) == 36L &&
    nrow(manifest$fits) == 108L &&
    !anyDuplicated(manifest$datasets$dataset_id) &&
    !anyDuplicated(manifest$calibrations$calibration_id) &&
    !anyDuplicated(manifest$fits$fit_id) &&
    !anyDuplicated(manifest$fits$fit_seed) &&
    all(manifest$datasets$train_occasions == 12L) &&
    all(manifest$datasets$simulation_seed ==
      680000000L + manifest$datasets$replicate) &&
    all(manifest$calibrations$calibration_seed ==
      690000000L + manifest$calibrations$replicate)
  if (!valid) {
    .goal005_stop("Goal005 Task 4 manifest differs from its frozen design.")
  }
  invisible(TRUE)
}

#' Generate and validate the frozen Goal005 Task 4 manifest
read_goal005_task4_manifest <- function() {
  base <- read_goal005_task3_manifest()
  scenarios <- .goal005_task2_expected_scenarios()
  profiles <- .goal005_task4_expected_profiles()
  datasets <- .goal005_task4_expected_datasets()
  calibrations <- .goal005_task4_expected_calibrations(profiles)
  fits <- .goal005_task4_expected_fits(datasets, calibrations)
  table_hashes <- c(
    scenarios = digest::digest(scenarios, algo = "sha256", serialize = TRUE),
    profiles = digest::digest(profiles, algo = "sha256", serialize = TRUE),
    datasets = digest::digest(datasets, algo = "sha256", serialize = TRUE),
    calibrations = digest::digest(
      calibrations,
      algo = "sha256",
      serialize = TRUE
    ),
    fits = digest::digest(fits, algo = "sha256", serialize = TRUE)
  )
  result <- list(
    scenarios = scenarios,
    profiles = profiles,
    datasets = datasets,
    calibrations = calibrations,
    fits = fits,
    effort = base$effort,
    hashes = c(table_hashes, base$hashes[c("effort", "candidates", "priors")])
  )
  validate_goal005_task4_manifest(result)
  result
}
