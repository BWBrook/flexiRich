if (!dir.exists("R") || !file.exists("renv.lock")) {
  stop("Run this script from the flexiRich repository root.", call. = FALSE)
}

arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) > 2L) {
  stop(
    "Usage: Rscript scripts/run_goal003_task4_screen.R [workers] [refresh]",
    call. = FALSE
  )
}
workers <- if (length(arguments) >= 1L) as.integer(arguments[[1L]]) else 8L
refresh <- if (length(arguments) >= 2L) as.integer(arguments[[2L]]) else 100L
if (anyNA(c(workers, refresh))) {
  stop("workers and refresh must be whole numbers.", call. = FALSE)
}

for (path in sort(list.files("R", pattern = "\\.R$", full.names = TRUE))) {
  source(path, local = FALSE)
}

result <- run_goal003_task4_screen(
  output_dir = file.path("outputs", "goal003", "task4-screen-v1"),
  max_workers = workers,
  refresh = refresh
)
cat("Goal003 Task 4 screen: ", result$status, "\n", sep = "")
