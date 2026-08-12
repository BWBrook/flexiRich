.infer_fixture <- function() {
  candidate_pool <- tibble::tibble(
    species_id = c("sp_c", "sp_a", "sp_b")
  )
  effort_weekly <- tibble::tibble(
    camera_id = c("cam_b", "cam_a", "cam_b", "cam_a"),
    occasion_id = c("occ_02", "occ_01", "occ_01", "occ_02"),
    active_days = c(7L, 7L, 3L, 0L)
  )
  detections <- tidyr::crossing(
    species_id = candidate_pool$species_id,
    camera_id = c("cam_b", "cam_a"),
    occasion_id = c("occ_02", "occ_01")
  ) |>
    dplyr::left_join(
      effort_weekly,
      by = c("camera_id", "occasion_id")
    ) |>
    dplyr::mutate(
      detected = dplyr::case_when(
        active_days == 0L ~ NA_integer_,
        species_id == "sp_a" & camera_id == "cam_a" ~ 1L,
        species_id == "sp_b" &
          camera_id == "cam_b" &
          occasion_id == "occ_02" ~ 1L,
        .default = 0L
      )
    ) |>
    dplyr::select(
      species_id,
      camera_id,
      occasion_id,
      detected
    )

  list(
    candidate_pool = candidate_pool,
    effort_weekly = effort_weekly,
    detections = detections
  )
}

.prepare_infer_fixture <- function(inputs = .infer_fixture()) {
  prepare_flexirich_g_data(
    inputs$candidate_pool,
    inputs$effort_weekly,
    inputs$detections
  )
}

testthat::test_that("simulator adapter retains observations and excludes truth", {
  sim <- simulate_flexirich_g(
    flexirich_sim_config(
      candidate_pool_size = 4L,
      true_richness = 2L,
      n_cameras = 2L,
      n_occasions = 3L,
      seed = 2101L
    )
  )
  data <- sim_to_flexirich_g_data(sim)

  testthat::expect_s3_class(data, "flexirich_g_data")
  testthat::expect_true(validate_flexirich_g_data(data))
  forbidden <- c(
    "member", "true_richness", "alpha", "camera_effect",
    "encounter_rate", "detect_prob", "detect_prob_if_member", "truth"
  )
  testthat::expect_length(intersect(forbidden, names(data)), 0L)
  testthat::expect_length(
    intersect(forbidden, names(data$stan_data)),
    0L
  )
  testthat::expect_length(
    intersect(c("sim", "simulator", "truth"), names(attributes(data))),
    0L
  )
  testthat::expect_identical(data$stan_data$C, 4L)
  testthat::expect_identical(data$stan_data$J, 2L)

  changed_truth <- sim
  changed_truth$species$member <- !changed_truth$species$member
  changed_truth$species$alpha[] <- Inf
  changed_truth$rates <- NULL
  changed_truth$truth <- NULL
  testthat::expect_identical(
    sim_to_flexirich_g_data(changed_truth),
    data
  )
})

testthat::test_that("zero effort contributes no grouped trial", {
  sim <- simulate_flexirich_g(
    flexirich_sim_config(
      candidate_pool_size = 3L,
      true_richness = 2L,
      n_cameras = 2L,
      n_occasions = 2L,
      seed = 2102L
    )
  )
  sim$effort_weekly$active_days[1] <- 0L
  affected <- sim$detections$camera_id ==
    sim$effort_weekly$camera_id[1] &
    sim$detections$occasion_id ==
    sim$effort_weekly$occasion_id[1]
  sim$detections$active_days[affected] <- 0L
  sim$detections$sampled[affected] <- FALSE
  sim$detections$detected[affected] <- NA_integer_

  data <- prepare_flexirich_g_data(
    sim$species["species_id"],
    sim$effort_weekly[c("camera_id", "occasion_id", "active_days")],
    sim$detections[c(
      "species_id", "camera_id", "occasion_id", "detected"
    )]
  )

  testthat::expect_identical(
    sum(data$grouped$n_trials),
    3L * (2L * 2L - 1L)
  )
  testthat::expect_false(any(data$grouped$active_days == 0L))
})

