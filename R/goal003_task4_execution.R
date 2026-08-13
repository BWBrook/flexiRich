.goal003_task4_execution_stop <- function(message) {
  stop(message, call. = FALSE)
}

.goal003_task4_artifact_id <- function(artifact_id) {
  valid <- is.character(artifact_id) &&
    length(artifact_id) == 1L &&
    !is.na(artifact_id) &&
    grepl("^[A-Za-z0-9][A-Za-z0-9._-]*$", artifact_id)
  if (!valid) {
    .goal003_task4_execution_stop("artifact_id is invalid.")
  }
  artifact_id
}

#' Inspect one non-overwriting Task 4 row artifact
goal003_task4_artifact_state <- function(parent, artifact_id) {
  artifact_id <- .goal003_task4_artifact_id(artifact_id)
  final <- file.path(parent, artifact_id)
  staging <- file.path(parent, paste0(".staging-", artifact_id))
  if (dir.exists(staging) || file.exists(staging)) {
    return("interrupted")
  }
  if (dir.exists(final) || file.exists(final)) {
    if (dir.exists(final) &&
        file.exists(file.path(final, "completion-status.txt"))) {
      return("complete")
    }
    return("interrupted")
  }
  "pending"
}

#' Publish one Task 4 artifact atomically and without overwrite
publish_goal003_task4_artifact <- function(parent, artifact_id, writer) {
  artifact_id <- .goal003_task4_artifact_id(artifact_id)
  if (!is.function(writer)) {
    .goal003_task4_execution_stop("writer must be a function.")
  }
  dir.create(parent, recursive = TRUE, showWarnings = FALSE)
  state <- goal003_task4_artifact_state(parent, artifact_id)
  if (identical(state, "complete")) {
    .goal003_task4_execution_stop("The Task 4 artifact already exists.")
  }
  if (identical(state, "interrupted")) {
    .goal003_task4_execution_stop(
      "The Task 4 artifact has interrupted staging that requires diagnosis."
    )
  }
  final <- file.path(parent, artifact_id)
  staging <- file.path(parent, paste0(".staging-", artifact_id))
  if (!dir.create(staging, recursive = FALSE, showWarnings = FALSE)) {
    .goal003_task4_execution_stop("Could not create Task 4 staging.")
  }
  writer(staging)
  completion <- file.path(staging, "completion-status.txt")
  if (!file.exists(completion)) {
    .goal003_task4_execution_stop(
      "Task 4 artifact writer did not write completion-status.txt last."
    )
  }
  if (!file.rename(staging, final)) {
    .goal003_task4_execution_stop("Could not publish the Task 4 artifact.")
  }
  normalizePath(final, mustWork = TRUE)
}

#' Audit frozen dataset and fit rows against a Task 4 output directory
audit_goal003_task4_run_rows <- function(output_dir, manifest) {
  if (!is.list(manifest) ||
      !all(c("datasets", "fits") %in% names(manifest))) {
    .goal003_task4_execution_stop("manifest lacks Task 4 rows.")
  }
  dataset_parent <- file.path(output_dir, "datasets")
  fit_parent <- file.path(output_dir, "fits")
  datasets <- manifest$datasets |>
    dplyr::mutate(state = vapply(
      dataset_id,
      function(id) goal003_task4_artifact_state(dataset_parent, id),
      character(1)
    ))
  fits <- manifest$fits |>
    dplyr::mutate(state = vapply(
      fit_id,
      function(id) goal003_task4_artifact_state(fit_parent, id),
      character(1)
    ))
  list(datasets = datasets, fits = fits)
}

#' Extend synthetic truth for the broader named-pool sensitivity
expand_goal003_task4_truth <- function(truth, candidate_pool_size = 106L) {
  .goal003_task4_validate_truth(truth)
  C <- nrow(truth$species)
  valid <- is.numeric(candidate_pool_size) &&
    !is.logical(candidate_pool_size) &&
    length(candidate_pool_size) == 1L &&
    !is.na(candidate_pool_size) &&
    is.finite(candidate_pool_size) &&
    candidate_pool_size == trunc(candidate_pool_size) &&
    candidate_pool_size >= C &&
    candidate_pool_size <= .Machine$integer.max
  if (!valid) {
    .goal003_task4_execution_stop(
      "candidate_pool_size cannot define broader Task 4 truth."
    )
  }
  n_added <- as.integer(candidate_pool_size) - C
  if (n_added == 0L) {
    return(truth)
  }
  added <- tibble::tibble(
    species_id = sprintf("sp_%03d", C + seq_len(n_added)),
    member = FALSE,
    latent_normal = NA_real_,
    alpha = NA_real_,
    guild = "nonmember",
    season_phase = NA_integer_,
    training_detected = FALSE,
    future_detected = FALSE,
    future_first_detection = FALSE
  )
  truth$species <- dplyr::bind_rows(truth$species, added)
  .goal003_task4_validate_truth(truth)
  truth
}

