.flexirich_g_summary_fields <- c(
  "terminal_status",
  "rescue_used",
  "richness",
  "membership",
  "effects",
  "posterior_predictive",
  "diagnostics",
  "metadata"
)

.flexirich_g_metadata_fields <- c(
  "terminal_attempt_id",
  "data_hash",
  "model_source_hash",
  "prior_profile",
  "terminal_attempt"
)

.flexirich_g_stat_fields <- c(
  "mean",
  "sd",
  "q05",
  "median",
  "q95"
)

.stop_invalid_flexirich_g_summary <- function(message) {
  stop(message, call. = FALSE)
}

.assert_summary_flag <- function(x, name) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    .stop_invalid_flexirich_g_summary(
      paste0(name, " must be exactly TRUE or FALSE.")
    )
  }
  x
}

.assert_summary_scalar <- function(
  x,
  name,
  lower = -Inf,
  upper = Inf,
  whole = FALSE
) {
  valid <- is.numeric(x) &&
    !is.complex(x) &&
    !is.logical(x) &&
    length(x) == 1L &&
    !is.na(x) &&
    is.finite(x) &&
    x >= lower &&
    x <= upper &&
    (!whole || x == trunc(x))
  if (!valid) {
    .stop_invalid_flexirich_g_summary(
      paste0(name, " is not a valid scalar.")
    )
  }
  if (whole) as.integer(x) else as.numeric(x)
}

richness_pmf_from_q <- function(q_draws) {
  q_draws <- tryCatch(
    as.matrix(q_draws),
    error = function(e) NULL
  )
  valid <- !is.null(q_draws) &&
    is.numeric(q_draws) &&
    !is.complex(q_draws) &&
    !is.logical(q_draws) &&
    nrow(q_draws) > 0L &&
    ncol(q_draws) > 0L &&
    !anyNA(q_draws) &&
    all(is.finite(q_draws)) &&
    all(q_draws >= 0 & q_draws <= 1)
  if (!valid) {
    .stop_invalid_flexirich_g_summary(
      "q_draws must be a non-empty finite numeric matrix in [0, 1]."
    )
  }

  candidate_pool_size <- ncol(q_draws)
  pmf_by_draw <- vapply(
    seq_len(nrow(q_draws)),
    function(draw) poisson_binomial_pmf(q_draws[draw, ]),
    numeric(candidate_pool_size + 1L)
  )
  probability <- rowMeans(pmf_by_draw)
  probability <- unname(probability / sum(probability))

  tibble::tibble(
    richness = seq.int(0L, as.integer(candidate_pool_size)),
    probability = probability
  )
}

.summary_draw_matrix <- function(fit) {
  draws <- tryCatch(
    as.matrix(fit$draws),
    error = function(e) NULL
  )
  if (is.null(draws) ||
      !is.numeric(draws) ||
      nrow(draws) == 0L) {
    .stop_invalid_flexirich_g_summary(
      "fit posterior draws must be a non-empty numeric matrix."
    )
  }
  draws
}

.extract_summary_draws <- function(draws, variables, label) {
  if (length(variables) == 0L ||
      !all(variables %in% colnames(draws))) {
    .stop_invalid_flexirich_g_summary(
      paste0(label, " draw columns are missing.")
    )
  }
  result <- draws[, variables, drop = FALSE]
  if (anyNA(result) || any(!is.finite(result))) {
    .stop_invalid_flexirich_g_summary(
      paste0(label, " draws must be finite.")
    )
  }
  result
}

posterior_richness_pmf <- function(fit) {
  validate_flexirich_g_fit(fit)
  if (identical(fit$terminal_status, "final_nonclean")) {
    .stop_invalid_flexirich_g_summary(
      "posterior_richness_pmf requires a clean terminal fit."
    )
  }

  draws <- .summary_draw_matrix(fit)
  q_names <- sprintf(
    "q_member[%d]",
    seq_along(fit$candidate_ids)
  )
  richness_pmf_from_q(
    .extract_summary_draws(draws, q_names, "q_member")
  )
}

.summarise_draw_vector <- function(x) {
  standard_deviation <- if (length(x) == 1L) 0 else stats::sd(x)
  quantiles <- stats::quantile(
    x,
    probs = c(0.05, 0.5, 0.95),
    names = FALSE,
    type = 8
  )
  c(
    mean = mean(x),
    sd = standard_deviation,
    q05 = quantiles[1L],
    median = quantiles[2L],
    q95 = quantiles[3L]
  )
}

