.goal003_sampler_stop <- function(message) {
  stop(message, call. = FALSE)
}

.goal003_project_root <- function() {
  path <- normalizePath(getwd(), mustWork = TRUE)
  repeat {
    if (dir.exists(file.path(path, "R")) &&
        dir.exists(file.path(path, "stan")) &&
        file.exists(file.path(path, "renv.lock"))) {
      return(path)
    }
    parent <- dirname(path)
    if (identical(parent, path)) {
      break
    }
    path <- parent
  }
  .goal003_sampler_stop("Could not locate the flexiRich repository root.")
}

.goal003_compile_model <- function(
  stan_file,
  cache_id,
  executable_stem,
  output_namespace = "goal003",
  force_recompile = FALSE
) {
  valid_text <- function(x) {
    is.character(x) && length(x) == 1L && !is.na(x) && nzchar(x)
  }
  if (!valid_text(stan_file) ||
      !valid_text(cache_id) ||
      !valid_text(executable_stem) ||
      !valid_text(output_namespace) ||
      !grepl("^[a-z0-9][a-z0-9-]*$", output_namespace)) {
    .goal003_sampler_stop(
      paste0(
        "Stan file, cache ID, executable stem, and output namespace ",
        "must be valid strings."
      )
    )
  }
  if (!is.logical(force_recompile) ||
      length(force_recompile) != 1L ||
      is.na(force_recompile)) {
    .goal003_sampler_stop("force_recompile must be exactly TRUE or FALSE.")
  }
  check_goal002_cmdstan()
  root <- .goal003_project_root()
  source <- normalizePath(
    file.path(root, stan_file),
    mustWork = FALSE
  )
  stan_root <- normalizePath(file.path(root, "stan"), mustWork = TRUE)
  if (!startsWith(source, paste0(stan_root, .Platform$file.sep)) ||
      !file.exists(source)) {
    .goal003_sampler_stop("The tracked Goal003 Stan source does not exist.")
  }
  source_hash <- digest::digest(
    file = source,
    algo = "sha256",
    serialize = FALSE
  )
  hash_prefix <- substr(source_hash, 1L, 16L)
  cache <- file.path(
    root,
    "outputs",
    output_namespace,
    cache_id,
    "cmdstan"
  )
  source_dir <- file.path(cache, "source", hash_prefix)
  bin_dir <- file.path(cache, "bin")
  dir.create(source_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(bin_dir, recursive = TRUE, showWarnings = FALSE)
  copied_source <- file.path(source_dir, basename(source))
  if (!file.exists(copied_source) &&
      !file.copy(source, copied_source, overwrite = FALSE)) {
    .goal003_sampler_stop("Could not cache the tracked Goal003 Stan source.")
  }
  copied_hash <- digest::digest(
    file = copied_source,
    algo = "sha256",
    serialize = FALSE
  )
  if (!identical(copied_hash, source_hash)) {
    .goal003_sampler_stop(
      "The cached Goal003 Stan source does not match its tracked source."
    )
  }
  executable <- file.path(
    bin_dir,
    paste0(executable_stem, "-", hash_prefix)
  )
  model <- cmdstanr::cmdstan_model(
    stan_file = copied_source,
    exe_file = executable,
    compile = FALSE
  )
  model$compile(
    quiet = TRUE,
    force_recompile = force_recompile || !file.exists(executable)
  )
  if (!file.exists(executable)) {
    .goal003_sampler_stop("CmdStan did not produce the Goal003 executable.")
  }
  model
}

classify_goal003_diagnostics <- function(
  parameter_summary,
  sampler_diagnostics,
  sampler_profile,
  thresholds
) {
  reasons <- character()
  metrics <- list(
    divergences = NA_integer_,
    treedepth_hits = NA_integer_,
    min_ebfmi = NA_real_,
    max_rhat = NA_real_,
    min_bulk_ess = NA_real_,
    min_tail_ess = NA_real_
  )
  required_thresholds <- c(
    "max_divergences", "max_treedepth_hits", "min_ebfmi",
    "max_rhat", "min_bulk_ess", "min_tail_ess"
  )
  thresholds_valid <- is.list(thresholds) &&
    identical(names(thresholds), required_thresholds) &&
    all(vapply(thresholds, function(x) {
      is.numeric(x) && length(x) == 1L && !is.na(x) && is.finite(x)
    }, logical(1)))
  profile_valid <- is.list(sampler_profile) &&
    is.numeric(sampler_profile$max_treedepth) &&
    length(sampler_profile$max_treedepth) == 1L &&
    !is.na(sampler_profile$max_treedepth) &&
    is.finite(sampler_profile$max_treedepth)
  if (!thresholds_valid || !profile_valid) {
    return(list(
      clean = FALSE,
      metrics = metrics,
      reasons = "invalid diagnostic contract"
    ))
  }

  required_summary <- c("rhat", "ess_bulk", "ess_tail")
  if (!is.data.frame(parameter_summary) ||
      nrow(parameter_summary) == 0L ||
      any(!required_summary %in% names(parameter_summary))) {
    reasons <- c(reasons, "invalid parameter-summary diagnostics")
  } else {
    values <- unlist(parameter_summary[required_summary], use.names = FALSE)
    if (!is.numeric(values) || anyNA(values) || any(!is.finite(values))) {
      reasons <- c(reasons, "non-finite parameter-summary diagnostics")
    } else {
      metrics$max_rhat <- max(parameter_summary$rhat)
      metrics$min_bulk_ess <- min(parameter_summary$ess_bulk)
      metrics$min_tail_ess <- min(parameter_summary$ess_tail)
      if (metrics$max_rhat > thresholds$max_rhat) {
        reasons <- c(reasons, "R-hat exceeds 1.01")
      }
      if (metrics$min_bulk_ess < thresholds$min_bulk_ess) {
        reasons <- c(reasons, "bulk ESS is below 400")
      }
      if (metrics$min_tail_ess < thresholds$min_tail_ess) {
        reasons <- c(reasons, "tail ESS is below 400")
      }
    }
  }

  required_sampler <- c(
    "divergent__", "treedepth__", "energy__", ".chain", ".iteration"
  )
  sampler <- if (is.data.frame(sampler_diagnostics)) {
    as.data.frame(sampler_diagnostics)
  } else {
    NULL
  }
  if (is.null(sampler) ||
      nrow(sampler) == 0L ||
      any(!required_sampler %in% names(sampler))) {
    reasons <- c(reasons, "invalid sampler diagnostics")
  } else {
    sampler <- sampler[required_sampler]
    values <- unlist(sampler, use.names = FALSE)
    if (!is.numeric(values) || anyNA(values) || any(!is.finite(values))) {
      reasons <- c(reasons, "non-finite sampler diagnostics")
    } else {
      metrics$divergences <- as.integer(sum(sampler$divergent__))
      metrics$treedepth_hits <- as.integer(sum(
        sampler$treedepth__ >= sampler_profile$max_treedepth
      ))
      chains <- sort(unique(as.integer(sampler$.chain)))
      ebfmi <- vapply(chains, function(chain) {
        rows <- sampler$.chain == chain
        energy <- sampler$energy__[rows][order(sampler$.iteration[rows])]
        denominator <- stats::var(energy)
        if (length(energy) < 2L ||
            !is.finite(denominator) ||
            denominator <= 0) {
          return(NA_real_)
        }
        mean(diff(energy)^2) / denominator
      }, numeric(1))
      if (anyNA(ebfmi) || any(!is.finite(ebfmi))) {
        reasons <- c(reasons, "undefined E-BFMI")
      } else {
        metrics$min_ebfmi <- min(ebfmi)
        if (metrics$min_ebfmi < thresholds$min_ebfmi) {
          reasons <- c(reasons, "E-BFMI is below 0.3")
        }
      }
      if (metrics$divergences > thresholds$max_divergences) {
        reasons <- c(reasons, "divergent transitions")
      }
      if (metrics$treedepth_hits > thresholds$max_treedepth_hits) {
        reasons <- c(reasons, "maximum-treedepth transitions")
      }
    }
  }
  list(
    clean = length(reasons) == 0L,
    metrics = metrics,
    reasons = unique(reasons)
  )
}

.goal003_fit_diagnostics <- function(
  fit,
  sampler_profile,
  monitored_variables,
  thresholds
) {
  parameter_summary <- tryCatch(
    fit$summary(variables = monitored_variables),
    error = function(e) NULL
  )
  sampler <- tryCatch(
    fit$sampler_diagnostics(inc_warmup = FALSE, format = "df"),
    error = function(e) NULL
  )
  classify_goal003_diagnostics(
    parameter_summary,
    sampler,
    sampler_profile,
    thresholds
  )
}

.goal003_model_attempt <- function(
  model,
  stan_data,
  sampler_profile,
  diagnostic_thresholds,
  monitored_variables,
  seed,
  output_dir,
  attempt_id,
  refresh
) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  started <- proc.time()[["elapsed"]]
  fit <- tryCatch(
    suppressMessages(model$sample(
      data = stan_data,
      seed = seed,
      chains = sampler_profile$chains,
      parallel_chains = sampler_profile$parallel_chains,
      iter_warmup = sampler_profile$iter_warmup,
      iter_sampling = sampler_profile$iter_sampling,
      adapt_delta = sampler_profile$adapt_delta,
      max_treedepth = sampler_profile$max_treedepth,
      refresh = refresh,
      sig_figs = 18L,
      diagnostics = c("divergences", "treedepth"),
      show_messages = FALSE,
      output_dir = output_dir,
      output_basename = attempt_id
    )),
    error = function(e) e
  )
  elapsed <- proc.time()[["elapsed"]] - started
  if (inherits(fit, "error")) {
    return(list(
      attempt_id = attempt_id,
      profile = sampler_profile,
      elapsed_seconds = as.numeric(elapsed),
      diagnostics = list(
        clean = FALSE,
        metrics = NULL,
        reasons = conditionMessage(fit)
      ),
      fit = NULL
    ))
  }
  list(
    attempt_id = attempt_id,
    profile = sampler_profile,
    elapsed_seconds = as.numeric(elapsed),
    diagnostics = .goal003_fit_diagnostics(
      fit,
      sampler_profile,
      monitored_variables,
      diagnostic_thresholds
    ),
    fit = fit
  )
}

