testthat::test_that("Goal004 nested data preserves independent named strata", {
  manifest <- read_goal004_task4_manifests()
  simulation <- simulate_goal004_task4_dataset(
    manifest$datasets[1L, ],
    manifest
  )
  data <- prepare_goal004_nested_data(simulation$training_data)
  mapping <- goal004_task2_candidate_mapping()

  testthat::expect_identical(data$core_ids, mapping$core$candidate_id)
  testthat::expect_identical(data$fringe_ids, mapping$fringe$candidate_id)
  testthat::expect_identical(length(data$candidate_ids), 106L)
  testthat::expect_identical(
    data$detected_ever[data$fringe_index],
    rep(0L, 56L)
  )
  testthat::expect_identical(
    data$stan_data$alpha_location[data$core_index],
    ifelse(
      mapping$core$encounter_class == "routine",
      log(0.002),
      log(0.0005)
    )
  )
  testthat::expect_identical(
    data$stan_data$alpha_location[data$fringe_index],
    ifelse(
      mapping$fringe$encounter_class == "routine",
      log(0.002),
      log(0.0002)
    )
  )
  testthat::expect_false(any(c(
    "truth", "member", "true_richness"
  ) %in% names(data)))
})

testthat::test_that("Goal004 nested R conditionals separate membership scales", {
  manifest <- read_goal004_task4_manifests()
  simulation <- simulate_goal004_task4_dataset(
    manifest$datasets[1L, ],
    manifest
  )
  data <- prepare_goal004_nested_data(simulation$training_data)
  alpha <- data$stan_data$alpha_location
  camera <- rep(0, length(data$camera_ids))
  result <- goal004_nested_conditionals(
    data,
    expected_core_members = 25,
    expected_fringe_members = 5,
    alpha = alpha,
    camera_effect = camera
  )

  testthat::expect_equal(result$omega_core, 0.5, tolerance = 0)
  testthat::expect_equal(result$omega_fringe, 5 / 56, tolerance = 0)
  testthat::expect_true(all(result$q_core >= 0 & result$q_core <= 1))
  testthat::expect_true(all(result$q_fringe >= 0 & result$q_fringe <= 1))
  testthat::expect_equal(
    result$expected_total_richness,
    result$expected_core_richness + result$expected_fringe_richness,
    tolerance = 1e-14
  )
})

testthat::test_that("Goal004 nested fringe prior is normalized and exact in mean", {
  pmf <- goal004_nested_fringe_prior_pmf()
  exact_mean <- 5 - 56 / expm1(56 / 5)

  testthat::expect_identical(pmf$richness, 0:56)
  testthat::expect_equal(sum(pmf$probability), 1, tolerance = 1e-13)
  testthat::expect_equal(
    sum(pmf$richness * pmf$probability),
    exact_mean,
    tolerance = 1e-8
  )
})

testthat::test_that("Goal004 nested draw summaries retain all three PMFs", {
  manifest <- read_goal004_task4_manifests()
  simulation <- simulate_goal004_task4_dataset(
    manifest$datasets[1L, ],
    manifest
  )
  data <- prepare_goal004_nested_data(simulation$training_data)
  detected <- data$detected_ever[data$core_index] == 1L
  q_core <- rbind(
    ifelse(detected, 1, 0.2),
    ifelse(detected, 1, 0.6)
  )
  q_fringe <- matrix(c(0.02, 0.08), nrow = 2L, ncol = 56L)
  result <- summarise_goal004_nested_draws(q_core, q_fringe, data)

  testthat::expect_equal(
    sum(result$core_richness_pmf$probability),
    1,
    tolerance = 1e-13
  )
  testthat::expect_equal(
    sum(result$fringe_richness_pmf$probability),
    1,
    tolerance = 1e-13
  )
  testthat::expect_equal(
    sum(result$total_richness_pmf$probability),
    1,
    tolerance = 1e-13
  )
  testthat::expect_identical(
    max(result$total_richness_pmf$richness),
    106L
  )
  testthat::expect_true(all(
    result$core_membership$membership_probability[detected] == 1
  ))
})

testthat::test_that("Goal004 nested Stan source fixes independent strata", {
  root <- if (dir.exists("R")) "." else file.path("..", "..")
  path <- file.path(root, "stan", "goal004_nested_flexirich.stan")
  testthat::expect_true(file.exists(path))
  if (!file.exists(path)) {
    return(invisible())
  }
  text <- paste(readLines(path, warn = FALSE), collapse = "\n")

  testthat::expect_match(text, "expected_core_members / C_core", fixed = TRUE)
  testthat::expect_match(text, "expected_fringe_members / C_fringe", fixed = TRUE)
  testthat::expect_match(text, "beta_lpdf", fixed = TRUE)
  testthat::expect_match(text, "exponential_lpdf", fixed = TRUE)
  testthat::expect_match(text, "vector[C_core] q_core", fixed = TRUE)
  testthat::expect_match(text, "vector[C_fringe] q_fringe", fixed = TRUE)
  testthat::expect_false(grepl("mu_alpha", text, fixed = TRUE))
  testthat::expect_false(grepl("sigma_alpha", text, fixed = TRUE))
  testthat::expect_false(grepl("bernoulli_rng", text, fixed = TRUE))
})
