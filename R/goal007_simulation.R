.goal007_task2_dataset_row <- function(dataset_row, contract) {
  required <- names(goal007_expected_task2_datasets())
  valid <- inherits(dataset_row, "data.frame") && nrow(dataset_row) == 1L &&
    identical(names(dataset_row), required) && is.list(contract) &&
    all(c("candidates", "effort", "task2_datasets") %in% names(contract))
  if (!valid) {
    .goal007_stop("Invalid Goal007 Task 2 dataset request.")
  }
  frozen <- contract$task2_datasets |>
    dplyr::filter(dataset_id == dataset_row$dataset_id)
  if (nrow(frozen) != 1L || !identical(dataset_row, frozen)) {
    .goal007_stop("The Goal007 Task 2 dataset differs from its contract.")
  }
  dataset_row
}

.goal007_goal006_surrogate <- function(dataset) {
  tibble::tibble(
    simulation_id = dataset$dataset_id,
    profile_id = dataset$profile_id,
    profile_code = as.integer(dataset$profile_code),
    replicate = as.integer(dataset$replicate),
    calibration_start_index = as.integer(dataset$calibration_start_index),
    calibration_end_index = as.integer(dataset$calibration_end_index),
    candidate_pool_size = as.integer(dataset$candidate_pool_size),
    routine_candidates = as.integer(dataset$routine_candidates),
    occasional_candidates = as.integer(dataset$occasional_candidates),
    true_members = as.integer(dataset$true_members),
    routine_rate = dataset$routine_rate,
    occasional_rate = dataset$occasional_rate,
    log_rate_sd = dataset$log_rate_sd,
    camera_sd = dataset$camera_sd,
    simulation_seed = as.integer(dataset$simulation_seed),
    fit_seed = 1L
  )
}

#' Simulate one frozen Goal007 Task 2 calibration dataset
#'
#' This deliberately reuses the proven Goal006 generator after converting one
#' Goal007 row to its exact internal schema. The conversion changes identifiers
#' and seeds but not the ecological or observation process.
#'
#' @param dataset_row One row of the Goal007 Task 2 dataset contract.
#' @param contract Outcome-free Goal007 Task 1 contract.
#'
#' @return Canonical calibration histories plus protected synthetic truth.
simulate_goal007_task2_dataset <- function(dataset_row, contract) {
  dataset <- .goal007_task2_dataset_row(dataset_row, contract)
  surrogate <- .goal007_goal006_surrogate(dataset)
  goal006_contract <- list(
    candidates = contract$candidates,
    effort = contract$effort,
    synthetic = surrogate,
    model = goal006_model_contract()
  )
  result <- simulate_goal006_calibration_dataset(
    surrogate,
    goal006_contract
  )
  result$simulation_id <- dataset$dataset_id
  result$audit$empirical_outcomes_used <- FALSE
  result$audit$goal007_profile_id <- dataset$profile_id
  result$audit$goal007_screen_role <- dataset$screen_role
  result
}
