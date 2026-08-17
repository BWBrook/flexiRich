.goal004_task4_dataset_row <- function(dataset_row, manifest) {
  if (!inherits(dataset_row, "data.frame") || nrow(dataset_row) != 1L ||
      !identical(names(dataset_row), .goal004_task4_dataset_fields) ||
      !is.list(manifest) ||
      !all(c("scenarios", "datasets", "effort") %in% names(manifest))) {
    .goal004_task4_stop("Invalid Goal004 Task 4 dataset request.")
  }
  frozen <- manifest$datasets |>
    dplyr::filter(dataset_id == dataset_row$dataset_id)
  if (nrow(frozen) != 1L || !identical(dataset_row, frozen)) {
    .goal004_task4_stop("The dataset row differs from its frozen manifest.")
  }
  scenario <- manifest$scenarios |>
    dplyr::filter(scenario_id == dataset_row$scenario_id)
  if (nrow(scenario) != 1L) {
    .goal004_task4_stop("The dataset does not resolve to one scenario.")
  }
  list(dataset = dataset_row, scenario = scenario)
}

.goal004_task4_effort_block <- function(dataset, effort) {
  start <- dataset$effort_block_start[[1L]]
  end <- dataset$effort_block_end[[1L]]
  selected <- effort |>
    dplyr::filter(occasion_index >= start, occasion_index <= end) |>
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
    (dataset$train_occasions[[1L]] + dataset$forecast_occasions[[1L]])
  if (nrow(selected) != expected) {
    .goal004_task4_stop("The Goal004 effort block is incomplete.")
  }
  selected
}

.goal004_task4_species <- function(dataset, scenario, candidates) {
  if (!tibble::is_tibble(candidates) || nrow(candidates) != 50L ||
      !identical(
        as.integer(table(candidates$encounter_class)[c(
          "routine", "occasional"
        )]),
        c(44L, 6L)
      )) {
    .goal004_task4_stop("The Goal004 core candidate mapping is invalid.")
  }
  seed <- dataset$simulation_seed[[1L]]
  routine_index <- which(candidates$encounter_class == "routine")
  occasional_index <- which(candidates$encounter_class == "occasional")
  routine_order <- .with_sim_rng(
    seed + 101L,
    sample(routine_index, length(routine_index), replace = FALSE)
  )
  occasional_order <- .with_sim_rng(
    seed + 102L,
    sample(occasional_index, length(occasional_index), replace = FALSE)
  )
  member_index <- c(
    routine_order[seq_len(scenario$routine_members[[1L]])],
    occasional_order[seq_len(scenario$occasional_members[[1L]])]
  )
  latent_normal <- .with_sim_rng(seed + 201L, stats::rnorm(nrow(candidates)))
  true_component <- candidates$encounter_class
  flipped <- rep(FALSE, nrow(candidates))
  if (scenario$flipped_count[[1L]] > 0L) {
    flipped_index <- .with_sim_rng(
      seed + 202L,
      sample.int(
        nrow(candidates),
        scenario$flipped_count[[1L]],
        replace = FALSE
      )
    )
    flipped[flipped_index] <- TRUE
    true_component[flipped & true_component == "routine"] <- "occasional"
    true_component[flipped & candidates$encounter_class == "occasional"] <-
      "routine"
  }
  location <- ifelse(
    true_component == "routine",
    log(scenario$true_routine_median_rate[[1L]]),
    log(scenario$true_occasional_median_rate[[1L]])
  )
  tibble::tibble(
    species_id = candidates$candidate_id,
    member = seq_len(nrow(candidates)) %in% member_index,
    latent_normal = latent_normal,
    alpha = location + scenario$true_log_rate_sd[[1L]] * latent_normal,
    guild = true_component,
    season_phase = NA_integer_,
    reviewed_encounter_class = candidates$encounter_class,
    class_flipped = flipped
  )
}

.goal004_task4_cameras <- function(dataset, effort, sd_camera) {
  camera_ids <- sort(unique(effort$camera_id), method = "radix")
  raw <- .with_sim_rng(
    dataset$simulation_seed[[1L]] + 301L,
    stats::rnorm(length(camera_ids), mean = 0, sd = sd_camera)
  )
  effect <- raw - mean(raw)
  if (length(effect) > 1L) {
    effect[[length(effect)]] <- -sum(effect[-length(effect)])
  } else {
    effect[[1L]] <- 0
  }
  tibble::tibble(camera_id = camera_ids, camera_effect = effect)
}

#' Simulate one frozen Goal004 Task 4 development dataset
simulate_goal004_task4_dataset <- function(dataset_row, manifest) {
  resolved <- .goal004_task4_dataset_row(dataset_row, manifest)
  dataset <- resolved$dataset
  scenario <- resolved$scenario
  effort <- .goal004_task4_effort_block(dataset, manifest$effort)
  candidates <- goal004_task2_candidate_mapping()$core
  species <- .goal004_task4_species(dataset, scenario, candidates)
  cameras <- .goal004_task4_cameras(dataset, effort, scenario$sd_camera[[1L]])
  observations <- tidyr::crossing(
    species_id = species$species_id,
    effort
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
    .goal004_task4_stop("The generator produced an invalid probability.")
  }
  uniform <- .with_sim_rng(
    dataset$simulation_seed[[1L]] + 401L,
    stats::runif(nrow(observations))
  )
  observations$detected <- as.integer(uniform < probability)
  observations$detected[observations$active_days == 0L] <- NA_integer_

  training <- observations$relative_index <= dataset$train_occasions[[1L]]
  forecast <- !training
  effort_weekly <- effort |>
    dplyr::filter(relative_index <= dataset$train_occasions[[1L]]) |>
    dplyr::select(camera_id, occasion_id, active_days)
  detections <- observations[training, ] |>
    dplyr::select(species_id, camera_id, occasion_id, detected)
  training_data <- prepare_flexirich_g_data(
    species["species_id"],
    effort_weekly,
    detections
  )
  forecast_effort <- effort |>
    dplyr::filter(relative_index > dataset$train_occasions[[1L]]) |>
    dplyr::select(camera_id, occasion_id, active_days)

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
  audit <- list(
    scenario_id = dataset$scenario_id[[1L]],
    pair_id = dataset$pair_id[[1L]],
    simulation_seed = dataset$simulation_seed[[1L]],
    effort_block_start = dataset$effort_block_start[[1L]],
    effort_block_end = dataset$effort_block_end[[1L]],
    train_occasions = dataset$train_occasions[[1L]],
    forecast_occasions = dataset$forecast_occasions[[1L]],
    training_active_camera_days = as.integer(sum(effort_weekly$active_days)),
    forecast_active_camera_days = as.integer(sum(forecast_effort$active_days)),
    flipped_candidate_ids = species$species_id[species$class_flipped],
    reviewed_encounter_class = stats::setNames(
      species$reviewed_encounter_class,
      species$species_id
    ),
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
