testthat::test_that("daily effort has complete ordered camera-date coverage", {
  config <- flexirich_sim_config(n_cameras = 3L, n_occasions = 4L, seed = 10L)
  daily <- simulate_daily_effort(config)

  expected_cameras <- sprintf("cam_%02d", seq_len(config$n_cameras))
  expected_dates <- seq(
    config$start_date,
    by = "day",
    length.out = config$n_occasions * config$occasion_days
  )

  testthat::expect_s3_class(daily, "tbl_df")
  testthat::expect_named(daily, c("camera_id", "date", "operating"))
  testthat::expect_equal(nrow(daily), 3L * 4L * 7L)
  testthat::expect_true(all(daily$operating %in% c(0L, 1L)))
  testthat::expect_identical(
    daily$camera_id,
    rep(expected_cameras, each = length(expected_dates))
  )
  testthat::expect_equal(
    daily$date,
    rep(expected_dates, times = length(expected_cameras))
  )
})

testthat::test_that("camera ordering follows configured position at 100 cameras", {
  config <- flexirich_sim_config(
    n_cameras = 100L,
    n_occasions = 1L,
    seed = 101L
  )
  expected_cameras <- sprintf("cam_%02d", seq_len(config$n_cameras))

  daily <- simulate_daily_effort(config)
  weekly <- aggregate_weekly_effort(daily, config)

  testthat::expect_identical(unique(daily$camera_id), expected_cameras)
  testthat::expect_identical(unique(weekly$camera_id), expected_cameras)
})

testthat::test_that("configured failure and repair probabilities control operation", {
  failure_config <- flexirich_sim_config(
    n_cameras = 1L,
    n_occasions = 1L,
    initial_operating_prob = 1,
    daily_failure_prob = 1,
    daily_repair_prob = 0,
    seed = 11L
  )
  failure_daily <- simulate_daily_effort(failure_config)

  testthat::expect_identical(
    failure_daily$operating,
    c(1L, rep(0L, 6L))
  )

  repair_config <- flexirich_sim_config(
    n_cameras = 1L,
    n_occasions = 1L,
    initial_operating_prob = 0,
    daily_failure_prob = 0,
    daily_repair_prob = 1,
    seed = 12L
  )
  repair_daily <- simulate_daily_effort(repair_config)

  testthat::expect_identical(
    repair_daily$operating,
    c(0L, rep(1L, 6L))
  )
})

testthat::test_that("weekly effort is the exact daily sum", {
  config <- flexirich_sim_config(n_cameras = 2L, n_occasions = 2L, seed = 20L)
  daily <- simulate_daily_effort(config)
  weekly <- aggregate_weekly_effort(daily, config)

  recomputed <- daily |>
    dplyr::mutate(
      occasion_index = as.integer(date - config$start_date) %/% 7L + 1L,
      occasion_id = sprintf("occ_%03d", occasion_index)
    ) |>
    dplyr::summarise(
      active_days_expected = sum(operating),
      .by = c(camera_id, occasion_id)
    )

  joined <- dplyr::left_join(
    weekly, recomputed, by = c("camera_id", "occasion_id")
  )
  testthat::expect_named(
    weekly,
    c(
      "camera_id", "occasion_id", "occasion_start", "occasion_end",
      "active_days"
    )
  )
  testthat::expect_equal(joined$active_days, joined$active_days_expected)
  testthat::expect_true(
    all(weekly$active_days >= 0L & weekly$active_days <= 7L)
  )
  testthat::expect_identical(
    weekly$camera_id,
    rep(c("cam_01", "cam_02"), each = 2L)
  )
  testthat::expect_identical(
    weekly$occasion_id,
    rep(c("occ_001", "occ_002"), times = 2L)
  )
  testthat::expect_identical(
    weekly$occasion_start,
    rep(config$start_date + c(0L, 7L), times = 2L)
  )
  testthat::expect_identical(
    weekly$occasion_end,
    rep(config$start_date + c(6L, 13L), times = 2L)
  )
})

