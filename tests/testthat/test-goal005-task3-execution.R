testthat::test_that("Goal005 Task 3 freezes generated and source manifests", {
  manifest <- read_goal005_task3_manifest()
  staging <- tempfile("goal005-task3-manifests-")
  dir.create(staging)
  on.exit(unlink(staging, recursive = TRUE), add = TRUE)

  hashes <- .goal005_task3_write_manifests(staging, manifest)
  metadata <- list(manifest_file_hashes = hashes)
  testthat::expect_identical(length(hashes), 8L)
  testthat::expect_silent(
    .goal005_task3_validate_manifest_files(staging, metadata)
  )

  path <- .goal005_task3_manifest_files(staging)[[1L]]
  writeLines(c(readLines(path), "corrupt"), path)
  testthat::expect_error(
    .goal005_task3_validate_manifest_files(staging, metadata),
    "changed",
    fixed = TRUE
  )
})

testthat::test_that("Goal005 Task 3 scoring preserves its calibration identity", {
  manifest <- read_goal005_task3_manifest()
  fit_row <- manifest$fits |>
    dplyr::filter(information_level == "F1.25") |>
    dplyr::slice(1L)
  dataset_row <- manifest$datasets |>
    dplyr::filter(dataset_id == fit_row$dataset_id)
  simulation <- simulate_goal005_task3_dataset(dataset_row, manifest)
  score <- score_goal005_task2_fit(
    .goal005_task3_as_task2_fit_row(fit_row),
    simulation$truth,
    terminal_clean = FALSE
  )

  testthat::expect_identical(score$information_level, "F1.25")
  testthat::expect_identical(
    score$prior_profile,
    "class_location_calibration_v1"
  )
  testthat::expect_false(score$prediction_available)
  testthat::expect_false(score$interval_90_covered)
})

testthat::test_that("Goal005 Task 3 result artifact retains the full surface", {
  input <- .goal005_task3_gate_fixture()
  gates <- evaluate_goal005_task3_gates(
    input$manifest,
    input$fit_status,
    input$richness
  )
  staging <- tempfile("goal005-task3-results-")
  dir.create(staging)
  on.exit(unlink(staging, recursive = TRUE), add = TRUE)

  .goal005_task3_write_results(
    list(
      dataset_status = input$manifest$datasets,
      fit_status = input$fit_status,
      richness = input$richness,
      gates = gates
    ),
    staging
  )
  testthat::expect_identical(
    nrow(utils::read.csv(file.path(staging, "calibration-gates.csv"))),
    357L
  )
  testthat::expect_identical(
    nrow(utils::read.csv(file.path(staging, "frontier-summary.csv"))),
    3L
  )
  testthat::expect_identical(
    readLines(file.path(staging, "completion-status.txt"))[[1L]],
    "status=TASK3_COMPLETE"
  )
})

testthat::test_that("Goal005 Task 3 source stays outside protected outcomes", {
  root <- if (dir.exists("R")) "." else file.path("..", "..")
  paths <- file.path(
    root,
    c(
      "R/goal005_class_calibration.R",
      "R/goal005_task3_manifest.R",
      "R/goal005_task3_simulation.R",
      "R/goal005_task3_gates.R",
      "R/goal005_task3_execution.R",
      "scripts/check_goal005_class_calibration_model.R",
      "scripts/check_goal005_task3_execution.R",
      "scripts/run_goal005_task3_smoke.R",
      "scripts/run_goal005_task3_class_frontier.R"
    )
  )
  testthat::expect_true(all(file.exists(paths)))
  text <- tolower(paste(
    unlist(lapply(paths, readLines, warn = FALSE)),
    collapse = "\n"
  ))
  testthat::expect_false(grepl("judbury_inputs", text, fixed = TRUE))
  testthat::expect_false(grepl("huon", text, fixed = TRUE))
})
