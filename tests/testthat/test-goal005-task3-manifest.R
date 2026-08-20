testthat::test_that("Goal005 Task 3 manifest is bounded and deterministic", {
  manifest <- read_goal005_task3_manifest()

  testthat::expect_identical(nrow(manifest$levels), 7L)
  testthat::expect_identical(nrow(manifest$datasets), 108L)
  testthat::expect_identical(nrow(manifest$calibrations), 84L)
  testthat::expect_identical(nrow(manifest$fits), 756L)
  testthat::expect_identical(
    manifest$levels$precision_id,
    c("C0", "F1.10", "F1.25", "F1.50", "F2", "F3", "F5")
  )
  testthat::expect_equal(
    exp(stats::qnorm(0.975) * manifest$levels$calibration_sd),
    manifest$levels$multiplicative_factor,
    tolerance = 1e-14
  )
  testthat::expect_identical(
    sort(unique(manifest$datasets$train_occasions)),
    c(12L, 16L, 26L)
  )
  testthat::expect_identical(anyDuplicated(manifest$fits$fit_seed), 0L)
  testthat::expect_true(validate_goal005_task3_manifest(manifest))
})

testthat::test_that("Goal005 calibration errors are paired across precision", {
  manifest <- read_goal005_task3_manifest()
  selected <- manifest$calibrations |>
    dplyr::filter(replicate == 4L)
  truth <- c(routine = log(0.002), occasional = log(0.0005))
  finite <- selected |>
    dplyr::filter(calibration_sd > 0) |>
    dplyr::mutate(
      z_routine =
        (routine_location_estimate - truth[["routine"]]) / calibration_sd,
      z_occasional =
        (occasional_location_estimate - truth[["occasional"]]) /
          calibration_sd
    )

  testthat::expect_equal(
    finite$z_routine,
    rep(finite$z_routine[[1L]], nrow(finite)),
    tolerance = 1e-13
  )
  testthat::expect_equal(
    finite$z_occasional,
    rep(finite$z_occasional[[1L]], nrow(finite)),
    tolerance = 1e-13
  )
  c0 <- selected[selected$precision_id == "C0", ]
  testthat::expect_equal(c0$routine_location_estimate, truth[["routine"]])
  testthat::expect_equal(
    c0$occasional_location_estimate,
    truth[["occasional"]]
  )
})

testthat::test_that("Goal005 Task 3 histories are fresh and nested", {
  manifest <- read_goal005_task3_manifest()
  rows <- manifest$datasets |>
    dplyr::filter(replicate == 1L)
  low12 <- simulate_goal005_task3_dataset(
    rows |>
      dplyr::filter(true_richness == 10L, train_occasions == 12L),
    manifest
  )
  high26 <- simulate_goal005_task3_dataset(
    rows |>
      dplyr::filter(true_richness == 40L, train_occasions == 26L),
    manifest
  )

  testthat::expect_identical(low12$audit$simulation_seed, 660000001L)
  testthat::expect_identical(
    low12$truth$species$latent_normal,
    high26$truth$species$latent_normal
  )
  testthat::expect_identical(low12$truth$cameras, high26$truth$cameras)
  testthat::expect_false(any(c(
    "truth", "member", "true_richness", "alpha_fixed"
  ) %in% names(low12$training_data)))
})
