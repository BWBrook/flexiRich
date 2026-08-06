if (!dir.exists("R") || !dir.exists("stan")) {
  stop("Run this script from the flexiRich repository root.", call. = FALSE)
}

for (path in sort(list.files("R", pattern = "\\.R$", full.names = TRUE))) {
  source(path, local = FALSE)
}
source(file.path("scripts", "source_goal002r.R"))
source_goal002r(".")

output_file <- file.path(
  goal002r_output_path("quadrature-revision"),
  "numerical-screen.csv"
)
result <- goal002r_screen_quadrature(output_file = output_file)

summary <- result$screen |>
  dplyr::group_by(method, order) |>
  dplyr::summarise(
    checks = dplyr::n(),
    passed = sum(passed),
    maximum_error = max(absolute_error),
    .groups = "drop"
  )
print(summary)
if (is.null(result$selected)) {
  stop("No prespecified quadrature candidate passed all checks.", call. = FALSE)
}
cat(
  "Selected:", result$selected$method,
  "order", result$selected$order, "\n",
  "Evidence:", output_file, "\n"
)
