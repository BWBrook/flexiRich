.goal004_task4_stop <- function(message) {
  stop(message, call. = FALSE)
}

.goal004_task4_scenario_fields <- c(
  "scenario_id",
  "scenario_order",
  "fidelity",
  "true_richness",
  "routine_members",
  "occasional_members",
  "true_routine_median_rate",
  "true_occasional_median_rate",
  "true_log_rate_sd",
  "flipped_count",
  "sd_camera"
)

.goal004_task4_dataset_fields <- c(
  "dataset_id",
  "pair_id",
  "scenario_id",
  "fidelity",
  "true_richness",
  "train_occasions",
  "forecast_occasions",
  "replicate",
  "candidate_pool_size",
  "n_cameras",
  "effort_template_id",
  "effort_block_start",
  "effort_block_end",
  "simulation_seed"
)

.goal004_task4_fit_fields <- c(
  "fit_id",
  "dataset_id",
  "method",
  "run_role",
  "prior_profile",
  "pool_profile",
  "candidate_pool_size",
  "fit_seed"
)

.goal004_task4_expected_scenarios <- function() {
  richness <- tibble::tibble(
    richness_label = c("low", "mid", "high"),
    true_richness = c(10L, 25L, 40L),
    routine_members = c(9L, 22L, 35L),
    occasional_members = c(1L, 3L, 5L)
  )
  aligned_mean <- (44 * log(0.002) + 6 * log(0.0005)) / 50
  weak_difference <- log(2)
  fidelity <- tibble::tibble(
    fidelity = c("aligned", "weak_signal", "ten_percent_flipped"),
    true_routine_median_rate = c(
      0.002,
      exp(aligned_mean + (6 / 50) * weak_difference),
      0.002
    ),
    true_occasional_median_rate = c(
      0.0005,
      exp(aligned_mean - (44 / 50) * weak_difference),
      0.0005
    ),
    flipped_count = c(0L, 0L, 5L)
  )
  tidyr::crossing(
    fidelity_order = seq_len(nrow(fidelity)),
    richness_order = seq_len(nrow(richness))
  ) |>
    dplyr::left_join(
      dplyr::mutate(fidelity, fidelity_order = dplyr::row_number()),
      by = "fidelity_order"
    ) |>
    dplyr::left_join(
      dplyr::mutate(richness, richness_order = dplyr::row_number()),
      by = "richness_order"
    ) |>
    dplyr::mutate(
      scenario_id = paste(fidelity, richness_label, sep = "_"),
      scenario_order = as.integer(
        (fidelity_order - 1L) * nrow(richness) + richness_order
      ),
      true_log_rate_sd = 1,
      sd_camera = 0.35
    ) |>
    dplyr::arrange(scenario_order) |>
    dplyr::select(dplyr::all_of(.goal004_task4_scenario_fields))
}

.goal004_task4_effort_starts <- function() {
  tibble::tibble(
    train_occasions = rep(c(4L, 26L), each = 10L),
    replicate = rep(seq_len(10L), times = 2L),
    effort_block_start = c(
      31L, 55L, 80L, 69L, 126L, 108L, 97L, 1L, 146L, 15L,
      13L, 25L, 49L, 58L, 39L, 72L, 83L, 100L, 91L, 124L
    ),
    effort_block_end = c(
      38L, 62L, 87L, 76L, 133L, 115L, 104L, 8L, 153L, 22L,
      42L, 54L, 78L, 87L, 68L, 101L, 112L, 129L, 120L, 153L
    ),
    training_active_camera_days = c(
      28L, 82L, 171L, 196L, 224L, 224L, 243L, 252L, 252L, 252L,
      748L, 884L, 1009L, 1065L, 1160L, 1293L, 1440L, 1513L,
      1525L, 1591L
    ),
    future_active_camera_days = c(
      28L, 73L, 176L, 196L, 247L, 247L, 252L, 252L, 239L, 175L,
      252L, 171L, 190L, 176L, 185L, 250L, 228L, 224L, 224L, 239L
    )
  )
}

