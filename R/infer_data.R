.stop_invalid_inference_data <- function(message) {
  stop(message, call. = FALSE)
}

.infer_table_contract <- function(table, name, required) {
  if (!is.data.frame(table)) {
    .stop_invalid_inference_data(
      paste0(name, " must be a data frame.")
    )
  }

  fields <- names(table)
  if (is.null(fields) ||
      anyNA(fields) ||
      any(!nzchar(fields))) {
    .stop_invalid_inference_data(
      paste0(name, " fields must all be named.")
    )
  }

  duplicate_fields <- unique(fields[duplicated(fields)])
  if (length(duplicate_fields) > 0L) {
    .stop_invalid_inference_data(paste0(
      name,
      " has duplicate fields: ",
      paste(duplicate_fields, collapse = ", "),
      "."
    ))
  }

  missing_fields <- setdiff(required, fields)
  if (length(missing_fields) > 0L) {
    .stop_invalid_inference_data(paste0(
      name,
      " is missing fields: ",
      paste(missing_fields, collapse = ", "),
      "."
    ))
  }

  extra_fields <- setdiff(fields, required)
  if (length(extra_fields) > 0L) {
    .stop_invalid_inference_data(paste0(
      name,
      " has unexpected fields: ",
      paste(extra_fields, collapse = ", "),
      "."
    ))
  }

  tibble::as_tibble(table[, required, drop = FALSE])
}

.infer_identifier_contract <- function(x, name) {
  if (!is.character(x) ||
      anyNA(x) ||
      any(!nzchar(x))) {
    .stop_invalid_inference_data(paste0(
      name,
      " must contain non-missing, non-empty character identifiers."
    ))
  }
  x
}

.infer_integer_contract <- function(
  x,
  name,
  lower,
  upper,
  allow_missing = FALSE
) {
  numeric_type <- (is.numeric(x) && !is.complex(x)) || is.logical(x)
  non_missing <- !is.na(x)
  invalid_missing <- !allow_missing && any(!non_missing)
  invalid_values <- numeric_type && (
    any(is.nan(x)) ||
      any(!is.finite(x[non_missing])) ||
      any(x[non_missing] != trunc(x[non_missing])) ||
      any(x[non_missing] < lower | x[non_missing] > upper)
  )

  if (!numeric_type || invalid_missing || invalid_values) {
    missing_phrase <- if (allow_missing) {
      " or NA"
    } else {
      ""
    }
    .stop_invalid_inference_data(paste0(
      name,
      " must contain finite whole numbers in [",
      lower,
      ", ",
      upper,
      "]",
      missing_phrase,
      "."
    ))
  }

  as.integer(x)
}

.infer_lexical_sort <- function(x) {
  sort(x, method = "radix")
}

.infer_complete_grid <- function(
  table,
  columns,
  levels,
  name
) {
  if (anyDuplicated(table[columns])) {
    .stop_invalid_inference_data(paste0(
      name,
      " must have one row per ",
      paste(columns, collapse = "-"),
      " key."
    ))
  }

  expected <- do.call(
    tidyr::expand_grid,
    stats::setNames(levels, columns)
  )
  missing <- dplyr::anti_join(
    expected,
    table[, columns, drop = FALSE],
    by = columns
  )
  unexpected <- dplyr::anti_join(
    table[, columns, drop = FALSE],
    expected,
    by = columns
  )

  if (nrow(table) != nrow(expected) ||
      nrow(missing) > 0L ||
      nrow(unexpected) > 0L) {
    .stop_invalid_inference_data(paste0(
      name,
      " must cover the complete ",
      paste(columns, collapse = "-"),
      " Cartesian grid."
    ))
  }
  invisible(TRUE)
}

.sum_zero_basis <- function(J) {
  if (J == 1L) {
    return(matrix(numeric(), nrow = 1L, ncol = 0L))
  }
  H <- stats::contr.helmert(J)
  sweep(H, 2L, sqrt(colSums(H^2)), "/")
}

.group_inference_observations <- function(
  observed,
  candidate_ids,
  camera_ids
) {
  observed |>
    dplyr::filter(active_days > 0L) |>
    dplyr::summarise(
      n_trials = dplyr::n(),
      n_detected = as.integer(sum(detected)),
      .by = c(species_id, camera_id, active_days)
    ) |>
    dplyr::arrange(
      match(species_id, candidate_ids),
      match(camera_id, camera_ids),
      active_days
    )
}

