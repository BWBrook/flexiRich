# Bounded canonical Judbury adapter. File access belongs to the scoring runner.
# Keep the established event-start and fixed UTC+10 observation protocol.
goal011_build_bounded_weekly <- function(observations, operation, taxonomy,
                                       site_mapping, candidate_pool, protocol) {
  start <- as.Date("2019-06-05")
  end <- as.Date("2022-05-11")
  observations <- goal008_filter_early_observations(
    observations, protocol$parse_datetime_local, start, end)
  op <- protocol$pivot_op_long(operation) |>
    dplyr::filter(trap_date >= start, trap_date < end)
  event_map <- site_mapping |>
    dplyr::select(physical_location_id, analysis_site_id)
  taxon_map <- taxonomy |>
    dplyr::transmute(source_species = short,
                     species_id = paste(genus, species))
  stopifnot(!anyNA(event_map), !anyNA(taxon_map),
    !anyDuplicated(event_map$physical_location_id),
    !anyDuplicated(taxon_map$source_species), !anyDuplicated(taxon_map$species_id))
  # Check source identities before operational filtering can discard a row.
  stopifnot(all(observations$site %in% event_map$physical_location_id),
    all(observations$species %in% taxon_map$source_species))
  operational <- protocol$filter_obs_by_effort(observations, op)
  physical <- protocol$define_events(operational, threshold = 15,
    tz = "Australia/Hobart", fixed_offset_hours = 10) |>
    dplyr::summarise(event_time = min(dt), .by = c(event_id, site, species))
  mapped <- physical |>
    dplyr::left_join(event_map, by = c("site" = "physical_location_id")) |>
    dplyr::left_join(taxon_map, by = c("species" = "source_species"))
  stopifnot(!anyNA(mapped$analysis_site_id), !anyNA(mapped$species_id))
  events <- mapped |>
    dplyr::filter(species_id %in% candidate_pool$species_id) |>
    dplyr::transmute(event_id = as.character(event_id),
      camera_id = analysis_site_id, species_id, event_time) |>
    dplyr::arrange(event_time, event_id)
  daily <- op |>
    dplyr::left_join(event_map, by = c("site" = "physical_location_id")) |>
    dplyr::summarise(active = as.integer(any(on_off == 1L, na.rm = TRUE)),
      .by = c(analysis_site_id, trap_date)) |>
    dplyr::transmute(camera_id = analysis_site_id, date = as.Date(trap_date), active) |>
    dplyr::arrange(camera_id, date)
  stopifnot(!anyNA(daily$camera_id))
  weekly <- build_goal003_weekly_inputs(candidate_pool["species_id"], daily,
    events, occasion_origin = start, timezone = "Etc/GMT-10")
  stopifnot(weekly$audit$n_occasions == 153L)
  list(weekly = weekly, events = events,
    excluded_taxa = mapped |>
      dplyr::filter(!species_id %in% candidate_pool$species_id) |>
      dplyr::count(species_id, name = "event_count"),
    audit = data.frame(
      bounded_observation_rows = nrow(observations),
      operational_observation_rows = nrow(operational),
      operational_event_rows = nrow(mapped),
      candidate_event_rows = nrow(events)))
}
