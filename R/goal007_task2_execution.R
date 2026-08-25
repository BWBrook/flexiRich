.goal007_task2_output_path <- function(root, output_dir) {
  boundary <- normalizePath(file.path(root, "outputs", "goal007"), mustWork = FALSE)
  output <- normalizePath(
    if (startsWith(output_dir, "/")) output_dir else file.path(root, output_dir),
    mustWork = FALSE
  )
  if (!startsWith(output, paste0(boundary, .Platform$file.sep))) {
    .goal007_stop("output_dir must be beneath outputs/goal007.")
  }
  output
}

.goal007_task2_source_hashes <- function(root) {
  files <- c(
    sort(list.files(file.path(root, "R"), pattern = "[.]R$", full.names = TRUE)),
    sort(list.files(file.path(root, "stan"), pattern = "[.]stan$", full.names = TRUE)),
    file.path(root, "scripts", "run_goal007_task2_screen.R"),
    file.path(root, "scripts", "run_goal007_task2_execution_smoke.R"),
    file.path(root, "scripts", "audit_goal007_task2_results.R"),
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

.goal007_task2_manifest_paths <- function(output_dir) {
  file.path(
    output_dir,
    "manifests",
    c(
      "models.csv", "profiles.csv", "datasets.csv", "fits.csv",
      "candidate-classes.csv", "calibration-effort.csv", "gates.csv"
    )
  )
}

.goal007_task2_write_manifests <- function(staging, contract) {
  directory <- file.path(staging, "manifests")
  dir.create(directory)
  tables <- list(
    "models.csv" = contract$models,
    "profiles.csv" = contract$profiles,
    "datasets.csv" = contract$task2_datasets,
    "fits.csv" = contract$task2_fits,
    "candidate-classes.csv" = contract$candidates,
    "calibration-effort.csv" = contract$effort |>
      dplyr::filter(occasion_index <= 52L),
    "gates.csv" = contract$gates |>
      dplyr::filter(stage == "task2")
  )
  for (name in names(tables)) {
    .goal003_task4_write_csv(tables[[name]], file.path(directory, name))
  }
  paths <- .goal007_task2_manifest_paths(staging)
  if (any(!file.exists(paths))) {
    .goal007_stop("Goal007 Task 2 manifest publication is incomplete.")
  }
  stats::setNames(vapply(paths, function(path) {
    digest::digest(file = path, algo = "sha256", serialize = FALSE)
  }, character(1)), basename(paths))
}

.goal007_task2_validate_manifests <- function(output_dir, metadata) {
  paths <- .goal007_task2_manifest_paths(output_dir)
  observed <- if (all(file.exists(paths))) {
    stats::setNames(vapply(paths, function(path) {
      digest::digest(file = path, algo = "sha256", serialize = FALSE)
    }, character(1)), basename(paths))
  } else {
    character()
  }
  if (!identical(observed, metadata$manifest_hashes)) {
    .goal007_stop("Frozen Goal007 Task 2 manifests changed.")
  }
  invisible(TRUE)
}

.goal007_task2_initialise <- function(
  output_dir,
  contract,
  git_commit,
  max_workers
) {
  if (dir.exists(output_dir) || file.exists(output_dir)) {
    metadata_path <- file.path(output_dir, "run-metadata.rds")
    if (!file.exists(metadata_path)) {
      .goal007_stop("Existing Goal007 Task 2 output lacks run metadata.")
    }
    metadata <- readRDS(metadata_path)
    valid <- identical(metadata$git_commit, git_commit) &&
      identical(metadata$contract_hashes, contract$hashes) &&
      identical(metadata$max_workers, as.integer(max_workers))
    if (!valid) {
      .goal007_stop("Existing Goal007 Task 2 output differs from this run.")
    }
    .goal007_task2_validate_manifests(output_dir, metadata)
    if (file.exists(file.path(output_dir, "completion-status.txt"))) {
      .goal007_stop("The frozen Goal007 Task 2 run is complete.")
    }
    return(invisible(output_dir))
  }
  parent <- dirname(output_dir)
  staging <- file.path(parent, paste0(".initialising-", basename(output_dir)))
  if (dir.exists(staging) || file.exists(staging)) {
    .goal007_stop("Interrupted Goal007 Task 2 initialisation exists.")
  }
  dir.create(staging, recursive = TRUE, showWarnings = FALSE)
  manifest_hashes <- .goal007_task2_write_manifests(staging, contract)
  metadata <- list(
    git_commit = git_commit,
    contract_hashes = contract$hashes,
    manifest_hashes = manifest_hashes,
    max_workers = as.integer(max_workers),
    simulation_seed_rule = "710000000 + 100 * profile_code + replicate",
    fit_seed_rule = paste0(
      "720000000 + 1000000 * model_code + 100 * profile_code + replicate"
    ),
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
    .goal007_task2_source_hashes(.goal003_project_root()),
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
    .goal007_stop("Could not publish Goal007 Task 2 initialisation.")
  }
  .goal007_task2_validate_manifests(output_dir, metadata)
  invisible(output_dir)
}

.goal007_task2_fit_state <- function(output_dir, fit_id) {
  goal003_task4_artifact_state(file.path(output_dir, "fits"), fit_id)
}

.goal007_task2_fit_rows <- function(contract, fit_row) {
  dataset <- contract$task2_datasets |>
    dplyr::filter(dataset_id == fit_row$dataset_id)
  if (nrow(dataset) != 1L) {
    .goal007_stop("Goal007 Task 2 fit does not resolve to one dataset.")
  }
  list(dataset = dataset, fit = fit_row)
}

.goal007_task2_write_fit <- function(fit_row, contract, staging, refresh) {
  rows <- .goal007_task2_fit_rows(contract, fit_row)
  simulation <- simulate_goal007_task2_dataset(rows$dataset, contract)
  fit <- .goal007_fit_task2_row(
    rows$fit,
    simulation,
    file.path(staging, "sampler"),
    refresh
  )
  compact <- summarise_goal007_task2_fit(
    rows$fit,
    rows$dataset,
    simulation,
    fit
  )
  .goal003_task4_write_csv(compact$status, file.path(staging, "fit-status.csv"))
  .goal003_task4_write_csv(compact$recovery, file.path(staging, "recovery.csv"))
  .goal003_task4_write_fit_summary(fit, staging)
  .goal004_task4_compress_sampler_csv(staging)
  status_check <- utils::read.csv(file.path(staging, "fit-status.csv"))
  recovery_check <- utils::read.csv(file.path(staging, "recovery.csv"))
  if (nrow(status_check) != 1L || nrow(recovery_check) != 2L) {
    .goal007_stop("Goal007 Task 2 compact fit evidence failed readback.")
  }
  writeLines(
    c(
      "status=COMPLETE",
      paste0("fit_id=", fit_row$fit_id),
      paste0("model_id=", fit_row$model_id),
      paste0("terminal_status=", fit$terminal_status),
      paste0("simulation_seed=", rows$dataset$simulation_seed),
      paste0("fit_seed=", fit_row$fit_seed),
      "empirical_outcomes_used=false"
    ),
    file.path(staging, "completion-status.txt")
  )
}

.goal007_task2_read_rows <- function(paths) {
  dplyr::bind_rows(lapply(paths, function(path) {
    tibble::as_tibble(utils::read.csv(
      path,
      stringsAsFactors = FALSE,
      check.names = FALSE,
      na.strings = c("", "NA")
    ))
  }))
}

.goal007_task2_aggregate <- function(output_dir, contract) {
  directories <- file.path(output_dir, "fits", contract$task2_fits$fit_id)
  status <- .goal007_task2_read_rows(file.path(directories, "fit-status.csv"))
  recovery <- .goal007_task2_read_rows(file.path(directories, "recovery.csv"))
  status$terminal_clean <- as.logical(status$terminal_clean)
  status$artifact_pass <- as.logical(status$artifact_pass)
  recovery$terminal_clean <- as.logical(recovery$terminal_clean)
  recovery$generator_covered_90 <- as.logical(recovery$generator_covered_90)
  prior_bridge <- goal007_prior_bridge_metrics()
  likelihood_bridge <- goal006_likelihood_bridge_metrics()
  evaluation <- evaluate_goal007_task2_gates(
    contract,
    status,
    recovery,
    prior_bridge,
    likelihood_bridge
  )
  list(
    fit_status = status,
    recovery = recovery,
    prior_bridge = prior_bridge,
    likelihood_bridge = likelihood_bridge,
    evaluation = evaluation
  )
}

.goal007_task2_write_results <- function(result, staging) {
  catastrophic <- dplyr::bind_rows(lapply(
    names(result$evaluation$candidate_metrics),
    function(model_id) {
      result$evaluation$candidate_metrics[[model_id]]$catastrophic |>
        dplyr::mutate(model_id = model_id, .before = 1L)
    }
  ))
  tables <- list(
    "fit-status.csv" = result$fit_status,
    "recovery.csv" = result$recovery,
    "prior-bridge.csv" = result$prior_bridge,
    "likelihood-bridge.csv" = result$likelihood_bridge,
    "decision-gates.csv" = result$evaluation$gates,
    "candidate-eligibility.csv" = result$evaluation$eligibility,
    "catastrophic-cases.csv" = catastrophic
  )
  for (name in names(tables)) {
    .goal003_task4_write_csv(tables[[name]], file.path(staging, name))
  }
  selected <- result$evaluation$selected_model_id
  writeLines(
    c(
      paste0("status=", result$evaluation$decision),
      paste0("selected_model_id=", ifelse(is.na(selected), "none", selected)),
      "datasets=60",
      "fits=180",
      "empirical_outcomes_used=false"
    ),
    file.path(staging, "completion-status.txt")
  )
}

#' Run or resume the frozen Goal007 Task 2 screen
run_goal007_task2_screen <- function(
  output_dir = file.path("outputs", "goal007", "task2-screen-v1"),
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
    .goal007_stop("Goal007 Task 2 requires one to eight Unix workers.")
  }
  root <- .goal003_project_root()
  git_commit <- .goal003_task4_git_state(root)
  contract <- read_goal007_task1_contract(verify_external = FALSE)
  output_dir <- .goal007_task2_output_path(root, output_dir)
  .goal007_task2_initialise(
    output_dir,
    contract,
    git_commit,
    as.integer(max_workers)
  )
  cat("goal007_task2_git_commit=", git_commit, "\n", sep = "")
  cat("goal007_task2_output_dir=", output_dir, "\n", sep = "")
  dir.create(file.path(output_dir, "fits"), showWarnings = FALSE)
  states <- vapply(contract$task2_fits$fit_id, function(id) {
    .goal007_task2_fit_state(output_dir, id)
  }, character(1))
  if (any(states == "interrupted")) {
    .goal007_stop("Interrupted Goal007 Task 2 fit staging requires diagnosis.")
  }
  pending <- contract$task2_fits[states == "pending", ]
  cat("goal007_task2_pending_fits=", nrow(pending), "\n", sep = "")
  if (nrow(pending) > 0L) {
    compile_goal006_calibration_model()
    compile_goal007_calibration_model()
    result <- parallel::mclapply(
      seq_len(nrow(pending)),
      function(index) {
        row <- pending[index, ]
        publish_goal003_task4_artifact(
          file.path(output_dir, "fits"),
          row$fit_id,
          function(staging) {
            .goal007_task2_write_fit(row, contract, staging, refresh)
          }
        )
        cat("goal007_task2_fit_complete=", row$fit_id, "\n", sep = "")
        row$fit_id
      },
      mc.cores = as.integer(max_workers),
      mc.preschedule = FALSE
    )
    failed <- vapply(result, inherits, logical(1), what = "try-error")
    if (any(failed)) {
      .goal007_stop("One or more Goal007 Task 2 workers failed.")
    }
  }
  final_states <- vapply(contract$task2_fits$fit_id, function(id) {
    .goal007_task2_fit_state(output_dir, id)
  }, character(1))
  if (any(final_states != "complete")) {
    .goal007_stop("Goal007 Task 2 fit rows are incomplete.")
  }
  result_state <- goal003_task4_artifact_state(output_dir, "results")
  if (result_state == "interrupted") {
    .goal007_stop("Interrupted Goal007 Task 2 result staging requires diagnosis.")
  }
  if (result_state == "pending") {
    publish_goal003_task4_artifact(output_dir, "results", function(staging) {
      .goal007_task2_write_results(
        .goal007_task2_aggregate(output_dir, contract),
        staging
      )
    })
  }
  lines <- readLines(
    file.path(output_dir, "results", "completion-status.txt"),
    warn = FALSE
  )
  decision <- sub("^status=", "", lines[grepl("^status=", lines)])
  selected <- sub(
    "^selected_model_id=", "", lines[grepl("^selected_model_id=", lines)]
  )
  writeLines(
    c(
      paste0("status=", decision),
      paste0("selected_model_id=", selected),
      paste0("git_commit=", git_commit),
      "datasets=60",
      "fits=180",
      "empirical_outcomes_used=false"
    ),
    file.path(output_dir, "completion-status.txt")
  )
  cat("goal007_task2_status=", decision, "\n", sep = "")
  cat("goal007_task2_selected_model_id=", selected, "\n", sep = "")
  invisible(list(
    status = decision,
    selected_model_id = selected,
    output_dir = output_dir
  ))
}
