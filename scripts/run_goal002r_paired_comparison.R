if (!dir.exists("R") || !dir.exists("stan")) {
  stop("Run this script from the flexiRich repository root.", call. = FALSE)
}

for (path in sort(list.files("R", pattern = "\\.R$", full.names = TRUE))) {
  source(path, local = FALSE)
}
source(file.path("scripts", "source_goal002r.R"))
source_goal002r(".")

result <- goal002r_run_paired_comparison()
print(result$evidence$case_results)
print(result$evidence$decision$criteria)
cat("\nGoal002R paired-comparison decision:",
    result$evidence$decision$decision, "\n")
cat("Outputs:", dirname(result$paths[[1L]]), "\n")
