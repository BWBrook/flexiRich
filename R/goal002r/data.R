.goal002r_validate_collapsed <- function(data) {
  if (!is.list(data) ||
      !identical(class(data), c("flexirich_g_collapsed_data", "list"))) {
    .goal002r_stop("data must be a flexirich_g_collapsed_data object.")
  }
  required <- c(
    "candidate_ids", "detected_ids", "unseen_ids", "camera_ids",
    "detected_ever", "observed", "grouped", "zero_history",
    "stan_core", "source_data_hash", "data_hash", "audit"
  )
  if (!identical(names(data), required)) {
    .goal002r_stop("Collapsed data has an invalid component contract.")
  }
  if (!setequal(c(data$detected_ids, data$unseen_ids), data$candidate_ids) ||
      anyDuplicated(data$candidate_ids) ||
      anyDuplicated(data$detected_ids) ||
      anyDuplicated(data$unseen_ids)) {
    .goal002r_stop("Detected and unseen IDs must partition the candidate pool.")
  }
  if (!identical(
    data$detected_ever,
    as.integer(data$candidate_ids %in% data$detected_ids)
  )) {
    .goal002r_stop("detected_ever does not match the collapsed partition.")
  }
  if (length(data$unseen_ids) > 0L) {
    required_zero <- c("camera_id", "active_days", "n_trials")
    if (!tibble::is_tibble(data$zero_history) ||
        !identical(names(data$zero_history), required_zero) ||
        !is.integer(data$zero_history$active_days) ||
        !is.integer(data$zero_history$n_trials) ||
        any(data$zero_history$active_days < 1L) ||
        any(data$zero_history$n_trials < 1L)) {
      .goal002r_stop("zero_history has an invalid contract.")
    }
  } else if (nrow(data$zero_history) != 0L) {
    .goal002r_stop("zero_history must be empty when U is zero.")
  }
  if (!is.list(data$stan_core) ||
      !identical(names(data$stan_core), c(
      "D", "U", "J", "G", "G0", "species_index", "camera_index",
        "active_days", "n_trials", "n_detected", "zero_camera_index",
        "zero_active_days", "zero_n_trials"
      ))) {
    .goal002r_stop("stan_core has an invalid contract.")
  }
  TRUE
}

.goal002r_zero_history <- function(data, unseen_ids) {
  if (length(unseen_ids) == 0L) {
    return(tibble::tibble(
      camera_id = character(),
      active_days = integer(),
      n_trials = integer()
    ))
  }
  reference <- data$observed[
    data$observed$species_id == unseen_ids[1L] &
      data$observed$active_days > 0L,
    c("camera_id", "occasion_id", "active_days", "detected"),
    drop = FALSE
  ]
  if (nrow(reference) == 0L || any(reference$detected != 0L)) {
    .goal002r_stop("An unseen candidate does not have an all-zero history.")
  }
  for (species_id in unseen_ids[-1L]) {
    candidate <- data$observed[
      data$observed$species_id == species_id &
        data$observed$active_days > 0L,
      c("camera_id", "occasion_id", "active_days", "detected"),
      drop = FALSE
    ]
    if (!identical(candidate, reference)) {
      .goal002r_stop(
        "Never-detected candidates do not share a common opportunity history."
      )
    }
  }
  reference |>
    dplyr::count(camera_id, active_days, name = "n_trials") |>
    dplyr::mutate(
      active_days = as.integer(active_days),
      n_trials = as.integer(n_trials)
    ) |>
    dplyr::arrange(camera_id, active_days)
}

prepare_flexirich_g_collapsed_data <- function(data) {
  validate_flexirich_g_data(data)
  candidate_ids <- data$candidate_ids
  detected_ids <- candidate_ids[data$stan_data$detected_ever == 1L]
  unseen_ids <- candidate_ids[data$stan_data$detected_ever == 0L]
  zero_history <- .goal002r_zero_history(data, unseen_ids)
  detected_grouped <- data$grouped[
    data$grouped$species_id %in% detected_ids,
    ,
    drop = FALSE
  ]
  detected_index <- match(detected_grouped$species_id, detected_ids)
  camera_index <- match(detected_grouped$camera_id, data$camera_ids)
  zero_camera_index <- match(zero_history$camera_id, data$camera_ids)
  stan_core <- list(
    D = as.integer(length(detected_ids)),
    U = as.integer(length(unseen_ids)),
    J = as.integer(length(data$camera_ids)),
    G = as.integer(nrow(detected_grouped)),
    G0 = as.integer(nrow(zero_history)),
    species_index = as.integer(detected_index),
    camera_index = as.integer(camera_index),
    active_days = as.integer(detected_grouped$active_days),
    n_trials = as.integer(detected_grouped$n_trials),
    n_detected = as.integer(detected_grouped$n_detected),
    zero_camera_index = as.integer(zero_camera_index),
    zero_active_days = as.integer(zero_history$active_days),
    zero_n_trials = as.integer(zero_history$n_trials)
  )
  result <- list(
    candidate_ids = candidate_ids,
    detected_ids = detected_ids,
    unseen_ids = unseen_ids,
    camera_ids = data$camera_ids,
    detected_ever = as.integer(candidate_ids %in% detected_ids),
    observed = data$observed,
    grouped = detected_grouped,
    zero_history = zero_history,
    stan_core = stan_core,
    source_data_hash = data$data_hash,
    data_hash = digest::digest(
      list(
        source_data_hash = data$data_hash,
        detected_ids = detected_ids,
        unseen_ids = unseen_ids,
        zero_history = zero_history,
        detected_grouped = detected_grouped
      ),
      algo = "sha256",
      serialize = TRUE
    ),
    audit = list(
      candidate_pool_size = as.integer(length(candidate_ids)),
      observed_richness = as.integer(length(detected_ids)),
      unseen_capacity = as.integer(length(unseen_ids)),
      common_zero_history_rows = as.integer(nrow(zero_history))
    )
  )
  class(result) <- c("flexirich_g_collapsed_data", "list")
  .goal002r_validate_collapsed(result)
  result
}

validate_flexirich_g_collapsed_data <- function(data) {
  .goal002r_validate_collapsed(data)
}
