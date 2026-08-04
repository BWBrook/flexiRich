project_root <- if (dir.exists("R")) "." else file.path("..", "..")
source(file.path(project_root, "scripts", "source_goal002r.R"))
source_goal002r(project_root)

status <- check_goal002_cmdstan(error = FALSE)
if (!isTRUE(status$matches)) {
  stop(
    "CmdStan ", status$required_version,
    " is required for the Goal002R smoke fit.",
    call. = FALSE
  )
}

data <- goal002r_toy_data()
fit <- goal002r_fit(
  data,
  seed = 220020902L,
  sampler = goal002r_default_sampler(
    iter_warmup = 200L,
    iter_sampling = 200L,
    adapt_delta = 0.95,
    chains = 2L,
    parallel_chains = 2L
  ),
  quadrature_order = 16L,
  output_dir = tempfile("goal002r-smoke-")
)
summary <- goal002r_summarise_fit(fit)
validate_goal002r_summary(summary)
cat("Goal002R smoke fit: PASS\n")
cat("posterior mean richness:", summary$richness$mean, "\n")
cat("output directory:", fit$output_dir, "\n")
