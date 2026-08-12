testthat::test_that("FlexiRich profiles freeze the approved priors and sampler", {
  priors <- goal003_flexirich_prior_profiles()
  sampler <- goal003_flexirich_sampler_profiles()
  thresholds <- goal003_flexirich_diagnostic_thresholds()

  testthat::expect_identical(
    names(priors),
    c("primary", "membership_regularised", "mu_alpha_wide", "tail_wide")
  )
  primary <- priors$primary
  testthat::expect_equal(primary$omega_alpha, 1)
  testthat::expect_equal(primary$omega_beta, 1)
  testthat::expect_equal(primary$mu_alpha_location, log(0.02))
  testthat::expect_equal(primary$mu_alpha_scale, 1.5)
  testthat::expect_equal(primary$sigma_alpha_scale, 1)
  testthat::expect_equal(primary$sigma_camera_scale, 0.75)

  fields <- setdiff(names(primary), "profile_id")
  changed <- function(profile) {
    fields[!vapply(fields, function(field) {
      identical(profile[[field]], primary[[field]])
    }, logical(1))]
  }
  testthat::expect_identical(
    changed(priors$membership_regularised),
    c("omega_alpha", "omega_beta")
  )
  testthat::expect_identical(changed(priors$mu_alpha_wide), "mu_alpha_scale")
  testthat::expect_identical(changed(priors$tail_wide), "sigma_alpha_scale")
  testthat::expect_equal(priors$membership_regularised$omega_alpha, 2)
  testthat::expect_equal(priors$membership_regularised$omega_beta, 2)
  testthat::expect_equal(priors$mu_alpha_wide$mu_alpha_scale, 2)
  testthat::expect_equal(priors$tail_wide$sigma_alpha_scale, 1.5)

  testthat::expect_identical(sampler$primary$iter_warmup, 1000L)
  testthat::expect_identical(sampler$primary$iter_sampling, 1000L)
  testthat::expect_identical(sampler$rescue$iter_warmup, 1500L)
  testthat::expect_identical(sampler$rescue$iter_sampling, 1500L)
  testthat::expect_equal(sampler$rescue$adapt_delta, 0.999)
  testthat::expect_identical(sampler$rescue$max_treedepth, 15L)
  testthat::expect_equal(thresholds$max_rhat, 1.01)
})

testthat::test_that("FlexiRich adapter preserves canonical grouped data", {
  source <- .goal003_baseline_fixture()
  data <- prepare_goal003_flexirich_data(source)

  testthat::expect_identical(data$candidate_ids, source$candidate_ids)
  testthat::expect_identical(data$camera_ids, source$camera_ids)
  testthat::expect_identical(
    data$detected_ever,
    source$stan_data$detected_ever
  )
  testthat::expect_identical(data$stan_data$C, source$stan_data$C)
  testthat::expect_identical(data$stan_data$J, source$stan_data$J)
  testthat::expect_identical(data$stan_data$Q, source$stan_data$Q)
  testthat::expect_identical(
    data$stan_data$n_detected,
    source$stan_data$n_detected
  )
  testthat::expect_match(data$data_hash, "^[0-9a-f]{64}$")

  sensitivity <- prepare_goal003_flexirich_data(source, "tail_wide")
  testthat::expect_false(identical(data$data_hash, sensitivity$data_hash))
  testthat::expect_identical(
    data$stan_data$sigma_alpha_scale,
    1
  )
  testthat::expect_identical(
    sensitivity$stan_data$sigma_alpha_scale,
    1.5
  )

  corrupted <- data
  corrupted$stan_data$n_trials[[1L]] <-
    corrupted$stan_data$n_trials[[1L]] + 1L
  testthat::expect_error(
    .validate_goal003_flexirich_data(corrupted),
    "canonical",
    fixed = TRUE
  )
  corrupted <- data
  corrupted$data_hash <- paste0(rep("0", 64L), collapse = "")
  testthat::expect_error(
    .validate_goal003_flexirich_data(corrupted),
    "canonical",
    fixed = TRUE
  )
})

testthat::test_that("FlexiRich conditionals match exhaustive membership ratios", {
  data <- prepare_goal003_flexirich_data(.goal003_baseline_fixture())
  alpha <- seq(log(0.005), log(0.08), length.out = 8L)
  camera_effect <- c(-0.2, 0.2)
  omega <- 0.37
  out <- goal003_flexirich_conditionals(
    data,
    omega,
    alpha,
    camera_effect
  )
  all_zero <- data$detected_ever == 0L
  expected <- omega * exp(out$member_ll[all_zero]) /
    ((1 - omega) + omega * exp(out$member_ll[all_zero]))

  testthat::expect_identical(
    unname(out$q_member[!all_zero]),
    rep(1, sum(!all_zero))
  )
  testthat::expect_equal(
    unname(out$q_member[all_zero]),
    unname(expected),
    tolerance = 1e-13
  )
  testthat::expect_equal(
    out$expected_richness,
    sum(out$q_member),
    tolerance = 1e-14
  )
})

