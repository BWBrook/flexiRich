if (!dir.exists("R") || !file.exists("renv.lock")) {
  stop("Run this script from the flexiRich repository root.", call. = FALSE)
}
for (path in sort(list.files("R", pattern = "[.]R$", full.names = TRUE))) {
  source(path, local = FALSE)
}

workers <- as.integer(Sys.getenv("GOAL006_TASK2_WORKERS", unset = "6"))
refresh <- as.integer(Sys.getenv("GOAL006_TASK2_REFRESH", unset = "100"))
output <- Sys.getenv(
  "GOAL006_TASK2_OUTPUT",
  unset = file.path("outputs", "goal006", "task2-recovery-v1")
)
tryCatch(
  run_goal006_task2_recovery(output, workers, refresh),
  error = function(error) {
    root <- .goal003_project_root()
    path <- tryCatch(
      .goal006_task2_output_path(root, output),
      error = function(e) NULL
    )
    if (!is.null(path) && dir.exists(path)) {
      writeLines(
        c(
          "status=TASK2_EXECUTION_STOP",
          paste0("reason=", conditionMessage(error)),
          paste0("recorded_utc=", format(Sys.time(), tz = "UTC", usetz = TRUE)),
          "empirical_outcomes_used=false"
        ),
        file.path(path, "execution-stop.txt")
      )
    }
    stop(error)
  }
)
