.goal004_task4_output_path <- function(root, output_dir) {
  boundary <- normalizePath(
    file.path(root, "outputs", "goal004"),
    mustWork = FALSE
  )
  output <- normalizePath(
    if (startsWith(output_dir, "/")) output_dir else file.path(root, output_dir),
    mustWork = FALSE
  )
  if (!startsWith(output, paste0(boundary, .Platform$file.sep))) {
    .goal004_task4_stop("output_dir must be beneath outputs/goal004.")
  }
  output
}

.goal004_task4_source_hashes <- function(root) {
  files <- c(
    sort(list.files(file.path(root, "R"), pattern = "[.]R$", full.names = TRUE)),
    sort(list.files(file.path(root, "stan"), pattern = "[.]stan$", full.names = TRUE)),
    file.path(root, "scripts", "run_goal004_task4_development.R"),
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

.goal004_task4_validate_manifest_copies <- function(output_dir, manifest) {
  paths <- .goal004_task4_paths(.goal003_project_root())
  copied <- file.path(output_dir, "manifests", basename(paths))
  if (any(!file.exists(copied))) {
    .goal004_task4_stop("Goal004 Task 4 is missing a frozen manifest copy.")
  }
  observed <- vapply(copied, function(path) {
    digest::digest(file = path, algo = "sha256", serialize = FALSE)
  }, character(1))
  names(observed) <- names(manifest$hashes)
  if (!identical(observed, manifest$hashes)) {
    .goal004_task4_stop("Goal004 Task 4 manifest copies changed.")
  }
  invisible(TRUE)
}

.goal004_task4_initialise_run <- function(
  output_dir,
  manifest,
  git_commit,
  max_workers
) {
  root <- .goal003_project_root()
  if (dir.exists(output_dir) || file.exists(output_dir)) {
    metadata_path <- file.path(output_dir, "run-metadata.rds")
    if (!file.exists(metadata_path)) {
      .goal004_task4_stop(
        "Existing Goal004 Task 4 output lacks run metadata."
      )
    }
    metadata <- readRDS(metadata_path)
    valid <- identical(metadata$git_commit, git_commit) &&
      identical(metadata$manifest_hashes, manifest$hashes) &&
      identical(metadata$max_workers, as.integer(max_workers))
    if (!valid) {
      .goal004_task4_stop(
        "Existing Goal004 Task 4 output differs from this frozen run."
      )
    }
    .goal004_task4_validate_manifest_copies(output_dir, manifest)
    if (file.exists(file.path(output_dir, "completion-status.txt"))) {
      .goal004_task4_stop("The frozen Goal004 Task 4 run is complete.")
    }
    return(invisible(output_dir))
  }

  parent <- dirname(output_dir)
  staging <- file.path(parent, paste0(".initialising-", basename(output_dir)))
  if (dir.exists(staging) || file.exists(staging)) {
    .goal004_task4_stop("Interrupted Goal004 Task 4 initialisation exists.")
  }
  dir.create(staging, recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(staging, "manifests"))
  manifest_paths <- .goal004_task4_paths(root)
  copied <- file.copy(
    manifest_paths,
    file.path(staging, "manifests", basename(manifest_paths)),
    overwrite = FALSE
  )
  if (!all(copied)) {
    .goal004_task4_stop("Could not copy Goal004 Task 4 manifests.")
  }
  metadata <- list(
    git_commit = git_commit,
    manifest_hashes = manifest$hashes,
    max_workers = as.integer(max_workers),
    simulation_seed_rule = "440000000 + 100 * train_occasions + replicate",
    fit_seed_rule = paste0(
      "540000000 + 1000000 * profile_code + 10000 * scenario_order + ",
      "100 * train_occasions + replicate"
    ),
    prior_seed = 40042L,
    prior_draws = 50000L,
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
    .goal004_task4_source_hashes(root),
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
    .goal004_task4_stop("Could not publish Goal004 Task 4 initialisation.")
  }
  .goal004_task4_validate_manifest_copies(output_dir, manifest)
  invisible(output_dir)
}

#' Run or resume the frozen Goal004 Task 4 development screen
run_goal004_task4_development <- function(
  output_dir = file.path("outputs", "goal004", "task4-development-v1"),
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
    .goal004_task4_stop(
      "Goal004 Task 4 requires one to eight Unix workers."
    )
  }
  max_workers <- as.integer(max_workers)
  refresh <- as.integer(refresh)
  root <- .goal003_project_root()
  git_commit <- .goal003_task4_git_state(root)
  manifest <- read_goal004_task4_manifests()
  output_dir <- .goal004_task4_output_path(root, output_dir)
  .goal004_task4_initialise_run(
    output_dir,
    manifest,
    git_commit,
    max_workers
  )
  cat("goal004_task4_git_commit=", git_commit, "\n", sep = "")
  cat("goal004_task4_output_dir=", output_dir, "\n", sep = "")

  prior_state <- goal003_task4_artifact_state(output_dir, "prior-forecasts")
  if (identical(prior_state, "interrupted")) {
    .goal004_task4_stop("Interrupted prior-forecast staging requires diagnosis.")
  }
  if (identical(prior_state, "pending")) {
    publish_goal003_task4_artifact(
      output_dir,
      "prior-forecasts",
      function(staging) {
        .goal004_task4_write_prior_forecasts(manifest, staging)
      }
    )
  }
  prior_forecasts <- readRDS(file.path(
    output_dir,
    "prior-forecasts",
    "prior-forecasts.rds"
  ))
  dir.create(file.path(output_dir, "datasets"), showWarnings = FALSE)
  dir.create(file.path(output_dir, "fits"), showWarnings = FALSE)
  state <- audit_goal003_task4_run_rows(output_dir, manifest)
  if (any(state$datasets$state == "interrupted") ||
      any(state$fits$state == "interrupted")) {
    .goal004_task4_stop("Interrupted row staging requires diagnosis.")
  }
  pending_datasets <- dplyr::filter(state$datasets, state == "pending")
  cat("goal004_task4_pending_datasets=", nrow(pending_datasets), "\n", sep = "")
  for (index in seq_len(nrow(pending_datasets))) {
    row <- pending_datasets[index, .goal004_task4_dataset_fields]
    publish_goal003_task4_artifact(
      file.path(output_dir, "datasets"),
      row$dataset_id,
      function(staging) {
        .goal004_task4_write_dataset(
          row,
          manifest,
          prior_forecasts,
          staging
        )
      }
    )
    if (index %% 20L == 0L || index == nrow(pending_datasets)) {
      cat(
        "goal004_task4_datasets_completed_this_run=",
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
  cat("goal004_task4_pending_fits=", nrow(pending_fits), "\n", sep = "")
  if (nrow(pending_fits) > 0L) {
    compile_goal004_flexirich_model()
    compile_goal003_flexirich_model()
    compile_goal003_occupancy_model()
    compile_goal004_nested_model()
    results <- parallel::mclapply(
      seq_len(nrow(pending_fits)),
      function(index) {
        row <- pending_fits[index, .goal004_task4_fit_fields]
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
            .goal004_task4_write_fit(row, simulation, staging, refresh)
          }
        )
        cat("goal004_task4_fit_complete=", row$fit_id, "\n", sep = "")
        row$fit_id
      },
      mc.cores = max_workers,
      mc.preschedule = FALSE
    )
    failed <- vapply(results, inherits, logical(1), what = "try-error")
    if (any(failed)) {
      .goal004_task4_stop(
        "One or more Goal004 Task 4 workers failed; staging is preserved."
      )
    }
  }

  final_state <- audit_goal003_task4_run_rows(output_dir, manifest)
  if (any(final_state$datasets$state != "complete") ||
      any(final_state$fits$state != "complete")) {
    .goal004_task4_stop("Goal004 Task 4 rows are not all complete.")
  }
  results_state <- goal003_task4_artifact_state(output_dir, "results")
  if (identical(results_state, "interrupted")) {
    .goal004_task4_stop("Interrupted result staging requires diagnosis.")
  }
  if (identical(results_state, "pending")) {
    publish_goal003_task4_artifact(
      output_dir,
      "results",
      function(staging) {
        .goal004_task4_write_results(
          .goal004_task4_aggregate(output_dir, manifest),
          staging
        )
      }
    )
  }
  decision <- readLines(
    file.path(output_dir, "results", "completion-status.txt"),
    warn = FALSE
  )
  status <- sub("^status=", "", decision[grepl("^status=", decision)])
  if (length(status) != 1L ||
      !status %in% c("TASK4_PASS", "TASK4_STOP")) {
    .goal004_task4_stop("Goal004 Task 4 result decision is invalid.")
  }
  writeLines(
    c(
      paste0("status=", status),
      paste0("git_commit=", git_commit),
      "datasets=180",
      "fits=750",
      "empirical_outcomes_used=false"
    ),
    file.path(output_dir, "completion-status.txt")
  )
  cat("goal004_task4_status=", status, "\n", sep = "")
  invisible(list(status = status, output_dir = output_dir))
}
