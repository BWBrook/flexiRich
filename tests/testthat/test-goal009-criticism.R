testthat::test_that("Goal009 PPC preserves canonical order, effort NA, and shared membership", {
  data <- .goal003_baseline_fixture()
  labels <- tibble::tibble(
    species_id = data$candidate_ids,
    taxon_class = rep(c("Mammalia", "Aves"), length.out = length(data$candidate_ids)),
    encounter_class = rep(c("routine", "occasional"), length.out = length(data$candidate_ids))
  )
  labels <- labels[rev(seq_len(nrow(labels))), , drop = FALSE]
  D <- 240L
  C <- length(data$candidate_ids)
  J <- length(data$camera_ids)
  q <- matrix(0.5, D, C)
  q[, data$stan_data$detected_ever == 1L] <- 1
  alpha <- matrix(-2, D, C)
  camera <- matrix(0, D, J)
  out <- goal009_ppc(data, q, alpha, camera, labels, seed = 901L)
  testthat::expect_identical(
    names(out), c("summary", "draw_statistics", "species_station",
                  "species_counts", "species_block", "metadata")
  )
  testthat::expect_identical(
    names(out$summary),
    c("statistic", "observed", "q05", "q50", "q95", "tail_ge", "mcse")
  )
  testthat::expect_identical(
    out$species_station$species_id,
    rep(data$candidate_ids, each = length(data$camera_ids))
  )
  testthat::expect_identical(out$metadata$n_draws, D)
  testthat::expect_true(all(out$species_station$q95 >= out$species_station$q05))
  testthat::expect_true(any(data$observed$active_days == 0L & is.na(data$observed$detected)))
  withr::with_seed(99L, {
    before <- .Random.seed
    other_kind <- goal009_ppc(data, q, alpha, camera, labels, seed = 901L)
    testthat::expect_identical(.Random.seed, before)
    testthat::expect_identical(out, other_kind)
  }, .rng_kind = "L'Ecuyer-CMRG")
})

testthat::test_that("Goal009 near-certain predictions and deterministic draw selection are reproducible", {
  data <- .goal003_baseline_fixture()
  labels <- tibble::tibble(
    species_id = data$candidate_ids,
    taxon_class = rep(c("Mammalia", "Aves"), length.out = length(data$candidate_ids)),
    encounter_class = rep("routine", length(data$candidate_ids))
  )
  D <- 1205L
  q <- matrix(1, D, length(data$candidate_ids))
  alpha <- matrix(40, D, length(data$candidate_ids))
  camera <- matrix(0, D, length(data$camera_ids))
  first <- goal009_ppc(data, q, alpha, camera, labels, seed = 902L, max_draws = 1000L)
  second <- goal009_ppc(data, q, alpha, camera, labels, seed = 902L, max_draws = 1000L)
  testthat::expect_identical(first, second)
  testthat::expect_identical(first$metadata$draw_indices, as.integer(floor(seq(0, D - 1L, length.out = 1000L))) + 1L)
  active <- data$observed$active_days[seq_len(length(data$camera_ids) * length(data$occasion_ids))]
  active <- matrix(active, nrow = length(data$camera_ids), byrow = TRUE)
  expected_station <- rep(rowSums(active > 0L), times = length(data$candidate_ids))
  testthat::expect_true(all(first$species_station$q05 == expected_station))
  testthat::expect_true(all(first$species_station$q95 == expected_station))
})

testthat::test_that("shared membership is one draw across every operational cell", {
  data <- .goal003_baseline_fixture()
  labels <- tibble::tibble(
    species_id = data$candidate_ids,
    taxon_class = rep("Mammalia", length(data$candidate_ids)),
    encounter_class = rep("routine", length(data$candidate_ids))
  )
  D <- 120L
  q <- matrix(0.5, D, length(data$candidate_ids))
  q[, data$stan_data$detected_ever == 1L] <- 1
  out <- goal009_ppc(
    data, q,
    matrix(40, D, length(data$candidate_ids)),
    matrix(0, D, length(data$camera_ids)), labels, seed = 903L
  )
  unknown <- data$stan_data$detected_ever == 0L
  operational_cells <- sum(data$observed$active_days[seq_len(
    length(data$camera_ids) * length(data$occasion_ids)
  )] > 0L)
  testthat::expect_true(all(unlist(out$species_counts[unknown, "q05"]) >= 0))
  testthat::expect_true(all(unlist(out$species_counts[unknown, "q95"]) <= operational_cells))
  draw_columns <- paste0(
    "species_total_", make.names(data$candidate_ids[unknown])
  )
  testthat::expect_true(all(as.matrix(out$draw_statistics[, draw_columns]) %in%
    c(0, operational_cells)))
  testthat::expect_true(all(unlist(out$species_counts[unknown, "observed"]) == 0))
})

testthat::test_that("loaded posterior draw classes cannot change effort allocation", {
  data <- .goal003_baseline_fixture()
  labels <- tibble::tibble(
    species_id = data$candidate_ids,
    taxon_class = rep("Mammalia", length(data$candidate_ids)),
    encounter_class = rep("routine", length(data$candidate_ids))
  )
  D <- 30L
  C <- length(data$candidate_ids)
  J <- length(data$camera_ids)
  q <- matrix(0.4, D, C)
  q[, data$stan_data$detected_ever == 1L] <- 1
  alpha <- matrix(rep(seq(-5, -1, length.out = C), each = D), D, C)
  camera <- matrix(rep(c(-0.7, 0.7), each = D), D, J)
  # Loading posterior is essential: deserializing alone does not register [.
  wrapped <- lapply(list(q, alpha, camera), posterior::as_draws_matrix)
  testthat::expect_equal(dim(wrapped[[2]][1, ]), c(1L, C))
  expected <- goal009_ppc(data, q, alpha, camera, labels, 904L, 20L)
  testthat::expect_no_warning(actual <- goal009_ppc(
    data, wrapped[[1]], wrapped[[2]], wrapped[[3]], labels, 904L, 20L
  ))
  testthat::expect_identical(actual, expected)
  testthat::expect_identical(
    .goal003_mean_poisson_binomial(wrapped[[1]]),
    .goal003_mean_poisson_binomial(q)
  )
})

testthat::test_that("Goal009 sequential bridge detects membership reinitialisation", {
  bridge <- goal009_sequential_bridge()
  testthat::expect_true(bridge$normalized_same_grid)
  testthat::expect_lte(bridge$max_abs_difference, 1e-12)
  testthat::expect_gt(bridge$max_wrong_abs_difference, 0)
  testthat::expect_true(all(bridge$grid$q_after_period2 >= 0 & bridge$grid$q_after_period2 <= 1))
  testthat::expect_equal(bridge$error_fields[["known_detection_min_membership_probability"]], 1)
  testthat::expect_true(bridge$reverse_period_order_agreement)
  mass <- tapply(bridge$grid$joint_posterior_mass, bridge$grid$case_id, sum)
  testthat::expect_equal(as.numeric(mass), rep(1, 3))
  testthat::expect_equal(bridge$membership_probabilities$q_period2,
                        bridge$membership_probabilities$joint_membership_probability,
                        tolerance = 1e-12)
  testthat::expect_equal(bridge$membership_probabilities$q_reverse_final,
                        bridge$membership_probabilities$joint_membership_probability,
                        tolerance = 1e-12)
})
