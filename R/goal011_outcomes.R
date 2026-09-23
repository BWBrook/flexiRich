# Goal011 empirical outcomes from already-normalised event rows.
#
# This module deliberately does not read files or perform raw-observation
# normalisation.  Its input is the canonical event representation produced by
# the frozen Judbury protocol: one or more rows with camera, candidate taxon,
# and event time.  Presence is collapsed within a species-camera-occasion
# cell, as in build_goal003_weekly_inputs().

.goal011_outcome_stop <- function(message) {
  stop(message, call. = FALSE)
}

.goal011_outcome_identifiers <- function(x, name) {
  if (!is.character(x) || anyNA(x) || any(!nzchar(x))) {
    .goal011_outcome_stop(paste0(
      name, " must contain non-missing, non-empty character identifiers."
    ))
  }
  x
}

.goal011_outcome_whole_integer <- function(x, name, lower = -Inf, upper = Inf) {
  if (!is.numeric(x) || is.logical(x) || anyNA(x) || any(!is.finite(x)) ||
      any(x != trunc(x)) || any(x < lower) || any(x > upper)) {
    .goal011_outcome_stop(paste0(name, " must contain valid whole numbers."))
  }
  as.integer(x)
}

.goal011_outcome_validate_calendar <- function(calendar, end_occasion) {
  required <- c("occasion_index", "start_date", "end_date")
  if (!is.data.frame(calendar) || !all(required %in% names(calendar))) {
    .goal011_outcome_stop(
      "calendar must contain occasion_index, start_date, and end_date."
    )
  }
  calendar <- as.data.frame(calendar, stringsAsFactors = FALSE)
  calendar$occasion_index <- .goal011_outcome_whole_integer(
    calendar$occasion_index, "calendar$occasion_index", 1L, end_occasion
  )
  if (!inherits(calendar$start_date, "Date") ||
      !inherits(calendar$end_date, "Date") ||
      anyNA(calendar$start_date) || anyNA(calendar$end_date)) {
    .goal011_outcome_stop("calendar dates must be complete Date vectors.")
  }
  expected_index <- seq_len(end_occasion)
  if (nrow(calendar) != end_occasion ||
      anyDuplicated(calendar$occasion_index) ||
      !identical(sort(calendar$occasion_index), expected_index)) {
    .goal011_outcome_stop(
      "calendar must contain every occasion exactly once in sequence."
    )
  }
  calendar <- calendar[order(calendar$occasion_index), , drop = FALSE]
  if (any(calendar$end_date != calendar$start_date + 6L) ||
      any(calendar$start_date[-1L] != calendar$start_date[-nrow(calendar)] + 7L) ||
      any(calendar$start_date > calendar$end_date)) {
    .goal011_outcome_stop(
      "calendar must contain contiguous, non-overlapping seven-day occasions."
    )
  }
  calendar
}

.goal011_outcome_validate_effort <- function(effort, end_occasion) {
  required <- c("camera_id", "occasion_index", "active_days")
  if (!is.data.frame(effort) || !all(required %in% names(effort))) {
    .goal011_outcome_stop(
      "effort must contain camera_id, occasion_index, and active_days."
    )
  }
  effort <- as.data.frame(effort, stringsAsFactors = FALSE)
  effort$camera_id <- .goal011_outcome_identifiers(
    effort$camera_id, "effort$camera_id"
  )
  effort$occasion_index <- .goal011_outcome_whole_integer(
    effort$occasion_index, "effort$occasion_index", 1L, end_occasion
  )
  effort$active_days <- .goal011_outcome_whole_integer(
    effort$active_days, "effort$active_days", 0L, 7L
  )
  if (!nrow(effort) || anyDuplicated(effort[c("camera_id", "occasion_index")])) {
    .goal011_outcome_stop(
      "effort must contain one row per camera and occasion."
    )
  }
  camera_ids <- sort(unique(effort$camera_id), method = "radix")
  expected <- tidyr::expand_grid(
    camera_id = camera_ids,
    occasion_index = seq_len(end_occasion)
  )
  missing <- dplyr::anti_join(
    expected, effort[c("camera_id", "occasion_index")],
    by = c("camera_id", "occasion_index")
  )
  if (nrow(effort) != nrow(expected) || nrow(missing) > 0L) {
    .goal011_outcome_stop(
      "effort must cover the complete camera-by-occasion grid."
    )
  }
  effort[order(match(effort$camera_id, camera_ids), effort$occasion_index),
         , drop = FALSE]
}