testthat::test_that("aggregation reconstructs every sampled observation", {
  sim <- simulate_flexirich_g(
    flexirich_sim_config(
      candidate_pool_size = 5L,
      true_richness = 3L,
      n_cameras = 3L,
      n_occasions = 8L,
      seed = 2103L
    )
  )
  data <- sim_to_flexirich_g_data(sim)

  testthat::expect_identical(
    sum(data$grouped$n_trials),
    data$audit$n_sampled_rows
  )
  testthat::expect_identical(
    sum(data$grouped$n_detected),
    data$audit$n_detections
  )
  testthat::expect_identical(
    sort(unique(data$grouped$species_id)),
    sort(data$candidate_ids)
  )
})

testthat::test_that("the public inference-data schemas are exact", {
  data <- .prepare_infer_fixture()

  testthat::expect_identical(
    names(data),
    c(
      "candidate_ids", "camera_ids", "occasion_ids", "observed",
      "grouped", "stan_data", "audit", "data_hash"
    )
  )
  testthat::expect_identical(
    names(data$observed),
    c(
      "species_id", "camera_id", "occasion_id", "active_days",
      "detected"
    )
  )
  testthat::expect_identical(
    names(data$grouped),
    c(
      "species_id", "camera_id", "active_days", "n_trials",
      "n_detected"
    )
  )
  testthat::expect_identical(
    names(data$stan_data),
    c(
      "C", "J", "B", "G", "species_index", "camera_index",
      "active_days", "n_trials", "n_detected", "detected_ever", "Q"
    )
  )
  testthat::expect_identical(
    names(data$audit),
    c(
      "n_original_rows", "n_sampled_rows", "n_zero_effort_rows",
      "n_grouped_rows", "n_detections"
    )
  )
  testthat::expect_true(tibble::is_tibble(data$observed))
  testthat::expect_true(tibble::is_tibble(data$grouped))
  testthat::expect_type(data$observed$active_days, "integer")
  testthat::expect_type(data$observed$detected, "integer")
  testthat::expect_true(all(vapply(
    data$stan_data[setdiff(names(data$stan_data), "Q")],
    is.integer,
    logical(1)
  )))
  testthat::expect_true(is.matrix(data$stan_data$Q))
  testthat::expect_type(data$stan_data$Q, "double")
  testthat::expect_match(data$data_hash, "^[0-9a-f]{64}$")
})

testthat::test_that("input tables reject missing, extra, duplicate, and unnamed fields", {
  inputs <- .infer_fixture()
  cases <- list(
    candidate_pool = list(
      required = c("species_id"),
      other = inputs$effort_weekly,
      third = inputs$detections
    ),
    effort_weekly = list(
      required = c("camera_id", "occasion_id", "active_days"),
      other = inputs$candidate_pool,
      third = inputs$detections
    ),
    detections = list(
      required = c("species_id", "camera_id", "occasion_id", "detected"),
      other = inputs$candidate_pool,
      third = inputs$effort_weekly
    )
  )

  call_prepare <- function(name, value) {
    args <- inputs
    args[[name]] <- value
    do.call(prepare_flexirich_g_data, unname(args))
  }

  for (name in names(cases)) {
    original <- inputs[[name]]
    required <- cases[[name]]$required

    testthat::expect_error(
      call_prepare(name, as.matrix(original)),
      name,
      fixed = TRUE
    )
    testthat::expect_error(
      call_prepare(name, original[, -1L, drop = FALSE]),
      "missing",
      fixed = TRUE
    )

    extra <- original
    extra$unexpected <- seq_len(nrow(extra))
    testthat::expect_error(
      call_prepare(name, extra),
      "unexpected",
      fixed = TRUE
    )

    duplicate <- original
    duplicate$duplicate <- duplicate[[required[1L]]]
    names(duplicate)[ncol(duplicate)] <- required[1L]
    testthat::expect_error(
      call_prepare(name, duplicate),
      "duplicate",
      fixed = TRUE
    )

    unnamed <- original
    names(unnamed)[1L] <- ""
    testthat::expect_error(
      call_prepare(name, unnamed),
      "named",
      fixed = TRUE
    )
  }
})

