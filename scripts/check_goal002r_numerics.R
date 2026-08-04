project_root <- if (dir.exists("R")) "." else file.path("..", "..")
source(file.path(project_root, "scripts", "source_goal002r.R"))
source_goal002r(project_root)

data <- goal002r_toy_data()
camera_effect <- stats::setNames(c(-0.2, 0.2), data$camera_ids)
certificate <- goal002r_certify_quadrature(
  data$zero_history,
  mu_alpha = log(0.001),
  sigma_alpha = 2,
  camera_effect = camera_effect
)
if (is.na(certificate$selected_order)) {
  print(certificate$candidates)
  stop("No candidate quadrature order passed the numerical certificate.", call. = FALSE)
}
print(certificate$candidates)
cat("selected order:", certificate$selected_order, "\n")
cat("Goal002R numerical certificate: PASS\n")
