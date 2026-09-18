.goal010_bridge_fake_spatial <- function() {
  source <- .goal003_baseline_fixture()
  data <- prepare_goal010_spatial_data(source)
  C <- length(data$candidate_ids)
  J <- length(data$camera_ids)
  D <- 7L
  alpha <- matrix(rep(log(0.02), D * C), nrow = D, ncol = C)
  camera_effect <- matrix(rep(c(-0.1, 0.1), D), nrow = D, ncol = J, byrow = TRUE)
  interaction <- array(0, dim = c(D, C, J))
  for (d in seq_len(D)) {
    for (i in seq_len(C)) {
      interaction[d, i, ] <- c(-0.04, 0.04)
    }
  }
  station_log_rate <- array(NA_real_, dim = c(D, C, J))
  q_member <- matrix(NA_real_, nrow = D, ncol = C)
  member_ll <- matrix(NA_real_, nrow = D, ncol = C)
  expected_richness <- numeric(D)
  omega <- rep(0.35, D)
  for (d in seq_len(D)) {
    station_log_rate[d, , ] <- outer(alpha[d, ], camera_effect[d, ], "+") +
      interaction[d, , ]
    reference <- goal010_spatial_conditionals(
      data,
      omega[d],
      alpha[d, ],
      camera_effect[d, ],
      interaction[d, , ]
    )
    member_ll[d, ] <- unname(reference$member_ll)
    q_member[d, ] <- unname(reference$q_member)
    expected_richness[d] <- reference$expected_richness
  }
  core_names <- c(
    "omega",
    sprintf("member_ll[%d]", seq_len(C)),
    sprintf("q_member[%d]", seq_len(C)),
    "expected_richness"
  )
  core <- matrix(NA_real_, nrow = D, ncol = length(core_names))
  colnames(core) <- core_names
  core[, "omega"] <- omega
  core[, sprintf("member_ll[%d]", seq_len(C))] <- member_ll
  core[, sprintf("q_member[%d]", seq_len(C))] <- q_member
  core[, "expected_richness"] <- expected_richness
  fake_fit <- list(draws = function(...) core)
  draws <- list(
    alpha = alpha,
    camera_effect = camera_effect,
    interaction = interaction,
    station_log_rate = station_log_rate
  )
  list(fit = fake_fit, data = data, draws = draws)
}

testthat::test_that("Goal010 bridge passes reference-consistent spatial draws", {
  fake <- .goal010_bridge_fake_spatial()
  result <- goal010_fit_bridge(fake$fit, fake$data, fake$draws, max_draws = 4L)
  testthat::expect_identical(
    names(result),
    c(
      "draw_index", "member_ll_error", "q_error",
      "expected_richness_error", "camera_center_error",
      "interaction_center_error", "station_log_rate_error"
    )
  )
  testthat::expect_equal(nrow(result), 4L)
  testthat::expect_equal(result$draw_index, c(1L, 3L, 5L, 7L))
  testthat::expect_lt(max(result$member_ll_error), 1e-12)
  testthat::expect_lt(max(result$q_error), 1e-12)
  testthat::expect_lt(max(result$expected_richness_error), 1e-12)
  testthat::expect_lt(max(result$interaction_center_error), 1e-12)
  testthat::expect_lt(max(result$station_log_rate_error), 1e-12)
})

testthat::test_that("Goal010 bridge catches transformed quantity and rate corruption", {
  fake <- .goal010_bridge_fake_spatial()
  corrupted <- fake$fit
  corrupted$draws <- function(...) {
    result <- fake$fit$draws()
    result[1L, "member_ll[1]"] <- result[1L, "member_ll[1]"] + 1e-4
    result
  }
  testthat::expect_error(
    goal010_fit_bridge(corrupted, fake$data, fake$draws, max_draws = 4L),
    "member_ll_error",
    fixed = TRUE
  )
  corrupted <- fake$fit
  corrupted$draws <- function(...) {
    result <- fake$fit$draws()
    result
  }
  broken_draws <- fake$draws
  broken_draws$station_log_rate[1L, 1L, 1L] <-
    broken_draws$station_log_rate[1L, 1L, 1L] + 1e-4
  testthat::expect_error(
    goal010_fit_bridge(corrupted, fake$data, broken_draws, max_draws = 4L),
    "station_log_rate_error",
    fixed = TRUE
  )
})

testthat::test_that("Goal010 bridge supports the prepared Goal003 baseline", {
  source <- .goal003_baseline_fixture()
  data <- prepare_goal003_flexirich_data(source)
  C <- length(data$candidate_ids)
  J <- length(data$camera_ids)
  D <- 3L
  alpha <- matrix(log(0.02), nrow = D, ncol = C)
  camera_effect <- matrix(rep(c(-0.1, 0.1), D), nrow = D, ncol = J, byrow = TRUE)
  omega <- rep(0.35, D)
  core_names <- c(
    "omega", sprintf("member_ll[%d]", seq_len(C)),
    sprintf("q_member[%d]", seq_len(C)), "expected_richness"
  )
  core <- matrix(NA_real_, nrow = D, ncol = length(core_names))
  colnames(core) <- core_names
  core[, "omega"] <- omega
  for (d in seq_len(D)) {
    reference <- goal003_flexirich_conditionals(
      data, omega[d], alpha[d, ], camera_effect[d, ]
    )
    core[d, sprintf("member_ll[%d]", seq_len(C))] <- reference$member_ll
    core[d, sprintf("q_member[%d]", seq_len(C))] <- reference$q_member
    core[d, "expected_richness"] <- reference$expected_richness
  }
  fit <- list(draws = function(...) core)
  result <- goal010_fit_bridge(
    fit,
    data,
    list(alpha = alpha, camera_effect = camera_effect),
    max_draws = 20L
  )
  testthat::expect_equal(nrow(result), D)
  testthat::expect_equal(result$interaction_center_error, rep(0, D))
  testthat::expect_equal(result$station_log_rate_error, rep(0, D))
})

testthat::test_that("Goal010 bridge rejects malformed draw contracts", {
  fake <- .goal010_bridge_fake_spatial()
  missing_field <- fake$draws
  missing_field$station_log_rate <- NULL
  testthat::expect_error(
    goal010_fit_bridge(fake$fit, fake$data, missing_field),
    "draws is missing: station_log_rate",
    fixed = TRUE
  )
  broken <- fake$draws
  broken$interaction <- broken$interaction[, , -1L, drop = FALSE]
  testthat::expect_error(
    goal010_fit_bridge(fake$fit, fake$data, broken),
    "draws\\$interaction",
    fixed = FALSE
  )
  testthat::expect_error(
    goal010_fit_bridge(fake$fit, fake$data, fake$draws, max_draws = 0L),
    "max_draws",
    fixed = TRUE
  )
})
