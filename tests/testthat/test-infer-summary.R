goal002_summary_diagnostics_fixture <- function(clean) {
  reasons <- if (clean) character() else "divergences"
  details <- if (clean) {
    character()
  } else {
    stats::setNames("One divergent transition was observed.", reasons)
  }

  list(
    clean = clean,
    reasons = reasons,
    metrics = list(
      divergences = if (clean) 0L else 1L,
      treedepth_hits = 0L,
      ebfmi_by_chain = stats::setNames(rep(0.8, 4L), as.character(1:4)),
      min_ebfmi = 0.8,
      max_rhat = 1,
      min_bulk_ess = 800,
      min_tail_ess = 800
    ),
    richness = list(
      status = "estimated",
      tau = 0.05,
      observed_richness = 2L,
      candidate_pool_size = 4L,
      lower_cutoff = 2L,
      upper_cutoff = 4L,
      mean_lower_mass = 0.25,
      mean_upper_mass = 0.25,
      row_diagnostics = tibble::tibble(
        variable = c(
          "expected_richness",
          "richness_lower_tail",
          "richness_upper_tail"
        ),
        rhat = rep(1, 3L),
        ess_bulk = rep(800, 3L),
        ess_tail = rep(800, 3L)
      ),
      detail = ""
    ),
    generated_richness = list(
      status = "passed",
      reasons = character(),
      metrics = list(
        n_draws = 40L,
        candidate_pool_size = 4L,
        observed_richness = 2L,
        max_expected_richness_error = 0
      ),
      details = character()
    ),
    details = details
  )
}

goal002_summary_attempt_fixture <- function(clean, attempt_id = "primary") {
  list(
    attempt_id = attempt_id,
    sampler_profile_id = if (identical(attempt_id, "primary")) {
      "primary-sampler-v1"
    } else {
      "rescue-sampler-v1"
    },
    seed = if (identical(attempt_id, "primary")) 72002101L else 72502101L,
    started_at_utc = "2026-07-28T00:00:00Z",
    elapsed_seconds = 1,
    model_source_hash = paste(rep("a", 64L), collapse = ""),
    data_hash = paste(rep("b", 64L), collapse = ""),
    prior_profile = "primary-v1",
    R_version = as.character(getRversion()),
    cmdstanr_version = as.character(utils::packageVersion("cmdstanr")),
    cmdstan_version = "2.38.0",
    compiler = "g++ test compiler",
    output_files = if (clean) {
      sprintf("outputs/goal002/test/%s/chain-%d.csv", attempt_id, 1:4)
    } else {
      character()
    },
    diagnostics = goal002_summary_diagnostics_fixture(clean),
    clean = clean
  )
}

