if (!dir.exists("R") ||
    !file.exists(file.path("stan", "goal006_selection_calibration.stan"))) {
  stop("Run this script from the flexiRich repository root.", call. = FALSE)
}
for (path in sort(list.files("R", pattern = "[.]R$", full.names = TRUE))) {
  source(path, local = FALSE)
}

contract <- read_goal006_task1_contract(verify_external = FALSE)
quadrature <- goal006_gauss_hermite(64L)
bridge_cases <- tidyr::crossing(
  class_location = log(c(0.00025, 0.0005, 0.001, 0.002, 0.004)),
  log_rate_sd = c(0.75, 1, 1.25)
)
active_days <- c(310, 280, 260, 240)
camera_effect <- c(-0.3, -0.1, 0.1, 0.3)
step <- 1e-5
bridge <- lapply(seq_len(nrow(bridge_cases)), function(index) {
  row <- bridge_cases[index, ]
  reference <- goal006_selection_reference(
    row$class_location,
    row$log_rate_sd,
    active_days,
    camera_effect
  )
  f <- function(shift) {
    goal006_selection_log_probability(
      row$class_location + shift,
      row$log_rate_sd,
      active_days,
      camera_effect,
      quadrature
    )
  }
  tibble::tibble(
    value_error = abs(f(0) - reference$log_probability),
    gradient_error = abs(
      (f(step) - f(-step)) / (2 * step) -
        reference$gradient_class_location
    )
  )
}) |>
  dplyr::bind_rows()
max_value_error <- max(bridge$value_error)
max_gradient_error <- max(bridge$gradient_error)
if (max_value_error > 1e-8 || max_gradient_error > 1e-5) {
  stop("Goal006 deterministic likelihood bridge failed.", call. = FALSE)
}

simulation <- simulate_goal006_calibration_dataset(
  contract$synthetic[1, ],
  contract
)
data <- prepare_goal006_calibration_data(
  simulation$source_data,
  simulation$encounter_class,
  contract$calibration_fits[1, ]
)
model <- compile_goal006_calibration_model()
source_hash <- digest::digest(
  file = file.path("stan", "goal006_selection_calibration.stan"),
  algo = "sha256",
  serialize = FALSE
)
run_dir <- file.path(
  "outputs", "goal006", "selection-calibration", "bridge",
  substr(source_hash, 1L, 16L)
)
unlink(run_dir, recursive = TRUE, force = TRUE)
dir.create(run_dir, recursive = TRUE, showWarnings = FALSE)
fit <- suppressMessages(model$sample(
  data = data$stan_data,
  seed = 60021L,
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
  "class_location", "alpha", "camera_effect",
  "history_log_likelihood", "log_selection_probability",
  "selection_adjusted_log_likelihood"
)))
errors <- matrix(
  0,
  nrow = nrow(draws),
  ncol = 4L,
  dimnames = list(NULL, c("history", "selection", "adjusted", "camera_sum"))
)
for (draw in seq_len(nrow(draws))) {
  reference <- goal006_calibration_likelihood_terms(
    data,
    draws[draw, sprintf("class_location[%d]", 1:2)],
    draws[draw, sprintf("alpha[%d]", seq_len(D))],
    draws[draw, sprintf("camera_effect[%d]", seq_len(J))]
  )
  errors[draw, ] <- c(
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
tolerance <- c(history = 1e-8, selection = 1e-8, adjusted = 1e-7, camera_sum = 1e-10)
if (any(stan_error > tolerance)) {
  stop("Goal006 Stan/R likelihood bridge failed.", call. = FALSE)
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
artifact <- make_goal006_calibration_artifact(
  artifact_result,
  source_receipts = tibble::tibble(
    source_id = "synthetic_bridge",
    sha256 = source_hash
  ),
  fit_seed = 60021L
)
if (!identical(names(artifact), goal006_output_schema()$calibration_artifact)) {
  stop("Goal006 calibration artifact schema failed.", call. = FALSE)
}

cat("Goal006 selection-calibration bridge: PASS\n")
cat("maximum_value_error=", format(max_value_error, digits = 6), "\n", sep = "")
cat("maximum_gradient_error=", format(max_gradient_error, digits = 6), "\n", sep = "")
cat(paste(
  sprintf("stan_%s_error=%.3g", names(stan_error), stan_error),
  collapse = "\n"
), "\n", sep = "")
cat("artifact_fields=", length(artifact), "\n", sep = "")
cat("empirical_outcomes_used=false\n")
