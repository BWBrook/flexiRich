validate_daily_effort <- function(effort_daily, config) {
  required <- c("camera_id", "date", "operating")
  if (!is.data.frame(effort_daily)) {
    stop("effort_daily must be a data frame.", call. = FALSE)
  }
  effort_fields <- names(effort_daily)
  if (is.null(effort_fields) ||
      anyNA(effort_fields) ||
      any(!nzchar(effort_fields))) {
    stop("effort_daily fields must all be named.", call. = FALSE)
  }
  duplicate_fields <- unique(effort_fields[duplicated(effort_fields)])
  if (length(duplicate_fields) > 0L) {
    stop(
      "effort_daily has duplicate fields: ",
      paste(duplicate_fields, collapse = ", "),
      ".",
      call. = FALSE
    )
  }
  missing_fields <- setdiff(required, effort_fields)
  if (length(missing_fields) > 0L) {
    stop(
      "effort_daily is missing fields: ",
      paste(missing_fields, collapse = ", "),
      ".",
      call. = FALSE
    )
  }
  extra_fields <- setdiff(effort_fields, required)
  if (length(extra_fields) > 0L) {
    stop(
      "effort_daily has unexpected fields: ",
      paste(extra_fields, collapse = ", "),
      ".",
      call. = FALSE
    )
  }

  effort_daily <- tibble::as_tibble(
    effort_daily[, required, drop = FALSE]
  )
  camera_id <- effort_daily$camera_id
  if (is.factor(camera_id)) {
    effort_daily$camera_id <- as.character(camera_id)
  } else if (!is.character(camera_id)) {
    stop(
      "effort_daily$camera_id must be character or factor.",
      call. = FALSE
    )
  }

  expected_cameras <- sprintf("cam_%02d", seq_len(config$n_cameras))
  expected_dates <- seq(
    config$start_date,
    by = "day",
    length.out = config$n_occasions * config$occasion_days
  )

  if (!inherits(effort_daily$date, "Date")) {
    stop("effort_daily$date must have class Date.", call. = FALSE)
  }
  operating <- effort_daily$operating
  valid_operating_type <- is.numeric(operating) || is.logical(operating)
  if (!valid_operating_type ||
      anyNA(operating) ||
      any(!is.finite(operating)) ||
      !all(operating %in% c(0L, 1L))) {
    stop(
      paste0(
        "effort_daily$operating must contain only 0 and 1, supplied as ",
        "finite numeric or logical values without missing values."
      ),
      call. = FALSE
    )
  }
  if (anyDuplicated(effort_daily[c("camera_id", "date")])) {
    stop(
      "effort_daily must have one row per camera_id and date.",
      call. = FALSE
    )
  }
  if (!setequal(effort_daily$camera_id, expected_cameras) ||
      !setequal(effort_daily$date, expected_dates) ||
      nrow(effort_daily) != length(expected_cameras) * length(expected_dates)) {
    stop(
      "effort_daily does not cover the complete configured camera-date grid.",
      call. = FALSE
    )
  }

  effort_daily |>
    dplyr::mutate(operating = as.integer(operating)) |>
    dplyr::arrange(match(camera_id, expected_cameras), date)
}

simulate_daily_effort <- function(config) {
  config <- validate_sim_config(config)
  n_days <- config$n_occasions * config$occasion_days
  cameras <- sprintf("cam_%02d", seq_len(config$n_cameras))
  dates <- seq(config$start_date, by = "day", length.out = n_days)

  states <- .with_sim_rng(config$seed + 301L, {
    result <- matrix(0L, nrow = config$n_cameras, ncol = n_days)
    result[, 1L] <- stats::rbinom(
      config$n_cameras,
      1L,
      config$initial_operating_prob
    )

    if (n_days > 1L) {
      for (day in 2:n_days) {
        previous <- result[, day - 1L]
        result[, day] <- ifelse(
          previous == 1L,
          1L - stats::rbinom(
            config$n_cameras,
            1L,
            config$daily_failure_prob
          ),
          stats::rbinom(
            config$n_cameras,
            1L,
            config$daily_repair_prob
          )
        )
      }
    }

    result
  })

  daily <- tidyr::expand_grid(camera_id = cameras, date = dates) |>
    dplyr::mutate(operating = as.integer(c(t(states))))

  validate_daily_effort(daily, config)
}

aggregate_weekly_effort <- function(effort_daily, config) {
  config <- validate_sim_config(config)
  expected_cameras <- sprintf("cam_%02d", seq_len(config$n_cameras))
  daily <- validate_daily_effort(effort_daily, config)

  daily |>
    dplyr::mutate(
      occasion_index = as.integer(
        date - config$start_date
      ) %/% config$occasion_days + 1L,
      occasion_id = sprintf("occ_%03d", occasion_index)
    ) |>
    dplyr::summarise(
      occasion_start = min(date),
      occasion_end = max(date),
      active_days = as.integer(sum(operating)),
      .by = c(camera_id, occasion_id, occasion_index)
    ) |>
    dplyr::arrange(
      match(camera_id, expected_cameras),
      occasion_index
    ) |>
    dplyr::select(-occasion_index)
}
