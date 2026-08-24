if (!dir.exists("R") || !file.exists("renv.lock")) {
  stop("Run this script from the flexiRich repository root.", call. = FALSE)
}
for (path in sort(list.files("R", pattern = "[.]R$", full.names = TRUE))) {
  source(path, local = FALSE)
}

contract <- read_goal006_task1_contract(verify_external = FALSE)
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
git_commit <- .goal003_task4_git_state(.goal003_project_root())
output <- file.path("outputs", "goal006", "task2-smoke", git_commit)
if (dir.exists(output)) {
  unlink(output, recursive = TRUE, force = TRUE)
}
dir.create(output, recursive = TRUE, showWarnings = FALSE)
fit <- suppressMessages(model$sample(
  data = data$stan_data,
  seed = 60022L,
  chains = 2L,
  parallel_chains = 2L,
  iter_warmup = 300L,
  iter_sampling = 300L,
  adapt_delta = 0.95,
  max_treedepth = 12L,
  refresh = 0L,
  sig_figs = 18L,
  show_messages = FALSE,
  output_dir = output,
  output_basename = "smoke"
))
summary <- fit$summary(variables = "class_location")
sampler <- fit$sampler_diagnostics(format = "df")
passed <- nrow(summary) == 2L && all(is.finite(summary$mean)) &&
  all(summary$rhat < 1.1) && sum(sampler$divergent__) == 0L
status <- if (passed) "SMOKE_PASS" else "SMOKE_STOP"
writeLines(
  c(
    paste0("status=", status),
    paste0("git_commit=", git_commit),
    paste0("simulation_seed=", contract$synthetic$simulation_seed[[1L]]),
    "empirical_outcomes_used=false"
  ),
  file.path(output, "completion-status.txt")
)
cat("Goal006 Task 2 smoke: ", status, "\n", sep = "")
cat("git_commit=", git_commit, "\n", sep = "")
cat("empirical_outcomes_used=false\n")
if (!passed) {
  quit(status = 1L)
}
