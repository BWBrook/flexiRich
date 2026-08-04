testthat::test_that("Gauss--Hermite rules have standard-normal moments", {
  rule <- goal002r_gauss_hermite_rule(32L)
  testthat::expect_equal(sum(rule$weight), 1, tolerance = 1e-14)
  testthat::expect_equal(sum(rule$weight * rule$node), 0, tolerance = 1e-14)
  testthat::expect_equal(
    sum(rule$weight * rule$node^2),
    1,
    tolerance = 1e-13
  )
  testthat::expect_equal(
    sum(rule$weight * rule$node^4),
    3,
    tolerance = 1e-11
  )
})

testthat::test_that("all-zero encounter integral matches the deterministic limit", {
  fixture <- goal002_oracle_fixture(C = 4L)
  collapsed <- prepare_flexirich_g_collapsed_data(fixture$data)
  mu <- log(0.001)
  expected <- -sum(
    collapsed$zero_history$n_trials *
      collapsed$zero_history$active_days *
      exp(mu)
  )
  actual <- goal002r_log_m0(
    collapsed$zero_history,
    mu_alpha = mu,
    sigma_alpha = 0,
    camera_effect = stats::setNames(rep(0, 2), collapsed$camera_ids)
  )
  testthat::expect_equal(actual, expected, tolerance = 1e-14)
})

testthat::test_that("quadrature agrees with an independent adaptive integral", {
  fixture <- goal002_oracle_fixture(C = 4L)
  collapsed <- prepare_flexirich_g_collapsed_data(fixture$data)
  mu <- log(0.001)
  sigma <- 1.1
  camera_effect <- stats::setNames(c(-0.2, 0.2), collapsed$camera_ids)
  camera <- unname(camera_effect[collapsed$zero_history$camera_id])
  log_integrand <- function(z) {
    vapply(z, function(value) {
      log_density <- stats::dnorm(value, log = TRUE)
      log_likelihood <- sum(
        collapsed$zero_history$n_trials *
          (-collapsed$zero_history$active_days *
            exp(mu + sigma * value + camera))
      )
      exp(log_density + log_likelihood)
    }, numeric(1))
  }
  adaptive <- stats::integrate(
    log_integrand,
    lower = -9,
    upper = 9,
    rel.tol = 1e-11
  )$value
  quadrature <- goal002r_log_m0(
    collapsed$zero_history,
    mu_alpha = mu,
    sigma_alpha = sigma,
    camera_effect = camera_effect,
    rule = goal002r_gauss_hermite_rule(64L)
  )
  testthat::expect_equal(quadrature, log(adaptive), tolerance = 1e-8)
})

testthat::test_that("unseen membership and richness PMF respect boundaries", {
  testthat::expect_identical(goal002r_q_unseen(0, 0), 0)
  testthat::expect_identical(goal002r_q_unseen(1, -100), 1)
  testthat::expect_identical(goal002r_q_unseen(0.5, -Inf), 0)

  pmf <- goal002r_richness_pmf(
    q_unseen = c(0.05, 0.95),
    observed_richness = 2L,
    candidate_pool_size = 4L
  )
  expected <- rowMeans(cbind(
    stats::dbinom(0:2, 2, 0.05),
    stats::dbinom(0:2, 2, 0.95)
  ))
  testthat::expect_equal(pmf$probability, expected, tolerance = 1e-14)
  testthat::expect_identical(pmf$richness, 2:4)
  testthat::expect_equal(sum(pmf$probability), 1, tolerance = 1e-14)
})

testthat::test_that("Goal002R Stan data is a compact collapsed interface", {
  fixture <- goal002_oracle_fixture(C = 4L)
  collapsed <- prepare_flexirich_g_collapsed_data(fixture$data)
  stan_data <- goal002r_stan_data(collapsed, quadrature_order = 16L)
  testthat::expect_identical(stan_data$D, 2L)
  testthat::expect_identical(stan_data$U, 2L)
  testthat::expect_identical(stan_data$J, 2L)
  testthat::expect_identical(stan_data$Nq, 16L)
  testthat::expect_equal(sum(stan_data$gh_log_weights |> exp()), 1)
  testthat::expect_equal(nrow(stan_data$Q), 2L)
  testthat::expect_equal(ncol(stan_data$Q), 1L)
})
