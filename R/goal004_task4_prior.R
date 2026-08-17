#' Aggregate the 20 frozen Task 4 training and forecast effort blocks
goal004_task4_prior_effort <- function(manifest) {
  if (!is.list(manifest) ||
      !all(c("datasets", "effort") %in% names(manifest))) {
    .goal004_task4_stop("A Goal004 Task 4 manifest is required.")
  }
  blocks <- manifest$datasets |>
    dplyr::distinct(
      train_occasions,
      replicate,
      effort_block_start,
      effort_block_end
    ) |>
    dplyr::arrange(train_occasions, replicate)
  if (nrow(blocks) != 20L) {
    .goal004_task4_stop("The Task 4 effort-block universe is incomplete.")
  }
  cells <- lapply(seq_len(nrow(blocks)), function(index) {
    block <- blocks[index, ]
    future_start <- block$effort_block_start + block$train_occasions
    by_camera <- manifest$effort |>
      dplyr::filter(
        occasion_index >= block$effort_block_start,
        occasion_index <= block$effort_block_end
      ) |>
      dplyr::mutate(
        phase = dplyr::if_else(
          occasion_index < future_start,
          "training",
          "future"
        )
      ) |>
      dplyr::summarise(
        active_camera_days = sum(active_days),
        .by = c(camera_id, phase)
      ) |>
      tidyr::pivot_wider(
        names_from = phase,
        values_from = active_camera_days,
        values_fill = 0,
        names_prefix = "active_days_"
      ) |>
      dplyr::arrange(camera_id) |>
      dplyr::mutate(
        window_id = sprintf(
          "g004_%02dw_r%02d",
          block$train_occasions,
          block$replicate
        ),
        train_occasions = block$train_occasions,
        effort_label = "task4_quantile",
        effort_replicate = block$replicate,
        effort_block_start = block$effort_block_start,
        .before = 1L
      )
    if (nrow(by_camera) != 9L ||
        anyNA(by_camera[c("active_days_training", "active_days_future")])) {
      .goal004_task4_stop("A Task 4 prior effort block is incomplete.")
    }
    by_camera
  }) |>
    dplyr::bind_rows()
  summary <- cells |>
    dplyr::summarise(
      training_active_camera_days = sum(active_days_training),
      future_active_camera_days = sum(active_days_future),
      .by = c(
        window_id,
        train_occasions,
        effort_label,
        effort_replicate,
        effort_block_start
      )
    )
  expected <- .goal004_task4_effort_starts()
  observed <- summary |>
    dplyr::transmute(
      train_occasions,
      replicate = effort_replicate,
      effort_block_start,
      effort_block_end = effort_block_start + train_occasions + 3L,
      training_active_camera_days,
      future_active_camera_days
    )
  if (!identical(observed, expected)) {
    .goal004_task4_stop("Task 4 prior effort differs from the frozen blocks.")
  }
  list(summary = summary, cells = cells)
}

.goal004_task4_prior_anchor_error <- function(combined, anchors) {
  anchor_ids <- unique(anchors$predictive_summary$window_id)
  compare <- function(first, second, keys, value) {
    first <- first |>
      dplyr::filter(window_id %in% .env$anchor_ids) |>
      dplyr::arrange(dplyr::across(dplyr::all_of(keys)))
    second <- second |>
      dplyr::arrange(dplyr::across(dplyr::all_of(keys)))
    if (!identical(first[keys], second[keys])) {
      .goal004_task4_stop("Task 2 prior anchor keys no longer agree.")
    }
    max(abs(first[[value]] - second[[value]]))
  }
  c(
    summary_mean = compare(
      combined$predictive_summary,
      anchors$predictive_summary,
      c("profile_id", "window_id", "outcome"),
      "mean"
    ),
    pmf_probability = compare(
      combined$predictive_pmf,
      anchors$predictive_pmf,
      c("profile_id", "window_id", "outcome", "value"),
      "probability"
    ),
    candidate_training = compare(
      combined$candidate_prediction,
      anchors$candidate_prediction,
      c("profile_id", "window_id", "candidate_id"),
      "training_detection_probability"
    ),
    candidate_future = compare(
      combined$candidate_prediction,
      anchors$candidate_prediction,
      c("profile_id", "window_id", "candidate_id"),
      "future_first_detection_probability"
    )
  )
}

#' Generate matching no-data forecasts for Goal004 Task 4
goal004_task4_prior_forecasts <- function(
  n_draws = 50000L,
  seed = 40042L,
  manifest = read_goal004_task4_manifests(),
  profiles = read_goal004_task2_profiles(),
  candidates = goal004_task2_candidate_mapping()$core
) {
  valid_integer <- function(value, lower) {
    is.numeric(value) && length(value) == 1L && is.finite(value) &&
      value == trunc(value) && value >= lower &&
      value <= .Machine$integer.max
  }
  if (!valid_integer(n_draws, 100L) || !valid_integer(seed, 0L) ||
      nrow(profiles) != 6L || nrow(candidates) != 50L) {
    .goal004_task4_stop("Invalid Task 4 prior-forecast inputs.")
  }
  goal003_manifest <- read_goal003_task4_manifests()
  anchors <- goal004_task2_effort_windows(goal003_manifest)
  task4 <- goal004_task4_prior_effort(manifest)
  combined_effort <- list(
    summary = dplyr::bind_rows(anchors$summary, task4$summary),
    cells = dplyr::bind_rows(anchors$cells, task4$cells)
  )
  base <- .goal004_task2_base_draws(
    n_draws = as.integer(n_draws),
    max_candidates = 106L,
    n_cameras = 9L,
    seed = as.integer(seed)
  )
  combined <- .goal004_task2_core_calibration(
    profiles,
    candidates,
    combined_effort,
    base
  )
  anchor_only <- .goal004_task2_core_calibration(
    profiles,
    candidates,
    anchors,
    base
  )
  anchor_error <- .goal004_task4_prior_anchor_error(combined, anchor_only)
  if (any(anchor_error != 0)) {
    .goal004_task4_stop("The Task 2 prior anchors were not reproduced exactly.")
  }
  task4_ids <- task4$summary$window_id
  list(
    seed = as.integer(seed),
    n_draws = as.integer(n_draws),
    effort_windows = task4$summary,
    effort_by_camera = task4$cells,
    richness_pmf = combined$richness_pmf,
    predictive_summary = combined$predictive_summary |>
      dplyr::filter(window_id %in% .env$task4_ids),
    predictive_pmf = combined$predictive_pmf |>
      dplyr::filter(window_id %in% .env$task4_ids),
    candidate_prediction = combined$candidate_prediction |>
      dplyr::filter(window_id %in% .env$task4_ids),
    task2_anchor_max_abs_error = anchor_error
  )
}
