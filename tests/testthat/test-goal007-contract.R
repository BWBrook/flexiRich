testthat::test_that("Goal007 candidates encode the proposed shared-shift priors", {
  models <- goal007_expected_models()

  testthat::expect_identical(
    models$model_id,
    c("independent", "shared_F5", "shared_F3")
  )
  testthat::expect_equal(nrow(models), 3L)
  testthat::expect_equal(
    exp(.goal007_q975 * models$contrast_sd[models$model_id == "shared_F5"]),
    5,
    tolerance = 1e-12
  )
  testthat::expect_equal(
    exp(.goal007_q975 * models$contrast_sd[models$model_id == "shared_F3"]),
    3,
    tolerance = 1e-12
  )
  testthat::expect_identical(
    models$model_id[order(models$selection_priority, na.last = NA)],
    c("shared_F5", "shared_F3")
  )
  testthat::expect_error(goal007_contrast_sd(1), "greater than one")
  testthat::expect_error(goal007_contrast_sd(c(3, 5)), "one finite number")
})

testthat::test_that("Goal007 rate profiles match their common-shift semantics", {
  profiles <- goal007_expected_profiles()
  base <- goal007_model_contract()$base_location
  implied_routine <- base[["routine"]] + profiles$common_shift
  implied_occasional <- base[["occasional"]] + profiles$common_shift +
    profiles$contrast_deviation

  testthat::expect_equal(nrow(profiles), 6L)
  testthat::expect_identical(
    as.integer(table(profiles$screen_role)[c("core", "stress")]),
    c(5L, 1L)
  )
  testthat::expect_equal(log(profiles$routine_rate), implied_routine, tolerance = 1e-14)
  testthat::expect_equal(
    log(profiles$occasional_rate),
    implied_occasional,
    tolerance = 1e-14
  )
  testthat::expect_equal(
    profiles$occasional_rate[profiles$profile_id == "no_separation"],
    profiles$routine_rate[profiles$profile_id == "no_separation"]
  )
})

testthat::test_that("Goal007 Task 2 is paired, fresh, and fixed-denominator", {
  contract <- read_goal007_task1_contract(verify_external = FALSE)
  datasets <- contract$task2_datasets
  fits <- contract$task2_fits

  testthat::expect_equal(nrow(datasets), 60L)
  testthat::expect_true(all(table(datasets$profile_id) == 10L))
  testthat::expect_true(all(datasets$true_members == 50L))
  testthat::expect_equal(anyDuplicated(datasets$simulation_seed), 0L)
  testthat::expect_false(any(datasets$simulation_seed %in%
    goal006_expected_synthetic_manifest()$simulation_seed))

  testthat::expect_equal(nrow(fits), 180L)
  testthat::expect_true(all(table(fits$dataset_id) == 3L))
  testthat::expect_true(all(table(fits$model_id) == 60L))
  testthat::expect_equal(anyDuplicated(fits$fit_id), 0L)
  testthat::expect_equal(anyDuplicated(fits$fit_seed), 0L)
  testthat::expect_true(all(fits$fit_seed < .Machine$integer.max))
})

testthat::test_that("Goal007 Task 3 streams are nested and effort-balanced", {
  contract <- read_goal007_task1_contract(verify_external = FALSE)
  datasets <- contract$task3_datasets
  windows <- contract$task3_windows

  testthat::expect_equal(nrow(datasets), 48L)
  testthat::expect_true(all(table(datasets$profile_id) == 12L))
  testthat::expect_true(all(table(datasets$richness_id) == 16L))
  testthat::expect_true(all(table(
    datasets$profile_id,
    datasets$richness_id
  ) == 4L))
  testthat::expect_true(all(table(datasets$stream_id) == 3L))
  testthat::expect_true(all(table(datasets$simulation_seed) == 3L))
  testthat::expect_true(all(datasets$persistent_species_rates))
  testthat::expect_identical(
    sort(unique(datasets$forecast_start_index)),
    c(81L, 105L, 129L, 149L)
  )

  testthat::expect_equal(nrow(windows), 12L)
  testthat::expect_true(all(table(windows$replicate) == 3L))
  testthat::expect_true(all(table(windows$training_occasions) == 4L))
  testthat::expect_identical(
    sort(unique(windows$training_occasions)),
    c(12L, 16L, 26L)
  )
  testthat::expect_equal(
    min(windows$target_active_station_days[
      windows$training_occasions == 26L
    ]),
    1007L
  )
  testthat::expect_equal(
    max(windows$target_active_station_days[
      windows$training_occasions == 26L
    ]),
    1584L
  )
})

