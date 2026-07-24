project_root <- if (dir.exists("R")) "." else file.path("..", "..")

for (path in sort(list.files(
  file.path(project_root, "R"),
  pattern = "\\.R$",
  full.names = TRUE
))) {
  source(path, local = FALSE)
}

rm(project_root)
