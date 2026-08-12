testthat::test_that("stable hazard terms match hand values", {
  log_rate <- log(c(1e-12, 1e-3, 50))
  effort <- c(1L, 7L, 1L)

  testthat::expect_equal(
    log_detect_probability(log_rate, effort),
    log(-expm1(-effort * exp(log_rate))),
    tolerance = 1e-14
  )
  testthat::expect_equal(
    log_nondetect_probability(log_rate, effort),
    -effort * exp(log_rate),
    tolerance = 1e-14
  )
})

testthat::test_that("hazard terms retain limiting values without NaN", {
  log_rate <- c(-1000, -1000, 1000, 1000)
  effort <- c(7L, 0L, 1L, 0L)

  testthat::expect_equal(
    log_detect_probability(log_rate, effort),
    c(log(7) - 1000, -Inf, 0, -Inf),
    tolerance = 1e-14
  )
  testthat::expect_identical(
    log_nondetect_probability(log_rate, effort),
    c(0, 0, -Inf, 0)
  )
})

testthat::test_that("hazard inputs reject unsafe recycling and invalid effort", {
  testthat::expect_error(
    log_detect_probability(c(-2, -1, 0), c(1L, 2L)),
    "length",
    fixed = TRUE
  )
  testthat::expect_error(
    log_nondetect_probability(0, -1),
    "non-negative",
    fixed = TRUE
  )
  testthat::expect_error(
    log_detect_probability(Inf, 1L),
    "finite",
    fixed = TRUE
  )
  testthat::expect_error(
    log_nondetect_probability(0, 1.5),
    "whole",
    fixed = TRUE
  )
})

testthat::test_that("grouped and rowwise kernels are identical", {
  fixture <- goal002_oracle_fixture()
  grouped <- member_log_likelihood(
    fixture$data,
    fixture$alpha,
    fixture$camera_effect
  )
  rowwise <- oracle_rowwise_member_log_likelihood(
    fixture$data$observed,
    fixture$alpha,
    fixture$camera_effect,
    fixture$data$candidate_ids,
    fixture$data$camera_ids
  )

  tolerance <- 1e-10 * (1 + abs(rowwise))
  testthat::expect_true(all(abs(grouped - rowwise) <= tolerance))
})

testthat::test_that("analytic membership marginalisation matches every small enumeration", {
  for (C in 1:4) {
    fixture <- goal002_oracle_fixture(C = C)
    member_ll <- member_log_likelihood(
      fixture$data,
      fixture$alpha,
      fixture$camera_effect
    )
    enumeration <- oracle_membership_configuration_log_weights(
      member_ll,
      fixture$data$stan_data$detected_ever,
      omega = 0.37
    )
    analytic <- marginal_membership_log_likelihood(
      member_ll,
      fixture$data$stan_data$detected_ever,
      omega = 0.37
    )
    enumerated <- oracle_log_sum_exp(enumeration$log_weight)

    testthat::expect_equal(
      nrow(enumeration$configurations),
      2^C
    )
    testthat::expect_equal(
      analytic,
      enumerated,
      tolerance = 1e-12 * (1 + abs(enumerated))
    )
    incompatible <- apply(
      enumeration$configurations,
      1L,
      function(membership) {
        any(
          fixture$data$stan_data$detected_ever == 1L &
            membership == 0L
        )
      }
    )
    testthat::expect_true(all(
      enumeration$log_weight[incompatible] == -Inf
    ))
    testthat::expect_true(all(is.finite(
      enumeration$log_weight[!incompatible]
    )))
  }
})

testthat::test_that("analytic membership marginalisation matches enumeration", {
  fixture <- goal002_oracle_fixture(C = 4L)
  member_ll <- member_log_likelihood(
    fixture$data,
    fixture$alpha,
    fixture$camera_effect
  )
  analytic <- marginal_membership_log_likelihood(
    member_ll,
    fixture$data$stan_data$detected_ever,
    omega = 0.37
  )
  enumerated <- oracle_enumerated_membership_log_likelihood(
    member_ll,
    fixture$data$stan_data$detected_ever,
    omega = 0.37
  )

  testthat::expect_equal(
    analytic,
    enumerated,
    tolerance = 1e-12 * (1 + abs(enumerated))
  )
})

