.goal002r_stop <- function(message) {
  stop(message, call. = FALSE)
}

goal002r_contract <- function() {
  list(
    occasion_days = 7L,
    quadrature_orders = c(16L, 32L, 64L, 128L),
    quadrature_default = 128L,
    quadrature_reference = 256L,
    pmf_tolerance = 1e-12,
    log_integral_tolerance = 1e-8,
    stan_file = file.path("stan", "flexirich_g_collapsed.stan"),
    output_root = file.path("outputs", "goal002r")
  )
}

.goal002r_validate_quadrature_order <- function(order) {
  order <- .goal002r_scalar(order, "quadrature_order", lower = 1)
  if (order != trunc(order)) {
    .goal002r_stop("quadrature_order must be a whole number.")
  }
  order <- as.integer(order)
  allowed <- c(
    goal002r_contract()$quadrature_orders,
    goal002r_contract()$quadrature_reference
  )
  if (!order %in% allowed) {
    .goal002r_stop(
      paste0(
        "quadrature_order must be one of: ",
        paste(allowed, collapse = ", "), "."
      )
    )
  }
  order
}

goal002r_project_root <- function(path = getwd()) {
  path <- normalizePath(path, mustWork = TRUE)
  repeat {
    if (file.exists(file.path(path, "R", "infer_data.R")) &&
        file.exists(file.path(path, "stan"))) {
      return(path)
    }
    parent <- dirname(path)
    if (identical(parent, path)) {
      .goal002r_stop("Could not locate the flexiRich project root.")
    }
    path <- parent
  }
}

goal002r_output_path <- function(
  component = "",
  project_root = goal002r_project_root()
) {
  if (!is.character(component) || length(component) != 1L ||
      is.na(component) || grepl("(^|/|\\\\)\\.\\.($|/|\\\\)", component)) {
    .goal002r_stop("component must be one safe relative path.")
  }
  root <- file.path(project_root, goal002r_contract()$output_root)
  path <- if (nzchar(component)) file.path(root, component) else root
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  normalizePath(path, mustWork = TRUE)
}

goal002r_default_prior <- function() {
  if (!exists("goal002_prior_profiles", mode = "function")) {
    .goal002r_stop("Goal002 prior profiles are not loaded.")
  }
  goal002_prior_profiles()$primary
}

goal002r_default_sampler <- function(
  iter_warmup = 500L,
  iter_sampling = 500L,
  chains = 2L,
  parallel_chains = 2L,
  adapt_delta = 0.9,
  max_treedepth = 12L,
  refresh = 0L
) {
  values <- list(
    iter_warmup = iter_warmup,
    iter_sampling = iter_sampling,
    chains = chains,
    parallel_chains = parallel_chains,
    adapt_delta = adapt_delta,
    max_treedepth = max_treedepth,
    refresh = refresh
  )
  integer_fields <- c(
    "iter_warmup", "iter_sampling", "chains", "parallel_chains",
    "max_treedepth", "refresh"
  )
  for (field in integer_fields) {
    value <- values[[field]]
    if (!is.numeric(value) || length(value) != 1L || is.na(value) ||
        !is.finite(value) || value != trunc(value) || value < 0) {
      .goal002r_stop(paste0(field, " must be one non-negative integer."))
    }
    values[[field]] <- as.integer(value)
  }
  if (values$chains < 1L || values$parallel_chains < 1L ||
      values$parallel_chains > values$chains ||
      values$iter_sampling < 1L || values$iter_warmup < 1L ||
      !is.numeric(adapt_delta) || length(adapt_delta) != 1L ||
      !is.finite(adapt_delta) || adapt_delta <= 0 || adapt_delta >= 1) {
    .goal002r_stop("Invalid Goal002R sampler settings.")
  }
  values$adapt_delta <- as.numeric(adapt_delta)
  values
}

goal002r_default_health_thresholds <- function(
  max_divergences = 0L,
  max_treedepth_hits = 0L,
  min_ebfmi = 0.3,
  max_rhat = 1.05,
  min_bulk_ess = 20,
  min_tail_ess = 20
) {
  integer_fields <- c("max_divergences", "max_treedepth_hits")
  values <- list(
    max_divergences = max_divergences,
    max_treedepth_hits = max_treedepth_hits,
    min_ebfmi = min_ebfmi,
    max_rhat = max_rhat,
    min_bulk_ess = min_bulk_ess,
    min_tail_ess = min_tail_ess
  )
  for (field in integer_fields) {
    value <- values[[field]]
    if (!is.numeric(value) || length(value) != 1L || is.na(value) ||
        !is.finite(value) || value != trunc(value) || value < 0) {
      .goal002r_stop(paste0(field, " must be one non-negative integer."))
    }
    values[[field]] <- as.integer(value)
  }
  if (!is.numeric(values$min_ebfmi) || length(values$min_ebfmi) != 1L ||
      !is.finite(values$min_ebfmi) || values$min_ebfmi <= 0 ||
      !is.numeric(values$max_rhat) || length(values$max_rhat) != 1L ||
      !is.finite(values$max_rhat) || values$max_rhat < 1 ||
      !is.numeric(values$min_bulk_ess) || length(values$min_bulk_ess) != 1L ||
      !is.finite(values$min_bulk_ess) || values$min_bulk_ess <= 0 ||
      !is.numeric(values$min_tail_ess) || length(values$min_tail_ess) != 1L ||
      !is.finite(values$min_tail_ess) || values$min_tail_ess <= 0) {
    .goal002r_stop("Invalid Goal002R sampler-health thresholds.")
  }
  values$min_ebfmi <- as.numeric(values$min_ebfmi)
  values$max_rhat <- as.numeric(values$max_rhat)
  values$min_bulk_ess <- as.numeric(values$min_bulk_ess)
  values$min_tail_ess <- as.numeric(values$min_tail_ess)
  values
}
