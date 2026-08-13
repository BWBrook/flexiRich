testthat::test_that("Task 4 manifests reproduce the frozen screening design", {
  manifest <- read_goal003_task4_manifests()

  testthat::expect_identical(
    names(manifest),
    c("scenarios", "datasets", "fits", "effort", "hashes")
  )
  testthat::expect_true(validate_goal003_task4_manifests(
    manifest$scenarios,
    manifest$datasets,
    manifest$fits,
    manifest$effort
  ))
  testthat::expect_equal(nrow(manifest$scenarios), 5L)
  testthat::expect_equal(nrow(manifest$datasets), 300L)
  testthat::expect_equal(nrow(manifest$fits), 840L)
  testthat::expect_equal(nrow(manifest$effort), 9L * 153L)
  testthat::expect_identical(
    manifest$scenarios$scenario_id,
    c(
      "matched_low",
      "matched_mid",
      "matched_high",
      "guild_lower_tail",
      "seasonal_availability"
    )
  )
  testthat::expect_identical(
    manifest$scenarios$true_richness,
    c(10L, 25L, 40L, 25L, 25L)
  )
  testthat::expect_setequal(
    manifest$datasets$train_occasions,
    c(4L, 26L)
  )
  testthat::expect_true(all(manifest$datasets$forecast_occasions == 4L))
  testthat::expect_true(all(manifest$datasets$candidate_pool_size == 50L))
  testthat::expect_true(all(manifest$datasets$n_cameras == 9L))
  testthat::expect_equal(anyDuplicated(manifest$datasets$dataset_id), 0L)
  testthat::expect_equal(anyDuplicated(manifest$fits$fit_id), 0L)
  testthat::expect_equal(anyDuplicated(manifest$fits$fit_seed), 0L)
  testthat::expect_true(all(manifest$fits$dataset_id %in%
    manifest$datasets$dataset_id))
  testthat::expect_equal(
    sum(manifest$fits$run_role == "primary"),
    600L
  )
  testthat::expect_equal(
    sum(manifest$fits$run_role == "prior_sensitivity"),
    180L
  )
  testthat::expect_equal(
    sum(manifest$fits$run_role == "pool_sensitivity"),
    60L
  )
  testthat::expect_setequal(
    unique(manifest$fits$candidate_pool_size),
    c(50L, 106L)
  )
  testthat::expect_true(all(grepl("^[0-9a-f]{64}$", manifest$hashes)))
})

testthat::test_that("Task 4 effort is frozen without detection outcomes", {
  manifest <- read_goal003_task4_manifests()
  effort <- manifest$effort

  testthat::expect_identical(
    names(effort),
    c("camera_id", "occasion_index", "active_days")
  )
  testthat::expect_equal(length(unique(effort$camera_id)), 9L)
  testthat::expect_identical(
    sort(unique(effort$occasion_index)),
    seq_len(153L)
  )
  testthat::expect_true(all(effort$active_days %in% 0:7))
  testthat::expect_equal(sum(effort$active_days), 7644L)
  testthat::expect_equal(sum(effort$active_days == 0L), 266L)

  root <- if (dir.exists("R")) "." else file.path("..", "..")
  tracked <- c(
    file.path("R", "goal003_task4_manifest.R"),
    file.path("scripts", "check_goal003_task4_manifest.R"),
    file.path("docs", "goals", "003-prospective-finite-pool-validation",
              "Task4Manifest.md")
  )
  text <- tolower(paste(
    unlist(lapply(file.path(root, tracked), readLines, warn = FALSE)),
    collapse = "\n"
  ))
  testthat::expect_false(grepl("jc_obs", text, fixed = TRUE))
  testthat::expect_false(grepl("prospective outcome", text, fixed = TRUE))
})

testthat::test_that("Task 4 common random numbers and effort blocks are paired", {
  datasets <- read_goal003_task4_manifests()$datasets
  groups <- datasets |>
    dplyr::summarise(
      n_scenarios = dplyr::n_distinct(scenario_id),
      n_simulation_seeds = dplyr::n_distinct(simulation_seed),
      n_effort_starts = dplyr::n_distinct(effort_block_start),
      .by = c(train_occasions, replicate)
    )

  testthat::expect_equal(nrow(groups), 60L)
  testthat::expect_true(all(groups$n_scenarios == 5L))
  testthat::expect_true(all(groups$n_simulation_seeds == 1L))
  testthat::expect_true(all(groups$n_effort_starts == 1L))
  testthat::expect_equal(
    datasets$effort_block_end - datasets$effort_block_start + 1L,
    datasets$train_occasions + datasets$forecast_occasions
  )

  selected_starts <- lapply(c(4L, 26L), function(train_occasions) {
    max_start <- 153L - train_occasions - 4L + 1L
    .with_sim_rng(
      300300L + train_occasions,
      sample.int(max_start, 30L, replace = FALSE)
    )
  })
  names(selected_starts) <- c("4", "26")
  testthat::expect_identical(
    .goal003_task4_effort_starts(),
    selected_starts
  )
})

testthat::test_that("Task 4 validators reject altered frozen rows", {
  manifest <- read_goal003_task4_manifests()

  missing_dataset <- manifest$datasets[-1L, ]
  testthat::expect_error(
    validate_goal003_task4_manifests(
      manifest$scenarios,
      missing_dataset,
      manifest$fits,
      manifest$effort
    ),
    "frozen dataset rows",
    fixed = TRUE
  )

  altered_fit <- manifest$fits
  altered_fit$fit_seed[1L] <- altered_fit$fit_seed[1L] + 1L
  testthat::expect_error(
    validate_goal003_task4_manifests(
      manifest$scenarios,
      manifest$datasets,
      altered_fit,
      manifest$effort
    ),
    "frozen fit rows",
    fixed = TRUE
  )

  altered_effort <- manifest$effort
  altered_effort$active_days[1L] <- 1L - altered_effort$active_days[1L]
  testthat::expect_error(
    validate_goal003_task4_manifests(
      manifest$scenarios,
      manifest$datasets,
      manifest$fits,
      altered_effort
    ),
    "effort template",
    fixed = TRUE
  )
})