goal002_fit_fixture <- function(terminal_status = "primary_clean") {
  data <- goal002_oracle_fixture(C = 4L)$data
  primary <- goal002_summary_attempt_fixture(
    clean = identical(terminal_status, "primary_clean")
  )
  primary$data_hash <- data$data_hash
  rescue <- if (identical(terminal_status, "primary_clean")) {
    NULL
  } else {
    goal002_summary_attempt_fixture(
      clean = identical(terminal_status, "rescue_clean"),
      attempt_id = "rescue"
    )
  }
  if (!is.null(rescue)) {
    rescue$data_hash <- data$data_hash
  }
  resolution <- resolve_goal002_attempts(primary, rescue)

  variables <- c(
    "omega",
    "mu_alpha",
    "sigma_alpha",
    "sigma_camera",
    sprintf("alpha[%d]", seq_len(data$stan_data$C)),
    sprintf("camera_effect[%d]", seq_len(data$stan_data$J)),
    sprintf("member_ll[%d]", seq_len(data$stan_data$C)),
    sprintf("q_member[%d]", seq_len(data$stan_data$C)),
    sprintf("g_member[%d]", seq_len(data$stan_data$C)),
    "S_grid",
    "expected_richness",
    sprintf("y_rep[%d]", seq_len(data$stan_data$G))
  )
  draws <- matrix(
    0,
    nrow = 40L,
    ncol = length(variables),
    dimnames = list(NULL, variables)
  )
  draws[, "omega"] <- rep(c(0.4, 0.6), 20L)
  draws[, "mu_alpha"] <- rep(c(-7, -6), 20L)
  draws[, "sigma_alpha"] <- rep(c(0.8, 1.2), 20L)
  draws[, "sigma_camera"] <- rep(c(0.4, 0.6), 20L)
  for (candidate in seq_len(data$stan_data$C)) {
    draws[, sprintf("alpha[%d]", candidate)] <-
      -8 + candidate + rep(c(-0.1, 0.1), 20L)
  }
  draws[, "camera_effect[1]"] <- -0.2
  draws[, "camera_effect[2]"] <- 0.2

  q_names <- sprintf("q_member[%d]", seq_len(data$stan_data$C))
  g_names <- sprintf("g_member[%d]", seq_len(data$stan_data$C))
  q <- cbind(1, 1, 0.5, 0.5)
  q <- q[rep(1L, 40L), , drop = FALSE]
  g <- cbind(
    1,
    1,
    rep(c(0, 0, 1, 1), 10L),
    rep(c(0, 1, 0, 1), 10L)
  )
  draws[, q_names] <- q
  draws[, g_names] <- g
  draws[, "S_grid"] <- rowSums(g)
  draws[, "expected_richness"] <- rowSums(q)

  observed_rep <- data$stan_data$n_detected
  richer_rep <- observed_rep
  richer_rep[c(2L, 6L)] <- 1L
  y_rep <- matrix(
    rep(c(observed_rep, richer_rep), 20L),
    nrow = 40L,
    byrow = TRUE
  )
  draws[, sprintf("y_rep[%d]", seq_len(data$stan_data$G))] <- y_rep

  result <- list(
    terminal_status = resolution$terminal_status,
    rescue_used = resolution$rescue_used,
    terminal_attempt_id = resolution$terminal_attempt_id,
    candidate_ids = data$candidate_ids,
    camera_ids = data$camera_ids,
    detected_ever = data$stan_data$detected_ever,
    observed = data$observed,
    grouped = data$grouped,
    data_hash = data$data_hash,
    prior_profile = goal002_prior_profiles()$primary,
    model_source_hash = primary$model_source_hash,
    attempts = resolution$attempts,
    draws = if (identical(terminal_status, "final_nonclean")) {
      NULL
    } else {
      posterior::as_draws_matrix(draws)
    }
  )
  class(result) <- c("flexirich_g_fit", "list")
  result
}

testthat::test_that("Rao-Blackwellised richness PMF is coherent", {
  q <- rbind(
    c(1, 1, 0.2, 0.4),
    c(1, 1, 0.3, 0.5)
  )
  pmf <- richness_pmf_from_q(q)

  testthat::expect_identical(pmf$richness, 0:4)
  testthat::expect_equal(sum(pmf$probability), 1, tolerance = 1e-14)
  testthat::expect_equal(sum(pmf$probability[1:2]), 0)
})

testthat::test_that("non-clean fit cannot expose posterior inference", {
  fit <- goal002_fit_fixture(terminal_status = "final_nonclean")
  summary <- summarise_flexirich_g(fit, fit$candidate_ids)

  testthat::expect_identical(summary$terminal_status, "final_nonclean")
  testthat::expect_null(summary$richness)
  testthat::expect_null(summary$membership)
})

testthat::test_that("posterior richness uses continuous membership draws", {
  fit <- goal002_fit_fixture()
  pmf <- posterior_richness_pmf(fit)

  testthat::expect_identical(pmf$richness, 0:4)
  testthat::expect_equal(
    pmf$probability,
    c(0, 0, 0.25, 0.5, 0.25),
    tolerance = 1e-14
  )
  testthat::expect_equal(
    sum(pmf$richness * pmf$probability),
    mean(fit$draws[, "expected_richness"]),
    tolerance = 1e-14
  )
})

