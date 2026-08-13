testthat::test_that("Task 4 artifacts publish once and completion is final", {
  parent <- tempfile("goal003-task4-artifacts-")
  dir.create(parent)
  on.exit(unlink(parent, recursive = TRUE), add = TRUE)

  published <- publish_goal003_task4_artifact(
    parent,
    "row-001",
    function(staging) {
      writeLines("payload", file.path(staging, "payload.txt"))
      writeLines("status=COMPLETE", file.path(staging, "completion-status.txt"))
    }
  )
  testthat::expect_true(dir.exists(published))
  testthat::expect_true(file.exists(file.path(published, "payload.txt")))
  testthat::expect_identical(
    goal003_task4_artifact_state(parent, "row-001"),
    "complete"
  )
  testthat::expect_error(
    publish_goal003_task4_artifact(
      parent,
      "row-001",
      function(staging) NULL
    ),
    "already exists",
    fixed = TRUE
  )
})

testthat::test_that("Task 4 interrupted artifacts are preserved and block rerun", {
  parent <- tempfile("goal003-task4-interrupt-")
  dir.create(parent)
  on.exit(unlink(parent, recursive = TRUE), add = TRUE)

  testthat::expect_error(
    publish_goal003_task4_artifact(
      parent,
      "row-002",
      function(staging) {
        writeLines("partial", file.path(staging, "partial.txt"))
        stop("forced interruption")
      }
    ),
    "forced interruption",
    fixed = TRUE
  )
  testthat::expect_identical(
    goal003_task4_artifact_state(parent, "row-002"),
    "interrupted"
  )
  testthat::expect_true(file.exists(file.path(
    parent,
    ".staging-row-002",
    "partial.txt"
  )))
  testthat::expect_error(
    publish_goal003_task4_artifact(
      parent,
      "row-002",
      function(staging) NULL
    ),
    "interrupted staging",
    fixed = TRUE
  )
})

testthat::test_that("Task 4 run-state audit distinguishes pending rows", {
  manifest <- read_goal003_task4_manifests()
  output <- tempfile("goal003-task4-state-")
  dir.create(file.path(output, "datasets"), recursive = TRUE)
  dir.create(file.path(output, "fits"), recursive = TRUE)
  on.exit(unlink(output, recursive = TRUE), add = TRUE)

  dataset_id <- manifest$datasets$dataset_id[[1L]]
  fit_id <- manifest$fits$fit_id[[1L]]
  publish_goal003_task4_artifact(
    file.path(output, "datasets"),
    dataset_id,
    function(staging) {
      writeLines("status=COMPLETE", file.path(staging, "completion-status.txt"))
    }
  )
  dir.create(file.path(output, "fits", paste0(".staging-", fit_id)))
  state <- audit_goal003_task4_run_rows(output, manifest)

  testthat::expect_equal(sum(state$datasets$state == "complete"), 1L)
  testthat::expect_equal(sum(state$datasets$state == "pending"), 299L)
  testthat::expect_equal(sum(state$fits$state == "interrupted"), 1L)
  testthat::expect_equal(sum(state$fits$state == "pending"), 839L)
})

testthat::test_that("Task 4 expanded truth matches the broader candidate pool", {
  manifest <- read_goal003_task4_manifests()
  row <- manifest$datasets |>
    dplyr::filter(
      scenario_id == "matched_mid",
      train_occasions == 4L,
      replicate == 1L
    )
  simulation <- simulate_goal003_task4_dataset(row, manifest)
  expanded <- expand_goal003_task4_truth(simulation$truth, 106L)

  testthat::expect_equal(nrow(expanded$species), 106L)
  testthat::expect_equal(expanded$true_richness, simulation$truth$true_richness)
  testthat::expect_equal(
    expanded$observed_richness,
    simulation$truth$observed_richness
  )
  added <- expanded$species[51:106, ]
  testthat::expect_false(any(added$member))
  testthat::expect_false(any(added$training_detected))
  testthat::expect_false(any(added$future_first_detection))
})

testthat::test_that("Task 4 aggregate oracle requires every frozen row", {
  manifest <- read_goal003_task4_manifests()
  dataset_status <- manifest$datasets
  fit_status <- manifest$fits
  baseline_point <- tidyr::crossing(
    dataset_id = manifest$datasets$dataset_id,
    method = c(
      "observed", "chao2", "ichao2", "chao2_complete",
      "ichao2_complete", "inext"
    )
  )
  richness <- dplyr::bind_rows(
    tibble::tibble(fit_id = manifest$fits$fit_id),
    tidyr::crossing(
      dataset_id = manifest$datasets$dataset_id,
      method = c(
        "observed", "chao2", "ichao2", "chao2_complete",
        "ichao2_complete", "inext", "lower_prior"
      )
    ) |>
      dplyr::mutate(fit_id = NA_character_)
  )
  discovery <- dplyr::bind_rows(
    tibble::tibble(fit_id = manifest$fits$fit_id),
    tidyr::crossing(
      dataset_id = manifest$datasets$dataset_id,
      method = c("observed", "inext")
    ) |>
      dplyr::mutate(fit_id = NA_character_)
  )

  testthat::expect_true(isTRUE(.goal003_task4_validate_aggregate(
    manifest,
    dataset_status,
    fit_status,
    baseline_point,
    richness,
    discovery
  )))
  testthat::expect_error(
    .goal003_task4_validate_aggregate(
      manifest,
      dataset_status,
      fit_status[-1L, ],
      baseline_point,
      richness,
      discovery
    ),
    "frozen output contract",
    fixed = TRUE
  )
})

