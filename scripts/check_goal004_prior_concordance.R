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
  stop("The prior concordance run requires a clean worktree.", call. = FALSE)
}
git_commit <- system2(
  "git",
  c("rev-parse", "HEAD"),
  stdout = TRUE,
  stderr = TRUE
)
if (length(git_commit) != 1L ||
    !grepl("^[0-9a-f]{40}$", git_commit)) {
  stop("Could not identify the committed source.", call. = FALSE)
}

for (path in sort(list.files(
  "R",
  pattern = "\\.R$",
  full.names = TRUE
))) {
  source(path, local = FALSE)
}

reference_dir <- file.path(
  "outputs",
  "goal004",
  "task2-prior-only-v1"
)
reference_files <- c(
  "effort_by_camera.csv",
  "core_predictive_pmf.csv"
)
hash_path <- file.path(reference_dir, "output_hashes.csv")
completion_path <- file.path(reference_dir, "completion.txt")
if (!all(file.exists(file.path(reference_dir, reference_files))) ||
    !file.exists(hash_path) ||
    !file.exists(completion_path)) {
  stop(
    "Generate the frozen Goal004 Task 2 prior-only output first.",
    call. = FALSE
  )
}
completion <- readLines(completion_path, warn = FALSE)
if (!"status=PRIOR_ONLY_COMPLETE" %in% completion ||
    !"empirical_outcomes_used=false" %in% completion) {
  stop("The Task 2 prior-only completion contract is invalid.", call. = FALSE)
}
expected_hashes <- utils::read.csv(
  hash_path,
  stringsAsFactors = FALSE,
  check.names = FALSE
)
for (filename in reference_files) {
  expected <- expected_hashes$sha256[
    match(filename, expected_hashes$file)
  ]
  observed <- digest::digest(
    file = file.path(reference_dir, filename),
    algo = "sha256",
    serialize = FALSE
  )
  if (length(expected) != 1L || is.na(expected) || observed != expected) {
    stop("A frozen Task 2 reference hash failed.", call. = FALSE)
  }
}

