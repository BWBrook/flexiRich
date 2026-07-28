testthat::test_that("Goal 002 prior profiles are exact and named", {
  profiles <- goal002_prior_profiles()
  primary <- list(
    profile_id = "primary-v1",
    omega_alpha = 1,
    omega_beta = 1,
    mu_alpha_location = log(1e-3),
    mu_alpha_scale = 2,
    sigma_alpha_scale = 1.5,
    sigma_camera_scale = 0.75
  )
  expected <- list(
    primary = primary,
    sensitivity_membership = utils::modifyList(
      primary,
      list(
        profile_id = "sensitivity-membership-v1",
        omega_alpha = 0.5,
        omega_beta = 0.5
      )
    ),
    sensitivity_tail = utils::modifyList(
      primary,
      list(
        profile_id = "sensitivity-tail-v2",
        mu_alpha_scale = 2.5,
        sigma_alpha_scale = 1.75
      )
    )
  )

  testthat::expect_identical(
    names(profiles),
    c("primary", "sensitivity_membership", "sensitivity_tail")
  )
  testthat::expect_identical(profiles, expected)
  testthat::expect_identical(
    lapply(
      profiles,
      validate_goal002_profile,
      type = "prior"
    ),
    profiles
  )
  testthat::expect_equal(profiles$primary$omega_alpha, 1)
  testthat::expect_equal(profiles$primary$omega_beta, 1)
  testthat::expect_equal(profiles$primary$mu_alpha_location, log(1e-3))
  testthat::expect_equal(profiles$primary$mu_alpha_scale, 2)
  testthat::expect_equal(profiles$primary$sigma_alpha_scale, 1.5)
  testthat::expect_equal(profiles$primary$sigma_camera_scale, 0.75)
  testthat::expect_equal(
    profiles$sensitivity_membership$omega_alpha,
    0.5
  )
  testthat::expect_equal(
    profiles$sensitivity_membership$omega_beta,
    0.5
  )
  testthat::expect_equal(profiles$sensitivity_tail$mu_alpha_scale, 2.5)
  testthat::expect_equal(
    profiles$sensitivity_tail$sigma_alpha_scale,
    1.75
  )
})

testthat::test_that("sampler and clean-fit profiles are frozen explicitly", {
  sampler <- goal002_sampler_profiles()
  limits <- goal002_diagnostic_thresholds()
  expected_sampler <- list(
    primary = list(
      profile_id = "primary-sampler-v1",
      chains = 4L,
      parallel_chains = 4L,
      iter_warmup = 1000L,
      iter_sampling = 1000L,
      adapt_delta = 0.90,
      max_treedepth = 12L,
      refresh = 100L
    ),
    rescue = list(
      profile_id = "rescue-sampler-v1",
      chains = 4L,
      parallel_chains = 4L,
      iter_warmup = 1500L,
      iter_sampling = 1500L,
      adapt_delta = 0.99,
      max_treedepth = 15L,
      refresh = 100L
    )
  )

  testthat::expect_identical(names(sampler), c("primary", "rescue"))
  testthat::expect_identical(sampler, expected_sampler)
  testthat::expect_identical(
    lapply(
      sampler,
      validate_goal002_profile,
      type = "sampler"
    ),
    sampler
  )
  testthat::expect_equal(sampler$primary$chains, 4L)
  testthat::expect_equal(sampler$primary$parallel_chains, 4L)
  testthat::expect_equal(sampler$primary$iter_warmup, 1000L)
  testthat::expect_equal(sampler$primary$iter_sampling, 1000L)
  testthat::expect_equal(sampler$primary$adapt_delta, 0.90)
  testthat::expect_equal(sampler$primary$max_treedepth, 12L)
  testthat::expect_equal(sampler$rescue$iter_warmup, 1500L)
  testthat::expect_equal(sampler$rescue$iter_sampling, 1500L)
  testthat::expect_equal(sampler$rescue$adapt_delta, 0.99)
  testthat::expect_equal(sampler$rescue$max_treedepth, 15L)
  testthat::expect_identical(
    limits,
    list(
      max_divergences = 0L,
      max_treedepth_hits = 0L,
      min_ebfmi = 0.3,
      max_rhat = 1.01,
      min_bulk_ess = 400,
      min_tail_ess = 400
    )
  )
})

testthat::test_that("invalid inference profiles fail before sampling", {
  bad <- goal002_prior_profiles()$primary
  bad$omega_alpha <- 0
  testthat::expect_error(
    validate_goal002_profile(bad, "prior"),
    "omega_alpha"
  )

  bad_sampler <- goal002_sampler_profiles()$primary
  bad_sampler$parallel_chains <- 5L
  testthat::expect_error(
    validate_goal002_profile(bad_sampler, "sampler"),
    "parallel_chains"
  )
})

