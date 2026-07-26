testthat::test_that("reordered configuration canonicalizes and self-validates", {
  config <- flexirich_sim_config(
    candidate_pool_size = 8L,
    true_richness = 4L,
    n_cameras = 2L,
    n_occasions = 2L,
    seed = 20260722L
  )
  canonical_fields <- names(formals(flexirich_sim_config))
  reordered <- config[rev(canonical_fields)]

  validated <- validate_sim_config(reordered)
  sim <- simulate_flexirich_g(reordered)

  testthat::expect_s3_class(validated, "flexirich_sim_config")
  testthat::expect_identical(names(validated), canonical_fields)
  testthat::expect_identical(sim$config, validated)
  testthat::expect_true(validate_flexirich_sim(sim))
})

testthat::test_that("configuration schema rejects extra missing duplicate and unnamed fields", {
  config <- unclass(flexirich_sim_config(
    candidate_pool_size = 8L,
    true_richness = 4L,
    n_cameras = 2L,
    n_occasions = 2L,
    seed = 20260721L
  ))

  extra <- config
  extra$unexpected <- TRUE
  testthat::expect_error(
    validate_sim_config(extra),
    "config has unexpected fields: unexpected",
    fixed = TRUE
  )
  testthat::expect_error(
    simulate_flexirich_g(extra),
    "config has unexpected fields: unexpected",
    fixed = TRUE
  )

  missing <- config
  missing$seed <- NULL
  testthat::expect_error(
    validate_sim_config(missing),
    "config is missing fields: seed",
    fixed = TRUE
  )

  duplicate <- config
  names(duplicate)[1L] <- names(duplicate)[2L]
  testthat::expect_error(
    validate_sim_config(duplicate),
    "config has duplicate fields: true_richness",
    fixed = TRUE
  )

  unnamed <- config
  names(unnamed)[1L] <- ""
  testthat::expect_error(
    validate_sim_config(unnamed),
    "config fields must all be named",
    fixed = TRUE
  )
})

testthat::test_that("reordered factor effort canonicalizes and self-validates", {
  config <- flexirich_sim_config(
    candidate_pool_size = 8L,
    true_richness = 4L,
    n_cameras = 2L,
    n_occasions = 2L,
    seed = 20260720L
  )
  supplied <- tidyr::expand_grid(
    camera_id = sprintf("cam_%02d", 2:1),
    date = rev(seq(config$start_date, by = "day", length.out = 14L))
  ) |>
    dplyr::mutate(
      operating = as.integer(dplyr::row_number() %% 3L != 0L),
      camera_id = factor(camera_id)
    ) |>
    dplyr::select(operating, camera_id, date)

  validated <- validate_daily_effort(supplied, config)
  sim <- simulate_flexirich_g(config, supplied)

  testthat::expect_named(validated, c("camera_id", "date", "operating"))
  testthat::expect_type(validated$camera_id, "character")
  testthat::expect_type(validated$operating, "integer")
  testthat::expect_identical(sim$effort_daily, validated)
  testthat::expect_true(validate_flexirich_sim(sim))
})

testthat::test_that("daily-effort schema rejects extra missing duplicate and unnamed fields", {
  config <- flexirich_sim_config(
    candidate_pool_size = 8L,
    true_richness = 4L,
    n_cameras = 2L,
    n_occasions = 2L,
    seed = 20260719L
  )
  supplied <- tidyr::expand_grid(
    camera_id = sprintf("cam_%02d", 1:2),
    date = seq(config$start_date, by = "day", length.out = 14L)
  ) |>
    dplyr::mutate(operating = 1L)

  extra <- dplyr::mutate(supplied, note = "unexpected")
  testthat::expect_error(
    validate_daily_effort(extra, config),
    "effort_daily has unexpected fields: note",
    fixed = TRUE
  )
  testthat::expect_error(
    simulate_flexirich_g(config, extra),
    "effort_daily has unexpected fields: note",
    fixed = TRUE
  )

  missing <- dplyr::select(supplied, -operating)
  testthat::expect_error(
    validate_daily_effort(missing, config),
    "effort_daily is missing fields: operating",
    fixed = TRUE
  )

  duplicate <- supplied
  duplicate$camera_copy <- duplicate$camera_id
  names(duplicate)[ncol(duplicate)] <- "camera_id"
  testthat::expect_error(
    validate_daily_effort(duplicate, config),
    "effort_daily has duplicate fields: camera_id",
    fixed = TRUE
  )

  unnamed <- supplied
  names(unnamed)[1L] <- ""
  testthat::expect_error(
    validate_daily_effort(unnamed, config),
    "effort_daily fields must all be named",
    fixed = TRUE
  )
})

testthat::test_that("daily effort rejects non-character non-factor camera identifiers", {
  config <- flexirich_sim_config(
    candidate_pool_size = 8L,
    true_richness = 4L,
    n_cameras = 2L,
    n_occasions = 2L,
    seed = 20260718L
  )
  supplied <- tidyr::expand_grid(
    camera_id = rep(1:2),
    date = seq(config$start_date, by = "day", length.out = 14L)
  ) |>
    dplyr::mutate(operating = 1L)

  testthat::expect_error(
    validate_daily_effort(supplied, config),
    "effort_daily$camera_id must be character or factor",
    fixed = TRUE
  )
})
