if (!dir.exists("R") ||
    !file.exists(file.path("stan", "goal003_flexirich.stan"))) {
  stop("Run this script from the flexiRich repository root.", call. = FALSE)
}

git_status <- system2(
  "git",
  c("status", "--porcelain"),
  stdout = TRUE,
  stderr = TRUE
)
if (length(git_status) > 0L) {
  stop("The smoke run requires a clean committed worktree.", call. = FALSE)
}
git_commit <- system2(
  "git",
  c("rev-parse", "HEAD"),
  stdout = TRUE,
  stderr = TRUE
)
if (length(git_commit) != 1L ||
    !grepl("^[0-9a-f]{40}$", git_commit)) {
  stop("Could not identify the committed smoke-run source.", call. = FALSE)
}

for (path in sort(list.files(
  "R",
  pattern = "\\.R$",
  full.names = TRUE
))) {
  source(path, local = FALSE)
}

simulation <- simulate_flexirich_g(flexirich_sim_config(
  candidate_pool_size = 12L,
  true_richness = 8L,
  n_cameras = 3L,
  n_occasions = 26L,
  mean_log_rate = log(0.02),
  sd_log_rate = 0.6,
  sd_camera = 0.2,
  initial_operating_prob = 1,
  daily_failure_prob = 0,
  daily_repair_prob = 0,
  seed = 30032L
))
source_data <- sim_to_flexirich_g_data(simulation)
candidate_data <- prepare_goal003_flexirich_data(source_data)
if (any(c("truth", "member", "true_richness") %in% names(candidate_data))) {
  stop("Synthetic truth entered the fitted candidate data.", call. = FALSE)
}

output_dir <- file.path(
  "outputs",
  "goal003",
  "flexirich-task3-smoke-v1"
)
fit <- fit_goal003_flexirich(
  candidate_data,
  seed = 30033L,
  output_dir = output_dir,
  rescue = TRUE,
  refresh = 100L
)
terminal_name <- if (identical(fit$terminal_status, "primary_clean")) {
  "primary"
} else if (identical(fit$terminal_status, "rescue_clean")) {
  "rescue"
} else {
  names(fit$attempts)[[length(fit$attempts)]]
}
terminal <- fit$attempts[[terminal_name]]
metrics <- terminal$diagnostics$metrics
if (is.null(metrics)) {
  metrics <- list(
    divergences = NA_integer_,
    treedepth_hits = NA_integer_,
    min_ebfmi = NA_real_,
    max_rhat = NA_real_,
    min_bulk_ess = NA_real_,
    min_tail_ess = NA_real_
  )
}
diagnostics <- tibble::tibble(
  git_commit = git_commit,
  terminal_status = fit$terminal_status,
  terminal_attempt = terminal_name,
  elapsed_seconds = terminal$elapsed_seconds,
  divergences = metrics$divergences,
  treedepth_hits = metrics$treedepth_hits,
  min_ebfmi = metrics$min_ebfmi,
  max_rhat = metrics$max_rhat,
  min_bulk_ess = metrics$min_bulk_ess,
  min_tail_ess = metrics$min_tail_ess,
  reasons = paste(terminal$diagnostics$reasons, collapse = "; ")
)
write_csv <- function(data, filename) {
  utils::write.csv(data, filename, row.names = FALSE, na = "")
}
write_csv(diagnostics, file.path(output_dir, "terminal-diagnostics.csv"))

if (!identical(fit$terminal_status, "final_nonclean")) {
  future_effort <- tidyr::expand_grid(
    camera_id = candidate_data$camera_ids,
    occasion_id = sprintf("future_%02d", 1:4)
  ) |>
    dplyr::mutate(active_days = 7L)
  prediction <- predict_goal003_flexirich(fit, future_effort)
  richness_sum <- sum(prediction$richness_pmf$probability)
  discovery_sum <- sum(prediction$new_species_count_pmf$probability)
  invariants <- tibble::tibble(
    invariant = c(
      "richness_pmf_normalised",
      "discovery_pmf_normalised",
      "richness_support_matches_pool"
    ),
    value = c(
      richness_sum,
      discovery_sum,
      max(prediction$richness_pmf$richness)
    ),
    expected = c(1, 1, length(candidate_data$candidate_ids)),
    passed = c(
      abs(richness_sum - 1) < 1e-12,
      abs(discovery_sum - 1) < 1e-12,
      max(prediction$richness_pmf$richness) ==
        length(candidate_data$candidate_ids)
    )
  )
  write_csv(
    prediction$richness_pmf,
    file.path(output_dir, "richness-pmf.csv")
  )
  write_csv(
    prediction$new_species_count_pmf,
    file.path(output_dir, "new-species-count-pmf.csv")
  )
  write_csv(
    prediction$grid_identity,
    file.path(output_dir, "membership-probabilities.csv")
  )
  write_csv(
    prediction$future_identity,
    file.path(output_dir, "future-detection-probabilities.csv")
  )
  write_csv(invariants, file.path(output_dir, "invariants.csv"))
  if (!all(invariants$passed)) {
    writeLines(
      c("status=INVARIANT_FAILURE", paste0("git_commit=", git_commit)),
      file.path(output_dir, "completion-status.txt")
    )
    stop("The Goal003 smoke prediction failed an invariant.", call. = FALSE)
  }
}

writeLines(
  c(
    paste0("status=", toupper(fit$terminal_status)),
    paste0("git_commit=", git_commit),
    "simulation_seed=30032",
    "fit_seed=30033",
    "empirical_outcomes_used=false"
  ),
  file.path(output_dir, "completion-status.txt")
)
cat("Goal003 FlexiRich smoke: ", fit$terminal_status, "\n", sep = "")
