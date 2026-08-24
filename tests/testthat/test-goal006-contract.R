testthat::test_that("Goal006 sources, candidates, and effort are content-frozen", {
  contract <- read_goal006_task1_contract(verify_external = FALSE)

  testthat::expect_identical(
    names(contract),
    c(
      "sources", "candidates", "effort", "folds", "synthetic",
      "calibration_fits", "target_fits", "gates", "output_schema",
      "model", "hashes"
    )
  )
  testthat::expect_equal(nrow(contract$sources), 6L)
  testthat::expect_true(all(grepl(
    "^[0-9a-f]{64}$",
    contract$sources$sha256
  )))
  testthat::expect_equal(nrow(contract$candidates), 50L)
  testthat::expect_identical(
    as.integer(table(contract$candidates$encounter_class)[
      c("occasional", "routine")
    ]),
    c(6L, 44L)
  )
  testthat::expect_equal(nrow(contract$effort), 9L * 153L)
  testthat::expect_equal(sum(contract$effort$active_days), 7644L)
  testthat::expect_equal(sum(contract$effort$active_days == 0L), 266L)
  testthat::expect_true(all(grepl("^[0-9a-f]{64}$", contract$hashes)))
})

testthat::test_that("Goal006 folds are paired, nested, and outcome-free", {
  contract <- read_goal006_task1_contract(verify_external = FALSE)
  folds <- contract$folds

  testthat::expect_equal(nrow(folds), 90L)
  testthat::expect_equal(length(unique(folds$forecast_id)), 18L)
  testthat::expect_identical(
    sort(unique(folds$forecast_start_index)),
    seq(81L, 149L, 4L)
  )
  testthat::expect_true(all(table(folds$training_occasions) == 18L))
  testthat::expect_identical(
    sort(unique(folds$training_occasions)),
    c(4L, 8L, 12L, 16L, 26L)
  )
  testthat::expect_true(all(
    folds$train_end_index + 1L == folds$forecast_start_index
  ))
  testthat::expect_true(all(
    folds$forecast_end_index - folds$forecast_start_index == 3L
  ))
  testthat::expect_equal(length(unique(folds$uncertainty_block_id)), 6L)

  paired <- folds |>
    dplyr::summarise(
      n_durations = dplyr::n_distinct(training_occasions),
      n_forecast_windows = dplyr::n_distinct(paste(
        forecast_start_index,
        forecast_end_index
      )),
      n_forecast_efforts = dplyr::n_distinct(paste(
        forecast_active_station_days,
        forecast_active_stations,
        forecast_zero_effort_station_weeks
      )),
      .by = forecast_id
    )
  testthat::expect_true(all(paired$n_durations == 5L))
  testthat::expect_true(all(paired$n_forecast_windows == 1L))
  testthat::expect_true(all(paired$n_forecast_efforts == 1L))
  testthat::expect_true(all(
    folds$duration_role[folds$training_occasions %in% c(4L, 8L)] ==
      "negative_control"
  ))
  testthat::expect_true(all(
    folds$duration_role[folds$training_occasions %in% c(12L, 16L, 26L)] ==
      "eligible"
  ))

  root <- if (dir.exists("R")) "." else file.path("..", "..")
  manifest_hash <- digest::digest(
    file = file.path(root, "config", "goal006_validation_folds.csv"),
    algo = "sha256",
    serialize = FALSE
  )
  testthat::expect_identical(
    manifest_hash,
    "aa881d46343ea6ec0f15b706ad15f3e97b43783b62db9bb723e48bc9cb3f9f8e"
  )
})

testthat::test_that("Goal006 schedules and seeds are complete and bounded", {
  contract <- read_goal006_task1_contract(verify_external = FALSE)

  testthat::expect_equal(nrow(contract$synthetic), 30L)
  testthat::expect_true(all(table(contract$synthetic$profile_id) == 10L))
  testthat::expect_equal(anyDuplicated(contract$synthetic$simulation_seed), 0L)
  testthat::expect_equal(anyDuplicated(contract$synthetic$fit_seed), 0L)
  testthat::expect_true(all(contract$synthetic$true_members == 50L))

  testthat::expect_equal(nrow(contract$calibration_fits), 17L)
  testthat::expect_identical(
    contract$calibration_fits$calibration_profile[1:4],
    c("primary", "prior_wide", "spread_lower", "spread_upper")
  )
  testthat::expect_equal(
    sum(grepl("^loso_", contract$calibration_fits$calibration_profile)),
    9L
  )
  testthat::expect_equal(
    sum(grepl(
      "^leave_quarter_",
      contract$calibration_fits$calibration_profile
    )),
    4L
  )
  testthat::expect_equal(anyDuplicated(contract$calibration_fits$fit_seed), 0L)

  testthat::expect_equal(nrow(contract$target_fits), 234L)
  testthat::expect_equal(anyDuplicated(contract$target_fits$fit_id), 0L)
  testthat::expect_equal(anyDuplicated(contract$target_fits$fit_seed), 0L)
  counts <- contract$target_fits |>
    dplyr::count(method, fit_profile)
  testthat::expect_equal(
    counts$n[counts$method == "flexirich" & counts$fit_profile == "primary"],
    90L
  )
  testthat::expect_equal(
    counts$n[counts$method == "occupancy"],
    90L
  )
  testthat::expect_true(all(
    counts$n[counts$fit_profile == "calibration_envelope_artifact"] == 54L
  ))
})

testthat::test_that("Goal006 numerical gates encode the approved stop surface", {
  gates <- read_goal006_task1_contract(verify_external = FALSE)$gates

  testthat::expect_equal(nrow(gates), 50L)
  testthat::expect_equal(anyDuplicated(gates$gate_id), 0L)
  testthat::expect_true(all(gates$required_for_advance))
  testthat::expect_identical(
    as.integer(table(gates$stage)[c("task2", "task3", "task4", "task5")]),
    c(12L, 15L, 19L, 4L)
  )
  threshold <- function(id) gates$threshold[gates$gate_id == id]
  testthat::expect_equal(threshold("T3-primary-F"), 2)
  testthat::expect_equal(threshold("T3-wide-shift"), log(1.5))
  testthat::expect_equal(threshold("T4-count-skill"), 0.10)
  testthat::expect_equal(threshold("T4-count-skill-lower"), -0.05)
  testthat::expect_equal(threshold("T4-identity-ratio-upper"), 1.05)
  testthat::expect_equal(threshold("T4-reference-compatible"), 16)
  testthat::expect_equal(threshold("T4-sensitivity-median"), 3)
  testthat::expect_equal(threshold("T4-sensitivity-max"), 8)
})

testthat::test_that("Goal006 calibration artifact cannot carry identity leakage", {
  schema <- goal006_output_schema()$calibration_artifact
  forbidden <- c(
    "candidate", "species", "membership", "detected", "history",
    "individual_rate"
  )
  testthat::expect_false(any(vapply(forbidden, function(term) {
    any(grepl(term, schema, fixed = TRUE))
  }, logical(1))))

  body_text <- paste(deparse(body(verify_goal006_source_receipts)), collapse = "\n")
  testthat::expect_false(grepl("read.csv", body_text, fixed = TRUE))
  testthat::expect_false(grepl("readRDS", body_text, fixed = TRUE))
})
