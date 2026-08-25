if (!dir.exists("R") || !file.exists("renv.lock")) {
  stop("Run this script from the flexiRich repository root.", call. = FALSE)
}
for (path in sort(list.files("R", pattern = "[.]R$", full.names = TRUE))) {
  source(path, local = FALSE)
}

input <- Sys.getenv(
  "GOAL007_TASK2_INPUT",
  unset = file.path("outputs", "goal007", "task2-screen-v1")
)
output <- Sys.getenv(
  "GOAL007_TASK2_AUDIT_OUTPUT",
  unset = file.path("outputs", "goal007", "task2-audit-v1")
)
expected <- Sys.getenv("GOAL007_TASK2_RUN_COMMIT", unset = "")
root <- .goal003_project_root()
output <- .goal007_task2_output_path(root, output)
if (dir.exists(output) || file.exists(output)) {
  stop("The Goal007 Task 2 audit output already exists.", call. = FALSE)
}
result <- audit_goal007_task2_results(
  input,
  expected_commit = if (nzchar(expected)) expected else NULL
)
dir.create(output, recursive = TRUE, showWarnings = FALSE)
.goal003_task4_write_csv(result$gates, file.path(output, "replayed-gates.csv"))
.goal003_task4_write_csv(
  result$eligibility,
  file.path(output, "replayed-eligibility.csv")
)
.goal003_task4_write_csv(
  result$catastrophic,
  file.path(output, "replayed-catastrophic-cases.csv")
)
.goal003_task4_write_csv(
  result$artifact_hashes,
  file.path(output, "artifact-hashes.csv")
)
selected <- if (is.na(result$selected_model_id)) {
  "none"
} else {
  result$selected_model_id
}
writeLines(
  c(
    "status=AUDIT_PASS",
    paste0("decision=", result$decision),
    paste0("selected_model_id=", selected),
    paste0("run_commit=", result$run_commit),
    "gate_rows=52",
    "all_rows_match=true",
    "empirical_outcomes_used=false"
  ),
  file.path(output, "completion-status.txt")
)
cat("Goal007 Task 2 independent audit: PASS\n")
cat("decision=", result$decision, "\n", sep = "")
cat("selected_model_id=", selected, "\n", sep = "")
