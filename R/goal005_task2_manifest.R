.goal005_task2_scenario_fields <- c(
  "scenario_id",
  "scenario_order",
  "true_richness",
  "routine_members",
  "occasional_members",
  "true_routine_median_rate",
  "true_occasional_median_rate",
  "true_log_rate_sd",
  "sd_camera"
)

.goal005_task2_dataset_fields <- c(
  "dataset_id",
  "pair_id",
  "scenario_id",
  "true_richness",
  "train_occasions",
  "forecast_occasions",
  "replicate",
  "candidate_pool_size",
  "n_cameras",
  "effort_template_id",
  "effort_block_start",
  "effort_block_end",
  "training_active_camera_days",
  "active_camera_count",
  "simulation_seed"
)

.goal005_task2_fit_fields <- c(
  "fit_id",
  "dataset_id",
  "method",
  "run_role",
  "information_level",
  "prior_profile",
  "pool_profile",
  "candidate_pool_size",
  "fit_seed"
)

.goal005_task2_effort_fields <- c(
  "replicate",
  "effort_block_start",
  "train_occasions",
  "training_active_camera_days",
  "active_camera_count"
)

.goal005_task2_expected_scenarios <- function() {
  tibble::tibble(
    scenario_id = c("aligned_low", "aligned_mid", "aligned_high"),
    scenario_order = 1:3,
    true_richness = c(10L, 25L, 40L),
    routine_members = c(9L, 22L, 35L),
    occasional_members = c(1L, 3L, 5L),
    true_routine_median_rate = rep(0.002, 3L),
    true_occasional_median_rate = rep(0.0005, 3L),
    true_log_rate_sd = rep(1, 3L),
    sd_camera = rep(0.35, 3L)
  ) |>
    dplyr::select(dplyr::all_of(.goal005_task2_scenario_fields))
}

.goal005_task2_effort_starts <- function(effort) {
  valid <- tibble::is_tibble(effort) &&
    identical(names(effort), .goal003_task4_effort_fields) &&
    nrow(effort) > 0L
  if (!valid) {
    .goal005_stop("Invalid Goal005 Task 2 effort template.")
  }
  starts <- c(1L, 13L, 25L, 31L, 39L, 49L, 58L, 72L, 83L, 91L, 100L, 124L)
  durations <- c(4L, 8L, 12L, 16L, 26L)
  rows <- lapply(seq_along(starts), function(replicate) {
    start <- starts[[replicate]]
    lapply(durations, function(duration) {
      selected <- effort |>
        dplyr::filter(
          occasion_index >= .env$start,
          occasion_index < .env$start + .env$duration
        )
      by_camera <- selected |>
        dplyr::summarise(active_days = sum(active_days), .by = camera_id)
      tibble::tibble(
        replicate = as.integer(replicate),
        effort_block_start = as.integer(start),
        train_occasions = as.integer(duration),
        training_active_camera_days = as.integer(sum(by_camera$active_days)),
        active_camera_count = as.integer(sum(by_camera$active_days > 0L))
      )
    })
  }) |>
    unlist(recursive = FALSE) |>
    dplyr::bind_rows() |>
    dplyr::select(dplyr::all_of(.goal005_task2_effort_fields))
  if (nrow(rows) != 60L || any(rows$active_camera_count < 1L) ||
      any(rows$active_camera_count > 9L)) {
    .goal005_stop("Goal005 Task 2 effort starts are incomplete.")
  }
  rows
}

.goal005_task2_expected_datasets <- function() {
  scenarios <- .goal005_task2_expected_scenarios()
  effort <- read_goal003_task4_manifests()$effort
  starts <- .goal005_task2_effort_starts(effort)
  tidyr::crossing(
    scenario_order = scenarios$scenario_order,
    replicate = seq_len(12L),
    train_occasions = c(4L, 8L, 12L, 16L, 26L)
  ) |>
    dplyr::left_join(scenarios, by = "scenario_order") |>
    dplyr::left_join(starts, by = c("replicate", "train_occasions")) |>
    dplyr::mutate(
      dataset_id = sprintf(
        "g005t2-%s-%02dw-r%02d",
        scenario_id,
        train_occasions,
        replicate
      ),
      pair_id = sprintf("g005t2-pair-r%02d", replicate),
      forecast_occasions = 4L,
      candidate_pool_size = 50L,
      n_cameras = 9L,
      effort_template_id = "judbury-nine-station-weekly-v1",
      effort_block_end = as.integer(
        effort_block_start + train_occasions + forecast_occasions - 1L
      ),
      simulation_seed = as.integer(650000000L + replicate)
    ) |>
    dplyr::arrange(scenario_order, train_occasions, replicate) |>
    dplyr::select(dplyr::all_of(.goal005_task2_dataset_fields))
}

.goal005_task2_fit_seed <- function(
  information_code,
  scenario_order,
  train_occasions,
  replicate
) {
  as.integer(
    750000000L +
      1000000L * information_code +
      10000L * scenario_order +
      100L * train_occasions +
      replicate
  )
}

