# Goal008 first-year empirical development diagnostics.
#
# This adapter deliberately reads the pinned Judbury source files itself. Raw
# observations are parsed with the fixed UTC+10 protocol and restricted to the
# first 52 occasions before effort filtering, event construction, taxonomy
# joining, or any diagnostic aggregation.

.goal008_development_stop <- function(message) {
  stop(message, call. = FALSE)
}

.goal008_timezone <- "Etc/GMT-10"
.goal008_start_date <- as.Date("2019-06-05")
.goal008_end_date_exclusive <- as.Date("2020-06-03")
.goal008_max_occasion <- 52L
.goal008_block_width <- 13L

goal008_filter_early_observations <- function(
  observations,
  parse_datetime,
  start_date = .goal008_start_date,
  end_date_exclusive = .goal008_end_date_exclusive
) {
  if (!is.data.frame(observations) || !"datetime" %in% names(observations)) {
    .goal008_development_stop("observations must contain a datetime column.")
  }
  if (!is.function(parse_datetime)) {
    .goal008_development_stop("parse_datetime must be a fixed-offset parser function.")
  }
  if (!inherits(start_date, "Date") || length(start_date) != 1L ||
      !inherits(end_date_exclusive, "Date") ||
      length(end_date_exclusive) != 1L ||
      is.na(start_date) || is.na(end_date_exclusive) ||
      end_date_exclusive <= start_date) {
    .goal008_development_stop("The early observation date bounds are invalid.")
  }
  parsed <- parse_datetime(
    observations$datetime,
    tz = "UTC",
    fixed_offset_hours = 10,
    quiet = TRUE
  )
  if (!inherits(parsed, "POSIXct") || length(parsed) != nrow(observations)) {
    .goal008_development_stop("The fixed-offset parser returned an invalid datetime vector.")
  }
  start_time <- as.POSIXct(
    format(start_date, "%Y-%m-%d"),
    tz = .goal008_timezone
  )
  end_time <- as.POSIXct(
    format(end_date_exclusive, "%Y-%m-%d"),
    tz = .goal008_timezone
  )
  keep <- !is.na(parsed) & parsed >= start_time & parsed < end_time
  observations[keep, , drop = FALSE]
}

.goal008_read_csv <- function(path) {
  tibble::as_tibble(utils::read.csv(
    path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = c("", "NA")
  ))
}

