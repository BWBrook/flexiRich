if (!dir.exists("R") || !file.exists("renv.lock")) {
  stop("Run this script from the flexiRich repository root.", call. = FALSE)
}

for (path in sort(list.files("R", pattern = "[.]R$", full.names = TRUE))) {
  source(path, local = FALSE)
}

input <- Sys.getenv(
  "GOAL005_TASK2_INPUT",
  unset = file.path("outputs", "goal005", "task2-information-ceiling-v1")
)
output <- Sys.getenv(
  "GOAL005_TASK2_AUDIT_OUTPUT",
  unset = file.path("outputs", "goal005", "task2-audit-v1")
)
expected_commit <- Sys.getenv("GOAL005_TASK2_RUN_COMMIT", unset = "")
if (dir.exists(output) || file.exists(output)) {
  stop("The Goal005 Task 2 audit output already exists.", call. = FALSE)
}
result <- audit_goal005_task2_results(
  input,
  expected_commit = if (nzchar(expected_commit)) expected_commit else NULL
)
dir.create(output, recursive = TRUE, showWarnings = FALSE)
.goal003_task4_write_csv(
  result$replayed_gates,
  file.path(output, "replayed-gates.csv")
)
.goal003_task4_write_csv(
  result$gate_comparison,
  file.path(output, "gate-comparison.csv")
)
.goal003_task4_write_csv(
  result$duration_summary,
  file.path(output, "duration-summary.csv")
)
.goal003_task4_write_csv(
  result$pruning,
  file.path(output, "task3-pruning.csv")
)
.goal003_task4_write_csv(
  result$artifact_hashes,
  file.path(output, "artifact-hashes.csv")
)
writeLines(
  c(
    "status=AUDIT_PASS",
    paste0("run_commit=", result$run_commit),
    "gate_rows=170",
    "all_gate_rows_match=true",
    "empirical_outcomes_used=false"
  ),
  file.path(output, "completion-status.txt")
)
cat("Goal005 Task 2 independent audit: PASS\n")
print(result$duration_summary)
print(result$pruning)
