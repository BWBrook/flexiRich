.goal010_labels <- function(data) {
  tibble::tibble(
    species_id = data$candidate_ids,
    taxon_class = rep(c("Mammalia", "Aves"), length.out = length(data$candidate_ids)),
    encounter_class = rep("routine", length(data$candidate_ids))
  )
}

.goal010_inputs <- function(data, D = 32L, alpha = -4) {
  C <- length(data$candidate_ids)
  J <- length(data$camera_ids)
  q <- matrix(1, nrow = D, ncol = C)
  list(
    q = q,
    alpha = matrix(alpha, nrow = D, ncol = C),
    camera = matrix(0, nrow = D, ncol = J),
    labels = .goal010_labels(data)
  )
}

testthat::test_that("Goal010 thinning preserves joint posterior draw identities", {
  data <- .goal003_baseline_fixture()
  x <- .goal010_inputs(data, D = 7L)
  C <- ncol(x$q); J <- ncol(x$camera)
  x$alpha <- matrix(rep(seq(-8, -2, length.out = 7L), C), nrow = 7L)
  u <- array(0, c(7L, C, J))
  u[4L, , 1L] <- 8
  u[4L, , 2L] <- -8
  selected <- c(1L, 4L, 7L)
  automatic <- goal009_ppc(data, x$q, x$alpha, x$camera, x$labels,
    1007L, max_draws = 3L, interaction_draws = u)
  manual <- goal009_ppc(data, x$q[selected, , drop = FALSE],
    x$alpha[selected, , drop = FALSE], x$camera[selected, , drop = FALSE],
    x$labels, 1007L, max_draws = 3L,
    interaction_draws = u[selected, , , drop = FALSE])
  manual$draw_statistics$draw_index <- selected
  fields <- setdiff(names(automatic), "metadata")
  testthat::expect_identical(automatic[fields], manual[fields])
})

testthat::test_that("Goal010 zero interactions preserve Goal009 draws and summaries", {
  data <- .goal003_baseline_fixture()
  inputs <- .goal010_inputs(data, D = 32L)
  D <- nrow(inputs$q)
  zero <- array(0, dim = c(D, length(data$candidate_ids), length(data$camera_ids)))
  baseline <- do.call(
    goal009_ppc,
    c(list(data, inputs$q, inputs$alpha, inputs$camera, inputs$labels, 1001L),
      list(max_draws = 20L))
  )
  with_interaction <- do.call(
    goal009_ppc,
    c(list(data, inputs$q, inputs$alpha, inputs$camera, inputs$labels, 1001L),
      list(max_draws = 20L, interaction_draws = zero))
  )
  scientific <- setdiff(names(baseline), "metadata")
  testthat::expect_identical(baseline[scientific], with_interaction[scientific])
  testthat::expect_true("interaction" %in% names(with_interaction$metadata))
})

testthat::test_that("Goal010 interactions create opposite species-station patterns", {
  data <- .goal003_baseline_fixture()
  inputs <- .goal010_inputs(data, D = 48L, alpha = -3)
  C <- length(data$candidate_ids)
  J <- length(data$camera_ids)
  interaction <- array(0, dim = c(nrow(inputs$q), C, J))
  for (d in seq_len(dim(interaction)[1L])) {
    for (i in seq_len(C)) {
      interaction[d, i, ] <- if (i %% 2L == 1L) c(4, -4) else c(-4, 4)
    }
  }
  out <- goal009_ppc(
    data, inputs$q, inputs$alpha, inputs$camera, inputs$labels,
    seed = 1002L, max_draws = 48L, interaction_draws = interaction
  )
  first <- out$species_station[out$species_station$species_id == data$candidate_ids[[1L]], ]
  second <- out$species_station[out$species_station$species_id == data$candidate_ids[[2L]], ]
  testthat::expect_gt(first$q50[first$camera_id == data$camera_ids[[1L]]],
                      first$q50[first$camera_id == data$camera_ids[[2L]]])
  testthat::expect_gt(second$q50[second$camera_id == data$camera_ids[[2L]]],
                      second$q50[second$camera_id == data$camera_ids[[1L]]])
})