.goal008_build_early_weekly <- function(
  observations,
  operation,
  taxonomy,
  site_mapping,
  candidate_pool,
  protocol,
  effort_reference
) {
  required <- list(
    observations = c("datetime", "site", "species"),
    operation = "date",
    taxonomy = c("short", "genus", "species"),
    site_mapping = c("physical_location_id", "analysis_site_id"),
    candidate_pool = c("species_id", "encounter_class")
  )
  for (name in names(required)) {
    if (!all(required[[name]] %in% names(get(name)))) {
      .goal008_development_stop(paste0("Missing required ", name, " fields."))
    }
  }
  early_observations <- goal008_filter_early_observations(
    observations,
    protocol$parse_datetime_local
  )
  operation_long <- protocol$pivot_op_long(operation)
  operation_long <- operation_long |>
    dplyr::filter(
      trap_date >= .goal008_start_date,
      trap_date < .goal008_end_date_exclusive
    )
  event_map <- site_mapping |>
    dplyr::select(physical_location_id, analysis_site_id)
  if (anyDuplicated(event_map$physical_location_id) ||
      anyNA(event_map$analysis_site_id)) {
    .goal008_development_stop("The site mapping is ambiguous or incomplete.")
  }
  operation_daily <- operation_long |>
    dplyr::left_join(
      event_map,
      by = c("site" = "physical_location_id")
    ) |>
    dplyr::summarise(
      active = as.integer(any(on_off == 1L, na.rm = TRUE)),
      .by = c(analysis_site_id, trap_date)
    ) |>
    dplyr::transmute(
      camera_id = analysis_site_id,
      date = as.Date(trap_date),
      active = active
    ) |>
    dplyr::arrange(camera_id, date)
  if (anyNA(operation_daily$camera_id)) {
    .goal008_development_stop("The early operation table contains an unmapped site.")
  }

  # This is the first event operation after date restriction. In particular,
  # taxonomy and event construction never see observations from later dates.
  observed_with_effort <- protocol$filter_obs_by_effort(
    early_observations,
    operation_long
  )
  observed_events <- protocol$define_events(
    observed_with_effort,
    threshold = 15,
    tz = "Australia/Hobart",
    fixed_offset_hours = 10
  )
  physical_events <- observed_events |>
    dplyr::summarise(
      event_time = min(dt),
      .by = c(event_id, site, species)
    )
  taxon_lookup <- taxonomy |>
    dplyr::transmute(
      source_species = short,
      scientific_name = paste(genus, species)
    )
  if (anyDuplicated(taxon_lookup$source_species) ||
      anyDuplicated(taxon_lookup$scientific_name)) {
    .goal008_development_stop("The pinned Judbury taxon map is not one-to-one.")
  }
  all_events <- physical_events |>
    dplyr::left_join(
      event_map,
      by = c("site" = "physical_location_id")
    ) |>
    dplyr::left_join(
      taxon_lookup,
      by = c("species" = "source_species")
    )
  if (anyNA(all_events$analysis_site_id) || anyNA(all_events$scientific_name)) {
    .goal008_development_stop("An early event did not resolve to its site or taxon.")
  }
  events <- all_events |>
    dplyr::filter(scientific_name %in% candidate_pool$species_id) |>
    dplyr::transmute(
      event_id = as.character(event_id),
      camera_id = analysis_site_id,
      species_id = scientific_name,
      event_time = event_time
    ) |>
    dplyr::arrange(event_time, event_id)
  weekly <- build_goal003_weekly_inputs(
    candidate_pool = candidate_pool["species_id"],
    operation_daily = operation_daily,
    events = events,
    occasion_origin = .goal008_start_date,
    timezone = .goal008_timezone
  )
  expected <- effort_reference |>
    dplyr::filter(occasion_index <= .goal008_max_occasion) |>
    dplyr::mutate(
      occasion_id = sprintf("occ_%03d", occasion_index)
    ) |>
    dplyr::select(camera_id, occasion_id, active_days) |>
    dplyr::arrange(camera_id, occasion_id)
  actual <- weekly$effort_weekly |>
    dplyr::arrange(camera_id, occasion_id)
  if (!identical(actual, expected)) {
    .goal008_development_stop("Early effort does not match the frozen Goal006 subset.")
  }
  if (!identical(weekly$audit$n_candidate_species, 50L) ||
      !identical(weekly$audit$n_cameras, 9L) ||
      !identical(weekly$audit$n_occasions, .goal008_max_occasion)) {
    .goal008_development_stop("The early canonical weekly audit is not 50 x 9 x 52.")
  }
  list(
    weekly = weekly,
    candidates = candidate_pool,
    n_early_observations = nrow(early_observations),
    n_early_operational_observations = nrow(observed_with_effort),
    n_early_all_events = nrow(all_events),
    n_early_candidate_events = nrow(events)
  )
}

.goal008_add_calendar <- function(weekly) {
  weekly$occasion_calendar |>
    dplyr::select(occasion_id, occasion_index, start_date, end_date)
}

goal008_weekly_effort <- function(weekly) {
  calendar <- .goal008_add_calendar(weekly)
  weekly$effort_weekly |>
    dplyr::left_join(calendar, by = "occasion_id") |>
    dplyr::summarise(
      active_station_days = as.integer(sum(active_days)),
      active_stations = as.integer(sum(active_days > 0L)),
      zero_effort_station_weeks = as.integer(sum(active_days == 0L)),
      mean_active_days_per_station = mean(active_days),
      .by = c(occasion_id, occasion_index, start_date, end_date)
    ) |>
    dplyr::arrange(occasion_index)
}