testthat::test_that("Goal007 Task 3 alternative branches are exact and bounded", {
  contract <- read_goal007_task1_contract(verify_external = FALSE)

  for (selected in c("shared_F5", "shared_F3")) {
    branch <- contract$task3_branches[[selected]]
    calibration <- branch$calibration_fits
    target <- branch$target_fits

    testthat::expect_equal(nrow(calibration), 96L)
    testthat::expect_equal(nrow(target), 288L)
    testthat::expect_setequal(
      unique(calibration$model_id),
      c("independent", selected)
    )
    testthat::expect_setequal(
      unique(target$model_id),
      c("independent", selected)
    )
    testthat::expect_true(all(table(calibration$dataset_id) == 2L))
    testthat::expect_true(all(table(target$dataset_id) == 6L))
    testthat::expect_true(all(table(target$training_occasions) == 96L))
    testthat::expect_equal(anyDuplicated(calibration$fit_id), 0L)
    testthat::expect_equal(anyDuplicated(calibration$fit_seed), 0L)
    testthat::expect_equal(anyDuplicated(target$fit_id), 0L)
    testthat::expect_equal(anyDuplicated(target$fit_seed), 0L)
    testthat::expect_true(all(calibration$fit_seed < .Machine$integer.max))
    testthat::expect_true(all(target$fit_seed < .Machine$integer.max))
  }
  testthat::expect_error(
    goal007_expected_task3_calibration_fits("independent"),
    "shared_F5 or shared_F3"
  )
})

testthat::test_that("Goal007 gates and output schemas preserve the freeze", {
  contract <- read_goal007_task1_contract(verify_external = FALSE)
  gates <- contract$gates

  testthat::expect_equal(nrow(gates), 54L)
  testthat::expect_equal(anyDuplicated(gates$gate_id), 0L)
  testthat::expect_identical(
    as.integer(table(gates$stage)[c("task2", "task3")]),
    c(26L, 28L)
  )
  testthat::expect_equal(
    gates$threshold[gates$gate_id == "T2-rare-rmse-ratio"],
    0.90
  )
  testthat::expect_equal(
    gates$threshold[gates$gate_id == "T3-rps-gain"],
    0.40
  )
  testthat::expect_false(gates$required_for_advance[
    gates$gate_id == "T3-earned-rps"
  ])
  testthat::expect_false(gates$required_for_advance[
    gates$gate_id == "T3-earned-catastrophic"
  ])
  testthat::expect_true(gates$required_for_advance[
    gates$gate_id == "T3-earned-redesign"
  ])

  artifact <- contract$output_schema$calibration_artifact
  testthat::expect_false(any(vapply(
    .goal007_forbidden_artifact_terms,
    function(term) any(grepl(term, artifact, fixed = TRUE)),
    logical(1)
  )))
  testthat::expect_true(all(grepl("^[0-9a-f]{64}$", contract$hashes)))
})

testthat::test_that("Goal007 contract construction does not read empirical outcomes", {
  functions <- c(
    "goal007_expected_models",
    "goal007_expected_profiles",
    "goal007_expected_task2_datasets",
    "goal007_expected_task2_fits",
    "goal007_expected_task3_datasets",
    "goal007_expected_task3_calibration_fits",
    "goal007_expected_task3_target_fits",
    "read_goal007_task1_contract"
  )
  text <- paste(vapply(functions, function(name) {
    paste(deparse(body(get(name, mode = "function"))), collapse = "\n")
  }, character(1)), collapse = "\n")
  forbidden <- c(
    "read.csv", "readRDS", "jc_obs", "detected_ever", "Huon",
    "empirical"
  )
  testthat::expect_false(any(vapply(
    forbidden,
    grepl,
    logical(1),
    x = text,
    fixed = TRUE
  )))
})
