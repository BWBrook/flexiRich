.goal006_synthetic_row <- function(simulation_row, manifest) {
  required <- names(goal006_expected_synthetic_manifest())
  valid <- inherits(simulation_row, "data.frame") &&
    nrow(simulation_row) == 1L && identical(names(simulation_row), required) &&
    inherits(manifest, "data.frame") && identical(names(manifest), required)
  if (!valid) {
    .goal006_stop("Invalid Goal006 synthetic dataset request.")
  }
  frozen <- manifest |>
    dplyr::filter(simulation_id == simulation_row$simulation_id)
  if (nrow(frozen) != 1L || !identical(simulation_row, frozen)) {
    .goal006_stop("The Goal006 synthetic row differs from its manifest.")
  }
  simulation_row
}

#' Simulate one frozen Goal006 calibration-recovery dataset
#'
#' @param simulation_row One row of the frozen synthetic manifest.
#' @param contract Goal006 Task 1 contract read without empirical outcomes.
#'
#' @return Canonical calibration histories plus protected synthetic truth.
simulate_goal006_calibration_dataset <- function(simulation_row, contract) {
  required_contract <- c("candidates", "effort", "synthetic", "model")
  if (!is.list(contract) || any(!required_contract %in% names(contract))) {
    .goal006_stop("contract must contain the Goal006 synthetic authorities.")
  }
  simulation <- .goal006_synthetic_row(simulation_row, contract$synthetic)
  candidates <- contract$candidates |>
    dplyr::transmute(
      species_id = candidate_id,
      encounter_class
    ) |>
    dplyr::arrange(species_id)
  if (nrow(candidates) != simulation$candidate_pool_size ||
      nrow(candidates) != simulation$true_members) {
    .goal006_stop("Goal006 synthetic membership differs from its contract.")
  }
  effort <- contract$effort |>
    dplyr::filter(
      occasion_index >= simulation$calibration_start_index,
      occasion_index <= simulation$calibration_end_index
    ) |>
    dplyr::mutate(occasion_id = sprintf("occ_%03d", occasion_index)) |>
    dplyr::select(camera_id, occasion_id, active_days) |>
    dplyr::arrange(camera_id, occasion_id)
  expected_effort_rows <- length(unique(effort$camera_id)) *
    (simulation$calibration_end_index -
      simulation$calibration_start_index + 1L)
  if (nrow(effort) != expected_effort_rows) {
    .goal006_stop("The Goal006 synthetic effort block is incomplete.")
  }

  class_location <- c(
    routine = log(simulation$routine_rate),
    occasional = log(simulation$occasional_rate)
  )
  latent_normal <- .with_sim_rng(
    simulation$simulation_seed + 1L,
    stats::rnorm(nrow(candidates))
  )
  species <- candidates |>
    dplyr::mutate(
      latent_normal = latent_normal,
      alpha = unname(class_location[encounter_class]) +
        simulation$log_rate_sd * latent_normal
    )
  cameras <- tibble::tibble(
    camera_id = sort(unique(effort$camera_id), method = "radix"),
    raw_effect = .with_sim_rng(
      simulation$simulation_seed + 2L,
      stats::rnorm(length(unique(effort$camera_id)), 0, simulation$camera_sd)
    )
  ) |>
    dplyr::mutate(
      camera_effect = raw_effect - mean(raw_effect)
    ) |>
    dplyr::select(-raw_effect)
  observations <- tidyr::crossing(species_id = species$species_id, effort) |>
    dplyr::left_join(species[c("species_id", "alpha")], by = "species_id") |>
    dplyr::left_join(cameras, by = "camera_id")
  probability <- -expm1(
    -observations$active_days *
      exp(observations$alpha + observations$camera_effect)
  )
  if (any(!is.finite(probability)) || any(probability < 0 | probability > 1)) {
    .goal006_stop("The Goal006 generator produced invalid probabilities.")
  }
  uniform <- .with_sim_rng(
    simulation$simulation_seed + 3L,
    stats::runif(nrow(observations))
  )
  observations$detected <- as.integer(uniform < probability)
  observations$detected[observations$active_days == 0L] <- NA_integer_
  source_data <- prepare_flexirich_g_data(
    species["species_id"],
    effort,
    observations |>
      dplyr::select(species_id, camera_id, occasion_id, detected)
  )
  detected <- stats::setNames(
    as.logical(source_data$stan_data$detected_ever),
    source_data$candidate_ids
  )
  species <- species |>
    dplyr::mutate(calibration_detected = unname(detected[species_id]))
  class_detected <- species |>
    dplyr::summarise(
      candidates = dplyr::n(),
      detected = sum(calibration_detected),
      .by = encounter_class
    ) |>
    dplyr::arrange(match(encounter_class, c("routine", "occasional")))
  list(
    simulation_id = simulation$simulation_id,
    source_data = source_data,
    encounter_class = stats::setNames(
      species$encounter_class,
      species$species_id
    ),
    truth = list(
      class_location = class_location,
      species = species,
      cameras = cameras,
      class_detected = class_detected
    ),
    audit = list(
      empirical_outcomes_used = FALSE,
      simulation_seed = as.integer(simulation$simulation_seed),
      active_station_days = as.integer(sum(effort$active_days)),
      detected_species = as.integer(sum(species$calibration_detected)),
      data_hash = source_data$data_hash
    )
  )
}
