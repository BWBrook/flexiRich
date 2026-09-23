testthat::test_that("Goal011 bounds observations before mapping or event construction", {
  origin <- as.Date("2019-06-05")
  ending <- origin + 153L * 7L
  obs <- data.frame(datetime = c("04/06/2019 23:59:59", "05/06/2019 00:00:00",
    "03/06/2020 00:00:00", "10/05/2022 23:59:59", "11/05/2022 00:00:00"),
    site = c("outside", "a", "a", "a", "outside"),
    species = c("outside", "one", "one", "other", "outside"))
  protocol <- list(
    parse_datetime_local = function(datetime, ...) as.POSIXct(strptime(datetime,
      "%d/%m/%Y %H:%M:%S", tz = "Etc/GMT-10")),
    pivot_op_long = identity,
    filter_obs_by_effort = function(x, op) {
      testthat::expect_true(all(op$trap_date >= origin & op$trap_date < ending))
      testthat::expect_equal(nrow(x), 3L)
      x
    },
    define_events = function(x, threshold, tz, fixed_offset_hours) {
      testthat::expect_identical(threshold, 15)
      testthat::expect_identical(fixed_offset_hours, 10)
      x$dt <- as.POSIXct(strptime(x$datetime, "%d/%m/%Y %H:%M:%S", tz = "Etc/GMT-10"))
      x$event_id <- paste0("e", seq_len(nrow(x)))
      x
    })
  op <- data.frame(site = "a", trap_date = seq(origin - 1L, ending, by = "day"), on_off = 1L)
  z <- goal011_build_bounded_weekly(obs, op,
    data.frame(short = c("one", "other"), genus = "Genus", species = c("one", "other")),
    data.frame(physical_location_id = "a", analysis_site_id = "cam_a"),
    data.frame(species_id = "Genus one"), protocol)
  testthat::expect_equal(z$weekly$audit$n_occasions, 153L)
  testthat::expect_equal(z$weekly$audit$n_active_camera_days, 1071L)
  testthat::expect_equal(z$excluded_taxa$species_id, "Genus other")
  testthat::expect_equal(z$excluded_taxa$event_count, 1L)
  testthat::expect_equal(sum(z$weekly$detections$detected), 2L)
  testthat::expect_equal(z$weekly$detections$occasion_id[z$weekly$detections$detected == 1L],
    c("occ_001", "occ_053"))
})