.goal003_task4_write_csv <- function(data, path) {
  utils::write.csv(data, path, row.names = FALSE, na = "")
}

.goal003_task4_terminal_attempt <- function(fit) {
  name <- if (identical(fit$terminal_status, "primary_clean")) {
    "primary"
  } else if (identical(fit$terminal_status, "rescue_clean")) {
    "rescue"
  } else {
    names(fit$attempts)[[length(fit$attempts)]]
  }
  list(name = name, value = fit$attempts[[name]])
}

.goal003_task4_fit_status <- function(fit_row, fit) {
  terminal <- .goal003_task4_terminal_attempt(fit)
  metrics <- terminal$value$diagnostics$metrics
  if (is.null(metrics)) {
    metrics <- list(
      divergences = NA_integer_,
      treedepth_hits = NA_integer_,
      min_ebfmi = NA_real_,
      max_rhat = NA_real_,
      min_bulk_ess = NA_real_,
      min_tail_ess = NA_real_
    )
  }
  tibble::tibble(
    fit_id = fit_row$fit_id,
    dataset_id = fit_row$dataset_id,
    method = fit_row$method,
    run_role = fit_row$run_role,
    prior_profile = fit_row$prior_profile,
    pool_profile = fit_row$pool_profile,
    candidate_pool_size = fit_row$candidate_pool_size,
    fit_seed = fit_row$fit_seed,
    terminal_status = fit$terminal_status,
    terminal_clean = fit$terminal_status %in%
      c("primary_clean", "rescue_clean"),
    terminal_attempt = terminal$name,
    n_attempts = as.integer(length(fit$attempts)),
    elapsed_seconds = sum(vapply(
      fit$attempts,
      function(attempt) attempt$elapsed_seconds,
      numeric(1)
    )),
    divergences = metrics$divergences,
    treedepth_hits = metrics$treedepth_hits,
    min_ebfmi = metrics$min_ebfmi,
    max_rhat = metrics$max_rhat,
    min_bulk_ess = metrics$min_bulk_ess,
    min_tail_ess = metrics$min_tail_ess,
    reasons = paste(terminal$value$diagnostics$reasons, collapse = "; ")
  )
}

.goal003_task4_fit_inputs <- function(simulation, fit_row) {
  data <- simulation$training_data
  truth <- simulation$truth
  if (fit_row$candidate_pool_size[[1L]] > length(data$candidate_ids)) {
    data <- expand_goal003_task4_candidate_pool(
      data,
      fit_row$candidate_pool_size[[1L]]
    )
    truth <- expand_goal003_task4_truth(
      truth,
      fit_row$candidate_pool_size[[1L]]
    )
  }
  list(
    data = data,
    future_effort = simulation$forecast_effort,
    truth = truth
  )
}

.goal003_task4_write_fit_summary <- function(fit, staging) {
  terminal <- .goal003_task4_terminal_attempt(fit)$value
  if (is.null(terminal$fit)) {
    return(invisible(NULL))
  }
  summary <- terminal$fit$summary()
  keep <- intersect(
    c(
      "variable", "mean", "median", "sd", "mad", "q5", "q95",
      "rhat", "ess_bulk", "ess_tail"
    ),
    names(summary)
  )
  .goal003_task4_write_csv(
    summary[keep],
    file.path(staging, "compact-fit-summary.csv")
  )
}

