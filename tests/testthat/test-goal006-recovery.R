.goal006_passing_recovery <- function() {
  manifest <- goal006_expected_synthetic_manifest()
  status <- manifest |>
    dplyr::transmute(
      simulation_id,
      profile_id,
      terminal_clean = TRUE
    )
  recovery <- tidyr::crossing(
    simulation_id = manifest$simulation_id,
    encounter_class = c("routine", "occasional")
  ) |>
    dplyr::left_join(
      manifest[c("simulation_id", "profile_id", "replicate")],
      by = "simulation_id"
    ) |>
    dplyr::mutate(
      true_location = ifelse(
        encounter_class == "routine",
        log(0.002),
        log(0.0005)
      ),
      posterior_mean = true_location,
      posterior_median = true_location,
      lower_90 = true_location - 0.5,
      upper_90 = true_location + 0.5,
      error = 0,
      covered_90 = TRUE,
      terminal_clean = TRUE
    )
  list(manifest = manifest, status = status, recovery = recovery)
}

testthat::test_that("Goal006 Task 2 gate replay passes ideal recovery", {
  evidence <- .goal006_passing_recovery()
  result <- evaluate_goal006_task2_gates(
    evidence$manifest,
    evidence$status,
    evidence$recovery
  )

  testthat::expect_identical(result$decision, "TASK2_PASS")
  testthat::expect_equal(nrow(result$gates), 12L)
  testthat::expect_true(all(result$gates$passed))
  testthat::expect_equal(result$coverage_by_class$value, c(30L, 30L))
  testthat::expect_equal(sum(result$catastrophic$failed), 0L)
})

testthat::test_that("Goal006 Task 2 gate replay preserves fixed denominators", {
  evidence <- .goal006_passing_recovery()
  failed <- evidence$manifest$simulation_id[c(1L, 2L)]
  evidence$status$terminal_clean[
    evidence$status$simulation_id %in% failed
  ] <- FALSE
  rows <- evidence$recovery$simulation_id %in% failed
  evidence$recovery$terminal_clean[rows] <- FALSE
  evidence$recovery$covered_90[rows] <- FALSE
  evidence$recovery$error[rows] <- NA_real_
  evidence$recovery$posterior_median[rows] <- NA_real_
  result <- evaluate_goal006_task2_gates(
    evidence$manifest,
    evidence$status,
    evidence$recovery
  )

  testthat::expect_identical(result$decision, "TASK2_RECOVERY_FAIL")
  testthat::expect_false(result$gates$passed[
    result$gates$gate_id == "T2-clean"
  ])
  testthat::expect_false(result$gates$passed[
    result$gates$gate_id == "T2-catastrophic"
  ])
  testthat::expect_equal(
    result$gates$value[result$gates$gate_id == "T2-routine-coverage"],
    28
  )
  testthat::expect_equal(
    result$gates$denominator[
      result$gates$gate_id == "T2-routine-coverage"
    ],
    30
  )
})

testthat::test_that("Goal006 Task 2 output is restricted to its namespace", {
  root <- .goal003_project_root()
  testthat::expect_match(
    .goal006_task2_output_path(
      root,
      file.path("outputs", "goal006", "task2-test")
    ),
    "/outputs/goal006/task2-test$"
  )
  testthat::expect_error(
    .goal006_task2_output_path(root, file.path("outputs", "goal005", "bad")),
    "beneath outputs/goal006",
    fixed = TRUE
  )
})

testthat::test_that("Goal006 compact Task 2 results replay exactly", {
  evidence <- .goal006_passing_recovery()
  bridge <- goal006_likelihood_bridge_metrics()
  evaluation <- evaluate_goal006_task2_gates(
    evidence$manifest,
    evidence$status,
    evidence$recovery,
    bridge
  )
  directory <- tempfile("goal006-task2-audit-")
  dir.create(file.path(directory, "results"), recursive = TRUE)
  commit <- paste(rep("a", 40L), collapse = "")
  saveRDS(
    list(git_commit = commit, empirical_outcomes_used = FALSE),
    file.path(directory, "run-metadata.rds")
  )
  writeLines(
    c("status=TASK2_PASS", "empirical_outcomes_used=false"),
    file.path(directory, "completion-status.txt")
  )
  .goal006_task2_write_results(
    list(
      fit_status = evidence$status,
      recovery = evidence$recovery,
      bridge = bridge,
      evaluation = evaluation
    ),
    file.path(directory, "results")
  )

  replay <- audit_goal006_task2_results(directory, expected_commit = commit)
  testthat::expect_identical(replay$decision, "TASK2_PASS")
  testthat::expect_true(all(replay$gates$passed))
  testthat::expect_true(nrow(replay$artifact_hashes) >= 10L)
  unlink(directory, recursive = TRUE, force = TRUE)
})
