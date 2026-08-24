if (!dir.exists("R") || !file.exists("renv.lock")) {
  stop("Run this script from the flexiRich repository root.", call. = FALSE)
}

for (path in sort(list.files("R", pattern = "[.]R$", full.names = TRUE))) {
  source(path, local = FALSE)
}

contract <- read_goal006_task1_contract(verify_external = TRUE)
checks <- c(
  source_receipts = nrow(contract$sources) == 6L,
  candidates = nrow(contract$candidates) == 50L,
  effort = nrow(contract$effort) == 9L * 153L,
  folds = nrow(contract$folds) == 90L,
  forecasts = length(unique(contract$folds$forecast_id)) == 18L,
  synthetic_datasets = nrow(contract$synthetic) == 30L,
  calibration_fits = nrow(contract$calibration_fits) == 17L,
  target_fits = nrow(contract$target_fits) == 234L,
  decision_gates = nrow(contract$gates) == 50L
)
if (!all(checks)) {
  stop("Goal006 Task 1 contract check failed.", call. = FALSE)
}

cat("Goal006 Task 1 contract: PASS\n")
cat("camtrap_workflow_commit=", unique(
  contract$sources$observed_git_commit
), "\n", sep = "")
cat("fold_manifest_sha256=", digest::digest(
  file = file.path("config", "goal006_validation_folds.csv"),
  algo = "sha256",
  serialize = FALSE
), "\n", sep = "")
cat("datasets=", nrow(contract$synthetic), "\n", sep = "")
cat("calibration_fits=", nrow(contract$calibration_fits), "\n", sep = "")
cat("target_fits=", nrow(contract$target_fits), "\n", sep = "")
cat("gates=", nrow(contract$gates), "\n", sep = "")
print(checks)
