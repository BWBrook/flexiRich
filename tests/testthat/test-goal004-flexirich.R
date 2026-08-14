.goal004_test_classes <- function(candidate_ids) {
  stats::setNames(
    rep(c("routine", "occasional"), length.out = length(candidate_ids)),
    candidate_ids
  )
}

testthat::test_that("Goal004 maps the frozen core and one-factor profiles", {
  mapping <- goal004_task2_candidate_mapping()$core
  profiles <- read_goal004_task2_profiles()

  testthat::expect_identical(nrow(mapping), 50L)
  testthat::expect_identical(
    as.integer(table(mapping$encounter_class)[c("routine", "occasional")]),
    c(44L, 6L)
  )
  testthat::expect_identical(
    profiles$profile_id,
    c(
      "primary", "rate_lower", "rate_higher", "spread_wider",
      "class_blur", "membership_regularised"
    )
  )
  primary <- goal004_flexirich_profile("primary")
  testthat::expect_equal(primary$omega_alpha, 1)
  testthat::expect_equal(primary$omega_beta, 1)
  testthat::expect_equal(primary$routine_median_rate, 0.002)
  testthat::expect_equal(primary$occasional_median_rate, 0.0005)
  testthat::expect_equal(primary$log_rate_sd, 1)
  testthat::expect_equal(primary$camera_sd_scale, 0.75)

  compared_fields <- c(
    "omega_alpha", "omega_beta", "routine_median_rate",
    "occasional_median_rate", "log_rate_sd", "class_blur_probability",
    "camera_sd_scale"
  )
  changed_groups <- lapply(profiles$profile_id[-1L], function(profile_id) {
    profile <- goal004_flexirich_profile(profile_id)
    compared_fields[!vapply(compared_fields, function(field) {
      identical(profile[[field]], primary[[field]])
    }, logical(1))]
  })
  testthat::expect_identical(
    changed_groups,
    list(
      c("routine_median_rate", "occasional_median_rate"),
      c("routine_median_rate", "occasional_median_rate"),
      "log_rate_sd",
      "class_blur_probability",
      c("omega_alpha", "omega_beta")
    )
  )
})

testthat::test_that("Goal004 adapter freezes classes, profile, and hashes", {
  source <- .goal003_baseline_fixture()
  classes <- .goal004_test_classes(source$candidate_ids)
  primary <- prepare_goal004_flexirich_data(source, classes)
  blur <- prepare_goal004_flexirich_data(source, classes, "class_blur")

  testthat::expect_identical(primary$candidate_ids, source$candidate_ids)
  testthat::expect_identical(primary$camera_ids, source$camera_ids)
  testthat::expect_identical(primary$encounter_class, unname(classes))
  testthat::expect_identical(
    primary$routine_weight,
    as.numeric(unname(classes) == "routine")
  )
  testthat::expect_equal(
    blur$routine_weight,
    ifelse(unname(classes) == "routine", 0.9, 0.1),
    tolerance = 0
  )
  testthat::expect_false(identical(primary$data_hash, blur$data_hash))
  testthat::expect_false(any(c(
    "mu_alpha_location", "mu_alpha_scale", "sigma_alpha_scale"
  ) %in% names(primary$stan_data)))

  changed_classes <- classes
  changed_classes[[1L]] <- if (classes[[1L]] == "routine") {
    "occasional"
  } else {
    "routine"
  }
  changed <- prepare_goal004_flexirich_data(source, changed_classes)
  testthat::expect_false(identical(primary$data_hash, changed$data_hash))

  corrupted <- primary
  corrupted$routine_weight[[1L]] <- 0.5
  testthat::expect_error(
    .validate_goal004_flexirich_data(corrupted),
    "canonical",
    fixed = TRUE
  )
  testthat::expect_error(
    prepare_goal004_flexirich_data(source, unname(classes)),
    "named routine/occasional",
    fixed = TRUE
  )
})

testthat::test_that("Goal004 accepts a canonical zero-effort dataset", {
  candidates <- tibble::tibble(species_id = paste0("sp_", 1:4))
  effort <- tidyr::expand_grid(
    camera_id = c("cam_a", "cam_b"),
    occasion_id = c("week_1", "week_2")
  ) |>
    dplyr::mutate(active_days = 0L)
  detections <- tidyr::expand_grid(
    species_id = candidates$species_id,
    camera_id = c("cam_a", "cam_b"),
    occasion_id = c("week_1", "week_2")
  ) |>
    dplyr::mutate(detected = NA_integer_)
  source <- prepare_flexirich_g_data(candidates, effort, detections)
  classes <- .goal004_test_classes(source$candidate_ids)
  data <- prepare_goal004_flexirich_data(source, classes)

  testthat::expect_identical(data$stan_data$C, 4L)
  testthat::expect_identical(data$stan_data$G, 0L)
  testthat::expect_identical(data$detected_ever, rep(0L, 4L))
})

