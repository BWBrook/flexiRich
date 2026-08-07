testthat::test_that("preflight states reproduce the locked evidence", {
  states <- goal002r_preflight_posterior_states()
  testthat::expect_identical(nrow(states), 750L)
  testthat::expect_setequal(
    unique(states$case_id),
    goal002r_paired_cases()$case_id
  )
  testthat::expect_true(all(states$U >= 0L & states$U <= 29L))
  testthat::expect_equal(
    range(states$a),
    c(-5.5408861, 3.2412154),
    tolerance = 1e-6
  )
  testthat::expect_equal(
    range(states$sigma_alpha),
    c(0.002599196, 4.675935063),
    tolerance = 1e-6
  )
})

testthat::test_that("protected grid includes every boundary", {
  grid <- goal002r_preflight_domain_grid()
  testthat::expect_identical(nrow(grid), 61L * 61L)
  testthat::expect_identical(range(grid$a), c(-8, 10))
  testthat::expect_identical(range(grid$sigma_alpha), c(0, 5.5))
  testthat::expect_true(all(grid$U == 29L))
})

testthat::test_that("audit reports both orders and scaled discrepancies", {
  states <- tibble::tribble(
    ~a, ~sigma_alpha, ~U,
    -8, 0, 29L,
     0, 2.75, 29L,
    10, 5.5, 29L
  )
  audit <- goal002r_preflight_audit(states, source = "test")
  testthat::expect_identical(nrow(audit), 6L)
  testthat::expect_setequal(unique(audit$order), c(256L, 512L))
  testthat::expect_true(all(c(
    "target_error", "scaled_a_error", "scaled_sigma_error",
    "scaled_log_sigma_error", "value_agreement",
    "derivative_a_mixed_pass", "derivative_sigma_mixed_pass",
    "scaled_reference_a_uncertainty",
    "scaled_reference_sigma_uncertainty", "tail_relative_bound",
    "expansion_change"
  ) %in% names(audit)))
  numeric <- audit[vapply(audit, is.numeric, logical(1))]
  testthat::expect_true(all(is.finite(unlist(numeric))))
})

testthat::test_that("selection precedence is 256 headroom then 512 then close", {
  passing <- tibble::tibble(
    order = c(256L, 512L),
    full_pass = c(TRUE, TRUE),
    headroom_pass = c(TRUE, TRUE)
  )
  testthat::expect_identical(
    goal002r_preflight_select(passing),
    "SELECT_256"
  )
  passing$headroom_pass[1] <- FALSE
  testthat::expect_identical(
    goal002r_preflight_select(passing),
    "SELECT_512"
  )
  passing$full_pass[2] <- FALSE
  testthat::expect_identical(
    goal002r_preflight_select(passing),
    "CLOSE"
  )
})

testthat::test_that("bounded maxima search reports every order and metric", {
  domain_audit <- tidyr::crossing(
    order = c(256L, 512L),
    state_index = seq_len(12L)
  ) |>
    dplyr::mutate(
      a = 0,
      sigma_alpha = 0,
      U = 29L,
      target_error = 0,
      scaled_a_error = 0,
      scaled_sigma_error = 0,
      scaled_log_sigma_error = 0
    )
  maxima <- goal002r_preflight_search_maxima(domain_audit)
  testthat::expect_identical(nrow(maxima), 8L)
  testthat::expect_identical(
    names(maxima),
    c("order", "metric", "a", "sigma_alpha", "observed", "convergence")
  )
  testthat::expect_setequal(maxima$order, c(256L, 512L))
  testthat::expect_setequal(maxima$metric, c(
    "target_error", "scaled_a_error", "scaled_sigma_error",
    "scaled_log_sigma_error"
  ))
  testthat::expect_true(all(is.finite(maxima$observed)))
  testthat::expect_true(all(maxima$a >= -8 & maxima$a <= 10))
  testthat::expect_true(all(
    maxima$sigma_alpha >= 0 & maxima$sigma_alpha <= 5.5
  ))
})

testthat::test_that("bounded search does not hide oracle failures", {
  domain_audit <- tidyr::crossing(
    order = c(256L, 512L),
    state_index = seq_len(12L)
  ) |>
    dplyr::mutate(
      a = 0,
      sigma_alpha = 0,
      U = 29L,
      target_error = 0,
      scaled_a_error = 0,
      scaled_sigma_error = 0,
      scaled_log_sigma_error = 0
    )
  binding <- list(.goal002r_preflight_metric_at = function(...) {
    stop("Preflight oracle failure at search fixture.", call. = FALSE)
  })
  rlang::local_bindings(!!!binding, .env = globalenv())
  testthat::expect_error(
    goal002r_preflight_search_maxima(domain_audit),
    "Preflight oracle failure at search fixture"
  )
})

