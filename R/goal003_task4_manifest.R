.goal003_task4_stop <- function(message) {
  stop(message, call. = FALSE)
}

.goal003_task4_scenario_fields <- c(
  "scenario_id",
  "scenario_order",
  "scenario_class",
  "misspecification",
  "true_richness",
  "mean_log_rate",
  "sd_log_rate",
  "sd_camera",
  "cryptic_fraction",
  "cryptic_mean_log_rate",
  "cryptic_sd_log_rate",
  "season_cycle_occasions",
  "season_active_occasions",
  "season_active_multiplier",
  "season_inactive_multiplier"
)

.goal003_task4_dataset_fields <- c(
  "dataset_id",
  "pair_id",
  "scenario_id",
  "scenario_class",
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

.goal003_task4_fit_fields <- c(
  "fit_id",
  "dataset_id",
  "method",
  "run_role",
  "prior_profile",
  "pool_profile",
  "candidate_pool_size",
  "fit_seed"
)

.goal003_task4_effort_fields <- c(
  "camera_id",
  "occasion_index",
  "active_days"
)

.goal003_task4_expected_scenarios <- function() {
  tibble::tibble(
    scenario_id = c(
      "matched_low",
      "matched_mid",
      "matched_high",
      "guild_lower_tail",
      "seasonal_availability"
    ),
    scenario_order = seq_len(5L),
    scenario_class = c(rep("matched", 3L), rep("misspecified", 2L)),
    misspecification = c(
      rep("none", 3L),
      "guild_lower_tail",
      "seasonal_availability"
    ),
    true_richness = c(10L, 25L, 40L, 25L, 25L),
    mean_log_rate = c(
      rep(log(0.002), 3L),
      log(0.003),
      log(0.002)
    ),
    sd_log_rate = c(1, 1, 1, 0.6, 1),
    sd_camera = rep(0.35, 5L),
    cryptic_fraction = c(rep(NA_real_, 3L), 0.2, NA_real_),
    cryptic_mean_log_rate = c(
      rep(NA_real_, 3L),
      log(0.00015),
      NA_real_
    ),
    cryptic_sd_log_rate = c(rep(NA_real_, 3L), 0.6, NA_real_),
    season_cycle_occasions = c(rep(NA_integer_, 4L), 52L),
    season_active_occasions = c(rep(NA_integer_, 4L), 13L),
    season_active_multiplier = c(rep(NA_real_, 4L), 3.4),
    season_inactive_multiplier = c(rep(NA_real_, 4L), 0.2)
  )
}

.goal003_task4_effort_starts <- function() {
  list(
    `4` = c(
      76L, 117L, 81L, 90L, 80L, 132L, 64L, 108L, 36L, 35L,
      25L, 141L, 22L, 123L, 28L, 120L, 145L, 7L, 134L, 27L,
      122L, 11L, 121L, 107L, 60L, 119L, 128L, 75L, 138L, 40L
    ),
    `26` = c(
      73L, 83L, 89L, 59L, 55L, 22L, 28L, 29L, 75L, 36L,
      1L, 72L, 50L, 109L, 93L, 108L, 94L, 113L, 63L, 121L,
      117L, 58L, 71L, 57L, 47L, 5L, 33L, 45L, 119L, 60L
    )
  )
}

.goal003_task4_expected_datasets <- function() {
  scenarios <- .goal003_task4_expected_scenarios()
  starts <- .goal003_task4_effort_starts()
  tidyr::crossing(
    scenario_order = scenarios$scenario_order,
    train_occasions = c(4L, 26L),
    replicate = seq_len(30L)
  ) |>
    dplyr::left_join(scenarios, by = "scenario_order") |>
    dplyr::mutate(
      dataset_id = sprintf(
        "g003t4-%s-%02dw-r%02d",
        scenario_id,
        train_occasions,
        replicate
      ),
      pair_id = sprintf(
        "g003t4-pair-%02dw-r%02d",
        train_occasions,
        replicate
      ),
      forecast_occasions = 4L,
      candidate_pool_size = 50L,
      n_cameras = 9L,
      effort_template_id = "judbury-nine-station-weekly-v1",
      effort_block_start = vapply(
        seq_len(dplyr::n()),
        function(index) {
          starts[[as.character(train_occasions[[index]])]][[
            replicate[[index]]
          ]]
        },
        integer(1)
      ),
      effort_block_end = effort_block_start + train_occasions +
        forecast_occasions - 1L,
      simulation_seed = as.integer(
        430000000L + 100L * train_occasions + replicate
      )
    ) |>
    dplyr::select(dplyr::all_of(.goal003_task4_dataset_fields))
}

.goal003_task4_fit_seed <- function(
  profile_code,
  scenario_order,
  train_occasions,
  replicate
) {
  as.integer(
    530000000L +
      1000000L * profile_code +
      10000L * scenario_order +
      100L * train_occasions +
      replicate
  )
}

.goal003_task4_expected_fits <- function() {
  datasets <- .goal003_task4_expected_datasets() |>
    dplyr::left_join(
      .goal003_task4_expected_scenarios()[
        c("scenario_id", "scenario_order")
      ],
      by = "scenario_id"
    )
  primary <- tidyr::crossing(
    dataset_id = datasets$dataset_id,
    method = c("flexirich", "occupancy")
  ) |>
    dplyr::left_join(
      datasets[
        c(
          "dataset_id", "scenario_order", "train_occasions",
          "replicate"
        )
      ],
      by = "dataset_id"
    ) |>
    dplyr::mutate(
      run_role = "primary",
      prior_profile = dplyr::if_else(
        method == "flexirich",
        "primary",
        "occupancy_fixed"
      ),
      pool_profile = "primary_50",
      candidate_pool_size = 50L,
      profile_code = dplyr::if_else(method == "flexirich", 1L, 2L)
    )

  sensitivity_datasets <- datasets |>
    dplyr::filter(scenario_class == "matched", replicate <= 10L)
  prior_profiles <- tibble::tibble(
    prior_profile = c(
      "membership_regularised",
      "mu_alpha_wide",
      "tail_wide"
    ),
    profile_code = 3:5
  )
  prior_sensitivity <- tidyr::crossing(
    dataset_id = sensitivity_datasets$dataset_id,
    prior_profile = prior_profiles$prior_profile
  ) |>
    dplyr::left_join(
      sensitivity_datasets[
        c(
          "dataset_id", "scenario_order", "train_occasions",
          "replicate"
        )
      ],
      by = "dataset_id"
    ) |>
    dplyr::left_join(prior_profiles, by = "prior_profile") |>
    dplyr::mutate(
      method = "flexirich",
      run_role = "prior_sensitivity",
      pool_profile = "primary_50",
      candidate_pool_size = 50L
    )
  pool_sensitivity <- sensitivity_datasets |>
    dplyr::transmute(
      dataset_id,
      scenario_order,
      train_occasions,
      replicate,
      method = "flexirich",
      run_role = "pool_sensitivity",
      prior_profile = "primary",
      pool_profile = "broader_106",
      candidate_pool_size = 106L,
      profile_code = 6L
    )

  dplyr::bind_rows(primary, prior_sensitivity, pool_sensitivity) |>
    dplyr::mutate(
      fit_id = paste(
        dataset_id,
        method,
        prior_profile,
        pool_profile,
        sep = "--"
      ),
      fit_seed = .goal003_task4_fit_seed(
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
    dplyr::select(dplyr::all_of(.goal003_task4_fit_fields))
}

.goal003_task4_read_csv <- function(path, fields, integer_fields) {
  if (!file.exists(path)) {
    .goal003_task4_stop(paste0("Missing frozen Task 4 manifest: ", path, "."))
  }
  value <- tibble::as_tibble(utils::read.csv(
    path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = c("", "NA")
  ))
  if (!identical(names(value), fields)) {
    .goal003_task4_stop("A Task 4 manifest differs from its frozen schema.")
  }
  for (field in integer_fields) {
    value[[field]] <- as.integer(value[[field]])
  }
  value
}

.goal003_task4_paths <- function(root) {
  stats::setNames(
    file.path(
      root,
      "config",
      c(
        "goal003_task4_scenarios.csv",
        "goal003_task4_datasets.csv",
        "goal003_task4_fits.csv",
        "goal003_task4_effort_template.csv"
      )
    ),
    c("scenarios", "datasets", "fits", "effort")
  )
}

#' Validate the frozen Goal003 Task 4 screening manifests
validate_goal003_task4_manifests <- function(
  scenarios,
  datasets,
  fits,
  effort
) {
  scenarios_match <- isTRUE(all.equal(
    scenarios,
    .goal003_task4_expected_scenarios(),
    tolerance = 1e-14,
    check.attributes = TRUE
  ))
  if (!scenarios_match) {
    .goal003_task4_stop("The scenarios differ from the frozen scenario rows.")
  }
  if (!identical(datasets, .goal003_task4_expected_datasets())) {
    .goal003_task4_stop("The datasets differ from the frozen dataset rows.")
  }
  if (!identical(fits, .goal003_task4_expected_fits())) {
    .goal003_task4_stop("The fits differ from the frozen fit rows.")
  }
  root <- .goal003_project_root()
  effort_path <- .goal003_task4_paths(root)[["effort"]]
  effort_hash <- digest::digest(
    file = effort_path,
    algo = "sha256",
    serialize = FALSE
  )
  expected_effort_hash <-
    "d46655701ba0427264fc40a4a568b2ee350a34e9683b1cf1daa3d67ceeaeede9"
  if (!identical(effort_hash, expected_effort_hash)) {
    .goal003_task4_stop("The frozen Judbury effort template hash has changed.")
  }
  expected_effort <- .goal003_task4_read_csv(
    effort_path,
    .goal003_task4_effort_fields,
    c("occasion_index", "active_days")
  )
  if (!identical(effort, expected_effort)) {
    .goal003_task4_stop("The supplied effort template differs from its file.")
  }
  valid_effort <- nrow(effort) == 9L * 153L &&
    length(unique(effort$camera_id)) == 9L &&
    identical(sort(unique(effort$occasion_index)), seq_len(153L)) &&
    all(effort$active_days %in% 0:7) &&
    sum(effort$active_days) == 7644L &&
    sum(effort$active_days == 0L) == 266L
  if (!valid_effort) {
    .goal003_task4_stop("The frozen Judbury effort template is invalid.")
  }
  TRUE
}

#' Read the frozen Goal003 Task 4 screening manifests
read_goal003_task4_manifests <- function() {
  root <- .goal003_project_root()
  paths <- .goal003_task4_paths(root)
  scenarios <- .goal003_task4_read_csv(
    paths[["scenarios"]],
    .goal003_task4_scenario_fields,
    c(
      "scenario_order", "true_richness", "season_cycle_occasions",
      "season_active_occasions"
    )
  )
  datasets <- .goal003_task4_read_csv(
    paths[["datasets"]],
    .goal003_task4_dataset_fields,
    c(
      "true_richness", "train_occasions", "forecast_occasions",
      "replicate", "candidate_pool_size", "n_cameras",
      "effort_block_start", "effort_block_end", "simulation_seed"
    )
  )
  fits <- .goal003_task4_read_csv(
    paths[["fits"]],
    .goal003_task4_fit_fields,
    c("candidate_pool_size", "fit_seed")
  )
  effort <- .goal003_task4_read_csv(
    paths[["effort"]],
    .goal003_task4_effort_fields,
    c("occasion_index", "active_days")
  )
  validate_goal003_task4_manifests(scenarios, datasets, fits, effort)
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
