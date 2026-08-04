.goal002r_zero_sum_basis <- function(J) {
  if (!is.numeric(J) || length(J) != 1L || is.na(J) ||
      J != trunc(J) || J < 2L) {
    .goal002r_stop("Goal002R fitting requires at least two cameras.")
  }
  J <- as.integer(J)
  H <- stats::contr.helmert(J)
  sweep(H, 2L, sqrt(colSums(H^2)), "/")
}

goal002r_stan_data <- function(
  data,
  prior_profile = goal002r_default_prior(),
  quadrature_order = goal002r_contract()$quadrature_default
) {
  .goal002r_validate_collapsed(data)
  prior_profile <- validate_goal002_profile(prior_profile, type = "prior")
  quadrature_order <- .goal002r_validate_quadrature_order(quadrature_order)
  rule <- goal002r_gauss_hermite_rule(quadrature_order)
  core <- data$stan_core
  if (core$D < 1L || core$J < 2L) {
    .goal002r_stop(
      "The first Stan prototype requires at least one detected candidate and two cameras."
    )
  }
  c(
    core[c(
      "D", "U", "J", "G", "G0", "species_index", "camera_index",
      "active_days", "n_trials", "n_detected", "zero_camera_index",
      "zero_active_days", "zero_n_trials"
    )],
    list(
      B = as.integer(core$J - 1L),
      Nq = as.integer(nrow(rule)),
      Q = .goal002r_zero_sum_basis(core$J),
      gh_nodes = as.numeric(rule$node),
      gh_log_weights = log(as.numeric(rule$weight)),
      omega_alpha = prior_profile$omega_alpha,
      omega_beta = prior_profile$omega_beta,
      mu_alpha_location = prior_profile$mu_alpha_location,
      mu_alpha_scale = prior_profile$mu_alpha_scale,
      sigma_alpha_scale = prior_profile$sigma_alpha_scale,
      sigma_camera_scale = prior_profile$sigma_camera_scale
    )
  )
}

goal002r_compile_model <- function(
  project_root = goal002r_project_root(),
  force_recompile = FALSE
) {
  if (!requireNamespace("cmdstanr", quietly = TRUE)) {
    .goal002r_stop("cmdstanr is required for Goal002R fitting.")
  }
  check_goal002_cmdstan()
  stan_file <- file.path(
    project_root,
    goal002r_contract()$stan_file
  )
  if (!file.exists(stan_file)) {
    .goal002r_stop("The collapsed Stan source file does not exist.")
  }
  source_hash <- digest::digest(
    file = stan_file,
    algo = "sha256",
    serialize = FALSE
  )
  executable <- file.path(
    goal002r_output_path("cmdstan", project_root),
    paste0("flexirich_g_collapsed-", substr(source_hash, 1L, 16L))
  )
  model <- cmdstanr::cmdstan_model(
    stan_file = stan_file,
    exe_file = executable,
    compile = FALSE
  )
  model$compile(
    quiet = TRUE,
    force_recompile = isTRUE(force_recompile) || !file.exists(executable)
  )
  model
}

goal002r_fit <- function(
  data,
  seed = 220020001L,
  prior_profile = goal002r_default_prior(),
  sampler = goal002r_default_sampler(),
  quadrature_order = goal002r_contract()$quadrature_default,
  project_root = goal002r_project_root(),
  output_dir = NULL,
  force_recompile = FALSE,
  health_thresholds = goal002r_default_health_thresholds()
) {
  .goal002r_validate_collapsed(data)
  seed <- .goal002r_scalar(seed, "seed", lower = 1)
  if (seed != trunc(seed) || seed > .Machine$integer.max) {
    .goal002r_stop("seed must be one representable positive integer.")
  }
  seed <- as.integer(seed)
  prior_profile <- validate_goal002_profile(prior_profile, type = "prior")
  if (!is.list(sampler)) {
    .goal002r_stop("sampler must be a Goal002R sampler list.")
  }
  if (!is.list(health_thresholds)) {
    .goal002r_stop("health_thresholds must be a Goal002R threshold list.")
  }
  health_thresholds <- goal002r_default_health_thresholds(
    max_divergences = health_thresholds$max_divergences,
    max_treedepth_hits = health_thresholds$max_treedepth_hits,
    min_ebfmi = health_thresholds$min_ebfmi,
    max_rhat = health_thresholds$max_rhat,
    min_bulk_ess = health_thresholds$min_bulk_ess,
    min_tail_ess = health_thresholds$min_tail_ess
  )
  stan_data <- goal002r_stan_data(
    data,
    prior_profile = prior_profile,
    quadrature_order = quadrature_order
  )
  model <- goal002r_compile_model(
    project_root = project_root,
    force_recompile = force_recompile
  )
  if (is.null(output_dir)) {
    output_dir <- goal002r_output_path(
      file.path("fits", paste0("seed-", seed)),
      project_root
    )
  } else {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
    output_dir <- normalizePath(output_dir, mustWork = TRUE)
  }
  csv_pattern <- file.path(output_dir, "fit-*.csv")
  if (length(Sys.glob(csv_pattern)) > 0L) {
    .goal002r_stop("The requested fit output directory is not empty.")
  }
  fit <- model$sample(
    data = stan_data,
    seed = seed,
    chains = sampler$chains,
    parallel_chains = sampler$parallel_chains,
    iter_warmup = sampler$iter_warmup,
    iter_sampling = sampler$iter_sampling,
    adapt_delta = sampler$adapt_delta,
    max_treedepth = sampler$max_treedepth,
    refresh = sampler$refresh,
    save_warmup = FALSE,
    sig_figs = 18L,
    show_messages = FALSE,
    diagnostics = NULL,
    output_dir = output_dir,
    output_basename = "fit"
  )
  draws <- posterior::as_draws_matrix(fit$draws())
  result <- list(
    backend = fit,
    draws = draws,
    data = data,
    prior_profile = prior_profile,
    sampler = sampler,
    health_thresholds = health_thresholds,
    quadrature_order = as.integer(quadrature_order),
    seed = seed,
    model_source_hash = digest::digest(
      file = file.path(project_root, goal002r_contract()$stan_file),
      algo = "sha256",
      serialize = FALSE
    ),
    output_dir = output_dir
  )
  class(result) <- c("flexirich_g_collapsed_fit", "list")
  result$health <- goal002r_sampler_health(
    result,
    thresholds = health_thresholds
  )
  if (!isTRUE(result$health$passed)) {
    .goal002r_stop(
      paste0("CmdStan sampler-health gate failed: ", result$health$message)
    )
  }
  result
}
