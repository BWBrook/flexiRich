.goal003_task4_simulation_stop <- function(message) {
  stop(message, call. = FALSE)
}

.goal003_task4_dataset_row <- function(dataset_row, manifest) {
  if (!inherits(dataset_row, "data.frame") || nrow(dataset_row) != 1L ||
      !identical(names(dataset_row), .goal003_task4_dataset_fields)) {
    .goal003_task4_simulation_stop(
      "dataset_row must be one frozen Goal003 Task 4 dataset row."
    )
  }
  if (!is.list(manifest) ||
      !all(c("scenarios", "datasets", "effort") %in% names(manifest))) {
    .goal003_task4_simulation_stop(
      "manifest must contain the frozen Task 4 scenarios, datasets, and effort."
    )
  }
  frozen <- manifest$datasets |>
    dplyr::filter(dataset_id == dataset_row$dataset_id)
  if (nrow(frozen) != 1L || !identical(dataset_row, frozen)) {
    .goal003_task4_simulation_stop(
      "dataset_row does not exactly match its frozen manifest row."
    )
  }
  scenario <- manifest$scenarios |>
    dplyr::filter(scenario_id == dataset_row$scenario_id)
  if (nrow(scenario) != 1L) {
    .goal003_task4_simulation_stop(
      "dataset_row does not resolve to one frozen Task 4 scenario."
    )
  }
  list(dataset = dataset_row, scenario = scenario)
}

#' Return frozen seasonal rate multipliers
#'
#' @param season_phase Integer phases from zero through three, one per species.
#' @param occasion_index Positive absolute occasion indices.
#' @param active_multiplier Multiplier during the species' active quarter.
#' @param inactive_multiplier Multiplier during the other three quarters.
#'
#' @return A species-by-occasion numeric matrix.
goal003_task4_seasonal_multipliers <- function(
  season_phase,
  occasion_index,
  active_multiplier = 3.4,
  inactive_multiplier = 0.2
) {
  valid <- is.numeric(season_phase) &&
    !is.logical(season_phase) &&
    length(season_phase) > 0L &&
    !anyNA(season_phase) &&
    all(is.finite(season_phase)) &&
    all(season_phase == trunc(season_phase)) &&
    all(season_phase %in% 0:3) &&
    is.numeric(occasion_index) &&
    !is.logical(occasion_index) &&
    length(occasion_index) > 0L &&
    !anyNA(occasion_index) &&
    all(is.finite(occasion_index)) &&
    all(occasion_index == trunc(occasion_index)) &&
    all(occasion_index >= 1L) &&
    is.numeric(active_multiplier) &&
    length(active_multiplier) == 1L &&
    is.finite(active_multiplier) &&
    active_multiplier > 0 &&
    is.numeric(inactive_multiplier) &&
    length(inactive_multiplier) == 1L &&
    is.finite(inactive_multiplier) &&
    inactive_multiplier > 0
  if (!valid) {
    .goal003_task4_simulation_stop(
      "Seasonal phases, occasions, and multipliers are invalid."
    )
  }
  cycle_position <- (as.integer(occasion_index) - 1L) %% 52L
  phase_start <- as.integer(season_phase) * 13L
  active <- outer(
    phase_start,
    cycle_position,
    function(start, position) ((position - start) %% 52L) < 13L
  )
  ifelse(active, active_multiplier, inactive_multiplier)
}

.goal003_task4_species <- function(dataset, scenario) {
  C <- dataset$candidate_pool_size[[1L]]
  S <- dataset$true_richness[[1L]]
  seed <- dataset$simulation_seed[[1L]]
  species_id <- sprintf("sp_%03d", seq_len(C))
  permutation <- .with_sim_rng(seed + 101L, sample.int(C, C))
  member_index <- if (S == 0L) integer() else permutation[seq_len(S)]
  latent_normal <- .with_sim_rng(seed + 102L, stats::rnorm(C))
  member <- seq_len(C) %in% member_index
  guild <- rep("nonmember", C)
  season_phase <- rep(NA_integer_, C)

  if (identical(scenario$misspecification[[1L]], "guild_lower_tail")) {
    n_cryptic <- as.integer(round(
      S * scenario$cryptic_fraction[[1L]]
    ))
    cryptic_index <- .with_sim_rng(
      seed + 103L,
      sample(member_index, n_cryptic, replace = FALSE)
    )
    guild[member] <- "ordinary"
    guild[cryptic_index] <- "cryptic"
    alpha <- scenario$mean_log_rate[[1L]] +
      scenario$sd_log_rate[[1L]] * latent_normal
    alpha[cryptic_index] <- scenario$cryptic_mean_log_rate[[1L]] +
      scenario$cryptic_sd_log_rate[[1L]] * latent_normal[cryptic_index]
  } else {
    alpha <- scenario$mean_log_rate[[1L]] +
      scenario$sd_log_rate[[1L]] * latent_normal
    guild[member] <- "single"
  }

  if (identical(
    scenario$misspecification[[1L]],
    "seasonal_availability"
  )) {
    balanced <- rep(0:3, length.out = S)
    assigned <- .with_sim_rng(seed + 104L, sample(balanced, S))
    season_phase[member_index] <- as.integer(assigned)
  }

  tibble::tibble(
    species_id = species_id,
    member = member,
    latent_normal = latent_normal,
    alpha = alpha,
    guild = guild,
    season_phase = season_phase
  )
}

.goal003_task4_camera_table <- function(dataset, effort, scenario) {
  camera_ids <- sort(unique(effort$camera_id), method = "radix")
  J <- length(camera_ids)
  raw <- .with_sim_rng(
    dataset$simulation_seed[[1L]] + 201L,
    stats::rnorm(J, mean = 0, sd = scenario$sd_camera[[1L]])
  )
  effect <- raw - mean(raw)
  if (J > 1L) {
    effect[[J]] <- -sum(effect[seq_len(J - 1L)])
  } else {
    effect[[1L]] <- 0
  }
  tibble::tibble(camera_id = camera_ids, camera_effect = effect)
}