testthat::test_that("Goal004 R conditionals use count-scale membership", {
  source <- .goal003_baseline_fixture()
  data <- prepare_goal004_flexirich_data(
    source,
    .goal004_test_classes(source$candidate_ids)
  )
  alpha <- seq(log(0.0005), log(0.004), length.out = 8L)
  camera_effect <- c(-0.2, 0.2)
  result <- goal004_flexirich_conditionals(
    data,
    expected_core_members = 3.2,
    alpha = alpha,
    camera_effect = camera_effect
  )

  testthat::expect_equal(result$omega, 0.4, tolerance = 0)
  testthat::expect_identical(
    unname(result$q_member[data$detected_ever == 1L]),
    rep(1, sum(data$detected_ever == 1L))
  )
  testthat::expect_true(all(result$q_member >= 0 & result$q_member <= 1))
  testthat::expect_equal(
    result$expected_richness,
    sum(result$q_member),
    tolerance = 1e-14
  )
})

testthat::test_that("Goal004 Stan source has only the frozen model structure", {
  root <- if (dir.exists("R")) "." else file.path("..", "..")
  path <- file.path(root, "stan", "goal004_flexirich.stan")
  testthat::expect_true(file.exists(path))
  if (!file.exists(path)) {
    return(invisible())
  }
  text <- paste(readLines(path, warn = FALSE), collapse = "\n")

  testthat::expect_match(text, "expected_core_members / C", fixed = TRUE)
  testthat::expect_match(text, "beta_lpdf(omega", fixed = TRUE)
  testthat::expect_match(text, "- log(C)", fixed = TRUE)
  testthat::expect_match(text, "routine_weight[i] == 1", fixed = TRUE)
  testthat::expect_match(text, "routine_weight[i] == 0", fixed = TRUE)
  testthat::expect_match(text, "log_mix")
  testthat::expect_match(text, "vector[C] q_member", fixed = TRUE)
  testthat::expect_false(grepl("mu_alpha", text, fixed = TRUE))
  testthat::expect_false(grepl("sigma_alpha", text, fixed = TRUE))
  testthat::expect_false(grepl("z_alpha", text, fixed = TRUE))
  testthat::expect_false(grepl("bernoulli_rng", text, fixed = TRUE))
  testthat::expect_false(grepl("binomial_rng", text, fixed = TRUE))
})

testthat::test_that("Goal004 draw summaries expose prior and posterior PMFs", {
  source <- .goal003_baseline_fixture()
  data <- prepare_goal004_flexirich_data(
    source,
    .goal004_test_classes(source$candidate_ids)
  )
  detected <- data$detected_ever == 1L
  q <- rbind(
    ifelse(detected, 1, 0.2),
    ifelse(detected, 1, 0.6)
  )
  alpha <- matrix(log(0.002), nrow = 2L, ncol = 8L)
  camera <- matrix(0, nrow = 2L, ncol = 2L)
  result <- summarise_goal004_flexirich_draws(
    q_member_draws = q,
    alpha_draws = alpha,
    camera_effect_draws = camera,
    data = data,
    future_active_days = c(cam_a = 7, cam_b = 0)
  )

  testthat::expect_identical(
    names(result),
    c(
      "posterior_richness_pmf", "posterior_richness_summary",
      "prior_richness_pmf", "prior_richness_summary",
      "candidate_membership", "future_discovery_pmf", "future_identity"
    )
  )
  testthat::expect_equal(
    sum(result$posterior_richness_pmf$probability),
    1,
    tolerance = 1e-14
  )
  testthat::expect_equal(
    sum(result$prior_richness_pmf$probability),
    1,
    tolerance = 1e-14
  )
  testthat::expect_equal(
    sum(result$future_discovery_pmf$probability),
    1,
    tolerance = 1e-14
  )
  testthat::expect_equal(
    result$prior_richness_summary$mean,
    4,
    tolerance = 1e-13
  )
  testthat::expect_true(all(
    result$candidate_membership$posterior_membership_probability[detected] == 1
  ))
  testthat::expect_equal(
    goal004_total_variation(c(0.5, 0.5), c(0.25, 0.75)),
    0.25,
    tolerance = 0
  )
})

testthat::test_that("Goal004 output remains in its own namespace", {
  root <- .goal003_project_root()
  path <- file.path(
    "outputs",
    "goal004",
    paste0("test-output-", Sys.getpid())
  )
  absolute <- file.path(root, path)
  unlink(absolute, recursive = TRUE, force = TRUE)
  on.exit(unlink(absolute, recursive = TRUE, force = TRUE), add = TRUE)

  testthat::expect_identical(
    .goal003_prepare_output_directory(path, "goal004"),
    normalizePath(absolute, mustWork = TRUE)
  )
  testthat::expect_error(
    .goal003_prepare_output_directory(
      file.path("outputs", "goal003", "wrong-namespace"),
      "goal004"
    ),
    "beneath outputs/goal004",
    fixed = TRUE
  )
})

testthat::test_that("Goal004 Task 3 runners cannot access empirical outcomes", {
  root <- if (dir.exists("R")) "." else file.path("..", "..")
  paths <- file.path(
    root,
    "scripts",
    c(
      "check_goal004_flexirich_model.R",
      "check_goal004_prior_concordance.R",
      "run_goal004_flexirich_smoke.R"
    )
  )
  testthat::expect_true(all(file.exists(paths)))
  if (!all(file.exists(paths))) {
    return(invisible())
  }
  text <- tolower(paste(
    unlist(lapply(paths, readLines, warn = FALSE)),
    collapse = "\n"
  ))
  testthat::expect_false(grepl("judbury_inputs", text, fixed = TRUE))
  testthat::expect_false(grepl("goal003_task4_screen", text, fixed = TRUE))
  testthat::expect_false(grepl("huon", text, fixed = TRUE))
})
