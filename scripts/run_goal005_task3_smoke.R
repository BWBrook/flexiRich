if (!dir.exists("R") || !file.exists("renv.lock")) {
  stop("Run this script from the flexiRich repository root.", call. = FALSE)
}

git_status <- system2("git", c("status", "--porcelain"), stdout = TRUE)
if (length(git_status) > 0L) {
  stop("The Goal005 Task 3 smoke requires a clean worktree.", call. = FALSE)
}
git_commit <- system2("git", c("rev-parse", "HEAD"), stdout = TRUE)
if (length(git_commit) != 1L || !grepl("^[0-9a-f]{40}$", git_commit)) {
  stop("Could not identify the committed Task 3 source.", call. = FALSE)
}

for (path in sort(list.files("R", pattern = "[.]R$", full.names = TRUE))) {
  source(path, local = FALSE)
}

manifest <- read_goal005_task3_manifest()
dataset_row <- manifest$datasets |>
  dplyr::filter(
    scenario_id == "aligned_mid",
    train_occasions == 12L,
    replicate == 1L
  )
fit_rows <- manifest$fits |>
  dplyr::filter(
    dataset_id == dataset_row$dataset_id,
    information_level %in% c("C0", "F1.25")
  ) |>
  dplyr::arrange(precision_code)
output <- file.path(
  "outputs",
  "goal005",
  "task3-smoke",
  substr(git_commit, 1L, 12L)
)
if (dir.exists(output) || file.exists(output)) {
  stop("The committed Goal005 Task 3 smoke already exists.", call. = FALSE)
}
dir.create(file.path(output, "datasets"), recursive = TRUE)
dir.create(file.path(output, "fits"))
simulation <- simulate_goal005_task3_dataset(dataset_row, manifest)
saveRDS(
  simulation,
  file.path(output, "datasets", "simulation.rds"),
  version = 3
)
fit_dirs <- vapply(seq_len(nrow(fit_rows)), function(index) {
  row <- fit_rows[index, .goal005_task3_fit_fields]
  publish_goal003_task4_artifact(
    file.path(output, "fits"),
    row$fit_id,
    function(staging) {
      .goal005_task3_write_fit(row, simulation, staging, refresh = 100L)
    }
  )
}, character(1))
status <- .goal005_task3_read_fit_status(file.path(fit_dirs, "fit-status.csv"))
scores <- .goal003_task4_read_richness_scores(file.path(
  fit_dirs,
  "richness-score.csv"
))
pmf_ok <- vapply(fit_dirs, function(path) {
  pmf <- utils::read.csv(file.path(path, "richness-pmf.csv"))
  abs(sum(pmf$probability) - 1) <= 1e-10
}, logical(1))
compressed <- vapply(fit_dirs, function(path) {
  length(list.files(
    file.path(path, "sampler"),
    pattern = "[.]csv[.]gz$",
    recursive = TRUE,
    full.names = TRUE
  )) >= 4L
}, logical(1))
checks <- tibble::tibble(
  check = c(
    "both_levels_terminal_clean",
    "both_richness_predictions_available",
    "both_richness_pmfs_normalised",
    "both_raw_sampler_outputs_compressed",
    "fitted_training_data_excludes_truth"
  ),
  passed = c(
    nrow(status) == 2L && all(status$terminal_clean),
    nrow(scores) == 2L && all(scores$prediction_available),
    all(pmf_ok),
    all(compressed),
    !any(c("truth", "member", "true_richness", "alpha_fixed") %in%
      names(simulation$training_data))
  )
)
.goal003_task4_write_csv(checks, file.path(output, "smoke-checks.csv"))
smoke_status <- if (all(checks$passed)) "SMOKE_PASS" else "SMOKE_STOP"
writeLines(
  c(
    paste0("status=", smoke_status),
    paste0("git_commit=", git_commit),
    paste0("dataset_id=", dataset_row$dataset_id),
    paste0("fit_ids=", paste(fit_rows$fit_id, collapse = ",")),
    "empirical_outcomes_used=false"
  ),
  file.path(output, "completion-status.txt")
)
if (!identical(smoke_status, "SMOKE_PASS")) {
  stop("Goal005 Task 3 smoke failed.", call. = FALSE)
}
cat("Goal005 Task 3 smoke: PASS\n")
print(checks)
