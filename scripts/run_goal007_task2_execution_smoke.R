if (!dir.exists("R") || !file.exists("renv.lock")) {
  stop("Run this script from the flexiRich repository root.", call. = FALSE)
}
for (path in sort(list.files("R", pattern = "[.]R$", full.names = TRUE))) {
  source(path, local = FALSE)
}

root <- .goal003_project_root()
git_commit <- .goal003_task4_git_state(root)
contract <- read_goal007_task1_contract(verify_external = FALSE)
dataset_id <- contract$task2_datasets$dataset_id[[1L]]
fits <- contract$task2_fits |>
  dplyr::filter(.data$dataset_id == .env$dataset_id) |>
  dplyr::arrange(model_code)
output <- Sys.getenv(
  "GOAL007_TASK2_SMOKE_OUTPUT",
  unset = file.path(
    "outputs", "goal007", "task2-execution-smoke-v1", git_commit
  )
)
output <- .goal007_task2_output_path(root, output)
if (dir.exists(output) || file.exists(output)) {
  stop("The Goal007 Task 2 execution smoke output already exists.", call. = FALSE)
}
dir.create(file.path(output, "fits"), recursive = TRUE, showWarnings = FALSE)
compile_goal006_calibration_model()
compile_goal007_calibration_model()
for (index in seq_len(nrow(fits))) {
  row <- fits[index, ]
  publish_goal003_task4_artifact(
    file.path(output, "fits"),
    row$fit_id,
    function(staging) {
      .goal007_task2_write_fit(row, contract, staging, refresh = 0L)
    }
  )
  cat("goal007_task2_smoke_fit_complete=", row$fit_id, "\n", sep = "")
}
directories <- file.path(output, "fits", fits$fit_id)
status <- .goal007_task2_read_rows(file.path(directories, "fit-status.csv"))
recovery <- .goal007_task2_read_rows(file.path(directories, "recovery.csv"))
passed <- nrow(status) == 3L && nrow(recovery) == 6L &&
  setequal(status$fit_id, fits$fit_id) &&
  all(table(recovery$fit_id) == 2L) &&
  setequal(status$model_id, c("independent", "shared_F5", "shared_F3"))
run_status <- if (passed) "SMOKE_PASS" else "SMOKE_STOP"
writeLines(
  c(
    paste0("status=", run_status),
    paste0("git_commit=", git_commit),
    paste0("dataset_id=", dataset_id),
    "fits=3",
    "recovery_rows=6",
    "empirical_outcomes_used=false"
  ),
  file.path(output, "completion-status.txt")
)
cat("Goal007 Task 2 execution smoke: ", run_status, "\n", sep = "")
cat("git_commit=", git_commit, "\n", sep = "")
cat("empirical_outcomes_used=false\n")
if (!passed) {
  quit(status = 1L)
}