.goal005_task2_expected_fits <- function() {
  scenarios <- .goal005_task2_expected_scenarios()
  datasets <- .goal005_task2_expected_datasets() |>
    dplyr::left_join(
      scenarios[c("scenario_id", "scenario_order")],
      by = "scenario_id"
    )
  profiles <- tibble::tibble(
    method = c("goal004", "goal005_candidate_oracle"),
    run_role = "information_ceiling",
    information_level = c("C0", "I0"),
    prior_profile = c("primary", "candidate_rate_exact_v1"),
    pool_profile = "core_50",
    candidate_pool_size = 50L,
    information_code = 1:2
  )
  tidyr::crossing(
    dataset_id = datasets$dataset_id,
    information_code = profiles$information_code
  ) |>
    dplyr::left_join(profiles, by = "information_code") |>
    dplyr::left_join(
      datasets[c(
        "dataset_id", "scenario_order", "train_occasions", "replicate"
      )],
      by = "dataset_id"
    ) |>
    dplyr::mutate(
      fit_id = paste(
        dataset_id,
        information_level,
        sep = "--"
      ),
      fit_seed = .goal005_task2_fit_seed(
        information_code,
        scenario_order,
        train_occasions,
        replicate
      )
    ) |>
    dplyr::arrange(
      match(dataset_id, datasets$dataset_id),
      information_code
    ) |>
    dplyr::select(dplyr::all_of(.goal005_task2_fit_fields))
}

.goal005_task2_read_csv <- function(path, fields, integer_fields) {
  if (!file.exists(path)) {
    .goal005_stop(paste0("Missing Goal005 Task 2 manifest: ", path, "."))
  }
  value <- tibble::as_tibble(utils::read.csv(
    path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = c("", "NA")
  ))
  if (!identical(names(value), fields)) {
    .goal005_stop("A Goal005 Task 2 manifest has an invalid schema.")
  }
  for (field in integer_fields) {
    value[[field]] <- as.integer(value[[field]])
  }
  value
}

.goal005_task2_paths <- function(root = .goal003_project_root()) {
  stats::setNames(
    file.path(
      root,
      "config",
      c(
        "goal005_task2_scenarios.csv",
        "goal005_task2_datasets.csv",
        "goal005_task2_fits.csv",
        "goal003_task4_effort_template.csv",
        "goal003_candidate_pool.csv",
        "goal004_task2_priors.csv"
      )
    ),
    c("scenarios", "datasets", "fits", "effort", "candidates", "priors")
  )
}

validate_goal005_task2_manifests <- function(
  scenarios,
  datasets,
  fits,
  effort
) {
  if (!isTRUE(all.equal(
    scenarios,
    .goal005_task2_expected_scenarios(),
    tolerance = 1e-14,
    check.attributes = TRUE
  ))) {
    .goal005_stop("The Goal005 Task 2 scenarios have changed.")
  }
  if (!identical(datasets, .goal005_task2_expected_datasets())) {
    .goal005_stop("The Goal005 Task 2 datasets have changed.")
  }
  if (!identical(fits, .goal005_task2_expected_fits())) {
    .goal005_stop("The Goal005 Task 2 fits have changed.")
  }
  if (!tibble::is_tibble(effort) ||
      !identical(names(effort), .goal003_task4_effort_fields)) {
    .goal005_stop("The Goal005 Task 2 effort table is invalid.")
  }
  paths <- .goal005_task2_paths()
  required_hashes <- c(
    effort = "d46655701ba0427264fc40a4a568b2ee350a34e9683b1cf1daa3d67ceeaeede9",
    candidates = "60c8900c1904bafa34340e8ea7e2a44fc819836f76746fc7ee80c484166608db",
    priors = "cebff55cb261aedb5ce3a2980764273ef151a1ac741ac6e911383a7db23df3fb"
  )
  observed <- vapply(names(required_hashes), function(name) {
    digest::digest(
      file = paths[[name]],
      algo = "sha256",
      serialize = FALSE
    )
  }, character(1))
  if (!identical(observed, required_hashes)) {
    .goal005_stop("A frozen Goal005 Task 2 input hash has changed.")
  }
  TRUE
}

#' Read and validate the frozen Goal005 Task 2 manifests
read_goal005_task2_manifests <- function() {
  paths <- .goal005_task2_paths()
  scenarios <- .goal005_task2_read_csv(
    paths[["scenarios"]],
    .goal005_task2_scenario_fields,
    c(
      "scenario_order", "true_richness", "routine_members",
      "occasional_members"
    )
  )
  datasets <- .goal005_task2_read_csv(
    paths[["datasets"]],
    .goal005_task2_dataset_fields,
    c(
      "true_richness", "train_occasions", "forecast_occasions",
      "replicate", "candidate_pool_size", "n_cameras",
      "effort_block_start", "effort_block_end",
      "training_active_camera_days", "active_camera_count", "simulation_seed"
    )
  )
  fits <- .goal005_task2_read_csv(
    paths[["fits"]],
    .goal005_task2_fit_fields,
    c("candidate_pool_size", "fit_seed")
  )
  effort <- .goal005_task2_read_csv(
    paths[["effort"]],
    .goal003_task4_effort_fields,
    c("occasion_index", "active_days")
  )
  validate_goal005_task2_manifests(scenarios, datasets, fits, effort)
  hashes <- vapply(paths, function(path) {
    digest::digest(file = path, algo = "sha256", serialize = FALSE)
  }, character(1))
  list(
    scenarios = scenarios,
    datasets = datasets,
    fits = fits,
    effort = effort,
    hashes = hashes
  )
}