.goal011_outcome_validate_candidates <- function(candidate_map) {
  if (!is.data.frame(candidate_map) || !"species_id" %in% names(candidate_map)) {
    .goal011_outcome_stop("candidate_map must contain a species_id column.")
  }
  candidate_map <- as.data.frame(candidate_map, stringsAsFactors = FALSE)
  candidate_map$species_id <- .goal011_outcome_identifiers(
    candidate_map$species_id, "candidate_map$species_id"
  )
  if (!nrow(candidate_map) || anyDuplicated(candidate_map$species_id)) {
    .goal011_outcome_stop(
      "candidate_map must contain one row per unique reviewed candidate."
    )
  }
  candidate_map
}

.goal011_outcome_validate_observations <- function(observations) {
  required <- c("camera_id", "species_id", "event_time")
  if (!is.data.frame(observations) || !all(required %in% names(observations))) {
    .goal011_outcome_stop(
      "observations must contain camera_id, species_id, and event_time."
    )
  }
  observations <- as.data.frame(observations, stringsAsFactors = FALSE)
  observations$camera_id <- .goal011_outcome_identifiers(
    observations$camera_id, "observations$camera_id"
  )
  observations$species_id <- .goal011_outcome_identifiers(
    observations$species_id, "observations$species_id"
  )
  if (!inherits(observations$event_time, "POSIXct") ||
      anyNA(observations$event_time)) {
    .goal011_outcome_stop(
      "observations$event_time must be a complete POSIXct vector."
    )
  }
  observations
}