.summarise_draw_columns <- function(draws) {
  statistics <- t(vapply(
    seq_len(ncol(draws)),
    function(column) .summarise_draw_vector(draws[, column]),
    numeric(length(.flexirich_g_stat_fields))
  ))
  colnames(statistics) <- .flexirich_g_stat_fields
  tibble::as_tibble(statistics)
}

.build_effect_summaries <- function(fit, draws) {
  hyperparameter_names <- c(
    "omega",
    "mu_alpha",
    "sigma_alpha",
    "sigma_camera"
  )
  candidate_names <- sprintf(
    "alpha[%d]",
    seq_along(fit$candidate_ids)
  )
  camera_names <- sprintf(
    "camera_effect[%d]",
    seq_along(fit$camera_ids)
  )

  list(
    hyperparameters = dplyr::bind_cols(
      tibble::tibble(parameter = hyperparameter_names),
      .summarise_draw_columns(.extract_summary_draws(
        draws,
        hyperparameter_names,
        "hyperparameter"
      ))
    ),
    candidate_effects = dplyr::bind_cols(
      tibble::tibble(species_id = fit$candidate_ids),
      .summarise_draw_columns(.extract_summary_draws(
        draws,
        candidate_names,
        "alpha"
      ))
    ),
    camera_effects = dplyr::bind_cols(
      tibble::tibble(camera_id = fit$camera_ids),
      .summarise_draw_columns(.extract_summary_draws(
        draws,
        camera_names,
        "camera_effect"
      ))
    )
  )
}

.replicated_statistics <- function(x) {
  statistics <- .summarise_draw_vector(x)
  names(statistics) <- paste0("replicated_", names(statistics))
  tibble::as_tibble_row(as.list(statistics))
}

.replicated_statistics_by_column <- function(draws) {
  dplyr::bind_rows(lapply(
    seq_len(ncol(draws)),
    function(column) .replicated_statistics(draws[, column])
  ))
}

.build_posterior_predictive <- function(fit, draws) {
  grouped <- fit$grouped
  y_names <- sprintf("y_rep[%d]", seq_len(nrow(grouped)))
  y_rep <- .extract_summary_draws(draws, y_names, "y_rep")
  valid_y_rep <- all(y_rep == trunc(y_rep)) &&
    all(y_rep >= 0) &&
    !any(sweep(y_rep, 2L, grouped$n_trials, FUN = ">"))
  if (!valid_y_rep) {
    .stop_invalid_flexirich_g_summary(
      "y_rep draws must be whole counts within grouped trial bounds."
    )
  }

  species_index <- match(grouped$species_id, fit$candidate_ids)
  camera_index <- match(grouped$camera_id, fit$camera_ids)
  replicated_candidate <- vapply(
    seq_along(fit$candidate_ids),
    function(index) {
      rowSums(y_rep[, species_index == index, drop = FALSE])
    },
    numeric(nrow(y_rep))
  )
  replicated_camera <- vapply(
    seq_along(fit$camera_ids),
    function(index) {
      rowSums(y_rep[, camera_index == index, drop = FALSE])
    },
    numeric(nrow(y_rep))
  )
  observed_candidate <- vapply(
    seq_along(fit$candidate_ids),
    function(index) sum(grouped$n_detected[species_index == index]),
    integer(1)
  )
  observed_camera <- vapply(
    seq_along(fit$camera_ids),
    function(index) sum(grouped$n_detected[camera_index == index]),
    integer(1)
  )

  detection_counts <- 0:2
  replicated_frequencies <- vapply(
    detection_counts,
    function(count) rowSums(replicated_candidate == count),
    numeric(nrow(y_rep))
  )
  observed_frequencies <- vapply(
    detection_counts,
    function(count) as.integer(sum(observed_candidate == count)),
    integer(1)
  )

  list(
    total_detections = dplyr::bind_cols(
      tibble::tibble(
        observed = as.integer(sum(grouped$n_detected))
      ),
      .replicated_statistics(rowSums(y_rep))
    ),
    detections_per_candidate = dplyr::bind_cols(
      tibble::tibble(
        species_id = fit$candidate_ids,
        observed = observed_candidate
      ),
      .replicated_statistics_by_column(replicated_candidate)
    ),
    detections_per_camera = dplyr::bind_cols(
      tibble::tibble(
        camera_id = fit$camera_ids,
        observed = observed_camera
      ),
      .replicated_statistics_by_column(replicated_camera)
    ),
    candidate_detection_frequencies = dplyr::bind_cols(
      tibble::tibble(
        n_detections = detection_counts,
        observed_frequency = observed_frequencies
      ),
      .replicated_statistics_by_column(replicated_frequencies)
    )
  )
}