.goal004_task4_select_effort_starts <- function(effort, train_occasions) {
  if (!tibble::is_tibble(effort) ||
      !identical(names(effort), .goal003_task4_effort_fields) ||
      !train_occasions %in% c(4L, 26L)) {
    .goal004_task4_stop("Invalid Task 4 effort-selection inputs.")
  }
  last_start <- max(effort$occasion_index) - train_occasions - 4L + 1L
  candidates <- lapply(seq_len(last_start), function(start) {
    training_end <- start + train_occasions - 1L
    future_end <- training_end + 4L
    tibble::tibble(
      effort_block_start = as.integer(start),
      effort_block_end = as.integer(future_end),
      training_active_camera_days = as.integer(sum(
        effort$active_days[
          effort$occasion_index >= start &
            effort$occasion_index <= training_end
        ]
      )),
      future_active_camera_days = as.integer(sum(
        effort$active_days[
          effort$occasion_index > training_end &
            effort$occasion_index <= future_end
        ]
      ))
    )
  }) |>
    dplyr::bind_rows()
  targets <- stats::quantile(
    candidates$training_active_camera_days,
    probs = seq(0, 1, length.out = 10L),
    type = 7,
    names = FALSE
  )
  chosen <- integer()
  selected <- vector("list", 10L)
  for (index in seq_len(10L)) {
    pool <- candidates |>
      dplyr::filter(!effort_block_start %in% .env$chosen) |>
      dplyr::mutate(
        effort_distance = abs(training_active_camera_days - targets[[index]])
      ) |>
      dplyr::filter(effort_distance == min(effort_distance))
    if (length(chosen) > 0L) {
      pool <- pool |>
        dplyr::rowwise() |>
        dplyr::mutate(
          start_separation = min(abs(effort_block_start - .env$chosen))
        ) |>
        dplyr::ungroup() |>
        dplyr::filter(start_separation == max(start_separation))
    }
    pick <- pool |>
      dplyr::arrange(effort_block_start) |>
      dplyr::slice(1L)
    chosen <- c(chosen, pick$effort_block_start[[1L]])
    selected[[index]] <- pick |>
      dplyr::transmute(
        train_occasions = as.integer(.env$train_occasions),
        replicate = as.integer(.env$index),
        effort_block_start,
        effort_block_end,
        training_active_camera_days,
        future_active_camera_days
      )
  }
  dplyr::bind_rows(selected)
}

.goal004_task4_expected_datasets <- function() {
  scenarios <- .goal004_task4_expected_scenarios()
  starts <- .goal004_task4_effort_starts()
  tidyr::crossing(
    scenario_order = scenarios$scenario_order,
    train_occasions = c(4L, 26L),
    replicate = seq_len(10L)
  ) |>
    dplyr::left_join(scenarios, by = "scenario_order") |>
    dplyr::left_join(
      starts |>
        dplyr::select(
          train_occasions,
          replicate,
          effort_block_start,
          effort_block_end
        ),
      by = c("train_occasions", "replicate")
    ) |>
    dplyr::mutate(
      dataset_id = sprintf(
        "g004t4-%s-%02dw-r%02d",
        scenario_id,
        train_occasions,
        replicate
      ),
      pair_id = sprintf(
        "g004t4-pair-%02dw-r%02d",
        train_occasions,
        replicate
      ),
      forecast_occasions = 4L,
      candidate_pool_size = 50L,
      n_cameras = 9L,
      effort_template_id = "judbury-nine-station-weekly-v1",
      simulation_seed = as.integer(
        440000000L + 100L * train_occasions + replicate
      )
    ) |>
    dplyr::arrange(scenario_order, train_occasions, replicate) |>
    dplyr::select(dplyr::all_of(.goal004_task4_dataset_fields))
}

.goal004_task4_fit_seed <- function(
  profile_code,
  scenario_order,
  train_occasions,
  replicate
) {
  as.integer(
    540000000L +
      1000000L * profile_code +
      10000L * scenario_order +
      100L * train_occasions +
      replicate
  )
}

.goal004_task4_expected_fits <- function() {
  scenarios <- .goal004_task4_expected_scenarios()
  datasets <- .goal004_task4_expected_datasets() |>
    dplyr::left_join(
      scenarios[c("scenario_id", "scenario_order")],
      by = "scenario_id"
    )
  primary_profiles <- tibble::tibble(
    method = c("goal004", "goal003", "occupancy"),
    run_role = "primary",
    prior_profile = c("primary", "goal003_primary", "occupancy_fixed"),
    pool_profile = "core_50",
    candidate_pool_size = 50L,
    profile_code = 1:3
  )
  primary <- tidyr::crossing(
    dataset_id = datasets$dataset_id,
    profile_code = primary_profiles$profile_code
  ) |>
    dplyr::left_join(primary_profiles, by = "profile_code")

  aligned <- datasets |>
    dplyr::filter(fidelity == "aligned", replicate <= 5L)
  sensitivity_profiles <- tibble::tibble(
    prior_profile = c(
      "rate_lower",
      "rate_higher",
      "spread_wider",
      "class_blur",
      "membership_regularised"
    ),
    profile_code = 4:8
  )
  sensitivity <- tidyr::crossing(
    dataset_id = aligned$dataset_id,
    prior_profile = sensitivity_profiles$prior_profile
  ) |>
    dplyr::left_join(sensitivity_profiles, by = "prior_profile") |>
    dplyr::mutate(
      method = "goal004",
      run_role = "prior_sensitivity",
      pool_profile = "core_50",
      candidate_pool_size = 50L
    )
  flipped_blur <- datasets |>
    dplyr::filter(
      fidelity == "ten_percent_flipped",
      replicate <= 5L
    ) |>
    dplyr::transmute(
      dataset_id,
      method = "goal004",
      run_role = "prior_sensitivity",
      prior_profile = "class_blur",
      pool_profile = "core_50",
      candidate_pool_size = 50L,
      profile_code = 7L
    )
  nested <- aligned |>
    dplyr::transmute(
      dataset_id,
      method = "goal004_nested",
      run_role = "pool_sensitivity",
      prior_profile = "primary",
      pool_profile = "broader_106",
      candidate_pool_size = 106L,
      profile_code = 9L
    )

  dplyr::bind_rows(primary, sensitivity, flipped_blur, nested) |>
    dplyr::left_join(
      datasets[c(
        "dataset_id", "scenario_id", "scenario_order",
        "train_occasions", "replicate"
      )],
      by = "dataset_id"
    ) |>
    dplyr::mutate(
      fit_id = paste(
        dataset_id,
        method,
        prior_profile,
        pool_profile,
        sep = "--"
      ),
      fit_seed = .goal004_task4_fit_seed(
        profile_code,
        scenario_order,
        train_occasions,
        replicate
      )
    ) |>
    dplyr::arrange(
      match(dataset_id, datasets$dataset_id),
      profile_code
    ) |>
    dplyr::select(dplyr::all_of(.goal004_task4_fit_fields))
}

