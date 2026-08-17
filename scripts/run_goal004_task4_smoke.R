if (!dir.exists("R") || !file.exists("renv.lock")) {
  stop("Run this script from the flexiRich repository root.", call. = FALSE)
}

git_status <- system2(
  "git",
  c("status", "--porcelain"),
  stdout = TRUE,
  stderr = TRUE
)
if (length(git_status) > 0L) {
  stop("The Goal004 Task 4 smoke requires a clean worktree.", call. = FALSE)
}
git_commit <- system2(
  "git",
  c("rev-parse", "HEAD"),
  stdout = TRUE,
  stderr = TRUE
)
if (length(git_commit) != 1L || !grepl("^[0-9a-f]{40}$", git_commit)) {
  stop("Could not identify the committed smoke source.", call. = FALSE)
}

for (path in sort(list.files("R", pattern = "[.]R$", full.names = TRUE))) {
  source(path, local = FALSE)
}

manifest <- read_goal004_task4_manifests()
dataset_row <- manifest$datasets |>
  dplyr::filter(
    scenario_id == "aligned_mid",
    train_occasions == 26L,
    replicate == 8L
  )
fit_row <- manifest$fits |>
  dplyr::filter(
    dataset_id == dataset_row$dataset_id,
    method == "goal004",
    run_role == "primary"
  )
output <- file.path(
  "outputs",
  "goal004",
  "task4-smoke",
  substr(git_commit, 1L, 12L)
)
if (dir.exists(output) || file.exists(output)) {
  stop("The committed Goal004 Task 4 smoke already exists.", call. = FALSE)
}
dir.create(file.path(output, "datasets"), recursive = TRUE)
dir.create(file.path(output, "fits"))
prior <- goal004_task4_prior_forecasts(
  n_draws = 50000L,
  seed = 40042L,
  manifest = manifest
)
dataset_dir <- publish_goal003_task4_artifact(
  file.path(output, "datasets"),
  dataset_row$dataset_id,
  function(staging) {
    .goal004_task4_write_dataset(dataset_row, manifest, prior, staging)
  }
)
simulation <- readRDS(file.path(dataset_dir, "simulation.rds"))
fit_dir <- publish_goal003_task4_artifact(
  file.path(output, "fits"),
  fit_row$fit_id,
  function(staging) {
    .goal004_task4_write_fit(fit_row, simulation, staging, refresh = 100L)
  }
)
status <- utils::read.csv(
  file.path(fit_dir, "fit-status.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
score <- utils::read.csv(
  file.path(fit_dir, "richness-score.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)
compressed <- list.files(
  file.path(fit_dir, "sampler"),
  pattern = "[.]csv[.]gz$",
  recursive = TRUE,
  full.names = TRUE
)
pmf_path <- file.path(fit_dir, "richness-pmf.csv")
pmf_normalised <- FALSE
if (file.exists(pmf_path)) {
  pmf_normalised <- abs(sum(utils::read.csv(
    pmf_path,
    check.names = FALSE
  )$probability) - 1) <= 1e-10
}
checks <- tibble::tibble(
  check = c(
    "terminal_sampler_clean",
    "richness_prediction_available",
    "richness_pmf_normalised",
    "raw_sampler_csv_compressed",
    "fitted_data_excludes_truth"
  ),
  passed = c(
    status$terminal_clean[[1L]],
    score$prediction_available[[1L]],
    pmf_normalised,
    length(compressed) >= 4L,
    !any(c("truth", "member", "true_richness") %in%
      names(simulation$training_data))
  )
)
utils::write.csv(checks, file.path(output, "smoke-checks.csv"), row.names = FALSE)
smoke_status <- if (all(checks$passed)) "SMOKE_PASS" else "SMOKE_STOP"
writeLines(
  c(
    paste0("status=", smoke_status),
    paste0("git_commit=", git_commit),
    paste0("dataset_id=", dataset_row$dataset_id),
    paste0("fit_id=", fit_row$fit_id),
    "prior_seed=40042",
    "empirical_outcomes_used=false"
  ),
  file.path(output, "completion-status.txt")
)
if (smoke_status != "SMOKE_PASS") {
  stop("Goal004 Task 4 smoke failed.", call. = FALSE)
}
cat("Goal004 Task 4 smoke: PASS\n")
print(checks)
