.make_small_sim <- function(seed = 200L) {
  simulate_flexirich_g(flexirich_sim_config(
    candidate_pool_size = 6L,
    true_richness = 3L,
    n_cameras = 2L,
    n_occasions = 3L,
    mean_log_rate = log(0.01),
    sd_log_rate = 0.2,
    sd_camera = 0.1,
    daily_failure_prob = 0,
    seed = seed
  ))
}

.nudge_probability <- function(probability) {
  if (probability < 0.5) {
    probability + 0.1
  } else {
    probability - 0.1
  }
}

testthat::test_that("validation enforces the object contract and configured key grains", {
  sim <- .make_small_sim()
  validation <- withVisible(validate_flexirich_sim(sim))
  testthat::expect_identical(validation$value, TRUE)
  testthat::expect_false(validation$visible)

  wrong_class <- sim
  class(wrong_class) <- "list"
  testthat::expect_error(
    validate_flexirich_sim(wrong_class),
    "inherit from flexirich_sim",
    fixed = TRUE
  )

  missing_component <- sim
  missing_component$metadata <- NULL
  testthat::expect_error(
    validate_flexirich_sim(missing_component),
    "component contract",
    fixed = TRUE
  )

  bad_schema <- sim
  bad_schema$rates <- dplyr::select(bad_schema$rates, -alpha)
  testthat::expect_error(
    validate_flexirich_sim(bad_schema),
    "rates component contract",
    fixed = TRUE
  )

  bad_species_dimension <- sim
  bad_species_dimension$species <- bad_species_dimension$species[-1L, ]
  testthat::expect_error(
    validate_flexirich_sim(bad_species_dimension),
    "configured species",
    fixed = TRUE
  )

  bad_camera_dimension <- sim
  bad_camera_dimension$cameras <- bad_camera_dimension$cameras[-1L, ]
  testthat::expect_error(
    validate_flexirich_sim(bad_camera_dimension),
    "configured cameras",
    fixed = TRUE
  )

  bad_rate_key <- sim
  last_rate <- nrow(bad_rate_key$rates)
  bad_rate_key$rates$species_id[last_rate] <- bad_rate_key$rates$species_id[1L]
  bad_rate_key$rates$camera_id[last_rate] <- bad_rate_key$rates$camera_id[1L]
  testthat::expect_error(
    validate_flexirich_sim(bad_rate_key),
    "one row per configured species-camera key",
    fixed = TRUE
  )

  bad_detection_key <- sim
  last_detection <- nrow(bad_detection_key$detections)
  bad_detection_key$detections$species_id[last_detection] <-
    bad_detection_key$detections$species_id[1L]
  bad_detection_key$detections$camera_id[last_detection] <-
    bad_detection_key$detections$camera_id[1L]
  bad_detection_key$detections$occasion_id[last_detection] <-
    bad_detection_key$detections$occasion_id[1L]
  testthat::expect_error(
    validate_flexirich_sim(bad_detection_key),
    "one row per configured species-camera-occasion key",
    fixed = TRUE
  )
})

testthat::test_that("validation reconstructs daily and weekly effort exactly", {
  sim <- .make_small_sim(seed = 201L)

  incomplete_daily <- sim
  incomplete_daily$effort_daily <- incomplete_daily$effort_daily[-1L, ]
  testthat::expect_error(
    validate_flexirich_sim(incomplete_daily),
    "daily effort",
    fixed = TRUE
  )

  corrupted_weekly <- sim
  corrupted_weekly$effort_weekly$active_days[1L] <-
    corrupted_weekly$effort_weekly$active_days[1L] - 1L
  testthat::expect_error(
    validate_flexirich_sim(corrupted_weekly),
    "weekly effort",
    fixed = TRUE
  )
})

testthat::test_that("validation reconstructs rate equations and latent-state links", {
  sim <- .make_small_sim(seed = 202L)

  unlinked_effect <- sim
  unlinked_effect$rates$alpha[1L] <- unlinked_effect$rates$alpha[1L] + 0.5
  unlinked_effect$rates$encounter_rate[1L] <- exp(
    unlinked_effect$rates$alpha[1L] +
      unlinked_effect$rates$camera_effect[1L]
  )
  testthat::expect_error(
    validate_flexirich_sim(unlinked_effect),
    "species effects",
    fixed = TRUE
  )

  wrong_equation <- sim
  wrong_equation$rates$encounter_rate[1L] <-
    wrong_equation$rates$encounter_rate[1L] * 1.1
  testthat::expect_error(
    validate_flexirich_sim(wrong_equation),
    "encounter-rate equation",
    fixed = TRUE
  )

  invalid_rate <- sim
  invalid_rate$rates$encounter_rate[1L] <- -0.1
  testthat::expect_error(
    validate_flexirich_sim(invalid_rate),
    "finite and positive",
    fixed = TRUE
  )
})

