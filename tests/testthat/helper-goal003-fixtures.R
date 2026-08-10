.goal003_baseline_fixture <- function() {
  candidate_ids <- paste0("sp_", letters[1:8])
  camera_ids <- c("cam_a", "cam_b")
  occasion_ids <- sprintf("occ_%03d", 1:6)
  effort <- tidyr::expand_grid(
    camera_id = camera_ids,
    occasion_id = occasion_ids
  ) |>
    dplyr::mutate(
      active_days = dplyr::case_when(
        camera_id == "cam_b" & occasion_id == "occ_002" ~ 0L,
        camera_id == "cam_a" & occasion_id == "occ_003" ~ 4L,
        .default = 7L
      )
    )
  detections <- tidyr::expand_grid(
    species_id = candidate_ids,
    camera_id = camera_ids,
    occasion_id = occasion_ids
  ) |>
    dplyr::left_join(effort, by = c("camera_id", "occasion_id")) |>
    dplyr::mutate(
      detected = dplyr::case_when(
        active_days == 0L ~ NA_integer_,
        species_id == "sp_a" ~ 1L,
        species_id == "sp_b" & camera_id == "cam_a" ~ 1L,
        species_id == "sp_c" & occasion_id == "occ_001" ~ 1L,
        species_id == "sp_d" & camera_id == "cam_b" &
          occasion_id == "occ_006" ~ 1L,
        .default = 0L
      )
    ) |>
    dplyr::select(species_id, camera_id, occasion_id, detected)
  prepare_flexirich_g_data(
    tibble::tibble(species_id = candidate_ids),
    effort,
    detections
  )
}

.goal003_sample_from_frequencies <- function(T, frequencies, C = NULL) {
  if (is.null(C)) {
    C <- length(frequencies)
  }
  incidence <- matrix(0L, nrow = C, ncol = T)
  for (i in seq_along(frequencies)) {
    if (frequencies[[i]] > 0L) {
      incidence[i, seq_len(frequencies[[i]])] <- 1L
    }
  }
  frequency <- as.integer(rowSums(incidence))
  sample <- list(
    candidate_ids = sprintf("sp_%03d", seq_len(C)),
    sample_ids = sprintf("unit_%03d", seq_len(T)),
    incidence = incidence,
    incidence_frequency = frequency,
    n_sampling_units = as.integer(T),
    observed_richness = as.integer(sum(frequency > 0L)),
    frequency_counts = stats::setNames(
      vapply(1:4, function(k) as.integer(sum(frequency == k)), integer(1)),
      paste0("Q", 1:4)
    ),
    complete_only = FALSE
  )
  .validate_goal003_incidence_sample(sample)
  sample
}
