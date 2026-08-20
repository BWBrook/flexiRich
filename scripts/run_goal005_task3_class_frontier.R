if (!dir.exists("R") || !file.exists("renv.lock")) {
  stop("Run this script from the flexiRich repository root.", call. = FALSE)
}

for (path in sort(list.files("R", pattern = "[.]R$", full.names = TRUE))) {
  source(path, local = FALSE)
}

workers <- as.integer(Sys.getenv("GOAL005_TASK3_WORKERS", unset = "8"))
refresh <- as.integer(Sys.getenv("GOAL005_TASK3_REFRESH", unset = "100"))
output <- Sys.getenv(
  "GOAL005_TASK3_OUTPUT",
  unset = file.path("outputs", "goal005", "task3-class-frontier-v1")
)

tryCatch(
  run_goal005_task3_class_frontier(
    output_dir = output,
    max_workers = workers,
    refresh = refresh
  ),
  error = function(error) {
    root <- .goal003_project_root()
    path <- tryCatch(
      .goal005_task2_output_path(root, output),
      error = function(e) NULL
    )
    if (!is.null(path) && dir.exists(path)) {
      writeLines(
        c(
          "status=TASK3_EXECUTION_STOP",
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
