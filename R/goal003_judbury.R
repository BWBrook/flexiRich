.goal003_judbury_commit <- "dbe656e3e423e4c89028965bf79dfa18a441a49a"

.goal003_judbury_sources <- c(
  "data/jc_obs.csv" =
    "deafe2af080726aa8b3ec67baca70f7f9c45b18acbfc56ceed39cb353eab5ae0",
  "data/jc_op.csv" =
    "28222586fa232fccc46bfab5e8c07e0c453f07387ebe4eb95b9a90e4687033a3",
  "data/jc_taxa.csv" =
    "7abcc6ff7fd49d3130b29589dc552ff45d00a8a7dfeb355d1ac61c7eb35ea18a",
  "docs/goals/009-analysis-site-vertical-slice/judbury_analysis_site_mapping.csv" =
    "6490d7f7021e5c727b9be1c7d6dfbf44ba50a1ef5b0396c66e1dd813a9c77083",
  "R/custom_funcs.R" =
    "9bd5ea8508867a52dc58635b5023a9cdd8ae3fa89a7666af2555fb1579432866",
  "R/time_utils.R" =
    "ec7901a10024e9833194426701a3ed7a3ef29e9cd6daf0bb9e4d405932b08067"
)

.goal003_read_csv <- function(path) {
  tibble::as_tibble(utils::read.csv(
    path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = c("", "NA")
  ))
}

.goal003_verify_judbury_source <- function(source_root) {
  if (!is.character(source_root) ||
      length(source_root) != 1L ||
      is.na(source_root) ||
      !dir.exists(source_root)) {
    .goal003_stop("source_root must name the pinned camtrap-workflow checkout.")
  }
  source_root <- normalizePath(source_root, mustWork = TRUE)
  head <- suppressWarnings(system2(
    "git",
    c("-C", source_root, "rev-parse", "HEAD"),
    stdout = TRUE,
    stderr = TRUE
  ))
  if (length(head) != 1L || !identical(head, .goal003_judbury_commit)) {
    .goal003_stop(
      "camtrap-workflow is not at the frozen Goal003 source commit."
    )
  }
  for (relative_path in names(.goal003_judbury_sources)) {
    path <- file.path(source_root, relative_path)
    if (!file.exists(path)) {
      .goal003_stop(paste0("Missing frozen Judbury source: ", relative_path, "."))
    }
    actual <- digest::digest(
      file = path,
      algo = "sha256",
      serialize = FALSE
    )
    if (!identical(actual, .goal003_judbury_sources[[relative_path]])) {
      .goal003_stop(paste0(
        "Frozen Judbury source hash mismatch: ",
        relative_path,
        "."
      ))
    }
  }
  source_root
}