testthat::test_that("prior profile schema is exact and canonical", {
  profile <- goal002_prior_profiles()$primary
  expected_fields <- c(
    "profile_id",
    "omega_alpha",
    "omega_beta",
    "mu_alpha_location",
    "mu_alpha_scale",
    "sigma_alpha_scale",
    "sigma_camera_scale"
  )

  reordered <- profile[rev(expected_fields)]
  validated <- validate_goal002_profile(reordered, "prior")
  testthat::expect_identical(names(validated), expected_fields)
  testthat::expect_identical(validated$profile_id, "primary-v1")

  unnamed <- unname(profile)
  duplicate <- structure(
    c(profile, list(omega_alpha = 1)),
    names = c(names(profile), "omega_alpha")
  )

  testthat::expect_error(
    validate_goal002_profile(unnamed, "prior"),
    "named"
  )
  testthat::expect_error(
    validate_goal002_profile(duplicate, "prior"),
    "duplicate.*omega_alpha"
  )
  testthat::expect_error(
    validate_goal002_profile(profile[-1L], "prior"),
    "missing.*profile_id"
  )
  testthat::expect_error(
    validate_goal002_profile(c(profile, extra = list(1)), "prior"),
    "unexpected.*extra"
  )
})

testthat::test_that("prior profile scalars and positivity are enforced", {
  profile <- goal002_prior_profiles()$primary
  invalid_values <- list(
    profile_id = "",
    omega_alpha = c(1, 2),
    omega_beta = NA_real_,
    mu_alpha_location = Inf,
    mu_alpha_scale = 0,
    sigma_alpha_scale = -1,
    sigma_camera_scale = "0.75"
  )

  for (field in names(invalid_values)) {
    bad <- profile
    bad[[field]] <- invalid_values[[field]]
    testthat::expect_no_warning(
      testthat::expect_error(
        validate_goal002_profile(bad, "prior"),
        field,
        info = paste("invalid prior field:", field)
      )
    )
  }
})

testthat::test_that("sampler profile schema, scalar types, and bounds are enforced", {
  profile <- goal002_sampler_profiles()$primary
  expected_fields <- c(
    "profile_id",
    "chains",
    "parallel_chains",
    "iter_warmup",
    "iter_sampling",
    "adapt_delta",
    "max_treedepth",
    "refresh"
  )

  validated <- validate_goal002_profile(profile[rev(expected_fields)], "sampler")
  testthat::expect_identical(names(validated), expected_fields)
  testthat::expect_identical(validated$chains, 4L)

  invalid_values <- list(
    profile_id = NA_character_,
    chains = 3L,
    parallel_chains = 0L,
    iter_warmup = 1.5,
    iter_sampling = Inf,
    adapt_delta = 1,
    max_treedepth = 0L,
    refresh = -1L
  )

  for (field in names(invalid_values)) {
    bad <- profile
    bad[[field]] <- invalid_values[[field]]
    testthat::expect_no_warning(
      testthat::expect_error(
        validate_goal002_profile(bad, "sampler"),
        field,
        info = paste("invalid sampler field:", field)
      )
    )
  }

  testthat::expect_error(
    validate_goal002_profile(profile[-1L], "sampler"),
    "missing.*profile_id"
  )
  testthat::expect_error(
    validate_goal002_profile(c(profile, extra = list(1)), "sampler"),
    "unexpected.*extra"
  )
})

testthat::test_that("profile type and top-level objects are validated", {
  testthat::expect_error(
    validate_goal002_profile("not a list", "prior"),
    "profile"
  )
  testthat::expect_error(
    validate_goal002_profile(goal002_prior_profiles()$primary, "unknown"),
    "type"
  )
  testthat::expect_error(
    validate_goal002_profile(
      goal002_prior_profiles()$primary,
      c("prior", "sampler")
    ),
    "type"
  )
})

testthat::test_that("CmdStan contract reports the frozen installed version", {
  status <- check_goal002_cmdstan()

  testthat::expect_identical(
    names(status),
    c(
      "available",
      "required_version",
      "installed_version",
      "path",
      "matches"
    )
  )
  testthat::expect_true(status$available)
  testthat::expect_identical(status$required_version, "2.38.0")
  testthat::expect_identical(status$installed_version, "2.38.0")
  testthat::expect_true(dir.exists(status$path))
  testthat::expect_true(status$matches)

  mismatch <- check_goal002_cmdstan("0.0.0", error = FALSE)
  testthat::expect_false(mismatch$matches)
  testthat::expect_error(
    check_goal002_cmdstan("0.0.0", error = TRUE),
    "0.0.0.*required"
  )
})
