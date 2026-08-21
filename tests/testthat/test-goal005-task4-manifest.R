testthat::test_that("Goal005 Task 4 manifest is bounded and deterministic", {
  manifest <- read_goal005_task4_manifest()

  testthat::expect_identical(nrow(manifest$profiles), 3L)
  testthat::expect_identical(nrow(manifest$datasets), 36L)
  testthat::expect_identical(nrow(manifest$calibrations), 36L)
  testthat::expect_identical(nrow(manifest$fits), 108L)
  testthat::expect_identical(
    manifest$profiles$profile_id,
    c("unbiased", "down_0.8", "up_1.25")
  )
  testthat::expect_equal(
    manifest$profiles$calibration_sd,
    rep(log(3) / stats::qnorm(0.975), 3L),
    tolerance = 1e-14
  )
  testthat::expect_identical(anyDuplicated(manifest$fits$fit_seed), 0L)
  testthat::expect_true(validate_goal005_task4_manifest(manifest))
})

testthat::test_that("Goal005 Task 4 calibration profiles differ only by bias", {
  manifest <- read_goal005_task4_manifest()
  selected <- manifest$calibrations |>
    dplyr::filter(replicate == 7L) |>
    dplyr::arrange(profile_code)
  unbiased <- selected |>
    dplyr::filter(profile_id == "unbiased")

  testthat::expect_equal(
    selected$routine_location_estimate -
      unbiased$routine_location_estimate[[1L]],
    c(0, -log(1.25), log(1.25)),
    tolerance = 1e-14
  )
  testthat::expect_equal(
    selected$occasional_location_estimate -
      unbiased$occasional_location_estimate[[1L]],
    c(0, -log(1.25), log(1.25)),
    tolerance = 1e-14
  )
})

testthat::test_that("Goal005 Task 4 histories are fresh and paired", {
  manifest <- read_goal005_task4_manifest()
  rows <- manifest$datasets |>
    dplyr::filter(replicate == 1L)
  low <- simulate_goal005_task4_dataset(
    rows |> dplyr::filter(true_richness == 10L),
    manifest
  )
  high <- simulate_goal005_task4_dataset(
    rows |> dplyr::filter(true_richness == 40L),
    manifest
  )

  testthat::expect_identical(low$audit$simulation_seed, 680000001L)
  testthat::expect_identical(
    low$truth$species$latent_normal,
    high$truth$species$latent_normal
  )
  testthat::expect_identical(low$truth$cameras, high$truth$cameras)
  testthat::expect_false(any(c(
    "truth", "member", "true_richness", "alpha_fixed"
  ) %in% names(low$training_data)))
})
