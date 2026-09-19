.goal011_test_fixture <- function() {
  D <- 3L
  C <- 4L
  J <- 2L
  candidate_ids <- paste0("s", seq_len(C))
  camera_ids <- paste0("j", seq_len(J))
  q <- matrix(c(
    1, .2, .6, .8,
    1, .4, .5, .7,
    1, .3, .9, .1
  ), D, C, byrow = TRUE)
  alpha <- matrix(c(
    -2, -1.5, -1, -2.5,
    -1.8, -1.2, -.8, -2.2,
    -2.1, -1.1, -1.3, -1.7
  ), D, C, byrow = TRUE)
  camera_effect <- matrix(c(-.2, .2, -.1, .1, -.3, .3), D, J, byrow = TRUE)
  interaction <- array(0, dim = c(D, C, J))
  interaction[1, 2, ] <- c(.4, -.4)
  interaction[2, 3, ] <- c(-.2, .2)
  interaction[3, 4, ] <- c(.5, -.5)
  labels <- data.frame(
    species_id = candidate_ids,
    taxon_class = c("Aves", "Mammalia", "Aves", "Mammalia"),
    encounter_class = c("routine", "occasional", "routine", "occasional"),
    stringsAsFactors = FALSE
  )
  future_effort <- expand.grid(
    camera_id = camera_ids, future_week = seq_len(4L),
    stringsAsFactors = FALSE
  )
  future_effort$active_days <- c(7, 0, 5, 7, 0, 6, 7, 2)
  list(
    draws = list(
      q_member = q, alpha = alpha, camera_effect = camera_effect,
      interaction = interaction, candidate_ids = candidate_ids,
      camera_ids = camera_ids
    ),
    detected_ever = c(1L, 0L, 0L, 0L),
    future_effort = future_effort,
    labels = labels,
    horizons = c(1L, 2L, 4L)
  )
}

.goal011_test_brute_pmf <- function(probabilities) {
  K <- ncol(probabilities)
  states <- expand.grid(rep(list(c(FALSE, TRUE)), K))
  state_prob <- apply(states, 1L, function(state) {
    prod(ifelse(state, probabilities[1L, ], 1 - probabilities[1L, ]))
  })
  counts <- rowSums(states)
  out <- numeric(K + 1L)
  out[seq_len(K + 1L)] <- vapply(0:K, function(k) sum(state_prob[counts == k]), numeric(1))
  if (nrow(probabilities) > 1L) {
    for (d in 2:nrow(probabilities)) {
      state_prob <- apply(states, 1L, function(state) {
        prod(ifelse(state, probabilities[d, ], 1 - probabilities[d, ]))
      })
      out <- out + vapply(0:K, function(k) sum(state_prob[counts == k]), numeric(1))
    }
  }
  out / nrow(probabilities)
}

testthat::test_that("Goal011 count PMFs integrate posterior draws and match enumeration", {
  f <- .goal011_test_fixture()
  out <- goal011_forecast(
    f$draws, f$detected_ever, f$future_effort, f$horizons, f$labels
  )
  unseen <- !as.logical(f$detected_ever)
  probs <- exp(out$per_draw$log_detection[, unseen, 3L])
  expected <- .goal011_test_brute_pmf(probs)
  actual <- out$count_pmfs[which(
    out$count_pmfs$target == "totaldiscovery" & out$count_pmfs$horizon == 4L
  ), ]
  testthat::expect_equal(actual$probability, expected, tolerance = 1e-12)
  testthat::expect_equal(sum(actual$probability), 1, tolerance = 1e-12)
  testthat::expect_equal(sum(out$count_pmfs$probability),
                         sum(out$count_pmfs$probability), tolerance = 0)
})

testthat::test_that("known membership, zero effort, and extreme hazards are bounded", {
  f <- .goal011_test_fixture()
  f$future_effort$active_days[] <- 0
  out <- goal011_forecast(f$draws, f$detected_ever, f$future_effort,
                          f$horizons, f$labels)
  testthat::expect_true(all(out$species_probabilities$detection_probability == 0))
  testthat::expect_true(all(out$species_probabilities$discovery_probability == 0))
  zero <- out$count_pmfs$target == "totaldiscovery"
  testthat::expect_true(all(out$count_pmfs$probability[zero & out$count_pmfs$count == 0] == 1))
  testthat::expect_true(all(out$count_pmfs$log_probability[zero & out$count_pmfs$count > 0] == -Inf))

  f$draws$q_member <- matrix(1, 1L, 4L)
  f$draws$alpha <- matrix(c(log(1000), -1000, -1000, -1000), 1L, 4L)
  f$draws$camera_effect <- matrix(0, 1L, 2L)
  f$draws$interaction <- array(0, dim = c(1L, 4L, 2L))
  f$detected_ever <- c(1L, 0L, 0L, 0L)
  f$future_effort$active_days <- c(1, 0, 1, 0, 1, 0, 1, 0)
  out <- testthat::expect_no_warning(goal011_forecast(
    f$draws, f$detected_ever, f$future_effort, c(1L, 4L), f$labels
  ))
  redetect_zero <- out$count_pmfs$target == "redetection" &
    out$count_pmfs$horizon == 1L & out$count_pmfs$count == 0L
  testthat::expect_equal(out$count_pmfs$log_probability[redetect_zero], -1000,
                         tolerance = 1e-10)
  testthat::expect_equal(out$species_probabilities$log_detection_probability[1L],
                         -0.0, tolerance = 1e-12)
})

