.goal005_task2_write_dataset <- function(dataset_row, manifest, staging) {
  simulation <- simulate_goal005_task2_dataset(dataset_row, manifest)
  prior <- score_goal005_task2_prior(dataset_row, simulation$truth)
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
    prior,
    file.path(staging, "prior-richness-score.csv")
  )
  status <- dataset_row |>
    dplyr::mutate(
      observed_richness = simulation$truth$observed_richness,
      true_new_species = simulation$truth$true_new_species,
      forecast_active_camera_days =
        simulation$audit$forecast_active_camera_days,
      training_data_hash = simulation$training_data$data_hash
    )
  .goal003_task4_write_csv(status, file.path(staging, "dataset-status.csv"))
  required <- c(
    "simulation.rds", "truth-species.csv", "truth-cameras.csv",
    "prior-richness-score.csv", "dataset-status.csv"
  )
  restored <- utils::read.csv(
    file.path(staging, "prior-richness-score.csv"),
    check.names = FALSE
  )
  if (any(!file.exists(file.path(staging, required))) || nrow(restored) != 1L) {
    .goal005_stop("Goal005 Task 2 dataset readback failed.")
  }
  writeLines(
    c(
      "status=COMPLETE",
      paste0("dataset_id=", dataset_row$dataset_id),
      paste0("simulation_seed=", dataset_row$simulation_seed),
      "empirical_outcomes_used=false"
    ),
    file.path(staging, "completion-status.txt")
  )
}

.goal005_task2_fit_model <- function(
  simulation,
  fit_row,
  output_dir,
  refresh
) {
  method <- fit_row$method[[1L]]
  level <- fit_row$information_level[[1L]]
  if (identical(method, "goal004") && identical(level, "C0")) {
    prepared <- prepare_goal004_flexirich_data(
      simulation$training_data,
      stats::setNames(
        goal004_task2_candidate_mapping()$core$encounter_class,
        goal004_task2_candidate_mapping()$core$candidate_id
      ),
      profile_id = "primary"
    )
    model <- compile_goal004_flexirich_model()
    monitored <- .goal004_flexirich_monitored_variables(prepared)
    extra_name <- "profile"
    extra <- goal004_flexirich_profile("primary")
  } else if (identical(method, "goal005_candidate_oracle") &&
      identical(level, "I0")) {
    candidate_rates <- stats::setNames(
      simulation$truth$species$alpha,
      simulation$truth$species$species_id
    )
    prepared <- prepare_goal005_candidate_oracle_data(
      simulation$training_data,
      candidate_rates
    )
    model <- compile_goal005_candidate_oracle_model()
    monitored <- .goal005_candidate_oracle_monitored_variables(prepared)
    extra_name <- "prior"
    extra <- goal005_candidate_oracle_prior()
  } else {
    .goal005_stop("The Goal005 fit row names an invalid oracle path.")
  }
  if (any(c("truth", "member", "true_richness") %in% names(prepared))) {
    .goal005_stop("Synthetic membership truth entered fitted Goal005 data.")
  }
  attempts <- .goal004_task4_run_attempts(
    model = model,
    stan_data = prepared$stan_data,
    profiles = goal003_flexirich_sampler_profiles(),
    thresholds = goal003_flexirich_diagnostic_thresholds(),
    monitored = monitored,
    seed = fit_row$fit_seed[[1L]],
    output_dir = output_dir,
    refresh = refresh
  )
  result <- list(
    terminal_status = attempts$terminal_status,
    data = prepared,
    extra = extra,
    output_dir = output_dir,
    attempts = attempts$attempts
  )
  names(result)[[3L]] <- extra_name
  result
}

.goal005_task2_predict_fit <- function(fit, fit_row) {
  if (identical(fit$terminal_status, "final_nonclean")) {
    return(NULL)
  }
  if (identical(fit_row$information_level[[1L]], "C0")) {
    return(predict_goal004_flexirich(fit)$posterior_richness_pmf)
  }
  if (identical(fit_row$information_level[[1L]], "I0")) {
    return(predict_goal005_candidate_oracle(fit)$posterior_richness_pmf)
  }
  .goal005_stop("Unknown Goal005 information level.")
}