goal008_observed_accumulation <- function(weekly) {
  calendar <- .goal008_add_calendar(weekly)
  effort <- weekly$effort_weekly |>
    dplyr::left_join(calendar, by = "occasion_id") |>
    dplyr::summarise(
      active_station_days = as.integer(sum(active_days)),
      active_stations = as.integer(sum(active_days > 0L)),
      .by = c(occasion_id, occasion_index, start_date, end_date)
    ) |>
    dplyr::arrange(occasion_index)
  weekly_counts <- weekly$detections |>
    dplyr::filter(detected == 1L) |>
    dplyr::summarise(
      weekly_detected_species = dplyr::n_distinct(species_id),
      .by = occasion_id
    )
  effort$weekly_detected_species <- as.integer(dplyr::coalesce(
    weekly_counts$weekly_detected_species[
      match(effort$occasion_id, weekly_counts$occasion_id)
    ],
    0L
  ))
  cumulative <- vapply(effort$occasion_index, function(index) {
    keep <- !is.na(weekly$detections$detected) &
      weekly$detections$occasion_id %in%
        weekly$occasion_calendar$occasion_id[seq_len(index)] &
      weekly$detections$detected == 1L
    dplyr::n_distinct(weekly$detections$species_id[keep])
  }, integer(1))
  effort$cumulative_detected_species <- cumulative
  effort$new_detected_species <- c(cumulative[[1L]], diff(cumulative))
  effort |>
    dplyr::select(
      occasion_id, occasion_index, start_date, end_date,
      active_station_days, active_stations, weekly_detected_species,
      new_detected_species, cumulative_detected_species
    )
}

.goal008_detection_long <- function(weekly, candidates) {
  calendar <- .goal008_add_calendar(weekly)
  effort <- weekly$effort_weekly
  weekly$detections |>
    dplyr::left_join(effort, by = c("camera_id", "occasion_id")) |>
    dplyr::left_join(calendar, by = "occasion_id") |>
    dplyr::left_join(candidates, by = c("species_id" = "species_id")) |>
    dplyr::mutate(
      block_index = ((occasion_index - 1L) %/% .goal008_block_width) + 1L,
      block_start_date = .goal008_start_date +
        7L * (block_index - 1L) * .goal008_block_width,
      block_end_date = block_start_date +
        7L * .goal008_block_width - 1L,
      block_id = paste0(
        "block_", sprintf("%02d", block_index), "_",
        block_start_date, "_to_", block_end_date
      )
    )
}

goal008_candidate_detection_frequency <- function(weekly, candidates) {
  long <- .goal008_detection_long(weekly, candidates)
  long |>
    dplyr::summarise(
      positive_sample_stationweeks = as.integer(sum(
        detected == 1L,
        na.rm = TRUE
      )),
      sample_stationweeks = as.integer(sum(!is.na(detected))),
      sample_active_days = as.integer(sum(active_days, na.rm = TRUE)),
      positive_active_days = as.integer(sum(
        active_days[!is.na(detected) & detected == 1L],
        na.rm = TRUE
      )),
      stations_detected = as.integer(dplyr::n_distinct(
        camera_id[!is.na(detected) & detected == 1L]
      )),
      blocks_detected = as.integer(dplyr::n_distinct(
        block_id[!is.na(detected) & detected == 1L]
      )),
      .by = c(species_id, encounter_class)
    ) |>
    dplyr::mutate(
      detected = as.integer(positive_sample_stationweeks > 0L),
      incidence_fraction = dplyr::if_else(
        sample_stationweeks > 0L,
        positive_sample_stationweeks / sample_stationweeks,
        NA_real_
      )
    ) |>
    dplyr::arrange(species_id)
}

goal008_species_station_summary <- function(weekly, candidates) {
  .goal008_detection_long(weekly, candidates) |>
    dplyr::summarise(
      positive_sample_stationweeks = as.integer(sum(
        detected == 1L,
        na.rm = TRUE
      )),
      sample_stationweeks = as.integer(sum(!is.na(detected))),
      active_days = as.integer(sum(active_days, na.rm = TRUE)),
      incidence_fraction = dplyr::if_else(
        sample_stationweeks > 0L,
        positive_sample_stationweeks / sample_stationweeks,
        NA_real_
      ),
      .by = c(species_id, encounter_class, camera_id)
    ) |>
    dplyr::arrange(species_id, camera_id)
}

