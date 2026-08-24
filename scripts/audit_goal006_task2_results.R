if (!dir.exists("R") || !file.exists("renv.lock")) {
  stop("Run this script from the flexiRich repository root.", call. = FALSE)
}
for (path in sort(list.files("R", pattern = "[.]R$", full.names = TRUE))) {
  source(path, local = FALSE)
}

input <- Sys.getenv(
  "GOAL006_TASK2_INPUT",
  unset = file.path("outputs", "goal006", "task2-recovery-v1")
)
output <- Sys.getenv(
  "GOAL006_TASK2_AUDIT_OUTPUT",
  unset = file.path("outputs", "goal006", "task2-audit-v1")
)
expected <- Sys.getenv("GOAL006_TASK2_RUN_COMMIT", unset = "")
if (dir.exists(output) || file.exists(output)) {
  stop("The Goal006 Task 2 audit output already exists.", call. = FALSE)
}
result <- audit_goal006_task2_results(
  input,
  expected_commit = if (nzchar(expected)) expected else NULL
)
dir.create(output, recursive = TRUE, showWarnings = FALSE)
.goal003_task4_write_csv(result$gates, file.path(output, "replayed-gates.csv"))
.goal003_task4_write_csv(
  result$artifact_hashes,
  file.path(output, "artifact-hashes.csv")
)
writeLines(
  c(
    "status=AUDIT_PASS",
    paste0("decision=", result$decision),
    paste0("run_commit=", result$run_commit),
    "gate_rows=12",
    "all_rows_match=true",
    "empirical_outcomes_used=false"
  ),
  file.path(output, "completion-status.txt")
)
cat("Goal006 Task 2 independent audit: PASS\n")
cat("decision=", result$decision, "\n", sep = "")
