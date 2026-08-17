testthat::test_that("Goal004 Task 4 scenarios encode the frozen class grid", {
  scenarios <- .goal004_task4_expected_scenarios()

  testthat::expect_identical(nrow(scenarios), 9L)
  testthat::expect_identical(scenarios$scenario_order, seq_len(9L))
  testthat::expect_identical(
    unique(scenarios$fidelity),
    c("aligned", "weak_signal", "ten_percent_flipped")
  )
  testthat::expect_identical(
    scenarios$true_richness,
    rep(c(10L, 25L, 40L), times = 3L)
  )
  testthat::expect_equal(
    unique(scenarios$true_routine_median_rate[scenarios$fidelity == "weak_signal"]),
    0.001840375301250,
    tolerance = 1e-14
  )
  testthat::expect_equal(
    unique(scenarios$true_occasional_median_rate[scenarios$fidelity == "weak_signal"]),
    0.000920187650625,
    tolerance = 1e-14
  )
  testthat::expect_identical(
    scenarios$flipped_count,
    c(rep(0L, 6L), rep(5L, 3L))
  )
})

testthat::test_that("Goal004 Task 4 effort blocks reproduce the frozen rule", {
  goal003 <- read_goal003_task4_manifests()
  selected <- dplyr::bind_rows(
    .goal004_task4_select_effort_starts(goal003$effort, 4L),
    .goal004_task4_select_effort_starts(goal003$effort, 26L)
  )

  testthat::expect_identical(selected, .goal004_task4_effort_starts())
  testthat::expect_identical(
    selected$training_active_camera_days,
    c(
      28L, 82L, 171L, 196L, 224L, 224L, 243L, 252L, 252L, 252L,
      748L, 884L, 1009L, 1065L, 1160L, 1293L, 1440L, 1513L,
      1525L, 1591L
    )
  )
})

testthat::test_that("Goal004 Task 4 manifests close at 180 datasets and 750 fits", {
  datasets <- .goal004_task4_expected_datasets()
  fits <- .goal004_task4_expected_fits()

  testthat::expect_identical(nrow(datasets), 180L)
  testthat::expect_identical(nrow(fits), 750L)
  testthat::expect_identical(anyDuplicated(datasets$dataset_id), 0L)
  testthat::expect_identical(anyDuplicated(fits$fit_id), 0L)
  testthat::expect_identical(anyDuplicated(fits$fit_seed), 0L)
  testthat::expect_identical(
    as.integer(table(fits$method)[c(
      "goal003", "goal004", "goal004_nested", "occupancy"
    )]),
    c(180L, 360L, 30L, 180L)
  )
  testthat::expect_identical(
    sum(fits$run_role == "prior_sensitivity"),
    180L
  )
  testthat::expect_identical(
    sum(fits$method == "goal004" & fits$prior_profile == "class_blur"),
    60L
  )
  testthat::expect_identical(
    unique(datasets$simulation_seed[datasets$pair_id == datasets$pair_id[[1L]]]),
    440000401L
  )
})

testthat::test_that("tracked Goal004 Task 4 CSVs match their generators", {
  manifest <- read_goal004_task4_manifests()

  testthat::expect_true(validate_goal004_task4_manifests(
    manifest$scenarios,
    manifest$datasets,
    manifest$fits,
    manifest$effort
  ))
  testthat::expect_identical(length(manifest$hashes), 6L)
})
