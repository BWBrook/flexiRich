.goal007_ideal_task2_evidence <- function() {
  contract <- read_goal007_task1_contract(verify_external = FALSE)
  status <- contract$task2_fits |>
    dplyr::left_join(
      contract$task2_datasets[c("dataset_id", "profile_id", "screen_role")],
      by = "dataset_id"
    ) |>
    dplyr::transmute(
      fit_id,
      dataset_id,
      model_id,
      profile_id,
      screen_role,
      terminal_clean = TRUE,
      artifact_pass = dplyr::if_else(
        model_id == "independent",
        NA,
        TRUE
      )
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

testthat::test_that("Goal007 Task 2 ideal evidence selects the weaker F5 prior", {
  evidence <- .goal007_ideal_task2_evidence()
  result <- evaluate_goal007_task2_gates(
    evidence$contract,
    evidence$status,
    evidence$recovery
  )

  testthat::expect_identical(result$decision, "TASK2_PASS")
  testthat::expect_identical(result$selected_model_id, "shared_F5")
  testthat::expect_equal(nrow(result$gates), 52L)
  testthat::expect_true(all(result$gates$passed))
  testthat::expect_true(all(result$eligibility$eligible))
})

testthat::test_that("Goal007 weak-first rule falls back to F3 without reranking", {
  evidence <- .goal007_ideal_task2_evidence()
  f5 <- which(evidence$status$model_id == "shared_F5")[1:3]
  evidence$status$artifact_pass[f5] <- FALSE
  result <- evaluate_goal007_task2_gates(
    evidence$contract,
    evidence$status,
    evidence$recovery
  )

  testthat::expect_identical(result$decision, "TASK2_PASS")
  testthat::expect_identical(result$selected_model_id, "shared_F3")
  testthat::expect_false(result$eligibility$eligible[
    result$eligibility$model_id == "shared_F5"
  ])
  testthat::expect_true(result$eligibility$eligible[
    result$eligibility$model_id == "shared_F3"
  ])
})

testthat::test_that("Goal007 catastrophic gate combines both location targets", {
  evidence <- .goal007_ideal_task2_evidence()
  ids <- unique(evidence$recovery$dataset_id[
    evidence$recovery$model_id == "shared_F5" &
      evidence$recovery$screen_role == "core"
  ])[1:3]
  affected <- evidence$recovery$model_id == "shared_F5" &
    evidence$recovery$dataset_id %in% ids &
    evidence$recovery$encounter_class == "occasional"
  evidence$recovery$finite_error[affected] <- log(3) + 0.01
  result <- evaluate_goal007_task2_gates(
    evidence$contract,
    evidence$status,
    evidence$recovery
  )
  gate <- result$gates |>
    dplyr::filter(
      model_id == "shared_F5",
      gate_id == "T2-catastrophic"
    )

  testthat::expect_equal(gate$value, 3)
  testthat::expect_false(gate$passed)
  testthat::expect_identical(result$selected_model_id, "shared_F3")
})

testthat::test_that("Goal007 non-clean fits remain in fixed denominators", {
  evidence <- .goal007_ideal_task2_evidence()
  rows <- which(evidence$status$model_id == "shared_F5")[1:3]
  fit_ids <- evidence$status$fit_id[rows]
  evidence$status$terminal_clean[rows] <- FALSE
  evidence$recovery$terminal_clean[
    evidence$recovery$fit_id %in% fit_ids
  ] <- FALSE
  result <- evaluate_goal007_task2_gates(
    evidence$contract,
    evidence$status,
    evidence$recovery
  )
  clean <- result$gates |>
    dplyr::filter(model_id == "shared_F5", gate_id == "T2-clean")

  testthat::expect_equal(clean$value, 57)
  testthat::expect_equal(clean$denominator, 60)
  testthat::expect_false(clean$passed)
  testthat::expect_identical(result$selected_model_id, "shared_F3")
})