.make_inference_stan_data <- function(
  grouped,
  observed,
  candidate_ids,
  camera_ids
) {
  C <- length(candidate_ids)
  J <- length(camera_ids)
  G <- nrow(grouped)

  list(
    C = as.integer(C),
    J = as.integer(J),
    B = as.integer(max(J - 1L, 0L)),
    G = as.integer(G),
    species_index = as.integer(match(
      grouped$species_id,
      candidate_ids
    )),
    camera_index = as.integer(match(
      grouped$camera_id,
      camera_ids
    )),
    active_days = as.integer(grouped$active_days),
    n_trials = as.integer(grouped$n_trials),
    n_detected = as.integer(grouped$n_detected),
    detected_ever = vapply(
      candidate_ids,
      function(species_id) {
        as.integer(any(
          observed$detected[observed$species_id == species_id] == 1L,
          na.rm = TRUE
        ))
      },
      integer(1),
      USE.NAMES = FALSE
    ),
    Q = .sum_zero_basis(J)
  )
}

.make_inference_audit <- function(observed, grouped) {
  list(
    n_original_rows = as.integer(nrow(observed)),
    n_sampled_rows = as.integer(sum(observed$active_days > 0L)),
    n_zero_effort_rows = as.integer(sum(observed$active_days == 0L)),
    n_grouped_rows = as.integer(nrow(grouped)),
    n_detections = as.integer(sum(observed$detected, na.rm = TRUE))
  )
}

.inference_data_hash <- function(
  candidate_ids,
  camera_ids,
  occasion_ids,
  observed,
  grouped
) {
  digest::digest(
    list(
      candidate_ids = candidate_ids,
      camera_ids = camera_ids,
      occasion_ids = occasion_ids,
      observed = observed,
      grouped = grouped
    ),
    algo = "sha256",
    serialize = TRUE
  )
}

prepare_flexirich_g_data <- function(
  candidate_pool,
  effort_weekly,
  detections
) {
  candidate_pool <- .infer_table_contract(
    candidate_pool,
    "candidate_pool",
    "species_id"
  )
  effort_weekly <- .infer_table_contract(
    effort_weekly,
    "effort_weekly",
    c("camera_id", "occasion_id", "active_days")
  )
  detections <- .infer_table_contract(
    detections,
    "detections",
    c("species_id", "camera_id", "occasion_id", "detected")
  )

  candidate_pool$species_id <- .infer_identifier_contract(
    candidate_pool$species_id,
    "candidate_pool$species_id"
  )
  effort_weekly$camera_id <- .infer_identifier_contract(
    effort_weekly$camera_id,
    "effort_weekly$camera_id"
  )
  effort_weekly$occasion_id <- .infer_identifier_contract(
    effort_weekly$occasion_id,
    "effort_weekly$occasion_id"
  )
  detections$species_id <- .infer_identifier_contract(
    detections$species_id,
    "detections$species_id"
  )
  detections$camera_id <- .infer_identifier_contract(
    detections$camera_id,
    "detections$camera_id"
  )
  detections$occasion_id <- .infer_identifier_contract(
    detections$occasion_id,
    "detections$occasion_id"
  )

  if (nrow(candidate_pool) == 0L) {
    .stop_invalid_inference_data(
      "candidate_pool must contain at least one candidate species."
    )
  }
  if (anyDuplicated(candidate_pool$species_id)) {
    .stop_invalid_inference_data(
      "candidate_pool$species_id values must be unique."
    )
  }

  effort_weekly$active_days <- .infer_integer_contract(
    effort_weekly$active_days,
    "effort_weekly$active_days",
    0L,
    7L
  )
  detections$detected <- .infer_integer_contract(
    detections$detected,
    "detections$detected",
    0L,
    1L,
    allow_missing = TRUE
  )

  if (nrow(effort_weekly) == 0L) {
    .stop_invalid_inference_data(
      "effort_weekly must contain at least one camera and occasion."
    )
  }

  candidate_ids <- .infer_lexical_sort(candidate_pool$species_id)
  camera_ids <- .infer_lexical_sort(unique(effort_weekly$camera_id))
  occasion_ids <- .infer_lexical_sort(unique(effort_weekly$occasion_id))

  detection_species <- .infer_lexical_sort(unique(detections$species_id))
  detection_cameras <- .infer_lexical_sort(unique(detections$camera_id))
  detection_occasions <- .infer_lexical_sort(unique(detections$occasion_id))
  if (!identical(detection_species, candidate_ids)) {
    .stop_invalid_inference_data(
      "detections species_id universe must exactly match candidate IDs."
    )
  }
  if (!identical(detection_cameras, camera_ids)) {
    .stop_invalid_inference_data(
      "detections camera_id universe must exactly match effort cameras."
    )
  }
  if (!identical(detection_occasions, occasion_ids)) {
    .stop_invalid_inference_data(paste0(
      "detections occasion_id universe must exactly match effort ",
      "occasions."
    ))
  }

  .infer_complete_grid(
    effort_weekly,
    c("camera_id", "occasion_id"),
    list(camera_ids, occasion_ids),
    "effort_weekly"
  )
  .infer_complete_grid(
    detections,
    c("species_id", "camera_id", "occasion_id"),
    list(candidate_ids, camera_ids, occasion_ids),
    "detections"
  )

  n_expected <- length(candidate_ids) *
    length(camera_ids) *
    length(occasion_ids)
  if (!is.finite(n_expected) || n_expected > .Machine$integer.max) {
    .stop_invalid_inference_data(
      "The complete observation grid exceeds R's integer range."
    )
  }

  observation_keys <- tidyr::expand_grid(
    species_id = candidate_ids,
    camera_id = camera_ids,
    occasion_id = occasion_ids
  )
  observed <- observation_keys |>
    dplyr::left_join(
      detections,
      by = c("species_id", "camera_id", "occasion_id")
    ) |>
    dplyr::left_join(
      effort_weekly,
      by = c("camera_id", "occasion_id")
    ) |>
    dplyr::select(
      species_id,
      camera_id,
      occasion_id,
      active_days,
      detected
    ) |>
    dplyr::mutate(
      active_days = as.integer(active_days),
      detected = as.integer(detected)
    )

  if (any(observed$active_days == 0L & !is.na(observed$detected))) {
    .stop_invalid_inference_data(
      "detections$detected must be missing at zero effort."
    )
  }
  if (any(observed$active_days > 0L & is.na(observed$detected))) {
    .stop_invalid_inference_data(
      "detections$detected must be binary at positive effort."
    )
  }

  grouped <- .group_inference_observations(
    observed,
    candidate_ids,
    camera_ids
  )
  stan_data <- .make_inference_stan_data(
    grouped,
    observed,
    candidate_ids,
    camera_ids
  )
  audit <- .make_inference_audit(observed, grouped)
  data_hash <- .inference_data_hash(
    candidate_ids,
    camera_ids,
    occasion_ids,
    observed,
    grouped
  )

  result <- list(
    candidate_ids = candidate_ids,
    camera_ids = camera_ids,
    occasion_ids = occasion_ids,
    observed = observed,
    grouped = grouped,
    stan_data = stan_data,
    audit = audit,
    data_hash = data_hash
  )
  class(result) <- c("flexirich_g_data", "list")
  validate_flexirich_g_data(result)
  result
}

