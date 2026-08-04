goal002r_toy_data <- function() {
  candidate_pool <- tibble::tibble(
    species_id = sprintf("sp_%02d", 1:4)
  )
  effort_weekly <- tibble::tribble(
    ~camera_id, ~occasion_id, ~active_days,
    "cam_01", "occ_01", 7L,
    "cam_01", "occ_02", 7L,
    "cam_01", "occ_03", 0L,
    "cam_02", "occ_01", 6L,
    "cam_02", "occ_02", 7L,
    "cam_02", "occ_03", 5L
  )
  detections <- tidyr::crossing(
    species_id = candidate_pool$species_id,
    camera_id = unique(effort_weekly$camera_id),
    occasion_id = unique(effort_weekly$occasion_id)
  ) |>
    dplyr::left_join(
      effort_weekly,
      by = c("camera_id", "occasion_id")
    ) |>
    dplyr::mutate(
      detected = dplyr::case_when(
        active_days == 0L ~ NA_integer_,
        species_id == "sp_01" & camera_id == "cam_01" &
          occasion_id == "occ_01" ~ 1L,
        species_id == "sp_02" & camera_id == "cam_02" &
          occasion_id == "occ_02" ~ 1L,
        .default = 0L
      )
    ) |>
    dplyr::select(species_id, camera_id, occasion_id, detected)
  prepare_flexirich_g_collapsed_data(
    prepare_flexirich_g_data(
      candidate_pool,
      effort_weekly,
      detections
    )
  )
}
