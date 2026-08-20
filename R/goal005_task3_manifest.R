.goal005_task3_level_fields <- c(
  "precision_id",
  "precision_code",
  "multiplicative_factor",
  "calibration_sd",
  "calibration_mode"
)

.goal005_task3_calibration_fields <- c(
  "calibration_id",
  "precision_id",
  "precision_code",
  "replicate",
  "multiplicative_factor",
  "calibration_sd",
  "routine_location_estimate",
  "occasional_location_estimate",
  "calibration_seed"
)

.goal005_task3_fit_fields <- c(
  "fit_id",
  "dataset_id",
  "method",
  "run_role",
  "information_level",
  "precision_code",
  "multiplicative_factor",
  "calibration_sd",
  "routine_location_estimate",
  "occasional_location_estimate",
  "calibration_id",
  "prior_profile",
  "pool_profile",
  "candidate_pool_size",
  "fit_seed"
)

.goal005_task3_paths <- function(root = .goal003_project_root()) {
  stats::setNames(
    file.path(
      root,
      "config",
      c(
        "goal005_task3_calibration_levels.csv",
        "goal003_task4_effort_template.csv",
        "goal003_candidate_pool.csv",
        "goal004_task2_priors.csv"
      )
    ),
    c("levels", "effort", "candidates", "priors")
  )
}

.goal005_task3_expected_levels <- function() {
  factors <- c(1, 1.1, 1.25, 1.5, 2, 3, 5)
  tibble::tibble(
    precision_id = c("C0", "F1.10", "F1.25", "F1.50", "F2", "F3", "F5"),
    precision_code = seq_along(factors),
    multiplicative_factor = factors,
    calibration_sd = c(0, log(factors[-1L]) / stats::qnorm(0.975)),
    calibration_mode = c("exact", rep("external_class", 6L))
  ) |>
    dplyr::mutate(precision_code = as.integer(precision_code)) |>
    dplyr::select(dplyr::all_of(.goal005_task3_level_fields))
}

.goal005_task3_read_levels <- function(path) {
  if (!file.exists(path)) {
    .goal005_stop("Missing Goal005 Task 3 calibration-level manifest.")
  }
  levels <- tibble::as_tibble(utils::read.csv(
    path,
    stringsAsFactors = FALSE,
    check.names = FALSE
  ))
  if (!identical(names(levels), .goal005_task3_level_fields)) {
    .goal005_stop("Goal005 Task 3 calibration levels have an invalid schema.")
  }
  levels$precision_code <- as.integer(levels$precision_code)
  expected <- .goal005_task3_expected_levels()
  if (!isTRUE(all.equal(
    levels,
    expected,
    tolerance = 1e-14,
    check.attributes = TRUE
  ))) {
    .goal005_stop("Goal005 Task 3 calibration levels changed.")
  }
  levels
}

.goal005_task3_expected_datasets <- function() {
  .goal005_task2_expected_datasets() |>
    dplyr::filter(train_occasions %in% c(12L, 16L, 26L)) |>
    dplyr::mutate(
      dataset_id = sub("^g005t2-", "g005t3-", dataset_id),
      pair_id = sprintf("g005t3-pair-r%02d", replicate),
      simulation_seed = as.integer(660000000L + replicate)
    ) |>
    dplyr::arrange(
      match(scenario_id, c("aligned_low", "aligned_mid", "aligned_high")),
      train_occasions,
      replicate
    ) |>
    dplyr::select(dplyr::all_of(.goal005_task2_dataset_fields))
}

.goal005_task3_calibration_z <- function(replicate) {
  seed <- as.integer(670000000L + replicate)
  value <- .with_sim_rng(seed, stats::rnorm(2L))
  names(value) <- c("routine", "occasional")
  value
}

.goal005_task3_expected_calibrations <- function(levels) {
  true_location <- c(
    routine = log(0.002),
    occasional = log(0.0005)
  )
  rows <- lapply(seq_len(12L), function(replicate) {
    z <- .goal005_task3_calibration_z(replicate)
    levels |>
      dplyr::transmute(
        calibration_id = sprintf(
          "g005t3-r%02d-%s",
          replicate,
          precision_id
        ),
        precision_id,
        precision_code,
        replicate = as.integer(replicate),
        multiplicative_factor,
        calibration_sd,
        routine_location_estimate =
          true_location[["routine"]] + calibration_sd * z[["routine"]],
        occasional_location_estimate =
          true_location[["occasional"]] +
            calibration_sd * z[["occasional"]],
        calibration_seed = as.integer(670000000L + replicate)
      )
  })
  dplyr::bind_rows(rows) |>
    dplyr::arrange(replicate, precision_code) |>
    dplyr::select(dplyr::all_of(.goal005_task3_calibration_fields))
}

