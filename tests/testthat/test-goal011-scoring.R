.goal011_scoring_fixture <- function() {
  ids <- c("u_fast", "u_impossible", "k_one", "k_two")
  horizons <- c(1L, 2L)
  known <- c(0L, 0L, 1L, 1L)
  labels <- data.frame(
    species_id = ids,
    taxon_class = c("Mammalia", "Aves", "Mammalia", "Aves"),
    encounter_class = c("routine", "occasional", "routine", "routine"),
    stringsAsFactors = FALSE
  )
  log_detection <- array(0, dim = c(2L, length(ids), length(horizons)))
  log_nondetection <- array(0, dim = dim(log_detection))
  fast_detection <- log(-expm1(-exp(10)))
  fast_nondetection <- -exp(10)
  for (d in seq_len(dim(log_detection)[1L])) {
    log_detection[d, 1L, ] <- fast_detection
    log_nondetection[d, 1L, ] <- fast_nondetection
    log_detection[d, 2L, ] <- -Inf
    log_nondetection[d, 2L, ] <- 0
    log_detection[d, 3L, ] <- log(c(0.2, 0.4))
    log_nondetection[d, 3L, ] <- log(c(0.8, 0.6))
    log_detection[d, 4L, ] <- log(c(0.6, 0.8))
    log_nondetection[d, 4L, ] <- log(c(0.4, 0.2))
  }
  species <- expand.grid(
    species_id = ids, horizon = horizons,
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  species$known_member <- rep(known, times = length(horizons))
  species$log_detection_probability <- vapply(seq_len(nrow(species)), function(i) {
    j <- match(species$species_id[[i]], ids)
    h <- match(species$horizon[[i]], horizons)
    .goal011_score_logsumexp(log_detection[, j, h]) - log(2)
  }, numeric(1))
  species$log_nondetection_probability <- vapply(seq_len(nrow(species)), function(i) {
    j <- match(species$species_id[[i]], ids)
    h <- match(species$horizon[[i]], horizons)
    .goal011_score_logsumexp(log_nondetection[, j, h]) - log(2)
  }, numeric(1))
  species$detection_probability <- exp(species$log_detection_probability)
  make_pmf <- function(target, group, horizon, probabilities) {
    data.frame(
      target = target,
      group = group,
      horizon = horizon,
      count = seq.int(0L, length(probabilities) - 1L),
      probability = probabilities,
      log_probability = ifelse(probabilities == 0, -Inf, log(probabilities)),
      stringsAsFactors = FALSE
    )
  }
  rows <- list()
  add <- function(target, group, probabilities) {
    for (h in horizons) {
      rows[[length(rows) + 1L]] <<- make_pmf(target, group, h, probabilities)
    }
  }
  add("totaldiscovery", "all", c(0.5, 0, 0.5, 0))
  add("redetection", "all", c(0.4, 0.4, 0.2, 0))
  add("all_detection", "all", c(0.2, 0.3, 0.3, 0.2))
  add("discovery_taxon_class", "Aves", c(0.5, 0.3, 0.2))
  add("discovery_taxon_class", "Mammalia", c(0.7, 0.2, 0.1))
  add("discovery_encounter_class", "occasional", c(0.5, 0.3, 0.2))
  add("discovery_encounter_class", "routine", c(0.7, 0.2, 0.1))
  outcomes <- expand.grid(
    species_id = ids, horizon = horizons,
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  outcomes$detected <- c(0L, 1L, 0L, 1L, 0L, 1L, 1L, 1L)
  list(
    forecast = list(
      species_probabilities = species,
      count_pmfs = do.call(rbind, rows),
      per_draw = list(
        log_detection = log_detection,
        log_nondetection = log_nondetection
      ),
      metadata = list(
        candidate_ids = ids,
        horizons = horizons,
        labels = labels
      )
    ),
    outcomes = outcomes
  )
}

testthat::test_that("Goal011 scoring uses stable species logs and frozen groups", {
  fixture <- .goal011_scoring_fixture()
  scored <- goal011_score_forecast(fixture$forecast, fixture$outcomes)
  testthat::expect_identical(
    names(scored), c("species_scores", "aggregate_species_scores", "count_scores")
  )
  testthat::expect_equal(nrow(scored$species_scores), 8L)
  testthat::expect_setequal(
    scored$aggregate_species_scores$group,
    c("unseen_discovery", "known_redetection", "all")
  )
  fast_absence <- scored$species_scores[
    scored$species_scores$species_id == "u_fast" &
      scored$species_scores$horizon == 1L, , drop = FALSE
  ]
  testthat::expect_true(is.finite(fast_absence$negative_log_score))
  testthat::expect_gt(fast_absence$negative_log_score, 10000)
  impossible_detection <- scored$species_scores[
    scored$species_scores$species_id == "u_impossible" &
      scored$species_scores$horizon == 1L, , drop = FALSE
  ]
  testthat::expect_true(is.infinite(impossible_detection$negative_log_score))
  impossible_count <- scored$count_scores[
    scored$count_scores$target == "totaldiscovery" &
      scored$count_scores$horizon == 1L, , drop = FALSE
  ]
  testthat::expect_true(is.infinite(impossible_count$negative_log_score))
  taxon_count <- scored$count_scores[
    scored$count_scores$target == "discovery_taxon_class" &
      scored$count_scores$group == "Aves" &
      scored$count_scores$horizon == 1L, , drop = FALSE
  ]
  testthat::expect_identical(taxon_count$observed_count, 1L)
})

testthat::test_that("Goal011 scoring rejects malformed or non-nested outcomes", {
  fixture <- .goal011_scoring_fixture()
  missing <- fixture$outcomes[-1L, , drop = FALSE]
  testthat::expect_error(
    goal011_score_forecast(fixture$forecast, missing),
    "exact forecast candidate-horizon set",
    fixed = TRUE
  )
  duplicate <- rbind(fixture$outcomes, fixture$outcomes[1L, , drop = FALSE])
  testthat::expect_error(
    goal011_score_forecast(fixture$forecast, duplicate),
    "duplicate species-horizon",
    fixed = TRUE
  )
  absent <- fixture$outcomes
  absent$species_id[[1L]] <- "not_in_forecast"
  testthat::expect_error(
    goal011_score_forecast(fixture$forecast, absent),
    "absent from the forecast",
    fixed = TRUE
  )
  nonnested <- fixture$outcomes
  nonnested$detected[nonnested$species_id == "u_fast"] <- c(1L, 0L)
  testthat::expect_error(
    goal011_score_forecast(fixture$forecast, nonnested),
    "nested nondecreasing",
    fixed = TRUE
  )
  binary <- fixture$outcomes
  binary$detected[[1L]] <- 2L
  testthat::expect_error(
    goal011_score_forecast(fixture$forecast, binary),
    "binary",
    fixed = TRUE
  )
})

testthat::test_that("Goal011 scorer accepts the core forecast representation", {
  ids <- c("u", "v", "known_a", "known_b")
  labels <- data.frame(
    species_id = ids,
    taxon_class = c("Mammalia", "Aves", "Mammalia", "Aves"),
    encounter_class = rep("routine", 4L),
    stringsAsFactors = FALSE
  )
  draws <- list(
    q_member = rbind(c(0.5, 0.6, 1, 1), c(0.7, 0.4, 1, 1)),
    alpha = matrix(log(0.02), nrow = 2L, ncol = 4L),
    camera_effect = matrix(0, nrow = 2L, ncol = 1L),
    interaction = NULL,
    candidate_ids = ids,
    camera_ids = "cam"
  )
  effort <- data.frame(
    camera_id = rep("cam", 2L), future_week = 1:2, active_days = c(7, 7),
    stringsAsFactors = FALSE
  )
  forecast <- goal011_forecast(
    draws, detected_ever = c(0L, 0L, 1L, 1L), future_effort = effort,
    horizons = c(1L, 2L), labels = labels
  )
  outcomes <- expand.grid(
    species_id = ids, horizon = c(1L, 2L),
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  outcomes$detected <- 0L
  scored <- goal011_score_forecast(forecast, outcomes)
  testthat::expect_equal(nrow(scored$species_scores), 8L)
  testthat::expect_true(all(is.finite(scored$species_scores$negative_log_score)))
  testthat::expect_true(all(scored$species_scores$event_type[1:4] == "discovery"))
})


testthat::test_that("Goal011 scoring rejects corrupted saved event probabilities", {
  f <- .goal011_scoring_fixture()
  for(bad in c(NA_real_,Inf,.1)) {
    x <- f$forecast
    x$species_probabilities$log_detection_probability[1] <- bad
    testthat::expect_error(goal011_score_forecast(x,f$outcomes),"invalid schema")
  }
  x <- f$forecast
  x$species_probabilities$log_detection_probability[1] <- log(.5)
  testthat::expect_error(goal011_score_forecast(x,f$outcomes),"normalized")
})