.goal003_task4_write_dataset <- function(dataset_row, manifest, staging) {
  simulation <- simulate_goal003_task4_dataset(dataset_row, manifest)
  baseline <- evaluate_goal003_task4_baselines(simulation)
  saveRDS(simulation, file.path(staging, "simulation.rds"), version = 3)
  .goal003_task4_write_csv(
    simulation$truth$species,
    file.path(staging, "truth-species.csv")
  )
  .goal003_task4_write_csv(
    simulation$truth$cameras,
    file.path(staging, "truth-cameras.csv")
  )
  .goal003_task4_write_csv(
    baseline$point_predictions,
    file.path(staging, "baseline-point-predictions.csv")
  )
  .goal003_task4_write_csv(
    baseline$richness_scores,
    file.path(staging, "baseline-richness-scores.csv")
  )
  .goal003_task4_write_csv(
    baseline$discovery_scores,
    file.path(staging, "baseline-discovery-scores.csv")
  )
  status <- dplyr::bind_cols(
    dataset_row,
    tibble::tibble(
      observed_richness = simulation$truth$observed_richness,
      true_new_species = simulation$truth$true_new_species,
      training_active_camera_days =
        simulation$audit$training_active_camera_days,
      forecast_active_camera_days =
        simulation$audit$forecast_active_camera_days,
      training_data_hash = simulation$training_data$data_hash
    )
  )
  .goal003_task4_write_csv(status, file.path(staging, "dataset-status.csv"))
  writeLines(
    c(
      "status=COMPLETE",
      paste0("dataset_id=", dataset_row$dataset_id),
      paste0("simulation_seed=", dataset_row$simulation_seed)
    ),
    file.path(staging, "completion-status.txt")
  )
}

.goal003_task4_write_fit <- function(fit_row, simulation, staging, refresh) {
  inputs <- .goal003_task4_fit_inputs(simulation, fit_row)
  sampler_dir <- file.path(staging, "sampler")
  if (identical(fit_row$method[[1L]], "flexirich")) {
    data <- prepare_goal003_flexirich_data(
      inputs$data,
      prior_id = fit_row$prior_profile[[1L]]
    )
    if (any(c("truth", "member", "true_richness") %in% names(data))) {
      .goal003_task4_execution_stop("Synthetic truth entered FlexiRich data.")
    }
    fit <- fit_goal003_flexirich(
      data,
      seed = fit_row$fit_seed[[1L]],
      output_dir = sampler_dir,
      rescue = TRUE,
      refresh = refresh
    )
    prediction <- if (fit$terminal_status == "final_nonclean") NULL else
      predict_goal003_flexirich(fit, inputs$future_effort)
  } else if (identical(fit_row$method[[1L]], "occupancy")) {
    data <- prepare_goal003_occupancy_data(inputs$data)
    if (any(c("truth", "member", "true_richness") %in% names(data))) {
      .goal003_task4_execution_stop("Synthetic truth entered occupancy data.")
    }
    fit <- fit_goal003_occupancy(
      data,
      seed = fit_row$fit_seed[[1L]],
      output_dir = sampler_dir,
      rescue = TRUE,
      refresh = refresh
    )
    prediction <- if (fit$terminal_status == "final_nonclean") NULL else
      predict_goal003_occupancy(fit, inputs$future_effort)
  } else {
    .goal003_task4_execution_stop("The fit manifest names an unknown method.")
  }
  clean <- fit$terminal_status != "final_nonclean"
  scores <- score_goal003_task4_prediction(
    dataset_id = fit_row$dataset_id[[1L]],
    fit_id = fit_row$fit_id[[1L]],
    method = fit_row$method[[1L]],
    run_role = fit_row$run_role[[1L]],
    terminal_clean = clean,
    truth = inputs$truth,
    richness_pmf = if (clean) prediction$richness_pmf else NULL,
    new_species_count_pmf = if (clean) {
      prediction$new_species_count_pmf
    } else {
      NULL
    },
    future_identity = if (clean) prediction$future_identity else NULL
  )
  score_context <- fit_row[c(
    "prior_profile", "pool_profile", "candidate_pool_size"
  )]
  richness_score <- dplyr::bind_cols(scores$richness, score_context)
  discovery_score <- dplyr::bind_cols(scores$discovery, score_context)
  status <- .goal003_task4_fit_status(fit_row, fit)
  .goal003_task4_write_csv(status, file.path(staging, "fit-status.csv"))
  .goal003_task4_write_csv(
    richness_score,
    file.path(staging, "richness-score.csv")
  )
  .goal003_task4_write_csv(
    discovery_score,
    file.path(staging, "discovery-score.csv")
  )
  if (clean) {
    .goal003_task4_write_csv(
      prediction$richness_pmf,
      file.path(staging, "richness-pmf.csv")
    )
    .goal003_task4_write_csv(
      prediction$new_species_count_pmf,
      file.path(staging, "new-species-count-pmf.csv")
    )
    .goal003_task4_write_csv(
      prediction$grid_identity,
      file.path(staging, "grid-probabilities.csv")
    )
    .goal003_task4_write_csv(
      prediction$future_identity,
      file.path(staging, "future-detection-probabilities.csv")
    )
  }
  .goal003_task4_write_fit_summary(fit, staging)
  writeLines(
    c(
      "status=COMPLETE",
      paste0("fit_id=", fit_row$fit_id),
      paste0("terminal_status=", fit$terminal_status),
      paste0("fit_seed=", fit_row$fit_seed)
    ),
    file.path(staging, "completion-status.txt")
  )
}