goal008_species_block_summary <- function(weekly, candidates) {
  .goal008_detection_long(weekly, candidates) |>
    dplyr::summarise(
      positive_sample_stationweeks = as.integer(sum(
        detected == 1L,
        na.rm = TRUE
      )),
      sample_stationweeks = as.integer(sum(!is.na(detected))),
      active_days = as.integer(sum(active_days, na.rm = TRUE)),
      incidence_fraction = dplyr::if_else(
        sample_stationweeks > 0L,
        positive_sample_stationweeks / sample_stationweeks,
        NA_real_
      ),
      .by = c(
        species_id, encounter_class, block_index, block_id,
        block_start_date, block_end_date
      )
    ) |>
    dplyr::arrange(species_id, block_id)
}

goal008_class_summary <- function(frequency, candidates) {
  detected_ids <- frequency$species_id[frequency$detected == 1L]
  candidates |>
    dplyr::left_join(
      frequency[c("species_id", "incidence_fraction")],
      by = "species_id"
    ) |>
    dplyr::group_by(encounter_class) |>
    dplyr::summarise(
      n_candidates = dplyr::n(),
      n_detected = sum(species_id %in% detected_ids),
      detected_incidence_fraction_mean = {
        values <- incidence_fraction[species_id %in% detected_ids]
        values <- values[!is.na(values)]
        if (length(values) == 0L) NA_real_ else mean(values)
      },
      detected_incidence_fraction_median = {
        values <- incidence_fraction[species_id %in% detected_ids]
        values <- values[!is.na(values)]
        if (length(values) == 0L) NA_real_ else stats::median(values)
      },
      detected_incidence_fraction_min = {
        values <- incidence_fraction[species_id %in% detected_ids]
        values <- values[!is.na(values)]
        if (length(values) == 0L) NA_real_ else min(values)
      },
      detected_incidence_fraction_max = {
        values <- incidence_fraction[species_id %in% detected_ids]
        values <- values[!is.na(values)]
        if (length(values) == 0L) NA_real_ else max(values)
      },
      .groups = "drop"
    ) |>
    dplyr::mutate(
      summary_note = "Distribution among detected species; selection-biased; descriptive only"
    )
}

.goal008_heatmap_data <- function(weekly, candidates, margin) {
  long <- .goal008_detection_long(weekly, candidates) |>
    dplyr::filter(species_id %in% candidates$species_id[
      candidates$species_id %in%
        unique(weekly$detections$species_id[weekly$detections$detected == 1L])
    ])
  if (identical(margin, "station")) {
    return(long |>
      dplyr::transmute(
        species_id, camera_id, occasion_index,
        value = detected
      ))
  }
  long |>
    dplyr::summarise(
      value = dplyr::if_else(
        sum(!is.na(detected)) > 0L,
        mean(detected, na.rm = TRUE),
        NA_real_
      ),
      .by = c(species_id, occasion_id, occasion_index)
    )
}

