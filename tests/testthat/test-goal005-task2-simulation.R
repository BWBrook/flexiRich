testthat::test_that("Goal005 histories are nested across richness and duration", {
  manifest <- read_goal005_task2_manifests()
  rows <- manifest$datasets |>
    dplyr::filter(replicate == 1L)
  low4 <- simulate_goal005_task2_dataset(rows |>
    dplyr::filter(true_richness == 10L, train_occasions == 4L), manifest)
  mid8 <- simulate_goal005_task2_dataset(rows |>
    dplyr::filter(true_richness == 25L, train_occasions == 8L), manifest)
  high26 <- simulate_goal005_task2_dataset(rows |>
    dplyr::filter(true_richness == 40L, train_occasions == 26L), manifest)

  members <- lapply(list(low4, mid8, high26), function(x) {
    dplyr::filter(x$truth$species, member)$species_id
  })
  testthat::expect_true(all(members[[1L]] %in% members[[2L]]))
  testthat::expect_true(all(members[[2L]] %in% members[[3L]]))
  testthat::expect_identical(
    low4$truth$species$latent_normal,
    high26$truth$species$latent_normal
  )
  testthat::expect_identical(low4$truth$cameras, high26$truth$cameras)

  common <- c("species_id", "camera_id", "occasion_id")
  low_observed <- low4$training_data$observed |>
    dplyr::arrange(dplyr::across(dplyr::all_of(common)))
  high_observed <- high26$training_data$observed |>
    dplyr::filter(occasion_id %in% unique(low_observed$occasion_id)) |>
    dplyr::arrange(dplyr::across(dplyr::all_of(common)))
  # Nonmembers differ by richness; overlapping member candidates must share
  # their random observation stream exactly.
  shared_members <- members[[1L]]
  testthat::expect_identical(
    dplyr::filter(low_observed, species_id %in% shared_members),
    dplyr::filter(high_observed, species_id %in% shared_members)
  )
})

testthat::test_that("Goal005 simulations preserve effort and truth isolation", {
  manifest <- read_goal005_task2_manifests()
  row <- manifest$datasets |>
    dplyr::filter(
      true_richness == 25L,
      train_occasions == 4L,
      effort_block_start == 31L
    )
  simulation <- simulate_goal005_task2_dataset(row, manifest)

  testthat::expect_identical(
    simulation$audit$training_active_camera_days,
    28L
  )
  testthat::expect_identical(simulation$audit$active_camera_count, 1L)
  testthat::expect_identical(
    nrow(simulation$training_data$observed),
    50L * 9L * 4L
  )
  testthat::expect_true(validate_flexirich_g_data(simulation$training_data))
  testthat::expect_false(any(c(
    "truth", "member", "true_richness", "alpha_fixed"
  ) %in% names(simulation$training_data)))
  testthat::expect_silent(.goal003_task4_validate_truth(simulation$truth))

  oracle <- prepare_goal005_candidate_oracle_data(
    simulation$training_data,
    stats::setNames(
      simulation$truth$species$alpha,
      simulation$truth$species$species_id
    )
  )
  testthat::expect_identical(
    oracle$alpha_fixed,
    simulation$truth$species$alpha
  )
})

testthat::test_that("Goal005 simulation is deterministic", {
  manifest <- read_goal005_task2_manifests()
  row <- manifest$datasets[77L, ]

  testthat::expect_identical(
    simulate_goal005_task2_dataset(row, manifest),
    simulate_goal005_task2_dataset(row, manifest)
  )
})
