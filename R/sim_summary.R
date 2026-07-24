.stop_invalid_sim <- function(message) {
  stop(message, call. = FALSE)
}

.validate_table_contract <- function(table, name, columns) {
  if (!is.data.frame(table) || !identical(names(table), columns)) {
    .stop_invalid_sim(paste0(name, " component contract is invalid."))
  }
}

.validate_identifier_contract <- function(table, name, columns) {
  for (column in columns) {
    if (!is.character(table[[column]])) {
      .stop_invalid_sim(paste0(
        name,
        " identifier column ",
        column,
        " must be character."
      ))
    }
  }
}

.combined_key <- function(data, columns) {
  do.call(paste, c(unname(data[columns]), sep = "\r"))
}

validate_flexirich_sim <- function(sim) {
  if (!inherits(sim, "flexirich_sim")) {
    .stop_invalid_sim("sim must inherit from flexirich_sim.")
  }

  required <- c(
    "config", "species", "cameras", "rates", "effort_daily",
    "effort_weekly", "detections", "truth", "metadata"
  )
  if (!identical(names(sim), required)) {
    .stop_invalid_sim("sim has an invalid component contract.")
  }

  canonical_config_fields <- names(formals(flexirich_sim_config))
  if (!is.list(sim$config) ||
      !identical(names(sim$config), canonical_config_fields)) {
    .stop_invalid_sim(paste0(
      "config field contract must exactly match ",
      "flexirich_sim_config()."
    ))
  }

  config <- tryCatch(
    validate_sim_config(sim$config),
    error = function(error) {
      .stop_invalid_sim(paste0(
        "config component contract is invalid: ",
        conditionMessage(error)
      ))
    }
  )
  if (!identical(config, sim$config)) {
    .stop_invalid_sim("config component contract is not canonical.")
  }

  .validate_table_contract(
    sim$species,
    "species",
    c("species_id", "member", "alpha")
  )
  .validate_table_contract(
    sim$cameras,
    "cameras",
    c("camera_id", "camera_effect")
  )
  .validate_table_contract(
    sim$rates,
    "rates",
    c(
      "species_id", "camera_id", "member", "alpha", "camera_effect",
      "encounter_rate"
    )
  )
  .validate_table_contract(
    sim$effort_daily,
    "effort_daily",
    c("camera_id", "date", "operating")
  )
  .validate_table_contract(
    sim$effort_weekly,
    "effort_weekly",
    c(
      "camera_id", "occasion_id", "occasion_start", "occasion_end",
      "active_days"
    )
  )
  .validate_table_contract(
    sim$detections,
    "detections",
    c(
      "species_id", "camera_id", "occasion_id", "occasion_start",
      "occasion_end", "active_days", "member", "encounter_rate",
      "sampled", "detect_prob_if_member", "detect_prob", "detected"
    )
  )
  .validate_table_contract(
    sim$truth,
    "truth",
    c(
      "candidate_pool_size", "true_richness", "observed_richness",
      "unseen_true_members", "nonmembers", "total_detections"
    )
  )
  if (!is.list(sim$metadata) ||
      !identical(
        names(sim$metadata),
        c("simulator_version", "seed", "generated_at")
      )) {
    .stop_invalid_sim("metadata component contract is invalid.")
  }
  if (!identical(sim$metadata$simulator_version, "0.1.0")) {
    .stop_invalid_sim(
      "metadata simulator_version must equal 0.1.0."
    )
  }

  identifier_fields <- list(
    species = "species_id",
    cameras = "camera_id",
    rates = c("species_id", "camera_id"),
    effort_daily = "camera_id",
    effort_weekly = c("camera_id", "occasion_id"),
    detections = c("species_id", "camera_id", "occasion_id")
  )
  for (component in names(identifier_fields)) {
    .validate_identifier_contract(
      sim[[component]],
      component,
      identifier_fields[[component]]
    )
  }

  expected_species <- sprintf(
    "sp_%03d",
    seq_len(config$candidate_pool_size)
  )
  if (nrow(sim$species) != config$candidate_pool_size ||
      !identical(sim$species$species_id, expected_species)) {
    .stop_invalid_sim(
      "species must contain exactly the configured species."
    )
  }
  if (!is.logical(sim$species$member) || anyNA(sim$species$member)) {
    .stop_invalid_sim(
      "species membership must be complete and logical."
    )
  }
  if (!is.numeric(sim$species$alpha) ||
      anyNA(sim$species$alpha) ||
      any(!is.finite(sim$species$alpha))) {
    .stop_invalid_sim("species effects must be finite numbers.")
  }
  if (!identical(
    as.integer(sum(sim$species$member)),
    config$true_richness
  )) {
    .stop_invalid_sim(
      "species membership does not match configured true_richness."
    )
  }

  expected_cameras <- sprintf("cam_%02d", seq_len(config$n_cameras))
  if (nrow(sim$cameras) != config$n_cameras ||
      !identical(sim$cameras$camera_id, expected_cameras)) {
    .stop_invalid_sim(
      "cameras must contain exactly the configured cameras."
    )
  }
  if (!is.numeric(sim$cameras$camera_effect) ||
      anyNA(sim$cameras$camera_effect) ||
      any(!is.finite(sim$cameras$camera_effect))) {
    .stop_invalid_sim("camera effects must be finite numbers.")
  }

  expected_rate_keys <- tidyr::crossing(
    species_id = expected_species,
    camera_id = expected_cameras
  )
  rate_key <- .combined_key(
    sim$rates,
    c("species_id", "camera_id")
  )
  expected_rate_key <- .combined_key(
    expected_rate_keys,
    c("species_id", "camera_id")
  )
  if (nrow(sim$rates) != nrow(expected_rate_keys) ||
      anyDuplicated(rate_key) ||
      !setequal(rate_key, expected_rate_key)) {
    .stop_invalid_sim(
      "rates must have one row per configured species-camera key."
    )
  }
  rates <- sim$rates[match(expected_rate_key, rate_key), , drop = FALSE]
  expected_rate_membership <- sim$species$member[
    match(rates$species_id, sim$species$species_id)
  ]
  expected_alpha <- sim$species$alpha[
    match(rates$species_id, sim$species$species_id)
  ]
  expected_camera_effect <- sim$cameras$camera_effect[
    match(rates$camera_id, sim$cameras$camera_id)
  ]
  if (!identical(rates$member, expected_rate_membership)) {
    .stop_invalid_sim(
      "rate membership does not match the species table."
    )
  }
  if (!identical(rates$alpha, expected_alpha)) {
    .stop_invalid_sim(
      "rate species effects do not match the species table."
    )
  }
  if (!identical(rates$camera_effect, expected_camera_effect)) {
    .stop_invalid_sim(
      "rate camera effects do not match the camera table."
    )
  }
  if (!is.numeric(rates$encounter_rate) ||
      anyNA(rates$encounter_rate) ||
      any(!is.finite(rates$encounter_rate)) ||
      any(rates$encounter_rate <= 0)) {
    .stop_invalid_sim("encounter rates must be finite and positive.")
  }
  if (!identical(
    rates$encounter_rate,
    exp(rates$alpha + rates$camera_effect)
  )) {
    .stop_invalid_sim(
      "encounter rates do not satisfy the encounter-rate equation."
    )
  }

  validated_daily <- tryCatch(
    validate_daily_effort(sim$effort_daily, config),
    error = function(error) {
      .stop_invalid_sim(paste0(
        "daily effort is invalid: ",
        conditionMessage(error)
      ))
    }
  )
  if (!identical(validated_daily, sim$effort_daily)) {
    .stop_invalid_sim("daily effort is not in its canonical form.")
  }
  expected_weekly <- aggregate_weekly_effort(validated_daily, config)
  if (!identical(sim$effort_weekly, expected_weekly)) {
    .stop_invalid_sim(
      "weekly effort does not exactly aggregate daily effort."
    )
  }

  expected_occasions <- sprintf(
    "occ_%03d",
    seq_len(config$n_occasions)
  )
  expected_detection_keys <- tidyr::crossing(
    species_id = expected_species,
    camera_id = expected_cameras,
    occasion_id = expected_occasions
  )
  detection_key <- .combined_key(
    sim$detections,
    c("species_id", "camera_id", "occasion_id")
  )
  expected_detection_key <- .combined_key(
    expected_detection_keys,
    c("species_id", "camera_id", "occasion_id")
  )
  if (nrow(sim$detections) != nrow(expected_detection_keys) ||
      anyDuplicated(detection_key) ||
      !setequal(detection_key, expected_detection_key)) {
    .stop_invalid_sim(paste0(
      "detections must have one row per configured ",
      "species-camera-occasion key."
    ))
  }

  detection_template <- tidyr::crossing(
    species_id = expected_species,
    sim$effort_weekly
  ) |>
    dplyr::left_join(
      sim$rates |>
        dplyr::select(
          species_id,
          camera_id,
          member,
          encounter_rate
        ),
      by = c("species_id", "camera_id")
    )
  template_key <- .combined_key(
    detection_template,
    c("species_id", "camera_id", "occasion_id")
  )
  detections <- sim$detections[
    match(template_key, detection_key),
    ,
    drop = FALSE
  ]

  for (field in c(
    "occasion_start", "occasion_end", "active_days"
  )) {
    if (!identical(detections[[field]], detection_template[[field]])) {
      .stop_invalid_sim(
        "detection effort context does not match weekly effort."
      )
    }
  }
  if (!identical(detections$member, detection_template$member)) {
    .stop_invalid_sim(
      "detection membership does not match the rates table."
    )
  }
  if (!identical(
    detections$encounter_rate,
    detection_template$encounter_rate
  )) {
    .stop_invalid_sim(
      "detection encounter rates do not match the rates table."
    )
  }

  expected_sampled <- detections$active_days > 0L
  if (!is.logical(detections$sampled) ||
      anyNA(detections$sampled) ||
      !identical(detections$sampled, expected_sampled)) {
    .stop_invalid_sim(
      "detection sampled status does not match weekly effort."
    )
  }

  probability_fields <- c(
    "detect_prob_if_member",
    "detect_prob"
  )
  invalid_probability <- vapply(
    probability_fields,
    function(field) {
      value <- detections[[field]]
      !is.numeric(value) ||
        anyNA(value) ||
        any(!is.finite(value)) ||
        any(value < 0 | value > 1)
    },
    logical(1)
  )
  if (any(invalid_probability)) {
    .stop_invalid_sim(
      "detection probabilities must be finite and lie in [0, 1]."
    )
  }

  expected_conditional_probability <- -expm1(
    -detections$active_days * detections$encounter_rate
  )
  if (!identical(
    detections$detect_prob_if_member,
    expected_conditional_probability
  )) {
    .stop_invalid_sim(paste0(
      "conditional detection probabilities do not satisfy the ",
      "conditional detection-probability equation."
    ))
  }
  expected_member_probability <- as.numeric(detections$member) *
    expected_conditional_probability
  if (!identical(
    detections$detect_prob,
    expected_member_probability
  )) {
    .stop_invalid_sim(paste0(
      "detection probabilities do not satisfy the member ",
      "detection-probability equation."
    ))
  }

  if (any(!is.na(detections$detected[!detections$sampled]))) {
    .stop_invalid_sim(
      "zero-effort observations must be missing."
    )
  }
  sampled_outcomes <- detections$detected[detections$sampled]
  if (!is.integer(detections$detected) ||
      anyNA(sampled_outcomes) ||
      any(!(sampled_outcomes %in% c(0L, 1L)))) {
    .stop_invalid_sim(
      "sampled observations must be binary."
    )
  }
  if (any(
    detections$detected[
      detections$sampled & !detections$member
    ] == 1L
  )) {
    .stop_invalid_sim("a non-member species was detected.")
  }

  if (nrow(sim$truth) != 1L) {
    .stop_invalid_sim("truth component must contain one row.")
  }
  observed_species <- unique(detections$species_id[
    detections$detected == 1L & !is.na(detections$detected)
  ])
  expected_truth <- list(
    candidate_pool_size = config$candidate_pool_size,
    true_richness = as.integer(sum(sim$species$member)),
    observed_richness = as.integer(length(observed_species)),
    unseen_true_members = as.integer(
      sum(sim$species$member) - length(observed_species)
    ),
    nonmembers = as.integer(
      config$candidate_pool_size - sum(sim$species$member)
    ),
    total_detections = as.integer(
      sum(detections$detected, na.rm = TRUE)
    )
  )
  for (field in names(expected_truth)) {
    if (!identical(sim$truth[[field]], expected_truth[[field]])) {
      .stop_invalid_sim(paste0(
        "truth field ", field, " does not match recomputed arithmetic."
      ))
    }
  }

  if (!identical(sim$metadata$seed, config$seed) ||
      length(sim$metadata$simulator_version) != 1L ||
      !is.character(sim$metadata$simulator_version) ||
      is.na(sim$metadata$simulator_version) ||
      length(sim$metadata$generated_at) != 1L ||
      !is.character(sim$metadata$generated_at) ||
      is.na(sim$metadata$generated_at)) {
    .stop_invalid_sim("metadata component contract is invalid.")
  }

  invisible(TRUE)
}

