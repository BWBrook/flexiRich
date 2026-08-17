testthat::test_that("Goal004 Task 4 simulations are deterministic and nested", {
  manifest <- read_goal004_task4_manifests()
  rows <- manifest$datasets |>
    dplyr::filter(
      fidelity == "aligned",
      train_occasions == 4L,
      replicate == 1L
    )
  simulations <- lapply(seq_len(nrow(rows)), function(index) {
    simulate_goal004_task4_dataset(rows[index, ], manifest)
  })
  names(simulations) <- rows$scenario_id

  testthat::expect_identical(
    simulations[[1L]],
    simulate_goal004_task4_dataset(rows[1L, ], manifest)
  )
  testthat::expect_true(validate_flexirich_g_data(
    simulations[[1L]]$training_data
  ))
  testthat::expect_false(any(c("truth", "member", "true_richness") %in%
    names(simulations[[1L]]$training_data)))
  member_ids <- lapply(simulations, function(simulation) {
    dplyr::filter(simulation$truth$species, member)$species_id
  })
  testthat::expect_true(all(member_ids[[1L]] %in% member_ids[[2L]]))
  testthat::expect_true(all(member_ids[[2L]] %in% member_ids[[3L]]))
  testthat::expect_identical(
    unname(vapply(simulations, function(x) {
      x$truth$true_richness
    }, integer(1))),
    c(10L, 25L, 40L)
  )
  testthat::expect_identical(
    simulations[[1L]]$truth$species$latent_normal,
    simulations[[3L]]$truth$species$latent_normal
  )
  testthat::expect_identical(
    simulations[[1L]]$truth$cameras,
    simulations[[3L]]$truth$cameras
  )
  testthat::expect_lt(
    abs(sum(simulations[[1L]]$truth$cameras$camera_effect)),
    1e-14
  )
})

testthat::test_that("Goal004 class-fidelity transformations are exact", {
  manifest <- read_goal004_task4_manifests()
  rows <- manifest$datasets |>
    dplyr::filter(
      true_richness == 25L,
      train_occasions == 26L,
      replicate == 2L
    )
  simulations <- lapply(seq_len(nrow(rows)), function(index) {
    simulate_goal004_task4_dataset(rows[index, ], manifest)
  })
  names(simulations) <- rows$fidelity
  aligned <- simulations$aligned
  weak <- simulations$weak_signal
  flipped <- simulations$ten_percent_flipped

  testthat::expect_identical(
    aligned$truth$species$member,
    weak$truth$species$member
  )
  testthat::expect_identical(
    aligned$truth$species$member,
    flipped$truth$species$member
  )
  testthat::expect_identical(
    aligned$truth$species$latent_normal,
    weak$truth$species$latent_normal
  )
  testthat::expect_identical(
    aligned$truth$cameras,
    flipped$truth$cameras
  )
  testthat::expect_identical(length(flipped$audit$flipped_candidate_ids), 5L)
  reviewed <- flipped$audit$reviewed_encounter_class
  actual <- stats::setNames(
    flipped$truth$species$guild,
    flipped$truth$species$species_id
  )
  testthat::expect_identical(sum(reviewed != actual), 5L)

  aligned_scenario <- manifest$scenarios |>
    dplyr::filter(scenario_id == "aligned_mid")
  expected_alpha <- ifelse(
    aligned$truth$species$guild == "routine",
    log(aligned_scenario$true_routine_median_rate),
    log(aligned_scenario$true_occasional_median_rate)
  ) + aligned$truth$species$latent_normal
  testthat::expect_equal(
    aligned$truth$species$alpha,
    expected_alpha,
    tolerance = 1e-14
  )
})

testthat::test_that("Goal004 effort and truth respect the frozen block", {
  manifest <- read_goal004_task4_manifests()
  row <- manifest$datasets |>
    dplyr::filter(
      scenario_id == "aligned_mid",
      train_occasions == 4L,
      replicate == 1L
    )
  simulation <- simulate_goal004_task4_dataset(row, manifest)

  testthat::expect_identical(
    simulation$audit$training_active_camera_days,
    28L
  )
  testthat::expect_identical(
    simulation$audit$forecast_active_camera_days,
    28L
  )
  testthat::expect_identical(
    nrow(simulation$training_data$observed),
    50L * 9L * 4L
  )
  zero <- simulation$training_data$observed$active_days == 0L
  testthat::expect_true(all(is.na(
    simulation$training_data$observed$detected[zero]
  )))
  nonmember <- simulation$truth$species$species_id[
    !simulation$truth$species$member
  ]
  testthat::expect_identical(
    sum(
      simulation$training_data$observed$detected[
        simulation$training_data$observed$species_id %in% nonmember
      ],
      na.rm = TRUE
    ),
    0L
  )
  testthat::expect_silent(.goal003_task4_validate_truth(simulation$truth))
})

testthat::test_that("Goal004 simulations remain compatible with baselines", {
  manifest <- read_goal004_task4_manifests()
  row <- manifest$datasets[1L, ]
  simulation <- simulate_goal004_task4_dataset(row, manifest)
  baseline <- evaluate_goal003_task4_baselines(simulation)

  testthat::expect_true(tibble::is_tibble(baseline$point_predictions))
  testthat::expect_true(tibble::is_tibble(baseline$richness_scores))
  testthat::expect_true(tibble::is_tibble(baseline$discovery_scores))
})
