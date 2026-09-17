if (!dir.exists("R") || !file.exists("renv.lock")) {
  stop("Run this script from the flexiRich repository root.", call. = FALSE)
}

source(file.path("R", "goal008_theory.R"), local = FALSE)

output <- Sys.getenv(
  "GOAL008_THEORY_OUTPUT",
  unset = file.path("outputs", "goal008", "theory-v2")
)
run_goal008_theory(output)
cat("Goal008 cheap theory diagnostics: COMPLETE\n")
