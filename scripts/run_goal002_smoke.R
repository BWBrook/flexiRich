if (!dir.exists("R") ||
    !file.exists(file.path("stan", "flexirich_g.stan"))) {
  stop(
    "Run this script from the flexiRich repository root.",
    call. = FALSE
  )
}

for (path in sort(list.files(
  "R",
  pattern = "\\.R$",
  full.names = TRUE
))) {
  source(path, local = FALSE)
}

simulation_seed <- 72002001L
fit_seed <- 72002101L
run_id <- paste0(
  "run-",
  format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC"),
  "-",
  Sys.getpid()
)
output_dir <- file.path(
  "outputs",
  "goal002",
  "smoke",
  run_id
)

config <- flexirich_sim_config(
  candidate_pool_size = 4L,
  true_richness = 2L,
  n_cameras = 2L,
  n_occasions = 26L,
  mean_log_rate = log(0.01),
  sd_log_rate = 0.5,
  sd_camera = 0.2,
  seed = simulation_seed
)
simulation <- simulate_flexirich_g(config)
inference_data <- sim_to_flexirich_g_data(simulation)

forbidden_truth <- c(
  "member",
  "true_richness",
  "alpha",
  "camera_effect",
  "encounter_rate",
  "detect_prob",
  "detect_prob_if_member",
  "truth",
  "simulation",
  "simulator"
)
if (length(intersect(forbidden_truth, names(inference_data))) > 0L ||
    length(intersect(
      forbidden_truth,
      names(inference_data$stan_data)
    )) > 0L ||
    length(intersect(
      forbidden_truth,
      names(attributes(inference_data))
    )) > 0L) {
  stop(
    "Simulation truth entered the inference-data contract.",
    call. = FALSE
  )
}

start_time <- proc.time()[["elapsed"]]
fit <- fit_flexirich_g(
  data = inference_data,
  seed = fit_seed,
  prior_profile = goal002_prior_profiles()$primary,
  output_dir = output_dir,
  allow_rescue = TRUE
)
runtime_seconds <- as.numeric(
  proc.time()[["elapsed"]] - start_time
)

cat("Goal 002 deterministic smoke fit\n")
cat("  simulation seed:", simulation_seed, "\n")
cat("  fit seed:", fit_seed, "\n")
cat("  output:", output_dir, "\n")
cat("  runtime seconds:", format(runtime_seconds, digits = 5L), "\n")
cat("  terminal status:", fit$terminal_status, "\n")
for (attempt_id in names(fit$attempts)) {
  attempt <- fit$attempts[[attempt_id]]
  cat("  attempt:", attempt_id, "\n")
  cat("    sampler:", attempt$sampler_profile_id, "\n")
  cat("    seed:", attempt$seed, "\n")
  cat("    clean:", attempt$clean, "\n")
  cat(
    "    reasons:",
    if (length(attempt$diagnostics$reasons) == 0L) {
      "none"
    } else {
      paste(attempt$diagnostics$reasons, collapse = ", ")
    },
    "\n"
  )
  print(attempt$diagnostics$metrics)
  cat("    richness diagnostics:\n")
  print(attempt$diagnostics$richness)
  cat("    generated-richness contract:\n")
  print(attempt$diagnostics$generated_richness)
}

if (!fit$terminal_status %in% c("primary_clean", "rescue_clean")) {
  stop(
    "The deterministic smoke fit did not reach a clean terminal state.",
    call. = FALSE
  )
}

draws <- as.matrix(fit$draws)
if (nrow(draws) < 20L) {
  stop("The smoke fit returned fewer than 20 draws.", call. = FALSE)
}
generated_contract <- .goal002_check_generated_richness(
  fit$draws,
  fit$detected_ever
)
if (!identical(generated_contract$status, "passed")) {
  stop(
    "The full generated-richness draw contract did not pass.",
    call. = FALSE
  )
}

indexed_names <- function(variable, size) {
  sprintf("%s[%d]", variable, seq_len(size))
}

C <- length(fit$candidate_ids)
J <- length(fit$camera_ids)
alpha_names <- indexed_names("alpha", C)
camera_names <- indexed_names("camera_effect", J)
member_names <- indexed_names("member_ll", C)
q_names <- indexed_names("q_member", C)
g_names <- indexed_names("g_member", C)
required_draws <- c(
  "omega",
  alpha_names,
  camera_names,
  member_names,
  q_names,
  g_names,
  "S_grid",
  "expected_richness"
)
missing_draws <- setdiff(required_draws, colnames(draws))
if (length(missing_draws) > 0L) {
  stop(
    "Smoke draws are missing: ",
    paste(missing_draws, collapse = ", "),
    ".",
    call. = FALSE
  )
}

for (draw in seq_len(20L)) {
  expected_member <- member_log_likelihood(
    inference_data,
    draws[draw, alpha_names],
    draws[draw, camera_names]
  )
  expected_q <- conditional_membership_probability(
    expected_member,
    inference_data$stan_data$detected_ever,
    draws[draw, "omega"]
  )
  if (any(abs(
    draws[draw, member_names] - expected_member
  ) > 1e-8)) {
    stop(
      "Stan and R member_ll differ by more than 1e-8.",
      call. = FALSE
    )
  }
  if (any(abs(draws[draw, q_names] - expected_q) > 1e-8)) {
    stop(
      "Stan and R q_member differ by more than 1e-8.",
      call. = FALSE
    )
  }

  conditional_pmf <- poisson_binomial_pmf(
    as.numeric(draws[draw, q_names])
  )
  if (abs(sum(conditional_pmf) - 1) > 1e-12) {
    stop(
      "A conditional richness PMF does not sum to one.",
      call. = FALSE
    )
  }
}

detected <- inference_data$stan_data$detected_ever == 1L
q_draws <- draws[, q_names, drop = FALSE]
g_draws <- draws[, g_names, drop = FALSE]
if (any(q_draws[, detected, drop = FALSE] != 1) ||
    any(g_draws[, detected, drop = FALSE] != 1)) {
  stop(
    "Detected candidates do not have certain membership.",
    call. = FALSE
  )
}

richness <- draws[, "S_grid"]
observed_richness <- sum(detected)
if (any(!is.finite(richness)) ||
    any(richness != round(richness)) ||
    any(richness < observed_richness | richness > C) ||
    any(richness != rowSums(g_draws))) {
  stop(
    "Richness draws violate integer, support, or reconstruction rules.",
    call. = FALSE
  )
}
if (any(abs(
  draws[, "expected_richness"] - rowSums(q_draws)
) > 1e-8)) {
  stop(
    "Expected richness does not reconstruct from q_member.",
    call. = FALSE
  )
}

cat("Goal 002 deterministic smoke: PASS\n")
