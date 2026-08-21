.goal005_task4_gate_fixture <- function() {
  manifest <- read_goal005_task4_manifest()
  context <- manifest$datasets |>
    dplyr::select(
      dataset_id,
      pair_id,
      true_richness,
      train_occasions,
      replicate,
      training_active_camera_days,
      active_camera_count
    )
  status <- manifest$fits |>
    dplyr::left_join(context, by = "dataset_id") |>
    dplyr::mutate(
      terminal_status = "primary_clean",
      terminal_clean = TRUE,
      elapsed_seconds = 1
    )
  fit_scores <- status |>
    dplyr::transmute(
      dataset_id,
      fit_id,
      method,
      run_role,
      information_level,
      prior_profile,
      pool_profile,
      candidate_pool_size,
      terminal_clean,
      prediction_available = TRUE,
      true_richness,
      point_estimate = as.numeric(true_richness),
      absolute_error = 0,
      rps = 0.2,
      log_score = 1,
      interval_90_lower = true_richness - 5L,
      interval_90_upper = true_richness + 5L,
      interval_90_covered = TRUE,
      interval_90_width = 10
    )
  prior_scores <- context |>
    dplyr::transmute(
      dataset_id,
      fit_id = NA_character_,
      method = "goal005_prior",
      run_role = "prior_only",
      information_level = "P0",
      prior_profile = "uniform_membership",
      pool_profile = "core_50",
      candidate_pool_size = 50L,
      terminal_clean = TRUE,
      prediction_available = TRUE,
      true_richness,
      point_estimate = 25,
      absolute_error = abs(25 - true_richness),
      rps = 0.5,
      log_score = 1,
      interval_90_lower = 2L,
      interval_90_upper = 48L,
      interval_90_covered = TRUE,
      interval_90_width = 46
    )
  list(
    manifest = manifest,
    fit_status = status |>
      dplyr::select(
        dplyr::all_of(.goal005_task3_fit_fields),
        terminal_status,
        terminal_clean,
        elapsed_seconds
      ),
    richness = dplyr::bind_rows(fit_scores, prior_scores)
  )
}
