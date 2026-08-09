goal002r_preflight_test_pair <- function(
  log_m0 = -10,
  derivative_a = -2,
  derivative_sigma = 5
) {
  c(
    log_m0 = log_m0,
    derivative_a = derivative_a,
    derivative_sigma = derivative_sigma,
    value_agreement = 0,
    derivative_a_agreement = 0,
    derivative_sigma_agreement = 0,
    derivative_a_mixed_limit = 1e-8,
    derivative_sigma_mixed_limit = 1e-8,
    derivative_a_mixed_pass = 1,
    derivative_sigma_mixed_pass = 1,
    scaled_reference_a_uncertainty = 0,
    scaled_reference_sigma_uncertainty = 0,
    scaled_reference_a_pass = 1,
    scaled_reference_sigma_pass = 1,
    maximum_tail_relative_bound = 0,
    maximum_expansion_change = 0,
    maximum_tail_expansions = 0
  )
}

goal002r_preflight_test_domain_starts <- function() {
  coordinates <- tibble::tibble(
    start_id = seq_len(12L),
    a = c(-7, -6, -5, -4, -3, -2, 0, 1, 3, 5, 7, 9),
    sigma_alpha = c(0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5, 5.25, 5.4)
  )
  tidyr::crossing(order = c(256L, 512L), start_id = seq_len(12L)) |>
    dplyr::left_join(coordinates, by = "start_id") |>
    dplyr::mutate(
      U = 29L,
      target_error = 13 - start_id,
      scaled_a_error = 13 - start_id,
      scaled_sigma_error = 13 - start_id,
      scaled_log_sigma_error = 13 - start_id
    )
}

goal002r_preflight_test_audit <- function(
  target_error = 0,
  scaled_a_error = 0,
  scaled_sigma_error = 0,
  scaled_log_sigma_error = 0
) {
  tibble::tibble(
    order = c(256L, 512L),
    target_error = target_error,
    scaled_a_error = scaled_a_error,
    scaled_sigma_error = scaled_sigma_error,
    scaled_log_sigma_error = scaled_log_sigma_error,
    value_agreement = 0,
    derivative_a_mixed_pass = TRUE,
    derivative_sigma_mixed_pass = TRUE,
    scaled_reference_a_uncertainty = 0,
    scaled_reference_sigma_uncertainty = 0,
    tail_relative_bound = 0,
    expansion_change = 0
  )
}

goal002r_preflight_test_maxima <- function(
  target_error = 0,
  scaled_a_error = 0,
  scaled_sigma_error = 0,
  scaled_log_sigma_error = 0
) {
  values <- c(
    target_error = target_error,
    scaled_a_error = scaled_a_error,
    scaled_sigma_error = scaled_sigma_error,
    scaled_log_sigma_error = scaled_log_sigma_error
  )
  tidyr::crossing(
    order = c(256L, 512L),
    metric = names(values)
  ) |>
    dplyr::mutate(observed = unname(values[metric]))
}

goal002r_preflight_test_rule_checks <- function() {
  tidyr::crossing(order = c(256L, 512L), check_index = seq_len(9L)) |>
    dplyr::transmute(
      order,
      check = paste0("check_", check_index),
      observed = 0,
      threshold = 1,
      passed = TRUE
    )
}

goal002r_preflight_test_algebra_checks <- function() {
  tibble::tibble(
    sigma_alpha = c(0, 0.4, 1.1, 2),
    rowwise_log_m0 = -1,
    reduced_log_m0 = -1,
    absolute_error = 0,
    passed = TRUE
  )
}

