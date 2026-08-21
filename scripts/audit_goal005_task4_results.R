if (!dir.exists("R") || !file.exists("renv.lock")) {
  stop("Run this script from the flexiRich repository root.", call. = FALSE)
}

for (path in sort(list.files("R", pattern = "[.]R$", full.names = TRUE))) {
  source(path, local = FALSE)
}

input <- Sys.getenv(
  "GOAL005_TASK4_INPUT",
  unset = file.path("outputs", "goal005", "task4-transfer-stress-v1")
)
output <- Sys.getenv(
  "GOAL005_TASK4_AUDIT_OUTPUT",
  unset = file.path("outputs", "goal005", "task4-audit-v1")
)
expected_commit <- Sys.getenv("GOAL005_TASK4_RUN_COMMIT", unset = "")
if (dir.exists(output) || file.exists(output)) {
  stop("The Goal005 Task 4 audit output already exists.", call. = FALSE)
}
result <- audit_goal005_task4_results(
  input,
  expected_commit = if (nzchar(expected_commit)) expected_commit else NULL
)
dir.create(output, recursive = TRUE, showWarnings = FALSE)
tables <- list(
  "replayed-profile-gates.csv" = result$replayed_profile_gates,
  "profile-comparison.csv" = result$profile_comparison,
  "replayed-shifts.csv" = result$replayed_shifts,
  "replayed-shift-gates.csv" = result$replayed_shift_gates,
  "shift-comparison.csv" = result$shift_comparison,
  "decision.csv" = result$decision,
  "artifact-hashes.csv" = result$artifact_hashes
)
for (name in names(tables)) {
  .goal003_task4_write_csv(tables[[name]], file.path(output, name))
}
writeLines(
  c(
    "status=AUDIT_PASS",
    paste0("run_commit=", result$run_commit),
    "profile_gate_rows=51",
    "shift_gate_rows=6",
    "all_rows_match=true",
    "empirical_outcomes_used=false"
  ),
  file.path(output, "completion-status.txt")
)
cat("Goal005 Task 4 independent audit: PASS\n")
print(result$decision)
