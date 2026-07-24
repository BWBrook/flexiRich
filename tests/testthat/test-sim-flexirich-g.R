testthat::test_that("simulation returns the complete truth contract", {
  config <- flexirich_sim_config(
    candidate_pool_size = 12L,
    true_richness = 7L,
    n_cameras = 3L,
    n_occasions = 5L,
    seed = 100L
  )
  sim <- simulate_flexirich_g(config)

  testthat::expect_s3_class(sim, "flexirich_sim")
  testthat::expect_named(sim, c(
    "config", "species", "cameras", "rates", "effort_daily",
    "effort_weekly", "detections", "truth", "metadata"
  ))
  testthat::expect_named(
    sim$species,
    c("species_id", "member", "alpha")
  )
  testthat::expect_named(
    sim$cameras,
    c("camera_id", "camera_effect")
  )
  testthat::expect_named(
    sim$rates,
    c(
      "species_id", "camera_id", "member", "alpha", "camera_effect",
      "encounter_rate"
    )
  )
  testthat::expect_named(
    sim$detections,
    c(
      "species_id", "camera_id", "occasion_id", "occasion_start",
      "occasion_end", "active_days", "member", "encounter_rate",
      "sampled", "detect_prob_if_member", "detect_prob", "detected"
    )
  )
  testthat::expect_named(
    sim$truth,
    c(
      "candidate_pool_size", "true_richness", "observed_richness",
      "unseen_true_members", "nonmembers", "total_detections"
    )
  )
  testthat::expect_named(
    sim$metadata,
    c("simulator_version", "seed", "generated_at")
  )

  testthat::expect_equal(sum(sim$species$member), 7L)
  testthat::expect_equal(nrow(sim$rates), 12L * 3L)
  testthat::expect_equal(nrow(sim$detections), 12L * 3L * 5L)
  testthat::expect_identical(sim$truth$true_richness, 7L)
  testthat::expect_identical(sim$metadata$seed, config$seed)
})

testthat::test_that("random streams reconstruct latent membership and effects", {
  config <- flexirich_sim_config(
    candidate_pool_size = 11L,
    true_richness = 6L,
    n_cameras = 4L,
    n_occasions = 2L,
    mean_log_rate = log(0.004),
    sd_log_rate = 0.7,
    sd_camera = 0.25,
    seed = 105L
  )
  sim <- simulate_flexirich_g(config)

  member_index <- withr::with_seed(
    config$seed + 101L,
    sample.int(config$candidate_pool_size, config$true_richness)
  )
  expected_member <- seq_len(config$candidate_pool_size) %in% member_index
  expected_alpha <- withr::with_seed(
    config$seed + 102L,
    stats::rnorm(
      config$candidate_pool_size,
      mean = config$mean_log_rate,
      sd = config$sd_log_rate
    )
  )
  expected_camera_effect <- withr::with_seed(
    config$seed + 201L,
    stats::rnorm(config$n_cameras, mean = 0, sd = config$sd_camera)
  )

  testthat::expect_identical(sim$species$member, expected_member)
  testthat::expect_identical(sim$species$alpha, expected_alpha)
  testthat::expect_identical(
    sim$cameras$camera_effect,
    expected_camera_effect
  )
})

testthat::test_that("non-members and zero effort never generate detections", {
  config <- flexirich_sim_config(
    candidate_pool_size = 8L,
    true_richness = 4L,
    n_cameras = 2L,
    n_occasions = 3L,
    seed = 110L
  )
  no_effort <- tidyr::expand_grid(
    camera_id = sprintf("cam_%02d", 1:2),
    date = seq(config$start_date, by = "day", length.out = 21L)
  ) |>
    dplyr::mutate(operating = 0L)
  sim <- simulate_flexirich_g(config, no_effort)

  testthat::expect_true(all(is.na(sim$detections$detected)))
  testthat::expect_true(all(!sim$detections$sampled))
  testthat::expect_true(all(sim$detections$detect_prob_if_member == 0))
  testthat::expect_true(all(sim$detections$detect_prob == 0))

  ordinary <- simulate_flexirich_g(config)
  absent_rows <- ordinary$detections[!ordinary$detections$member, ]
  testthat::expect_true(all(
    absent_rows$detected[absent_rows$sampled] == 0L
  ))
  testthat::expect_true(all(
    is.na(absent_rows$detected[!absent_rows$sampled])
  ))
})

testthat::test_that("same seed reproduces data and truth without changing global RNG", {
  config <- flexirich_sim_config(seed = 120L)
  set.seed(777)
  before <- .Random.seed
  first <- simulate_flexirich_g(config)
  middle <- .Random.seed
  second <- simulate_flexirich_g(config)

  testthat::expect_identical(first$species, second$species)
  testthat::expect_identical(first$cameras, second$cameras)
  testthat::expect_identical(first$rates, second$rates)
  testthat::expect_identical(first$effort_daily, second$effort_daily)
  testthat::expect_identical(first$effort_weekly, second$effort_weekly)
  testthat::expect_identical(first$detections, second$detections)
  testthat::expect_identical(first$truth, second$truth)
  testthat::expect_identical(before, middle)
  testthat::expect_identical(before, .Random.seed)
})

testthat::test_that("baseline membership is independent of encounter-rate settings", {
  first <- simulate_flexirich_g(flexirich_sim_config(
    mean_log_rate = log(1e-5), sd_log_rate = 0.2, seed = 121L
  ))
  second <- simulate_flexirich_g(flexirich_sim_config(
    mean_log_rate = log(0.02), sd_log_rate = 2, seed = 121L
  ))

  testthat::expect_identical(first$species$member, second$species$member)
  testthat::expect_equal(sum(first$species$member), first$config$true_richness)
})