.goal003_task4_read_rows <- function(
  paths,
  character_fields = character(),
  logical_fields = character(),
  integer_fields = character(),
  numeric_fields = character()
) {
  rows <- lapply(paths, function(path) {
    value <- tibble::as_tibble(utils::read.csv(
      path,
      stringsAsFactors = FALSE,
      check.names = FALSE,
      na.strings = ""
    ))
    for (field in intersect(character_fields, names(value))) {
      value[[field]] <- as.character(value[[field]])
    }
    for (field in intersect(logical_fields, names(value))) {
      value[[field]] <- as.logical(value[[field]])
    }
    for (field in intersect(integer_fields, names(value))) {
      value[[field]] <- as.integer(value[[field]])
    }
    for (field in intersect(numeric_fields, names(value))) {
      value[[field]] <- as.numeric(value[[field]])
    }
    value
  })
  dplyr::bind_rows(rows)
}

.goal003_task4_read_richness_scores <- function(paths) {
  .goal003_task4_read_rows(
    paths,
    character_fields = c(
      "dataset_id", "fit_id", "method", "run_role", "prior_profile",
      "pool_profile"
    ),
    logical_fields = c(
      "terminal_clean", "prediction_available", "interval_90_covered"
    ),
    integer_fields = c(
      "true_richness", "interval_90_lower", "interval_90_upper",
      "candidate_pool_size"
    ),
    numeric_fields = c(
      "point_estimate", "absolute_error", "rps", "log_score",
      "interval_90_width"
    )
  )
}

.goal003_task4_read_discovery_scores <- function(paths) {
  .goal003_task4_read_rows(
    paths,
    character_fields = c(
      "dataset_id", "fit_id", "method", "run_role", "prior_profile",
      "pool_profile"
    ),
    logical_fields = c(
      "terminal_clean", "prediction_available",
      "identity_prediction_available"
    ),
    integer_fields = c(
      "true_new_species", "n_unseen_candidates", "candidate_pool_size"
    ),
    numeric_fields = c(
      "expected_new_species", "absolute_error", "count_rps",
      "identity_brier"
    )
  )
}

.goal003_task4_source_hashes <- function(root) {
  files <- c(
    sort(list.files(file.path(root, "R"), pattern = "\\.R$", full.names = TRUE)),
    sort(list.files(file.path(root, "stan"), pattern = "\\.stan$", full.names = TRUE)),
    file.path(root, "scripts", "run_goal003_task4_screen.R"),
    file.path(root, "renv.lock")
  )
  files <- files[file.exists(files)]
  tibble::tibble(
    path = substring(files, nchar(root) + 2L),
    sha256 = vapply(files, function(path) {
      digest::digest(file = path, algo = "sha256", serialize = FALSE)
    }, character(1))
  )
}

.goal003_task4_package_versions <- function() {
  packages <- c(
    "cmdstanr", "posterior", "dplyr", "tidyr", "tibble", "digest",
    "iNEXT", "testthat"
  )
  tibble::tibble(
    package = packages,
    version = vapply(packages, function(package) {
      as.character(utils::packageVersion(package))
    }, character(1))
  )
}

