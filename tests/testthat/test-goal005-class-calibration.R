.goal005_test_classes <- function(candidate_ids) {
  stats::setNames(
    rep(c("routine", "occasional"), length.out = length(candidate_ids)),
    candidate_ids
  )
}

.goal005_test_locations <- c(
  routine = log(0.0021),
  occasional = log(0.00045)
)

testthat::test_that("Goal005 class calibration freezes only external summaries", {
  source <- .goal003_baseline_fixture()
  classes <- .goal005_test_classes(source$candidate_ids)
  data <- prepare_goal005_class_calibration_data(
    source,
    classes,
    .goal005_test_locations,
    calibration_sd = 0.2
  )

  testthat::expect_identical(data$candidate_ids, source$candidate_ids)
  testthat::expect_identical(data$encounter_class, unname(classes))
  testthat::expect_identical(
    data$class_index,
    as.integer(match(unname(classes), c("routine", "occasional")))
  )
  testthat::expect_identical(data$location_estimate, .goal005_test_locations)
  testthat::expect_equal(data$calibration_sd, 0.2, tolerance = 0)
  testthat::expect_false(any(c(
    "truth", "member", "true_richness", "alpha_fixed"
  ) %in% names(data)))

  changed <- prepare_goal005_class_calibration_data(
    source,
    classes,
    .goal005_test_locations + c(0.01, 0),
    calibration_sd = 0.2
  )
  testthat::expect_false(identical(data$data_hash, changed$data_hash))
  testthat::expect_error(
    prepare_goal005_class_calibration_data(
      source,
      classes,
      .goal005_test_locations,
      calibration_sd = 0
    ),
    "positive calibration SD",
    fixed = TRUE
  )

  corrupted <- data
  corrupted$location_estimate[[1L]] <- corrupted$location_estimate[[1L]] + 0.1
  testthat::expect_error(
    .validate_goal005_class_calibration_data(corrupted),
    "canonical",
    fixed = TRUE
  )
})

testthat::test_that("Goal005 class conditionals retain the proven likelihood", {
  source <- .goal003_baseline_fixture()
  classes <- .goal005_test_classes(source$candidate_ids)
  calibrated <- prepare_goal005_class_calibration_data(
    source,
    classes,
    .goal005_test_locations,
    calibration_sd = 0.2
  )
  fixed <- prepare_goal004_flexirich_data(source, classes)
  alpha <- seq(log(0.0005), log(0.004), length.out = 8L)
  camera <- c(-0.2, 0.2)

  observed <- goal005_class_calibration_conditionals(
    calibrated,
    expected_core_members = 3.2,
    alpha = alpha,
    camera_effect = camera
  )
  expected <- goal004_flexirich_conditionals(
    fixed,
    expected_core_members = 3.2,
    alpha = alpha,
    camera_effect = camera
  )
  testthat::expect_equal(observed$member_ll, expected$member_ll, tolerance = 0)
  testthat::expect_equal(observed$q_member, expected$q_member, tolerance = 0)
  testthat::expect_equal(
    observed$expected_richness,
    expected$expected_richness,
    tolerance = 0
  )
})

testthat::test_that("Goal005 class-calibration Stan source has only two new locations", {
  root <- if (dir.exists("R")) "." else file.path("..", "..")
  path <- file.path(root, "stan", "goal005_class_calibration.stan")
  testthat::expect_true(file.exists(path))
  if (!file.exists(path)) {
    return(invisible())
  }
  text <- paste(readLines(path, warn = FALSE), collapse = "\n")

  testthat::expect_match(text, "vector[2] class_location", fixed = TRUE)
  testthat::expect_match(
    text,
    "class_location ~ normal(location_estimate, calibration_sd)",
    fixed = TRUE
  )
  testthat::expect_match(
    text,
    "alpha[i] ~ normal(class_location[class_index[i]], log_rate_sd)",
    fixed = TRUE
  )
  testthat::expect_match(text, "expected_core_members / C", fixed = TRUE)
  testthat::expect_match(text, "vector[C] q_member", fixed = TRUE)
  testthat::expect_false(grepl("ordered[", text, fixed = TRUE))
  testthat::expect_false(grepl("bernoulli_rng", text, fixed = TRUE))
})