.goal004_task4_read_csv <- function(path, fields, integer_fields) {
  if (!file.exists(path)) {
    .goal004_task4_stop(paste0("Missing Goal004 Task 4 manifest: ", path, "."))
  }
  value <- tibble::as_tibble(utils::read.csv(
    path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = c("", "NA")
  ))
  if (!identical(names(value), fields)) {
    .goal004_task4_stop("A Goal004 Task 4 manifest has an invalid schema.")
  }
  for (field in integer_fields) {
    value[[field]] <- as.integer(value[[field]])
  }
  value
}

.goal004_task4_paths <- function(root = .goal003_project_root()) {
  stats::setNames(
    file.path(
      root,
      "config",
      c(
        "goal004_task4_scenarios.csv",
        "goal004_task4_datasets.csv",
        "goal004_task4_fits.csv",
        "goal003_task4_effort_template.csv",
        "goal003_candidate_pool.csv",
        "goal004_task2_priors.csv"
      )
    ),
    c("scenarios", "datasets", "fits", "effort", "candidates", "priors")
  )
}

validate_goal004_task4_manifests <- function(
  scenarios,
  datasets,
  fits,
  effort
) {
  if (!isTRUE(all.equal(
    scenarios,
    .goal004_task4_expected_scenarios(),
    tolerance = 1e-14,
    check.attributes = TRUE
  ))) {
    .goal004_task4_stop("The Goal004 Task 4 scenarios have changed.")
  }
  if (!identical(datasets, .goal004_task4_expected_datasets())) {
    .goal004_task4_stop("The Goal004 Task 4 datasets have changed.")
  }
  if (!identical(fits, .goal004_task4_expected_fits())) {
    .goal004_task4_stop("The Goal004 Task 4 fits have changed.")
  }
  if (!tibble::is_tibble(effort) ||
      !identical(names(effort), .goal003_task4_effort_fields)) {
    .goal004_task4_stop("The Goal004 Task 4 effort table is invalid.")
  }
  selected <- dplyr::bind_rows(
    .goal004_task4_select_effort_starts(effort, 4L),
    .goal004_task4_select_effort_starts(effort, 26L)
  )
  if (!identical(selected, .goal004_task4_effort_starts())) {
    .goal004_task4_stop("The frozen effort-block selection has changed.")
  }
  paths <- .goal004_task4_paths()
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
    .goal004_task4_stop("A frozen Goal004 Task 4 input hash has changed.")
  }
  TRUE
}

#' Read and validate the frozen Goal004 Task 4 development manifests
read_goal004_task4_manifests <- function() {
  paths <- .goal004_task4_paths()
  scenarios <- .goal004_task4_read_csv(
    paths[["scenarios"]],
    .goal004_task4_scenario_fields,
    c(
      "scenario_order", "true_richness", "routine_members",
      "occasional_members", "flipped_count"
    )
  )
  datasets <- .goal004_task4_read_csv(
    paths[["datasets"]],
    .goal004_task4_dataset_fields,
    c(
      "true_richness", "train_occasions", "forecast_occasions",
      "replicate", "candidate_pool_size", "n_cameras",
      "effort_block_start", "effort_block_end", "simulation_seed"
    )
  )
  fits <- .goal004_task4_read_csv(
    paths[["fits"]],
    .goal004_task4_fit_fields,
    c("candidate_pool_size", "fit_seed")
  )
  effort <- .goal004_task4_read_csv(
    paths[["effort"]],
    .goal003_task4_effort_fields,
    c("occasion_index", "active_days")
  )
  validate_goal004_task4_manifests(scenarios, datasets, fits, effort)
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
