.goal005_task2_dataset_row <- function(dataset_row, manifest) {
  valid <- inherits(dataset_row, "data.frame") &&
    nrow(dataset_row) == 1L &&
    identical(names(dataset_row), .goal005_task2_dataset_fields) &&
    is.list(manifest) &&
    all(c("scenarios", "datasets", "effort") %in% names(manifest))
  if (!valid) {
    .goal005_stop("Invalid Goal005 Task 2 dataset request.")
  }
  frozen <- manifest$datasets |>
    dplyr::filter(dataset_id == dataset_row$dataset_id)
  if (nrow(frozen) != 1L || !identical(dataset_row, frozen)) {
    .goal005_stop("The Goal005 dataset row differs from its manifest.")
  }
  scenario <- manifest$scenarios |>
    dplyr::filter(scenario_id == dataset_row$scenario_id)
  if (nrow(scenario) != 1L) {
    .goal005_stop("The Goal005 dataset does not resolve to one scenario.")
  }
  list(dataset = dataset_row, scenario = scenario)
}

.goal005_task2_full_effort_block <- function(dataset, effort) {
  start <- dataset$effort_block_start[[1L]]
  end <- start + 26L + dataset$forecast_occasions[[1L]] - 1L
  selected <- effort |>
    dplyr::filter(
      occasion_index >= .env$start,
      occasion_index <= .env$end
    ) |>
    dplyr::mutate(
      relative_index = as.integer(occasion_index - start + 1L),
      occasion_id = sprintf("occ_%03d", relative_index)
    ) |>
    dplyr::arrange(camera_id, relative_index) |>
    dplyr::select(
      camera_id,
      occasion_id,
      occasion_index,
      relative_index,
      active_days
    )
  expected <- dataset$n_cameras[[1L]] *
    (26L + dataset$forecast_occasions[[1L]])
  if (nrow(selected) != expected) {
    .goal005_stop("The Goal005 paired effort block is incomplete.")
  }
  selected
}

#' Simulate one frozen Goal005 Task 2 information-ceiling dataset
simulate_goal005_task2_dataset <- function(dataset_row, manifest) {
  resolved <- .goal005_task2_dataset_row(dataset_row, manifest)
  dataset <- resolved$dataset
  scenario <- resolved$scenario |>
    dplyr::mutate(flipped_count = 0L)
  full_effort <- .goal005_task2_full_effort_block(dataset, manifest$effort)
  candidates <- goal004_task2_candidate_mapping()$core
  species <- .goal004_task4_species(dataset, scenario, candidates)
  cameras <- .goal004_task4_cameras(
    dataset,
    full_effort,
    scenario$sd_camera[[1L]]
  )
  observations <- tidyr::crossing(
    species_id = species$species_id,
    full_effort
  ) |>
    dplyr::left_join(
      species[c("species_id", "member", "alpha")],
      by = "species_id"
    ) |>
    dplyr::left_join(cameras, by = "camera_id")
  probability <- as.numeric(observations$member) * -expm1(
    -observations$active_days *
      exp(observations$alpha + observations$camera_effect)
  )
  if (any(!is.finite(probability)) ||
      any(probability < 0 | probability > 1)) {
    .goal005_stop("The Goal005 generator produced an invalid probability.")
  }
  uniform <- .with_sim_rng(
    dataset$simulation_seed[[1L]] + 401L,
    stats::runif(nrow(observations))
  )
  observations$detected <- as.integer(uniform < probability)
  observations$detected[observations$active_days == 0L] <- NA_integer_

  training_end <- dataset$train_occasions[[1L]]
  future_end <- training_end + dataset$forecast_occasions[[1L]]
  training <- observations$relative_index <= training_end
  forecast <- observations$relative_index > training_end &
    observations$relative_index <= future_end
  effort_weekly <- full_effort |>
    dplyr::filter(relative_index <= .env$training_end) |>
    dplyr::select(camera_id, occasion_id, active_days)
  forecast_effort <- full_effort |>
    dplyr::filter(
      relative_index > .env$training_end,
      relative_index <= .env$future_end
    ) |>
    dplyr::select(camera_id, occasion_id, active_days)
  detections <- observations[training, ] |>
    dplyr::select(species_id, camera_id, occasion_id, detected)
  training_data <- prepare_flexirich_g_data(
    species["species_id"],
    effort_weekly,
    detections
  )
  training_detected <- vapply(species$species_id, function(id) {
    any(
      observations$detected[training & observations$species_id == id] == 1L,
      na.rm = TRUE
    )
  }, logical(1))
  future_detected <- vapply(species$species_id, function(id) {
    any(
      observations$detected[forecast & observations$species_id == id] == 1L,
      na.rm = TRUE
    )
  }, logical(1))
  species$training_detected <- unname(training_detected)
  species$future_detected <- unname(future_detected)
  species$future_first_detection <-
    !species$training_detected & species$future_detected
  scoring_species <- species |>
    dplyr::select(
      species_id,
      member,
      latent_normal,
      alpha,
      guild,
      season_phase,
      training_detected,
      future_detected,
      future_first_detection
    )
  truth <- list(
    scenario_id = dataset$scenario_id[[1L]],
    true_richness = as.integer(sum(species$member)),
    observed_richness = as.integer(sum(species$training_detected)),
    true_new_species = as.integer(sum(species$future_first_detection)),
    species = scoring_species,
    cameras = cameras
  )
  .goal003_task4_validate_truth(truth)
  by_camera <- effort_weekly |>
    dplyr::summarise(active_days = sum(active_days), .by = camera_id)
  training_active_days <- as.integer(sum(effort_weekly$active_days))
  active_camera_count <- as.integer(sum(by_camera$active_days > 0L))
  if (training_active_days != dataset$training_active_camera_days[[1L]] ||
      active_camera_count != dataset$active_camera_count[[1L]]) {
    .goal005_stop("Goal005 realised effort differs from its manifest.")
  }
  audit <- list(
    scenario_id = dataset$scenario_id[[1L]],
    pair_id = dataset$pair_id[[1L]],
    simulation_seed = dataset$simulation_seed[[1L]],
    effort_block_start = dataset$effort_block_start[[1L]],
    effort_block_end = dataset$effort_block_end[[1L]],
    train_occasions = dataset$train_occasions[[1L]],
    forecast_occasions = dataset$forecast_occasions[[1L]],
    training_active_camera_days = training_active_days,
    active_camera_count = active_camera_count,
    forecast_active_camera_days = as.integer(sum(forecast_effort$active_days)),
    training_data_hash = training_data$data_hash
  )
  list(
    dataset_id = dataset$dataset_id[[1L]],
    training_data = training_data,
    forecast_effort = forecast_effort,
    truth = truth,
    audit = audit
  )
}
