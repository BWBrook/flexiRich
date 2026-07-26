.make_goal002_rule_fixture <- function(n_draws = 200L) {
  effort <- goal002_prior_effort(seed = 2601L)
  draws <- simulate_goal002_prior(
    goal002_prior_profiles()$primary,
    effort = effort,
    n_draws = n_draws,
    seed = 2602L
  )

  richness <- rep(seq.int(2L, 29L), length.out = n_draws)
  observed_26 <- 1L + (seq_len(n_draws) %% pmax(richness - 1L, 1L))
  observed_26 <- pmin(observed_26, richness - 1L)
  observed_208 <- pmin(
    richness,
    observed_26 + as.integer(seq_len(n_draws) %% 2L)
  )

  draws$richness <- as.integer(richness)
  draws$observed_26 <- as.integer(observed_26)
  draws$observed_208 <- as.integer(observed_208)
  draws
}

.failed_goal002_rules <- function(draws) {
  assessment <- assess_goal002_prior(draws)
  assessment$rules$rule_id[!assessment$rules$passed]
}

testthat::test_that("prior effort is the frozen Goal 001 208-occasion history", {
  effort <- goal002_prior_effort(seed = 2601L)

  testthat::expect_s3_class(effort, "goal002_prior_effort")
  testthat::expect_named(effort, c(
    "schema_version", "seed", "candidate_pool_size", "n_cameras",
    "n_occasions", "prefix_occasions", "occasion_days", "effort_hash",
    "effort_weekly"
  ))
  testthat::expect_identical(effort$seed, 2601L)
  testthat::expect_identical(effort$candidate_pool_size, 30L)
  testthat::expect_identical(effort$n_cameras, 9L)
  testthat::expect_identical(effort$n_occasions, 208L)
  testthat::expect_identical(effort$prefix_occasions, 26L)
  testthat::expect_identical(effort$occasion_days, 7L)
  testthat::expect_match(effort$effort_hash, "^[0-9a-f]{64}$")
  testthat::expect_equal(nrow(effort$effort_weekly), 9L * 208L)
  testthat::expect_identical(
    unique(effort$effort_weekly$camera_id),
    sprintf("cam_%02d", seq_len(9L))
  )
  testthat::expect_identical(
    unique(effort$effort_weekly$occasion_id),
    sprintf("occ_%03d", seq_len(208L))
  )
  testthat::expect_true(validate_goal002_prior_effort(effort))
  testthat::expect_identical(
    goal002_prior_effort(seed = 2601L),
    effort
  )
})

testthat::test_that("prior histories are nested, bounded, and fully retained", {
  effort <- goal002_prior_effort(seed = 2601L)
  draws <- simulate_goal002_prior(
    goal002_prior_profiles()$primary,
    effort = effort,
    n_draws = 200L,
    seed = 2602L
  )

  testthat::expect_s3_class(draws, "goal002_prior_draws")
  testthat::expect_true(all(draws$observed_26 <= draws$observed_208))
  testthat::expect_true(all(draws$observed_208 <= draws$richness))
  testthat::expect_true(all(draws$richness <= 30L))
  testthat::expect_false(anyNA(draws))
  testthat::expect_true(all(is.finite(draws$log_likelihood_26)))
  testthat::expect_true(all(is.finite(draws$log_likelihood_208)))
  testthat::expect_identical(dim(draws$eta), c(200L, 30L, 9L))
  testthat::expect_identical(dim(draws$rate), c(200L, 30L, 9L))
  testthat::expect_identical(dim(draws$p1), c(200L, 30L, 9L))
  testthat::expect_identical(dim(draws$p7), c(200L, 30L, 9L))
  testthat::expect_identical(dim(draws$detect_probability_26), c(200L, 30L))
  testthat::expect_identical(dim(draws$detect_probability_208), c(200L, 30L))
  testthat::expect_equal(draws$rate, exp(draws$eta), tolerance = 0)
  testthat::expect_equal(
    draws$p1,
    -expm1(-draws$rate),
    tolerance = 0
  )
  testthat::expect_equal(
    draws$p7,
    -expm1(-7 * draws$rate),
    tolerance = 0
  )
  testthat::expect_true(all(draws$p1 >= 0 & draws$p1 <= 1))
  testthat::expect_true(all(draws$p7 >= 0 & draws$p7 <= 1))
  testthat::expect_equal(
    apply(draws$camera_effect, 1L, sum),
    rep(0, 200L),
    tolerance = 1e-12
  )
  testthat::expect_true(validate_goal002_prior_draws(draws))
})

