if (!dir.exists("R") || !file.exists("renv.lock")) {
  stop("Run this script from the flexiRich repository root.", call. = FALSE)
}

for (path in sort(list.files("R", pattern = "[.]R$", full.names = TRUE))) {
  source(path, local = FALSE)
}

contract <- read_goal007_task1_contract(verify_external = TRUE)
checks <- c(
  candidates = nrow(contract$candidates) == 50L,
  encounter_classes = identical(
    as.integer(table(contract$candidates$encounter_class)[
      c("occasional", "routine")
    ]),
    c(6L, 44L)
  ),
  models = nrow(contract$models) == 3L,
  profiles = nrow(contract$profiles) == 6L,
  task2_datasets = nrow(contract$task2_datasets) == 60L,
  task2_fits = nrow(contract$task2_fits) == 180L,
  task3_datasets = nrow(contract$task3_datasets) == 48L,
  task3_windows = nrow(contract$task3_windows) == 12L,
  task3_f5_calibration_fits =
    nrow(contract$task3_branches$shared_F5$calibration_fits) == 96L,
  task3_f5_target_fits =
    nrow(contract$task3_branches$shared_F5$target_fits) == 288L,
  task3_f3_calibration_fits =
    nrow(contract$task3_branches$shared_F3$calibration_fits) == 96L,
  task3_f3_target_fits =
    nrow(contract$task3_branches$shared_F3$target_fits) == 288L,
  gates = nrow(contract$gates) == 54L,
  hashes = all(grepl("^[0-9a-f]{64}$", contract$hashes))
)
if (!all(checks)) {
  stop("Goal007 Task 1 contract check failed.", call. = FALSE)
}

cat("Goal007 Task 1 contract: PASS\n")
cat("camtrap_workflow_commit=", unique(
  contract$sources$observed_git_commit
), "\n", sep = "")
cat("task2_datasets=", nrow(contract$task2_datasets), "\n", sep = "")
cat("task2_fits=", nrow(contract$task2_fits), "\n", sep = "")
cat("task3_datasets=", nrow(contract$task3_datasets), "\n", sep = "")
cat("task3_branch_calibration_fits=96\n")
cat("task3_branch_target_fits=288\n")
cat("gates=", nrow(contract$gates), "\n", sep = "")
cat("empirical_outcomes_used=false\n")
print(checks)