.goal003_task4_effort_block <- function(dataset, effort) {
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
    .goal003_task4_simulation_stop(
      "The frozen effort block is incomplete."
    )
  }
  selected
}

#' Simulate one frozen Goal003 Task 4 dataset
#'
#' Synthetic truth is returned separately from the canonical training object.
#' Only `training_data` is eligible for model preparation and fitting.
simulate_goal003_task4_dataset <- function(dataset_row, manifest) {
  resolved <- .goal003_task4_dataset_row(dataset_row, manifest)
  dataset <- resolved$dataset
  scenario <- resolved$scenario
  effort <- .goal003_task4_effort_block(dataset, manifest$effort)
  species <- .goal003_task4_species(dataset, scenario)
  cameras <- .goal003_task4_camera_table(dataset, effort, scenario)

  observations <- tidyr::crossing(
    species_id = species$species_id,
    effort
  ) |>
    dplyr::left_join(species, by = "species_id") |>
    dplyr::left_join(cameras, by = "camera_id")

  multiplier <- rep(1, nrow(observations))
  if (identical(
    scenario$misspecification[[1L]],
    "seasonal_availability"
  )) {
    members <- which(observations$member)
    phase <- observations$season_phase[members]
    position <- observations$occasion_index[members]
    active <- ((position - 1L - phase * 13L) %% 52L) < 13L
    multiplier[members] <- ifelse(
      active,
      scenario$season_active_multiplier[[1L]],
      scenario$season_inactive_multiplier[[1L]]
    )
  }
  rate <- exp(observations$alpha + observations$camera_effect) * multiplier
  probability <- as.numeric(observations$member) *
    -expm1(-observations$active_days * rate)
  if (any(!is.finite(probability)) ||
      any(probability < 0 | probability > 1)) {
    .goal003_task4_simulation_stop(
      "The frozen generator produced an invalid detection probability."
    )
  }
  uniform <- .with_sim_rng(
    dataset$simulation_seed[[1L]] + 401L,
    stats::runif(nrow(observations))
  )
  detected <- as.integer(uniform < probability)
  detected[observations$active_days == 0L] <- NA_integer_
  observations$detected <- detected

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

  training_detected <- unname(vapply(species$species_id, function(id) {
    any(observations$detected[training & observations$species_id == id] == 1L,
        na.rm = TRUE)
  }, logical(1)))
  future_detected <- unname(vapply(species$species_id, function(id) {
    any(observations$detected[forecast & observations$species_id == id] == 1L,
        na.rm = TRUE)
  }, logical(1)))
  species$training_detected <- training_detected
  species$future_detected <- future_detected
  species$future_first_detection <- !training_detected & future_detected
  truth <- list(
    scenario_id = dataset$scenario_id[[1L]],
    true_richness = as.integer(sum(species$member)),
    observed_richness = as.integer(sum(training_detected)),
    true_new_species = as.integer(sum(species$future_first_detection)),
    species = species,
    cameras = cameras
  )
  audit <- list(
    scenario_id = dataset$scenario_id[[1L]],
    simulation_seed = dataset$simulation_seed[[1L]],
    effort_block_start = dataset$effort_block_start[[1L]],
    effort_block_end = dataset$effort_block_end[[1L]],
    train_occasions = dataset$train_occasions[[1L]],
    forecast_occasions = dataset$forecast_occasions[[1L]],
    training_active_camera_days = as.integer(sum(effort_weekly$active_days)),
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

#' Add declared all-zero candidates for the broader-pool sensitivity
expand_goal003_task4_candidate_pool <- function(
  data,
  candidate_pool_size = 106L
) {
  validate_flexirich_g_data(data)
  valid <- is.numeric(candidate_pool_size) &&
    !is.logical(candidate_pool_size) &&
    length(candidate_pool_size) == 1L &&
    !is.na(candidate_pool_size) &&
    is.finite(candidate_pool_size) &&
    candidate_pool_size == trunc(candidate_pool_size) &&
    candidate_pool_size >= length(data$candidate_ids) &&
    candidate_pool_size <= .Machine$integer.max
  if (!valid) {
    .goal003_task4_simulation_stop(
      "candidate_pool_size must be a whole number at least as large as the input pool."
    )
  }
  candidate_pool_size <- as.integer(candidate_pool_size)
  n_added <- candidate_pool_size - length(data$candidate_ids)
  if (n_added == 0L) {
    return(data)
  }
  added_ids <- sprintf(
    "sp_%03d",
    length(data$candidate_ids) + seq_len(n_added)
  )
  if (any(added_ids %in% data$candidate_ids)) {
    .goal003_task4_simulation_stop(
      "Generated broader-pool candidate identifiers collide with the input."
    )
  }
  first_species <- data$candidate_ids[[1L]]
  effort <- data$observed |>
    dplyr::filter(species_id == first_species) |>
    dplyr::select(camera_id, occasion_id, active_days)
  added <- tidyr::crossing(species_id = added_ids, effort) |>
    dplyr::mutate(
      detected = dplyr::if_else(
        active_days > 0L,
        0L,
        NA_integer_
      )
    ) |>
    dplyr::select(species_id, camera_id, occasion_id, detected)
  detections <- dplyr::bind_rows(
    data$observed |>
      dplyr::select(species_id, camera_id, occasion_id, detected),
    added
  )
  prepare_flexirich_g_data(
    tibble::tibble(species_id = c(data$candidate_ids, added_ids)),
    effort,
    detections
  )
}
