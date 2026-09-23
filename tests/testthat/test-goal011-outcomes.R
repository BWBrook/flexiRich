.goal011_outcome_fixture <- function() {
  origin <- as.Date("2019-06-05")
  calendar <- tibble::tibble(
    occasion_index = seq_len(153L),
    start_date = origin + 7L * (seq_len(153L) - 1L),
    end_date = origin + 7L * seq_len(153L) - 1L
  )
  effort <- tidyr::expand_grid(
    camera_id = c("cam_a", "cam_b"),
    occasion_index = seq_len(153L)
  ) |>
    dplyr::mutate(active_days = 7L)
  event_at <- function(camera_id, species_id, date, suffix) {
    tibble::tibble(
      event_id = suffix,
      camera_id = camera_id,
      species_id = species_id,
      event_time = as.POSIXct(
        paste(as.character(date), "12:00:00"), tz = "Etc/GMT-10"
      )
    )
  }
  observations <- dplyr::bind_rows(
    event_at("cam_a", "sp_a", calendar$start_date[[1L]], "a_1"),
    event_at("cam_a", "sp_a", calendar$start_date[[1L]] + 1L, "a_2"),
    event_at("cam_a", "sp_b", calendar$start_date[[53L]], "b_53"),
    event_at("cam_a", "sp_b", calendar$end_date[[65L]], "b_65"),
    event_at("cam_a", "sp_c", calendar$start_date[[66L]], "c_66"),
    event_at("cam_a", "sp_d", calendar$start_date[[153L]], "d_153"),
    event_at("cam_b", "excluded", calendar$start_date[[53L]], "x_53")
  )
  list(
    candidate_map = tibble::tibble(species_id = paste0("sp_", letters[1:5])),
    effort = effort,
    calendar = calendar,
    observations = observations
  )
}

testthat::test_that("Goal011 outcomes use fixed inclusive future boundaries", {
  f <- .goal011_outcome_fixture()
  out <- goal011_build_outcomes(
    f$observations, f$candidate_map, f$effort, f$calendar
  )

  testthat::expect_equal(
    out$first52_outcomes$detected,
    c(1L, 0L, 0L, 0L, 0L)
  )
  get <- function(id) {
    out$future_outcomes$detected[out$future_outcomes$species_id == id]
  }
  testthat::expect_identical(get("sp_a"), c(0L, 0L, 0L, 0L))
  testthat::expect_identical(get("sp_b"), c(1L, 1L, 1L, 1L))
  testthat::expect_identical(get("sp_c"), c(0L, 1L, 1L, 1L))
  testthat::expect_identical(get("sp_d"), c(0L, 0L, 0L, 1L))
  testthat::expect_identical(get("sp_e"), c(0L, 0L, 0L, 0L))
  testthat::expect_identical(
    out$metadata$future_occasions,
    53:153
  )
  testthat::expect_equal(
    out$future_outcomes$detected[
      out$future_outcomes$species_id == "sp_d" &
        out$future_outcomes$horizon == 101L
    ],
    1L
  )
})

testthat::test_that("Goal011 outcomes collapse duplicates and retain excluded diagnostics", {
  f <- .goal011_outcome_fixture()
  out <- goal011_build_outcomes(
    f$observations, f$candidate_map, f$effort, f$calendar
  )

  testthat::expect_equal(nrow(out$presence), 5L)
  testthat::expect_identical(out$diagnostics$n_duplicate_candidate_records, 1L)
  testthat::expect_identical(out$diagnostics$n_excluded_observations, 1L)
  testthat::expect_identical(out$diagnostics$excluded_species$species_id, "excluded")
  testthat::expect_identical(out$diagnostics$excluded_species$n_records, 1L)
  testthat::expect_identical(out$outcomes, out$future_outcomes)
})

testthat::test_that("Goal011 outcomes reject identity, date, and zero-effort contradictions", {
  f <- .goal011_outcome_fixture()

  unknown_camera <- f$observations
  unknown_camera$camera_id[[1L]] <- "cam_unknown"
  testthat::expect_error(
    goal011_build_outcomes(
      unknown_camera, f$candidate_map, f$effort, f$calendar
    ),
    "camera IDs absent from effort",
    fixed = TRUE
  )

  outside <- f$observations
  outside$event_time[[1L]] <- as.POSIXct(
    "2019-06-04 12:00:00", tz = "Etc/GMT-10"
  )
  testthat::expect_error(
    goal011_build_outcomes(outside, f$candidate_map, f$effort, f$calendar),
    "outside the supplied calendar",
    fixed = TRUE
  )

  zero_effort <- f$effort
  zero_effort$active_days[
    zero_effort$camera_id == "cam_b" & zero_effort$occasion_index == 54L
  ] <- 0L
  zero_event <- f$observations[1L, , drop = FALSE]
  zero_event$camera_id <- "cam_b"
  zero_event$species_id <- "sp_a"
  zero_event$event_time <- as.POSIXct(
    paste(as.character(f$calendar$start_date[[54L]]), "12:00:00"),
    tz = "Etc/GMT-10"
  )
  testthat::expect_error(
    goal011_build_outcomes(
      dplyr::bind_rows(f$observations, zero_event),
      f$candidate_map, zero_effort, f$calendar
    ),
    "zero-effort stationweek",
    fixed = TRUE
  )

  testthat::expect_error(
    goal011_build_outcomes(
      f$observations, f$candidate_map, f$effort, f$calendar,
      horizons = c(26L, 13L)
    ),
    "in increasing order",
    fixed = TRUE
  )

  testthat::expect_error(
    goal011_build_outcomes(
      f$observations, f$candidate_map, f$effort, f$calendar,
      training_end = c(52L, 52L)
    ),
    "must each be one whole number",
    fixed = TRUE
  )

  testthat::expect_error(
    goal011_build_outcomes(
      f$observations, f$candidate_map, f$effort, f$calendar,
      future_end = 152L
    ),
    "fixes training_end at 52 and future_end at 153",
    fixed = TRUE
  )
})

testthat::test_that("Goal011 outcomes preserve an all-zero first-year audit", {
  f <- .goal011_outcome_fixture()
  f$observations <- f$observations[0L, , drop = FALSE]
  out <- goal011_build_outcomes(
    f$observations, f$candidate_map, f$effort, f$calendar
  )
  testthat::expect_equal(out$first52_outcomes$detected, integer(5L))
  testthat::expect_equal(out$future_outcomes$detected, integer(20L))
  testthat::expect_identical(out$diagnostics$n_candidate_presence_cells, 0L)
})
