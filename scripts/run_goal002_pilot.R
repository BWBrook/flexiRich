file_argument <- grep(
  "^--file=",
  commandArgs(trailingOnly = FALSE),
  value = TRUE
)
if (length(file_argument) != 1L) {
  stop("Could not resolve the pilot script path.", call. = FALSE)
}
script_path <- normalizePath(
  sub("^--file=", "", file_argument),
  mustWork = TRUE
)
project_root <- normalizePath(
  file.path(dirname(script_path), ".."),
  mustWork = TRUE
)

for (path in sort(list.files(
  file.path(project_root, "R"),
  pattern = "\\.R$",
  full.names = TRUE
))) {
  source(path, local = FALSE)
}

phase <- goal002_parse_pilot_args(commandArgs(trailingOnly = TRUE))
status <- dispatch_goal002_pilot(
  phase = phase,
  project_root = project_root
)

cat(
  "Goal 002 ",
  phase,
  " dispatcher: ",
  sum(status$action == "completed"),
  " completed, ",
  sum(status$action == "skipped"),
  " skipped.\n",
  sep = ""
)
