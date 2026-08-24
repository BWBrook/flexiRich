.goal006_task2_output_path <- function(root, output_dir) {
  boundary <- normalizePath(file.path(root, "outputs", "goal006"), mustWork = FALSE)
  output <- normalizePath(
    if (startsWith(output_dir, "/")) output_dir else file.path(root, output_dir),
    mustWork = FALSE
  )
  if (!startsWith(output, paste0(boundary, .Platform$file.sep))) {
    .goal006_stop("output_dir must be beneath outputs/goal006.")
  }
  output
}

.goal006_task2_source_hashes <- function(root) {
  files <- c(
    sort(list.files(file.path(root, "R"), pattern = "[.]R$", full.names = TRUE)),
    sort(list.files(file.path(root, "stan"), pattern = "[.]stan$", full.names = TRUE)),
    file.path(root, "scripts", "run_goal006_task2_recovery.R"),
    file.path(root, "scripts", "audit_goal006_task2_results.R"),
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

.goal006_task2_manifest_paths <- function(output_dir) {
  file.path(
    output_dir,
    "manifests",
    c(
      "synthetic-manifest.csv", "primary-calibration-profile.csv",
      "candidate-classes.csv", "calibration-effort.csv",
      "task2-gates.csv"
    )
  )
}

.goal006_task2_write_manifests <- function(staging, contract) {
  directory <- file.path(staging, "manifests")
  dir.create(directory)
  primary <- contract$calibration_fits[1, ]
  effort <- contract$effort |>
    dplyr::filter(occasion_index <= 52L)
  tables <- list(
    "synthetic-manifest.csv" = contract$synthetic,
    "primary-calibration-profile.csv" = primary,
    "candidate-classes.csv" = contract$candidates,
    "calibration-effort.csv" = effort,
    "task2-gates.csv" = dplyr::filter(contract$gates, stage == "task2")
  )
  for (name in names(tables)) {
    .goal003_task4_write_csv(tables[[name]], file.path(directory, name))
  }
  paths <- .goal006_task2_manifest_paths(staging)
  if (any(!file.exists(paths))) {
    .goal006_stop("Goal006 Task 2 manifest publication is incomplete.")
  }
  stats::setNames(vapply(paths, function(path) {
    digest::digest(file = path, algo = "sha256", serialize = FALSE)
  }, character(1)), basename(paths))
}

.goal006_task2_validate_manifests <- function(output_dir, metadata) {
  paths <- .goal006_task2_manifest_paths(output_dir)
  observed <- if (all(file.exists(paths))) {
    stats::setNames(vapply(paths, function(path) {
      digest::digest(file = path, algo = "sha256", serialize = FALSE)
    }, character(1)), basename(paths))
  } else {
    character()
  }
  if (!identical(observed, metadata$manifest_hashes)) {
    .goal006_stop("Frozen Goal006 Task 2 manifests changed.")
  }
  invisible(TRUE)
}

.goal006_task2_initialise <- function(
  output_dir,
  contract,
  git_commit,
  max_workers
) {
  if (dir.exists(output_dir) || file.exists(output_dir)) {
    path <- file.path(output_dir, "run-metadata.rds")
    if (!file.exists(path)) {
      .goal006_stop("Existing Goal006 Task 2 output lacks run metadata.")
    }
    metadata <- readRDS(path)
    valid <- identical(metadata$git_commit, git_commit) &&
      identical(metadata$contract_hashes, contract$hashes) &&
      identical(metadata$max_workers, as.integer(max_workers))
    if (!valid) {
      .goal006_stop("Existing Goal006 Task 2 output differs from this run.")
    }
    .goal006_task2_validate_manifests(output_dir, metadata)
    if (file.exists(file.path(output_dir, "completion-status.txt"))) {
      .goal006_stop("The frozen Goal006 Task 2 run is complete.")
    }
    return(invisible(output_dir))
  }
  parent <- dirname(output_dir)
  staging <- file.path(parent, paste0(".initialising-", basename(output_dir)))
  if (dir.exists(staging) || file.exists(staging)) {
    .goal006_stop("Interrupted Goal006 Task 2 initialisation exists.")
  }
  dir.create(staging, recursive = TRUE, showWarnings = FALSE)
  manifest_hashes <- .goal006_task2_write_manifests(staging, contract)
  metadata <- list(
    git_commit = git_commit,
    contract_hashes = contract$hashes,
    manifest_hashes = manifest_hashes,
    max_workers = as.integer(max_workers),
    simulation_seed_rule = "610000000 + 100 * profile_code + replicate",
    fit_seed_rule = "620000000 + 100 * profile_code + replicate",
    quadrature_order = 64L,
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
    .goal006_task2_source_hashes(.goal003_project_root()),
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
    .goal006_stop("Could not publish Goal006 Task 2 initialisation.")
  }
  .goal006_task2_validate_manifests(output_dir, metadata)
  invisible(output_dir)
}

.goal006_task2_fit_state <- function(output_dir, simulation_id) {
  goal003_task4_artifact_state(file.path(output_dir, "fits"), simulation_id)
}

.goal006_task2_write_fit <- function(row, contract, staging, refresh) {
  simulation <- simulate_goal006_calibration_dataset(row, contract)
  prepared <- prepare_goal006_calibration_data(
    simulation$source_data,
    simulation$encounter_class,
    contract$calibration_fits[1, ],
    quadrature_order = 64L
  )
  if (any(c("truth", "member", "omega", "q_member") %in%
      names(prepared$stan_data))) {
    .goal006_stop("Synthetic truth entered the Goal006 calibration fit.")
  }
  fit <- fit_goal006_calibration(
    prepared,
    seed = row$fit_seed[[1L]],
    output_dir = file.path(staging, "sampler"),
    refresh = refresh
  )
  compact <- summarise_goal006_calibration_recovery(row, simulation, fit)
  saveRDS(simulation, file.path(staging, "simulation.rds"), version = 3)
  .goal003_task4_write_csv(compact$status, file.path(staging, "fit-status.csv"))
  .goal003_task4_write_csv(compact$recovery, file.path(staging, "recovery.csv"))
  .goal003_task4_write_fit_summary(fit, staging)
  .goal004_task4_compress_sampler_csv(staging)
  if (nrow(utils::read.csv(file.path(staging, "fit-status.csv"))) != 1L ||
      nrow(utils::read.csv(file.path(staging, "recovery.csv"))) != 2L) {
    .goal006_stop("Goal006 Task 2 compact fit evidence failed readback.")
  }
  writeLines(
    c(
      "status=COMPLETE",
      paste0("simulation_id=", row$simulation_id),
      paste0("terminal_status=", fit$terminal_status),
      paste0("simulation_seed=", row$simulation_seed),
      paste0("fit_seed=", row$fit_seed),
      "empirical_outcomes_used=false"
    ),
    file.path(staging, "completion-status.txt")
  )
}

.goal006_task2_read_rows <- function(paths) {
  dplyr::bind_rows(lapply(paths, function(path) {
    tibble::as_tibble(utils::read.csv(
      path,
      stringsAsFactors = FALSE,
      check.names = FALSE,
      na.strings = c("", "NA")
    ))
  }))
}

.goal006_task2_aggregate <- function(output_dir, contract) {
  directories <- file.path(output_dir, "fits", contract$synthetic$simulation_id)
  status <- .goal006_task2_read_rows(file.path(directories, "fit-status.csv"))
  recovery <- .goal006_task2_read_rows(file.path(directories, "recovery.csv"))
  status$terminal_clean <- as.logical(status$terminal_clean)
  recovery$terminal_clean <- as.logical(recovery$terminal_clean)
  recovery$covered_90 <- as.logical(recovery$covered_90)
  bridge <- goal006_likelihood_bridge_metrics()
  evaluation <- evaluate_goal006_task2_gates(
    contract$synthetic,
    status,
    recovery,
    bridge
  )
  list(
    fit_status = status,
    recovery = recovery,
    bridge = bridge,
    evaluation = evaluation
  )
}

.goal006_task2_write_results <- function(result, staging) {
  tables <- list(
    "fit-status.csv" = result$fit_status,
    "recovery.csv" = result$recovery,
    "likelihood-bridge.csv" = result$bridge,
    "decision-gates.csv" = result$evaluation$gates,
    "clean-by-profile.csv" = result$evaluation$clean_by_profile,
    "bias-by-profile.csv" = result$evaluation$bias_by_profile,
    "rmse-by-class.csv" = result$evaluation$rmse_by_class,
    "coverage-by-class.csv" = result$evaluation$coverage_by_class,
    "coverage-by-profile.csv" = result$evaluation$coverage_by_profile,
    "catastrophic-cases.csv" = result$evaluation$catastrophic
  )
  for (name in names(tables)) {
    .goal003_task4_write_csv(tables[[name]], file.path(staging, name))
  }
  writeLines(
    c(
      paste0("status=", result$evaluation$decision),
      "datasets=30",
      "fits=30",
      paste0("gates_passed=", sum(result$evaluation$gates$passed)),
      "gates_total=12",
      "empirical_outcomes_used=false"
    ),
    file.path(staging, "completion-status.txt")
  )
}

#' Run or resume the frozen Goal006 Task 2 recovery batch
run_goal006_task2_recovery <- function(
  output_dir = file.path("outputs", "goal006", "task2-recovery-v1"),
  max_workers = 6L,
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
    .goal006_stop("Goal006 Task 2 requires one to eight Unix workers.")
  }
  root <- .goal003_project_root()
  git_commit <- .goal003_task4_git_state(root)
  contract <- read_goal006_task1_contract(verify_external = FALSE)
  output_dir <- .goal006_task2_output_path(root, output_dir)
  .goal006_task2_initialise(
    output_dir,
    contract,
    git_commit,
    as.integer(max_workers)
  )
  cat("goal006_task2_git_commit=", git_commit, "\n", sep = "")
  cat("goal006_task2_output_dir=", output_dir, "\n", sep = "")
  dir.create(file.path(output_dir, "fits"), showWarnings = FALSE)
  states <- vapply(contract$synthetic$simulation_id, function(id) {
    .goal006_task2_fit_state(output_dir, id)
  }, character(1))
  if (any(states == "interrupted")) {
    .goal006_stop("Interrupted Goal006 Task 2 staging requires diagnosis.")
  }
  pending <- contract$synthetic[states == "pending", ]
  cat("goal006_task2_pending_fits=", nrow(pending), "\n", sep = "")
  if (nrow(pending) > 0L) {
    compile_goal006_calibration_model()
    result <- parallel::mclapply(
      seq_len(nrow(pending)),
      function(index) {
        row <- pending[index, ]
        publish_goal003_task4_artifact(
          file.path(output_dir, "fits"),
          row$simulation_id,
          function(staging) {
            .goal006_task2_write_fit(row, contract, staging, refresh)
          }
        )
        cat("goal006_task2_fit_complete=", row$simulation_id, "\n", sep = "")
        row$simulation_id
      },
      mc.cores = as.integer(max_workers),
      mc.preschedule = FALSE
    )
    failed <- vapply(result, inherits, logical(1), what = "try-error")
    if (any(failed)) {
      .goal006_stop("One or more Goal006 Task 2 workers failed.")
    }
  }
  final_states <- vapply(contract$synthetic$simulation_id, function(id) {
    .goal006_task2_fit_state(output_dir, id)
  }, character(1))
  if (any(final_states != "complete")) {
    .goal006_stop("Goal006 Task 2 fit rows are incomplete.")
  }
  result_state <- goal003_task4_artifact_state(output_dir, "results")
  if (result_state == "interrupted") {
    .goal006_stop("Interrupted Goal006 Task 2 results require diagnosis.")
  }
  if (result_state == "pending") {
    publish_goal003_task4_artifact(output_dir, "results", function(staging) {
      .goal006_task2_write_results(
        .goal006_task2_aggregate(output_dir, contract),
        staging
      )
    })
  }
  decision <- sub(
    "^status=",
    "",
    readLines(file.path(output_dir, "results", "completion-status.txt"))[1L]
  )
  writeLines(
    c(
      paste0("status=", decision),
      paste0("git_commit=", git_commit),
      "datasets=30",
      "fits=30",
      "empirical_outcomes_used=false"
    ),
    file.path(output_dir, "completion-status.txt")
  )
  cat("goal006_task2_status=", decision, "\n", sep = "")
  invisible(list(status = decision, output_dir = output_dir))
}

#' Replay one completed Goal006 Task 2 compact archive
audit_goal006_task2_results <- function(output_dir, expected_commit = NULL) {
  output_dir <- normalizePath(output_dir, mustWork = TRUE)
  metadata <- readRDS(file.path(output_dir, "run-metadata.rds"))
  if (is.null(expected_commit)) {
    expected_commit <- metadata$git_commit
  }
  root_status <- readLines(file.path(output_dir, "completion-status.txt"))
  result_dir <- file.path(output_dir, "results")
  recorded_status <- readLines(file.path(result_dir, "completion-status.txt"))
  valid <- identical(metadata$git_commit, expected_commit) &&
    identical(metadata$empirical_outcomes_used, FALSE) &&
    "empirical_outcomes_used=false" %in% root_status &&
    "empirical_outcomes_used=false" %in% recorded_status &&
    !file.exists(file.path(output_dir, "execution-stop.txt"))
  if (!valid) {
    .goal006_stop("Goal006 Task 2 run metadata are invalid.")
  }
  contract <- read_goal006_task1_contract(verify_external = FALSE)
  status <- .goal006_task2_read_rows(file.path(result_dir, "fit-status.csv"))
  recovery <- .goal006_task2_read_rows(file.path(result_dir, "recovery.csv"))
  status$terminal_clean <- as.logical(status$terminal_clean)
  recovery$terminal_clean <- as.logical(recovery$terminal_clean)
  recovery$covered_90 <- as.logical(recovery$covered_90)
  bridge <- goal006_likelihood_bridge_metrics()
  replay <- evaluate_goal006_task2_gates(
    contract$synthetic,
    status,
    recovery,
    bridge
  )
  recorded <- .goal006_task2_read_rows(file.path(result_dir, "decision-gates.csv"))
  recorded$passed <- as.logical(recorded$passed)
  compare_fields <- c(
    "gate_id", "metric", "value", "threshold", "comparison",
    "numerator", "denominator", "passed"
  )
  matches <- isTRUE(all.equal(
    recorded[compare_fields],
    replay$gates[compare_fields],
    tolerance = 1e-12,
    check.attributes = FALSE
  ))
  if (!matches) {
    .goal006_stop("Goal006 Task 2 independent replay disagrees.")
  }
  files <- sort(list.files(result_dir, full.names = TRUE))
  list(
    decision = replay$decision,
    gates = replay$gates,
    artifact_hashes = tibble::tibble(
      path = basename(files),
      sha256 = vapply(files, function(path) {
        digest::digest(file = path, algo = "sha256", serialize = FALSE)
      }, character(1))
    ),
    run_commit = metadata$git_commit
  )
}