goal002r_preflight_test_run_bindings <- function(
  rule_checks = goal002r_preflight_test_rule_checks(),
  algebra_checks = goal002r_preflight_test_algebra_checks(),
  derivative_passed = rep(TRUE, 20L)
) {
  posterior_audit <- tibble::tibble(source = "posterior")
  domain_audit <- tibble::tibble(source = "domain")
  maxima <- tibble::tibble(marker = "maxima")
  criteria <- tibble::tibble(marker = "criteria")
  list(
    goal002r_preflight_posterior_states = function() tibble::tibble(U = 1L),
    goal002r_preflight_domain_grid = function() tibble::tibble(U = 29L),
    goal002r_preflight_audit = function(states, source) {
      if (source == "posterior") posterior_audit else domain_audit
    },
    goal002r_preflight_search_maxima = function(domain_audit) maxima,
    goal002r_preflight_criteria = function(...) criteria,
    goal002r_preflight_select = function(criteria) "SELECT_256",
    goal002r_preflight_rule = function(order) order,
    goal002r_preflight_rule_checks = function(rule, order) {
      rule_checks[rule_checks$order == order, , drop = FALSE]
    },
    goal002r_preflight_algebra_checks = function() algebra_checks,
    .goal002r_preflight_derivative_states = function(...) {
      tibble::tibble(a = seq_len(10L), sigma_alpha = 1)
    },
    goal002r_preflight_derivative_checks = function(states) {
      tibble::tibble(
        check_type = rep("derivative", 20L),
        passed = derivative_passed
      )
    }
  )
}

