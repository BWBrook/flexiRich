if (!dir.exists("R") || !file.exists("renv.lock")) {
  stop("Run this script from the flexiRich repository root.", call. = FALSE)
}
for (path in sort(list.files("R", pattern = "[.]R$", full.names = TRUE))) {
  source(path, local = FALSE)
}

arguments <- commandArgs(trailingOnly = TRUE)
output_dir <- if (length(arguments) >= 1L) arguments[[1L]] else
  file.path("outputs", "goal007", "task2-screen-v1")
max_workers <- if (length(arguments) >= 2L) as.integer(arguments[[2L]]) else 6L
refresh <- if (length(arguments) >= 3L) as.integer(arguments[[3L]]) else 100L

run_goal007_task2_screen(
  output_dir = output_dir,
  max_workers = max_workers,
  refresh = refresh
)
