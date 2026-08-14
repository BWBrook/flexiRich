if (!dir.exists("R") || !file.exists("renv.lock")) {
  stop("Run this script from the flexiRich repository root.", call. = FALSE)
}

for (path in sort(list.files("R", pattern = "[.]R$", full.names = TRUE))) {
  source(path, local = FALSE)
}

output_dir <- file.path("outputs", "goal004", "task2-prior-only-v1")
if (dir.exists(output_dir) || file.exists(output_dir)) {
  stop("The Goal004 Task 2 output directory already exists.", call. = FALSE)
}

git_commit <- system2("git", c("rev-parse", "HEAD"), stdout = TRUE)
git_status <- system2("git", c("status", "--porcelain"), stdout = TRUE)
if (length(git_commit) != 1L || !grepl("^[0-9a-f]{40}$", git_commit)) {
  stop("Could not identify the committed Goal004 source.", call. = FALSE)
}
if (length(git_status) != 0L) {
  stop("Goal004 Task 2 requires a clean committed worktree.", call. = FALSE)
}

n_draws <- 50000L
seed <- 40042L
input_paths <- c(
  prior_profiles = file.path("config", "goal004_task2_priors.csv"),
  candidate_pool = file.path("config", "goal003_candidate_pool.csv"),
  effort_template = file.path("config", "goal003_task4_effort_template.csv"),
  task2_design = file.path(
    "docs",
    "goals",
    "004-pool-stable-membership",
    "Task2PriorElicitation.md"
  )
)
input_hashes <- vapply(input_paths, function(path) {
  digest::digest(file = path, algo = "sha256", serialize = FALSE)
}, character(1))

result <- goal004_task2_prior_only(
  n_draws = n_draws,
  seed = seed
)
tables <- result[vapply(result, inherits, logical(1), what = "data.frame")]
if (length(tables) != 13L || !all(result$invariants$passed)) {
  stop("The Goal004 Task 2 result contract is incomplete.", call. = FALSE)
}

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
for (name in names(tables)) {
  utils::write.csv(
    tables[[name]],
    file.path(output_dir, paste0(name, ".csv")),
    row.names = FALSE,
    na = ""
  )
}
metadata <- tibble::tibble(
  key = c(
    "status",
    "git_commit",
    "simulation_seed",
    "simulation_draws",
    "empirical_outcomes_used",
    "r_version",
    paste0("sha256_", names(input_hashes))
  ),
  value = c(
    "PRIOR_ONLY_COMPLETE",
    git_commit,
    seed,
    n_draws,
    "false",
    R.version.string,
    unname(input_hashes)
  )
)
utils::write.csv(
  metadata,
  file.path(output_dir, "metadata.csv"),
  row.names = FALSE
)

expected_files <- c(paste0(names(tables), ".csv"), "metadata.csv")
if (!setequal(list.files(output_dir), expected_files)) {
  stop("The Goal004 Task 2 output file set is incomplete.", call. = FALSE)
}
for (name in names(tables)) {
  readback <- utils::read.csv(
    file.path(output_dir, paste0(name, ".csv")),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  if (nrow(readback) != nrow(tables[[name]]) ||
      !identical(names(readback), names(tables[[name]]))) {
    stop(paste0("Goal004 Task 2 readback failed for ", name, "."), call. = FALSE)
  }
}
output_hashes <- vapply(expected_files, function(name) {
  digest::digest(
    file = file.path(output_dir, name),
    algo = "sha256",
    serialize = FALSE
  )
}, character(1))
utils::write.csv(
  tibble::tibble(file = names(output_hashes), sha256 = unname(output_hashes)),
  file.path(output_dir, "output_hashes.csv"),
  row.names = FALSE
)

completion <- c(
  "Goal004 Task 2 prior-only calibration",
  "status=PRIOR_ONLY_COMPLETE",
  paste0("git_commit=", git_commit),
  paste0("simulation_seed=", seed),
  paste0("simulation_draws=", n_draws),
  "empirical_outcomes_used=false"
)
writeLines(completion, file.path(output_dir, "completion.txt"))
final_files <- c(expected_files, "output_hashes.csv", "completion.txt")
if (!setequal(list.files(output_dir), final_files)) {
  stop("The final Goal004 Task 2 output file set is incomplete.", call. = FALSE)
}
message(paste(completion[-1L], collapse = "\n"))
