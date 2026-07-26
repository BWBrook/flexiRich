.with_restored_test_rng <- function(code) {
  caller_kind <- RNGkind()
  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (had_seed) {
    caller_seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  }

  on.exit({
    suppressWarnings(do.call(RNGkind, as.list(caller_kind)))
    if (had_seed) {
      assign(".Random.seed", caller_seed, envir = .GlobalEnv)
    } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".Random.seed", envir = .GlobalEnv)
    }
  }, add = TRUE)

  eval.parent(substitute(code))
}

testthat::test_that("simulator output is independent of caller RNG algorithms", {
  .with_restored_test_rng({
    config <- flexirich_sim_config(
      candidate_pool_size = 12L,
      true_richness = 6L,
      n_cameras = 3L,
      n_occasions = 4L,
      initial_operating_prob = 0.6,
      daily_failure_prob = 0.2,
      daily_repair_prob = 0.3,
      seed = 20260726L
    )

    suppressWarnings(RNGkind(
      kind = "Mersenne-Twister",
      normal.kind = "Inversion",
      sample.kind = "Rejection"
    ))
    canonical <- simulate_flexirich_g(config)

    suppressWarnings(RNGkind(
      kind = "Mersenne-Twister",
      normal.kind = "Box-Muller",
      sample.kind = "Rounding"
    ))
    alternate_normal_sample <- simulate_flexirich_g(config)

    suppressWarnings(RNGkind(
      kind = "L'Ecuyer-CMRG",
      normal.kind = "Inversion",
      sample.kind = "Rejection"
    ))
    alternate_kind <- simulate_flexirich_g(config)

    stochastic_components <- c(
      "species", "cameras", "rates", "effort_daily", "effort_weekly",
      "detections", "truth"
    )
    for (component in stochastic_components) {
      testthat::expect_identical(
        alternate_normal_sample[[component]],
        canonical[[component]],
        info = paste("alternate normal/sample kind:", component)
      )
      testthat::expect_identical(
        alternate_kind[[component]],
        canonical[[component]],
        info = paste("alternate uniform kind:", component)
      )
    }
  })
})

testthat::test_that("public generators restore caller RNG kinds and existing seed", {
  .with_restored_test_rng({
    config <- flexirich_sim_config(
      candidate_pool_size = 8L,
      true_richness = 4L,
      n_cameras = 2L,
      n_occasions = 2L,
      seed = 20260725L
    )
    suppressWarnings(RNGkind(
      kind = "L'Ecuyer-CMRG",
      normal.kind = "Box-Muller",
      sample.kind = "Rounding"
    ))
    set.seed(90210L)
    expected_kind <- RNGkind()
    expected_seed <- .Random.seed

    generators <- list(
      simulate_daily_effort = function() simulate_daily_effort(config),
      simulate_flexirich_g = function() simulate_flexirich_g(config)
    )
    for (generator in names(generators)) {
      testthat::expect_no_warning(
        generators[[generator]]()
      )
      testthat::expect_identical(
        RNGkind(),
        expected_kind,
        info = paste(generator, "RNGkind")
      )
      testthat::expect_identical(
        .Random.seed,
        expected_seed,
        info = paste(generator, ".Random.seed")
      )
    }
  })
})

testthat::test_that("public generators preserve an initially absent random seed", {
  .with_restored_test_rng({
    config <- flexirich_sim_config(
      candidate_pool_size = 8L,
      true_richness = 4L,
      n_cameras = 2L,
      n_occasions = 2L,
      seed = 20260724L
    )
    suppressWarnings(RNGkind(
      kind = "L'Ecuyer-CMRG",
      normal.kind = "Box-Muller",
      sample.kind = "Rounding"
    ))
    if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".Random.seed", envir = .GlobalEnv)
    }
    expected_kind <- RNGkind()

    generators <- list(
      simulate_daily_effort = function() simulate_daily_effort(config),
      simulate_flexirich_g = function() simulate_flexirich_g(config)
    )
    for (generator in names(generators)) {
      testthat::expect_false(
        exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE),
        info = paste(generator, "precondition")
      )
      testthat::expect_no_warning(
        generators[[generator]]()
      )
      testthat::expect_identical(
        RNGkind(),
        expected_kind,
        info = paste(generator, "RNGkind")
      )
      testthat::expect_false(
        exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE),
        info = paste(generator, ".Random.seed")
      )
    }
  })
})

testthat::test_that("run metadata records and validates canonical RNG algorithms", {
  sim <- simulate_flexirich_g(flexirich_sim_config(
    candidate_pool_size = 6L,
    true_richness = 3L,
    n_cameras = 2L,
    n_occasions = 2L,
    seed = 20260723L
  ))

  testthat::expect_named(sim$metadata, c(
    "simulator_version", "seed", "rng_kind", "rng_normal_kind",
    "rng_sample_kind", "generated_at"
  ))
  testthat::expect_identical(sim$metadata$simulator_version, "0.1.1")
  testthat::expect_identical(sim$metadata$rng_kind, "Mersenne-Twister")
  testthat::expect_identical(sim$metadata$rng_normal_kind, "Inversion")
  testthat::expect_identical(sim$metadata$rng_sample_kind, "Rejection")
  testthat::expect_true(validate_flexirich_sim(sim))

  canonical <- c(
    rng_kind = "Mersenne-Twister",
    rng_normal_kind = "Inversion",
    rng_sample_kind = "Rejection"
  )
  for (field in names(canonical)) {
    corrupted <- sim
    corrupted$metadata[[field]] <- paste0(canonical[[field]], "-corrupt")
    testthat::expect_error(
      validate_flexirich_sim(corrupted),
      paste0("metadata ", field, " must equal ", canonical[[field]]),
      fixed = TRUE,
      info = paste("corrupted metadata field:", field)
    )
  }
})
