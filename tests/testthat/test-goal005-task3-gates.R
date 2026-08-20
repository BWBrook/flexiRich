testthat::test_that("Goal005 Task 3 fixture finds the coarsest class frontier", {
  input <- .goal005_task3_gate_fixture()
  result <- evaluate_goal005_task3_gates(
    input$manifest,
    input$fit_status,
    input$richness
  )

  testthat::expect_true(result$integrity$passed)
  testthat::expect_identical(nrow(result$pairs), 756L)
  testthat::expect_identical(nrow(result$gates), 357L)
  testthat::expect_true(all(result$gates$passed))
  testthat::expect_true(all(result$precision_summary$prefix_pass))
  testthat::expect_true(all(
    result$frontier$decision == "CLASS_FRONTIER_FOUND"
  ))
  testthat::expect_identical(
    result$frontier$coarsest_precision,
    rep("F5", 3L)
  )
})

testthat::test_that("Goal005 Task 3 frontier requires a passing precision prefix", {
  input <- .goal005_task3_gate_fixture()
  input <- .goal005_task3_flatten_level(input, 12L, "F1.25")
  result <- evaluate_goal005_task3_gates(
    input$manifest,
    input$fit_status,
    input$richness
  )
  twelve <- result$frontier |>
    dplyr::filter(train_occasions == 12L)
  levels <- result$precision_summary |>
    dplyr::filter(train_occasions == 12L)

  testthat::expect_false(levels$cell_pass[levels$information_level == "F1.25"])
  testthat::expect_true(levels$cell_pass[levels$information_level == "F5"])
  testthat::expect_false(levels$prefix_pass[levels$information_level == "F5"])
  testthat::expect_identical(twelve$finite_prefix_passes, 1L)
  testthat::expect_identical(twelve$coarsest_precision, "F1.10")
})

testthat::test_that("Goal005 Task 3 fresh oracle failure closes the duration", {
  input <- .goal005_task3_gate_fixture()
  input <- .goal005_task3_flatten_level(input, 12L, "C0")
  result <- evaluate_goal005_task3_gates(
    input$manifest,
    input$fit_status,
    input$richness
  )
  twelve <- result$frontier |>
    dplyr::filter(train_occasions == 12L)

  testthat::expect_identical(twelve$decision, "FRESH_ORACLE_FAIL")
  testthat::expect_identical(twelve$finite_prefix_passes, 0L)
  testthat::expect_true(is.na(twelve$coarsest_precision))
})

testthat::test_that("Goal005 Task 3 incomplete evidence cannot define a frontier", {
  input <- .goal005_task3_gate_fixture()
  input$fit_status <- input$fit_status[-1L, ]
  result <- evaluate_goal005_task3_gates(
    input$manifest,
    input$fit_status,
    input$richness
  )

  testthat::expect_false(result$integrity$passed)
  testthat::expect_true(all(!result$gates$passed))
  testthat::expect_true(all(result$frontier$decision == "INVALID_EVIDENCE"))
})

testthat::test_that("Goal005 Task 3 audit independently replays the frontier", {
  input <- .goal005_task3_gate_fixture()
  production <- evaluate_goal005_task3_gates(
    input$manifest,
    input$fit_status,
    input$richness
  )
  replayed_gates <- replay_goal005_task3_gates(production$pairs)
  gate_comparison <- .goal005_task3_compare_gates(
    replayed_gates,
    production$gates
  )
  replayed <- .goal005_task3_replay_frontier(
    replayed_gates,
    input$manifest$levels
  )
  frontier_comparison <- .goal005_task3_frontier_match(
    replayed$frontier,
    production$frontier
  )

  testthat::expect_identical(nrow(replayed_gates), 357L)
  testthat::expect_true(all(gate_comparison$all_match))
  testthat::expect_true(all(frontier_comparison$all_match))

  corrupted <- production$gates
  corrupted$value[[1L]] <- corrupted$value[[1L]] + 1
  testthat::expect_false(all(
    .goal005_task3_compare_gates(replayed_gates, corrupted)$all_match
  ))
})
