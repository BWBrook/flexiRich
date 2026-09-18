testthat::test_that("Goal010 interaction basis is normalized and safe", {
  Q <- goal010_interaction_basis(4L)
  testthat::expect_equal(dim(Q), c(4L, 3L))
  testthat::expect_equal(crossprod(Q), 4 / 3 * diag(3L), tolerance = 1e-14)
  testthat::expect_equal(unname(colSums(Q)), rep(0, 3L), tolerance = 1e-14)
  testthat::expect_equal(unname(rowSums(Q^2)), rep(1, 4L), tolerance = 1e-14)
  Q_one <- goal010_interaction_basis(1L)
  testthat::expect_equal(dim(Q_one), c(1L, 0L))
  testthat::expect_equal(length(Q_one), 0L)
})

testthat::test_that("Goal010 preparation preserves the candidate pool and adapter contract", {
  source <- .goal003_baseline_fixture()
  data <- prepare_goal010_spatial_data(source)
  testthat::expect_identical(
    names(data),
    c(
      "candidate_ids", "camera_ids", "detected_ever", "stan_data",
      "source_data", "prior_id", "interaction_scale", "data_hash"
    )
  )
  testthat::expect_identical(data$candidate_ids, source$candidate_ids)
  testthat::expect_identical(data$camera_ids, source$camera_ids)
  testthat::expect_identical(data$stan_data$C, source$stan_data$C)
  testthat::expect_identical(data$stan_data$J, source$stan_data$J)
  testthat::expect_identical(data$stan_data$Q, source$stan_data$Q)
  testthat::expect_equal(data$interaction_scale, 0.5)
  testthat::expect_match(data$data_hash, "^[0-9a-f]{64}$")
  testthat::expect_false(
    identical(
      data$data_hash,
      prepare_goal010_spatial_data(source, interaction_scale = 1)$data_hash
    )
  )
})

testthat::test_that("zero interaction gives the Goal003 likelihood and membership", {
  data <- prepare_goal010_spatial_data(.goal003_baseline_fixture())
  alpha <- seq(log(0.005), log(0.08), length.out = length(data$candidate_ids))
  camera_effect <- c(-0.2, 0.2)
  interaction <- matrix(0, nrow = length(data$candidate_ids), ncol = 2L)
  spatial <- goal010_spatial_conditionals(
    data, 0.37, alpha, camera_effect, interaction
  )
  baseline <- goal003_flexirich_conditionals(
    prepare_goal003_flexirich_data(data$source_data),
    0.37,
    alpha,
    camera_effect
  )
  testthat::expect_equal(spatial$member_ll, baseline$member_ll, tolerance = 1e-14)
  testthat::expect_equal(spatial$q_member, baseline$q_member, tolerance = 1e-14)
  testthat::expect_equal(
    spatial$expected_richness,
    baseline$expected_richness,
    tolerance = 1e-14
  )
})

testthat::test_that("nonzero interaction uses grouped cells and canonical membership", {
  source <- .goal003_baseline_fixture()
  data <- prepare_goal010_spatial_data(source)
  C <- length(data$candidate_ids)
  J <- length(data$camera_ids)
  alpha <- rep(log(0.02), C)
  camera_effect <- c(-0.15, 0.15)
  interaction <- matrix(c(-0.1, 0.1), nrow = C, ncol = J, byrow = TRUE)
  out <- goal010_spatial_conditionals(
    data, 0.25, alpha, camera_effect, interaction
  )
  expected_ll <- numeric(C)
  for (g in seq_len(nrow(source$grouped))) {
    i <- match(source$grouped$species_id[[g]], source$candidate_ids)
    j <- match(source$grouped$camera_id[[g]], source$camera_ids)
    log_rate <- alpha[[i]] + camera_effect[[j]] + interaction[i, j]
    y <- source$grouped$n_detected[[g]]
    n0 <- source$grouped$n_trials[[g]] - y
    if (y > 0L) {
      expected_ll[[i]] <- expected_ll[[i]] + y *
        log_detect_probability(log_rate, source$grouped$active_days[[g]])
    }
    if (n0 > 0L) {
      expected_ll[[i]] <- expected_ll[[i]] + n0 *
        log_nondetect_probability(log_rate, source$grouped$active_days[[g]])
    }
  }
  testthat::expect_equal(unname(out$member_ll), expected_ll, tolerance = 1e-14)
  testthat::expect_identical(unname(out$q_member[source$detected_ever == 1L]),
                             rep(1, sum(source$detected_ever == 1L)))
  testthat::expect_true(all(is.finite(out$q_member)))
})

