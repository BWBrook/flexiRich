.goal003_stop <- function(message) {
  stop(message, call. = FALSE)
}

.goal003_exact_table <- function(table, name, fields) {
  if (!is.data.frame(table) || !identical(names(table), fields)) {
    .goal003_stop(paste0(
      name,
      " must be a data frame with exactly these fields: ",
      paste(fields, collapse = ", "),
      "."
    ))
  }
  tibble::as_tibble(table)
}

.goal003_identifiers <- function(x, name) {
  if (!is.character(x) || anyNA(x) || any(!nzchar(x))) {
    .goal003_stop(paste0(
      name,
      " must contain non-missing, non-empty character identifiers."
    ))
  }
  x
}

.goal003_binary <- function(x, name) {
  valid_type <- (is.numeric(x) && !is.complex(x)) || is.logical(x)
  if (!valid_type || anyNA(x) || any(!is.finite(x)) ||
      any(!x %in% c(0, 1))) {
    .goal003_stop(paste0(name, " must contain only zero or one."))
  }
  as.integer(x)
}

#' Build Goal003 camera-week effort and incidence tables
#'
#' @param candidate_pool One row per named candidate with field `species_id`.
#' @param operation_daily Complete camera-by-date table with fields `camera_id`,
#'   `date`, and `active`.
#' @param events One row per operational detection event with fields `event_id`,
#'   `camera_id`, `species_id`, and `event_time`.
#' @param occasion_origin First date of the fixed seven-day occasion calendar.
#' @param timezone Timezone used to convert event times to calendar dates. By
#'   default it is read from `events$event_time` rather than guessed.
#'
#' @return A list containing the candidate pool, occasion calendar, weekly
#'   effort, complete incidence histories, and a compact audit summary.
build_goal003_weekly_inputs <- function(
  candidate_pool,
  operation_daily,
  events,
  occasion_origin = min(operation_daily$date),
  timezone = NULL
) {
  candidate_pool <- .goal003_exact_table(
    candidate_pool,
    "candidate_pool",
    "species_id"
  )
  operation_daily <- .goal003_exact_table(
    operation_daily,
    "operation_daily",
    c("camera_id", "date", "active")
  )
  events <- .goal003_exact_table(
    events,
    "events",
    c("event_id", "camera_id", "species_id", "event_time")
  )

  candidate_pool$species_id <- .goal003_identifiers(
    candidate_pool$species_id,
    "candidate_pool$species_id"
  )
  operation_daily$camera_id <- .goal003_identifiers(
    operation_daily$camera_id,
    "operation_daily$camera_id"
  )
  events$event_id <- .goal003_identifiers(events$event_id, "events$event_id")
  events$camera_id <- .goal003_identifiers(
    events$camera_id,
    "events$camera_id"
  )
  events$species_id <- .goal003_identifiers(
    events$species_id,
    "events$species_id"
  )

  if (nrow(candidate_pool) == 0L || anyDuplicated(candidate_pool$species_id)) {
    .goal003_stop("candidate_pool must contain unique named candidates.")
  }
  if (!inherits(operation_daily$date, "Date") ||
      anyNA(operation_daily$date)) {
    .goal003_stop("operation_daily$date must be a complete Date vector.")
  }
  operation_daily$active <- .goal003_binary(
    operation_daily$active,
    "operation_daily$active"
  )
  if (!inherits(events$event_time, "POSIXct") || anyNA(events$event_time)) {
    .goal003_stop("events$event_time must be a complete POSIXct vector.")
  }
  if (anyDuplicated(events$event_id)) {
    .goal003_stop("events$event_id must identify one event per row.")
  }
  if (is.null(timezone)) {
    timezone <- attr(events$event_time, "tzone")
  }
  if (!is.character(timezone) || length(timezone) != 1L ||
      is.na(timezone) || !timezone %in% OlsonNames()) {
    .goal003_stop("timezone must name one Olson timezone.")
  }

  candidate_ids <- sort(candidate_pool$species_id, method = "radix")
  camera_ids <- sort(unique(operation_daily$camera_id), method = "radix")
  dates <- sort(unique(operation_daily$date))
  if (length(camera_ids) == 0L || length(dates) == 0L) {
    .goal003_stop("operation_daily must contain cameras and dates.")
  }
  if (anyDuplicated(operation_daily[c("camera_id", "date")])) {
    .goal003_stop("operation_daily must have one row per camera-date key.")
  }
  expected_dates <- seq(min(dates), max(dates), by = "day")
  expected_operation <- tidyr::expand_grid(
    camera_id = camera_ids,
    date = expected_dates
  )
  missing_operation <- dplyr::anti_join(
    expected_operation,
    operation_daily[c("camera_id", "date")],
    by = c("camera_id", "date")
  )
  if (nrow(operation_daily) != nrow(expected_operation) ||
      nrow(missing_operation) > 0L) {
    .goal003_stop(
      "operation_daily must cover the complete camera-by-calendar-day grid."
    )
  }
  if (length(dates) %% 7L != 0L) {
    .goal003_stop(
      "operation_daily must span a whole number of seven-day occasions."
    )
  }
  if (!inherits(occasion_origin, "Date") || length(occasion_origin) != 1L ||
      is.na(occasion_origin) || occasion_origin != min(dates)) {
    .goal003_stop(
      "occasion_origin must equal the first operation date."
    )
  }
  if (any(!events$camera_id %in% camera_ids)) {
    .goal003_stop("events contains a camera outside operation_daily.")
  }
  if (any(!events$species_id %in% candidate_ids)) {
    .goal003_stop("events contains a species outside candidate_pool.")
  }

  event_date <- as.Date(events$event_time, tz = timezone)
  operation_key <- paste(
    operation_daily$camera_id,
    operation_daily$date,
    sep = "\r"
  )
  event_operation <- operation_daily$active[match(
    paste(events$camera_id, event_date, sep = "\r"),
    operation_key
  )]
  if (anyNA(event_operation) || any(event_operation != 1L)) {
    .goal003_stop(
      "Every event must resolve to an active camera-date in operation_daily."
    )
  }

  n_occasions <- as.integer(length(dates) / 7L)
  occasion_width <- max(3L, nchar(as.character(n_occasions)))
  occasion_calendar <- tibble::tibble(
    occasion_id = sprintf(
      paste0("occ_%0", occasion_width, "d"),
      seq_len(n_occasions)
    ),
    occasion_index = seq_len(n_occasions),
    start_date = occasion_origin + 7L * (seq_len(n_occasions) - 1L),
    end_date = occasion_origin + 7L * seq_len(n_occasions) - 1L
  )

  operation_daily$occasion_index <-
    as.integer(operation_daily$date - occasion_origin) %/% 7L + 1L
  operation_daily$occasion_id <- occasion_calendar$occasion_id[
    operation_daily$occasion_index
  ]
  effort_weekly <- operation_daily |>
    dplyr::summarise(
      active_days = as.integer(sum(active)),
      .by = c(camera_id, occasion_id)
    ) |>
    dplyr::arrange(
      match(camera_id, camera_ids),
      match(occasion_id, occasion_calendar$occasion_id)
    )

  events$occasion_index <- as.integer(event_date - occasion_origin) %/% 7L + 1L
  events$occasion_id <- occasion_calendar$occasion_id[events$occasion_index]
  event_presence <- events |>
    dplyr::distinct(species_id, camera_id, occasion_id) |>
    dplyr::mutate(detected = 1L)
  detections <- tidyr::expand_grid(
    species_id = candidate_ids,
    camera_id = camera_ids,
    occasion_id = occasion_calendar$occasion_id
  ) |>
    dplyr::left_join(
      effort_weekly,
      by = c("camera_id", "occasion_id")
    ) |>
    dplyr::left_join(
      event_presence,
      by = c("species_id", "camera_id", "occasion_id")
    ) |>
    dplyr::mutate(
      detected = dplyr::case_when(
        active_days == 0L ~ NA_integer_,
        is.na(detected) ~ 0L,
        .default = as.integer(detected)
      )
    ) |>
    dplyr::select(species_id, camera_id, occasion_id, detected)

  audit <- list(
    n_candidate_species = as.integer(length(candidate_ids)),
    n_cameras = as.integer(length(camera_ids)),
    n_occasions = n_occasions,
    n_active_camera_days = as.integer(sum(operation_daily$active)),
    n_zero_effort_camera_occasions = as.integer(sum(
      effort_weekly$active_days == 0L
    )),
    n_events = as.integer(nrow(events)),
    n_detected_species = as.integer(length(unique(events$species_id)))
  )

  list(
    candidate_pool = tibble::tibble(species_id = candidate_ids),
    occasion_calendar = occasion_calendar,
    effort_weekly = effort_weekly,
    detections = detections,
    audit = audit
  )
}