.build_generated_richness_check <- function(
  draws,
  posterior_pmf
) {
  candidate_pool_size <- max(posterior_pmf$richness)
  s_grid <- draws[, "S_grid"]
  if (any(s_grid != trunc(s_grid)) ||
      any(s_grid < 0 | s_grid > candidate_pool_size)) {
    .stop_invalid_flexirich_g_summary(
      "S_grid draws violate integer richness support."
    )
  }
  generated_probability <- tabulate(
    as.integer(s_grid) + 1L,
    nbins = candidate_pool_size + 1L
  ) / length(s_grid)
  maximum_difference <- max(abs(
    generated_probability - posterior_pmf$probability
  ))
  simultaneous_bound <- min(
    1,
    sqrt(
      log(2 * (candidate_pool_size + 1L) / 1e-6) /
        (2 * length(s_grid))
    )
  )

  list(
    pmf = tibble::tibble(
      richness = seq.int(0L, as.integer(candidate_pool_size)),
      probability = generated_probability
    ),
    max_absolute_difference = maximum_difference,
    simultaneous_bound = simultaneous_bound,
    agrees = maximum_difference <= simultaneous_bound
  )
}

.summary_metadata <- function(fit) {
  terminal_attempt <- fit$attempts[[fit$terminal_attempt_id]]
  list(
    terminal_attempt_id = fit$terminal_attempt_id,
    data_hash = fit$data_hash,
    model_source_hash = fit$model_source_hash,
    prior_profile = fit$prior_profile,
    terminal_attempt = terminal_attempt
  )
}

.summary_diagnostics <- function(fit, generated_richness = NULL) {
  list(
    terminal_attempt =
      fit$attempts[[fit$terminal_attempt_id]]$diagnostics,
    generated_richness = generated_richness
  )
}

summarise_flexirich_g <- function(fit, species_ids) {
  validate_flexirich_g_fit(fit)
  if (!identical(species_ids, fit$candidate_ids)) {
    .stop_invalid_flexirich_g_summary(
      "species_ids must exactly match fit$candidate_ids."
    )
  }

  if (identical(fit$terminal_status, "final_nonclean")) {
    result <- list(
      terminal_status = fit$terminal_status,
      rescue_used = fit$rescue_used,
      richness = NULL,
      membership = NULL,
      effects = NULL,
      posterior_predictive = NULL,
      diagnostics = .summary_diagnostics(fit),
      metadata = .summary_metadata(fit)
    )
    class(result) <- c("flexirich_g_summary", "list")
    validate_flexirich_g_summary(result)
    return(result)
  }

  draws <- .summary_draw_matrix(fit)
  q_names <- sprintf("q_member[%d]", seq_along(species_ids))
  q_draws <- .extract_summary_draws(draws, q_names, "q_member")
  posterior_pmf <- richness_pmf_from_q(q_draws)
  discrete <- discrete_richness_summary(
    posterior_pmf,
    levels = c(0.8, 0.9, 0.95)
  )
  expected_richness <- draws[, "expected_richness"]
  reconstructed_expected <- rowSums(q_draws)
  if (max(abs(expected_richness - reconstructed_expected)) > 1e-10 ||
      abs(discrete$mean - mean(expected_richness)) > 1e-10) {
    .stop_invalid_flexirich_g_summary(
      "Richness PMF mean disagrees with expected_richness draws."
    )
  }

  observed_richness <- as.integer(sum(fit$detected_ever))
  candidate_pool_size <- as.integer(length(species_ids))
  richness <- list(
    pmf = posterior_pmf,
    mean = discrete$mean,
    median = discrete$median,
    mode = discrete$mode,
    intervals = discrete$intervals,
    observed = observed_richness,
    candidate_pool = candidate_pool_size,
    boundary_mass = c(
      observed = unname(posterior_pmf$probability[
        posterior_pmf$richness == observed_richness
      ]),
      candidate_pool = unname(posterior_pmf$probability[
        posterior_pmf$richness == candidate_pool_size
      ])
    )
  )
  membership <- tibble::tibble(
    species_id = species_ids,
    detected = fit$detected_ever == 1L,
    probability = unname(colMeans(q_draws))
  )
  generated_check <- .build_generated_richness_check(
    draws,
    posterior_pmf
  )
  if (!generated_check$agrees) {
    .stop_invalid_flexirich_g_summary(
      "Generated S_grid frequencies disagree with the posterior PMF."
    )
  }

  result <- list(
    terminal_status = fit$terminal_status,
    rescue_used = fit$rescue_used,
    richness = richness,
    membership = membership,
    effects = .build_effect_summaries(fit, draws),
    posterior_predictive = .build_posterior_predictive(fit, draws),
    diagnostics = .summary_diagnostics(fit, generated_check),
    metadata = .summary_metadata(fit)
  )
  class(result) <- c("flexirich_g_summary", "list")
  validate_flexirich_g_summary(result)
  result
}

