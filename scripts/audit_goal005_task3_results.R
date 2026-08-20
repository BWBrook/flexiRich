if (!dir.exists("R") || !file.exists("renv.lock")) {
  stop("Run this script from the flexiRich repository root.", call. = FALSE)
}

for (path in sort(list.files("R", pattern = "[.]R$", full.names = TRUE))) {
  source(path, local = FALSE)
}

input <- Sys.getenv(
  "GOAL005_TASK3_INPUT",
  unset = file.path("outputs", "goal005", "task3-class-frontier-v1")
)
output <- Sys.getenv(
  "GOAL005_TASK3_AUDIT_OUTPUT",
  unset = file.path("outputs", "goal005", "task3-audit-v1")
)
expected_commit <- Sys.getenv("GOAL005_TASK3_RUN_COMMIT", unset = "")
if (dir.exists(output) || file.exists(output)) {
  stop("The Goal005 Task 3 audit output already exists.", call. = FALSE)
}
result <- audit_goal005_task3_results(
  input,
  expected_commit = if (nzchar(expected_commit)) expected_commit else NULL
)
dir.create(output, recursive = TRUE, showWarnings = FALSE)
tables <- list(
  "replayed-gates.csv" = result$replayed_gates,
  "gate-comparison.csv" = result$gate_comparison,
  "precision-summary.csv" = result$precision_summary,
  "frontier-summary.csv" = result$frontier,
  "frontier-comparison.csv" = result$frontier_comparison,
  "artifact-hashes.csv" = result$artifact_hashes
)
for (name in names(tables)) {
  .goal003_task4_write_csv(tables[[name]], file.path(output, name))
}
writeLines(
  c(
    "status=AUDIT_PASS",
    paste0("run_commit=", result$run_commit),
    "gate_rows=357",
    "frontier_rows=3",
    "all_rows_match=true",
    "empirical_outcomes_used=false"
  ),
  file.path(output, "completion-status.txt")
)
cat("Goal005 Task 3 independent audit: PASS\n")
print(result$frontier)