testthat::test_that("identifiers are complete, character, non-empty, and unique", {
  inputs <- .infer_fixture()

  duplicated_candidates <- inputs$candidate_pool
  duplicated_candidates$species_id[2L] <-
    duplicated_candidates$species_id[1L]
  testthat::expect_error(
    prepare_flexirich_g_data(
      duplicated_candidates,
      inputs$effort_weekly,
      inputs$detections
    ),
    "unique"
  )

  for (bad_id in list(NA_character_, "")) {
    bad <- inputs$candidate_pool
    bad$species_id[1L] <- bad_id
    testthat::expect_error(
      prepare_flexirich_g_data(
        bad,
        inputs$effort_weekly,
        inputs$detections
      ),
      "species_id"
    )
  }

  factor_candidate <- inputs$candidate_pool
  factor_candidate$species_id <- factor(factor_candidate$species_id)
  testthat::expect_error(
    prepare_flexirich_g_data(
      factor_candidate,
      inputs$effort_weekly,
      inputs$detections
    ),
    "character"
  )

  bad_effort <- inputs$effort_weekly
  bad_effort$camera_id <- as.integer(factor(bad_effort$camera_id))
  testthat::expect_error(
    prepare_flexirich_g_data(
      inputs$candidate_pool,
      bad_effort,
      inputs$detections
    ),
    "camera_id"
  )

  bad_detection <- inputs$detections
  bad_detection$occasion_id[1L] <- NA_character_
  testthat::expect_error(
    prepare_flexirich_g_data(
      inputs$candidate_pool,
      inputs$effort_weekly,
      bad_detection
    ),
    "occasion_id"
  )
})

testthat::test_that("effort and detection keys must be unique complete Cartesian grids", {
  inputs <- .infer_fixture()

  testthat::expect_error(
    prepare_flexirich_g_data(
      inputs$candidate_pool,
      inputs$effort_weekly[-1L, ],
      inputs$detections
    ),
    "complete"
  )
  testthat::expect_error(
    prepare_flexirich_g_data(
      inputs$candidate_pool,
      dplyr::bind_rows(
        inputs$effort_weekly,
        inputs$effort_weekly[1L, ]
      ),
      inputs$detections
    ),
    "one row"
  )
  testthat::expect_error(
    prepare_flexirich_g_data(
      inputs$candidate_pool,
      inputs$effort_weekly,
      inputs$detections[-1L, ]
    ),
    "complete"
  )
  testthat::expect_error(
    prepare_flexirich_g_data(
      inputs$candidate_pool,
      inputs$effort_weekly,
      dplyr::bind_rows(inputs$detections, inputs$detections[1L, ])
    ),
    "one row"
  )

  missing_species <- dplyr::filter(
    inputs$detections,
    species_id != "sp_c"
  )
  testthat::expect_error(
    prepare_flexirich_g_data(
      inputs$candidate_pool,
      inputs$effort_weekly,
      missing_species
    ),
    "candidate"
  )

  outside_species <- inputs$detections
  outside_species$species_id[1L] <- "sp_outside"
  testthat::expect_error(
    prepare_flexirich_g_data(
      inputs$candidate_pool,
      inputs$effort_weekly,
      outside_species
    ),
    "candidate"
  )

  outside_camera <- inputs$detections
  outside_camera$camera_id[1L] <- "cam_outside"
  testthat::expect_error(
    prepare_flexirich_g_data(
      inputs$candidate_pool,
      inputs$effort_weekly,
      outside_camera
    ),
    "camera"
  )

  outside_occasion <- inputs$detections
  outside_occasion$occasion_id[1L] <- "occ_outside"
  testthat::expect_error(
    prepare_flexirich_g_data(
      inputs$candidate_pool,
      inputs$effort_weekly,
      outside_occasion
    ),
    "occasion"
  )
})

testthat::test_that("active days are finite whole numbers in zero through seven", {
  inputs <- .infer_fixture()

  for (bad_value in c(-1, 8, 1.5, NA_real_, Inf, NaN)) {
    bad <- inputs$effort_weekly
    bad$active_days[1L] <- bad_value
    testthat::expect_error(
      prepare_flexirich_g_data(
        inputs$candidate_pool,
        bad,
        inputs$detections
      ),
      "active_days"
    )
  }

  bad <- inputs$effort_weekly
  bad$active_days <- as.character(bad$active_days)
  testthat::expect_error(
    prepare_flexirich_g_data(
      inputs$candidate_pool,
      bad,
      inputs$detections
    ),
    "active_days"
  )

  logical_effort <- inputs$effort_weekly
  logical_effort$active_days <- logical(
    nrow(logical_effort)
  )
  testthat::expect_error(
    prepare_flexirich_g_data(
      inputs$candidate_pool,
      logical_effort,
      inputs$detections
    ),
    "active_days"
  )
})

