.goal005_test_rates <- function(candidate_ids) {
  stats::setNames(
    seq(log(0.0004), log(0.004), length.out = length(candidate_ids)),
    candidate_ids
  )
}

testthat::test_that("Goal005 candidate-oracle data freezes exact named rates", {
  source <- .goal003_baseline_fixture()
  rates <- .goal005_test_rates(source$candidate_ids)
  data <- prepare_goal005_candidate_oracle_data(source, rates)

  testthat::expect_identical(data$candidate_ids, source$candidate_ids)
  testthat::expect_identical(data$camera_ids, source$camera_ids)
  testthat::expect_identical(data$alpha_fixed, unname(rates))
  testthat::expect_identical(data$stan_data$alpha_fixed, unname(rates))
  testthat::expect_identical(data$oracle_id, "candidate_rate_exact_v1")
  testthat::expect_false(any(c(
    "truth", "member", "true_richness"
  ) %in% names(data)))

  changed_rates <- rates
  changed_rates[[1L]] <- changed_rates[[1L]] + 0.1
  changed <- prepare_goal005_candidate_oracle_data(source, changed_rates)
  testthat::expect_false(identical(data$data_hash, changed$data_hash))

  corrupted <- data
  corrupted$alpha_fixed[[1L]] <- corrupted$alpha_fixed[[1L]] + 0.1
  testthat::expect_error(
    .validate_goal005_candidate_oracle_data(corrupted),
    "canonical",
    fixed = TRUE
  )
  testthat::expect_error(
    prepare_goal005_candidate_oracle_data(source, unname(rates)),
    "named",
    fixed = TRUE
  )
})

testthat::test_that("Goal005 candidate oracle accepts zero effort", {
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
  data <- prepare_goal005_candidate_oracle_data(
    source,
    stats::setNames(rep(log(0.002), 4L), candidates$species_id)
  )

  testthat::expect_identical(data$stan_data$G, 0L)
  testthat::expect_identical(data$detected_ever, rep(0L, 4L))
})

testthat::test_that("Goal005 fixed-rate conditionals match Goal004", {
  source <- .goal003_baseline_fixture()
  rates <- .goal005_test_rates(source$candidate_ids)
  oracle <- prepare_goal005_candidate_oracle_data(source, rates)
  classes <- stats::setNames(
    rep(c("routine", "occasional"), length.out = length(source$candidate_ids)),
    source$candidate_ids
  )
  goal004 <- prepare_goal004_flexirich_data(source, classes)
  camera_effect <- c(-0.2, 0.2)

  observed <- goal005_candidate_oracle_conditionals(
    oracle,
    expected_core_members = 3.2,
    camera_effect = camera_effect
  )
  expected <- goal004_flexirich_conditionals(
    goal004,
    expected_core_members = 3.2,
    alpha = unname(rates),
    camera_effect = camera_effect
  )

  testthat::expect_equal(observed$omega, expected$omega, tolerance = 0)
  testthat::expect_equal(
    observed$member_ll,
    expected$member_ll,
    tolerance = 1e-14
  )
  testthat::expect_equal(
    observed$q_member,
    expected$q_member,
    tolerance = 1e-14
  )
  testthat::expect_equal(
    observed$expected_richness,
    expected$expected_richness,
    tolerance = 1e-14
  )
})

testthat::test_that("Goal005 candidate-oracle Stan source fixes alpha as data", {
  root <- if (dir.exists("R")) "." else file.path("..", "..")
  path <- file.path(root, "stan", "goal005_candidate_oracle.stan")
  testthat::expect_true(file.exists(path))
  if (!file.exists(path)) {
    return(invisible())
  }
  text <- paste(readLines(path, warn = FALSE), collapse = "\n")

  testthat::expect_match(text, "vector[C] alpha_fixed", fixed = TRUE)
  testthat::expect_match(text, "expected_core_members / C", fixed = TRUE)
  testthat::expect_match(text, "beta_lpdf(omega", fixed = TRUE)
  testthat::expect_match(text, "vector[C] q_member", fixed = TRUE)
  testthat::expect_false(grepl("vector[C] alpha;", text, fixed = TRUE))
  testthat::expect_false(grepl("alpha_fixed ~", text, fixed = TRUE))
  testthat::expect_false(grepl("bernoulli_rng", text, fixed = TRUE))
})

testthat::test_that("Goal005 candidate-oracle summaries retain exact rates", {
  source <- .goal003_baseline_fixture()
  rates <- .goal005_test_rates(source$candidate_ids)
  data <- prepare_goal005_candidate_oracle_data(source, rates)
  detected <- data$detected_ever == 1L
  q <- rbind(
    ifelse(detected, 1, 0.2),
    ifelse(detected, 1, 0.6)
  )
  camera <- matrix(0, nrow = 2L, ncol = 2L)
  result <- summarise_goal005_candidate_oracle_draws(
    q_member_draws = q,
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
    result$prior_richness_summary$mean,
    4,
    tolerance = 1e-13
  )
  testthat::expect_equal(
    result$candidate_membership$alpha_fixed,
    unname(rates),
    tolerance = 0
  )
  testthat::expect_true(all(
    result$candidate_membership$posterior_membership_probability[detected] == 1
  ))
})
