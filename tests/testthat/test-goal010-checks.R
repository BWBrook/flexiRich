testthat::test_that("spatial mathematical checks preserve fixed species and array rates", {
  out <- goal010_theory_checks(.goal003_baseline_fixture())
  testthat::expect_true(all(out$absolute_error < 1e-10))
  testthat::expect_true("decomposition_shift_ll_error" %in% out$check)
})

testthat::test_that("paired controls change only the fixed interaction mechanism", {
  cases <- goal010_synthetic_cases()
  testthat::expect_identical(cases, goal010_synthetic_cases())
  for (field in c("alpha", "camera_effect", "membership", "richness", "seed")) {
    testthat::expect_identical(cases$zero$truth[[field]], cases$cross$truth[[field]])
  }
  testthat::expect_equal(cases$zero$truth$richness, 6)
  testthat::expect_true(all(cases$zero$truth$interaction == 0))
  testthat::expect_equal(rowSums(cases$cross$truth$interaction), rep(0,8))
  testthat::expect_identical(cases$zero$data$observed$active_days,
                             cases$cross$data$observed$active_days)
  testthat::expect_false(identical(cases$zero$data$observed$detected,
                                  cases$cross$data$observed$detected))
  for (case in cases) {
    absent <- case$data$candidate_ids[case$truth$membership == 0]
    y <- case$data$observed$detected[case$data$observed$species_id %in% absent]
    testthat::expect_true(all(y[!is.na(y)] == 0))
  }
})

testthat::test_that("prior comparisons preserve caller RNG and use paired membership", {
  source <- .goal003_baseline_fixture()
  withr::with_seed(900L, {
    before <- .Random.seed
    out <- goal010_prior_predictive(source, n_draws=12L, seed=902L)
    testthat::expect_identical(.Random.seed, before)
    testthat::expect_true(all(out$mean_member_detection_probability >= 0 &
                              out$mean_member_detection_probability <= 1))
    testthat::expect_true(all(out$detected_richness <= out$latent_richness))
    split_richness <- split(out$latent_richness,
                            interaction(out$prior_id,out$interaction_scale))
    testthat::expect_true(all(vapply(split_richness,identical,logical(1),
                                    split_richness[[1]])))
    testthat::expect_identical(out, goal010_prior_predictive(source,12L,902L))
  }, .rng_kind="L'Ecuyer-CMRG")
})
