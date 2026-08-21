testthat::test_that("Goal005 Task 4 fixture passes all transfer gates", {
  input <- .goal005_task4_gate_fixture()
  result <- evaluate_goal005_task4_gates(
    input$manifest,
    input$fit_status,
    input$richness
  )

  testthat::expect_true(result$integrity$passed)
  testthat::expect_identical(nrow(result$pairs), 108L)
  testthat::expect_identical(nrow(result$profile_gates), 51L)
  testthat::expect_identical(nrow(result$paired_shifts), 72L)
  testthat::expect_identical(nrow(result$shift_gates), 6L)
  testthat::expect_identical(nrow(result$all_gates), 57L)
  testthat::expect_true(all(result$all_gates$passed))
  testthat::expect_identical(result$decision$decision, "TRANSFER_ROBUST")
})

testthat::test_that("Goal005 Task 4 catches a large paired maximum shift", {
  input <- .goal005_task4_gate_fixture()
  affected <- input$richness$information_level == "up_1.25" &
    input$richness$true_richness == 25L &
    grepl("-r01--", input$richness$fit_id, fixed = TRUE)
  input$richness$point_estimate[affected] <-
    input$richness$point_estimate[affected] + 9
  input$richness$absolute_error[affected] <- 9
  result <- evaluate_goal005_task4_gates(
    input$manifest,
    input$fit_status,
    input$richness
  )
  maximum <- result$shift_gates |>
    dplyr::filter(
      information_level == "up_1.25",
      gate_id == "maximum-posterior-shift"
    )

  testthat::expect_false(maximum$passed)
  testthat::expect_equal(maximum$value, 9)
  testthat::expect_identical(result$decision$decision, "TRANSFER_SENSITIVE")
})

testthat::test_that("Goal005 Task 4 distinguishes fresh baseline failure", {
  input <- .goal005_task4_gate_fixture()
  affected <- input$richness$information_level == "unbiased"
  input$richness$point_estimate[affected] <- 25
  input$richness$absolute_error[affected] <- abs(
    input$richness$true_richness[affected] - 25
  )
  result <- evaluate_goal005_task4_gates(
    input$manifest,
    input$fit_status,
    input$richness
  )

  testthat::expect_identical(
    result$decision$decision,
    "UNBIASED_REPLICATION_FAIL"
  )
})

testthat::test_that("Goal005 Task 4 incomplete evidence is invalid", {
  input <- .goal005_task4_gate_fixture()
  input$fit_status <- input$fit_status[-1L, ]
  result <- evaluate_goal005_task4_gates(
    input$manifest,
    input$fit_status,
    input$richness
  )

  testthat::expect_false(result$integrity$passed)
  testthat::expect_true(all(!result$all_gates$passed))
  testthat::expect_identical(result$decision$decision, "INVALID_EVIDENCE")
})

testthat::test_that("Goal005 Task 4 audit independently replays decisions", {
  input <- .goal005_task4_gate_fixture()
  production <- evaluate_goal005_task4_gates(
    input$manifest,
    input$fit_status,
    input$richness
  )
  profile <- replay_goal005_task4_profile_gates(production$pairs)
  shifts <- .goal005_task4_replay_shifts(production$pairs)
  shift_gates <- .goal005_task4_replay_shift_gates(shifts)
  profile_comparison <- .goal005_task4_compare_gates(
    profile,
    production$profile_gates,
    51L
  )
  shift_comparison <- .goal005_task4_compare_gates(
    shift_gates,
    production$shift_gates,
    6L
  )

  testthat::expect_true(all(profile_comparison$all_match))
  testthat::expect_true(all(shift_comparison$all_match))
  testthat::expect_identical(
    .goal005_task4_replay_decision(profile, shift_gates),
    production$decision$decision
  )

  corrupted <- production$shift_gates
  corrupted$value[[1L]] <- corrupted$value[[1L]] + 1
  testthat::expect_false(all(
    .goal005_task4_compare_gates(shift_gates, corrupted, 6L)$all_match
  ))
})
