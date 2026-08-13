if (!dir.exists("R") || !file.exists("renv.lock")) {
  stop("Run this script from the flexiRich repository root.", call. = FALSE)
}

for (path in sort(list.files("R", pattern = "\\.R$", full.names = TRUE))) {
  source(path, local = FALSE)
}

manifest <- read_goal003_task4_manifests()
valid <- validate_goal003_task4_manifests(
  manifest$scenarios,
  manifest$datasets,
  manifest$fits,
  manifest$effort
)
if (!isTRUE(valid)) {
  stop("Goal003 Task 4 manifest validation did not return TRUE.", call. = FALSE)
}

cat("Goal003 Task 4 manifest: PASS\n")
cat("datasets=", nrow(manifest$datasets), "\n", sep = "")
cat("stan_fits=", nrow(manifest$fits), "\n", sep = "")
for (name in names(manifest$hashes)) {
  cat(name, "_sha256=", manifest$hashes[[name]], "\n", sep = "")
}
