testthat::test_that("Goal007 Task 2 output is confined to its namespace", {
  root <- .goal003_project_root()
  valid <- .goal007_task2_output_path(
    root,
    file.path("outputs", "goal007", "task2-test")
  )
  testthat::expect_match(valid, "/outputs/goal007/task2-test$")
  testthat::expect_error(
    .goal007_task2_output_path(
      root,
      file.path("outputs", "goal006", "task2-test")
    ),
    "beneath outputs/goal007",
    fixed = TRUE
  )
})

testthat::test_that("Goal007 Task 2 runner freezes the exact contract", {
  contract <- read_goal007_task1_contract(verify_external = FALSE)
  output <- tempfile("goal007-task2-manifests-")
  dir.create(output)
  hashes <- .goal007_task2_write_manifests(output, contract)

  testthat::expect_length(hashes, 7L)
  testthat::expect_true(all(grepl("^[0-9a-f]{64}$", hashes)))
  testthat::expect_equal(
    nrow(.goal007_audit_read_csv(file.path(output, "manifests", "fits.csv"))),
    180L
  )
  testthat::expect_equal(
    nrow(.goal007_audit_read_csv(file.path(output, "manifests", "gates.csv"))),
    26L
  )
  source_hashes <- .goal007_task2_source_hashes(.goal003_project_root())
  testthat::expect_true(any(
    source_hashes$path == "scripts/audit_goal007_task2_results.R"
  ))
  unlink(output, recursive = TRUE, force = TRUE)
})

.goal007_task2_ideal_evidence <- function() {
  contract <- read_goal007_task1_contract(verify_external = FALSE)
  status <- contract$task2_fits |>
    dplyr::left_join(
      contract$task2_datasets[c(
        "dataset_id", "profile_id", "screen_role"
      )],
      by = "dataset_id"
    ) |>
    dplyr::transmute(
      fit_id,
      dataset_id,
      model_id,
      profile_id,
      screen_role,
      terminal_clean = TRUE,
      artifact_pass = dplyr::if_else(model_id == "independent", NA, TRUE)
    )
  recovery <- tidyr::crossing(
    fit_id = status$fit_id,
    encounter_class = c("routine", "occasional")
  ) |>
    dplyr::left_join(status, by = "fit_id") |>
    dplyr::mutate(
      generating_location = 0,
      finite_location = 0,
      posterior_median = dplyr::case_when(
        encounter_class == "routine" ~ 0.1,
        model_id == "independent" ~ 0.4,
        TRUE ~ 0.1
      ),
      lower_90 = -1,
      upper_90 = 1,
      generator_error = posterior_median,
      finite_error = posterior_median,
      generator_covered_90 = TRUE
    ) |>
    dplyr::select(
      fit_id,
      dataset_id,
      model_id,
      profile_id,
      screen_role,
      encounter_class,
      generating_location,
      finite_location,
      posterior_median,
      lower_90,
      upper_90,
      generator_error,
      finite_error,
      generator_covered_90,
      terminal_clean
    )
  list(contract = contract, status = status, recovery = recovery)
}

testthat::test_that("Goal007 independent replay matches but does not call production", {
  evidence <- .goal007_task2_ideal_evidence()
  prior <- goal007_prior_bridge_metrics()
  likelihood <- goal006_likelihood_bridge_metrics()
  production <- evaluate_goal007_task2_gates(
    evidence$contract,
    evidence$status,
    evidence$recovery,
    prior,
    likelihood
  )
  replay <- replay_goal007_task2_gates_independent(
    evidence$contract,
    evidence$status,
    evidence$recovery,
    prior,
    likelihood
  )

  testthat::expect_equal(replay$gates, production$gates, tolerance = 1e-12)
  testthat::expect_equal(replay$eligibility, production$eligibility)
  testthat::expect_identical(replay$decision, production$decision)
  testthat::expect_identical(
    replay$selected_model_id,
    production$selected_model_id
  )
})

.goal007_fake_task2_archive <- function() {
  evidence <- .goal007_task2_ideal_evidence()
  prior <- goal007_prior_bridge_metrics()
  likelihood <- goal006_likelihood_bridge_metrics()
  evaluation <- evaluate_goal007_task2_gates(
    evidence$contract,
    evidence$status,
    evidence$recovery,
    prior,
    likelihood
  )
  output <- tempfile("goal007-task2-audit-")
  dir.create(output)
  manifest_hashes <- .goal007_task2_write_manifests(output, evidence$contract)
  commit <- paste(rep("a", 40L), collapse = "")
  saveRDS(
    list(
      git_commit = commit,
      contract_hashes = evidence$contract$hashes,
      manifest_hashes = manifest_hashes,
      max_workers = 1L,
      empirical_outcomes_used = FALSE
    ),
    file.path(output, "run-metadata.rds"),
    version = 3
  )
  .goal003_task4_write_csv(
    .goal007_task2_source_hashes(.goal003_project_root()),
    file.path(output, "source-hashes.csv")
  )
  dir.create(file.path(output, "results"))
  .goal007_task2_write_results(
    list(
      fit_status = evidence$status,
      recovery = evidence$recovery,
      prior_bridge = prior,
      likelihood_bridge = likelihood,
      evaluation = evaluation
    ),
    file.path(output, "results")
  )
  writeLines(
    c(
      "status=TASK2_PASS",
      "selected_model_id=shared_F5",
      paste0("git_commit=", commit),
      "datasets=60",
      "fits=180",
      "empirical_outcomes_used=false"
    ),
    file.path(output, "completion-status.txt")
  )
  list(output = output, commit = commit)
}

testthat::test_that("Goal007 compact Task 2 archive audits exactly", {
  archive <- .goal007_fake_task2_archive()
  replay <- audit_goal007_task2_results(
    archive$output,
    expected_commit = archive$commit
  )

  testthat::expect_identical(replay$decision, "TASK2_PASS")
  testthat::expect_identical(replay$selected_model_id, "shared_F5")
  testthat::expect_equal(nrow(replay$gates), 52L)
  testthat::expect_true(all(replay$gates$passed))
  testthat::expect_true(nrow(replay$artifact_hashes) >= 7L)
  unlink(archive$output, recursive = TRUE, force = TRUE)
})

testthat::test_that("Goal007 audit detects a changed recorded gate", {
  archive <- .goal007_fake_task2_archive()
  path <- file.path(archive$output, "results", "decision-gates.csv")
  gates <- .goal007_audit_read_csv(path)
  gates$value[[1L]] <- gates$value[[1L]] + 0.01
  .goal003_task4_write_csv(gates, path)

  testthat::expect_error(
    audit_goal007_task2_results(
      archive$output,
      expected_commit = archive$commit
    ),
    "independent audit disagrees",
    fixed = TRUE
  )
  unlink(archive$output, recursive = TRUE, force = TRUE)
})