.goal003_task4_git_state <- function(root) {
  status <- system2(
    "git",
    c("-C", root, "status", "--porcelain"),
    stdout = TRUE,
    stderr = TRUE
  )
  commit <- system2(
    "git",
    c("-C", root, "rev-parse", "HEAD"),
    stdout = TRUE,
    stderr = TRUE
  )
  if (length(status) > 0L || length(commit) != 1L ||
      !grepl("^[0-9a-f]{40}$", commit)) {
    .goal003_task4_execution_stop(
      "The Task 4 screen requires one clean committed Git state."
    )
  }
  commit
}

.goal003_task4_output_path <- function(root, output_dir) {
  boundary <- normalizePath(
    file.path(root, "outputs", "goal003"),
    mustWork = FALSE
  )
  output <- normalizePath(
    if (startsWith(output_dir, "/")) output_dir else file.path(root, output_dir),
    mustWork = FALSE
  )
  if (!startsWith(output, paste0(boundary, .Platform$file.sep))) {
    .goal003_task4_execution_stop(
      "output_dir must be beneath outputs/goal003."
    )
  }
  output
}

.goal003_task4_validate_manifest_copies <- function(output_dir, manifest) {
  copied <- file.path(
    output_dir,
    "manifests",
    basename(.goal003_task4_paths(.goal003_project_root()))
  )
  if (any(!file.exists(copied))) {
    .goal003_task4_execution_stop(
      "Task 4 output is missing a frozen manifest copy."
    )
  }
  hashes <- vapply(copied, function(path) {
    digest::digest(file = path, algo = "sha256", serialize = FALSE)
  }, character(1))
  names(hashes) <- names(manifest$hashes)
  if (!identical(hashes, manifest$hashes)) {
    .goal003_task4_execution_stop(
      "Task 4 output manifest copies differ from the frozen hashes."
    )
  }
  invisible(TRUE)
}

.goal003_task4_initialise_run <- function(
  output_dir,
  manifest,
  git_commit,
  max_workers
) {
  root <- .goal003_project_root()
  if (dir.exists(output_dir) || file.exists(output_dir)) {
    metadata_path <- file.path(output_dir, "run-metadata.rds")
    if (!file.exists(metadata_path)) {
      .goal003_task4_execution_stop(
        "Existing Task 4 output lacks run metadata and cannot be resumed."
      )
    }
    metadata <- readRDS(metadata_path)
    valid <- identical(metadata$git_commit, git_commit) &&
      identical(metadata$manifest_hashes, manifest$hashes) &&
      identical(metadata$max_workers, as.integer(max_workers))
    if (!valid) {
      .goal003_task4_execution_stop(
        "Existing Task 4 output differs from this frozen run."
      )
    }
    .goal003_task4_validate_manifest_copies(output_dir, manifest)
    if (file.exists(file.path(output_dir, "completion-status.txt"))) {
      .goal003_task4_execution_stop("The frozen Task 4 run is already complete.")
    }
    return(invisible(output_dir))
  }

  parent <- dirname(output_dir)
  staging <- file.path(parent, paste0(".initialising-", basename(output_dir)))
  if (dir.exists(staging) || file.exists(staging)) {
    .goal003_task4_execution_stop(
      "Interrupted Task 4 run initialisation requires diagnosis."
    )
  }
  dir.create(staging, recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(staging, "manifests"))
  manifest_paths <- .goal003_task4_paths(root)
  copied <- file.copy(
    manifest_paths,
    file.path(staging, "manifests", basename(manifest_paths)),
    overwrite = FALSE
  )
  if (!all(copied)) {
    .goal003_task4_execution_stop("Could not copy frozen Task 4 manifests.")
  }
  metadata <- list(
    git_commit = git_commit,
    manifest_hashes = manifest$hashes,
    max_workers = as.integer(max_workers),
    rng_kind = unname(.sim_rng_algorithms[["kind"]]),
    rng_normal_kind = unname(.sim_rng_algorithms[["normal.kind"]]),
    rng_sample_kind = unname(.sim_rng_algorithms[["sample.kind"]]),
    r_version = R.version.string,
    cmdstan_version = as.character(cmdstanr::cmdstan_version()),
    host = unname(Sys.info()[["nodename"]]),
    started_utc = format(Sys.time(), tz = "UTC", usetz = TRUE)
  )
  saveRDS(metadata, file.path(staging, "run-metadata.rds"), version = 3)
  .goal003_task4_write_csv(
    .goal003_task4_source_hashes(root),
    file.path(staging, "source-hashes.csv")
  )
  .goal003_task4_write_csv(
    .goal003_task4_package_versions(),
    file.path(staging, "package-versions.csv")
  )
  writeLines("status=INITIALISED", file.path(staging, "initialisation-status.txt"))
  if (!file.rename(staging, output_dir)) {
    .goal003_task4_execution_stop("Could not publish Task 4 run initialisation.")
  }
  .goal003_task4_validate_manifest_copies(output_dir, manifest)
  invisible(output_dir)
}