testthat::test_that("conditional membership agrees with exhaustive posterior ratios", {
  fixture <- goal002_oracle_fixture()
  member_ll <- member_log_likelihood(
    fixture$data,
    fixture$alpha,
    fixture$camera_effect
  )
  analytic <- conditional_membership_probability(
    member_ll,
    fixture$data$stan_data$detected_ever,
    omega = 0.37
  )
  enumerated <- oracle_enumerated_membership_probability(
    member_ll,
    fixture$data$stan_data$detected_ever,
    omega = 0.37
  )
  detected <- fixture$data$stan_data$detected_ever == 1L

  testthat::expect_identical(
    unname(analytic[detected]),
    rep(1, sum(detected))
  )
  testthat::expect_equal(
    analytic[!detected],
    enumerated[!detected],
    tolerance = 1e-12
  )
})

testthat::test_that("membership calculations honour zero and one prior boundaries", {
  fixture <- goal002_oracle_fixture()
  member_ll <- member_log_likelihood(
    fixture$data,
    fixture$alpha,
    fixture$camera_effect
  )
  detected <- fixture$data$stan_data$detected_ever

  testthat::expect_identical(
    marginal_membership_log_likelihood(member_ll, detected, 0),
    -Inf
  )
  testthat::expect_equal(
    marginal_membership_log_likelihood(member_ll, detected, 1),
    sum(member_ll)
  )
  testthat::expect_identical(
    conditional_membership_probability(member_ll, detected, 0),
    stats::setNames(as.numeric(detected), names(member_ll))
  )
  testthat::expect_identical(
    conditional_membership_probability(member_ll, detected, 1),
    stats::setNames(rep(1, length(member_ll)), names(member_ll))
  )
})

testthat::test_that("more zero-detection effort lowers conditional membership", {
  fixture <- goal002_oracle_fixture()
  higher_inputs <- fixture$inputs
  sampled <- higher_inputs$effort_weekly$active_days > 0L
  higher_inputs$effort_weekly$active_days[sampled] <- pmin(
    7L,
    higher_inputs$effort_weekly$active_days[sampled] + 1L
  )
  higher_data <- do.call(
    prepare_flexirich_g_data,
    unname(higher_inputs)
  )

  baseline_ll <- member_log_likelihood(
    fixture$data,
    fixture$alpha,
    fixture$camera_effect
  )
  higher_ll <- member_log_likelihood(
    higher_data,
    fixture$alpha,
    fixture$camera_effect
  )
  baseline_q <- conditional_membership_probability(
    baseline_ll,
    fixture$detected_ever,
    omega = 0.37
  )
  higher_q <- conditional_membership_probability(
    higher_ll,
    higher_data$stan_data$detected_ever,
    omega = 0.37
  )
  all_zero <- fixture$detected_ever == 0L

  testthat::expect_true(all(higher_ll[all_zero] < baseline_ll[all_zero]))
  testthat::expect_true(all(higher_q[all_zero] < baseline_q[all_zero]))
})

testthat::test_that("grouped row order does not change the member kernel", {
  fixture <- goal002_oracle_fixture()
  reference <- .member_log_likelihood_grouped(
    fixture$data$grouped,
    fixture$data$candidate_ids,
    fixture$data$camera_ids,
    fixture$alpha,
    fixture$camera_effect
  )
  permutation <- rev(seq_len(nrow(fixture$data$grouped)))
  permuted <- .member_log_likelihood_grouped(
    fixture$data$grouped[permutation, , drop = FALSE],
    fixture$data$candidate_ids,
    fixture$data$camera_ids,
    fixture$alpha,
    fixture$camera_effect
  )

  testthat::expect_identical(permuted, reference)
})

