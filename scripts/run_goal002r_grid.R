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
    " is required for the Goal002R recovery grid.",
    call. = FALSE
  )
}

cases <- tidyr::expand_grid(
  effort = c("high", "low"),
  detectability = c("low", "high"),
  true_richness = c(2L, 6L),
  n_occasions = c(13L, 52L)
) |>
  dplyr::mutate(
    case_id = dplyr::row_number(),
    simulation_seed = 930000L + case_id,
    fit_seed = 230000000L + case_id
  )

run_case <- function(case) {
  effort_parameters <- if (identical(case$effort, "high")) {
    list(
      initial_operating_prob = 1,
      daily_failure_prob = 0,
      daily_repair_prob = 1
    )
  } else {
    list(
      initial_operating_prob = 1,
      daily_failure_prob = 0.03,
      daily_repair_prob = 0.15
    )
  }
  mean_log_rate <- if (identical(case$detectability, "high")) {
    log(0.004)
  } else {
    log(0.001)
  }
  simulation <- simulate_flexirich_g(do.call(
    flexirich_sim_config,
    c(
      list(
        candidate_pool_size = 8L,
        true_richness = case$true_richness,
        n_cameras = 3L,
        n_occasions = case$n_occasions,
        mean_log_rate = mean_log_rate,
        sd_log_rate = 0.8,
        sd_camera = 0.25,
        seed = case$simulation_seed
      ),
      effort_parameters
    )
  ))
  data <- prepare_flexirich_g_collapsed_data(
    sim_to_flexirich_g_data(simulation)
  )
  fit <- tryCatch(
    goal002r_fit(
      data,
      seed = case$fit_seed,
      sampler = goal002r_default_sampler(
        iter_warmup = 200L,
        iter_sampling = 200L,
        adapt_delta = 0.95,
        chains = 2L,
        parallel_chains = 2L
      ),
      quadrature_order = goal002r_contract()$quadrature_default,
      output_dir = tempfile(paste0("goal002r-grid-", case$case_id, "-"))
    ),
    error = function(error) error
  )
  base <- tibble::tibble(
    case_id = case$case_id,
    effort = case$effort,
    detectability = case$detectability,
    true_richness = simulation$truth$true_richness,
    n_occasions = case$n_occasions,
    simulation_seed = case$simulation_seed,
    fit_seed = case$fit_seed,
    observed_richness = simulation$truth$observed_richness,
    unseen_true_members = simulation$truth$unseen_true_members,
    unseen_true_fraction = if (simulation$truth$true_richness == 0L) {
      NA_real_
    } else {
      simulation$truth$unseen_true_members / simulation$truth$true_richness
    },
    total_detections = simulation$truth$total_detections,
    unseen_capacity = length(data$unseen_ids)
  )
  if (inherits(fit, "error")) {
    failure_status <- if (grepl(
      "at least one detected candidate",
      conditionMessage(fit),
      fixed = TRUE
    )) {
      "no_detected_candidate"
    } else {
      "sampler_health_failed"
    }
    return(dplyr::mutate(
      base,
      status = failure_status,
      error = conditionMessage(fit),
      posterior_mean = NA_real_,
      posterior_median = NA_real_,
      interval_90_lower = NA_integer_,
      interval_90_upper = NA_integer_,
      covered = NA,
      absolute_error = NA_real_,
      q_unseen_mean = NA_real_,
      divergences = NA_real_,
      treedepth_hits = NA_real_,
      min_ebfmi = NA_real_,
      max_rhat = NA_real_,
      min_bulk_ess = NA_real_,
      min_tail_ess = NA_real_
    ))
  }
  summary <- goal002r_summarise_fit(fit)
  interval <- summary$richness$interval_90
  health <- fit$health$metrics
  dplyr::mutate(
    base,
    status = "ok",
    error = NA_character_,
    posterior_mean = summary$richness$mean,
    posterior_median = summary$richness$median,
    interval_90_lower = interval[1L],
    interval_90_upper = interval[2L],
    covered = simulation$truth$true_richness >= interval[1L] &&
      simulation$truth$true_richness <= interval[2L],
    absolute_error = abs(summary$richness$mean - simulation$truth$true_richness),
    q_unseen_mean = summary$diagnostics$q_unseen[["mean"]],
    divergences = health$divergences,
    treedepth_hits = health$treedepth_hits,
    min_ebfmi = health$min_ebfmi,
    max_rhat = health$max_rhat,
    min_bulk_ess = health$min_bulk_ess,
    min_tail_ess = health$min_tail_ess
  )
}

results <- dplyr::bind_rows(lapply(seq_len(nrow(cases)), function(index) {
  run_case(cases[index, , drop = FALSE])
}))
output_dir <- goal002r_output_path("recovery", project_root)
output_file <- file.path(output_dir, "grid-summary.csv")
utils::write.csv(results, output_file, row.names = FALSE)

print(results)
successful <- results[results$status == "ok", , drop = FALSE]
cat("\nfit failures:", sum(results$status != "ok"), "of", nrow(results), "\n")
if (nrow(successful) > 0L) {
  print(successful |>
    dplyr::group_by(effort, detectability, true_richness, n_occasions) |>
    dplyr::summarise(
      n = dplyr::n(),
      mean_absolute_error = mean(absolute_error),
      interval_90_coverage = mean(covered),
      mean_unseen_true_fraction = mean(unseen_true_fraction),
      .groups = "drop"
    ))
}
cat("\nGoal002R bounded recovery grid: COMPLETED (descriptive only)\n")
cat("summary:", output_file, "\n")