summary.flexirich_sim <- function(object, ...) {
  validate_flexirich_sim(object)
  tibble::tibble(
    candidate_pool_size = object$truth$candidate_pool_size,
    true_richness = object$truth$true_richness,
    observed_richness = object$truth$observed_richness,
    unseen_true_members = object$truth$unseen_true_members,
    detection_completeness = if (object$truth$true_richness == 0L) {
      1
    } else {
      object$truth$observed_richness / object$truth$true_richness
    },
    camera_days = sum(object$effort_weekly$active_days),
    total_detections = object$truth$total_detections
  )
}

print.flexirich_sim <- function(x, ...) {
  print(summary(x), ...)
  invisible(x)
}

discovery_curve <- function(sim) {
  validate_flexirich_sim(sim)

  occasions <- sim$effort_weekly |>
    dplyr::distinct(occasion_id, occasion_start) |>
    dplyr::arrange(occasion_start, occasion_id) |>
    dplyr::mutate(occasion_index = dplyr::row_number()) |>
    dplyr::select(
      occasion_index,
      occasion_id,
      occasion_start
    )

  first_discovery <- sim$detections |>
    dplyr::filter(detected == 1L) |>
    dplyr::group_by(species_id) |>
    dplyr::slice_min(
      occasion_start,
      n = 1L,
      with_ties = FALSE
    ) |>
    dplyr::ungroup() |>
    dplyr::transmute(
      species_id,
      first_occasion_start = occasion_start
    )

  occasions |>
    dplyr::mutate(
      cumulative_richness = vapply(
        occasion_start,
        function(start) {
          as.integer(sum(
            first_discovery$first_occasion_start <= start
          ))
        },
        integer(1)
      )
    )
}