testthat::test_that("sum-zero centring preserves Goal 001 linear predictors", {
  sim <- simulate_flexirich_g(flexirich_sim_config(
    candidate_pool_size = 4L,
    true_richness = 3L,
    n_cameras = 2L,
    n_occasions = 5L,
    seed = 2301L
  ))
  data <- sim_to_flexirich_g_data(sim)
  shift <- mean(sim$cameras$camera_effect)
  centred_camera_effect <- sim$cameras$camera_effect - shift
  centred_alpha <- sim$species$alpha + shift

  raw_eta <- outer(
    sim$species$alpha,
    sim$cameras$camera_effect,
    "+"
  )
  centred_eta <- outer(
    centred_alpha,
    centred_camera_effect,
    "+"
  )

  testthat::expect_equal(sum(centred_camera_effect), 0, tolerance = 1e-15)
  testthat::expect_equal(centred_eta, raw_eta, tolerance = 1e-15)
  testthat::expect_equal(
    member_log_likelihood(
      data,
      centred_alpha,
      centred_camera_effect
    ),
    member_log_likelihood(
      data,
      sim$species$alpha,
      sim$cameras$camera_effect
    ),
    tolerance = 1e-12
  )
})

testthat::test_that("Poisson-binomial PMFs cover empty, boundary, and hand cases", {
  empty <- poisson_binomial_pmf(numeric())
  boundary <- poisson_binomial_pmf(c(0, 1, 0, 1))
  hand <- poisson_binomial_pmf(c(0.2, 0.7))

  testthat::expect_identical(empty, stats::setNames(1, "0"))
  testthat::expect_identical(
    boundary,
    stats::setNames(c(0, 0, 1, 0, 0), as.character(0:4))
  )
  testthat::expect_equal(
    hand,
    stats::setNames(c(0.24, 0.62, 0.14), as.character(0:2)),
    tolerance = 1e-15
  )

  general <- poisson_binomial_pmf(c(0.01, 0.2, 0.5, 0.8, 0.99))
  testthat::expect_identical(names(general), as.character(0:5))
  testthat::expect_true(all(is.finite(general)))
  testthat::expect_true(all(general >= 0))
  testthat::expect_equal(sum(general), 1, tolerance = 1e-15)
})

testthat::test_that("draw-level Poisson-binomial mixtures have exact hand values", {
  probabilities <- rbind(
    c(1, 0.2),
    c(1, 0.6)
  )
  mixture <- .goal003_mean_poisson_binomial(probabilities)

  testthat::expect_identical(mixture$richness, 0:2)
  testthat::expect_equal(
    mixture$probability,
    c(0, 0.6, 0.4),
    tolerance = 1e-15
  )
  testthat::expect_equal(sum(mixture$probability), 1, tolerance = 1e-15)

  empty <- .goal003_mean_poisson_binomial(
    matrix(numeric(), nrow = 3L, ncol = 0L)
  )
  testthat::expect_identical(empty$richness, 0L)
  testthat::expect_identical(empty$probability, 1)
})

testthat::test_that("posterior PMF averaging belongs to inference mathematics", {
  root <- if (dir.exists("R")) "." else file.path("..", "..")
  module <- new.env(parent = globalenv())
  sys.source(file.path(root, "R", "infer_math.R"), envir = module)

  testthat::expect_true(
    exists(
      ".goal003_mean_poisson_binomial",
      envir = module,
      inherits = FALSE
    )
  )
})