testthat::test_that("validation reconstructs detection context and probability equations", {
  sim <- .make_small_sim(seed = 203L)
  sampled_row <- which(sim$detections$sampled)[1L]
  member_row <- which(sim$detections$sampled & sim$detections$member)[1L]

  unlinked_member <- sim
  unlinked_member$detections$member[member_row] <- FALSE
  testthat::expect_error(
    validate_flexirich_sim(unlinked_member),
    "detection membership",
    fixed = TRUE
  )

  unlinked_rate <- sim
  unlinked_rate$detections$encounter_rate[sampled_row] <-
    unlinked_rate$detections$encounter_rate[sampled_row] * 1.1
  testthat::expect_error(
    validate_flexirich_sim(unlinked_rate),
    "detection encounter rates",
    fixed = TRUE
  )

  wrong_sampled <- sim
  wrong_sampled$detections$sampled[sampled_row] <- FALSE
  testthat::expect_error(
    validate_flexirich_sim(wrong_sampled),
    "sampled status",
    fixed = TRUE
  )

  wrong_conditional_probability <- sim
  wrong_conditional_probability$detections$detect_prob_if_member[sampled_row] <-
    .nudge_probability(
      wrong_conditional_probability$detections$detect_prob_if_member[sampled_row]
    )
  testthat::expect_error(
    validate_flexirich_sim(wrong_conditional_probability),
    "conditional detection-probability equation",
    fixed = TRUE
  )

  wrong_member_probability <- sim
  wrong_member_probability$detections$detect_prob[member_row] <-
    .nudge_probability(
      wrong_member_probability$detections$detect_prob[member_row]
    )
  testthat::expect_error(
    validate_flexirich_sim(wrong_member_probability),
    "member detection-probability equation",
    fixed = TRUE
  )

  invalid_probability <- sim
  invalid_probability$detections$detect_prob_if_member[sampled_row] <- 1.1
  testthat::expect_error(
    validate_flexirich_sim(invalid_probability),
    "probabilities must be finite and lie in [0, 1]",
    fixed = TRUE
  )
})

testthat::test_that("validation enforces sampled outcomes and structural non-detection", {
  no_effort_config <- flexirich_sim_config(
    candidate_pool_size = 4L,
    true_richness = 2L,
    n_cameras = 1L,
    n_occasions = 2L,
    initial_operating_prob = 0,
    daily_failure_prob = 0,
    daily_repair_prob = 0,
    seed = 204L
  )
  no_effort <- simulate_flexirich_g(no_effort_config)
  testthat::expect_true(validate_flexirich_sim(no_effort))

  observed_without_effort <- no_effort
  observed_without_effort$detections$detected[1L] <- 0L
  testthat::expect_error(
    validate_flexirich_sim(observed_without_effort),
    "zero-effort observations must be missing",
    fixed = TRUE
  )

  sim <- .make_small_sim(seed = 205L)
  sampled_row <- which(sim$detections$sampled)[1L]
  invalid_binary <- sim
  invalid_binary$detections$detected[sampled_row] <- 2L
  testthat::expect_error(
    validate_flexirich_sim(invalid_binary),
    "sampled observations must be binary",
    fixed = TRUE
  )

  nonmember_row <- which(
    sim$detections$sampled & !sim$detections$member
  )[1L]
  detected_nonmember <- sim
  detected_nonmember$detections$detected[nonmember_row] <- 1L
  testthat::expect_error(
    validate_flexirich_sim(detected_nonmember),
    "non-member species was detected",
    fixed = TRUE
  )
})

testthat::test_that("validation recomputes every truth-summary field", {
  sim <- .make_small_sim(seed = 206L)
  truth_fields <- c(
    "candidate_pool_size", "true_richness", "observed_richness",
    "unseen_true_members", "nonmembers", "total_detections"
  )

  for (field in truth_fields) {
    broken <- sim
    broken$truth[[field]] <- broken$truth[[field]] + 1L
    testthat::expect_error(
      validate_flexirich_sim(broken),
      field,
      fixed = TRUE,
      info = paste("corrupted truth field:", field)
    )
  }
})

