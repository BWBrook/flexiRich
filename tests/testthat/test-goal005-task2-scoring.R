.goal005_task2_gate_fixture <- function() {
  manifest <- read_goal005_task2_manifests()
  context <- manifest$datasets |>
    dplyr::select(
      dataset_id,
      pair_id,
      true_richness,
      train_occasions,
      replicate,
      training_active_camera_days,
      active_camera_count
    )
  status <- manifest$fits |>
    dplyr::left_join(context, by = "dataset_id") |>
    dplyr::mutate(
      terminal_status = "primary_clean",
      terminal_clean = TRUE,
      elapsed_seconds = 1
    )
  fit_scores <- status |>
    dplyr::transmute(
      dataset_id,
      fit_id,
      method,
      run_role,
      information_level,
      prior_profile,
      pool_profile,
      candidate_pool_size,
      terminal_clean,
      prediction_available = TRUE,
      true_richness,
      point_estimate = as.numeric(true_richness),
      absolute_error = 0,
      rps = 0.2,
      log_score = 1,
      interval_90_lower = true_richness - 5L,
      interval_90_upper = true_richness + 5L,
      interval_90_covered = TRUE,
      interval_90_width = 10
    )
  prior_scores <- context |>
    dplyr::transmute(
      dataset_id,
      fit_id = NA_character_,
      method = "goal005_prior",
      run_role = "prior_only",
      information_level = "P0",
      prior_profile = "uniform_membership",
      pool_profile = "core_50",
      candidate_pool_size = 50L,
      terminal_clean = TRUE,
      prediction_available = TRUE,
      true_richness,
      point_estimate = 25,
      absolute_error = abs(25 - true_richness),
      rps = 0.5,
      log_score = 1,
      interval_90_lower = 3L,
      interval_90_upper = 47L,
      interval_90_covered = TRUE,
      interval_90_width = 44
    )
  list(
    manifest = manifest,
    fit_status = status |>
      dplyr::select(
        dplyr::all_of(.goal005_task2_fit_fields),
        terminal_status,
        terminal_clean,
        elapsed_seconds
      ),
    richness = dplyr::bind_rows(fit_scores, prior_scores)
  )
}

testthat::test_that("Goal005 Task 2 uses one common uniform richness prior", {
  manifest <- read_goal005_task2_manifests()
  row <- manifest$datasets[1L, ]
  simulation <- simulate_goal005_task2_dataset(row, manifest)
  score <- score_goal005_task2_prior(row, simulation$truth)

  testthat::expect_identical(score$method, "goal005_prior")
  testthat::expect_identical(score$information_level, "P0")
  testthat::expect_equal(score$point_estimate, 25)
  testthat::expect_identical(score$interval_90_lower, 2L)
  testthat::expect_identical(score$interval_90_upper, 48L)
})

testthat::test_that("Goal005 Task 2 fit scoring fixes non-clean coverage", {
  manifest <- read_goal005_task2_manifests()
  dataset <- manifest$datasets[1L, ]
  fit <- manifest$fits |>
    dplyr::filter(dataset_id == dataset$dataset_id, information_level == "I0")
  simulation <- simulate_goal005_task2_dataset(dataset, manifest)
  score <- score_goal005_task2_fit(
    fit,
    simulation$truth,
    terminal_clean = FALSE
  )

  testthat::expect_false(score$prediction_available)
  testthat::expect_false(score$interval_90_covered)
  testthat::expect_true(is.na(score$point_estimate))
  testthat::expect_identical(score$information_level, "I0")
})

testthat::test_that("Goal005 Task 2 gate fixture opens class calibration", {
  input <- .goal005_task2_gate_fixture()
  result <- evaluate_goal005_task2_gates(
    input$manifest,
    input$fit_status,
    input$richness
  )

  testthat::expect_identical(
    names(result),
    c("integrity", "gates", "duration_summary", "pruning", "pairs")
  )
  testthat::expect_true(result$integrity$passed)
  testthat::expect_true(all(result$gates$passed))
  testthat::expect_identical(nrow(result$pairs), 360L)
  testthat::expect_true(all(
    result$pruning$task3_path == "CLASS_CALIBRATION_ELIGIBLE"
  ))
})

