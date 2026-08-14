if (!dir.exists("R") ||
    !file.exists(file.path("stan", "goal004_flexirich.stan"))) {
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
  stop("Could not identify the committed smoke source.", call. = FALSE)
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
  mean_log_rate = log(0.002),
  sd_log_rate = 0.7,
  sd_camera = 0.2,
  initial_operating_prob = 1,
  daily_failure_prob = 0,
  daily_repair_prob = 0,
  seed = 40053L
))
source_data <- sim_to_flexirich_g_data(simulation)
encounter_class <- stats::setNames(
  c(rep("routine", 9L), rep("occasional", 3L)),
  source_data$candidate_ids
)
candidate_data <- prepare_goal004_flexirich_data(
  source_data,
  encounter_class,
  profile_id = "primary"
)
if (any(c("truth", "member", "true_richness") %in% names(candidate_data))) {
  stop("Synthetic truth entered the fitted candidate data.", call. = FALSE)
}

output_dir <- file.path(
  "outputs",
  "goal004",
  "task3-smoke-v1"
)
fit <- fit_goal004_flexirich(
  candidate_data,
  seed = 40054L,
  output_dir = output_dir,
  rescue = TRUE,
  refresh = 100L
)
terminal_name <- if (fit$terminal_status == "primary_clean") {
  "primary"
} else if (fit$terminal_status == "rescue_clean") {
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
write_csv <- function(value, filename) {
  utils::write.csv(value, file.path(output_dir, filename), row.names = FALSE)
}
write_csv(diagnostics, "terminal-diagnostics.csv")

if (fit$terminal_status != "final_nonclean") {
  future_effort <- tidyr::expand_grid(
    camera_id = candidate_data$camera_ids,
    occasion_id = sprintf("future_%02d", 1:4)
  ) |>
    dplyr::mutate(active_days = 7L)
  prediction <- predict_goal004_flexirich(fit, future_effort)
  detected_rows <- prediction$candidate_membership$training_detected
  invariants <- tibble::tibble(
    invariant = c(
      "posterior_richness_pmf_normalised",
      "prior_richness_pmf_normalised",
      "discovery_pmf_normalised",
      "richness_support_matches_pool",
      "detected_candidates_have_membership_one",
      "fitted_data_excludes_truth"
    ),
    value = c(
      sum(prediction$posterior_richness_pmf$probability),
      sum(prediction$prior_richness_pmf$probability),
      sum(prediction$future_discovery_pmf$probability),
      max(prediction$posterior_richness_pmf$richness),
      if (any(detected_rows)) {
        min(prediction$candidate_membership$
          posterior_membership_probability[detected_rows])
      } else {
        1
      },
      as.numeric(!any(c(
        "truth", "member", "true_richness"
      ) %in% names(candidate_data)))
    ),
    expected = c(1, 1, 1, 12, 1, 1),
    passed = c(
      abs(sum(prediction$posterior_richness_pmf$probability) - 1) < 1e-12,
      abs(sum(prediction$prior_richness_pmf$probability) - 1) < 1e-12,
      abs(sum(prediction$future_discovery_pmf$probability) - 1) < 1e-12,
      max(prediction$posterior_richness_pmf$richness) == 12L,
      !any(detected_rows) || all(
        prediction$candidate_membership$
          posterior_membership_probability[detected_rows] == 1
      ),
      !any(c("truth", "member", "true_richness") %in% names(candidate_data))
    )
  )
  write_csv(
    prediction$posterior_richness_pmf,
    "posterior-richness-pmf.csv"
  )
  write_csv(prediction$prior_richness_pmf, "prior-richness-pmf.csv")
  write_csv(
    prediction$future_discovery_pmf,
    "future-discovery-pmf.csv"
  )
  write_csv(prediction$candidate_membership, "candidate-membership.csv")
  write_csv(prediction$future_identity, "future-identity.csv")
  write_csv(invariants, "invariants.csv")
  if (!all(invariants$passed)) {
    writeLines(
      c(
        "status=INVARIANT_FAILURE",
        paste0("git_commit=", git_commit),
        "empirical_outcomes_used=false"
      ),
      file.path(output_dir, "completion.txt")
    )
    stop("The Goal004 smoke failed an invariant.", call. = FALSE)
  }
}

writeLines(
  c(
    paste0("status=", toupper(fit$terminal_status)),
    paste0("git_commit=", git_commit),
    "simulation_seed=40053",
    "fit_seed=40054",
    "profile=primary",
    "empirical_outcomes_used=false"
  ),
  file.path(output_dir, "completion.txt")
)
if (fit$terminal_status == "final_nonclean") {
  stop("Goal004 smoke ended with non-clean diagnostics.", call. = FALSE)
}
cat("Goal004 FlexiRich smoke: ", fit$terminal_status, "\n", sep = "")