.validate_effect_table <- function(table, id_field, ids, label) {
  expected_fields <- c(id_field, .flexirich_g_stat_fields)
  valid_schema <- tibble::is_tibble(table) &&
    identical(names(table), expected_fields) &&
    identical(table[[id_field]], ids)
  if (!valid_schema) {
    .stop_invalid_flexirich_g_summary(
      paste0(label, " has an invalid identity or field contract.")
    )
  }
  values <- as.matrix(table[.flexirich_g_stat_fields])
  if (!is.numeric(values) ||
      anyNA(values) ||
      any(!is.finite(values)) ||
      any(table$sd < 0) ||
      any(table$q05 > table$median) ||
      any(table$median > table$q95)) {
    .stop_invalid_flexirich_g_summary(
      paste0(label, " contains invalid posterior summaries.")
    )
  }
  TRUE
}

.validate_ppc_table <- function(
  table,
  id_field = NULL,
  ids = NULL,
  observed_field = "observed",
  label
) {
  expected <- c(
    if (!is.null(id_field)) id_field,
    observed_field,
    paste0("replicated_", .flexirich_g_stat_fields)
  )
  valid_schema <- tibble::is_tibble(table) &&
    identical(names(table), expected) &&
    (is.null(id_field) || identical(table[[id_field]], ids))
  if (!valid_schema) {
    .stop_invalid_flexirich_g_summary(
      paste0(label, " has an invalid field or identity contract.")
    )
  }
  observed <- table[[observed_field]]
  replicated <- as.matrix(table[
    paste0("replicated_", .flexirich_g_stat_fields)
  ])
  replicated_locations <- table[paste0(
    "replicated_",
    c("mean", "q05", "median", "q95")
  )]
  if (!is.integer(observed) ||
      anyNA(observed) ||
      any(observed < 0L) ||
      !is.numeric(replicated) ||
      anyNA(replicated) ||
      any(!is.finite(replicated)) ||
      any(table$replicated_sd < 0) ||
      any(table$replicated_q05 > table$replicated_median) ||
      any(table$replicated_median > table$replicated_q95)) {
    .stop_invalid_flexirich_g_summary(
      paste0(label, " contains invalid observed or replicated summaries.")
    )
  }
  if (any(as.matrix(replicated_locations) < 0)) {
    .stop_invalid_flexirich_g_summary(
      paste0(label, " replicated location summaries must be non-negative.")
    )
  }
  TRUE
}