testthat::test_that("Goal010 interactions persist across every week", {
  data <- .goal003_baseline_fixture()
  inputs <- .goal010_inputs(data, D = 1L, alpha = -10)
  C <- length(data$candidate_ids)
  J <- length(data$camera_ids)
  interaction <- array(0, dim = c(1L, C, J))
  for (i in seq_len(C)) {
    interaction[1L, i, ] <- if (i %% 2L == 1L) c(20, -20) else c(-20, 20)
  }
  out <- goal009_ppc(
    data, inputs$q, inputs$alpha, inputs$camera, inputs$labels,
    seed = 1003L, max_draws = 1L, interaction_draws = interaction
  )
  first <- out$species_station[out$species_station$species_id == data$candidate_ids[[1L]], ]
  second <- out$species_station[out$species_station$species_id == data$candidate_ids[[2L]], ]
  active <- data$observed$active_days[seq_len(J * length(data$occasion_ids))]
  active <- matrix(active, nrow = J, byrow = TRUE)
  testthat::expect_equal(first$q50[first$camera_id == data$camera_ids[[1L]]],
                         sum(active[1L, ] > 0L))
  testthat::expect_equal(first$q50[first$camera_id == data$camera_ids[[2L]]], 0)
  testthat::expect_equal(second$q50[second$camera_id == data$camera_ids[[2L]]],
                         sum(active[2L, ] > 0L))
  testthat::expect_equal(second$q50[second$camera_id == data$camera_ids[[1L]]], 0)
})

testthat::test_that("Goal010 interaction arrays require finite centered D x C x J input", {
  data <- .goal003_baseline_fixture()
  inputs <- .goal010_inputs(data, D = 4L)
  D <- nrow(inputs$q)
  C <- length(data$candidate_ids)
  J <- length(data$camera_ids)
  valid <- array(0, dim = c(D, C, J))
  call <- function(x) goal009_ppc(
    data, inputs$q, inputs$alpha, inputs$camera, inputs$labels,
    seed = 1004L, max_draws = 2L, interaction_draws = x
  )
  testthat::expect_no_error(call(valid))
  testthat::expect_error(call(array(0, dim = c(D, C, J - 1L))), "interaction_draws")
  nonfinite <- valid
  nonfinite[1L] <- Inf
  testthat::expect_error(call(nonfinite), "interaction_draws")
  noncentered <- valid
  noncentered[1L, 1L, 1L] <- 0.1
  testthat::expect_error(call(noncentered), "interaction_draws")
})

testthat::test_that("Goal010 singleton draw arrays and loaded posterior inputs are stable", {
  data <- .goal003_baseline_fixture()
  inputs <- .goal010_inputs(data, D = 1L)
  interaction <- array(0, dim = c(1L, length(data$candidate_ids), length(data$camera_ids)))
  testthat::expect_no_warning(single <- goal009_ppc(
    data, inputs$q, inputs$alpha, inputs$camera, inputs$labels,
    seed = 1005L, max_draws = 1L, interaction_draws = interaction
  ))
  testthat::expect_identical(single$metadata$n_draws, 1L)
  D <- 8L
  loaded <- .goal010_inputs(data, D = D)
  baseline <- goal009_ppc(
    data, loaded$q, loaded$alpha, loaded$camera, loaded$labels,
    seed = 1006L, max_draws = D
  )
  wrapped <- lapply(list(loaded$q, loaded$alpha, loaded$camera), posterior::as_draws_matrix)
  restored <- goal009_ppc(
    data, wrapped[[1L]], wrapped[[2L]], wrapped[[3L]], loaded$labels,
    seed = 1006L, max_draws = D
  )
  testthat::expect_identical(restored, baseline)
})
