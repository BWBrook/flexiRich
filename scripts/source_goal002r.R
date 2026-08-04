source_goal002r <- function(project_root = ".") {
  project_root <- normalizePath(project_root, mustWork = TRUE)
  required <- c("infer_config.R", "infer_data.R", "infer_math.R")
  for (file in required) {
    source(file.path(project_root, "R", file), local = .GlobalEnv)
  }
  nested <- sort(list.files(
    file.path(project_root, "R", "goal002r"),
    pattern = "\\.R$",
    full.names = TRUE
  ))
  if (length(nested) == 0L) {
    stop("No Goal002R source files were found.", call. = FALSE)
  }
  for (file in nested) {
    source(file, local = .GlobalEnv)
  }
  invisible(c(required, nested))
}

if (identical(environment(), globalenv()) &&
    identical(Sys.getenv("FLEXIRICH_SOURCE_GOAL002R"), "1")) {
  source_goal002r()
}