#' Build fixed-origin Goal011 cumulative detection outcomes.
#'
#' @param observations Canonical event rows with `camera_id`, `species_id`,
#'   and POSIXct `event_time`.  Rows may repeat a presence event.
#' @param candidate_map Reviewed candidate table containing unique `species_id`
#'   values.  Additional review columns are retained only in the input and do
#'   not affect the outcome construction.
#' @param effort Complete camera-by-occasion table with `camera_id`,
#'   `occasion_index`, and `active_days` (0--7).
#' @param calendar Complete occasion table with `occasion_index`, `start_date`,
#'   and `end_date` Date columns.
#' @param horizons Cumulative future horizons in occasions.  Goal011 defaults
#'   to 13, 26, 52, and 101.
#' @param training_end Last first-year occasion.  Goal011 fixes this at 52.
#' @param future_end Last reference-period occasion.  Goal011 fixes this at
#'   153, thereby including occasion 153.
#' @param timezone Olson timezone used to convert event times to dates.  The
#'   frozen Judbury protocol uses the fixed UTC+10 zone.
#'
#' @return A list with `first52_outcomes`, `future_outcomes`, deduplicated
#'   `presence`, diagnostics, and frozen period metadata.  Both outcome tables
#'   have one binary row per candidate and requested horizon; future rows use
#'   the `species_id`, `horizon`, `detected` schema consumed by
#'   `goal011_score_forecast()`.
goal011_build_outcomes <- function(
  observations,
  candidate_map,
  effort,
  calendar,
  horizons = c(13L, 26L, 52L, 101L),
  training_end = 52L,
  future_end = 153L,
  timezone = "Etc/GMT-10"
) {
  if (length(training_end) != 1L || length(future_end) != 1L) {
    .goal011_outcome_stop(
      "training_end and future_end must each be one whole number."
    )
  }
  training_end <- .goal011_outcome_whole_integer(
    training_end, "training_end", 1L, 152L
  )[[1L]]
  future_end <- .goal011_outcome_whole_integer(
    future_end, "future_end", 53L, 153L
  )[[1L]]
  if (training_end != 52L || future_end != 153L) {
    .goal011_outcome_stop(
      "Goal011 fixes training_end at 52 and future_end at 153."
    )
  }
  horizons <- .goal011_outcome_whole_integer(
    horizons, "horizons", 1L, future_end - training_end
  )
  if (!length(horizons) || anyDuplicated(horizons) ||
      !identical(horizons, sort(horizons))) {
    .goal011_outcome_stop(
      "horizons must be distinct positive whole numbers in increasing order."
    )
  }
  if (!is.character(timezone) || length(timezone) != 1L || is.na(timezone) ||
      !timezone %in% OlsonNames()) {
    .goal011_outcome_stop("timezone must name one Olson timezone.")
  }

  candidate_map <- .goal011_outcome_validate_candidates(candidate_map)
  observations <- .goal011_outcome_validate_observations(observations)
  calendar <- .goal011_outcome_validate_calendar(calendar, future_end)
  effort <- .goal011_outcome_validate_effort(effort, future_end)
  candidate_ids <- candidate_map$species_id
  camera_ids <- sort(unique(effort$camera_id), method = "radix")

  unknown_cameras <- setdiff(observations$camera_id, camera_ids)
  if (length(unknown_cameras)) {
    .goal011_outcome_stop(
      "observations contain camera IDs absent from effort."
    )
  }
  event_date <- as.Date(observations$event_time, tz = timezone)
  if (any(event_date < calendar$start_date[[1L]]) ||
      any(event_date > calendar$end_date[[nrow(calendar)]])) {
    .goal011_outcome_stop(
      "observations contain event dates outside the supplied calendar."
    )
  }
  occasion_index <- findInterval(
    event_date, calendar$start_date
  )
  valid_calendar_match <- occasion_index >= 1L & occasion_index <= future_end &
    event_date <= calendar$end_date[occasion_index]
  if (any(!valid_calendar_match)) {
    .goal011_outcome_stop(
      "observations contain event dates outside an occasion boundary."
    )
  }
  observations$occasion_index <- as.integer(occasion_index)
  observations$event_date <- event_date

  candidate_flag <- observations$species_id %in% candidate_ids
  excluded <- observations[!candidate_flag, c(
    "camera_id", "species_id", "event_time", "event_date", "occasion_index"
  ), drop = FALSE]
  excluded_species <- if (nrow(excluded)) {
    dplyr::count(excluded, species_id, name = "n_records") |>
      dplyr::arrange(species_id)
  } else {
    data.frame(species_id = character(), n_records = integer(),
               stringsAsFactors = FALSE)
  }
  candidate_observations <- observations[candidate_flag, , drop = FALSE]
  effort_key <- paste(effort$camera_id, effort$occasion_index, sep = "\r")
  candidate_effort <- effort$active_days[match(
    paste(candidate_observations$camera_id,
         candidate_observations$occasion_index, sep = "\r"), effort_key
  )]
  if (anyNA(candidate_effort)) {
    .goal011_outcome_stop(
      "candidate observations contain camera-occasion keys absent from effort."
    )
  }
  if (any(candidate_effort == 0L)) {
    .goal011_outcome_stop(
      "candidate observations occur in a zero-effort stationweek."
    )
  }

  # Multiple event rows in one species-camera-occasion are one detection
  # presence.  Keep the earliest event date only as an audit aid.
  if (nrow(candidate_observations)) {
    presence <- candidate_observations |>
      dplyr::summarise(
        event_date = min(event_date),
        .by = c(camera_id, species_id, occasion_index)
      ) |>
      dplyr::select(camera_id, species_id, occasion_index, event_date)
  } else {
    presence <- data.frame(
      camera_id = character(), species_id = character(),
      occasion_index = integer(), event_date = as.Date(character()),
      stringsAsFactors = FALSE
    )
  }
  presence <- presence[order(
    presence$occasion_index, presence$camera_id, presence$species_id,
    presence$event_date, method = "radix"
  ), , drop = FALSE]
  rownames(presence) <- NULL

  first52_presence <- presence$occasion_index <= training_end
  first52_detected <- stats::setNames(
    as.integer(vapply(candidate_ids, function(id) any(
      first52_presence & presence$species_id == id
    ), logical(1))),
    candidate_ids
  )
  first52_outcomes <- data.frame(
    species_id = candidate_ids,
    detected = unname(first52_detected),
    stringsAsFactors = FALSE
  )

  future_presence <- presence$occasion_index > training_end &
    presence$occasion_index <= future_end
  future_outcomes <- expand.grid(
    species_id = candidate_ids,
    horizon = horizons,
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  future_outcomes$horizon <- as.integer(future_outcomes$horizon)
  future_outcomes$detected <- as.integer(vapply(
    seq_len(nrow(future_outcomes)),
    function(i) {
      id <- future_outcomes$species_id[[i]]
      end <- training_end + future_outcomes$horizon[[i]]
      as.integer(any(
        future_presence & presence$species_id == id &
          presence$occasion_index <= end
      ))
    },
    integer(1)
  ))

  duplicate_records <- nrow(candidate_observations) - nrow(presence)
  diagnostics <- list(
    n_input_observations = as.integer(nrow(observations)),
    n_candidate_observations = as.integer(nrow(candidate_observations)),
    n_excluded_observations = as.integer(nrow(excluded)),
    n_duplicate_candidate_records = as.integer(duplicate_records),
    excluded_species = excluded_species,
    excluded_observations = excluded,
    n_candidate_presence_cells = as.integer(nrow(presence)),
    n_first52_detected_species = as.integer(sum(first52_outcomes$detected)),
    n_future_presence_cells = as.integer(sum(future_presence))
  )
  list(
    first52_outcomes = first52_outcomes,
    future_outcomes = future_outcomes,
    outcomes = future_outcomes,
    presence = presence,
    diagnostics = diagnostics,
    metadata = list(
      candidate_ids = candidate_ids,
      camera_ids = camera_ids,
      training_occasions = seq_len(training_end),
      future_occasions = seq.int(training_end + 1L, future_end),
      horizons = horizons,
      timezone = timezone,
      calendar = calendar,
      effort = effort
    )
  )
}
