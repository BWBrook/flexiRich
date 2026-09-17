goal008_test_weekly <- function() {
  fixture <- .goal003_baseline_fixture()
  origin <- as.Date("2019-06-05")
  calendar <- tibble::tibble(
    occasion_id = fixture$occasion_ids,
    occasion_index = seq_along(fixture$occasion_ids),
    start_date = origin + 7L * (seq_along(fixture$occasion_ids) - 1L),
    end_date = origin + 7L * seq_along(fixture$occasion_ids) - 1L
  )
  list(
    candidate_ids = fixture$candidate_ids,
    candidate_pool = tibble::tibble(species_id = fixture$candidate_ids),
    occasion_calendar = calendar,
    effort_weekly = fixture$observed |>
      dplyr::distinct(camera_id, occasion_id, active_days),
    detections = fixture$observed |>
      dplyr::select(species_id, camera_id, occasion_id, detected),
    audit = list()
  )
}

goal008_test_parse_datetime <- function(
  datetime,
  tz,
  fixed_offset_hours,
  quiet
) {
  as.POSIXct(strptime(
    datetime,
    format = "%d/%m/%Y %H:%M:%S",
    tz = "Etc/GMT-10"
  ))
}

testthat::test_that("Goal008 date filter uses fixed UTC+10 half-open bounds", {
  observations <- data.frame(
    datetime = c(
      "4/06/2019 23:59:59",
      "5/06/2019 00:00:00",
      "2/06/2020 23:59:59",
      "3/06/2020 00:00:00",
      "3/06/2020 00:00:01"
    ),
    species = c("before", "start", "last", "first_later", "later"),
    stringsAsFactors = FALSE
  )
  filtered <- goal008_filter_early_observations(
    observations,
    goal008_test_parse_datetime
  )
  testthat::expect_identical(filtered$species, c("start", "last"))
  testthat::expect_false(any(grepl("later", filtered$species)))
})

testthat::test_that("later raw identities cannot alter an early filtered block", {
  early <- data.frame(
    datetime = "5/06/2019 00:00:00",
    species = "early_species",
    stringsAsFactors = FALSE
  )
  later <- rbind(
    early,
    data.frame(
      datetime = "3/06/2020 00:00:00",
      species = "later_sentinel",
      stringsAsFactors = FALSE
    )
  )
  filtered_early <- goal008_filter_early_observations(
    early,
    goal008_test_parse_datetime
  )
  filtered_later <- goal008_filter_early_observations(
    later,
    goal008_test_parse_datetime
  )
  testthat::expect_identical(filtered_early, filtered_later)
  testthat::expect_false(any(filtered_later$species == "later_sentinel"))
})

testthat::test_that("Goal008 summaries retain all-zero candidates and effort denominators", {
  weekly <- goal008_test_weekly()
  candidates <- tibble::tibble(
    species_id = weekly$candidate_ids,
    encounter_class = rep(c("routine", "occasional"), each = 4L)
  )
  frequency <- goal008_candidate_detection_frequency(weekly, candidates)
  zero <- frequency[frequency$species_id == "sp_h", , drop = FALSE]
  testthat::expect_equal(nrow(frequency), 8L)
  testthat::expect_equal(zero$detected, 0L)
  testthat::expect_equal(zero$positive_sample_stationweeks, 0L)
  testthat::expect_equal(zero$sample_stationweeks, 11L)
  testthat::expect_equal(zero$incidence_fraction, 0)
  testthat::expect_equal(
    weekly$detections$detected[
      weekly$detections$camera_id == "cam_b" &
        weekly$detections$occasion_id == "occ_002"
    ],
    rep(NA_integer_, 8L)
  )
  station <- goal008_species_station_summary(weekly, candidates)
  testthat::expect_equal(
    station$sample_stationweeks[
      station$species_id == "sp_h" & station$camera_id == "cam_b"
    ],
    5L
  )
  blocks <- goal008_species_block_summary(weekly, candidates)
  testthat::expect_true(all(grepl("2019-06-05_to_2019-09-03", blocks$block_id)))
  testthat::expect_true(all(c("block_start_date", "block_end_date") %in%
    names(blocks)))
})

testthat::test_that("Goal008 accumulation counts distinct species, not detections", {
  weekly <- goal008_test_weekly()
  accumulation <- goal008_observed_accumulation(weekly)
  testthat::expect_equal(accumulation$cumulative_detected_species, c(3L, 3L, 3L, 3L, 3L, 4L))
  testthat::expect_equal(accumulation$new_detected_species, c(3L, 0L, 0L, 0L, 0L, 1L))
})

testthat::test_that("Goal008 effort uses the existing daily-union builder", {
  operation_daily <- tidyr::expand_grid(
    camera_id = c("cam_a", "cam_b"),
    date = seq(as.Date("2019-06-05"), as.Date("2019-06-18"), by = "day")
  ) |>
    dplyr::mutate(active = as.integer(
      (camera_id == "cam_a" & date <= as.Date("2019-06-06")) |
        (camera_id == "cam_b" & date == as.Date("2019-06-05"))
    ))
  events <- tibble::tibble(
    event_id = "event_1",
    camera_id = "cam_a",
    species_id = "sp_a",
    event_time = as.POSIXct(
      "2019-06-05 12:00:00",
      tz = "Etc/GMT-10"
    )
  )
  weekly <- build_goal003_weekly_inputs(
    tibble::tibble(species_id = "sp_a"),
    operation_daily,
    events,
    occasion_origin = as.Date("2019-06-05"),
    timezone = "Etc/GMT-10"
  )
  testthat::expect_equal(
    weekly$effort_weekly$active_days,
    c(2L, 0L, 1L, 0L)
  )
  testthat::expect_equal(
    weekly$detections$detected,
    c(1L, NA_integer_, 0L, NA_integer_)
  )
})