testthat::test_that("prior generators preserve caller RNG algorithms and state", {
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

  suppressWarnings(RNGkind(
    kind = "L'Ecuyer-CMRG",
    normal.kind = "Box-Muller",
    sample.kind = "Rounding"
  ))
  set.seed(12345L)
  expected_kind <- RNGkind()
  expected_seed <- .Random.seed

  effort <- goal002_prior_effort(seed = 2601L)
  draws <- simulate_goal002_prior(
    goal002_prior_profiles()$primary,
    effort = effort,
    n_draws = 20L,
    seed = 2602L
  )

  testthat::expect_identical(RNGkind(), expected_kind)
  testthat::expect_identical(.Random.seed, expected_seed)
  testthat::expect_identical(
    simulate_goal002_prior(
      goal002_prior_profiles()$primary,
      effort = effort,
      n_draws = 20L,
      seed = 2602L
    ),
    draws
  )
})

testthat::test_that("automatic prior rejection rules are immutable", {
  rules <- goal002_prior_rules()
  testthat::expect_named(rules, c(
    "n_draws", "candidate_pool_size", "n_cameras", "n_occasions",
    "prefix_occasions", "pmf_tolerance", "max_observed_mass",
    "min_partial_probability", "quantiles"
  ))
  testthat::expect_identical(rules$n_draws, 10000L)
  testthat::expect_identical(rules$candidate_pool_size, 30L)
  testthat::expect_identical(rules$n_cameras, 9L)
  testthat::expect_identical(rules$n_occasions, 208L)
  testthat::expect_identical(rules$prefix_occasions, 26L)
  testthat::expect_equal(rules$pmf_tolerance, 1e-12)
  testthat::expect_equal(rules$max_observed_mass, 0.95)
  testthat::expect_equal(rules$min_partial_probability, 0.05)
  testthat::expect_identical(
    rules$quantiles,
    c(0, 0.001, 0.01, 0.05, 0.5, 0.95, 0.99, 0.999, 1)
  )
})

testthat::test_that("assessment has one deterministic row per automatic rule", {
  draws <- .make_goal002_rule_fixture()
  assessment <- assess_goal002_prior(draws)

  testthat::expect_named(assessment, c(
    "schema_version", "profile_id", "profile_hash", "effort_hash",
    "simulation_seed", "n_draws", "rules", "automatic_rejected",
    "automatic_outcome"
  ))
  testthat::expect_s3_class(assessment$rules, "tbl_df")
  testthat::expect_named(assessment$rules, c(
    "rule_id", "statistic", "threshold", "comparison", "passed",
    "automatic_outcome"
  ))
  testthat::expect_identical(
    assessment$rules$rule_id,
    c(
      "finite_draws",
      "nested_richness_bounds",
      "richness_pmf",
      "max_observed_mass_26",
      "max_observed_mass_208",
      "min_partial_probability_26",
      "min_partial_probability_208"
    )
  )
  testthat::expect_true(all(assessment$rules$passed))
  testthat::expect_false(assessment$automatic_rejected)
  testthat::expect_identical(
    assessment$automatic_outcome,
    "not_rejected_automatically"
  )
})

testthat::test_that("non-finite prior values trigger only the finite rule", {
  draws <- .make_goal002_rule_fixture()
  draws$mu_alpha[1L] <- Inf

  testthat::expect_identical(
    .failed_goal002_rules(draws),
    "finite_draws"
  )
})

testthat::test_that("order violations trigger the nested-bounds rule", {
  draws <- .make_goal002_rule_fixture()
  draws$observed_26[1L] <- draws$observed_208[1L] + 1L

  testthat::expect_identical(
    .failed_goal002_rules(draws),
    "nested_richness_bounds"
  )
})

testthat::test_that("an invalid richness PMF triggers the PMF rule", {
  draws <- .make_goal002_rule_fixture()
  draws$richness_pmf$probability[1L] <-
    draws$richness_pmf$probability[1L] + 0.1

  testthat::expect_identical(
    .failed_goal002_rules(draws),
    "richness_pmf"
  )
})

testthat::test_that("duration-specific degenerate masses trigger independently", {
  draws_26 <- .make_goal002_rule_fixture()
  draws_26$observed_26[] <- 1L
  draws_26$observed_208 <- pmax(draws_26$observed_208, 1L)
  testthat::expect_identical(
    .failed_goal002_rules(draws_26),
    "max_observed_mass_26"
  )

  draws_208 <- .make_goal002_rule_fixture()
  draws_208$observed_26 <- as.integer(seq_len(200L) %% 2L)
  draws_208$observed_208[] <- 1L
  testthat::expect_identical(
    .failed_goal002_rules(draws_208),
    "max_observed_mass_208"
  )
})