goal008_write_heatmaps <- function(weekly, candidates, output_dir) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    .goal008_development_stop("ggplot2 is required to write Goal008 heatmaps.")
  }
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  species <- candidates$species_id[candidates$species_id %in%
    unique(weekly$detections$species_id[weekly$detections$detected == 1L])]
  if (length(species) == 0L) {
    .goal008_development_stop("No detected species are available for heatmaps.")
  }
  station_data <- .goal008_heatmap_data(weekly, candidates, "station") |>
    dplyr::mutate(
      species_id = factor(species_id, levels = rev(species)),
      value_label = factor(value, levels = c(0L, 1L))
    )
  time_data <- .goal008_heatmap_data(weekly, candidates, "time") |>
    dplyr::mutate(species_id = factor(species_id, levels = rev(species)))
  station_plot <- ggplot2::ggplot(
    station_data,
    ggplot2::aes(x = occasion_index, y = species_id, fill = value_label)
  ) +
    ggplot2::geom_tile(colour = "white", linewidth = 0.1) +
    ggplot2::scale_fill_manual(
      values = c("0" = "white", "1" = "#225ea8"),
      na.value = "grey78", drop = FALSE,
      name = "Detected"
    ) +
    ggplot2::facet_wrap(~camera_id, ncol = 3) +
    ggplot2::labs(x = "Seven-day occasion", y = NULL) +
    ggplot2::theme_minimal(base_size = 9) +
    ggplot2::theme(
      panel.grid = ggplot2::element_blank(),
      axis.text.y = ggplot2::element_text(size = 7),
      axis.text.x = ggplot2::element_text(angle = 45, hjust = 1),
      strip.text = ggplot2::element_text(size = 8)
    )
  time_plot <- ggplot2::ggplot(
    time_data,
    ggplot2::aes(x = occasion_index, y = species_id, fill = value)
  ) +
    ggplot2::geom_tile(colour = "white", linewidth = 0.1) +
    ggplot2::scale_fill_viridis_c(
      option = "C", limits = c(0, 1), na.value = "grey78",
      name = "Incidence\nfraction"
    ) +
    ggplot2::labs(x = "Seven-day occasion", y = NULL) +
    ggplot2::theme_minimal(base_size = 9) +
    ggplot2::theme(
      panel.grid = ggplot2::element_blank(),
      axis.text.y = ggplot2::element_text(size = 7),
      axis.text.x = ggplot2::element_text(angle = 45, hjust = 1)
    )
  save_plot <- function(plot, width, stem) {
    ggplot2::ggsave(file.path(output_dir, paste0(stem, ".pdf")), plot,
      width = width, height = 8, units = "in"
    )
    ggplot2::ggsave(file.path(output_dir, paste0(stem, ".png")), plot,
      width = width, height = 8, units = "in", dpi = 180
    )
  }
  save_plot(station_plot, 12, "heatmap_station")
  save_plot(time_plot, 12, "heatmap_time")
  invisible(c("heatmap_station", "heatmap_time"))
}

.goal008_write_table <- function(table, path) {
  utils::write.csv(table, path, row.names = FALSE, na = "")
}