testthat::test_that("Goal005 Task 2 pruning follows the information ceiling", {
  input <- .goal005_task2_gate_fixture()
  c0_four <- input$richness$information_level == "C0" &
    input$richness$run_role == "information_ceiling" &
    input$richness$dataset_id %in% input$manifest$datasets$dataset_id[
      input$manifest$datasets$train_occasions == 4L
    ]
  input$richness$point_estimate[c0_four] <- 25
  input$richness$absolute_error[c0_four] <- abs(
    input$richness$point_estimate[c0_four] -
      input$richness$true_richness[c0_four]
  )
  result <- evaluate_goal005_task2_gates(
    input$manifest,
    input$fit_status,
    input$richness
  )
  four <- result$pruning[result$pruning$train_occasions == 4L, ]
  testthat::expect_identical(
    four$task3_path,
    "CANDIDATE_CALIBRATION_REQUIRED"
  )

  i0_four <- input$richness$information_level == "I0" &
    input$richness$run_role == "information_ceiling" &
    input$richness$dataset_id %in% input$manifest$datasets$dataset_id[
      input$manifest$datasets$train_occasions == 4L
    ]
  input$richness$point_estimate[i0_four] <- 25
  input$richness$absolute_error[i0_four] <- abs(
    input$richness$point_estimate[i0_four] -
      input$richness$true_richness[i0_four]
  )
  result <- evaluate_goal005_task2_gates(
    input$manifest,
    input$fit_status,
    input$richness
  )
  four <- result$pruning[result$pruning$train_occasions == 4L, ]
  testthat::expect_identical(four$task3_path, "CLOSED_ORACLE_FAIL")
})

testthat::test_that("Goal005 Task 2 catastrophic rule uses the fixed 36 fits", {
  input <- .goal005_task2_gate_fixture()
  ids <- input$manifest$datasets |>
    dplyr::filter(train_occasions == 8L) |>
    dplyr::slice_head(n = 2L) |>
    dplyr::pull(dataset_id)
  affected <- input$richness$information_level == "C0" &
    input$richness$dataset_id %in% ids
  input$richness$absolute_error[affected] <- 12.5
  result <- evaluate_goal005_task2_gates(
    input$manifest,
    input$fit_status,
    input$richness
  )
  gate <- result$gates |>
    dplyr::filter(
      information_level == "C0",
      train_occasions == 8L,
      gate_id == "catastrophic-or-nonclean"
    )

  testthat::expect_identical(gate$denominator, 36L)
  testthat::expect_identical(gate$numerator, 2)
  testthat::expect_false(gate$passed)
})

testthat::test_that("Goal005 Task 2 rejects incomplete evidence before pruning", {
  input <- .goal005_task2_gate_fixture()
  input$fit_status <- input$fit_status[-1L, ]
  result <- evaluate_goal005_task2_gates(
    input$manifest,
    input$fit_status,
    input$richness
  )

  testthat::expect_false(result$integrity$passed)
  testthat::expect_true(all(result$pruning$task3_path == "INVALID_EVIDENCE"))
})

testthat::test_that("Goal005 Task 2 result artifact preserves all gate rows", {
  input <- .goal005_task2_gate_fixture()
  gates <- evaluate_goal005_task2_gates(
    input$manifest,
    input$fit_status,
    input$richness
  )
  staging <- tempfile("goal005-task2-results-")
  dir.create(staging)
  on.exit(unlink(staging, recursive = TRUE), add = TRUE)

  .goal005_task2_write_results(
    list(
      dataset_status = input$manifest$datasets,
      fit_status = input$fit_status,
      richness = input$richness,
      gates = gates
    ),
    staging
  )
  testthat::expect_identical(nrow(gates$gates), 170L)
  testthat::expect_true(file.exists(file.path(
    staging,
    "completion-status.txt"
  )))
  testthat::expect_identical(
    readLines(file.path(staging, "completion-status.txt"))[[1L]],
    "status=TASK2_COMPLETE"
  )
})