validate_flexirich_g_summary <- function(summary) {
  if (!is.list(summary) ||
      !identical(class(summary), c("flexirich_g_summary", "list")) ||
      !identical(names(attributes(summary)), c("names", "class")) ||
      !identical(names(summary), .flexirich_g_summary_fields)) {
    .stop_invalid_flexirich_g_summary(
      "summary must be a canonical flexirich_g_summary object."
    )
  }
  if (!is.character(summary$terminal_status) ||
      length(summary$terminal_status) != 1L ||
      is.na(summary$terminal_status) ||
      !summary$terminal_status %in% c(
        "primary_clean",
        "rescue_clean",
        "final_nonclean"
      )) {
    .stop_invalid_flexirich_g_summary(
      "summary$terminal_status is invalid."
    )
  }
  .assert_summary_flag(summary$rescue_used, "summary$rescue_used")

  metadata <- summary$metadata
  if (!is.list(metadata) ||
      !identical(names(metadata), .flexirich_g_metadata_fields)) {
    .stop_invalid_flexirich_g_summary(
      "summary metadata have an invalid component contract."
    )
  }
  if (!is.character(metadata$terminal_attempt_id) ||
      length(metadata$terminal_attempt_id) != 1L ||
      is.na(metadata$terminal_attempt_id) ||
      !metadata$terminal_attempt_id %in% c("primary", "rescue")) {
    .stop_invalid_flexirich_g_summary(
      "summary terminal attempt ID is invalid."
    )
  }
  expected_rescue <- identical(metadata$terminal_attempt_id, "rescue")
  if (!identical(summary$rescue_used, expected_rescue)) {
    .stop_invalid_flexirich_g_summary(
      "summary rescue status disagrees with its terminal attempt."
    )
  }
  terminal_attempt_valid <- tryCatch(
    validate_goal002_attempt(metadata$terminal_attempt),
    error = function(e) FALSE
  )
  prior_profile <- tryCatch(
    validate_goal002_profile(metadata$prior_profile, type = "prior"),
    error = function(e) NULL
  )
  valid_provenance <- identical(terminal_attempt_valid, TRUE) &&
    !is.null(prior_profile) &&
    identical(prior_profile, metadata$prior_profile) &&
    identical(
      metadata$terminal_attempt_id,
      metadata$terminal_attempt$attempt_id
    ) &&
    identical(metadata$data_hash, metadata$terminal_attempt$data_hash) &&
    identical(
      metadata$model_source_hash,
      metadata$terminal_attempt$model_source_hash
    ) &&
    identical(
      metadata$prior_profile$profile_id,
      metadata$terminal_attempt$prior_profile
    )
  if (!valid_provenance) {
    .stop_invalid_flexirich_g_summary(
      "summary metadata do not preserve terminal provenance."
    )
  }
  expected_status <- if (!metadata$terminal_attempt$clean) {
    "final_nonclean"
  } else if (identical(metadata$terminal_attempt_id, "primary")) {
    "primary_clean"
  } else {
    "rescue_clean"
  }
  if (!identical(summary$terminal_status, expected_status)) {
    .stop_invalid_flexirich_g_summary(
      "summary status disagrees with terminal attempt identity."
    )
  }
  expected_clean <- !identical(
    summary$terminal_status,
    "final_nonclean"
  )
  if (!identical(metadata$terminal_attempt$clean, expected_clean)) {
    .stop_invalid_flexirich_g_summary(
      "summary status disagrees with terminal attempt diagnostics."
    )
  }

  diagnostics <- summary$diagnostics
  if (!is.list(diagnostics) ||
      !identical(
        names(diagnostics),
        c("terminal_attempt", "generated_richness")
      ) ||
      !identical(
        diagnostics$terminal_attempt,
        metadata$terminal_attempt$diagnostics
      )) {
    .stop_invalid_flexirich_g_summary(
      "summary diagnostics do not match the terminal attempt."
    )
  }

  inference_fields <- c(
    "richness",
    "membership",
    "effects",
    "posterior_predictive"
  )
  if (!expected_clean) {
    if (any(!vapply(summary[inference_fields], is.null, logical(1))) ||
        !is.null(diagnostics$generated_richness)) {
      .stop_invalid_flexirich_g_summary(
        "A non-clean summary must not expose posterior inference."
      )
    }
    return(TRUE)
  }

  richness <- summary$richness
  richness_fields <- c(
    "pmf",
    "mean",
    "median",
    "mode",
    "intervals",
    "observed",
    "candidate_pool",
    "boundary_mass"
  )
  if (!is.list(richness) ||
      !identical(names(richness), richness_fields)) {
    .stop_invalid_flexirich_g_summary(
      "summary richness has an invalid component contract."
    )
  }
  observed <- .assert_summary_scalar(
    richness$observed,
    "summary richness observed",
    lower = 0,
    whole = TRUE
  )
  candidate_pool <- .assert_summary_scalar(
    richness$candidate_pool,
    "summary richness candidate_pool",
    lower = 1,
    whole = TRUE
  )
  if (observed > candidate_pool) {
    .stop_invalid_flexirich_g_summary(
      "Observed richness exceeds the candidate pool."
    )
  }
  pmf <- tryCatch(
    .validate_richness_pmf(richness$pmf),
    error = function(e) NULL
  )
  if (is.null(pmf) ||
      !identical(pmf$candidate_pool_size, candidate_pool) ||
      any(pmf$probability[pmf$richness < observed] > 1e-12)) {
    .stop_invalid_flexirich_g_summary(
      "summary richness PMF violates its support contract."
    )
  }
  recomputed <- discrete_richness_summary(
    richness$pmf,
    levels = c(0.8, 0.9, 0.95)
  )
  valid_richness <- is.numeric(richness$mean) &&
    length(richness$mean) == 1L &&
    !is.na(richness$mean) &&
    is.finite(richness$mean) &&
    abs(richness$mean - recomputed$mean) <= 1e-12 &&
    identical(richness$median, recomputed$median) &&
    identical(richness$mode, recomputed$mode) &&
    identical(richness$intervals, recomputed$intervals)
  expected_boundary <- c(
    observed = pmf$probability[pmf$richness == observed],
    candidate_pool =
      pmf$probability[pmf$richness == candidate_pool]
  )
  valid_boundary <- is.numeric(richness$boundary_mass) &&
    identical(names(richness$boundary_mass), names(expected_boundary)) &&
    length(richness$boundary_mass) == 2L &&
    !anyNA(richness$boundary_mass) &&
    all(is.finite(richness$boundary_mass)) &&
    isTRUE(all.equal(
      unname(richness$boundary_mass),
      unname(expected_boundary),
      tolerance = 1e-12
    ))
  if (!valid_richness || !valid_boundary) {
    .stop_invalid_flexirich_g_summary(
      "summary richness statistics disagree with its PMF."
    )
  }

  membership <- summary$membership
  valid_membership <- tibble::is_tibble(membership) &&
    identical(
      names(membership),
      c("species_id", "detected", "probability")
    ) &&
    is.character(membership$species_id) &&
    length(membership$species_id) == candidate_pool &&
    !anyNA(membership$species_id) &&
    anyDuplicated(membership$species_id) == 0L &&
    is.logical(membership$detected) &&
    !anyNA(membership$detected) &&
    is.numeric(membership$probability) &&
    !anyNA(membership$probability) &&
    all(is.finite(membership$probability)) &&
    all(membership$probability >= 0 & membership$probability <= 1) &&
    all(membership$probability[membership$detected] == 1) &&
    sum(membership$detected) == observed &&
    abs(sum(membership$probability) - richness$mean) <= 1e-10
  if (!valid_membership) {
    .stop_invalid_flexirich_g_summary(
      "summary membership violates its probability contract."
    )
  }

  effects <- summary$effects
  if (!is.list(effects) ||
      !identical(
        names(effects),
        c("hyperparameters", "candidate_effects", "camera_effects")
      )) {
    .stop_invalid_flexirich_g_summary(
      "summary effects have an invalid component contract."
    )
  }
  .validate_effect_table(
    effects$hyperparameters,
    "parameter",
    c("omega", "mu_alpha", "sigma_alpha", "sigma_camera"),
    "hyperparameter summaries"
  )
  .validate_effect_table(
    effects$candidate_effects,
    "species_id",
    membership$species_id,
    "candidate-effect summaries"
  )

  ppc <- summary$posterior_predictive
  if (!is.list(ppc) ||
      !identical(
        names(ppc),
        c(
          "total_detections",
          "detections_per_candidate",
          "detections_per_camera",
          "candidate_detection_frequencies"
        )
      )) {
    .stop_invalid_flexirich_g_summary(
      "posterior predictive summaries have an invalid contract."
    )
  }
  camera_ids <- effects$camera_effects$camera_id
  .validate_effect_table(
    effects$camera_effects,
    "camera_id",
    camera_ids,
    "camera-effect summaries"
  )
  .validate_ppc_table(
    ppc$total_detections,
    label = "total-detection summaries"
  )
  .validate_ppc_table(
    ppc$detections_per_candidate,
    "species_id",
    membership$species_id,
    label = "candidate-detection summaries"
  )
  .validate_ppc_table(
    ppc$detections_per_camera,
    "camera_id",
    camera_ids,
    label = "camera-detection summaries"
  )
  .validate_ppc_table(
    ppc$candidate_detection_frequencies,
    "n_detections",
    0:2,
    observed_field = "observed_frequency",
    label = "candidate-frequency summaries"
  )
  observed_total <- ppc$total_detections$observed
  location_fields <- paste0(
    "replicated_",
    c("mean", "q05", "median", "q95")
  )
  expected_observed_frequencies <- vapply(
    0:2,
    function(count) {
      as.integer(sum(
        ppc$detections_per_candidate$observed == count
      ))
    },
    integer(1)
  )
  frequency_table <- ppc$candidate_detection_frequencies
  frequency_locations <- as.matrix(
    frequency_table[location_fields]
  )
  valid_frequencies <- identical(
    frequency_table$observed_frequency,
    expected_observed_frequencies
  ) &&
    all(frequency_table$observed_frequency <= candidate_pool) &&
    all(frequency_locations <= candidate_pool) &&
    sum(frequency_table$replicated_mean) <= candidate_pool + 1e-10
  if (!valid_frequencies) {
    .stop_invalid_flexirich_g_summary(paste0(
      "Candidate-frequency summaries must reconstruct observed 0/1/2 ",
      "frequencies and remain within the candidate pool."
    ))
  }

  total_locations <- unlist(
    ppc$total_detections[location_fields],
    use.names = TRUE
  )
  candidate_locations <- as.matrix(
    ppc$detections_per_candidate[location_fields]
  )
  camera_locations <- as.matrix(
    ppc$detections_per_camera[location_fields]
  )
  within_total <- all(sweep(
    candidate_locations,
    2L,
    total_locations,
    FUN = "<="
  )) &&
    all(sweep(
      camera_locations,
      2L,
      total_locations,
      FUN = "<="
    ))
  if (!within_total) {
    .stop_invalid_flexirich_g_summary(paste0(
      "Candidate and camera replicated locations must not exceed ",
      "corresponding total-detection locations."
    ))
  }

  means_agree <- abs(
    sum(ppc$detections_per_candidate$replicated_mean) -
      ppc$total_detections$replicated_mean
  ) <= 1e-10 &&
    abs(
      sum(ppc$detections_per_camera$replicated_mean) -
        ppc$total_detections$replicated_mean
    ) <= 1e-10
  if (sum(ppc$detections_per_candidate$observed) != observed_total ||
      sum(ppc$detections_per_camera$observed) != observed_total ||
      !means_agree) {
    .stop_invalid_flexirich_g_summary(
      "posterior predictive margins do not reconstruct detection totals."
    )
  }

  generated <- diagnostics$generated_richness
  generated_fields <- c(
    "pmf",
    "max_absolute_difference",
    "simultaneous_bound",
    "agrees"
  )
  if (!is.list(generated) ||
      !identical(names(generated), generated_fields)) {
    .stop_invalid_flexirich_g_summary(
      "generated richness has an invalid verification contract."
    )
  }
  generated_pmf <- tryCatch(
    .validate_richness_pmf(generated$pmf),
    error = function(e) NULL
  )
  maximum_difference <- if (is.null(generated_pmf)) {
    Inf
  } else {
    max(abs(
      generated_pmf$probability - pmf$probability
    ))
  }
  valid_generated <- !is.null(generated_pmf) &&
    identical(
      generated_pmf$candidate_pool_size,
      candidate_pool
    ) &&
    is.numeric(generated$max_absolute_difference) &&
    length(generated$max_absolute_difference) == 1L &&
    is.finite(generated$max_absolute_difference) &&
    abs(
      generated$max_absolute_difference - maximum_difference
    ) <= 1e-12 &&
    is.numeric(generated$simultaneous_bound) &&
    length(generated$simultaneous_bound) == 1L &&
    is.finite(generated$simultaneous_bound) &&
    generated$simultaneous_bound >= 0 &&
    generated$simultaneous_bound <= 1 &&
    is.logical(generated$agrees) &&
    length(generated$agrees) == 1L &&
    isTRUE(generated$agrees) &&
    maximum_difference <= generated$simultaneous_bound
  if (!valid_generated) {
    .stop_invalid_flexirich_g_summary(
      "generated richness does not verify the posterior PMF."
    )
  }

  TRUE
}