validate_flexirich_g_data <- function(data) {
  if (!is.list(data) ||
      !identical(class(data), c("flexirich_g_data", "list"))) {
    .stop_invalid_inference_data(
      "data must be a canonical flexirich_g_data object."
    )
  }
  if (!identical(names(attributes(data)), c("names", "class"))) {
    .stop_invalid_inference_data(
      "data must not carry non-contract attributes."
    )
  }

  required_components <- c(
    "candidate_ids", "camera_ids", "occasion_ids", "observed",
    "grouped", "stan_data", "audit", "data_hash"
  )
  if (!identical(names(data), required_components)) {
    .stop_invalid_inference_data(
      "data has an invalid component contract."
    )
  }

  identifiers <- list(
    candidate_ids = data$candidate_ids,
    camera_ids = data$camera_ids,
    occasion_ids = data$occasion_ids
  )
  for (name in names(identifiers)) {
    values <- identifiers[[name]]
    .infer_identifier_contract(values, paste0("data$", name))
    if (length(values) == 0L ||
        anyDuplicated(values) ||
        !identical(values, .infer_lexical_sort(values))) {
      .stop_invalid_inference_data(paste0(
        "data$",
        name,
        " must be non-empty, unique, and lexically sorted."
      ))
    }
  }

  observed_fields <- c(
    "species_id", "camera_id", "occasion_id", "active_days",
    "detected"
  )
  if (!tibble::is_tibble(data$observed) ||
      !identical(names(data$observed), observed_fields)) {
    .stop_invalid_inference_data(
      "data$observed has an invalid tibble contract."
    )
  }
  observed <- data$observed
  if (!is.character(observed$species_id) ||
      !is.character(observed$camera_id) ||
      !is.character(observed$occasion_id) ||
      !is.integer(observed$active_days) ||
      !is.integer(observed$detected)) {
    .stop_invalid_inference_data(
      "data$observed has invalid column types."
    )
  }
  if (anyNA(observed$species_id) ||
      anyNA(observed$camera_id) ||
      anyNA(observed$occasion_id) ||
      anyNA(observed$active_days) ||
      any(observed$active_days < 0L | observed$active_days > 7L) ||
      any(!is.na(observed$detected) &
        !observed$detected %in% c(0L, 1L))) {
    .stop_invalid_inference_data(
      "data$observed contains invalid values."
    )
  }

  expected_keys <- tidyr::expand_grid(
    species_id = data$candidate_ids,
    camera_id = data$camera_ids,
    occasion_id = data$occasion_ids
  )
  if (!identical(observed[1:3], expected_keys)) {
    .stop_invalid_inference_data(
      "data$observed keys are incomplete or non-canonical."
    )
  }

  first_species_effort <- observed |>
    dplyr::filter(species_id == data$candidate_ids[1L]) |>
    dplyr::select(camera_id, occasion_id, active_days)
  expected_effort <- rep(
    first_species_effort$active_days,
    times = length(data$candidate_ids)
  )
  if (!identical(observed$active_days, expected_effort)) {
    .stop_invalid_inference_data(
      "data$observed effort differs across species."
    )
  }
  if (any(observed$active_days == 0L & !is.na(observed$detected)) ||
      any(observed$active_days > 0L & is.na(observed$detected))) {
    .stop_invalid_inference_data(
      "data$observed outcomes do not match sampling effort."
    )
  }

  grouped_fields <- c(
    "species_id", "camera_id", "active_days", "n_trials",
    "n_detected"
  )
  if (!tibble::is_tibble(data$grouped) ||
      !identical(names(data$grouped), grouped_fields) ||
      !is.character(data$grouped$species_id) ||
      !is.character(data$grouped$camera_id) ||
      !is.integer(data$grouped$active_days) ||
      !is.integer(data$grouped$n_trials) ||
      !is.integer(data$grouped$n_detected)) {
    .stop_invalid_inference_data(
      "data$grouped has an invalid tibble contract."
    )
  }
  expected_grouped <- .group_inference_observations(
    observed,
    data$candidate_ids,
    data$camera_ids
  )
  if (!identical(data$grouped, expected_grouped)) {
    .stop_invalid_inference_data(
      "data$grouped does not exactly reconstruct sampled observations."
    )
  }

  stan_fields <- c(
    "C", "J", "B", "G", "species_index", "camera_index",
    "active_days", "n_trials", "n_detected", "detected_ever", "Q"
  )
  if (!is.list(data$stan_data) ||
      !identical(names(data$stan_data), stan_fields)) {
    .stop_invalid_inference_data(
      "data$stan_data has an invalid component contract."
    )
  }
  expected_stan <- .make_inference_stan_data(
    expected_grouped,
    observed,
    data$candidate_ids,
    data$camera_ids
  )
  if (!identical(data$stan_data, expected_stan)) {
    .stop_invalid_inference_data(
      "data$stan_data does not exactly match the canonical Stan data."
    )
  }

  audit_fields <- c(
    "n_original_rows", "n_sampled_rows", "n_zero_effort_rows",
    "n_grouped_rows", "n_detections"
  )
  if (!is.list(data$audit) ||
      !identical(names(data$audit), audit_fields)) {
    .stop_invalid_inference_data(
      "data$audit has an invalid component contract."
    )
  }
  expected_audit <- .make_inference_audit(observed, expected_grouped)
  if (!identical(data$audit, expected_audit)) {
    .stop_invalid_inference_data(
      "data$audit does not exactly match the inference data."
    )
  }

  expected_hash <- .inference_data_hash(
    data$candidate_ids,
    data$camera_ids,
    data$occasion_ids,
    observed,
    expected_grouped
  )
  if (!is.character(data$data_hash) ||
      length(data$data_hash) != 1L ||
      is.na(data$data_hash) ||
      !grepl("^[0-9a-f]{64}$", data$data_hash) ||
      !identical(data$data_hash, expected_hash)) {
    .stop_invalid_inference_data(
      "data$data_hash is invalid or does not match the canonical data."
    )
  }

  TRUE
}

sim_to_flexirich_g_data <- function(sim) {
  required <- c("species", "effort_weekly", "detections")
  if (!is.list(sim) || !all(required %in% names(sim))) {
    .stop_invalid_inference_data(paste0(
      "sim must be a list containing species, effort_weekly, and ",
      "detections components."
    ))
  }

  candidate_pool <- sim$species["species_id"]
  effort_weekly <- sim$effort_weekly[
    c("camera_id", "occasion_id", "active_days")
  ]
  detections <- sim$detections[
    c("species_id", "camera_id", "occasion_id", "detected")
  ]

  prepare_flexirich_g_data(
    candidate_pool,
    effort_weekly,
    detections
  )
}