.goal003_season <- function(date) {
  month <- as.integer(format(date, "%m"))
  season <- ifelse(
    month %in% c(12L, 1L, 2L),
    "DJF",
    ifelse(
      month %in% 3L:5L,
      "MAM",
      ifelse(month %in% 6L:8L, "JJA", "SON")
    )
  )
  season_year <- as.integer(format(date, "%Y")) + as.integer(month == 12L)
  list(season = season, season_year = season_year)
}

#' Freeze rolling Goal003 training and forecast folds
#'
#' Forecast blocks partition the record from its fixed occasion origin. Each
#' eligible fold uses the immediately preceding training window. Thus future
#' outcomes never overlap within a training-duration stratum, while training
#' histories may overlap as they would in repeated prospective monitoring.
#'
#' @param occasion_calendar Output from `build_goal003_weekly_inputs()`.
#' @param training_occasions Prespecified training-window lengths.
#' @param forecast_occasions Common prospective forecast horizon.
#'
#' @return A deterministic table of temporal folds and season-year blocks.
make_goal003_temporal_folds <- function(
  occasion_calendar,
  training_occasions = c(4L, 26L),
  forecast_occasions = 4L
) {
  occasion_calendar <- .goal003_exact_table(
    occasion_calendar,
    "occasion_calendar",
    c("occasion_id", "occasion_index", "start_date", "end_date")
  )
  n_occasions <- nrow(occasion_calendar)
  valid_calendar <- n_occasions > 0L &&
    is.character(occasion_calendar$occasion_id) &&
    !anyNA(occasion_calendar$occasion_id) &&
    !anyDuplicated(occasion_calendar$occasion_id) &&
    identical(occasion_calendar$occasion_index, seq_len(n_occasions)) &&
    inherits(occasion_calendar$start_date, "Date") &&
    inherits(occasion_calendar$end_date, "Date") &&
    identical(
      occasion_calendar$start_date,
      occasion_calendar$start_date[[1L]] + 7L * (seq_len(n_occasions) - 1L)
    ) &&
    identical(occasion_calendar$end_date, occasion_calendar$start_date + 6L)
  if (!valid_calendar) {
    .goal003_stop(
      "occasion_calendar must be a contiguous sequence of seven-day occasions."
    )
  }

  valid_lengths <- is.numeric(training_occasions) &&
    !is.complex(training_occasions) &&
    length(training_occasions) > 0L &&
    !anyNA(training_occasions) &&
    all(is.finite(training_occasions)) &&
    all(training_occasions == trunc(training_occasions)) &&
    all(training_occasions > 0L) &&
    !anyDuplicated(training_occasions)
  valid_forecast <- is.numeric(forecast_occasions) &&
    !is.complex(forecast_occasions) &&
    length(forecast_occasions) == 1L &&
    !is.na(forecast_occasions) &&
    is.finite(forecast_occasions) &&
    forecast_occasions == trunc(forecast_occasions) &&
    forecast_occasions > 0L
  if (!valid_lengths || !valid_forecast) {
    .goal003_stop("Training and forecast lengths must be unique positive integers.")
  }
  training_occasions <- as.integer(training_occasions)
  forecast_occasions <- as.integer(forecast_occasions)

  forecast_start <- seq.int(1L, n_occasions, by = forecast_occasions)
  forecast_end <- forecast_start + forecast_occasions - 1L
  complete <- forecast_end <= n_occasions
  forecast_start <- forecast_start[complete]
  forecast_end <- forecast_end[complete]

  rows <- lapply(training_occasions, function(training_length) {
    eligible <- forecast_start > training_length
    starts <- forecast_start[eligible]
    ends <- forecast_end[eligible]
    if (length(starts) == 0L) {
      return(NULL)
    }
    midpoint <- occasion_calendar$start_date[starts] +
      floor((forecast_occasions * 7L - 1L) / 2L)
    season_info <- .goal003_season(midpoint)
    tibble::tibble(
      fold_id = sprintf(
        "train%03d_forecast%03d_%03d",
        training_length,
        starts,
        ends
      ),
      training_occasions = training_length,
      forecast_occasions = forecast_occasions,
      train_start_index = starts - training_length,
      train_end_index = starts - 1L,
      forecast_start_index = starts,
      forecast_end_index = ends,
      train_start_date = occasion_calendar$start_date[starts - training_length],
      train_end_date = occasion_calendar$end_date[starts - 1L],
      forecast_start_date = occasion_calendar$start_date[starts],
      forecast_end_date = occasion_calendar$end_date[ends],
      forecast_midpoint = midpoint,
      season = season_info$season,
      season_year = season_info$season_year,
      uncertainty_block_id = sprintf(
        "%s_%04d",
        season_info$season,
        season_info$season_year
      )
    )
  })
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (length(rows) != length(training_occasions)) {
    .goal003_stop(
      "The occasion calendar is too short for every requested training window."
    )
  }
  folds <- dplyr::bind_rows(rows) |>
    dplyr::arrange(training_occasions, forecast_start_index)

  overlap <- folds |>
    dplyr::arrange(training_occasions, forecast_start_index) |>
    dplyr::mutate(
      previous_forecast_end = dplyr::lag(forecast_end_index),
      .by = training_occasions
    ) |>
    dplyr::filter(
      !is.na(previous_forecast_end),
      forecast_start_index <= previous_forecast_end
    )
  if (nrow(overlap) > 0L ||
      any(folds$train_end_index >= folds$forecast_start_index)) {
    .goal003_stop("Temporal folds contain outcome overlap or future leakage.")
  }
  folds
}
