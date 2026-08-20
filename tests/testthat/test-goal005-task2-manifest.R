testthat::test_that("Goal005 Task 2 scenarios retain the aligned richness grid", {
  scenarios <- .goal005_task2_expected_scenarios()

  testthat::expect_identical(nrow(scenarios), 3L)
  testthat::expect_identical(scenarios$scenario_order, 1:3)
  testthat::expect_identical(scenarios$true_richness, c(10L, 25L, 40L))
  testthat::expect_identical(
    scenarios$routine_members,
    c(9L, 22L, 35L)
  )
  testthat::expect_identical(
    scenarios$occasional_members,
    c(1L, 3L, 5L)
  )
  testthat::expect_equal(
    scenarios$true_routine_median_rate,
    rep(0.002, 3L),
    tolerance = 0
  )
  testthat::expect_equal(
    scenarios$true_occasional_median_rate,
    rep(0.0005, 3L),
    tolerance = 0
  )
})

testthat::test_that("Goal005 Task 2 effort starts reproduce the paired design", {
  effort <- read_goal003_task4_manifests()$effort
  selected <- .goal005_task2_effort_starts(effort)

  testthat::expect_identical(nrow(selected), 60L)
  testthat::expect_identical(
    unique(selected$effort_block_start),
    c(1L, 13L, 25L, 31L, 39L, 49L, 58L, 72L, 83L, 91L, 100L, 124L)
  )
  testthat::expect_identical(
    unique(selected$train_occasions),
    c(4L, 8L, 12L, 16L, 26L)
  )
  expected_days <- matrix(as.integer(c(
    252, 504, 756, 1008, 1395,
    252, 493, 609, 667, 748,
    58, 97, 125, 265, 884,
    28, 56, 308, 560, 1021,
    252, 504, 745, 916, 1160,
    207, 335, 393, 530, 1009,
    46, 218, 410, 606, 1065,
    196, 386, 557, 733, 1293,
    162, 386, 610, 839, 1440,
    224, 453, 705, 943, 1525,
    252, 482, 706, 953, 1513,
    224, 457, 709, 961, 1591
  )), nrow = 12L, byrow = TRUE)
  observed_days <- selected |>
    tidyr::pivot_wider(
      id_cols = replicate,
      names_from = train_occasions,
      values_from = training_active_camera_days
    ) |>
    dplyr::select(-replicate) |>
    as.matrix()
  testthat::expect_identical(unname(observed_days), expected_days)
  testthat::expect_identical(
    range(selected$active_camera_count[selected$train_occasions == 4L]),
    c(1L, 9L)
  )
  testthat::expect_true(all(
    selected$active_camera_count[selected$train_occasions >= 16L] == 9L
  ))
})

testthat::test_that("Goal005 Task 2 manifests close at 180 datasets and 360 fits", {
  datasets <- .goal005_task2_expected_datasets()
  fits <- .goal005_task2_expected_fits()

  testthat::expect_identical(nrow(datasets), 180L)
  testthat::expect_identical(nrow(fits), 360L)
  testthat::expect_identical(anyDuplicated(datasets$dataset_id), 0L)
  testthat::expect_identical(anyDuplicated(fits$fit_id), 0L)
  testthat::expect_identical(anyDuplicated(fits$fit_seed), 0L)
  testthat::expect_identical(
    as.integer(table(fits$information_level)[c("C0", "I0")]),
    c(180L, 180L)
  )
  first_pair <- datasets$pair_id[[1L]]
  testthat::expect_identical(
    unique(datasets$simulation_seed[datasets$pair_id == first_pair]),
    650000001L
  )
})

testthat::test_that("tracked Goal005 Task 2 CSVs match their generators", {
  manifest <- read_goal005_task2_manifests()

  testthat::expect_true(validate_goal005_task2_manifests(
    manifest$scenarios,
    manifest$datasets,
    manifest$fits,
    manifest$effort
  ))
  testthat::expect_identical(length(manifest$hashes), 6L)
})