testthat::test_that("FlexiRich conditionals remain bounded at extreme hazards", {
  data <- prepare_goal003_flexirich_data(.goal003_baseline_fixture())
  for (alpha in list(rep(-700, 8L), rep(700, 8L))) {
    out <- goal003_flexirich_conditionals(
      data,
      omega = 0.2,
      alpha = alpha,
      camera_effect = c(0, 0)
    )
    testthat::expect_false(any(is.nan(out$member_ll)))
    testthat::expect_true(all(out$q_member >= 0 & out$q_member <= 1))
  }
  testthat::expect_error(
    goal003_flexirich_conditionals(
      data,
      omega = 0.2,
      alpha = rep(log(0.02), 8L),
      camera_effect = c(0, 0.1)
    ),
    "camera effect",
    fixed = TRUE
  )
})

testthat::test_that("Goal003 Stan source marginalises membership without RNG", {
  root <- if (dir.exists("R")) "." else file.path("..", "..")
  path <- file.path(root, "stan", "goal003_flexirich.stan")
  testthat::expect_true(file.exists(path))
  if (!file.exists(path)) {
    return(invisible())
  }
  text <- paste(readLines(path, warn = FALSE), collapse = "\n")

  testthat::expect_match(text, "log_mix")
  testthat::expect_match(text, "matrix\\[J, B\\] Q")
  testthat::expect_match(text, "vector\\[C\\] q_member")
  testthat::expect_match(text, "expected_richness")
  testthat::expect_false(grepl("bernoulli_rng", text, fixed = TRUE))
  testthat::expect_false(grepl("binomial_rng", text, fixed = TRUE))
  testthat::expect_false(grepl("y_rep", text, fixed = TRUE))
})

testthat::test_that("FlexiRich draw summaries give exact richness and discovery PMFs", {
  q <- rbind(c(1, 0.2), c(1, 0.6))
  alpha <- matrix(log(0.1), nrow = 2L, ncol = 2L)
  camera <- matrix(0, nrow = 2L, ncol = 2L)
  out <- summarise_goal003_flexirich_draws(
    q_member_draws = q,
    alpha_draws = alpha,
    camera_effect_draws = camera,
    candidate_ids = c("seen", "unseen"),
    camera_ids = c("cam_a", "cam_b"),
    detected_ever = c(1L, 0L),
    future_active_days = c(cam_a = 7, cam_b = 0)
  )

  testthat::expect_identical(out$richness_pmf$richness, 0:2)
  testthat::expect_equal(
    out$richness_pmf$probability,
    c(0, 0.6, 0.4),
    tolerance = 1e-14
  )
  encounter <- -expm1(-0.7)
  expected_discovery <- mean(c(0.2, 0.6) * encounter)
  testthat::expect_equal(
    out$new_species_count_pmf$probability,
    c(1 - expected_discovery, expected_discovery),
    tolerance = 1e-14
  )
  testthat::expect_identical(
    names(out$new_species_count_pmf),
    c("new_species_count", "probability")
  )
  testthat::expect_equal(
    out$future_identity$future_first_detection_probability,
    c(0, expected_discovery),
    tolerance = 1e-14
  )
  testthat::expect_equal(
    out$grid_identity$membership_probability,
    c(1, 0.4),
    tolerance = 1e-14
  )
})

testthat::test_that("FlexiRich discovery uses every camera and respects zero effort", {
  q <- matrix(c(1, 0.5), nrow = 1L)
  alpha <- matrix(log(c(0.02, 0.03)), nrow = 1L)
  camera <- matrix(c(-0.2, 0.2), nrow = 1L)
  common <- list(
    q_member_draws = q,
    alpha_draws = alpha,
    camera_effect_draws = camera,
    candidate_ids = c("seen", "unseen"),
    camera_ids = c("cam_a", "cam_b"),
    detected_ever = c(1L, 0L)
  )
  zero <- do.call(
    summarise_goal003_flexirich_draws,
    c(common, list(future_active_days = c(cam_a = 0, cam_b = 0)))
  )
  active <- do.call(
    summarise_goal003_flexirich_draws,
    c(common, list(future_active_days = c(cam_a = 7, cam_b = 14)))
  )
  hazard <- 7 * exp(log(0.03) - 0.2) +
    14 * exp(log(0.03) + 0.2)
  expected <- 0.5 * (-expm1(-hazard))

  testthat::expect_identical(
    zero$new_species_count_pmf$probability,
    c(1, 0)
  )
  testthat::expect_equal(
    active$future_identity$future_first_detection_probability,
    c(0, expected),
    tolerance = 1e-14
  )
})