.goal003_task4_aggregate <- function(output_dir, manifest) {
  dataset_dirs <- file.path(output_dir, "datasets", manifest$datasets$dataset_id)
  fit_dirs <- file.path(output_dir, "fits", manifest$fits$fit_id)
  dataset_status <- .goal003_task4_read_rows(file.path(
    dataset_dirs,
    "dataset-status.csv"
  ))
  fit_status <- .goal003_task4_read_rows(
    file.path(fit_dirs, "fit-status.csv"),
    character_fields = c(
      "fit_id", "dataset_id", "method", "run_role", "prior_profile",
      "pool_profile", "terminal_status", "terminal_attempt", "reasons"
    ),
    logical_fields = "terminal_clean",
    integer_fields = c(
      "candidate_pool_size", "fit_seed", "n_attempts", "divergences",
      "treedepth_hits"
    ),
    numeric_fields = c(
      "elapsed_seconds", "min_ebfmi", "max_rhat", "min_bulk_ess",
      "min_tail_ess"
    )
  )
  baseline_point <- .goal003_task4_read_rows(
    file.path(dataset_dirs, "baseline-point-predictions.csv"),
    character_fields = c("dataset_id", "method", "reason"),
    logical_fields = "eligible",
    numeric_fields = c("raw_estimate", "estimate")
  )
  baseline_richness <- .goal003_task4_read_richness_scores(file.path(
    dataset_dirs,
    "baseline-richness-scores.csv"
  ))
  baseline_discovery <- .goal003_task4_read_discovery_scores(file.path(
    dataset_dirs,
    "baseline-discovery-scores.csv"
  ))
  fit_richness <- .goal003_task4_read_richness_scores(file.path(
    fit_dirs,
    "richness-score.csv"
  ))
  fit_discovery <- .goal003_task4_read_discovery_scores(file.path(
    fit_dirs,
    "discovery-score.csv"
  ))
  richness <- dplyr::bind_rows(baseline_richness, fit_richness)
  discovery <- dplyr::bind_rows(baseline_discovery, fit_discovery)
  .goal003_task4_validate_aggregate(
    manifest,
    dataset_status,
    fit_status,
    baseline_point,
    richness,
    discovery
  )
  gates <- evaluate_goal003_task4_gates(
    manifest,
    fit_status,
    richness
  )
  list(
    dataset_status = dataset_status,
    fit_status = fit_status,
    baseline_point = baseline_point,
    richness = richness,
    discovery = discovery,
    score_summary = summarise_goal003_task4_scores(richness, discovery),
    gates = gates
  )
}

.goal003_task4_validate_aggregate <- function(
  manifest,
  dataset_status,
  fit_status,
  baseline_point,
  richness,
  discovery
) {
  exact_ids <- function(observed, expected) {
    length(observed) == length(expected) &&
      !anyNA(observed) &&
      !anyDuplicated(observed) &&
      setequal(observed, expected)
  }
  dataset_ok <- exact_ids(
    dataset_status$dataset_id,
    manifest$datasets$dataset_id
  )
  fit_ok <- exact_ids(fit_status$fit_id, manifest$fits$fit_id)
  fit_richness <- dplyr::filter(richness, !is.na(fit_id))
  fit_discovery <- dplyr::filter(discovery, !is.na(fit_id))
  score_ok <- exact_ids(fit_richness$fit_id, manifest$fits$fit_id) &&
    exact_ids(fit_discovery$fit_id, manifest$fits$fit_id)
  baseline_ok <- nrow(baseline_point) == 6L * 300L &&
    nrow(dplyr::filter(richness, is.na(fit_id))) == 7L * 300L &&
    nrow(dplyr::filter(discovery, is.na(fit_id))) == 2L * 300L
  if (!dataset_ok || !fit_ok || !score_ok || !baseline_ok) {
    .goal003_task4_execution_stop(
      "Task 4 aggregate rows do not match the frozen output contract."
    )
  }
  invisible(TRUE)
}