testthat::test_that("preflight states reproduce the locked evidence", {
  states <- goal002r_preflight_posterior_states()
  testthat::expect_identical(nrow(states), 750L)
  testthat::expect_identical(names(states), c(
    "case_id", "check_source", "posterior_row", "a", "sigma_alpha", "U"
  ))
  testthat::expect_setequal(
    unique(states$case_id),
    goal002r_paired_cases()$case_id
  )
  testthat::expect_equal(
    dplyr::count(states, case_id),
    tibble::tibble(
      case_id = c(
        "historical-hard", "small-easy", "small-unseen",
        "standard-long-medium", "standard-short-high",
        "standard-short-low"
      ),
      n = rep(125L, 6L)
    )
  )
  testthat::expect_equal(
    dplyr::arrange(dplyr::distinct(states, case_id, U), case_id),
    tibble::tribble(
      ~case_id, ~U,
      "historical-hard", 10L,
      "small-easy", 4L,
      "small-unseen", 6L,
      "standard-long-medium", 11L,
      "standard-short-high", 15L,
      "standard-short-low", 29L
    )
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
  testthat::expect_identical(
    sort(unique(grid$a)),
    seq(-8, 10, length.out = 61L)
  )
  testthat::expect_identical(
    sort(unique(grid$sigma_alpha)),
    seq(0, 5.5, length.out = 61L)
  )
  testthat::expect_identical(
    nrow(dplyr::distinct(grid, a, sigma_alpha)),
    61L * 61L
  )
  testthat::expect_identical(range(grid$a), c(-8, 10))
  testthat::expect_identical(range(grid$sigma_alpha), c(0, 5.5))
  testthat::expect_true(all(grid$U == 29L))
})

testthat::test_that("audit reports both orders and scaled discrepancies", {
  calls <- new.env(parent = emptyenv())
  calls$references <- 0L
  calls$rules <- integer()
  calls$candidate_orders <- integer()
  bindings <- list(
    goal002r_preflight_reference_pair = function(a, sigma_alpha) {
      calls$references <- calls$references + 1L
      goal002r_preflight_test_pair()
    },
    goal002r_preflight_rule = function(order) {
      calls$rules <- c(calls$rules, order)
      order
    },
    goal002r_preflight_gh = function(a, sigma_alpha, rule) {
      calls$candidate_orders <- c(calls$candidate_orders, rule)
      if (rule == 256L) {
        c(log_m0 = -9, derivative_a = -4, derivative_sigma = 1)
      } else {
        c(log_m0 = -12, derivative_a = -1, derivative_sigma = 7)
      }
    }
  )
  rlang::local_bindings(!!!bindings, .env = globalenv())
  states <- tibble::tribble(
    ~a, ~sigma_alpha, ~U,
    1, 2, 3L,
    2, 0.5, 7L
  )
  audit <- goal002r_preflight_audit(states, source = "test")
  testthat::expect_identical(calls$references, 2L)
  testthat::expect_identical(calls$rules, c(256L, 512L))
  testthat::expect_identical(
    calls$candidate_orders,
    c(256L, 512L, 256L, 512L)
  )
  observed <- dplyr::select(
    audit,
    state_index,
    order,
    target_error,
    scaled_a_error,
    scaled_sigma_error,
    scaled_log_sigma_error
  )
  expected <- tibble::tribble(
    ~state_index, ~order, ~target_error, ~scaled_a_error,
    ~scaled_sigma_error, ~scaled_log_sigma_error,
    1L, 256L, 3, 9, 10.2, 28.8,
    1L, 512L, 6, 4.5, 5.1, 14.4,
    2L, 256L, 7, 21, 23.8, 16.8,
    2L, 512L, 14, 10.5, 11.9, 8.4
  )
  testthat::expect_equal(observed, expected, tolerance = 1e-12)
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

testthat::test_that("bounded maxima recover distinct interior and boundary peaks", {
  domain_audit <- goal002r_preflight_test_domain_starts()
  bindings <- list(
    goal002r_preflight_rule = function(order) order,
    .goal002r_preflight_metric_at = function(
      a,
      sigma_alpha,
      order,
      rule,
      metric
    ) {
      switch(
        metric,
        target_error = 100 - (a - 2)^2 - (sigma_alpha - 1)^2,
        scaled_a_error = 50 - (a + 8)^2 - (sigma_alpha - 2)^2,
        scaled_sigma_error = 40 - (a - 10)^2 - (sigma_alpha - 5.5)^2,
        scaled_log_sigma_error = 30 - (a + 3)^2 - (sigma_alpha - 4)^2
      )
    }
  )
  rlang::local_bindings(!!!bindings, .env = globalenv())
  maxima <- goal002r_preflight_search_maxima(domain_audit)
  testthat::expect_identical(nrow(maxima), 8L)
  testthat::expect_identical(
    names(maxima),
    c("order", "metric", "a", "sigma_alpha", "observed", "convergence")
  )
  testthat::expect_false(anyDuplicated(maxima[c("order", "metric")]) > 0L)
  expected <- tibble::tribble(
    ~metric, ~a, ~sigma_alpha, ~observed,
    "target_error", 2, 1, 100,
    "scaled_a_error", -8, 2, 50,
    "scaled_sigma_error", 10, 5.5, 40,
    "scaled_log_sigma_error", -3, 4, 30
  )
  observed <- dplyr::left_join(
    maxima,
    expected,
    by = "metric",
    suffix = c("", "_expected")
  )
  testthat::expect_equal(observed$a, observed$a_expected, tolerance = 1e-5)
  testthat::expect_equal(
    observed$sigma_alpha,
    observed$sigma_alpha_expected,
    tolerance = 1e-5
  )
  testthat::expect_equal(
    observed$observed,
    observed$observed_expected,
    tolerance = 1e-8
  )
  testthat::expect_true(all(observed$convergence == 0L))
})

testthat::test_that("bounded maxima use the metric-specific twelve largest starts", {
  candidates <- tibble::tibble(
    candidate_id = seq_len(15L),
    a = seq(-7, 7, length.out = 15L),
    sigma_alpha = seq(0.25, 5.25, length.out = 15L),
    target_error = 15:1,
    scaled_a_error = 1:15,
    scaled_sigma_error = c(8:15, 1:7),
    scaled_log_sigma_error = c(15, 13, 11, 9, 7, 5, 3, 1, 2, 4, 6, 8, 10, 12, 14)
  )
  domain_audit <- tidyr::crossing(
    order = c(256L, 512L),
    candidate_id = candidates$candidate_id
  ) |>
    dplyr::left_join(candidates, by = "candidate_id") |>
    dplyr::mutate(U = 29L)
  calls <- tibble::tibble(a = numeric(), sigma_alpha = numeric())
  bindings <- list(
    goal002r_preflight_rule = function(order) order,
    .goal002r_preflight_optim = function(start, objective, lower, upper) {
      calls <<- dplyr::bind_rows(
        calls,
        tibble::tibble(a = start[[1L]], sigma_alpha = start[[2L]])
      )
      list(par = start, value = -1, convergence = 0L)
    },
    .goal002r_preflight_metric_at = function(
      a,
      sigma_alpha,
      order,
      rule,
      metric
    ) {
      a + sigma_alpha + match(metric, .goal002r_preflight_metrics)
    }
  )
  rlang::local_bindings(!!!bindings, .env = globalenv())
  goal002r_preflight_search_maxima(domain_audit)

  groups <- tibble::tibble(
    order = rep(c(256L, 512L), each = length(.goal002r_preflight_metrics)),
    metric = rep(.goal002r_preflight_metrics, times = 2L)
  )
  observed <- calls |>
    dplyr::mutate(
      group = ceiling(dplyr::row_number() / 12L),
      start_rank = (dplyr::row_number() - 1L) %% 12L + 1L
    ) |>
    dplyr::left_join(
      dplyr::mutate(groups, group = dplyr::row_number()),
      by = "group"
    ) |>
    dplyr::select(order, metric, a, sigma_alpha, start_rank)
  expected <- purrr::map2_dfr(groups$order, groups$metric, function(order, metric) {
    domain_audit |>
      dplyr::filter(.data$order == .env$order) |>
      dplyr::arrange(dplyr::desc(.data[[metric]]), .data$a, .data$sigma_alpha) |>
      dplyr::slice_head(n = 12L) |>
      dplyr::transmute(
        order,
        metric = metric,
        a,
        sigma_alpha,
        start_rank = dplyr::row_number()
      )
  })
  testthat::expect_equal(observed, expected)
})

testthat::test_that("one upstream oracle failure aborts bounded search", {
  domain_audit <- goal002r_preflight_test_domain_starts()
  failing <- domain_audit[1L, ]
  bindings <- list(
    goal002r_preflight_rule = function(order) order,
    goal002r_preflight_reference_pair = function(a, sigma_alpha) {
      if (a == failing$a && sigma_alpha == failing$sigma_alpha) {
        stop("Oracle mode could not be bracketed.", call. = FALSE)
      }
      goal002r_preflight_test_pair()
    },
    goal002r_preflight_gh = function(...) {
      c(log_m0 = -9, derivative_a = -1, derivative_sigma = 4)
    }
  )
  rlang::local_bindings(!!!bindings, .env = globalenv())
  testthat::expect_error(
    goal002r_preflight_search_maxima(domain_audit),
    paste0(
      "order 256.*target_error.*a=-7.*sigma_alpha=0.5.*",
      "Oracle mode could not be bracketed"
    ),
    class = "goal002r_preflight_evaluator_error"
  )
})

testthat::test_that("one non-finite candidate aborts bounded search", {
  domain_audit <- goal002r_preflight_test_domain_starts()
  failing <- domain_audit[1L, ]
  bindings <- list(
    goal002r_preflight_rule = function(order) order,
    goal002r_preflight_reference_pair = function(...) {
      goal002r_preflight_test_pair()
    },
    goal002r_preflight_gh = function(a, sigma_alpha, rule) {
      if (a == failing$a && sigma_alpha == failing$sigma_alpha) {
        return(c(
          log_m0 = Inf,
          derivative_a = -1,
          derivative_sigma = 4
        ))
      }
      c(log_m0 = -9, derivative_a = -1, derivative_sigma = 4)
    }
  )
  rlang::local_bindings(!!!bindings, .env = globalenv())
  testthat::expect_error(
    goal002r_preflight_search_maxima(domain_audit),
    "order 256.*target_error.*a=-7.*sigma_alpha=0.5.*[Nn]on-finite",
    class = "goal002r_preflight_evaluator_error"
  )
})

testthat::test_that("twelve ordinary optimiser failures block one metric", {
  calls <- 0L
  bindings <- list(
    goal002r_preflight_rule = function(order) order,
    .goal002r_preflight_optim = function(...) {
      calls <<- calls + 1L
      stop("optimiser infrastructure failed", call. = FALSE)
    }
  )
  rlang::local_bindings(!!!bindings, .env = globalenv())
  testthat::expect_error(
    goal002r_preflight_search_maxima(
      goal002r_preflight_test_domain_starts()
    ),
    "All 12 maxima searches failed for order 256 and target_error"
  )
  testthat::expect_identical(calls, 12L)
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

testthat::test_that("criteria apply exact full and headroom boundaries", {
  audit <- goal002r_preflight_test_audit()

  value_equal <- goal002r_preflight_criteria(
    audit,
    audit,
    goal002r_preflight_test_maxima(target_error = 5e-4)
  )
  testthat::expect_true(all(value_equal$full_pass))
  testthat::expect_false(any(value_equal$headroom_pass))

  gradient_equal <- goal002r_preflight_criteria(
    audit,
    audit,
    goal002r_preflight_test_maxima(scaled_a_error = 1e-2)
  )
  testthat::expect_false(any(gradient_equal$full_pass))

  rms_equal_audit <- goal002r_preflight_test_audit(
    scaled_a_error = 1e-3,
    scaled_sigma_error = 1e-3,
    scaled_log_sigma_error = 1e-3
  )
  rms_equal <- goal002r_preflight_criteria(
    rms_equal_audit,
    rms_equal_audit,
    goal002r_preflight_test_maxima(
      scaled_a_error = 1e-3,
      scaled_sigma_error = 1e-3,
      scaled_log_sigma_error = 1e-3
    )
  )
  testthat::expect_equal(rms_equal$rms_gradient, rep(1e-3, 2L))
  testthat::expect_false(any(rms_equal$full_pass))

  headroom_audit <- goal002r_preflight_test_audit(
    scaled_a_error = 5e-4,
    scaled_sigma_error = 5e-4,
    scaled_log_sigma_error = 5e-4
  )
  headroom_equal <- goal002r_preflight_criteria(
    headroom_audit,
    headroom_audit,
    goal002r_preflight_test_maxima(
      target_error = 2.5e-4,
      scaled_a_error = 5e-3,
      scaled_sigma_error = 5e-3,
      scaled_log_sigma_error = 5e-3
    )
  )
  testthat::expect_equal(
    headroom_equal$maximum_target,
    rep(2.5e-4, 2L)
  )
  testthat::expect_equal(
    headroom_equal$maximum_gradient,
    rep(5e-3, 2L)
  )
  testthat::expect_equal(
    headroom_equal$rms_gradient,
    rep(5e-4, 2L)
  )
  testthat::expect_true(all(headroom_equal$headroom_pass))
})

testthat::test_that("criteria include equality at every remaining full gate", {
  cases <- tibble::tribble(
    ~audit_column, ~criteria_column, ~threshold,
    "value_agreement", "maximum_value_agreement", 1e-8,
    "scaled_reference_a_uncertainty",
      "maximum_scaled_reference_uncertainty", 1e-4,
    "tail_relative_bound", "maximum_tail_relative_bound", 1e-14,
    "expansion_change", "maximum_expansion_change", 1e-9
  )
  for (index in seq_len(nrow(cases))) {
    audit <- goal002r_preflight_test_audit()
    audit[[cases$audit_column[[index]]]] <- cases$threshold[[index]]
    criteria <- goal002r_preflight_criteria(
      audit,
      audit,
      goal002r_preflight_test_maxima()
    )
    testthat::expect_equal(
      criteria[[cases$criteria_column[[index]]]],
      rep(cases$threshold[[index]], 2L)
    )
    testthat::expect_true(
      all(criteria$full_pass),
      info = cases$criteria_column[[index]]
    )
  }
})

testthat::test_that("criteria require exact finite order and metric keys", {
  audit <- goal002r_preflight_test_audit()
  maxima <- goal002r_preflight_test_maxima()
  malformed <- list(
    dplyr::bind_rows(maxima, maxima[1L, ]),
    maxima[-1L, ],
    dplyr::mutate(maxima, order = dplyr::if_else(
      dplyr::row_number() == 1L,
      128L,
      order
    )),
    dplyr::mutate(maxima, metric = dplyr::if_else(
      dplyr::row_number() == 1L,
      "wrong_metric",
      metric
    )),
    dplyr::mutate(maxima, observed = dplyr::if_else(
      dplyr::row_number() == 1L,
      Inf,
      observed
    ))
  )
  for (fixture in malformed) {
    testthat::expect_error(
      goal002r_preflight_criteria(audit, audit, fixture),
      "exactly one finite maximum per order and metric"
    )
  }
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
  special <- tibble::tribble(
    ~a, ~sigma_alpha, ~target_error, ~scaled_a_error,
    ~scaled_sigma_error, ~scaled_log_sigma_error,
    -6, 0.5, 100, 0, 0, 0,
    -4, 1, 0, 90, 0, 0,
    -2, 1.5, 0, 0, 80, 0,
     0, 2, 0, 0, 0, 70,
     2, 2.5, 60, 60, 60, 60
  )
  decoys <- tibble::tibble(
    a = 3:7,
    sigma_alpha = seq(3, 5, length.out = 5L),
    target_error = c(50, 40, 30, 20, 10),
    scaled_a_error = c(50, 40, 30, 20, 10),
    scaled_sigma_error = c(50, 40, 30, 20, 10),
    scaled_log_sigma_error = c(50, 40, 30, 20, 10)
  )
  candidates <- dplyr::bind_rows(special, decoys) |>
    dplyr::mutate(candidate_id = dplyr::row_number())
  audit <- tidyr::crossing(
    order = c(256L, 512L),
    candidate_id = candidates$candidate_id
  ) |>
    dplyr::left_join(candidates, by = "candidate_id") |>
    dplyr::mutate(dplyr::across(
      c(
        target_error,
        scaled_a_error,
        scaled_sigma_error,
        scaled_log_sigma_error
      ),
      ~ dplyr::if_else(order == 256L, .x, .x / 2)
    ))
  states <- .goal002r_preflight_derivative_states(audit, audit)
  testthat::expect_identical(nrow(states), 10L)
  testthat::expect_identical(nrow(dplyr::distinct(states)), 10L)
  testthat::expect_equal(
    dplyr::semi_join(anchors, states, by = names(anchors)),
    anchors
  )
  testthat::expect_equal(
    dplyr::semi_join(states, special, by = c("a", "sigma_alpha")),
    dplyr::select(special, a, sigma_alpha)
  )
  metric_columns <- c(
    "target_error", "scaled_a_error", "scaled_sigma_error",
    "scaled_log_sigma_error"
  )
  expected_worst <- dplyr::select(special, a, sigma_alpha)
  for (omitted in metric_columns) {
    remaining <- setdiff(metric_columns, omitted)
    mutated_worst <- candidates |>
      dplyr::mutate(score = do.call(pmax, unname(dplyr::select(
        candidates,
        dplyr::all_of(remaining)
      )))) |>
      dplyr::arrange(dplyr::desc(.data$score), .data$a, .data$sigma_alpha) |>
      dplyr::slice_head(n = 5L) |>
      dplyr::select(a, sigma_alpha)
    testthat::expect_false(
      setequal(
        paste(mutated_worst$a, mutated_worst$sigma_alpha),
        paste(expected_worst$a, expected_worst$sigma_alpha)
      ),
      info = omitted
    )
  }
})

testthat::test_that("preflight run assembles the locked result schema", {
  bindings <- goal002r_preflight_test_run_bindings()
  rlang::local_bindings(!!!bindings, .env = globalenv())
  result <- goal002r_preflight_run()
  testthat::expect_identical(names(result), c(
    "rule_integrity", "posterior_audit", "domain_audit", "maxima",
    "criteria", "decision"
  ))
  testthat::expect_identical(
    result$posterior_audit,
    tibble::tibble(source = "posterior")
  )
  testthat::expect_identical(
    result$domain_audit,
    tibble::tibble(source = "domain")
  )
  testthat::expect_identical(result$maxima, tibble::tibble(marker = "maxima"))
  testthat::expect_identical(
    result$criteria,
    tibble::tibble(marker = "criteria")
  )
  testthat::expect_identical(result$decision, "SELECT_256")
  testthat::expect_identical(nrow(result$rule_integrity), 42L)
})

testthat::test_that("locked rule and algebra integrity evidence validates", {
  rule_checks <- .goal002r_preflight_rule_integrity()
  algebra_checks <- .goal002r_preflight_algebra_integrity()
  testthat::expect_identical(nrow(rule_checks), 18L)
  testthat::expect_identical(nrow(algebra_checks), 4L)
  testthat::expect_true(all(rule_checks$passed))
  testthat::expect_true(all(algebra_checks$passed))
})

testthat::test_that("failed rule integrity stops before audit", {
  rule_checks <- goal002r_preflight_test_rule_checks()
  rule_checks$passed[1] <- FALSE
  bindings <- goal002r_preflight_test_run_bindings(rule_checks = rule_checks)
  bindings$goal002r_preflight_audit <- function(...) {
    stop("expensive audit was called", call. = FALSE)
  }
  rlang::local_bindings(!!!bindings, .env = globalenv())
  testthat::expect_error(
    goal002r_preflight_run(),
    "Preflight rule integrity checks failed"
  )
})

testthat::test_that("failed algebra integrity stops before audit", {
  algebra_checks <- goal002r_preflight_test_algebra_checks()
  algebra_checks$passed[1] <- FALSE
  bindings <- goal002r_preflight_test_run_bindings(
    algebra_checks = algebra_checks
  )
  bindings$goal002r_preflight_audit <- function(...) {
    stop("expensive audit was called", call. = FALSE)
  }
  rlang::local_bindings(!!!bindings, .env = globalenv())
  testthat::expect_error(
    goal002r_preflight_run(),
    "Preflight algebra integrity checks failed"
  )
})

testthat::test_that("missing rule integrity evidence stops before audit", {
  rule_checks <- goal002r_preflight_test_rule_checks()[-1L, ]
  bindings <- goal002r_preflight_test_run_bindings(rule_checks = rule_checks)
  bindings$goal002r_preflight_audit <- function(...) {
    stop("expensive audit was called", call. = FALSE)
  }
  rlang::local_bindings(!!!bindings, .env = globalenv())
  testthat::expect_error(
    goal002r_preflight_run(),
    "Preflight rule integrity checks failed"
  )
})

testthat::test_that("NA rule integrity evidence stops before audit", {
  rule_checks <- goal002r_preflight_test_rule_checks()
  rule_checks$passed[1] <- NA
  bindings <- goal002r_preflight_test_run_bindings(rule_checks = rule_checks)
  bindings$goal002r_preflight_audit <- function(...) {
    stop("expensive audit was called", call. = FALSE)
  }
  rlang::local_bindings(!!!bindings, .env = globalenv())
  testthat::expect_error(
    goal002r_preflight_run(),
    "Preflight rule integrity checks failed"
  )
})

testthat::test_that("NA rule labels stop before audit", {
  rule_checks <- goal002r_preflight_test_rule_checks()
  rule_checks$check[1] <- NA_character_
  bindings <- goal002r_preflight_test_run_bindings(rule_checks = rule_checks)
  bindings$goal002r_preflight_audit <- function(...) {
    stop("expensive audit was called", call. = FALSE)
  }
  rlang::local_bindings(!!!bindings, .env = globalenv())
  testthat::expect_error(
    goal002r_preflight_run(),
    "Preflight rule integrity checks failed"
  )
})

testthat::test_that("failed derivative integrity prevents selection", {
  bindings <- goal002r_preflight_test_run_bindings(
    derivative_passed = c(FALSE, rep(TRUE, 19L))
  )
  rlang::local_bindings(!!!bindings, .env = globalenv())
  testthat::expect_error(
    goal002r_preflight_run(),
    "Preflight derivative sanity checks failed"
  )
})

goal002r_preflight_result_fixture <- function(decision = "SELECT_256") {
  list(
    rule_integrity = tibble::tibble(check = "rule", passed = TRUE),
    posterior_audit = tibble::tibble(
      source = "posterior",
      order = c(256L, 512L)
    ),
    domain_audit = tibble::tibble(
      source = "domain",
      order = c(256L, 512L)
    ),
    maxima = tibble::tibble(
      order = c(256L, 512L),
      metric = "target_error",
      observed = 0
    ),
    criteria = tibble::tibble(
      order = c(256L, 512L),
      full_pass = TRUE,
      headroom_pass = c(TRUE, FALSE)
    ),
    decision = decision
  )
}

testthat::test_that("preflight writer emits only the five approved files", {
  fixture <- goal002r_preflight_result_fixture(decision = "SELECT_256")
  output_dir <- tempfile("goal002r-preflight-")
  paths <- goal002r_preflight_write(fixture, output_dir)
  testthat::expect_setequal(
    basename(paths),
    c(
      "rule-integrity.csv",
      "posterior-state-audit.csv",
      "domain-audit.csv",
      "numerical-maxima.csv",
      "decision.txt"
    )
  )
  testthat::expect_true(all(file.exists(paths)))
  decision_text <- paste(readLines(paths[["decision"]]), collapse = "\n")
  testthat::expect_match(decision_text, "SELECT_256")
})

testthat::test_that("preflight writer refuses an existing evidence file", {
  fixture <- goal002r_preflight_result_fixture()
  output_dir <- tempfile("goal002r-preflight-")
  dir.create(output_dir)
  decision_file <- file.path(output_dir, "decision.txt")
  writeLines("existing evidence", decision_file)

  testthat::expect_error(
    goal002r_preflight_write(fixture, output_dir),
    "already contains approved evidence"
  )
  testthat::expect_identical(readLines(decision_file), "existing evidence")
})