testthat::test_that("FlexiRich posterior summaries reject malformed draws", {
  q <- matrix(c(1, 0.5), nrow = 1L)
  alpha <- matrix(log(c(0.02, 0.03)), nrow = 1L)
  camera <- matrix(c(-0.2, 0.2), nrow = 1L)
  arguments <- list(
    q_member_draws = q,
    alpha_draws = alpha,
    camera_effect_draws = camera,
    candidate_ids = c("seen", "unseen"),
    camera_ids = c("cam_a", "cam_b"),
    detected_ever = c(1L, 0L),
    future_active_days = c(cam_a = 7, cam_b = 7)
  )
  broken <- arguments
  broken$q_member_draws[1L, 2L] <- NA_real_
  testthat::expect_error(
    do.call(summarise_goal003_flexirich_draws, broken),
    "invalid contract",
    fixed = TRUE
  )
  broken <- arguments
  broken$future_active_days <- c(cam_a = 7)
  testthat::expect_error(
    do.call(summarise_goal003_flexirich_draws, broken),
    "camera_ids order",
    fixed = TRUE
  )
})

testthat::test_that("FlexiRich monitors every frozen scientific parameter", {
  data <- prepare_goal003_flexirich_data(.goal003_baseline_fixture())
  testthat::expect_identical(
    .goal003_flexirich_monitored_variables(data),
    c(
      "omega", "mu_alpha", "sigma_alpha", "sigma_camera",
      "expected_richness", "alpha", "camera_effect"
    )
  )
})

testthat::test_that("FlexiRich output directories are new and Goal003-local", {
  root <- .goal003_project_root()
  path <- file.path(
    "outputs",
    "goal003",
    paste0("test-flexirich-output-", Sys.getpid())
  )
  absolute <- file.path(root, path)
  unlink(absolute, recursive = TRUE, force = TRUE)
  on.exit(unlink(absolute, recursive = TRUE, force = TRUE), add = TRUE)

  testthat::expect_identical(
    .goal003_prepare_output_directory(path),
    normalizePath(absolute, mustWork = TRUE)
  )
  testthat::expect_error(
    .goal003_prepare_output_directory(path),
    "must not already exist",
    fixed = TRUE
  )
  testthat::expect_error(
    .goal003_prepare_output_directory(tempfile()),
    "beneath outputs/goal003",
    fixed = TRUE
  )
})

testthat::test_that("non-clean FlexiRich results cannot produce predictions", {
  data <- prepare_goal003_flexirich_data(.goal003_baseline_fixture())
  result <- list(
    terminal_status = "final_nonclean",
    data = data,
    prior = goal003_flexirich_prior_profiles()$primary,
    output_dir = "unused",
    attempts = list(primary = list(fit = NULL))
  )
  testthat::expect_error(
    predict_goal003_flexirich(result),
    "terminal-clean",
    fixed = TRUE
  )
})

testthat::test_that("FlexiRich prior prediction is reproducible and coherent", {
  first <- simulate_goal003_flexirich_prior(
    profile_id = "primary",
    n_draws = 40L,
    seed = 30030L,
    candidate_pool_size = 12L,
    n_cameras = 3L
  )
  second <- simulate_goal003_flexirich_prior(
    profile_id = "primary",
    n_draws = 40L,
    seed = 30030L,
    candidate_pool_size = 12L,
    n_cameras = 3L
  )

  testthat::expect_identical(first, second)
  testthat::expect_identical(
    names(first),
    c("profile_id", "draws", "distribution_summary", "invariants")
  )
  testthat::expect_true(all(
    first$draws$observed_richness_4 <=
      first$draws$observed_richness_26
  ))
  testthat::expect_true(all(
    first$draws$observed_richness_26 <= first$draws$true_richness
  ))
  testthat::expect_true(all(first$invariants$passed))
  testthat::expect_lt(
    first$invariants$value[
      first$invariants$invariant == "max_abs_camera_effect_sum"
    ],
    1e-12
  )
})

testthat::test_that("prior prediction uses only frozen profiles", {
  primary <- simulate_goal003_flexirich_prior(
    profile_id = "primary",
    n_draws = 5L,
    seed = 1L,
    candidate_pool_size = 4L,
    n_cameras = 1L
  )
  testthat::expect_identical(
    primary$profile_id,
    goal003_flexirich_prior_profiles()$primary$profile_id
  )
  testthat::expect_error(
    simulate_goal003_flexirich_prior(
      profile_id = "unknown",
      n_draws = 5L,
      seed = 1L
    ),
    "profile_id",
    fixed = TRUE
  )
})

testthat::test_that("Task 3 runners exclude empirical Judbury outcomes", {
  root <- if (dir.exists("R")) "." else file.path("..", "..")
  paths <- file.path(
    root,
    "scripts",
    c(
      "run_goal003_flexirich_prior_check.R",
      "run_goal003_flexirich_smoke.R"
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
  testthat::expect_false(grepl("run_goal003_baselines", text, fixed = TRUE))
  testthat::expect_false(grepl("prospective", text, fixed = TRUE))
})