testthat::test_that("clean summaries have the exact richness and membership contract", {
  fit <- goal002_fit_fixture()
  summary <- summarise_flexirich_g(fit, fit$candidate_ids)

  testthat::expect_s3_class(summary, "flexirich_g_summary")
  testthat::expect_identical(
    names(summary),
    c(
      "terminal_status",
      "rescue_used",
      "richness",
      "membership",
      "effects",
      "posterior_predictive",
      "diagnostics",
      "metadata"
    )
  )
  testthat::expect_identical(
    names(summary$richness),
    c(
      "pmf",
      "mean",
      "median",
      "mode",
      "intervals",
      "observed",
      "candidate_pool",
      "boundary_mass"
    )
  )
  testthat::expect_equal(summary$richness$mean, 3)
  testthat::expect_identical(summary$richness$median, 3L)
  testthat::expect_identical(summary$richness$mode, 3L)
  testthat::expect_identical(
    summary$richness$intervals,
    list(
      `80` = c(lower = 2L, upper = 4L),
      `90` = c(lower = 2L, upper = 4L),
      `95` = c(lower = 2L, upper = 4L)
    )
  )
  testthat::expect_identical(summary$richness$observed, 2L)
  testthat::expect_identical(summary$richness$candidate_pool, 4L)
  testthat::expect_equal(
    summary$richness$boundary_mass,
    c(observed = 0.25, candidate_pool = 0.25)
  )
  testthat::expect_identical(
    names(summary$membership),
    c("species_id", "detected", "probability")
  )
  testthat::expect_identical(
    summary$membership$species_id,
    fit$candidate_ids
  )
  testthat::expect_identical(
    summary$membership$detected,
    c(TRUE, TRUE, FALSE, FALSE)
  )
  testthat::expect_equal(
    summary$membership$probability,
    c(1, 1, 0.5, 0.5)
  )
  testthat::expect_identical(
    summary$membership$probability[3:4],
    c(0.5, 0.5)
  )
})

testthat::test_that("effects summaries preserve candidate and camera identities", {
  fit <- goal002_fit_fixture()
  effects <- summarise_flexirich_g(fit, fit$candidate_ids)$effects

  testthat::expect_identical(
    names(effects),
    c("hyperparameters", "candidate_effects", "camera_effects")
  )
  testthat::expect_identical(
    effects$hyperparameters$parameter,
    c("omega", "mu_alpha", "sigma_alpha", "sigma_camera")
  )
  testthat::expect_equal(
    effects$hyperparameters$mean,
    c(0.5, -6.5, 1, 0.5)
  )
  testthat::expect_identical(
    effects$candidate_effects$species_id,
    fit$candidate_ids
  )
  testthat::expect_equal(
    effects$candidate_effects$mean,
    -8 + seq_along(fit$candidate_ids)
  )
  testthat::expect_identical(
    effects$camera_effects$camera_id,
    fit$camera_ids
  )
  testthat::expect_equal(effects$camera_effects$mean, c(-0.2, 0.2))
})

testthat::test_that("posterior predictive summaries retain required margins", {
  fit <- goal002_fit_fixture()
  ppc <- summarise_flexirich_g(
    fit,
    fit$candidate_ids
  )$posterior_predictive

  testthat::expect_identical(
    names(ppc),
    c(
      "total_detections",
      "detections_per_candidate",
      "detections_per_camera",
      "candidate_detection_frequencies"
    )
  )
  testthat::expect_identical(ppc$total_detections$observed, 2L)
  testthat::expect_equal(ppc$total_detections$replicated_mean, 3)
  testthat::expect_identical(
    ppc$detections_per_candidate$species_id,
    fit$candidate_ids
  )
  testthat::expect_identical(
    ppc$detections_per_candidate$observed,
    c(1L, 1L, 0L, 0L)
  )
  testthat::expect_equal(
    ppc$detections_per_candidate$replicated_mean,
    c(1.5, 1.5, 0, 0)
  )
  testthat::expect_identical(
    ppc$detections_per_camera$camera_id,
    fit$camera_ids
  )
  testthat::expect_identical(
    ppc$detections_per_camera$observed,
    c(1L, 1L)
  )
  testthat::expect_equal(
    ppc$detections_per_camera$replicated_mean,
    c(2, 1)
  )
  testthat::expect_identical(
    ppc$candidate_detection_frequencies$n_detections,
    0:2
  )
  testthat::expect_identical(
    ppc$candidate_detection_frequencies$observed_frequency,
    c(2L, 2L, 0L)
  )
  testthat::expect_equal(
    ppc$candidate_detection_frequencies$replicated_mean,
    c(2, 1, 1)
  )
})

testthat::test_that("generated richness verifies the Rao-Blackwellised PMF", {
  fit <- goal002_fit_fixture()
  diagnostics <- summarise_flexirich_g(
    fit,
    fit$candidate_ids
  )$diagnostics

  testthat::expect_identical(
    names(diagnostics),
    c("terminal_attempt", "generated_richness")
  )
  testthat::expect_identical(
    diagnostics$terminal_attempt,
    fit$attempts$primary$diagnostics
  )
  testthat::expect_equal(
    diagnostics$generated_richness$pmf$probability,
    c(0, 0, 0.25, 0.5, 0.25)
  )
  testthat::expect_equal(
    diagnostics$generated_richness$max_absolute_difference,
    0
  )
  testthat::expect_true(diagnostics$generated_richness$agrees)
})