testthat::test_that("likelihood functions reject malformed arguments", {
  fixture <- goal002_oracle_fixture()
  member_ll <- c(-1, -2, -3, -4)
  detected <- c(1L, 1L, 0L, 0L)

  testthat::expect_error(
    member_log_likelihood(
      fixture$data,
      fixture$alpha[-1L],
      fixture$camera_effect
    ),
    "alpha.*length",
    ignore.case = TRUE
  )
  testthat::expect_error(
    member_log_likelihood(
      fixture$data,
      fixture$alpha,
      c(0)
    ),
    "camera_effect.*length",
    ignore.case = TRUE
  )
  testthat::expect_error(
    marginal_membership_log_likelihood(
      member_ll,
      detected[-1L],
      0.5
    ),
    "same length",
    fixed = TRUE
  )
  testthat::expect_error(
    conditional_membership_probability(
      member_ll,
      detected,
      c(0.2, 0.3)
    ),
    "omega.*one",
    ignore.case = TRUE
  )
  testthat::expect_error(
    marginal_membership_log_likelihood(
      member_ll,
      c(1L, 2L, 0L, 0L),
      0.5
    ),
    "binary",
    fixed = TRUE
  )
  testthat::expect_error(
    poisson_binomial_pmf(c(0.2, NA_real_)),
    "finite values in [0, 1]",
    fixed = TRUE
  )
  testthat::expect_error(
    poisson_binomial_pmf(c(0.2, 1.1)),
    "finite values in [0, 1]",
    fixed = TRUE
  )
})

testthat::test_that("test oracles do not call production mathematics", {
  oracle_functions <- list(
    oracle_rowwise_member_log_likelihood,
    oracle_membership_configuration_log_weights,
    oracle_enumerated_membership_log_likelihood,
    oracle_enumerated_membership_probability
  )
  production_functions <- c(
    "log_detect_probability",
    "log_nondetect_probability",
    "member_log_likelihood",
    "marginal_membership_log_likelihood",
    "conditional_membership_probability",
    "poisson_binomial_pmf"
  )
  called <- unique(unlist(lapply(
    oracle_functions,
    function(fun) {
      codetools::findGlobals(fun, merge = FALSE)$functions
    }
  )))

  testthat::expect_length(intersect(called, production_functions), 0L)
})

testthat::test_that("Stan source marginalises species membership", {
  source_root <- if (dir.exists("R")) "." else file.path("..", "..")
  stan_path <- file.path(source_root, "stan", "flexirich_g.stan")
  exists <- file.exists(stan_path)

  testthat::expect_true(
    exists,
    info = "stan/flexirich_g.stan must provide the inference kernel"
  )
  if (!exists) {
    return(invisible())
  }

  stan_source <- readLines(stan_path, warn = FALSE)
  stan_text <- paste(stan_source, collapse = "\n")

  testthat::expect_match(stan_text, "log_mix")
  testthat::expect_match(stan_text, "bernoulli_rng")
  testthat::expect_match(stan_text, "binomial_rng")
  testthat::expect_match(stan_text, "matrix\\[J, B\\] Q")

  parameters_start <- which(trimws(stan_source) == "parameters {")
  transformed_start <- which(
    trimws(stan_source) == "transformed parameters {"
  )
  testthat::expect_length(parameters_start, 1L)
  testthat::expect_length(transformed_start, 1L)

  if (length(parameters_start) == 1L &&
      length(transformed_start) == 1L &&
      transformed_start > parameters_start + 1L) {
    parameters_text <- paste(
      stan_source[seq.int(
        parameters_start + 1L,
        transformed_start - 1L
      )],
      collapse = "\n"
    )
    membership_parameter <- paste0(
      "\\b(g|g_raw|g_member|member|membership|",
      "presence|z_raw)\\b"
    )

    testthat::expect_false(
      grepl(membership_parameter, parameters_text, perl = TRUE),
      info = paste0(
        "membership must be marginalised; no discrete or continuous ",
        "pseudo-presence parameter is allowed"
      )
    )
  }
})

testthat::test_that("Stan detection kernel guards its extreme lower tail", {
  source_root <- if (dir.exists("R")) "." else file.path("..", "..")
  stan_text <- paste(
    readLines(
      file.path(source_root, "stan", "flexirich_g.stan"),
      warn = FALSE
    ),
    collapse = "\n"
  )

  testthat::expect_match(
    stan_text,
    paste0(
      "if\\s*\\(log_hazard\\s*<\\s*-700\\)\\s*\\{\\s*",
      "return\\s+log_hazard\\s*;"
    ),
    perl = TRUE,
    info = paste0(
      "the Stan detection kernel must retain the finite lower-tail ",
      "limit before exp() underflows"
    )
  )
})