#' Summarise scheduled and scored Task 4 denominators
summarise_goal003_task4_scores <- function(richness, discovery) {
  richness_summary <- richness |>
    dplyr::mutate(
      prior_profile = dplyr::coalesce(prior_profile, "not_applicable"),
      pool_profile = dplyr::coalesce(pool_profile, "primary_50"),
      proper_score_available = !is.na(rps),
      interval_available = method %in%
        c("observed", "lower_prior", "flexirich", "occupancy")
    ) |>
    dplyr::summarise(
      scheduled = dplyr::n(),
      predictions_scored = sum(prediction_available),
      proper_scores = sum(proper_score_available),
      coverage_numerator = sum(interval_90_covered & interval_available),
      coverage_denominator = sum(interval_available),
      .by = c(method, run_role, prior_profile, pool_profile)
    )
  discovery_summary <- discovery |>
    dplyr::mutate(
      prior_profile = dplyr::coalesce(prior_profile, "not_applicable"),
      pool_profile = dplyr::coalesce(pool_profile, "primary_50")
    ) |>
    dplyr::summarise(
      scheduled = dplyr::n(),
      count_predictions_scored = sum(prediction_available),
      proper_count_scores = sum(!is.na(count_rps)),
      identity_predictions_scored = sum(identity_prediction_available),
      identity_scores = sum(!is.na(identity_brier)),
      .by = c(method, run_role, prior_profile, pool_profile)
    )
  list(richness = richness_summary, discovery = discovery_summary)
}

.goal003_task4_write_results <- function(results, staging) {
  .goal003_task4_write_csv(
    results$dataset_status,
    file.path(staging, "dataset-status.csv")
  )
  .goal003_task4_write_csv(
    results$fit_status,
    file.path(staging, "fit-status.csv")
  )
  .goal003_task4_write_csv(
    results$baseline_point,
    file.path(staging, "baseline-point-predictions.csv")
  )
  .goal003_task4_write_csv(
    results$richness,
    file.path(staging, "richness-scores.csv")
  )
  .goal003_task4_write_csv(
    results$discovery,
    file.path(staging, "discovery-scores.csv")
  )
  .goal003_task4_write_csv(
    results$score_summary$richness,
    file.path(staging, "richness-score-summary.csv")
  )
  .goal003_task4_write_csv(
    results$score_summary$discovery,
    file.path(staging, "discovery-score-summary.csv")
  )
  .goal003_task4_write_csv(
    results$gates$cell_summary,
    file.path(staging, "cell-summary.csv")
  )
  .goal003_task4_write_csv(
    results$gates$sensitivity_pairs,
    file.path(staging, "sensitivity-pairs.csv")
  )
  .goal003_task4_write_csv(
    results$gates$gates,
    file.path(staging, "screening-gates.csv")
  )
  status <- if (all(results$gates$gates$passed)) "SCREEN_PASS" else "SCREEN_STOP"
  writeLines(
    c(paste0("status=", status), "rows_complete=true"),
    file.path(staging, "completion-status.txt")
  )
}