testthat::test_that("detection outcomes obey binary and effort-missingness rules", {
  inputs <- .infer_fixture()
  positive_row <- which(!is.na(inputs$detections$detected))[1L]
  zero_row <- which(is.na(inputs$detections$detected))[1L]

  for (bad_value in c(-1, 2, 0.5, Inf, NaN)) {
    bad <- inputs$detections
    bad$detected[positive_row] <- bad_value
    testthat::expect_error(
      prepare_flexirich_g_data(
        inputs$candidate_pool,
        inputs$effort_weekly,
        bad
      ),
      "detected"
    )
  }

  bad_type <- inputs$detections
  bad_type$detected <- as.character(bad_type$detected)
  testthat::expect_error(
    prepare_flexirich_g_data(
      inputs$candidate_pool,
      inputs$effort_weekly,
      bad_type
    ),
    "detected"
  )

  positive_missing <- inputs$detections
  positive_missing$detected[positive_row] <- NA_integer_
  testthat::expect_error(
    prepare_flexirich_g_data(
      inputs$candidate_pool,
      inputs$effort_weekly,
      positive_missing
    ),
    "positive effort"
  )

  zero_observed <- inputs$detections
  zero_observed$detected[zero_row] <- 0L
  testthat::expect_error(
    prepare_flexirich_g_data(
      inputs$candidate_pool,
      inputs$effort_weekly,
      zero_observed
    ),
    "zero effort"
  )

  logical_detection <- inputs$detections
  logical_detection$detected <- as.logical(logical_detection$detected)
  logical_data <- prepare_flexirich_g_data(
    inputs$candidate_pool,
    inputs$effort_weekly,
    logical_detection
  )
  testthat::expect_identical(
    logical_data$observed$detected,
    .prepare_infer_fixture(inputs)$observed$detected
  )
})

testthat::test_that("cardinality guards fail without materialising grids", {
  testthat::expect_identical(
    .infer_checked_cardinality(
      c(3L, 4L),
      "test grid",
      limit = 12L
    ),
    12L
  )
  testthat::expect_error(
    .infer_checked_cardinality(
      c(3L, 4L),
      "test grid",
      limit = 11L
    ),
    "exceeds"
  )
  testthat::expect_error(
    .infer_checked_cardinality(
      c(.Machine$integer.max, 2L),
      "test grid"
    ),
    "exceeds"
  )
})

testthat::test_that("canonicalisation is byte-identical under input permutations", {
  inputs <- .infer_fixture()
  canonical <- .prepare_infer_fixture(inputs)
  permuted <- inputs
  permuted$candidate_pool <- permuted$candidate_pool[
    rev(seq_len(nrow(permuted$candidate_pool))),
    ,
    drop = FALSE
  ]
  permuted$effort_weekly <- permuted$effort_weekly[
    c(3L, 1L, 4L, 2L),
    ,
    drop = FALSE
  ]
  permuted$detections <- permuted$detections[
    rev(seq_len(nrow(permuted$detections))),
    ,
    drop = FALSE
  ]
  reordered <- .prepare_infer_fixture(permuted)

  testthat::expect_identical(canonical$candidate_ids, c("sp_a", "sp_b", "sp_c"))
  testthat::expect_identical(canonical$camera_ids, c("cam_a", "cam_b"))
  testthat::expect_identical(canonical$occasion_ids, c("occ_01", "occ_02"))
  testthat::expect_identical(
    serialize(canonical$observed, NULL),
    serialize(reordered$observed, NULL)
  )
  testthat::expect_identical(
    serialize(canonical$grouped, NULL),
    serialize(reordered$grouped, NULL)
  )
  testthat::expect_identical(
    serialize(canonical$stan_data, NULL),
    serialize(reordered$stan_data, NULL)
  )
  testthat::expect_identical(canonical$audit, reordered$audit)
  testthat::expect_identical(canonical$data_hash, reordered$data_hash)
})