.goal005_task2_fit_status <- function(fit_row, fit) {
  .goal003_task4_fit_status(fit_row, fit) |>
    dplyr::mutate(
      information_level = fit_row$information_level[[1L]],
      .after = run_role
    )
}

.goal005_task2_validate_fit_readback <- function(staging, clean) {
  required <- c("fit-status.csv", "richness-score.csv")
  if (any(!file.exists(file.path(staging, required)))) {
    .goal005_stop("Goal005 Task 2 compact fit evidence is incomplete.")
  }
  counts <- vapply(required, function(file) {
    nrow(utils::read.csv(file.path(staging, file), check.names = FALSE))
  }, integer(1))
  if (any(counts != 1L)) {
    .goal005_stop("Goal005 Task 2 compact fit evidence failed readback.")
  }
  if (clean) {
    path <- file.path(staging, "richness-pmf.csv")
    if (!file.exists(path)) {
      .goal005_stop("A clean Goal005 fit lacks its richness PMF.")
    }
    pmf <- utils::read.csv(path, check.names = FALSE)
    if (abs(sum(pmf$probability) - 1) > 1e-10) {
      .goal005_stop("A Goal005 richness PMF failed readback.")
    }
  }
  invisible(TRUE)
}

.goal005_task2_write_fit <- function(
  fit_row,
  simulation,
  staging,
  refresh
) {
  sampler_dir <- file.path(staging, "sampler")
  fit <- .goal005_task2_fit_model(
    simulation,
    fit_row,
    sampler_dir,
    refresh
  )
  clean <- fit$terminal_status %in% c("primary_clean", "rescue_clean")
  pmf <- .goal005_task2_predict_fit(fit, fit_row)
  score <- score_goal005_task2_fit(
    fit_row,
    simulation$truth,
    terminal_clean = clean,
    richness_pmf = pmf
  )
  status <- .goal005_task2_fit_status(fit_row, fit)
  .goal003_task4_write_csv(status, file.path(staging, "fit-status.csv"))
  .goal003_task4_write_csv(score, file.path(staging, "richness-score.csv"))
  if (clean) {
    .goal003_task4_write_csv(pmf, file.path(staging, "richness-pmf.csv"))
  }
  .goal003_task4_write_fit_summary(fit, staging)
  .goal005_task2_validate_fit_readback(staging, clean)
  .goal004_task4_compress_sampler_csv(staging)
  writeLines(
    c(
      "status=COMPLETE",
      paste0("fit_id=", fit_row$fit_id),
      paste0("information_level=", fit_row$information_level),
      paste0("terminal_status=", fit$terminal_status),
      paste0("fit_seed=", fit_row$fit_seed),
      "empirical_outcomes_used=false"
    ),
    file.path(staging, "completion-status.txt")
  )
}