#' Run the restricted Goal008 first-year descriptive development tranche.
run_goal008_development <- function(
  output_dir = file.path("outputs", "goal008", "development-v1"),
  root = .goal003_project_root(),
  source_root = "/home/bwbrook/git/camtrap-workflow"
) {
  started <- Sys.time()
  root <- normalizePath(root, mustWork = TRUE)
  output_dir <- file.path(root, output_dir)
  if (dir.exists(output_dir) && length(list.files(output_dir, all.files = TRUE,
    no.. = TRUE
  )) > 0L) {
    .goal008_development_stop("Goal008 output directory is non-empty; refusing to overwrite.")
  }
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  receipts <- verify_goal006_source_receipts(source_root)
  contract <- read_goal006_task1_contract(
    root = root,
    source_root = source_root,
    verify_external = FALSE
  )
  protocol <- new.env(parent = globalenv())
  sys.source(file.path(source_root, "R", "time_utils.R"), envir = protocol)
  original_directory <- getwd()
  setwd(source_root)
  tryCatch(
    sys.source(file.path(source_root, "R", "custom_funcs.R"), envir = protocol),
    finally = setwd(original_directory)
  )
  observations <- .goal008_read_csv(file.path(source_root, "data", "jc_obs.csv"))
  operation <- .goal008_read_csv(file.path(source_root, "data", "jc_op.csv"))
  taxonomy <- .goal008_read_csv(file.path(source_root, "data", "jc_taxa.csv"))
  mapping <- .goal008_read_csv(file.path(
    source_root, "docs", "goals", "009-analysis-site-vertical-slice",
    "judbury_analysis_site_mapping.csv"
  ))
  candidates <- contract$candidates |>
    dplyr::transmute(
      species_id = candidate_id,
      encounter_class
    )
  built <- .goal008_build_early_weekly(
    observations, operation, taxonomy, mapping, candidates, protocol,
    contract$effort
  )
  weekly <- built$weekly
  frequency <- goal008_candidate_detection_frequency(weekly, candidates)
  station <- goal008_species_station_summary(weekly, candidates)
  block <- goal008_species_block_summary(weekly, candidates)
  class <- goal008_class_summary(frequency, candidates)
  .goal008_write_table(weekly$candidate_pool,
    file.path(output_dir, "candidate_pool.csv")
  )
  .goal008_write_table(weekly$occasion_calendar,
    file.path(output_dir, "occasion_calendar.csv")
  )
  .goal008_write_table(weekly$effort_weekly,
    file.path(output_dir, "effort_weekly.csv")
  )
  .goal008_write_table(weekly$detections,
    file.path(output_dir, "detections_weekly.csv")
  )
  .goal008_write_table(goal008_weekly_effort(weekly),
    file.path(output_dir, "weekly_effort.csv")
  )
  .goal008_write_table(goal008_observed_accumulation(weekly),
    file.path(output_dir, "observed_accumulation.csv")
  )
  .goal008_write_table(frequency,
    file.path(output_dir, "candidate_detection_frequency.csv")
  )
  .goal008_write_table(station,
    file.path(output_dir, "species_station_summary.csv")
  )
  .goal008_write_table(block,
    file.path(output_dir, "species_block_summary.csv")
  )
  .goal008_write_table(class,
    file.path(output_dir, "class_summary.csv")
  )
  goal008_write_heatmaps(weekly, candidates, output_dir)
  source_hashes <- dplyr::bind_rows(
    receipts |>
      dplyr::transmute(
        source_id, relative_path, sha256, observed_sha256, observed_git_commit
      ),
    tibble::tibble(
      source_id = c("candidate_pool", "effort_template", "goal008_code"),
      relative_path = c(
        "config/goal003_candidate_pool.csv",
        "config/goal003_task4_effort_template.csv",
        "R/goal008_development.R"
      ),
      sha256 = c(
        digest::digest(file = file.path(root, "config", "goal003_candidate_pool.csv"),
          algo = "sha256", serialize = FALSE
        ),
        digest::digest(file = file.path(root, "config", "goal003_task4_effort_template.csv"),
          algo = "sha256", serialize = FALSE
        ),
        digest::digest(file = file.path(root, "R", "goal008_development.R"),
          algo = "sha256", serialize = FALSE
        )
      ),
      observed_sha256 = NA_character_,
      observed_git_commit = NA_character_
    )
  )
  .goal008_write_table(source_hashes, file.path(output_dir, "source-hashes.csv"))
  completed <- Sys.time()
  metadata <- tibble::tribble(
    ~key, ~value,
    "goal", "Goal008 ecological information development diagnostics",
    "analysis_version", "goal008-development-v1",
    "started_utc", format(started, tz = "UTC", usetz = TRUE),
    "completed_utc", format(completed, tz = "UTC", usetz = TRUE),
    "max_analysed_occasion", as.character(.goal008_max_occasion),
    "early_start_local", as.character(.goal008_start_date),
    "early_end_local_inclusive", as.character(.goal008_end_date_exclusive - 1L),
    "end_exclusion", "2020-06-03 00:00:00 UTC+10 (first instant excluded)",
    "timezone", .goal008_timezone,
    "event_rule", "operational_detection_event.gap/1.0",
    "event_threshold_minutes", "15",
    "analysis_unit", "nine mapped analysis stations",
    "n_early_observations", as.character(built$n_early_observations),
    "n_early_operational_observations", as.character(built$n_early_operational_observations),
    "n_early_candidate_events", as.character(built$n_early_candidate_events),
    "source_git_commit", receipts$observed_git_commit[[1L]],
    "raw_observations_not_archived", "true",
    "later_observations_in_diagnostics", "false"
  )
  .goal008_write_table(metadata, file.path(output_dir, "run-metadata.csv"))
  writeLines(
    c(
      "status=PASS",
      "analysis_version=goal008-development-v1",
      paste0("max_analysed_occasion=", .goal008_max_occasion),
      "later_observations_in_diagnostics=false",
      paste0("completed_utc=", format(completed, tz = "UTC", usetz = TRUE))
    ),
    file.path(output_dir, "completion-status.txt")
  )
  invisible(list(
    weekly = weekly, frequency = frequency, station = station,
    block = block, class = class, output_dir = output_dir
  ))
}
