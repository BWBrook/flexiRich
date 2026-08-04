project_root <- if (dir.exists("R")) "." else file.path("..", "..")
source(file.path(project_root, "scripts", "source_goal002r.R"))
source_goal002r(project_root)
for (file in c("sim_config.R", "sim_effort.R", "sim_rng.R", "sim_flexirich_g.R")) {
  source(file.path(project_root, "R", file))
}

status <- check_goal002_cmdstan(error = FALSE)
if (!isTRUE(status$matches)) {
  stop(
    "CmdStan ", status$required_version,
    " is required for the Goal002R recovery experiment.",
    call. = FALSE
  )
}

cases <- tibble::tribble(
  ~scenario, ~n_occasions, ~simulation_seed, ~fit_seed,
  "short", 13L, 910013L, 220021013L,
  "short", 13L, 910014L, 220021014L,
  "long", 52L, 910052L, 220021052L,
  "long", 52L, 910053L, 220021053L
)

run_case <- function(scenario, n_occasions, simulation_seed, fit_seed) {
  simulation <- simulate_flexirich_g(flexirich_sim_config(
    candidate_pool_size = 8L,
    true_richness = 4L,
    n_cameras = 3L,
    n_occasions = n_occasions,
    mean_log_rate = log(0.002),
    sd_log_rate = 0.8,
    sd_camera = 0.25,
    daily_failure_prob = 0,
    daily_repair_prob = 1,
    seed = simulation_seed
  ))
  data <- prepare_flexirich_g_collapsed_data(
    sim_to_flexirich_g_data(simulation)
  )
  fit <- goal002r_fit(
    data,
    seed = fit_seed,
    sampler = goal002r_default_sampler(
      iter_warmup = 200L,
      iter_sampling = 200L,
      adapt_delta = 0.95,
      chains = 2L,
      parallel_chains = 2L
    ),
    quadrature_order = 128L,
    output_dir = tempfile(paste0("goal002r-recovery-", scenario, "-"))
  )
  goal002r_validate_fit_health(fit)
  summary <- goal002r_summarise_fit(fit)
  interval <- summary$richness$interval_90
  tibble::tibble(
    scenario = scenario,
    n_occasions = n_occasions,
    simulation_seed = simulation_seed,
    fit_seed = fit_seed,
    true_richness = simulation$truth$true_richness,
    observed_richness = simulation$truth$observed_richness,
    unseen_capacity = length(data$unseen_ids),
    posterior_mean = summary$richness$mean,
    posterior_median = summary$richness$median,
    interval_90_lower = interval[1L],
    interval_90_upper = interval[2L],
    covered = simulation$truth$true_richness >= interval[1L] &&
      simulation$truth$true_richness <= interval[2L],
    absolute_error = abs(summary$richness$mean - simulation$truth$true_richness),
    q_unseen_mean = summary$diagnostics$q_unseen[["mean"]]
  )
}

results <- dplyr::bind_rows(lapply(seq_len(nrow(cases)), function(i) {
  run_case(
    cases$scenario[i],
    cases$n_occasions[i],
    cases$simulation_seed[i],
    cases$fit_seed[i]
  )
}))
output_dir <- goal002r_output_path("recovery", project_root)
utils::write.csv(
  results,
  file.path(output_dir, "small-recovery-summary.csv"),
  row.names = FALSE
)
print(results)
cat("\nmean absolute error:", mean(results$absolute_error), "\n")
cat("90% interval coverage:", mean(results$covered), "\n")
cat("Goal002R small recovery experiment: COMPLETED (descriptive only)\n")
