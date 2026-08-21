testthat::test_that("Goal005 Task 4 freezes generated and source manifests", {
  manifest <- read_goal005_task4_manifest()
  staging <- tempfile("goal005-task4-manifests-")
  dir.create(staging)
  on.exit(unlink(staging, recursive = TRUE), add = TRUE)

  hashes <- .goal005_task4_write_manifests(staging, manifest)
  metadata <- list(manifest_file_hashes = hashes)
  testthat::expect_identical(length(hashes), 8L)
  testthat::expect_silent(
    .goal005_task4_validate_manifest_files(staging, metadata)
  )

  path <- .goal005_task4_manifest_files(staging)[[1L]]
  writeLines(c(readLines(path), "corrupt"), path)
  testthat::expect_error(
    .goal005_task4_validate_manifest_files(staging, metadata),
    "changed",
    fixed = TRUE
  )
})

testthat::test_that("Goal005 Task 4 result artifact retains all decision rows", {
  input <- .goal005_task4_gate_fixture()
  gates <- evaluate_goal005_task4_gates(
    input$manifest,
    input$fit_status,
    input$richness
  )
  staging <- tempfile("goal005-task4-results-")
  dir.create(staging)
  on.exit(unlink(staging, recursive = TRUE), add = TRUE)

  .goal005_task4_write_results(
    list(
      dataset_status = input$manifest$datasets,
      fit_status = input$fit_status,
      richness = input$richness,
      gates = gates
    ),
    staging
  )
  testthat::expect_identical(
    nrow(utils::read.csv(file.path(staging, "all-gates.csv"))),
    57L
  )
  testthat::expect_identical(
    nrow(utils::read.csv(file.path(staging, "paired-shifts.csv"))),
    72L
  )
  testthat::expect_identical(
    readLines(file.path(staging, "completion-status.txt"))[[1L]],
    "status=TASK4_COMPLETE"
  )
})

testthat::test_that("Goal005 Task 4 source stays outside protected outcomes", {
  root <- if (dir.exists("R")) "." else file.path("..", "..")
  paths <- file.path(
    root,
    c(
      "R/goal005_task4_manifest.R",
      "R/goal005_task4_simulation.R",
      "R/goal005_task4_gates.R",
      "R/goal005_task4_audit.R",
      "R/goal005_task4_execution.R",
      "scripts/run_goal005_task4_transfer_stress.R",
      "scripts/run_goal005_task4_smoke.R",
      "scripts/audit_goal005_task4_results.R"
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