testthat::test_that("Task 4 score CSVs retain types across baseline and fit rows", {
  manifest <- read_goal003_task4_manifests()
  row <- manifest$datasets |>
    dplyr::filter(
      scenario_id == "matched_mid",
      train_occasions == 4L,
      replicate == 1L
    )
  simulation <- simulate_goal003_task4_dataset(row, manifest)
  baseline <- evaluate_goal003_task4_baselines(simulation)$richness_scores
  fit <- baseline |>
    dplyr::filter(method == "observed") |>
    dplyr::mutate(
      fit_id = "synthetic-fit",
      method = "flexirich",
      run_role = "primary",
      prior_profile = "primary",
      pool_profile = "primary_50",
      candidate_pool_size = 50L
    )
  directory <- tempfile("goal003-task4-csv-")
  dir.create(directory)
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  baseline_path <- file.path(directory, "baseline.csv")
  fit_path <- file.path(directory, "fit.csv")
  .goal003_task4_write_csv(baseline, baseline_path)
  .goal003_task4_write_csv(fit, fit_path)

  restored <- dplyr::bind_rows(
    .goal003_task4_read_richness_scores(baseline_path),
    .goal003_task4_read_richness_scores(fit_path)
  )
  testthat::expect_type(restored$fit_id, "character")
  testthat::expect_type(restored$rps, "double")
  testthat::expect_type(restored$interval_90_covered, "logical")
  testthat::expect_equal(sum(is.na(restored$fit_id)), nrow(baseline))
  testthat::expect_identical(restored$fit_id[[nrow(restored)]], "synthetic-fit")
})

testthat::test_that("Task 4 dataset writer publishes the complete frozen row", {
  manifest <- read_goal003_task4_manifests()
  row <- manifest$datasets[1L, ]
  parent <- tempfile("goal003-task4-dataset-writer-")
  dir.create(parent)
  on.exit(unlink(parent, recursive = TRUE), add = TRUE)

  published <- publish_goal003_task4_artifact(
    parent,
    row$dataset_id,
    function(staging) {
      .goal003_task4_write_dataset(row, manifest, staging)
    }
  )
  required <- c(
    "simulation.rds", "truth-species.csv", "truth-cameras.csv",
    "baseline-point-predictions.csv", "baseline-richness-scores.csv",
    "baseline-discovery-scores.csv", "dataset-status.csv",
    "completion-status.txt"
  )
  testthat::expect_true(all(file.exists(file.path(published, required))))
  restored <- readRDS(file.path(published, "simulation.rds"))
  testthat::expect_identical(restored$dataset_id, row$dataset_id)
  testthat::expect_false(any(c("truth", "member", "true_richness") %in%
    names(restored$training_data)))
})

testthat::test_that("Task 4 fit writer records non-clean fits without truth leakage", {
  manifest <- read_goal003_task4_manifests()
  fit_row <- manifest$fits |>
    dplyr::filter(
      method == "flexirich",
      run_role == "primary"
    ) |>
    dplyr::slice(1L)
  dataset_row <- manifest$datasets |>
    dplyr::filter(dataset_id == fit_row$dataset_id)
  simulation <- simulate_goal003_task4_dataset(dataset_row, manifest)
  fake_fit <- function(data, seed, output_dir, rescue, refresh) {
    testthat::expect_false(any(c("truth", "member", "true_richness") %in%
      names(data)))
    list(
      terminal_status = "final_nonclean",
      data = data,
      prior = goal003_flexirich_prior_profiles()$primary,
      output_dir = output_dir,
      attempts = list(primary = list(
        attempt_id = "primary",
        profile = goal003_flexirich_sampler_profiles()$primary,
        elapsed_seconds = 1,
        diagnostics = list(
          clean = FALSE,
          metrics = NULL,
          reasons = "synthetic non-clean hand case"
        ),
        fit = NULL
      ))
    )
  }
  rlang::local_bindings(
    fit_goal003_flexirich = fake_fit,
    .env = globalenv()
  )
  staging <- tempfile("goal003-task4-fit-writer-")
  dir.create(staging)
  on.exit(unlink(staging, recursive = TRUE), add = TRUE)

  .goal003_task4_write_fit(
    fit_row,
    simulation,
    staging,
    refresh = 0L
  )
  status <- utils::read.csv(file.path(staging, "fit-status.csv"))
  score <- utils::read.csv(file.path(staging, "richness-score.csv"))
  testthat::expect_identical(status$terminal_status, "final_nonclean")
  testthat::expect_false(status$terminal_clean)
  testthat::expect_false(score$prediction_available)
  testthat::expect_false(score$interval_90_covered)
  testthat::expect_true(file.exists(file.path(staging, "completion-status.txt")))
  testthat::expect_false(file.exists(file.path(staging, "richness-pmf.csv")))
})

testthat::test_that("Task 4 run initialisation freezes provenance and resumes exactly", {
  manifest <- read_goal003_task4_manifests()
  output <- tempfile("goal003-task4-initialise-")
  on.exit(unlink(output, recursive = TRUE), add = TRUE)
  commit <- paste(rep("a", 40L), collapse = "")

  testthat::expect_silent(.goal003_task4_initialise_run(
    output,
    manifest,
    commit,
    max_workers = 2L
  ))
  required <- c(
    "run-metadata.rds", "source-hashes.csv", "package-versions.csv",
    "initialisation-status.txt"
  )
  testthat::expect_true(all(file.exists(file.path(output, required))))
  testthat::expect_true(all(file.exists(file.path(
    output,
    "manifests",
    basename(.goal003_task4_paths(.goal003_project_root()))
  ))))
  testthat::expect_silent(.goal003_task4_initialise_run(
    output,
    manifest,
    commit,
    max_workers = 2L
  ))
  testthat::expect_error(
    .goal003_task4_initialise_run(
      output,
      manifest,
      commit,
      max_workers = 1L
    ),
    "differs from this frozen run",
    fixed = TRUE
  )
})