#' Run or resume the frozen Goal003 Task 4 synthetic screen
run_goal003_task4_screen <- function(
  output_dir = file.path("outputs", "goal003", "task4-screen-v1"),
  max_workers = 8L,
  refresh = 100L
) {
  valid_workers <- is.numeric(max_workers) &&
    !is.logical(max_workers) &&
    length(max_workers) == 1L &&
    !is.na(max_workers) &&
    is.finite(max_workers) &&
    max_workers == trunc(max_workers) &&
    max_workers >= 1L && max_workers <= 8L
  valid_refresh <- is.numeric(refresh) &&
    !is.logical(refresh) &&
    length(refresh) == 1L &&
    !is.na(refresh) &&
    is.finite(refresh) &&
    refresh == trunc(refresh) && refresh >= 0L
  if (!valid_workers || !valid_refresh || .Platform$OS.type != "unix") {
    .goal003_task4_execution_stop(
      "Task 4 requires one to eight Unix workers and non-negative refresh."
    )
  }
  max_workers <- as.integer(max_workers)
  refresh <- as.integer(refresh)
  root <- .goal003_project_root()
  git_commit <- .goal003_task4_git_state(root)
  manifest <- read_goal003_task4_manifests()
  output_dir <- .goal003_task4_output_path(root, output_dir)
  .goal003_task4_initialise_run(
    output_dir,
    manifest,
    git_commit,
    max_workers
  )
  cat("task4_git_commit=", git_commit, "\n", sep = "")
  cat("task4_output_dir=", output_dir, "\n", sep = "")
  dir.create(file.path(output_dir, "datasets"), showWarnings = FALSE)
  dir.create(file.path(output_dir, "fits"), showWarnings = FALSE)

  state <- audit_goal003_task4_run_rows(output_dir, manifest)
  if (any(state$datasets$state == "interrupted") ||
      any(state$fits$state == "interrupted")) {
    .goal003_task4_execution_stop(
      "Interrupted Task 4 row staging requires diagnosis before resume."
    )
  }
  pending_datasets <- dplyr::filter(state$datasets, state == "pending")
  cat("task4_pending_datasets=", nrow(pending_datasets), "\n", sep = "")
  for (index in seq_len(nrow(pending_datasets))) {
    row <- pending_datasets[index, .goal003_task4_dataset_fields]
    publish_goal003_task4_artifact(
      file.path(output_dir, "datasets"),
      row$dataset_id,
      function(staging) {
        .goal003_task4_write_dataset(row, manifest, staging)
      }
    )
    if (index %% 25L == 0L || index == nrow(pending_datasets)) {
      cat(
        "task4_datasets_completed_this_run=",
        index,
        "/",
        nrow(pending_datasets),
        "\n",
        sep = ""
      )
    }
  }

  state <- audit_goal003_task4_run_rows(output_dir, manifest)
  pending_fits <- dplyr::filter(state$fits, state == "pending")
  cat("task4_pending_fits=", nrow(pending_fits), "\n", sep = "")
  if (nrow(pending_fits) > 0L) {
    compile_goal003_flexirich_model()
    compile_goal003_occupancy_model()
    results <- parallel::mclapply(
      seq_len(nrow(pending_fits)),
      function(index) {
        row <- pending_fits[index, .goal003_task4_fit_fields]
        simulation <- readRDS(file.path(
          output_dir,
          "datasets",
          row$dataset_id,
          "simulation.rds"
        ))
        publish_goal003_task4_artifact(
          file.path(output_dir, "fits"),
          row$fit_id,
          function(staging) {
            .goal003_task4_write_fit(row, simulation, staging, refresh)
          }
        )
        cat("task4_fit_complete=", row$fit_id, "\n", sep = "")
        row$fit_id
      },
      mc.cores = max_workers,
      mc.preschedule = FALSE
    )
    failed <- vapply(results, inherits, logical(1), what = "try-error")
    if (any(failed)) {
      .goal003_task4_execution_stop(
        "One or more Task 4 fit workers failed; staging is preserved."
      )
    }
  }

  final_state <- audit_goal003_task4_run_rows(output_dir, manifest)
  if (any(final_state$datasets$state != "complete") ||
      any(final_state$fits$state != "complete")) {
    .goal003_task4_execution_stop("Task 4 rows are not all complete.")
  }
  results_state <- goal003_task4_artifact_state(output_dir, "results")
  if (identical(results_state, "interrupted")) {
    .goal003_task4_execution_stop(
      "Interrupted Task 4 result staging requires diagnosis."
    )
  }
  if (identical(results_state, "pending")) {
    publish_goal003_task4_artifact(
      output_dir,
      "results",
      function(staging) {
        .goal003_task4_write_results(
          .goal003_task4_aggregate(output_dir, manifest),
          staging
        )
      }
    )
  }
  gate_path <- file.path(output_dir, "results", "screening-gates.csv")
  gates <- utils::read.csv(gate_path, stringsAsFactors = FALSE)
  final_status <- if (all(gates$passed)) "SCREEN_PASS" else "SCREEN_STOP"
  writeLines(
    c(
      paste0("status=", final_status),
      paste0("git_commit=", git_commit),
      "empirical_outcomes_used=false"
    ),
    file.path(output_dir, "completion-status.txt")
  )
  cat("task4_status=", final_status, "\n", sep = "")
  invisible(list(status = final_status, output_dir = output_dir))
}