testthat::test_that("Goal010 conditionals reject malformed dimensions and centering", {
  data <- prepare_goal010_spatial_data(.goal003_baseline_fixture())
  C <- length(data$candidate_ids)
  interaction <- matrix(0, nrow = C, ncol = 2L)
  args <- list(
    data = data,
    omega = 0.3,
    alpha = rep(log(0.02), C),
    camera_effect = c(-0.1, 0.1),
    interaction = interaction
  )
  broken <- args
  broken$interaction <- matrix(0, nrow = C - 1L, ncol = 2L)
  testthat::expect_error(
    do.call(goal010_spatial_conditionals, broken),
    "row-centered",
    fixed = TRUE
  )
  broken <- args
  broken$interaction[1L, 1L] <- 0.01
  testthat::expect_error(
    do.call(goal010_spatial_conditionals, broken),
    "row-centered",
    fixed = TRUE
  )
})

testthat::test_that("Goal010 draw extraction respects explicit Stan matrix indices", {
  source <- .goal003_baseline_fixture()
  data <- prepare_goal010_spatial_data(source)
  C <- length(data$candidate_ids)
  J <- length(data$camera_ids)
  D <- 2L
  names <- c(
    unlist(list(
      sprintf("q_member[%d]", seq_len(C)),
      sprintf("alpha[%d]", seq_len(C)),
      sprintf("camera_effect[%d]", seq_len(J))
    ), use.names = FALSE),
    unlist(lapply(seq_len(J), function(j) {
      sprintf("interaction[%d,%d]", seq_len(C), j)
    }), use.names = FALSE),
    unlist(lapply(seq_len(J), function(j) {
      sprintf("station_log_rate[%d,%d]", seq_len(C), j)
    }), use.names = FALSE)
  )
  synthetic <- matrix(seq_len(D * length(names)), nrow = D, ncol = length(names))
  colnames(synthetic) <- names
  synthetic[, grepl("^q_member", names)] <- 0.5
  fake_fit <- list(draws = function(...) synthetic)
  out <- goal010_extract_draws(fake_fit, data)
  wrapped_fit <- list(draws = function(...) posterior::as_draws_matrix(synthetic))
  wrapped <- goal010_extract_draws(wrapped_fit, data)
  testthat::expect_identical(wrapped, out)
  testthat::expect_identical(class(wrapped$alpha), c("matrix", "array"))
  testthat::expect_identical(class(wrapped$q_member), c("matrix", "array"))
  testthat::expect_true(is.matrix(out$alpha))
  testthat::expect_true(is.array(out$interaction))
  testthat::expect_equal(out$interaction[1, 1, 1], unname(synthetic[1, "interaction[1,1]"]))
  testthat::expect_equal(out$interaction[1, 1, 2], unname(synthetic[1, "interaction[1,2]"]))
  testthat::expect_equal(out$interaction[1, 2, 1], unname(synthetic[1, "interaction[2,1]"]))
  testthat::expect_equal(out$alpha[1, 1], unname(synthetic[1, "alpha[1]"]))
})

testthat::test_that("Goal010 extraction and basis are safe for one camera", {
  Q <- goal010_interaction_basis(1L)
  testthat::expect_equal(dim(Q), c(1L, 0L))
  testthat::expect_silent(goal010_interaction_basis(1L))
  root <- if (dir.exists("R")) "." else file.path("..", "..")
  text <- paste(
    readLines(file.path(root, "stan", "goal010_spatial.stan"), warn = FALSE),
    collapse = "\n"
  )
  testthat::expect_match(text, "if \\(J == 1\\)")
  testthat::expect_match(text, "sigma_interaction")
})

testthat::test_that("Goal010 monitoring contract exposes the interaction fields", {
  data <- prepare_goal010_spatial_data(.goal003_baseline_fixture())
  testthat::expect_identical(
    goal010_monitored_variables(data),
    c(
      "omega", "mu_alpha", "sigma_alpha", "sigma_camera",
      "sigma_interaction", "expected_richness", "alpha", "camera_effect",
      "interaction", "station_log_rate"
    )
  )
})