mapping <- goal004_task2_candidate_mapping()$core
effort_reference <- tibble::as_tibble(utils::read.csv(
  file.path(reference_dir, "effort_by_camera.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)) |>
  dplyr::filter(window_id == "04w_lower_median") |>
  dplyr::arrange(camera_id)
if (nrow(effort_reference) != 9L) {
  stop("The lower-median Task 2 effort reference is invalid.", call. = FALSE)
}

candidate_pool <- tibble::tibble(species_id = mapping$candidate_id)
zero_effort <- tidyr::expand_grid(
  camera_id = effort_reference$camera_id,
  occasion_id = "zero_effort"
) |>
  dplyr::mutate(active_days = 0L)
zero_detections <- tidyr::expand_grid(
  species_id = candidate_pool$species_id,
  camera_id = effort_reference$camera_id,
  occasion_id = "zero_effort"
) |>
  dplyr::mutate(detected = NA_integer_)
source_data <- prepare_flexirich_g_data(
  candidate_pool,
  zero_effort,
  zero_detections
)
encounter_class <- stats::setNames(
  mapping$encounter_class,
  mapping$candidate_id
)
data <- prepare_goal004_flexirich_data(
  source_data,
  encounter_class,
  profile_id = "primary"
)
future_effort <- tidyr::expand_grid(
  camera_id = effort_reference$camera_id,
  week = seq_len(4L)
) |>
  dplyr::left_join(
    effort_reference |>
      dplyr::select(camera_id, active_days_training),
    by = "camera_id"
  ) |>
  dplyr::mutate(
    occasion_id = sprintf("future_%02d", week),
    active_days = as.integer(pmin(
      7,
      pmax(active_days_training - 7 * (week - 1L), 0)
    ))
  ) |>
  dplyr::select(camera_id, occasion_id, active_days)
if (!identical(
  as.integer(sum(future_effort$active_days)),
  as.integer(sum(effort_reference$active_days_training))
)) {
  stop("The prospective effort reconstruction failed.", call. = FALSE)
}

output_dir <- file.path(
  "outputs",
  "goal004",
  "task3-prior-concordance-v2"
)
fit_result <- fit_goal004_flexirich(
  data,
  seed = 40052L,
  output_dir = output_dir,
  rescue = TRUE,
  refresh = 100L
)
terminal_name <- if (fit_result$terminal_status == "primary_clean") {
  "primary"
} else if (fit_result$terminal_status == "rescue_clean") {
  "rescue"
} else {
  names(fit_result$attempts)[[length(fit_result$attempts)]]
}
terminal <- fit_result$attempts[[terminal_name]]
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
  terminal_status = fit_result$terminal_status,
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
if (fit_result$terminal_status == "final_nonclean") {
  writeLines(
    c(
      "status=PRIOR_CONCORDANCE_STOP",
      paste0("git_commit=", git_commit),
      "reason=nonclean_sampler",
      "empirical_outcomes_used=false"
    ),
    file.path(output_dir, "completion.txt")
  )
  stop("Goal004 prior concordance stopped at sampler diagnostics.", call. = FALSE)
}

prediction <- predict_goal004_flexirich(fit_result, future_effort)
fit <- .goal004_terminal_flexirich_fit(fit_result)
richness_summary <- posterior::summarise_draws(
  fit$draws(variables = "expected_richness"),
  "mean",
  "mcse_mean"
)
richness_mean <- richness_summary$mean
richness_mcse <- richness_summary$mcse_mean
if (!is.finite(richness_mean) || !is.finite(richness_mcse) ||
    richness_mcse <= 0) {
  stop("Expected-richness Monte Carlo diagnostics are missing.", call. = FALSE)
}
exact_mean <- 25
mean_error <- abs(richness_mean - exact_mean)
mean_limit <- 4 * richness_mcse

prior_reference <- goal004_beta_binomial_pmf(50L, 1, 1)
prior_tv <- goal004_total_variation(
  prediction$posterior_richness_pmf$probability,
  prior_reference$probability
)
future_reference <- tibble::as_tibble(utils::read.csv(
  file.path(reference_dir, "core_predictive_pmf.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)) |>
  dplyr::filter(
    profile_id == "primary",
    window_id == "04w_lower_median",
    outcome == "observed_richness"
  ) |>
  dplyr::arrange(value)
future_tv <- goal004_total_variation(
  prediction$future_discovery_pmf$probability,
  future_reference$probability
)
checks <- tibble::tibble(
  check = c(
    "terminal_sampler_clean",
    "expected_richness_mean_within_four_mcse",
    "prior_richness_total_variation",
    "four_week_detection_total_variation"
  ),
  value = c(1, mean_error, prior_tv, future_tv),
  threshold = c(1, mean_limit, 0.05, 0.05),
  comparison = c("equal", "at_most", "at_most", "at_most"),
  passed = c(
    TRUE,
    mean_error <= mean_limit,
    prior_tv <= 0.05,
    future_tv <= 0.05
  )
)
write_csv(checks, "concordance-checks.csv")
write_csv(
  prediction$posterior_richness_pmf,
  "posterior-richness-pmf.csv"
)
write_csv(prior_reference, "exact-prior-richness-pmf.csv")
write_csv(
  prediction$future_discovery_pmf,
  "posterior-four-week-discovery-pmf.csv"
)
write_csv(future_reference, "task2-four-week-reference-pmf.csv")
write_csv(prediction$candidate_membership, "candidate-membership.csv")
write_csv(prediction$future_identity, "future-identity.csv")
metadata <- tibble::tibble(
  git_commit = git_commit,
  fit_seed = 40052L,
  candidate_count = 50L,
  camera_count = 9L,
  grouped_likelihood_rows = data$stan_data$G,
  prospective_active_camera_days = sum(future_effort$active_days),
  exact_richness_mean = exact_mean,
  posterior_richness_mean = richness_mean,
  posterior_richness_mcse = richness_mcse,
  task2_reference_commit = sub("git_commit=", "", completion[
    grepl("^git_commit=", completion)
  ]),
  R_version = as.character(getRversion()),
  cmdstanr_version = as.character(utils::packageVersion("cmdstanr")),
  created_utc = format(Sys.time(), tz = "UTC", usetz = TRUE)
)
write_csv(metadata, "metadata.csv")

status <- if (all(checks$passed)) {
  "PRIOR_CONCORDANCE_PASS"
} else {
  "PRIOR_CONCORDANCE_STOP"
}
writeLines(
  c(
    paste0("status=", status),
    paste0("git_commit=", git_commit),
    "fit_seed=40052",
    "profile=primary",
    "empirical_outcomes_used=false"
  ),
  file.path(output_dir, "completion.txt")
)
if (status != "PRIOR_CONCORDANCE_PASS") {
  stop("Goal004 prior concordance failed a frozen gate.", call. = FALSE)
}
cat("Goal004 prior concordance: PASS\n")
print(checks)