#' Build canonical Goal003 inputs from the pinned Judbury checkout
#'
#' The separate `camtrap-workflow` checkout is read only. Its pinned event
#' functions are sourced into a private environment and used unchanged; this
#' adapter performs only the frozen taxonomic and nine-station mappings.
#'
#' @param source_root Read-only `camtrap-workflow` checkout.
#' @param candidate_pool_path Frozen Goal003 candidate-pool CSV.
#'
#' @return Canonical weekly inputs and compact source/audit metadata.
build_goal003_judbury_data <- function(
  source_root = "/home/bwbrook/git/camtrap-workflow",
  candidate_pool_path = file.path(
    .goal003_project_root(),
    "config",
    "goal003_candidate_pool.csv"
  )
) {
  source_root <- .goal003_verify_judbury_source(source_root)
  if (!file.exists(candidate_pool_path)) {
    .goal003_stop("The frozen Goal003 candidate pool is missing.")
  }
  candidate_hash <- digest::digest(
    file = candidate_pool_path,
    algo = "sha256",
    serialize = FALSE
  )
  expected_candidate_hash <-
    "60c8900c1904bafa34340e8ea7e2a44fc819836f76746fc7ee80c484166608db"
  if (!identical(candidate_hash, expected_candidate_hash)) {
    .goal003_stop("The Goal003 candidate-pool hash has changed.")
  }

  protocol <- new.env(parent = globalenv())
  sys.source(
    file.path(source_root, "R", "time_utils.R"),
    envir = protocol
  )
  original_directory <- getwd()
  setwd(source_root)
  tryCatch(
    sys.source(
      file.path(source_root, "R", "custom_funcs.R"),
      envir = protocol
    ),
    finally = setwd(original_directory)
  )
  obs <- .goal003_read_csv(file.path(source_root, "data", "jc_obs.csv"))
  op <- .goal003_read_csv(file.path(source_root, "data", "jc_op.csv"))
  taxa <- .goal003_read_csv(file.path(source_root, "data", "jc_taxa.csv"))
  mapping <- .goal003_read_csv(file.path(
    source_root,
    "docs",
    "goals",
    "009-analysis-site-vertical-slice",
    "judbury_analysis_site_mapping.csv"
  ))
  candidate_review <- .goal003_read_csv(candidate_pool_path)
  primary_ids <- sort(
    candidate_review$scientific_name[candidate_review$primary_pool == "include"],
    method = "radix"
  )
  if (length(primary_ids) != 50L || anyDuplicated(primary_ids)) {
    .goal003_stop("The frozen primary candidate pool must contain 50 species.")
  }

  op_long <- protocol$pivot_op_long(op)
  obs_filtered <- protocol$filter_obs_by_effort(obs, op_long)
  obs_events <- protocol$define_events(
    obs_filtered,
    threshold = 15,
    tz = "Australia/Hobart",
    fixed_offset_hours = 10
  )
  physical_events <- obs_events |>
    dplyr::summarise(
      event_time = min(dt),
      .by = c(event_id, site, species)
    )
  taxon_lookup <- taxa |>
    dplyr::transmute(
      source_species = short,
      scientific_name = paste(genus, species)
    )
  if (anyDuplicated(taxon_lookup$source_species) ||
      anyDuplicated(taxon_lookup$scientific_name)) {
    .goal003_stop("The pinned Judbury taxon map is not one-to-one.")
  }
  event_map <- mapping |>
    dplyr::select(
      physical_location_id,
      analysis_site_id
    )
  if (anyDuplicated(event_map$physical_location_id)) {
    .goal003_stop("The frozen Judbury analysis-site mapping is ambiguous.")
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
  if (anyNA(all_events$analysis_site_id) ||
      anyNA(all_events$scientific_name)) {
    .goal003_stop("A Judbury event did not resolve to its site or taxon.")
  }
  events <- all_events |>
    dplyr::filter(scientific_name %in% primary_ids) |>
    dplyr::transmute(
      event_id = as.character(event_id),
      camera_id = analysis_site_id,
      species_id = scientific_name,
      event_time = event_time
    ) |>
    dplyr::arrange(event_time, event_id)

  operation_daily <- op_long |>
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
  weekly <- build_goal003_weekly_inputs(
    candidate_pool = tibble::tibble(species_id = primary_ids),
    operation_daily = operation_daily,
    events = events,
    occasion_origin = as.Date("2019-06-05"),
    timezone = "Etc/GMT-10"
  )
  expected_audit <- c(
    n_candidate_species = 50L,
    n_cameras = 9L,
    n_occasions = 153L,
    n_active_camera_days = 7644L,
    n_zero_effort_camera_occasions = 266L,
    n_detected_species = 26L
  )
  actual_audit <- unlist(weekly$audit[names(expected_audit)])
  if (!identical(as.integer(actual_audit), unname(expected_audit))) {
    .goal003_stop(
      "Canonical Judbury inputs do not reproduce the frozen Task 1 audit."
    )
  }
  if (nrow(obs) != 15694L ||
      nrow(obs_filtered) != 15672L ||
      nrow(all_events) != 11572L) {
    .goal003_stop(
      "Pinned Judbury observation or operational-event totals changed."
    )
  }

  list(
    weekly = weekly,
    metadata = list(
      camtrap_workflow_commit = .goal003_judbury_commit,
      candidate_pool_sha256 = candidate_hash,
      event_rule_id = "operational_detection_event.gap/1.0",
      event_threshold_minutes = 15L,
      timezone = "Etc/GMT-10",
      analysis_unit = "analysis_site",
      n_raw_observations = as.integer(nrow(obs)),
      n_operational_memberships = as.integer(nrow(obs_filtered)),
      n_all_operational_events = as.integer(nrow(all_events)),
      n_primary_pool_events = as.integer(nrow(events))
    )
  )
}