testthat::test_that("effort order and interaction draw persistence are respected", {
  f <- .goal011_test_fixture()
  out <- goal011_forecast(f$draws, f$detected_ever, f$future_effort,
                          f$horizons, f$labels)
  shuffled <- f$future_effort[sample(nrow(f$future_effort)), , drop = FALSE]
  labels_shuffled <- f$labels[c(4L, 2L, 1L, 3L), , drop = FALSE]
  same <- goal011_forecast(f$draws, f$detected_ever, shuffled,
                           f$horizons, labels_shuffled)
  testthat::expect_equal(out$species_probabilities, same$species_probabilities,
                         tolerance = 1e-12)
  testthat::expect_equal(out$count_pmfs, same$count_pmfs, tolerance = 1e-12)
  testthat::expect_equal(dim(out$per_draw$log_detection), c(3L, 4L, 3L))
  # Draw 1's species 2 interaction changes its station-specific hazard while
  # remaining the same interaction draw at every forecast horizon.
  testthat::expect_false(
    isTRUE(all.equal(out$per_draw$log_detection[1, 2, 1],
                     out$per_draw$log_detection[1, 2, 3]))
  )
})

testthat::test_that("unseen named marginals are exchangeable and subgroup PMFs split hypergeometrically", {
  f <- .goal011_test_fixture()
  out <- goal011_forecast(f$draws, f$detected_ever, f$future_effort,
                          f$horizons, f$labels)
  species <- out$species_probabilities
  for (h in f$horizons) {
    unseen <- species[!species$known_member & species$horizon == h, ]
    testthat::expect_equal(unseen$discovery_probability,
                           rep(unseen$discovery_probability[[1L]], nrow(unseen)),
                           tolerance = 1e-12)
    total <- out$count_pmfs[out$count_pmfs$target == "totaldiscovery" &
                              out$count_pmfs$horizon == h, ]
    aves <- out$count_pmfs[out$count_pmfs$target == "discovery_taxon_class" &
                             out$count_pmfs$group == "Aves" &
                             out$count_pmfs$horizon == h, ]
    testthat::expect_equal(sum(aves$count * aves$probability),
                           1 / 3 * sum(total$count * total$probability),
                           tolerance = 1e-12)
  }
})

testthat::test_that("posterior draw dependence is retained in count PMFs", {
  p <- c(.9, .1)
  f <- .goal011_test_fixture()
  f$draws$q_member <- matrix(1, 2L, 2L)
  f$draws$alpha <- matrix(log(-log1p(-c(.9, .9, .1, .1))), 2L, 2L, byrow = TRUE)
  f$draws$camera_effect <- matrix(0, 2L, 2L)
  f$draws$interaction <- array(0, dim = c(2L, 2L, 2L))
  f$draws$candidate_ids <- c("s1", "s2")
  f$draws$camera_ids <- c("j1", "j2")
  f$detected_ever <- c(0L, 0L)
  f$labels <- data.frame(
    species_id = c("s1", "s2"), taxon_class = c("A", "B"),
    encounter_class = c("r", "o"), stringsAsFactors = FALSE
  )
  f$future_effort <- data.frame(
    camera_id = rep(c("j1", "j2"), each = 1L), future_week = 1L,
    active_days = c(1L, 0L), stringsAsFactors = FALSE
  )
  out <- goal011_forecast(f$draws, f$detected_ever, f$future_effort,
                          1L, f$labels)
  total <- out$count_pmfs[out$count_pmfs$target == "totaldiscovery", ]
  independent <- c((1 - .5)^2, 2 * .5 * .5, .5^2)
  testthat::expect_equal(total$probability, c(.41, .18, .41), tolerance = 1e-12)
  testthat::expect_false(isTRUE(all.equal(total$probability, independent)))
})

testthat::test_that("first-discovery bins retain saturated-hazard tail mass", {
  draws <- list(
    q_member = matrix(.5, 1L, 1L),
    alpha = matrix(log(1000), 1L, 1L),
    camera_effect = matrix(0, 1L, 1L),
    candidate_ids = "unseen", camera_ids = "j1"
  )
  effort <- data.frame(
    camera_id = c("j1", "j1"), future_week = c(1L, 2L),
    active_days = c(1L, 1L), stringsAsFactors = FALSE
  )
  labels <- data.frame(
    species_id = "unseen", taxon_class = "Aves", encounter_class = "routine",
    stringsAsFactors = FALSE
  )
  out <- goal011_forecast(draws, 0L, effort, c(1L, 2L), labels)
  second <- out$species_probabilities[
    out$species_probabilities$horizon == 2L, , drop = FALSE
  ]
  testthat::expect_true(is.finite(second$log_first_discovery_bin_probability))
  testthat::expect_equal(
    second$log_first_discovery_bin_probability,
    log(.5) - 1000 + log(-expm1(-1000)),
    tolerance = 1e-10
  )
})


testthat::test_that("Goal011 rejects hazards beyond the finite log-score range", {
  testthat::expect_error(.goal011_log_nondetection(c(0,1000)),"representable log-score range")
  testthat::expect_equal(.goal011_log_nondetection(log(1000)),-1000,tolerance=1e-10)
})
