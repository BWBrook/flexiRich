if (!dir.exists("R") || !dir.exists("stan")) {
  stop("Run this script from the flexiRich repository root.", call. = FALSE)
}

source(file.path("scripts", "source_goal002r.R"))
source_goal002r(".")

result <- goal002r_preflight_run()
output_dir <- goal002r_output_path(
  goal002r_preflight_contract()$output_component
)
paths <- goal002r_preflight_write(result, output_dir)
print(result$criteria)
cat("Decision:", result$decision, "\n")
cat("Evidence:", output_dir, "\n")
