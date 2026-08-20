testthat::test_that("Goal005 Task 2 dataset artifacts retain truth separation", {
  manifest <- read_goal005_task2_manifests()
  row <- manifest$datasets |>
    dplyr::filter(
      scenario_id == "aligned_mid",
      train_occasions == 8L,
      replicate == 1L
    )
  staging <- tempfile("goal005-task2-dataset-")
  dir.create(staging)
  on.exit(unlink(staging, recursive = TRUE), add = TRUE)

  .goal005_task2_write_dataset(row, manifest, staging)
  required <- c(
    "simulation.rds", "truth-species.csv", "truth-cameras.csv",
    "prior-richness-score.csv", "dataset-status.csv",
    "completion-status.txt"
  )
  testthat::expect_true(all(file.exists(file.path(staging, required))))
  simulation <- readRDS(file.path(staging, "simulation.rds"))
  testthat::expect_false(any(c(
    "truth", "member", "true_richness", "alpha_fixed"
  ) %in% names(simulation$training_data)))
  prior <- utils::read.csv(file.path(staging, "prior-richness-score.csv"))
  testthat::expect_identical(nrow(prior), 1L)
  testthat::expect_identical(prior$method, "goal005_prior")
})

testthat::test_that("Goal005 Task 2 records a non-clean oracle fit once", {
  manifest <- read_goal005_task2_manifests()
  fit_row <- manifest$fits |>
    dplyr::filter(information_level == "I0") |>
    dplyr::slice(1L)
  dataset_row <- manifest$datasets |>
    dplyr::filter(dataset_id == fit_row$dataset_id)
  simulation <- simulate_goal005_task2_dataset(dataset_row, manifest)
  fake_fit <- function(simulation, fit_row, output_dir, refresh) {
    testthat::expect_false(any(c(
      "truth", "member", "true_richness", "alpha_fixed"
    ) %in% names(simulation$training_data)))
    list(
      terminal_status = "final_nonclean",
      data = prepare_goal005_candidate_oracle_data(
        simulation$training_data,
        stats::setNames(
          simulation$truth$species$alpha,
          simulation$truth$species$species_id
        )
      ),
      prior = goal005_candidate_oracle_prior(),
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
    .goal005_task2_fit_model = fake_fit,
    .env = globalenv()
  )
  staging <- tempfile("goal005-task2-fit-")
  dir.create(staging)
  on.exit(unlink(staging, recursive = TRUE), add = TRUE)

  .goal005_task2_write_fit(fit_row, simulation, staging, refresh = 0L)
  status <- utils::read.csv(file.path(staging, "fit-status.csv"))
  score <- utils::read.csv(file.path(staging, "richness-score.csv"))
  testthat::expect_identical(status$terminal_status, "final_nonclean")
  testthat::expect_false(status$terminal_clean)
  testthat::expect_false(score$prediction_available)
  testthat::expect_false(file.exists(file.path(staging, "richness-pmf.csv")))
  testthat::expect_true(file.exists(file.path(staging, "completion-status.txt")))
})

testthat::test_that("Goal005 Task 2 source stays outside empirical outcomes", {
  root <- if (dir.exists("R")) "." else file.path("..", "..")
  paths <- file.path(
    root,
    c(
      "R/goal005_task2_execution.R",
      "scripts/check_goal005_task2_execution.R",
      "scripts/run_goal005_task2_smoke.R",
      "scripts/run_goal005_task2_information_ceiling.R"
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