.goal005_task3_fit_seed <- function(
  precision_code,
  scenario_order,
  train_occasions,
  replicate
) {
  as.integer(
    760000000L +
      1000000L * precision_code +
      10000L * scenario_order +
      100L * train_occasions +
      replicate
  )
}

.goal005_task3_expected_fits <- function(datasets, calibrations) {
  scenarios <- .goal005_task2_expected_scenarios()
  context <- datasets |>
    dplyr::left_join(
      scenarios[c("scenario_id", "scenario_order")],
      by = "scenario_id"
    )
  tidyr::crossing(
    dataset_id = context$dataset_id,
    precision_code = sort(unique(calibrations$precision_code))
  ) |>
    dplyr::left_join(
      context[c(
        "dataset_id", "scenario_order", "train_occasions", "replicate"
      )],
      by = "dataset_id"
    ) |>
    dplyr::left_join(
      calibrations,
      by = c("replicate", "precision_code")
    ) |>
    dplyr::mutate(
      fit_id = paste(dataset_id, precision_id, sep = "--"),
      method = ifelse(
        precision_id == "C0",
        "goal004",
        "goal005_class_calibration"
      ),
      run_role = "class_calibration_frontier",
      information_level = precision_id,
      prior_profile = ifelse(
        precision_id == "C0",
        "primary",
        "class_location_calibration_v1"
      ),
      pool_profile = "core_50",
      candidate_pool_size = 50L,
      fit_seed = .goal005_task3_fit_seed(
        precision_code,
        scenario_order,
        train_occasions,
        replicate
      )
    ) |>
    dplyr::arrange(
      match(dataset_id, context$dataset_id),
      precision_code
    ) |>
    dplyr::select(dplyr::all_of(.goal005_task3_fit_fields))
}

validate_goal005_task3_manifest <- function(manifest) {
  required <- c(
    "scenarios", "levels", "datasets", "calibrations", "fits", "effort",
    "hashes"
  )
  valid_structure <- is.list(manifest) && identical(names(manifest), required)
  if (!valid_structure) {
    .goal005_stop("Goal005 Task 3 manifest has an invalid structure.")
  }
  expected_scenarios <- .goal005_task2_expected_scenarios()
  expected_levels <- .goal005_task3_expected_levels()
  expected_datasets <- .goal005_task3_expected_datasets()
  expected_calibrations <- .goal005_task3_expected_calibrations(expected_levels)
  expected_fits <- .goal005_task3_expected_fits(
    expected_datasets,
    expected_calibrations
  )
  valid <- identical(manifest$scenarios, expected_scenarios) &&
    isTRUE(all.equal(
      manifest$levels,
      expected_levels,
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
    nrow(manifest$datasets) == 108L &&
    nrow(manifest$calibrations) == 84L &&
    nrow(manifest$fits) == 756L &&
    !anyDuplicated(manifest$datasets$dataset_id) &&
    !anyDuplicated(manifest$calibrations$calibration_id) &&
    !anyDuplicated(manifest$fits$fit_id) &&
    !anyDuplicated(manifest$fits$fit_seed) &&
    all(manifest$datasets$train_occasions %in% c(12L, 16L, 26L)) &&
    all(manifest$datasets$simulation_seed ==
      660000000L + manifest$datasets$replicate) &&
    all(manifest$calibrations$calibration_seed ==
      670000000L + manifest$calibrations$replicate)
  if (!valid) {
    .goal005_stop("Goal005 Task 3 manifest differs from its frozen design.")
  }
  invisible(TRUE)
}

#' Generate and validate the frozen Goal005 Task 3 manifest
read_goal005_task3_manifest <- function() {
  paths <- .goal005_task3_paths()
  base <- read_goal005_task2_manifests()
  levels <- .goal005_task3_read_levels(paths[["levels"]])
  scenarios <- .goal005_task2_expected_scenarios()
  datasets <- .goal005_task3_expected_datasets()
  calibrations <- .goal005_task3_expected_calibrations(levels)
  fits <- .goal005_task3_expected_fits(datasets, calibrations)
  effort <- base$effort
  table_hashes <- c(
    scenarios = digest::digest(scenarios, algo = "sha256", serialize = TRUE),
    datasets = digest::digest(datasets, algo = "sha256", serialize = TRUE),
    calibrations = digest::digest(
      calibrations,
      algo = "sha256",
      serialize = TRUE
    ),
    fits = digest::digest(fits, algo = "sha256", serialize = TRUE)
  )
  file_hashes <- vapply(paths, function(path) {
    digest::digest(file = path, algo = "sha256", serialize = FALSE)
  }, character(1))
  result <- list(
    scenarios = scenarios,
    levels = levels,
    datasets = datasets,
    calibrations = calibrations,
    fits = fits,
    effort = effort,
    hashes = c(table_hashes, file_hashes)
  )
  validate_goal005_task3_manifest(result)
  result
}
