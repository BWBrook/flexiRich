testthat::test_that("Task 4 matched simulations are deterministic and nested", {
  manifest <- read_goal003_task4_manifests()
  rows <- manifest$datasets |>
    dplyr::filter(
      train_occasions == 4L,
      replicate == 1L,
      scenario_id %in% c("matched_low", "matched_mid", "matched_high")
    )
  simulations <- lapply(seq_len(nrow(rows)), function(index) {
    simulate_goal003_task4_dataset(rows[index, ], manifest)
  })
  names(simulations) <- rows$scenario_id

  repeated <- simulate_goal003_task4_dataset(rows[1L, ], manifest)
  testthat::expect_identical(simulations$matched_low, repeated)
  testthat::expect_identical(
    names(simulations$matched_low),
    c("dataset_id", "training_data", "forecast_effort", "truth", "audit")
  )
  testthat::expect_true(validate_flexirich_g_data(
    simulations$matched_low$training_data
  ))
  testthat::expect_false(any(c("truth", "member", "true_richness") %in%
    names(simulations$matched_low$training_data)))

  low_members <- simulations$matched_low$truth$species$species_id[
    simulations$matched_low$truth$species$member
  ]
  mid_members <- simulations$matched_mid$truth$species$species_id[
    simulations$matched_mid$truth$species$member
  ]
  high_members <- simulations$matched_high$truth$species$species_id[
    simulations$matched_high$truth$species$member
  ]
  testthat::expect_true(all(low_members %in% mid_members))
  testthat::expect_true(all(mid_members %in% high_members))
  testthat::expect_identical(
    simulations$matched_low$truth$species$latent_normal,
    simulations$matched_high$truth$species$latent_normal
  )
  testthat::expect_identical(
    simulations$matched_low$truth$cameras,
    simulations$matched_high$truth$cameras
  )
  testthat::expect_equal(
    sum(simulations$matched_low$truth$cameras$camera_effect),
    0,
    tolerance = 1e-14
  )
})

testthat::test_that("Task 4 effort and truth use the declared train-forecast block", {
  manifest <- read_goal003_task4_manifests()
  row <- manifest$datasets |>
    dplyr::filter(
      scenario_id == "matched_mid",
      train_occasions == 26L,
      replicate == 2L
    )
  simulation <- simulate_goal003_task4_dataset(row, manifest)
  effort <- manifest$effort |>
    dplyr::filter(
      occasion_index >= row$effort_block_start,
      occasion_index <= row$effort_block_end
    )

  testthat::expect_equal(
    nrow(simulation$training_data$observed),
    50L * 9L * 26L
  )
  testthat::expect_equal(nrow(simulation$forecast_effort), 9L * 4L)
  testthat::expect_identical(
    as.integer(simulation$audit$effort_block_start),
    row$effort_block_start
  )
  testthat::expect_equal(
    sum(simulation$training_data$observed$active_days) / 50,
    sum(effort$active_days[effort$occasion_index <
      row$effort_block_start + row$train_occasions])
  )
  zero_effort <- simulation$training_data$observed$active_days == 0L
  testthat::expect_true(all(is.na(
    simulation$training_data$observed$detected[zero_effort]
  )))
  nonmembers <- !simulation$truth$species$member
  nonmember_ids <- simulation$truth$species$species_id[nonmembers]
  testthat::expect_equal(
    sum(
      simulation$training_data$observed$detected[
        simulation$training_data$observed$species_id %in% nonmember_ids
      ],
      na.rm = TRUE
    ),
    0L
  )
  testthat::expect_identical(
    simulation$truth$true_new_species,
    as.integer(sum(simulation$truth$species$future_first_detection))
  )
})

testthat::test_that("Task 4 misspecifications implement the frozen mechanisms", {
  manifest <- read_goal003_task4_manifests()
  select_row <- function(scenario) {
    manifest$datasets |>
      dplyr::filter(
        scenario_id == scenario,
        train_occasions == 26L,
        replicate == 1L
      )
  }
  guild <- simulate_goal003_task4_dataset(
    select_row("guild_lower_tail"),
    manifest
  )
  seasonal <- simulate_goal003_task4_dataset(
    select_row("seasonal_availability"),
    manifest
  )

  guild_members <- guild$truth$species |>
    dplyr::filter(member)
  testthat::expect_equal(sum(guild_members$guild == "cryptic"), 5L)
  testthat::expect_equal(sum(guild_members$guild == "ordinary"), 20L)
  testthat::expect_true(all(
    guild$truth$species$guild[!guild$truth$species$member] == "nonmember"
  ))

  seasonal_members <- seasonal$truth$species |>
    dplyr::filter(member)
  phase_counts <- table(seasonal_members$season_phase)
  testthat::expect_lte(max(phase_counts) - min(phase_counts), 1L)
  multipliers <- goal003_task4_seasonal_multipliers(
    seasonal_members$season_phase,
    seq_len(52L),
    active_multiplier = 3.4,
    inactive_multiplier = 0.2
  )
  testthat::expect_equal(rowMeans(multipliers), rep(1, 25L), tolerance = 1e-14)
})

testthat::test_that("Task 4 broader-pool sensitivity adds only all-zero candidates", {
  manifest <- read_goal003_task4_manifests()
  row <- manifest$datasets |>
    dplyr::filter(
      scenario_id == "matched_mid",
      train_occasions == 4L,
      replicate == 1L
    )
  simulation <- simulate_goal003_task4_dataset(row, manifest)
  expanded <- expand_goal003_task4_candidate_pool(
    simulation$training_data,
    candidate_pool_size = 106L
  )

  testthat::expect_true(validate_flexirich_g_data(expanded))
  testthat::expect_equal(length(expanded$candidate_ids), 106L)
  original <- dplyr::filter(
    expanded$observed,
    species_id %in% simulation$training_data$candidate_ids
  )
  testthat::expect_identical(original, simulation$training_data$observed)
  added <- dplyr::filter(
    expanded$observed,
    !species_id %in% simulation$training_data$candidate_ids,
    active_days > 0L
  )
  testthat::expect_true(all(added$detected == 0L))
})