testthat::test_that("summary metadata retain exact terminal provenance", {
  fit <- goal002_fit_fixture("rescue_clean")
  summary <- summarise_flexirich_g(fit, fit$candidate_ids)

  testthat::expect_identical(summary$terminal_status, "rescue_clean")
  testthat::expect_true(summary$rescue_used)
  testthat::expect_identical(
    names(summary$metadata),
    c(
      "terminal_attempt_id",
      "data_hash",
      "model_source_hash",
      "prior_profile",
      "terminal_attempt"
    )
  )
  testthat::expect_identical(summary$metadata$terminal_attempt_id, "rescue")
  testthat::expect_identical(
    summary$metadata$terminal_attempt,
    fit$attempts$rescue
  )
})

testthat::test_that("summary validation fails closed on contract corruption", {
  fit <- goal002_fit_fixture()
  summary <- summarise_flexirich_g(fit, fit$candidate_ids)
  testthat::expect_true(validate_flexirich_g_summary(summary))

  corruptions <- list(
    terminal_status = function(x) {
      x$terminal_status <- "rescue_clean"
      x
    },
    richness_mean = function(x) {
      x$richness$mean <- x$richness$mean + 0.1
      x
    },
    detected_membership = function(x) {
      x$membership$probability[1L] <- 0.9
      x
    },
    metadata_hash = function(x) {
      x$metadata$data_hash <- paste(rep("c", 64L), collapse = "")
      x
    },
    candidate_identity = function(x) {
      x$posterior_predictive$detections_per_candidate$species_id <-
        rev(x$membership$species_id)
      x
    }
  )
  for (case in names(corruptions)) {
    testthat::expect_error(
      validate_flexirich_g_summary(corruptions[[case]](summary)),
      info = case
    )
  }
})

testthat::test_that("unused transformed draws do not suppress valid summaries", {
  fit <- goal002_fit_fixture()
  fit$draws[1L, "member_ll[3]"] <- -Inf

  summary <- summarise_flexirich_g(fit, fit$candidate_ids)
  testthat::expect_true(validate_flexirich_g_summary(summary))
  testthat::expect_equal(summary$richness$mean, 3)
})

testthat::test_that("non-clean summaries retain diagnostics but no draw products", {
  fit <- goal002_fit_fixture("final_nonclean")
  summary <- summarise_flexirich_g(fit, fit$candidate_ids)

  testthat::expect_true(validate_flexirich_g_summary(summary))
  testthat::expect_null(summary$richness)
  testthat::expect_null(summary$membership)
  testthat::expect_null(summary$effects)
  testthat::expect_null(summary$posterior_predictive)
  testthat::expect_null(summary$diagnostics$generated_richness)
  testthat::expect_identical(
    summary$diagnostics$terminal_attempt,
    fit$attempts$rescue$diagnostics
  )
})

testthat::test_that("summary inputs reject mismatches and invalid replicated counts", {
  fit <- goal002_fit_fixture()
  testthat::expect_error(
    summarise_flexirich_g(fit, rev(fit$candidate_ids)),
    "exactly match",
    fixed = TRUE
  )
  invalid_y_rep <- fit
  invalid_y_rep$draws[1L, "y_rep[1]"] <- 2
  testthat::expect_error(
    summarise_flexirich_g(invalid_y_rep, invalid_y_rep$candidate_ids),
    "y_rep",
    fixed = TRUE
  )
})

testthat::test_that("richness PMFs reject malformed membership draws", {
  invalid <- list(
    matrix(numeric(), nrow = 0L, ncol = 2L),
    matrix(c(1, NA_real_), nrow = 1L),
    matrix(c(1, 1.1), nrow = 1L),
    matrix(c("1", "0.5"), nrow = 1L)
  )
  for (q in invalid) {
    testthat::expect_error(
      richness_pmf_from_q(q),
      "q_draws",
      fixed = TRUE
    )
  }

  nonclean <- goal002_fit_fixture("final_nonclean")
  testthat::expect_error(
    posterior_richness_pmf(nonclean),
    "clean",
    fixed = TRUE
  )
})
