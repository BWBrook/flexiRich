testthat::test_that("Goal004 Task 4 dataset writer freezes prior and truth evidence", {
  manifest <- read_goal004_task4_manifests()
  prior <- goal004_task4_prior_forecasts(n_draws = 200L, manifest = manifest)
  row <- manifest$datasets[1L, ]
  parent <- tempfile("goal004-task4-dataset-")
  dir.create(parent)
  on.exit(unlink(parent, recursive = TRUE), add = TRUE)

  published <- publish_goal003_task4_artifact(
    parent,
    row$dataset_id,
    function(staging) {
      .goal004_task4_write_dataset(row, manifest, prior, staging)
    }
  )
  required <- c(
    "simulation.rds", "truth-species.csv", "truth-cameras.csv",
    "baseline-point-predictions.csv", "baseline-richness-scores.csv",
    "baseline-discovery-scores.csv", "prior-richness-scores.csv",
    "prior-discovery-scores.csv", "prior-membership-scores.csv",
    "dataset-status.csv", "completion-status.txt"
  )
  testthat::expect_true(all(file.exists(file.path(published, required))))
  restored <- readRDS(file.path(published, "simulation.rds"))
  testthat::expect_identical(restored$dataset_id, row$dataset_id)
  testthat::expect_false(any(c(
    "truth", "member", "true_richness"
  ) %in% names(restored$training_data)))
  prior_rows <- utils::read.csv(file.path(
    published,
    "prior-richness-scores.csv"
  ))
  testthat::expect_identical(nrow(prior_rows), 6L)
})

testthat::test_that("Goal004 Task 4 fit writer records a non-clean row once", {
  manifest <- read_goal004_task4_manifests()
  fit_row <- manifest$fits |>
    dplyr::filter(method == "goal004", run_role == "primary") |>
    dplyr::slice(1L)
  dataset_row <- manifest$datasets |>
    dplyr::filter(dataset_id == fit_row$dataset_id)
  simulation <- simulate_goal004_task4_dataset(dataset_row, manifest)
  fake_fit <- function(data, fit_row, output_dir, refresh) {
    testthat::expect_false(any(c(
      "truth", "member", "true_richness"
    ) %in% names(data)))
    list(
      terminal_status = "final_nonclean",
      data = data,
      profile = goal004_flexirich_profile("primary"),
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
    .goal004_task4_fit_model = fake_fit,
    .env = globalenv()
  )
  staging <- tempfile("goal004-task4-fit-")
  dir.create(staging)
  on.exit(unlink(staging, recursive = TRUE), add = TRUE)

  .goal004_task4_write_fit(fit_row, simulation, staging, refresh = 0L)
  status <- utils::read.csv(file.path(staging, "fit-status.csv"))
  richness <- utils::read.csv(file.path(staging, "richness-score.csv"))
  membership <- utils::read.csv(file.path(staging, "membership-score.csv"))

  testthat::expect_identical(status$terminal_status, "final_nonclean")
  testthat::expect_false(status$terminal_clean)
  testthat::expect_false(richness$prediction_available)
  testthat::expect_false(membership$prediction_available)
  testthat::expect_false(file.exists(file.path(staging, "richness-pmf.csv")))
  testthat::expect_true(file.exists(file.path(staging, "completion-status.txt")))
})

testthat::test_that("Goal004 Task 4 prediction adapters retain shared schemas", {
  candidates <- paste0("sp_", 1:3)
  goal004 <- list(
    posterior_richness_pmf = tibble::tibble(
      richness = 0:3,
      probability = c(0.1, 0.2, 0.3, 0.4)
    ),
    future_discovery_pmf = tibble::tibble(
      future_discoveries = 0:3,
      probability = c(0.4, 0.3, 0.2, 0.1)
    ),
    future_identity = tibble::tibble(
      candidate_id = candidates,
      encounter_class = "routine",
      training_detected = c(TRUE, FALSE, FALSE),
      future_first_detection_probability = c(0, 0.2, 0.1)
    ),
    candidate_membership = tibble::tibble(
      candidate_id = candidates,
      encounter_class = "routine",
      routine_weight = 1,
      training_detected = c(TRUE, FALSE, FALSE),
      prior_membership_probability = 0.5,
      posterior_membership_probability = c(1, 0.4, 0.3),
      membership_probability_movement = c(0.5, -0.1, -0.2)
    )
  )
  adapted <- .goal004_task4_adapt_prediction("goal004", goal004)

  testthat::expect_identical(
    names(adapted),
    c("richness", "discovery", "future_identity", "membership")
  )
  testthat::expect_identical(
    names(adapted$discovery),
    c("new_species_count", "probability")
  )
  testthat::expect_identical(
    names(adapted$membership),
    c("species_id", "membership_probability")
  )
})

testthat::test_that("Goal004 Task 4 raw sampler evidence is compressed", {
  staging <- tempfile("goal004-task4-compress-")
  dir.create(file.path(staging, "sampler", "primary"), recursive = TRUE)
  on.exit(unlink(staging, recursive = TRUE), add = TRUE)
  path <- file.path(staging, "sampler", "primary", "draws.csv")
  writeLines(c("a,b", "1,2"), path)

  compressed <- .goal004_task4_compress_sampler_csv(staging)
  testthat::expect_false(file.exists(path))
  testthat::expect_true(file.exists(compressed))
})

testthat::test_that("Goal004 Task 4 scripts preserve the protected boundary", {
  root <- if (dir.exists("R")) "." else file.path("..", "..")
  paths <- file.path(
    root,
    "scripts",
    c(
      "check_goal004_nested_model.R",
      "check_goal004_task4_execution.R",
      "run_goal004_task4_smoke.R",
      "run_goal004_task4_development.R"
    )
  )
  testthat::expect_true(all(file.exists(paths)))
  text <- tolower(paste(
    unlist(lapply(paths, readLines, warn = FALSE)),
    collapse = "\n"
  ))
  testthat::expect_false(grepl("judbury_inputs", text, fixed = TRUE))
  testthat::expect_false(grepl("task4-screen-v1", text, fixed = TRUE))
  testthat::expect_false(grepl("huon", text, fixed = TRUE))
})
