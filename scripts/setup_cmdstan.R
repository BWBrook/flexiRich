args <- commandArgs(trailingOnly = TRUE)
install_requested <- identical(args, "--install")

if (!requireNamespace("cmdstanr", quietly = TRUE)) {
  stop(
    "Restore the project renv before checking CmdStan: Rscript bootstrap_env.R",
    call. = FALSE
  )
}

required <- "2.38.0"
current <- tryCatch(
  as.character(cmdstanr::cmdstan_version()),
  error = function(e) NA_character_
)

if (!identical(current, required) && install_requested) {
  cmdstanr::install_cmdstan(version = required, cores = 4L)
  current <- as.character(cmdstanr::cmdstan_version())
}

if (!identical(current, required)) {
  stop(
    "CmdStan ", required,
    " is required. Install explicitly with: ",
    "Rscript scripts/setup_cmdstan.R --install",
    call. = FALSE
  )
}

cat("CmdStan contract: PASS (", current, ")\n", sep = "")