testthat::test_that("zero and complete membership are supported", {
  empty <- simulate_flexirich_g(flexirich_sim_config(
    candidate_pool_size = 5L, true_richness = 0L, seed = 130L
  ))
  complete <- simulate_flexirich_g(flexirich_sim_config(
    candidate_pool_size = 5L, true_richness = 5L, seed = 131L
  ))

  testthat::expect_identical(empty$truth$true_richness, 0L)
  testthat::expect_identical(empty$truth$observed_richness, 0L)
  testthat::expect_true(all(!empty$species$member))
  testthat::expect_true(all(complete$species$member))
})

testthat::test_that("numerically invalid encounter-rate settings fail visibly", {
  for (mean_log_rate in c(-1000, 1000)) {
    testthat::expect_no_warning(
      testthat::expect_error(
        simulate_flexirich_g(flexirich_sim_config(
          mean_log_rate = mean_log_rate,
          sd_log_rate = 0,
          seed = 132L
        )),
        "finite, positive encounter rates",
        info = paste("mean_log_rate:", mean_log_rate)
      )
    )
  }
})

testthat::test_that("hazard detection probability is non-decreasing with effort", {
  config <- flexirich_sim_config(
    candidate_pool_size = 1L,
    true_richness = 1L,
    n_cameras = 1L,
    n_occasions = 4L,
    mean_log_rate = log(0.02),
    sd_log_rate = 0,
    sd_camera = 0,
    seed = 135L
  )
  active_days <- c(0L, 1L, 3L, 7L)
  effort <- tidyr::expand_grid(
    camera_id = "cam_01",
    date = seq(config$start_date, by = "day", length.out = 28L)
  ) |>
    dplyr::mutate(
      day_offset = as.integer(date - config$start_date),
      occasion_index = day_offset %/% config$occasion_days + 1L,
      day_within_occasion = day_offset %% config$occasion_days + 1L,
      operating = as.integer(
        day_within_occasion <= active_days[occasion_index]
      )
    ) |>
    dplyr::select(camera_id, date, operating)
  sim <- simulate_flexirich_g(config, effort)
  probability <- sim$detections$detect_prob_if_member

  testthat::expect_identical(sim$detections$active_days, active_days)
  testthat::expect_true(all(diff(probability) >= 0))
  testthat::expect_identical(probability[1L], 0)
  testthat::expect_true(all(probability >= 0 & probability <= 1))
})

testthat::test_that("returned tables exactly reproduce the generative equations", {
  config <- flexirich_sim_config(
    candidate_pool_size = 10L,
    true_richness = 6L,
    n_cameras = 3L,
    n_occasions = 4L,
    initial_operating_prob = 0.6,
    daily_failure_prob = 0.2,
    daily_repair_prob = 0.35,
    seed = 140L
  )
  sim <- simulate_flexirich_g(config)

  expected_effort <- sim$effort_daily |>
    dplyr::mutate(
      day_offset = as.integer(date - config$start_date),
      occasion_index = day_offset %/% config$occasion_days + 1L,
      occasion_id = sprintf("occ_%03d", occasion_index)
    ) |>
    dplyr::summarise(
      expected_occasion_start = min(date),
      expected_occasion_end = max(date),
      expected_active_days = as.integer(sum(operating)),
      .by = c(camera_id, occasion_id)
    )
  effort_check <- dplyr::left_join(
    sim$effort_weekly,
    expected_effort,
    by = c("camera_id", "occasion_id")
  )
  testthat::expect_identical(
    effort_check$occasion_start,
    effort_check$expected_occasion_start
  )
  testthat::expect_identical(
    effort_check$occasion_end,
    effort_check$expected_occasion_end
  )
  testthat::expect_identical(
    effort_check$active_days,
    effort_check$expected_active_days
  )

  expected_rate <- exp(sim$rates$alpha + sim$rates$camera_effect)
  testthat::expect_identical(sim$rates$encounter_rate, expected_rate)

  expected_member_probability <- 1 - exp(
    -sim$detections$active_days * sim$detections$encounter_rate
  )
  testthat::expect_equal(
    sim$detections$detect_prob_if_member,
    expected_member_probability
  )
  testthat::expect_equal(
    sim$detections$detect_prob,
    as.numeric(sim$detections$member) * expected_member_probability
  )

  sampled <- sim$detections$sampled
  expected_detection <- withr::with_seed(config$seed + 401L, {
    stats::rbinom(
      sum(sampled),
      size = 1L,
      prob = sim$detections$detect_prob[sampled]
    )
  })
  testthat::expect_identical(
    sim$detections$detected[sampled],
    expected_detection
  )
  testthat::expect_true(all(is.na(sim$detections$detected[!sampled])))

  observed_species <- unique(sim$detections$species_id[
    !is.na(sim$detections$detected) & sim$detections$detected == 1L
  ])
  expected_truth <- tibble::tibble(
    candidate_pool_size = config$candidate_pool_size,
    true_richness = config$true_richness,
    observed_richness = as.integer(length(observed_species)),
    unseen_true_members = as.integer(
      config$true_richness - length(observed_species)
    ),
    nonmembers = as.integer(
      config$candidate_pool_size - config$true_richness
    ),
    total_detections = as.integer(sum(sim$detections$detected, na.rm = TRUE))
  )
  testthat::expect_identical(sim$truth, expected_truth)
})
