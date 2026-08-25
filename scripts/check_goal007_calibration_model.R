if (!dir.exists("R") ||
    !file.exists(file.path("stan", "goal007_shared_shift_calibration.stan"))) {
  stop("Run this script from the flexiRich repository root.", call. = FALSE)
}
for (path in sort(list.files("R", pattern = "[.]R$", full.names = TRUE))) {
  source(path, local = FALSE)
}

prior_bridge <- goal007_prior_bridge_metrics()
if (!prior_bridge$passed) {
  stop("Goal007 prior transformation bridge failed.", call. = FALSE)
}

contract <- read_goal007_task1_contract(verify_external = FALSE)
simulation <- simulate_goal007_task2_dataset(
  contract$task2_datasets[1, ],
  contract
)
data <- prepare_goal007_calibration_data(
  simulation$source_data,
  simulation$encounter_class,
  "shared_F5"
)
model <- compile_goal007_calibration_model()
source_hash <- digest::digest(
  file = file.path("stan", "goal007_shared_shift_calibration.stan"),
  algo = "sha256",
  serialize = FALSE
)
run_dir <- file.path(
  "outputs", "goal007", "shared-shift-calibration", "bridge",
  substr(source_hash, 1L, 16L)
)
unlink(run_dir, recursive = TRUE, force = TRUE)
dir.create(run_dir, recursive = TRUE, showWarnings = FALSE)
fit <- suppressMessages(model$sample(
  data = data$stan_data,
  seed = 70021L,
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
D <- data$stan_data$D
J <- data$stan_data$J
draws <- posterior::as_draws_matrix(fit$draws(variables = c(
  "common_shift", "contrast_deviation", "class_location", "alpha",
  "camera_effect", "history_log_likelihood", "log_selection_probability",
  "selection_adjusted_log_likelihood"
)))
errors <- matrix(
  0,
  nrow = nrow(draws),
  ncol = 5L,
  dimnames = list(NULL, c(
    "location", "history", "selection", "adjusted", "camera_sum"
  ))
)
for (draw in seq_len(nrow(draws))) {
  reference <- goal007_calibration_likelihood_terms(
    data,
    draws[draw, "common_shift"],
    draws[draw, "contrast_deviation"],
    draws[draw, sprintf("alpha[%d]", seq_len(D))],
    draws[draw, sprintf("camera_effect[%d]", seq_len(J))]
  )
  errors[draw, ] <- c(
    max(abs(
      draws[draw, sprintf("class_location[%d]", 1:2)] -
        reference$class_location
    )),
    max(abs(
      draws[draw, sprintf("history_log_likelihood[%d]", seq_len(D))] -
        reference$history_log_likelihood
    )),
    max(abs(
      draws[draw, sprintf("log_selection_probability[%d]", 1:2)] -
        reference$log_selection_probability
    )),
    abs(
      draws[draw, "selection_adjusted_log_likelihood"] -
        reference$selection_adjusted_log_likelihood
    ),
    abs(sum(draws[draw, sprintf("camera_effect[%d]", seq_len(J))]))
  )
}
stan_error <- apply(errors, 2L, max)
tolerance <- c(
  location = 1e-12,
  history = 1e-8,
  selection = 1e-8,
  adjusted = 1e-7,
  camera_sum = 1e-10
)
if (any(stan_error > tolerance)) {
  stop("Goal007 Stan/R likelihood bridge failed.", call. = FALSE)
}

artifact_result <- list(
  terminal_status = "primary_clean",
  data = data,
  output_dir = run_dir,
  attempts = list(primary = list(
    diagnostics = list(
      clean = TRUE,
      metrics = list(
        divergences = 0L,
        treedepth_hits = 0L,
        min_ebfmi = 1,
        max_rhat = 1,
        min_bulk_ess = 20,
        min_tail_ess = 20
      ),
      reasons = character()
    ),
    fit = fit
  ))
)
artifact <- make_goal007_calibration_artifact(
  artifact_result,
  source_hashes = tibble::tibble(
    source_id = "synthetic_bridge",
    sha256 = source_hash
  ),
  fit_seed = 70021L
)
if (!identical(names(artifact), goal007_output_schema()$calibration_artifact)) {
  stop("Goal007 calibration artifact schema failed.", call. = FALSE)
}

cat("Goal007 shared-shift calibration bridge: PASS\n")
cat(
  "maximum_transform_error=",
  format(prior_bridge$maximum_transform_error, digits = 6),
  "\n",
  sep = ""
)
cat(
  "maximum_covariance_error=",
  format(prior_bridge$maximum_covariance_error, digits = 6),
  "\n",
  sep = ""
)
cat(paste(
  sprintf("stan_%s_error=%.3g", names(stan_error), stan_error),
  collapse = "\n"
), "\n", sep = "")
cat("artifact_fields=", length(artifact), "\n", sep = "")
cat("empirical_outcomes_used=false\n")