testthat::test_that("criteria include searched peaks and locked gates", {
  audit <- tidyr::crossing(order = c(256L, 512L), replicate = 1:2) |>
    dplyr::mutate(
      target_error = 1e-4,
      scaled_a_error = 5e-4,
      scaled_sigma_error = 2e-4,
      scaled_log_sigma_error = 1e-4,
      value_agreement = 1e-10,
      derivative_a_mixed_pass = TRUE,
      derivative_sigma_mixed_pass = TRUE,
      scaled_reference_a_uncertainty = 1e-6,
      scaled_reference_sigma_uncertainty = 2e-6,
      tail_relative_bound = 1e-15,
      expansion_change = 1e-10
    )
  maxima <- tidyr::crossing(
    order = c(256L, 512L),
    metric = c(
      "target_error", "scaled_a_error", "scaled_sigma_error",
      "scaled_log_sigma_error"
    )
  ) |>
    dplyr::mutate(
      observed = dplyr::case_when(
        metric == "target_error" & order == 256L ~ 2e-4,
        metric == "target_error" & order == 512L ~ 4e-4,
        TRUE ~ 2e-3
      )
    )
  criteria <- goal002r_preflight_criteria(audit, audit, maxima)
  testthat::expect_identical(nrow(criteria), 2L)
  testthat::expect_equal(criteria$maximum_target, c(2e-4, 4e-4))
  testthat::expect_equal(criteria$maximum_gradient, c(2e-3, 2e-3))
  testthat::expect_true(all(criteria$full_pass))
  testthat::expect_identical(criteria$headroom_pass, c(TRUE, FALSE))
})

testthat::test_that("derivative states combine anchors and worst unique states", {
  anchors <- tibble::tribble(
    ~a, ~sigma_alpha,
    -8, 0,
    -8, 5.5,
    10, 0,
    10, 5.5,
     1, 2.75
  )
  candidates <- tibble::tibble(
    a = seq(-6, 6, length.out = 7L),
    sigma_alpha = seq(0.5, 3.5, length.out = 7L),
    target_error = 1:7
  )
  audit <- dplyr::bind_rows(
    dplyr::mutate(anchors, target_error = 100),
    candidates
  ) |>
    dplyr::mutate(
      scaled_a_error = 0,
      scaled_sigma_error = 0,
      scaled_log_sigma_error = 0
    )
  states <- .goal002r_preflight_derivative_states(audit, audit)
  testthat::expect_identical(nrow(states), 10L)
  testthat::expect_identical(nrow(dplyr::distinct(states)), 10L)
  testthat::expect_equal(
    dplyr::semi_join(anchors, states, by = names(anchors)),
    anchors
  )
  testthat::expect_setequal(
    states$a[!states$a %in% anchors$a],
    c(-2, 0, 2, 4, 6)
  )
})

testthat::test_that("preflight run assembles the locked result schema", {
  posterior_audit <- tibble::tibble(source = "posterior")
  domain_audit <- tibble::tibble(source = "domain")
  maxima <- tibble::tibble(marker = "maxima")
  criteria <- tibble::tibble(marker = "criteria")
  derivative_checks <- tibble::tibble(
    check_type = rep("derivative", 20L),
    passed = TRUE
  )
  bindings <- list(
    goal002r_preflight_posterior_states = function() tibble::tibble(U = 1L),
    goal002r_preflight_domain_grid = function() tibble::tibble(U = 29L),
    goal002r_preflight_audit = function(states, source) {
      if (source == "posterior") posterior_audit else domain_audit
    },
    goal002r_preflight_search_maxima = function(domain_audit) maxima,
    goal002r_preflight_criteria = function(
      posterior_audit,
      domain_audit,
      maxima
    ) criteria,
    goal002r_preflight_select = function(criteria) "SELECT_256",
    goal002r_preflight_rule = function(order) order,
    goal002r_preflight_rule_checks = function(rule, order) {
      tibble::tibble(check_type = paste0("rule_", order), passed = TRUE)
    },
    goal002r_preflight_algebra_checks = function() {
      tibble::tibble(check_type = "algebra", passed = TRUE)
    },
    .goal002r_preflight_derivative_states = function(...) {
      tibble::tibble(a = seq_len(10L), sigma_alpha = 1)
    },
    goal002r_preflight_derivative_checks = function(states) derivative_checks
  )
  rlang::local_bindings(!!!bindings, .env = globalenv())
  result <- goal002r_preflight_run()
  testthat::expect_identical(names(result), c(
    "rule_integrity", "posterior_audit", "domain_audit", "maxima",
    "criteria", "decision"
  ))
  testthat::expect_identical(result$posterior_audit, posterior_audit)
  testthat::expect_identical(result$domain_audit, domain_audit)
  testthat::expect_identical(result$maxima, maxima)
  testthat::expect_identical(result$criteria, criteria)
  testthat::expect_identical(result$decision, "SELECT_256")
  testthat::expect_identical(nrow(result$rule_integrity), 23L)
})
