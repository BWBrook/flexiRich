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
  stop("The prior check requires a clean committed worktree.", call. = FALSE)
}
git_commit <- system2(
  "git",
  c("rev-parse", "HEAD"),
  stdout = TRUE,
  stderr = TRUE
)
if (length(git_commit) != 1L ||
    !grepl("^[0-9a-f]{40}$", git_commit)) {
  stop("Could not identify the committed prior-check source.", call. = FALSE)
}

for (path in sort(list.files(
  "R",
  pattern = "\\.R$",
  full.names = TRUE
))) {
  source(path, local = FALSE)
}

output_dir <- file.path(
  "outputs",
  "goal003",
  "flexirich-task3-prior-v3"
)
if (file.exists(output_dir) || dir.exists(output_dir)) {
  stop("The frozen prior-check output already exists.", call. = FALSE)
}
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

profile_names <- names(goal003_flexirich_prior_profiles())
results <- lapply(profile_names, function(profile) {
  simulate_goal003_flexirich_prior(
    profile_id = profile,
    n_draws = 50000L,
    seed = 30034L,
    candidate_pool_size = 50L,
    n_cameras = 9L
  )
})
names(results) <- profile_names

distribution <- dplyr::bind_rows(lapply(profile_names, function(profile_name) {
  result <- results[[profile_name]]
  dplyr::mutate(
    result$distribution_summary,
    profile = .env$profile_name,
    profile_id = result$profile_id,
    .before = 1L
  )
}))
invariants <- dplyr::bind_rows(lapply(profile_names, function(profile_name) {
  result <- results[[profile_name]]
  dplyr::mutate(
    result$invariants,
    profile = .env$profile_name,
    profile_id = result$profile_id,
    .before = 1L
  )
}))
draw_summary <- dplyr::bind_rows(lapply(profile_names, function(profile_name) {
  result <- results[[profile_name]]
  draws <- result$draws
  fields <- setdiff(names(draws), "draw")
  dplyr::bind_rows(lapply(fields, function(field) {
    values <- draws[[field]]
    quantiles <- stats::quantile(
      values,
      probs = c(0.025, 0.5, 0.975),
      names = FALSE,
      type = 8
    )
    tibble::tibble(
      profile = profile_name,
      profile_id = result$profile_id,
      metric = field,
      mean = mean(values),
      sd = stats::sd(values),
      q025 = quantiles[[1L]],
      median = quantiles[[2L]],
      q975 = quantiles[[3L]],
      minimum = min(values),
      maximum = max(values)
    )
  }))
}))
metadata <- tibble::tibble(
  git_commit = git_commit,
  seed = 30034L,
  n_draws = 50000L,
  candidate_pool_size = 50L,
  n_cameras = 9L,
  R_version = as.character(getRversion()),
  cmdstanr_version = as.character(utils::packageVersion("cmdstanr")),
  posterior_version = as.character(utils::packageVersion("posterior")),
  created_utc = format(Sys.time(), tz = "UTC", usetz = TRUE)
)

write_csv <- function(data, filename) {
  utils::write.csv(data, filename, row.names = FALSE, na = "")
}
write_csv(distribution, file.path(output_dir, "distribution-summary.csv"))
write_csv(draw_summary, file.path(output_dir, "draw-summary.csv"))
write_csv(invariants, file.path(output_dir, "invariants.csv"))
write_csv(metadata, file.path(output_dir, "metadata.csv"))
status <- if (all(invariants$passed)) "PASS" else "FAIL"
writeLines(
  c(
    paste0("status=", status),
    paste0("git_commit=", git_commit),
    "profiles=primary,membership_regularised,mu_alpha_wide,tail_wide",
    "empirical_outcomes_used=false"
  ),
  file.path(output_dir, "completion-status.txt")
)
if (!identical(status, "PASS")) {
  stop("The frozen Goal003 prior check failed an invariant.", call. = FALSE)
}
cat("Goal003 FlexiRich prior check: PASS\n")