.goal005_task2_read_fit_status <- function(paths) {
  .goal003_task4_read_rows(
    paths,
    character_fields = c(
      "fit_id", "dataset_id", "method", "run_role", "information_level",
      "prior_profile", "pool_profile", "terminal_status",
      "terminal_attempt", "reasons"
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
}

.goal005_task2_validate_aggregate <- function(
  manifest,
  dataset_status,
  fit_status,
  fit_richness,
  prior_richness
) {
  valid <- .goal005_task2_exact_ids(
    dataset_status$dataset_id,
    manifest$datasets$dataset_id
  ) &&
    .goal005_task2_exact_ids(fit_status$fit_id, manifest$fits$fit_id) &&
    .goal005_task2_exact_ids(fit_richness$fit_id, manifest$fits$fit_id) &&
    .goal005_task2_exact_ids(
      prior_richness$dataset_id,
      manifest$datasets$dataset_id
    )
  if (!valid) {
    .goal005_stop("Goal005 Task 2 aggregate rows differ from the contract.")
  }
  invisible(TRUE)
}

.goal005_task2_aggregate <- function(output_dir, manifest) {
  dataset_dirs <- file.path(output_dir, "datasets", manifest$datasets$dataset_id)
  fit_dirs <- file.path(output_dir, "fits", manifest$fits$fit_id)
  dataset_status <- .goal003_task4_read_rows(file.path(
    dataset_dirs,
    "dataset-status.csv"
  ))
  fit_status <- .goal005_task2_read_fit_status(file.path(
    fit_dirs,
    "fit-status.csv"
  ))
  prior_richness <- .goal003_task4_read_richness_scores(file.path(
    dataset_dirs,
    "prior-richness-score.csv"
  ))
  fit_richness <- .goal003_task4_read_richness_scores(file.path(
    fit_dirs,
    "richness-score.csv"
  ))
  .goal005_task2_validate_aggregate(
    manifest,
    dataset_status,
    fit_status,
    fit_richness,
    prior_richness
  )
  richness <- dplyr::bind_rows(prior_richness, fit_richness)
  gates <- evaluate_goal005_task2_gates(
    manifest,
    fit_status,
    richness,
    integrity_passed = TRUE
  )
  if (!isTRUE(gates$integrity$passed[[1L]])) {
    .goal005_stop("Goal005 Task 2 aggregate integrity failed.")
  }
  list(
    dataset_status = dataset_status,
    fit_status = fit_status,
    richness = richness,
    gates = gates
  )
}

.goal005_task2_write_results <- function(results, staging) {
  tables <- list(
    "dataset-status.csv" = results$dataset_status,
    "fit-status.csv" = results$fit_status,
    "richness-scores.csv" = results$richness,
    "information-ceiling-pairs.csv" = results$gates$pairs,
    "information-ceiling-gates.csv" = results$gates$gates,
    "duration-summary.csv" = results$gates$duration_summary,
    "task3-pruning.csv" = results$gates$pruning,
    "integrity-check.csv" = results$gates$integrity
  )
  for (name in names(tables)) {
    .goal003_task4_write_csv(tables[[name]], file.path(staging, name))
  }
  pruning <- utils::read.csv(
    file.path(staging, "task3-pruning.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  gates <- utils::read.csv(
    file.path(staging, "information-ceiling-gates.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  if (nrow(pruning) != 5L || nrow(gates) != 170L || anyNA(gates$passed)) {
    .goal005_stop("Goal005 Task 2 result readback failed.")
  }
  writeLines(
    c(
      "status=TASK2_COMPLETE",
      "rows_complete=true",
      "empirical_outcomes_used=false"
    ),
    file.path(staging, "completion-status.txt")
  )
}

.goal005_task2_output_path <- function(root, output_dir) {
  boundary <- normalizePath(
    file.path(root, "outputs", "goal005"),
    mustWork = FALSE
  )
  output <- normalizePath(
    if (startsWith(output_dir, "/")) output_dir else file.path(root, output_dir),
    mustWork = FALSE
  )
  if (!startsWith(output, paste0(boundary, .Platform$file.sep))) {
    .goal005_stop("output_dir must be beneath outputs/goal005.")
  }
  output
}

.goal005_task2_source_hashes <- function(root) {
  files <- c(
    sort(list.files(file.path(root, "R"), pattern = "[.]R$", full.names = TRUE)),
    sort(list.files(file.path(root, "stan"), pattern = "[.]stan$", full.names = TRUE)),
    file.path(root, "scripts", "run_goal005_task2_information_ceiling.R"),
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

.goal005_task2_validate_manifest_copies <- function(output_dir, manifest) {
  paths <- .goal005_task2_paths(.goal003_project_root())
  copies <- file.path(output_dir, "manifests", basename(paths))
  if (any(!file.exists(copies))) {
    .goal005_stop("Goal005 Task 2 is missing a frozen manifest copy.")
  }
  hashes <- vapply(copies, function(path) {
    digest::digest(file = path, algo = "sha256", serialize = FALSE)
  }, character(1))
  names(hashes) <- names(manifest$hashes)
  if (!identical(hashes, manifest$hashes)) {
    .goal005_stop("Goal005 Task 2 manifest copies changed.")
  }
  invisible(TRUE)
}

.goal005_task2_initialise_run <- function(
  output_dir,
  manifest,
  git_commit,
  max_workers
) {
  root <- .goal003_project_root()
  if (dir.exists(output_dir) || file.exists(output_dir)) {
    path <- file.path(output_dir, "run-metadata.rds")
    if (!file.exists(path)) {
      .goal005_stop("Existing Goal005 Task 2 output lacks run metadata.")
    }
    metadata <- readRDS(path)
    valid <- identical(metadata$git_commit, git_commit) &&
      identical(metadata$manifest_hashes, manifest$hashes) &&
      identical(metadata$max_workers, as.integer(max_workers))
    if (!valid) {
      .goal005_stop("Existing Goal005 Task 2 output differs from this run.")
    }
    .goal005_task2_validate_manifest_copies(output_dir, manifest)
    if (file.exists(file.path(output_dir, "completion-status.txt"))) {
      .goal005_stop("The frozen Goal005 Task 2 run is complete.")
    }
    return(invisible(output_dir))
  }
  parent <- dirname(output_dir)
  staging <- file.path(parent, paste0(".initialising-", basename(output_dir)))
  if (dir.exists(staging) || file.exists(staging)) {
    .goal005_stop("Interrupted Goal005 Task 2 initialisation exists.")
  }
  dir.create(staging, recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(staging, "manifests"))
  paths <- .goal005_task2_paths(root)
  copied <- file.copy(
    paths,
    file.path(staging, "manifests", basename(paths)),
    overwrite = FALSE
  )
  if (!all(copied)) {
    .goal005_stop("Could not copy Goal005 Task 2 manifests.")
  }
  metadata <- list(
    git_commit = git_commit,
    manifest_hashes = manifest$hashes,
    max_workers = as.integer(max_workers),
    simulation_seed_rule = "650000000 + replicate",
    fit_seed_rule = paste0(
      "750000000 + 1000000 * information_code + ",
      "10000 * scenario_order + 100 * train_occasions + replicate"
    ),
    rng_kind = unname(.sim_rng_algorithms[["kind"]]),
    rng_normal_kind = unname(.sim_rng_algorithms[["normal.kind"]]),
    rng_sample_kind = unname(.sim_rng_algorithms[["sample.kind"]]),
    r_version = R.version.string,
    cmdstan_version = as.character(cmdstanr::cmdstan_version()),
    host = unname(Sys.info()[["nodename"]]),
    started_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
    empirical_outcomes_used = FALSE
  )
  saveRDS(metadata, file.path(staging, "run-metadata.rds"), version = 3)
  .goal003_task4_write_csv(
    .goal005_task2_source_hashes(root),
    file.path(staging, "source-hashes.csv")
  )
  .goal003_task4_write_csv(
    .goal003_task4_package_versions(),
    file.path(staging, "package-versions.csv")
  )
  writeLines(
    c("status=INITIALISED", "empirical_outcomes_used=false"),
    file.path(staging, "initialisation-status.txt")
  )
  if (!file.rename(staging, output_dir)) {
    .goal005_stop("Could not publish Goal005 Task 2 initialisation.")
  }
  .goal005_task2_validate_manifest_copies(output_dir, manifest)
  invisible(output_dir)
}

#' Run or resume the frozen Goal005 Task 2 information-ceiling screen
run_goal005_task2_information_ceiling <- function(
  output_dir = file.path(
    "outputs", "goal005", "task2-information-ceiling-v1"
  ),
  max_workers = 8L,
  refresh = 100L
) {
  valid_integer <- function(value, lower, upper) {
    is.numeric(value) && !is.logical(value) && length(value) == 1L &&
      !is.na(value) && is.finite(value) && value == trunc(value) &&
      value >= lower && value <= upper
  }
  if (!valid_integer(max_workers, 1L, 8L) ||
      !valid_integer(refresh, 0L, .Machine$integer.max) ||
      .Platform$OS.type != "unix") {
    .goal005_stop("Goal005 Task 2 requires one to eight Unix workers.")
  }
  max_workers <- as.integer(max_workers)
  refresh <- as.integer(refresh)
  root <- .goal003_project_root()
  git_commit <- .goal003_task4_git_state(root)
  manifest <- read_goal005_task2_manifests()
  output_dir <- .goal005_task2_output_path(root, output_dir)
  .goal005_task2_initialise_run(
    output_dir,
    manifest,
    git_commit,
    max_workers
  )
  cat("goal005_task2_git_commit=", git_commit, "\n", sep = "")
  cat("goal005_task2_output_dir=", output_dir, "\n", sep = "")
  dir.create(file.path(output_dir, "datasets"), showWarnings = FALSE)
  dir.create(file.path(output_dir, "fits"), showWarnings = FALSE)
  state <- audit_goal003_task4_run_rows(output_dir, manifest)
  if (any(state$datasets$state == "interrupted") ||
      any(state$fits$state == "interrupted")) {
    .goal005_stop("Interrupted Goal005 row staging requires diagnosis.")
  }
  pending_datasets <- dplyr::filter(state$datasets, state == "pending")
  cat("goal005_task2_pending_datasets=", nrow(pending_datasets), "\n", sep = "")
  for (index in seq_len(nrow(pending_datasets))) {
    row <- pending_datasets[index, .goal005_task2_dataset_fields]
    publish_goal003_task4_artifact(
      file.path(output_dir, "datasets"),
      row$dataset_id,
      function(staging) {
        .goal005_task2_write_dataset(row, manifest, staging)
      }
    )
    if (index %% 20L == 0L || index == nrow(pending_datasets)) {
      cat(
        "goal005_task2_datasets_completed_this_run=",
        index, "/", nrow(pending_datasets), "\n", sep = ""
      )
    }
  }
  state <- audit_goal003_task4_run_rows(output_dir, manifest)
  pending_fits <- dplyr::filter(state$fits, state == "pending")
  cat("goal005_task2_pending_fits=", nrow(pending_fits), "\n", sep = "")
  if (nrow(pending_fits) > 0L) {
    compile_goal004_flexirich_model()
    compile_goal005_candidate_oracle_model()
    results <- parallel::mclapply(
      seq_len(nrow(pending_fits)),
      function(index) {
        row <- pending_fits[index, .goal005_task2_fit_fields]
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
            .goal005_task2_write_fit(row, simulation, staging, refresh)
          }
        )
        cat("goal005_task2_fit_complete=", row$fit_id, "\n", sep = "")
        row$fit_id
      },
      mc.cores = max_workers,
      mc.preschedule = FALSE
    )
    failed <- vapply(results, inherits, logical(1), what = "try-error")
    if (any(failed)) {
      .goal005_stop(
        "One or more Goal005 Task 2 workers failed; staging is preserved."
      )
    }
  }
  final_state <- audit_goal003_task4_run_rows(output_dir, manifest)
  if (any(final_state$datasets$state != "complete") ||
      any(final_state$fits$state != "complete")) {
    .goal005_stop("Goal005 Task 2 rows are not all complete.")
  }
  result_state <- goal003_task4_artifact_state(output_dir, "results")
  if (identical(result_state, "interrupted")) {
    .goal005_stop("Interrupted Goal005 result staging requires diagnosis.")
  }
  if (identical(result_state, "pending")) {
    publish_goal003_task4_artifact(
      output_dir,
      "results",
      function(staging) {
        .goal005_task2_write_results(
          .goal005_task2_aggregate(output_dir, manifest),
          staging
        )
      }
    )
  }
  writeLines(
    c(
      "status=TASK2_COMPLETE",
      paste0("git_commit=", git_commit),
      "datasets=180",
      "fits=360",
      "empirical_outcomes_used=false"
    ),
    file.path(output_dir, "completion-status.txt")
  )
  cat("goal005_task2_status=TASK2_COMPLETE\n")
  invisible(list(status = "TASK2_COMPLETE", output_dir = output_dir))
}