testthat::test_that("supplied daily effort is validated and ordered", {
  config <- flexirich_sim_config(n_cameras = 2L, n_occasions = 1L)
  expected_cameras <- c("cam_01", "cam_02")
  expected_dates <- seq(config$start_date, by = "day", length.out = 7L)
  supplied <- tidyr::expand_grid(
    camera_id = rev(expected_cameras),
    date = rev(expected_dates)
  ) |>
    dplyr::mutate(operating = rep(c(0L, 1L), length.out = dplyr::n()))

  validated <- validate_daily_effort(supplied, config)

  testthat::expect_s3_class(validated, "tbl_df")
  testthat::expect_type(validated$operating, "integer")
  testthat::expect_identical(
    validated$camera_id,
    rep(expected_cameras, each = length(expected_dates))
  )
  testthat::expect_equal(
    validated$date,
    rep(expected_dates, times = length(expected_cameras))
  )

  testthat::expect_error(
    validate_daily_effort(
      dplyr::select(supplied, -operating),
      config
    ),
    "missing: operating",
    fixed = TRUE
  )
  testthat::expect_error(
    validate_daily_effort(
      dplyr::mutate(supplied, date = as.character(date)),
      config
    ),
    "date must have class Date",
    fixed = TRUE
  )
  testthat::expect_error(
    validate_daily_effort(
      dplyr::mutate(supplied, operating = dplyr::if_else(
        dplyr::row_number() == 1L, 2L, operating
      )),
      config
    ),
    "operating must contain only 0 and 1",
    fixed = TRUE
  )
  testthat::expect_error(
    validate_daily_effort(dplyr::bind_rows(supplied, supplied[1L, ]), config),
    "one row per camera_id and date",
    fixed = TRUE
  )
  testthat::expect_error(
    validate_daily_effort(supplied[-1L, ], config),
    "complete configured camera-date grid",
    fixed = TRUE
  )
})

testthat::test_that("supplied binary operating types canonicalize to integer", {
  config <- flexirich_sim_config(n_cameras = 1L, n_occasions = 1L)
  binary <- rep(c(0L, 1L), length.out = 7L)
  supplied <- tibble::tibble(
    camera_id = rep("cam_01", 7L),
    date = seq(config$start_date, by = "day", length.out = 7L),
    operating = binary
  )
  accepted <- list(
    integer = binary,
    double = as.double(binary),
    logical = as.logical(binary)
  )

  for (input_type in names(accepted)) {
    candidate <- supplied
    candidate$operating <- accepted[[input_type]]

    validated <- validate_daily_effort(candidate, config)

    testthat::expect_identical(
      typeof(validated$operating),
      "integer",
      info = paste("accepted input type:", input_type)
    )
    testthat::expect_identical(
      validated$operating,
      binary,
      info = paste("accepted input type:", input_type)
    )
  }
})

testthat::test_that("invalid supplied operating types and values are rejected", {
  config <- flexirich_sim_config(n_cameras = 1L, n_occasions = 1L)
  binary <- rep(c(0L, 1L), length.out = 7L)
  supplied <- tibble::tibble(
    camera_id = rep("cam_01", 7L),
    date = seq(config$start_date, by = "day", length.out = 7L),
    operating = binary
  )
  invalid <- list(
    character = as.character(binary),
    factor = factor(binary, levels = c(0L, 1L)),
    missing = replace(binary, 1L, NA_integer_),
    positive_infinity = replace(as.double(binary), 1L, Inf),
    negative_infinity = replace(as.double(binary), 1L, -Inf),
    not_a_number = replace(as.double(binary), 1L, NaN),
    below_zero = replace(as.double(binary), 1L, -1),
    above_one = replace(as.double(binary), 1L, 2),
    fractional = replace(as.double(binary), 1L, 0.5)
  )

  for (invalid_case in names(invalid)) {
    candidate <- supplied
    candidate$operating <- invalid[[invalid_case]]

    testthat::expect_error(
      validate_daily_effort(candidate, config),
      "effort_daily\\$operating",
      info = paste("invalid operating case:", invalid_case)
    )
  }
})

testthat::test_that("zero-operation occasions remain explicit", {
  config <- flexirich_sim_config(n_cameras = 1L, n_occasions = 1L)
  supplied <- tibble::tibble(
    camera_id = rep("cam_01", 7L),
    date = seq(config$start_date, by = "day", length.out = 7L),
    operating = rep(0L, 7L)
  )

  weekly <- aggregate_weekly_effort(supplied, config)

  testthat::expect_equal(nrow(weekly), 1L)
  testthat::expect_identical(weekly$active_days, 0L)
})

testthat::test_that("effort functions are reproducible and preserve caller RNG state", {
  config <- flexirich_sim_config(
    n_cameras = 3L,
    n_occasions = 4L,
    initial_operating_prob = 0.5,
    daily_failure_prob = 0.25,
    daily_repair_prob = 0.4,
    seed = 30L
  )

  testthat::expect_identical(
    simulate_daily_effort(config),
    simulate_daily_effort(config)
  )

  set.seed(999)
  before <- .Random.seed
  daily <- simulate_daily_effort(config)
  invisible(validate_daily_effort(daily, config))
  invisible(aggregate_weekly_effort(daily, config))
  testthat::expect_identical(.Random.seed, before)
})
