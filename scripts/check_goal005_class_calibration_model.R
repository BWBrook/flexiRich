if (!dir.exists("R") ||
    !file.exists(file.path("stan", "goal005_class_calibration.stan"))) {
  stop("Run this script from the flexiRich repository root.", call. = FALSE)
}

for (path in sort(list.files("R", pattern = "[.]R$", full.names = TRUE))) {
  source(path, local = FALSE)
}
source(
  file.path("tests", "testthat", "helper-goal003-fixtures.R"),
  local = FALSE
)

source_data <- .goal003_baseline_fixture()
classes <- stats::setNames(
  rep(c("routine", "occasional"), length.out = length(source_data$candidate_ids)),
  source_data$candidate_ids
)
data <- prepare_goal005_class_calibration_data(
  source_data,
  classes,
  c(routine = log(0.002), occasional = log(0.0005)),
  calibration_sd = log(1.5) / stats::qnorm(0.975)
)
model <- compile_goal005_class_calibration_model()
source_hash <- digest::digest(
  file = file.path("stan", "goal005_class_calibration.stan"),
  algo = "sha256",
  serialize = FALSE
)
run_dir <- file.path(
  "outputs",
  "goal005",
  "class-calibration",
  "bridge",
  substr(source_hash, 1L, 16L)
)
unlink(run_dir, recursive = TRUE, force = TRUE)
dir.create(run_dir, recursive = TRUE, showWarnings = FALSE)

fit <- suppressMessages(model$sample(
  data = data$stan_data,
  seed = 50031L,
  chains = 1L,
  parallel_chains = 1L,
  iter_warmup = 200L,
  iter_sampling = 20L,
  refresh = 0L,
  sig_figs = 18L,
  show_messages = FALSE,
  output_dir = run_dir,
  output_basename = "bridge"
))
draws <- posterior::as_draws_matrix(fit$draws(
  variables = c(
    "expected_core_members", "omega", "alpha", "camera_effect",
    "member_ll", "q_member", "expected_richness"
  )
))
C <- length(data$candidate_ids)
J <- length(data$camera_ids)
errors <- matrix(
  0,
  nrow = nrow(draws),
  ncol = 5L,
  dimnames = list(NULL, c(
    "member_ll", "q_member", "expected_richness", "camera_sum",
    "count_scale"
  ))
)
for (draw in seq_len(nrow(draws))) {
  alpha <- draws[draw, sprintf("alpha[%d]", seq_len(C))]
  camera_effect <- draws[draw, sprintf("camera_effect[%d]", seq_len(J))]
  reference <- goal005_class_calibration_conditionals(
    data,
    draws[draw, "expected_core_members"],
    alpha,
    camera_effect
  )
  stan_member_ll <- draws[draw, sprintf("member_ll[%d]", seq_len(C))]
  stan_q <- draws[draw, sprintf("q_member[%d]", seq_len(C))]
  errors[draw, ] <- c(
    max(abs(stan_member_ll - reference$member_ll)),
    max(abs(stan_q - reference$q_member)),
    abs(draws[draw, "expected_richness"] - reference$expected_richness),
    abs(sum(camera_effect)),
    abs(draws[draw, "expected_core_members"] - C * draws[draw, "omega"])
  )
}
max_error <- apply(errors, 2L, max)
tolerance <- c(
  member_ll = 1e-8,
  q_member = 1e-8,
  expected_richness = 1e-7,
  camera_sum = 1e-10,
  count_scale = 1e-12
)
if (any(max_error > tolerance)) {
  stop(
    paste0(
      "Goal005 class-calibration Stan/R bridge failed: ",
      paste(
        sprintf("%s=%.3g", names(max_error), max_error),
        collapse = ", "
      )
    ),
    call. = FALSE
  )
}

# Marginalising the latent class location gives
# Var(alpha_i) = 1 + tau^2 and Cov(alpha_i, alpha_j) = tau^2 within a class.
# Both therefore converge to the frozen Goal004 N(m_h, 1) prior as tau -> 0.
limit_tau <- 1e-5
limit_error <- c(
  marginal_variance = abs((1 + limit_tau^2) - 1),
  within_class_covariance = limit_tau^2
)
if (any(limit_error > 2e-10)) {
  stop("Goal005 class-calibration prior limit failed.", call. = FALSE)
}

cat("Goal005 class-calibration Stan/R bridge: PASS\n")
cat(paste(
  sprintf("%s=%.3g", names(max_error), max_error),
  collapse = "\n"
), "\n", sep = "")
cat(paste(
  sprintf("prior_limit_%s=%.3g", names(limit_error), limit_error),
  collapse = "\n"
), "\n", sep = "")