testthat::test_that("duration-specific partial-observation rules trigger independently", {
  draws_26 <- .make_goal002_rule_fixture()
  even <- seq_len(200L) %% 2L == 0L
  draws_26$observed_26 <- ifelse(even, 0L, draws_26$richness)
  draws_26$observed_208 <- ifelse(even, 1L, draws_26$richness)
  draws_26$observed_26 <- as.integer(draws_26$observed_26)
  draws_26$observed_208 <- as.integer(draws_26$observed_208)
  testthat::expect_identical(
    .failed_goal002_rules(draws_26),
    "min_partial_probability_26"
  )

  draws_208 <- .make_goal002_rule_fixture()
  even <- seq_len(200L) %% 2L == 0L
  draws_208$observed_208 <- ifelse(even, 0L, draws_208$richness)
  draws_208$observed_26 <- ifelse(even, 0L, 1L)
  draws_208$observed_26 <- as.integer(draws_208$observed_26)
  draws_208$observed_208 <- as.integer(draws_208$observed_208)
  testthat::expect_identical(
    .failed_goal002_rules(draws_208),
    "min_partial_probability_208"
  )
})

testthat::test_that("assessment never relaxes the frozen PMF tolerance", {
  draws <- .make_goal002_rule_fixture(50L)

  testthat::expect_error(
    assess_goal002_prior(draws, tolerance = 1e-8),
    "must equal the frozen"
  )
})

testthat::test_that("prior report uses all values and fixed exact quantiles", {
  draws <- .make_goal002_rule_fixture()
  assessment <- assess_goal002_prior(draws)
  report <- goal002_prior_report(draws, assessment)
  probabilities <- goal002_prior_rules()$quantiles

  testthat::expect_named(report, c(
    "schema_version", "profile_id", "profile", "profile_hash",
    "effort_hash", "effort_seed", "simulation_seed", "n_draws",
    "quantile_type", "automatic_outcome", "assessment", "richness_pmf",
    "quantiles", "boundary_frequencies", "saturation_frequencies"
  ))
  testthat::expect_identical(report$profile, draws$profile)
  testthat::expect_identical(report$richness_pmf, draws$richness_pmf)
  testthat::expect_identical(report$quantile_type, 7L)
  testthat::expect_s3_class(report$quantiles, "tbl_df")
  testthat::expect_named(
    report$quantiles,
    c("variable", "probability", "value")
  )
  testthat::expect_identical(
    unique(report$quantiles$variable),
    c(
      "eta", "rate", "p1", "p7", "richness", "observed_26",
      "observed_208"
    )
  )
  for (variable in unique(report$quantiles$variable)) {
    testthat::expect_identical(
      report$quantiles$probability[
        report$quantiles$variable == variable
      ],
      probabilities,
      info = variable
    )
  }
  expected_eta <- as.numeric(stats::quantile(
    as.vector(draws$eta),
    probs = probabilities,
    names = FALSE,
    type = 7L
  ))
  testthat::expect_equal(
    report$quantiles$value[report$quantiles$variable == "eta"],
    expected_eta,
    tolerance = 0
  )
  testthat::expect_named(
    report$boundary_frequencies,
    c("variable", "boundary", "frequency")
  )
  testthat::expect_named(
    report$saturation_frequencies,
    c("variable", "boundary", "frequency")
  )
  testthat::expect_false(any(grepl(
    "verdict|ecological",
    names(report),
    ignore.case = TRUE
  )))
})

testthat::test_that("draw and assessment provenance must agree", {
  draws <- .make_goal002_rule_fixture(50L)
  assessment <- assess_goal002_prior(draws)
  assessment$effort_hash <- paste0(
    substr(assessment$effort_hash, 1L, 63L),
    "0"
  )

  testthat::expect_error(
    goal002_prior_report(draws, assessment),
    "provenance"
  )
})

testthat::test_that("reports reject a tampered automatic assessment", {
  draws <- .make_goal002_rule_fixture(50L)
  assessment <- assess_goal002_prior(draws)
  assessment$rules$passed[1L] <- FALSE

  testthat::expect_error(
    goal002_prior_report(draws, assessment),
    "does not exactly match"
  )
})