.goal003_terminal_status <- function(primary, rescue = NULL) {
  if (isTRUE(primary$diagnostics$clean)) {
    return("primary_clean")
  }
  if (!is.null(rescue) && isTRUE(rescue$diagnostics$clean)) {
    return("rescue_clean")
  }
  "final_nonclean"
}

.goal003_prepare_output_directory <- function(
  output_dir,
  output_namespace = "goal003"
) {
  if (!is.character(output_dir) ||
      length(output_dir) != 1L ||
      is.na(output_dir) ||
      !nzchar(output_dir)) {
    .goal003_sampler_stop("output_dir must be one non-empty path.")
  }
  if (!is.character(output_namespace) ||
      length(output_namespace) != 1L ||
      is.na(output_namespace) ||
      !grepl("^[a-z0-9][a-z0-9-]*$", output_namespace)) {
    .goal003_sampler_stop("output_namespace must be one safe directory name.")
  }
  root <- .goal003_project_root()
  boundary <- normalizePath(
    file.path(root, "outputs", output_namespace),
    mustWork = FALSE
  )
  absolute_output <- normalizePath(
    if (startsWith(output_dir, "/")) output_dir else file.path(root, output_dir),
    mustWork = FALSE
  )
  if (!startsWith(absolute_output, paste0(boundary, .Platform$file.sep))) {
    .goal003_sampler_stop(
      paste0(
        "output_dir must be a new directory beneath outputs/",
        output_namespace,
        "."
      )
    )
  }
  if (file.exists(absolute_output) || dir.exists(absolute_output)) {
    .goal003_sampler_stop("output_dir must not already exist.")
  }
  if (!dir.create(absolute_output, recursive = TRUE, showWarnings = FALSE)) {
    .goal003_sampler_stop("Could not create the model output directory.")
  }
  normalizePath(absolute_output, mustWork = TRUE)
}