testthat::test_that("Helmert basis is exact, orthonormal, and sum zero", {
  one_camera <- .infer_fixture()
  one_camera$effort_weekly <- dplyr::filter(
    one_camera$effort_weekly,
    camera_id == "cam_a"
  )
  one_camera$detections <- dplyr::filter(
    one_camera$detections,
    camera_id == "cam_a"
  )
  one <- .prepare_infer_fixture(one_camera)
  testthat::expect_identical(
    one$stan_data$Q,
    matrix(numeric(), nrow = 1L, ncol = 0L)
  )
  testthat::expect_identical(one$stan_data$B, 0L)

  sim <- simulate_flexirich_g(
    flexirich_sim_config(
      candidate_pool_size = 3L,
      true_richness = 2L,
      n_cameras = 3L,
      n_occasions = 2L,
      seed = 2110L
    )
  )
  data <- sim_to_flexirich_g_data(sim)
  expected <- stats::contr.helmert(3L)
  expected <- sweep(
    expected,
    2L,
    sqrt(colSums(expected^2)),
    "/"
  )

  testthat::expect_identical(data$stan_data$Q, expected)
  testthat::expect_equal(
    crossprod(data$stan_data$Q),
    diag(2L),
    tolerance = 1e-14
  )
  testthat::expect_equal(
    colSums(data$stan_data$Q),
    c(0, 0),
    tolerance = 1e-14
  )
})

testthat::test_that("audit arithmetic is exact and all-zero histories remain", {
  data <- .prepare_infer_fixture()

  testthat::expect_identical(
    data$audit,
    list(
      n_original_rows = 12L,
      n_sampled_rows = 9L,
      n_zero_effort_rows = 3L,
      n_grouped_rows = as.integer(nrow(data$grouped)),
      n_detections = 2L
    )
  )
  testthat::expect_identical(
    data$stan_data$detected_ever,
    c(1L, 1L, 0L)
  )
  testthat::expect_true("sp_c" %in% data$candidate_ids)
  testthat::expect_true("sp_c" %in% data$grouped$species_id)
  testthat::expect_identical(sum(data$grouped$n_trials), 9L)
  testthat::expect_identical(sum(data$grouped$n_detected), 2L)
})

testthat::test_that("future effort totals preserve the complete camera grid", {
  cameras <- c("cam_a", "cam_b")
  effort <- tidyr::expand_grid(
    camera_id = cameras,
    occasion_id = c("future_1", "future_2")
  ) |>
    dplyr::mutate(active_days = c(7L, 0L, 2L, 7L))

  testthat::expect_identical(
    .goal003_future_active_days(effort, cameras),
    c(cam_a = 7, cam_b = 9)
  )
  testthat::expect_error(
    .goal003_future_active_days(effort[-1L, ], cameras),
    "complete",
    fixed = TRUE
  )
  foreign <- effort
  foreign$camera_id[foreign$camera_id == "cam_b"] <- "cam_c"
  testthat::expect_error(
    .goal003_future_active_days(foreign, cameras),
    "exactly match",
    fixed = TRUE
  )
})

testthat::test_that("future effort aggregation belongs to inference data", {
  root <- if (dir.exists("R")) "." else file.path("..", "..")
  module <- new.env(parent = globalenv())
  sys.source(file.path(root, "R", "infer_data.R"), envir = module)

  testthat::expect_true(
    exists(".goal003_future_active_days", envir = module, inherits = FALSE)
  )
})

testthat::test_that("returned-object validation detects structural corruption", {
  data <- .prepare_infer_fixture()
  testthat::expect_true(validate_flexirich_g_data(data))

  corruptions <- list(
    no_class = unclass(data),
    extra_component = c(data, unexpected = list(TRUE)),
    leaked_attribute = structure(data, truth = list(member = TRUE)),
    unsorted_candidates = within(data, {
      candidate_ids <- rev(candidate_ids)
    }),
    bad_observed_schema = within(data, {
      observed$unexpected <- 1L
    }),
    bad_grouping = within(data, {
      grouped$n_trials[1L] <- grouped$n_trials[1L] + 1L
    }),
    bad_index = within(data, {
      stan_data$species_index[1L] <- stan_data$C + 1L
    }),
    bad_basis = within(data, {
      stan_data$Q[1L, 1L] <- 0
    }),
    bad_audit = within(data, {
      audit$n_sampled_rows <- audit$n_sampled_rows + 1L
    }),
    bad_hash = within(data, {
      data_hash <- paste0(substr(data_hash, 1L, 63L), "x")
    })
  )

  for (corrupted in corruptions) {
    testthat::expect_error(validate_flexirich_g_data(corrupted))
  }
})
