.goal003_input_fixture <- function() {
  dates <- seq(as.Date("2020-01-01"), by = "day", length.out = 28L)
  operation_daily <- tidyr::expand_grid(
    camera_id = c("cam_b", "cam_a"),
    date = dates
  ) |>
    dplyr::mutate(
      active = as.integer(!(
        camera_id == "cam_b" &
          date >= as.Date("2020-01-08") &
          date <= as.Date("2020-01-14")
      ))
    )
  events <- tibble::tibble(
    event_id = c("event_1", "event_2", "event_3"),
    camera_id = c("cam_a", "cam_a", "cam_b"),
    species_id = c("sp_a", "sp_a", "sp_b"),
    event_time = as.POSIXct(
      c(
        "2020-01-01 08:00:00",
        "2020-01-02 08:00:00",
        "2020-01-15 08:00:00"
      ),
      tz = "Australia/Hobart"
    )
  )
  list(
    candidate_pool = tibble::tibble(
      species_id = c("sp_c", "sp_a", "sp_b")
    ),
    operation_daily = operation_daily,
    events = events
  )
}

.goal003_calendar_fixture <- function(n = 40L) {
  origin <- as.Date("2019-06-05")
  tibble::tibble(
    occasion_id = sprintf("occ_%03d", seq_len(n)),
    occasion_index = seq_len(n),
    start_date = origin + 7L * (seq_len(n) - 1L),
    end_date = origin + 7L * seq_len(n) - 1L
  )
}

testthat::test_that("Goal003 weekly inputs preserve effort and unseen candidates", {
  fixture <- .goal003_input_fixture()
  result <- build_goal003_weekly_inputs(
    fixture$candidate_pool,
    fixture$operation_daily,
    fixture$events
  )

  testthat::expect_identical(
    names(result),
    c(
      "candidate_pool", "occasion_calendar", "effort_weekly",
      "detections", "audit"
    )
  )
  testthat::expect_identical(result$candidate_pool$species_id, c(
    "sp_a", "sp_b", "sp_c"
  ))
  testthat::expect_equal(nrow(result$detections), 3L * 2L * 4L)
  zero_effort <- result$effort_weekly |>
    dplyr::filter(camera_id == "cam_b", occasion_id == "occ_002")
  testthat::expect_identical(zero_effort$active_days, 0L)
  testthat::expect_true(all(is.na(
    result$detections$detected[
      result$detections$camera_id == "cam_b" &
        result$detections$occasion_id == "occ_002"
    ]
  )))
  testthat::expect_identical(
    sum(result$detections$detected, na.rm = TRUE),
    2L
  )
  testthat::expect_false(any(
    result$detections$species_id == "sp_c" &
      result$detections$detected == 1L,
    na.rm = TRUE
  ))

  inference <- prepare_flexirich_g_data(
    result$candidate_pool,
    result$effort_weekly,
    result$detections
  )
  testthat::expect_true(validate_flexirich_g_data(inference))

  window <- prepare_goal003_analysis_window(
    result,
    result$occasion_calendar$occasion_id[2:3]
  )
  testthat::expect_identical(window$occasion_ids, c("occ_002", "occ_003"))
  testthat::expect_equal(nrow(window$observed), 3L * 2L * 2L)
})

testthat::test_that("Goal003 windows reject unknown or reordered occasions", {
  fixture <- .goal003_input_fixture()
  weekly <- build_goal003_weekly_inputs(
    fixture$candidate_pool,
    fixture$operation_daily,
    fixture$events
  )

  testthat::expect_error(
    prepare_goal003_analysis_window(weekly, "occ_999"),
    "unknown",
    fixed = TRUE
  )
  testthat::expect_error(
    prepare_goal003_analysis_window(weekly, c("occ_003", "occ_002")),
    "chronological",
    fixed = TRUE
  )
})

testthat::test_that("Goal003 weekly inputs reject effort and event leakage", {
  fixture <- .goal003_input_fixture()

  missing_effort <- fixture$operation_daily[-1L, ]
  testthat::expect_error(
    build_goal003_weekly_inputs(
      fixture$candidate_pool,
      missing_effort,
      fixture$events
    ),
    "complete camera-by-calendar-day grid"
  )

  inactive_event <- fixture$events
  inactive_event$camera_id[[1L]] <- "cam_b"
  inactive_event$event_time[[1L]] <- as.POSIXct(
    "2020-01-08 08:00:00",
    tz = "Australia/Hobart"
  )
  testthat::expect_error(
    build_goal003_weekly_inputs(
      fixture$candidate_pool,
      fixture$operation_daily,
      inactive_event
    ),
    "active camera-date"
  )

  duplicate_event <- dplyr::bind_rows(
    fixture$events,
    fixture$events[1L, ]
  )
  testthat::expect_error(
    build_goal003_weekly_inputs(
      fixture$candidate_pool,
      fixture$operation_daily,
      duplicate_event
    ),
    "one event per row"
  )
})

testthat::test_that("Goal003 folds have fixed future horizons without leakage", {
  folds <- make_goal003_temporal_folds(.goal003_calendar_fixture())

  testthat::expect_identical(
    as.integer(table(folds$training_occasions)[c("4", "26")]),
    c(9L, 3L)
  )
  testthat::expect_true(all(folds$forecast_occasions == 4L))
  testthat::expect_true(all(
    folds$train_end_index + 1L == folds$forecast_start_index
  ))
  testthat::expect_true(all(
    folds$forecast_end_index - folds$forecast_start_index == 3L
  ))
  overlap <- folds |>
    dplyr::arrange(training_occasions, forecast_start_index) |>
    dplyr::mutate(
      previous_end = dplyr::lag(forecast_end_index),
      .by = training_occasions
    ) |>
    dplyr::filter(
      !is.na(previous_end),
      forecast_start_index <= previous_end
    )
  testthat::expect_equal(nrow(overlap), 0L)
})

testthat::test_that("the pinned Judbury calendar supports the frozen fold design", {
  folds <- make_goal003_temporal_folds(.goal003_calendar_fixture(153L))
  support <- folds |>
    dplyr::summarise(
      n_folds = dplyr::n(),
      n_blocks = dplyr::n_distinct(uncertainty_block_id),
      .by = training_occasions
    ) |>
    dplyr::arrange(training_occasions)

  testthat::expect_identical(support$training_occasions, c(4L, 26L))
  testthat::expect_identical(support$n_folds, c(37L, 31L))
  testthat::expect_identical(support$n_blocks, c(12L, 10L))
  testthat::expect_identical(max(folds$forecast_end_index), 152L)
  testthat::expect_false(any(folds$forecast_end_index == 153L))
})