testthat::test_that("summary is a one-row descriptive scientific record", {
  sim <- .make_small_sim(seed = 207L)
  result <- summary(sim)

  testthat::expect_s3_class(result, "tbl_df")
  testthat::expect_equal(nrow(result), 1L)
  testthat::expect_named(result, c(
    "candidate_pool_size", "true_richness", "observed_richness",
    "unseen_true_members", "detection_completeness", "camera_days",
    "total_detections"
  ))
  testthat::expect_identical(
    result$candidate_pool_size,
    sim$truth$candidate_pool_size
  )
  testthat::expect_identical(result$true_richness, sim$truth$true_richness)
  testthat::expect_identical(
    result$observed_richness,
    sim$truth$observed_richness
  )
  testthat::expect_identical(
    result$unseen_true_members,
    sim$truth$unseen_true_members
  )
  testthat::expect_equal(
    result$detection_completeness,
    sim$truth$observed_richness / sim$truth$true_richness
  )
  testthat::expect_identical(
    result$camera_days,
    sum(sim$effort_weekly$active_days)
  )
  testthat::expect_identical(
    result$total_detections,
    sim$truth$total_detections
  )

  zero_members <- simulate_flexirich_g(flexirich_sim_config(
    candidate_pool_size = 4L,
    true_richness = 0L,
    n_cameras = 1L,
    n_occasions = 2L,
    seed = 208L
  ))
  zero_summary <- summary(zero_members)
  testthat::expect_identical(zero_summary$detection_completeness, 1)
})

testthat::test_that("printing reports the descriptive summary and returns the simulation", {
  sim <- .make_small_sim(seed = 209L)

  output <- testthat::capture_output(
    returned <- withVisible(print(sim))
  )

  testthat::expect_identical(returned$value, sim)
  testthat::expect_false(returned$visible)
  testthat::expect_match(output, "candidate_pool_size", fixed = TRUE)
  testthat::expect_false(grepl("\\$config", output))
})

testthat::test_that("discovery curve reconstructs chronological first detections", {
  staged <- simulate_flexirich_g(flexirich_sim_config(
    candidate_pool_size = 3L,
    true_richness = 3L,
    n_cameras = 1L,
    n_occasions = 3L,
    daily_failure_prob = 0,
    seed = 210L
  ))
  staged$detections$detected[] <- 0L
  for (index in seq_len(3L)) {
    discovery_row <- which(
      staged$detections$species_id == sprintf("sp_%03d", index) &
        staged$detections$occasion_id == sprintf("occ_%03d", index)
    )
    staged$detections$detected[discovery_row] <- 1L
  }
  staged$truth$observed_richness <- 3L
  staged$truth$unseen_true_members <- 0L
  staged$truth$total_detections <- 3L

  curve <- discovery_curve(staged)

  testthat::expect_s3_class(curve, "tbl_df")
  testthat::expect_named(curve, c(
    "occasion_index", "occasion_id", "occasion_start",
    "cumulative_richness"
  ))
  testthat::expect_equal(nrow(curve), staged$config$n_occasions)
  testthat::expect_identical(curve$occasion_index, seq_len(3L))
  testthat::expect_identical(
    curve$occasion_id,
    sprintf("occ_%03d", seq_len(3L))
  )
  testthat::expect_identical(
    curve$occasion_start,
    staged$config$start_date + c(0L, 7L, 14L)
  )
  testthat::expect_identical(curve$cumulative_richness, seq_len(3L))
  testthat::expect_true(all(diff(curve$cumulative_richness) >= 0L))
  testthat::expect_identical(
    tail(curve$cumulative_richness, 1L),
    staged$truth$observed_richness
  )
})

testthat::test_that("zero members yield an all-zero complete discovery curve", {
  empty <- simulate_flexirich_g(flexirich_sim_config(
    candidate_pool_size = 5L,
    true_richness = 0L,
    n_cameras = 2L,
    n_occasions = 4L,
    seed = 211L
  ))

  testthat::expect_no_warning(
    curve <- discovery_curve(empty)
  )

  testthat::expect_equal(nrow(curve), empty$config$n_occasions)
  testthat::expect_identical(
    curve$occasion_index,
    seq_len(empty$config$n_occasions)
  )
  testthat::expect_true(all(curve$cumulative_richness == 0L))
  testthat::expect_identical(
    tail(curve$cumulative_richness, 1L),
    empty$truth$observed_richness
  )
})

testthat::test_that("high encounter rate reveals more species than a very low rate", {
  low <- simulate_flexirich_g(flexirich_sim_config(
    mean_log_rate = log(1e-5),
    sd_log_rate = 0,
    sd_camera = 0,
    daily_failure_prob = 0,
    seed = 220L
  ))
  high <- simulate_flexirich_g(flexirich_sim_config(
    mean_log_rate = log(0.02),
    sd_log_rate = 0,
    sd_camera = 0,
    daily_failure_prob = 0,
    seed = 220L
  ))

  testthat::expect_gt(
    high$truth$observed_richness,
    low$truth$observed_richness
  )
})
