.goal002_attempt_fields <- c(
  "attempt_id",
  "sampler_profile_id",
  "seed",
  "started_at_utc",
  "elapsed_seconds",
  "model_source_hash",
  "data_hash",
  "prior_profile",
  "R_version",
  "cmdstanr_version",
  "cmdstan_version",
  "compiler",
  "output_files",
  "diagnostics",
  "clean"
)

.goal002_fit_fields <- c(
  "terminal_status",
  "rescue_used",
  "terminal_attempt_id",
  "candidate_ids",
  "camera_ids",
  "detected_ever",
  "observed",
  "grouped",
  "data_hash",
  "prior_profile",
  "model_source_hash",
  "attempts",
  "draws"
)

.goal002_diagnostic_metric_fields <- c(
  "divergences",
  "treedepth_hits",
  "ebfmi_by_chain",
  "min_ebfmi",
  "max_rhat",
  "min_bulk_ess",
  "min_tail_ess"
)

.goal002_richness_variables <- c(
  "expected_richness",
  "richness_lower_tail",
  "richness_upper_tail"
)

.goal002_richness_metadata_fields <- c(
  "status",
  "tau",
  "observed_richness",
  "candidate_pool_size",
  "lower_cutoff",
  "upper_cutoff",
  "mean_lower_mass",
  "mean_upper_mass",
  "row_diagnostics",
  "detail"
)

.goal002_generated_metric_fields <- c(
  "n_draws",
  "candidate_pool_size",
  "observed_richness",
  "max_expected_richness_error"
)

.goal002_terminal_statuses <- c(
  "primary_clean",
  "rescue_clean",
  "final_nonclean"
)

.stop_invalid_goal002_fit <- function(message) {
  stop(message, call. = FALSE)
}

.goal002_project_root <- function() {
  path <- normalizePath(getwd(), mustWork = TRUE)
  repeat {
    if (file.exists(file.path(path, "R", "infer_config.R")) &&
        file.exists(file.path(path, "stan", "flexirich_g.stan"))) {
      return(path)
    }
    parent <- dirname(path)
    if (identical(parent, path)) {
      break
    }
    path <- parent
  }
  .stop_invalid_goal002_fit(
    "Could not locate the flexiRich repository root."
  )
}

.goal002_source_artifacts <- function(project_root) {
  file.path(
    project_root,
    "stan",
    c(
      "flexirich_g",
      "flexirich_g.hpp",
      "flexirich_g.o",
      "flexirich_g.d"
    )
  )
}

.goal002_source_hash <- function(project_root = .goal002_project_root()) {
  digest::digest(
    file = file.path(project_root, "stan", "flexirich_g.stan"),
    algo = "sha256",
    serialize = FALSE
  )
}

.goal002_assert_flag <- function(x, name) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    .stop_invalid_goal002_fit(
      paste0(name, " must be exactly TRUE or FALSE.")
    )
  }
  x
}

.goal002_assert_hash <- function(x, name) {
  valid <- is.character(x) &&
    length(x) == 1L &&
    !is.na(x) &&
    grepl("^[0-9a-f]{64}$", x)
  if (!valid) {
    .stop_invalid_goal002_fit(
      paste0(name, " must be one lowercase SHA-256 hash.")
    )
  }
  x
}

.goal002_assert_text <- function(x, name) {
  valid <- is.character(x) &&
    length(x) == 1L &&
    !is.na(x) &&
    nzchar(x)
  if (!valid) {
    .stop_invalid_goal002_fit(
      paste0(name, " must be one non-empty character value.")
    )
  }
  x
}

.goal002_output_directory <- function(output_dir) {
  .goal002_assert_text(output_dir, "output_dir")
  project_root <- .goal002_project_root()
  boundary <- file.path(project_root, "outputs", "goal002")
  dir.create(
    boundary,
    recursive = TRUE,
    showWarnings = FALSE
  )
  boundary <- normalizePath(boundary, mustWork = TRUE)

  absolute <- if (startsWith(output_dir, "/")) {
    normalizePath(output_dir, mustWork = FALSE)
  } else {
    normalizePath(
      file.path(project_root, output_dir),
      mustWork = FALSE
    )
  }
  inside_boundary <- startsWith(
    absolute,
    paste0(boundary, .Platform$file.sep)
  )
  if (!inside_boundary) {
    .stop_invalid_goal002_fit(
      "output_dir must be a descendant of outputs/goal002."
    )
  }
  if (file.exists(absolute) || dir.exists(absolute)) {
    .stop_invalid_goal002_fit(
      "output_dir must not already exist; attempts are immutable."
    )
  }
  absolute
}

.goal002_relative_paths <- function(paths) {
  if (length(paths) == 0L) {
    return(character())
  }
  project_root <- .goal002_project_root()
  absolute <- vapply(
    paths,
    normalizePath,
    character(1),
    mustWork = TRUE
  )
  prefix <- paste0(project_root, .Platform$file.sep)
  if (any(!startsWith(absolute, prefix))) {
    .stop_invalid_goal002_fit(
      "CmdStan output files must remain within the repository."
    )
  }
  substring(absolute, nchar(prefix) + 1L)
}

.goal002_compiler_identity <- function() {
  configured <- Sys.getenv("CXX", unset = "")
  command <- if (nzchar(configured)) configured else "g++"
  executable <- Sys.which(command)
  if (!nzchar(executable)) {
    executable <- command
  }
  version <- tryCatch(
    system2(executable, "--version", stdout = TRUE, stderr = TRUE),
    error = function(e) character()
  )
  first_line <- if (length(version) > 0L && nzchar(version[1L])) {
    version[1L]
  } else {
    "version unavailable"
  }
  paste(executable, first_line, sep = " | ")
}

compile_flexirich_g_model <- function(force_recompile = FALSE) {
  force_recompile <- .goal002_assert_flag(
    force_recompile,
    "force_recompile"
  )
  check_goal002_cmdstan()
  project_root <- .goal002_project_root()
  source_artifacts <- .goal002_source_artifacts(project_root)
  if (any(file.exists(source_artifacts))) {
    .stop_invalid_goal002_fit(
      "Compiler artefacts exist beside the tracked Stan source."
    )
  }

  stan_file <- file.path(project_root, "stan", "flexirich_g.stan")
  source_hash <- .goal002_source_hash(project_root)
  hash_prefix <- substr(source_hash, 1L, 16L)
  output_root <- file.path(project_root, "outputs", "goal002", "cmdstan")
  copied_source_dir <- file.path(output_root, "source", hash_prefix)
  bin_dir <- file.path(output_root, "bin")
  dir.create(copied_source_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(bin_dir, recursive = TRUE, showWarnings = FALSE)

  copied_source <- file.path(copied_source_dir, "flexirich_g.stan")
  if (file.exists(copied_source)) {
    copied_hash <- digest::digest(
      file = copied_source,
      algo = "sha256",
      serialize = FALSE
    )
    if (!identical(copied_hash, source_hash)) {
      .stop_invalid_goal002_fit(
        "The source-hashed Stan cache is corrupt; refusing overwrite."
      )
    }
  } else if (!file.copy(stan_file, copied_source, overwrite = FALSE)) {
    .stop_invalid_goal002_fit(
      "Could not copy Stan source beneath outputs/goal002."
    )
  }

  executable <- file.path(
    bin_dir,
    paste0("flexirich_g-", hash_prefix)
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

  if (!file.exists(executable) ||
      !identical(
        normalizePath(model$exe_file(), mustWork = TRUE),
        normalizePath(executable, mustWork = TRUE)
      )) {
    .stop_invalid_goal002_fit(
      "CmdStanR did not use the required source-hashed executable."
    )
  }
  if (!identical(.goal002_source_hash(project_root), source_hash)) {
    .stop_invalid_goal002_fit(
      "The tracked Stan source changed during compilation."
    )
  }
  if (any(file.exists(source_artifacts))) {
    .stop_invalid_goal002_fit(
      "Compilation wrote an artefact beside the tracked Stan source."
    )
  }
  model
}

.goal002_validate_thresholds <- function(thresholds) {
  required <- c(
    "max_divergences",
    "max_treedepth_hits",
    "min_ebfmi",
    "max_rhat",
    "min_bulk_ess",
    "min_tail_ess"
  )
  if (!is.list(thresholds) ||
      !identical(names(thresholds), required)) {
    .stop_invalid_goal002_fit(
      "thresholds have an invalid component contract."
    )
  }

  thresholds$max_divergences <- .goal002_assert_integer(
    thresholds$max_divergences,
    "max_divergences",
    lower = 0L
  )
  thresholds$max_treedepth_hits <- .goal002_assert_integer(
    thresholds$max_treedepth_hits,
    "max_treedepth_hits",
    lower = 0L
  )
  thresholds$min_ebfmi <- .goal002_assert_numeric(
    thresholds$min_ebfmi,
    "min_ebfmi",
    positive = TRUE
  )
  thresholds$max_rhat <- .goal002_assert_numeric(
    thresholds$max_rhat,
    "max_rhat",
    positive = TRUE
  )
  thresholds$min_bulk_ess <- .goal002_assert_numeric(
    thresholds$min_bulk_ess,
    "min_bulk_ess",
    positive = TRUE
  )
  thresholds$min_tail_ess <- .goal002_assert_numeric(
    thresholds$min_tail_ess,
    "min_tail_ess",
    positive = TRUE
  )
  thresholds
}

.goal002_empty_diagnostic_metrics <- function() {
  list(
    divergences = NA_integer_,
    treedepth_hits = NA_integer_,
    ebfmi_by_chain = stats::setNames(
      rep(NA_real_, 4L),
      as.character(1:4)
    ),
    min_ebfmi = NA_real_,
    max_rhat = NA_real_,
    min_bulk_ess = NA_real_,
    min_tail_ess = NA_real_
  )
}

.goal002_add_reason <- function(state, reason, detail) {
  if (!reason %in% state$reasons) {
    state$reasons <- c(state$reasons, reason)
    state$details <- c(
      state$details,
      stats::setNames(as.character(detail), reason)
    )
  }
  state
}

.goal002_empty_richness_rows <- function() {
  tibble::tibble(
    variable = .goal002_richness_variables,
    rhat = rep(NA_real_, length(.goal002_richness_variables)),
    ess_bulk = rep(NA_real_, length(.goal002_richness_variables)),
    ess_tail = rep(NA_real_, length(.goal002_richness_variables))
  )
}

.goal002_richness_metadata <- function(
  status,
  observed_richness,
  candidate_pool_size,
  tau = 0.05,
  lower_cutoff = NA_integer_,
  upper_cutoff = NA_integer_,
  mean_lower_mass = NA_real_,
  mean_upper_mass = NA_real_,
  row_diagnostics = .goal002_empty_richness_rows(),
  detail = ""
) {
  list(
    status = status,
    tau = as.numeric(tau),
    observed_richness = as.integer(observed_richness),
    candidate_pool_size = as.integer(candidate_pool_size),
    lower_cutoff = as.integer(lower_cutoff),
    upper_cutoff = as.integer(upper_cutoff),
    mean_lower_mass = as.numeric(mean_lower_mass),
    mean_upper_mass = as.numeric(mean_upper_mass),
    row_diagnostics = tibble::as_tibble(row_diagnostics),
    detail = as.character(detail)
  )
}

.goal002_invalid_richness <- function(
  detail,
  observed_richness = NA_integer_,
  candidate_pool_size = NA_integer_,
  tau = 0.05,
  lower_cutoff = NA_integer_,
  upper_cutoff = NA_integer_,
  mean_lower_mass = NA_real_,
  mean_upper_mass = NA_real_,
  row_diagnostics = .goal002_empty_richness_rows()
) {
  .goal002_richness_metadata(
    status = "invalid",
    observed_richness = observed_richness,
    candidate_pool_size = candidate_pool_size,
    tau = tau,
    lower_cutoff = lower_cutoff,
    upper_cutoff = upper_cutoff,
    mean_lower_mass = mean_lower_mass,
    mean_upper_mass = mean_upper_mass,
    row_diagnostics = row_diagnostics,
    detail = detail
  )
}

.goal002_select_tail_candidate <- function(
  cutoff,
  mass,
  tau,
  side
) {
  proper <- is.finite(mass) & mass > 0 & mass < 1
  if (!any(proper)) {
    return(list(cutoff = NA_integer_, mass = NA_real_))
  }
  cutoff <- cutoff[proper]
  mass <- mass[proper]
  distance <- abs(mass - tau)
  tolerance <- 64 * .Machine$double.eps *
    max(1, abs(tau), max(abs(mass)))
  closest <- distance <= min(distance) + tolerance
  cutoff <- cutoff[closest]
  mass <- mass[closest]
  largest <- mass >= max(mass) - tolerance
  cutoff <- cutoff[largest]
  mass <- mass[largest]
  selected <- if (identical(side, "lower")) {
    which.min(cutoff)
  } else {
    which.max(cutoff)
  }
  list(
    cutoff = as.integer(cutoff[selected]),
    mass = as.numeric(mass[selected])
  )
}

.goal002_select_richness_tail_cutoffs <- function(
  mean_pmf,
  observed_richness,
  tau = 0.05
) {
  valid_pmf <- is.numeric(mean_pmf) &&
    !is.complex(mean_pmf) &&
    length(mean_pmf) >= 2L &&
    !anyNA(mean_pmf) &&
    all(is.finite(mean_pmf))
  if (!valid_pmf) {
    .stop_invalid_goal002_fit(
      "mean_pmf must contain finite numeric probabilities."
    )
  }
  if (any(mean_pmf < 0)) {
    .stop_invalid_goal002_fit(
      "mean_pmf probabilities must be non-negative."
    )
  }
  if (abs(sum(mean_pmf) - 1) > 1e-12) {
    .stop_invalid_goal002_fit(
      "mean_pmf probabilities must sum to one."
    )
  }
  candidate_pool_size <- length(mean_pmf) - 1L
  observed_richness <- .goal002_assert_integer(
    observed_richness,
    "observed_richness",
    lower = 0L,
    upper = candidate_pool_size
  )
  tau <- .goal002_assert_numeric(tau, "tau", positive = TRUE)
  if (tau >= 1) {
    .stop_invalid_goal002_fit("tau must be less than one.")
  }

  support <- 0:candidate_pool_size
  cumulative <- cumsum(mean_pmf)
  lower_cutoffs <- observed_richness:(candidate_pool_size - 1L)
  upper_cutoffs <- (observed_richness + 1L):candidate_pool_size
  lower <- .goal002_select_tail_candidate(
    cutoff = lower_cutoffs,
    mass = cumulative[lower_cutoffs + 1L],
    tau = tau,
    side = "lower"
  )
  upper_mass <- rev(cumsum(rev(mean_pmf)))
  upper <- .goal002_select_tail_candidate(
    cutoff = upper_cutoffs,
    mass = upper_mass[upper_cutoffs + 1L],
    tau = tau,
    side = "upper"
  )
  list(
    lower_cutoff = lower$cutoff,
    upper_cutoff = upper$cutoff,
    mean_lower_mass = lower$mass,
    mean_upper_mass = upper$mass
  )
}

.goal002_richness_row_diagnostics <- function(
  series,
  chain,
  iteration,
  expected_iterations
) {
  expected_iterations <- .goal002_assert_integer(
    expected_iterations,
    "expected_iterations",
    lower = 1L
  )
  chains <- sort(unique(chain))
  if (!identical(chains, 1:4)) {
    stop("Richness diagnostics require chains 1:4.", call. = FALSE)
  }
  iteration_sets <- lapply(
    chains,
    function(x) sort(iteration[chain == x])
  )
  required_iterations <- seq_len(expected_iterations)
  complete <- all(vapply(
    iteration_sets,
    identical,
    logical(1),
    required_iterations
  ))
  if (!complete) {
    stop(
      paste0(
        "Richness diagnostics require the complete chain-iteration grid."
      ),
      call. = FALSE
    )
  }

  n_iterations <- expected_iterations
  draw_array <- array(
    NA_real_,
    dim = c(
      n_iterations,
      length(chains),
      length(.goal002_richness_variables)
    ),
    dimnames = list(
      iteration = as.character(iteration_sets[[1L]]),
      chain = as.character(chains),
      variable = .goal002_richness_variables
    )
  )
  for (chain_id in chains) {
    rows <- which(chain == chain_id)
    rows <- rows[order(iteration[rows])]
    draw_array[, chain_id, ] <- as.matrix(
      series[rows, .goal002_richness_variables, drop = FALSE]
    )
  }
  diagnostics <- posterior::summarise_draws(
    posterior::as_draws_array(draw_array),
    rhat = posterior::rhat,
    ess_bulk = posterior::ess_bulk,
    ess_tail = posterior::ess_tail
  )
  tibble::as_tibble(diagnostics)[
    c("variable", "rhat", "ess_bulk", "ess_tail")
  ]
}

.goal002_build_richness_diagnostics <- function(
  q_draws,
  detected_ever,
  chain,
  iteration,
  expected_iterations,
  tau = 0.05
) {
  if (!is.matrix(q_draws)) {
    q_draws <- tryCatch(
      as.matrix(q_draws),
      error = function(e) NULL
    )
  }
  candidate_pool_size <- if (is.null(q_draws)) {
    length(detected_ever)
  } else {
    ncol(q_draws)
  }
  valid_detected <- is.integer(detected_ever) &&
    length(detected_ever) == candidate_pool_size &&
    !anyNA(detected_ever) &&
    all(detected_ever %in% c(0L, 1L))
  observed_richness <- if (valid_detected) {
    sum(detected_ever)
  } else {
    NA_integer_
  }
  n_draws <- if (is.null(q_draws)) 0L else nrow(q_draws)
  empty_series <- tibble::tibble(
    .chain = as.integer(chain),
    .iteration = as.integer(iteration),
    expected_richness = rep(NA_real_, length(chain)),
    richness_lower_tail = rep(NA_real_, length(chain)),
    richness_upper_tail = rep(NA_real_, length(chain))
  )
  invalid_result <- function(detail) {
    list(
      metadata = .goal002_invalid_richness(
        detail = detail,
        observed_richness = observed_richness,
        candidate_pool_size = candidate_pool_size,
        tau = tau
      ),
      mean_pmf = stats::setNames(
        rep(NA_real_, candidate_pool_size + 1L),
        as.character(0:candidate_pool_size)
      ),
      series = empty_series
    )
  }

  valid_q <- !is.null(q_draws) &&
    is.numeric(q_draws) &&
    !is.complex(q_draws) &&
    n_draws > 0L &&
    candidate_pool_size > 0L &&
    !anyNA(q_draws) &&
    all(is.finite(q_draws)) &&
    all(q_draws >= 0 & q_draws <= 1)
  valid_indices <- is.numeric(chain) &&
    is.numeric(iteration) &&
    length(chain) == n_draws &&
    length(iteration) == n_draws &&
    !anyNA(chain) &&
    !anyNA(iteration) &&
    all(is.finite(chain)) &&
    all(is.finite(iteration)) &&
    all(chain == trunc(chain)) &&
    all(iteration == trunc(iteration))
  valid_expected_iterations <- is.numeric(expected_iterations) &&
    !is.complex(expected_iterations) &&
    length(expected_iterations) == 1L &&
    !is.na(expected_iterations) &&
    is.finite(expected_iterations) &&
    expected_iterations == trunc(expected_iterations) &&
    expected_iterations >= 1L &&
    expected_iterations <= .Machine$integer.max
  if (!valid_q) {
    return(invalid_result(
      "q_member draws must be a non-empty finite matrix in [0, 1]."
    ))
  }
  if (!valid_detected) {
    return(invalid_result(
      "detected_ever must be an integer candidate-level 0/1 vector."
    ))
  }
  if (!valid_indices) {
    return(invalid_result(
      "Richness chain and iteration identifiers are invalid."
    ))
  }
  if (!valid_expected_iterations) {
    return(invalid_result(
      "expected_iterations must be one positive representable integer."
    ))
  }
  expected_iterations <- as.integer(expected_iterations)
  complete_grid <- identical(sort(unique(as.integer(chain))), 1:4) &&
    all(vapply(
      1:4,
      function(chain_id) {
        identical(
          sort(as.integer(iteration[chain == chain_id])),
          seq_len(expected_iterations)
        )
      },
      logical(1)
    ))
  if (!complete_grid) {
    return(invalid_result(
      "Richness diagnostics require the complete chain-iteration grid."
    ))
  }
  if (any(q_draws[, detected_ever == 1L, drop = FALSE] != 1)) {
    return(invalid_result(
      "Detected candidates must have q_member exactly equal to one."
    ))
  }

  pmf_by_draw <- t(vapply(
    seq_len(n_draws),
    function(draw) poisson_binomial_pmf(q_draws[draw, ]),
    numeric(candidate_pool_size + 1L)
  ))
  colnames(pmf_by_draw) <- as.character(0:candidate_pool_size)
  mean_pmf <- colMeans(pmf_by_draw)
  mean_pmf <- mean_pmf / sum(mean_pmf)
  names(mean_pmf) <- as.character(0:candidate_pool_size)
  series <- tibble::tibble(
    .chain = as.integer(chain),
    .iteration = as.integer(iteration),
    expected_richness = rowSums(q_draws),
    richness_lower_tail = rep(NA_real_, n_draws),
    richness_upper_tail = rep(NA_real_, n_draws)
  )

  if (candidate_pool_size == observed_richness) {
    structural_pmf <- stats::setNames(
      c(rep(0, candidate_pool_size), 1),
      as.character(0:candidate_pool_size)
    )
    return(list(
      metadata = .goal002_richness_metadata(
        status = "structural_point_mass",
        observed_richness = observed_richness,
        candidate_pool_size = candidate_pool_size,
        tau = tau,
        row_diagnostics = .goal002_empty_richness_rows(),
        detail = "Richness is a structural point mass."
      ),
      mean_pmf = structural_pmf,
      series = series
    ))
  }

  cutoffs <- tryCatch(
    .goal002_select_richness_tail_cutoffs(
      mean_pmf,
      observed_richness,
      tau
    ),
    error = function(e) NULL
  )
  if (is.null(cutoffs) ||
      anyNA(unlist(cutoffs, use.names = FALSE))) {
    return(list(
      metadata = .goal002_invalid_richness(
        detail = "No proper richness-tail cutoff could be selected.",
        observed_richness = observed_richness,
        candidate_pool_size = candidate_pool_size,
        tau = tau
      ),
      mean_pmf = mean_pmf,
      series = series
    ))
  }

  lower_columns <- seq_len(cutoffs$lower_cutoff + 1L)
  upper_columns <- seq.int(
    cutoffs$upper_cutoff + 1L,
    candidate_pool_size + 1L
  )
  series$richness_lower_tail <- rowSums(
    pmf_by_draw[, lower_columns, drop = FALSE]
  )
  series$richness_upper_tail <- rowSums(
    pmf_by_draw[, upper_columns, drop = FALSE]
  )
  tail_values <- as.matrix(series[
    c("richness_lower_tail", "richness_upper_tail")
  ])
  constant_tail <- vapply(
    as.data.frame(tail_values),
    function(x) length(unique(x)) <= 1L,
    logical(1)
  )
  if (any(!is.finite(tail_values)) || any(constant_tail)) {
    return(list(
      metadata = .goal002_invalid_richness(
        detail = paste0(
          "Richness-tail series are non-finite or constant: ",
          paste(
            names(constant_tail)[constant_tail],
            collapse = ", "
          ),
          "."
        ),
        observed_richness = observed_richness,
        candidate_pool_size = candidate_pool_size,
        tau = tau,
        lower_cutoff = cutoffs$lower_cutoff,
        upper_cutoff = cutoffs$upper_cutoff,
        mean_lower_mass = cutoffs$mean_lower_mass,
        mean_upper_mass = cutoffs$mean_upper_mass
      ),
      mean_pmf = mean_pmf,
      series = series
    ))
  }

  row_diagnostics <- tryCatch(
    .goal002_richness_row_diagnostics(
      series,
      chain,
      iteration,
      expected_iterations
    ),
    error = function(e) NULL
  )
  diagnostic_values <- if (is.null(row_diagnostics)) {
    NA_real_
  } else {
    unlist(
      row_diagnostics[c("rhat", "ess_bulk", "ess_tail")],
      use.names = FALSE
    )
  }
  if (is.null(row_diagnostics) ||
      anyNA(diagnostic_values) ||
      any(!is.finite(diagnostic_values))) {
    return(list(
      metadata = .goal002_invalid_richness(
        detail = "Richness-tail convergence diagnostics are non-finite.",
        observed_richness = observed_richness,
        candidate_pool_size = candidate_pool_size,
        tau = tau,
        lower_cutoff = cutoffs$lower_cutoff,
        upper_cutoff = cutoffs$upper_cutoff,
        mean_lower_mass = cutoffs$mean_lower_mass,
        mean_upper_mass = cutoffs$mean_upper_mass,
        row_diagnostics = if (is.null(row_diagnostics)) {
          .goal002_empty_richness_rows()
        } else {
          row_diagnostics
        }
      ),
      mean_pmf = mean_pmf,
      series = series
    ))
  }

  list(
    metadata = .goal002_richness_metadata(
      status = "estimated",
      observed_richness = observed_richness,
      candidate_pool_size = candidate_pool_size,
      tau = tau,
      lower_cutoff = cutoffs$lower_cutoff,
      upper_cutoff = cutoffs$upper_cutoff,
      mean_lower_mass = cutoffs$mean_lower_mass,
      mean_upper_mass = cutoffs$mean_upper_mass,
      row_diagnostics = row_diagnostics
    ),
    mean_pmf = mean_pmf,
    series = series
  )
}

.goal002_validate_richness_metadata <- function(metadata) {
  fallback <- .goal002_invalid_richness(
    "Richness metadata do not match the contract."
  )
  if (!is.list(metadata) ||
      !identical(names(metadata), .goal002_richness_metadata_fields)) {
    return(list(valid = FALSE, metadata = fallback))
  }
  valid_status <- is.character(metadata$status) &&
    length(metadata$status) == 1L &&
    !is.na(metadata$status) &&
    metadata$status %in% c(
      "estimated",
      "structural_point_mass",
      "invalid"
    )
  valid_tau <- is.numeric(metadata$tau) &&
    length(metadata$tau) == 1L &&
    !is.na(metadata$tau) &&
    is.finite(metadata$tau) &&
    metadata$tau > 0 &&
    metadata$tau < 1
  scalar_integer <- function(x, allow_na = FALSE) {
    is.integer(x) &&
      length(x) == 1L &&
      (allow_na && is.na(x) ||
        !is.na(x) && x == trunc(x) && x >= 0L)
  }
  allow_unknown <- identical(metadata$status, "invalid")
  valid_sizes <- scalar_integer(
    metadata$observed_richness,
    allow_na = allow_unknown
  ) &&
    scalar_integer(
      metadata$candidate_pool_size,
      allow_na = allow_unknown
    ) &&
    (allow_unknown &&
      (is.na(metadata$observed_richness) ||
        is.na(metadata$candidate_pool_size)) ||
      metadata$observed_richness <= metadata$candidate_pool_size)
  rows <- metadata$row_diagnostics
  valid_rows <- tibble::is_tibble(rows) &&
    identical(
      names(rows),
      c("variable", "rhat", "ess_bulk", "ess_tail")
    ) &&
    identical(rows$variable, .goal002_richness_variables) &&
    all(vapply(
      rows[c("rhat", "ess_bulk", "ess_tail")],
      is.numeric,
      logical(1)
    ))
  valid_detail <- is.character(metadata$detail) &&
    length(metadata$detail) == 1L &&
    !is.na(metadata$detail)
  if (!valid_status || !valid_tau || !valid_sizes ||
      !valid_rows || !valid_detail) {
    return(list(valid = FALSE, metadata = fallback))
  }

  if (identical(metadata$status, "estimated")) {
    valid_cutoffs <- scalar_integer(metadata$lower_cutoff) &&
      scalar_integer(metadata$upper_cutoff) &&
      metadata$lower_cutoff >= metadata$observed_richness &&
      metadata$lower_cutoff < metadata$candidate_pool_size &&
      metadata$upper_cutoff > metadata$observed_richness &&
      metadata$upper_cutoff <= metadata$candidate_pool_size
    valid_masses <- all(vapply(
      metadata[c("mean_lower_mass", "mean_upper_mass")],
      function(x) {
        is.numeric(x) &&
          length(x) == 1L &&
          !is.na(x) &&
          is.finite(x) &&
          x > 0 &&
          x < 1
      },
      logical(1)
    ))
    diagnostic_values <- unlist(
      rows[c("rhat", "ess_bulk", "ess_tail")],
      use.names = FALSE
    )
    valid_diagnostics <- !anyNA(diagnostic_values) &&
      all(is.finite(diagnostic_values))
    if (!valid_cutoffs || !valid_masses || !valid_diagnostics) {
      return(list(valid = FALSE, metadata = fallback))
    }
  } else if (identical(metadata$status, "structural_point_mass")) {
    scalar_na <- vapply(
      metadata[c(
        "lower_cutoff",
        "upper_cutoff",
        "mean_lower_mass",
        "mean_upper_mass"
      )],
      function(x) length(x) == 1L && is.na(x),
      logical(1)
    )
    diagnostics_na <- all(is.na(unlist(
      rows[c("rhat", "ess_bulk", "ess_tail")],
      use.names = FALSE
    )))
    valid_structural <- all(scalar_na) &&
      diagnostics_na &&
      metadata$observed_richness == metadata$candidate_pool_size &&
      nzchar(metadata$detail)
    if (!valid_structural) {
      return(list(valid = FALSE, metadata = fallback))
    }
  } else if (!nzchar(metadata$detail)) {
    return(list(valid = FALSE, metadata = fallback))
  }

  list(valid = TRUE, metadata = metadata)
}

.goal002_summary_diagnostics <- function(summary, state, thresholds) {
  valid_list <- is.list(summary) &&
    identical(
      names(summary),
      c("monitored_variables", "statistics", "richness")
    )
  if (!valid_list) {
    return(.goal002_add_reason(
      state,
      "summary_schema",
      paste0(
        "Summary must contain monitored_variables, statistics, ",
        "and richness."
      )
    ))
  }

  richness_result <- .goal002_validate_richness_metadata(
    summary$richness
  )
  state$richness <- richness_result$metadata
  if (!richness_result$valid) {
    state <- .goal002_add_reason(
      state,
      "richness_schema",
      "Richness diagnostic metadata do not match the contract."
    )
  } else if (identical(state$richness$status, "invalid")) {
    state <- .goal002_add_reason(
      state,
      "richness_tail_degenerate",
      state$richness$detail
    )
  }

  monitored <- summary$monitored_variables
  valid_monitored <- is.character(monitored) &&
    length(monitored) > 0L &&
    !anyNA(monitored) &&
    all(nzchar(monitored)) &&
    !anyDuplicated(monitored)
  statistics <- summary$statistics
  valid_statistics <- is.data.frame(statistics) &&
    identical(
      names(statistics),
      c("variable", "rhat", "ess_bulk", "ess_tail")
    ) &&
    is.character(statistics$variable) &&
    is.numeric(statistics$rhat) &&
    is.numeric(statistics$ess_bulk) &&
    is.numeric(statistics$ess_tail)

  if (!valid_monitored || !valid_statistics) {
    return(.goal002_add_reason(
      state,
      "summary_schema",
      "Posterior summary fields or types do not match the contract."
    ))
  }

  if (richness_result$valid &&
      identical(state$richness$status, "estimated")) {
    richness_statistics <- statistics[
      statistics$variable %in% .goal002_richness_variables,
      ,
      drop = FALSE
    ]
    richness_statistics <- richness_statistics[
      match(
        .goal002_richness_variables,
        richness_statistics$variable
      ),
      ,
      drop = FALSE
    ]
    required_monitored <- all(
      .goal002_richness_variables %in% monitored
    )
    rows_match <- nrow(richness_statistics) ==
      length(.goal002_richness_variables) &&
      isTRUE(all.equal(
        tibble::as_tibble(richness_statistics),
        state$richness$row_diagnostics,
        tolerance = 0,
        check.attributes = FALSE
      ))
    if (!required_monitored || !rows_match) {
      state <- .goal002_add_reason(
        state,
        "richness_diagnostic_mismatch",
        paste0(
          "Richness convergence rows disagree with persisted ",
          "Rao-Blackwellised diagnostics."
        )
      )
    }
  } else if (richness_result$valid &&
      identical(state$richness$status, "structural_point_mass")) {
    if (any(.goal002_richness_variables %in% monitored) ||
        any(.goal002_richness_variables %in% statistics$variable)) {
      state <- .goal002_add_reason(
        state,
        "richness_diagnostic_mismatch",
        "Structural richness must not be assigned mixing diagnostics."
      )
    }
  }
  if (anyDuplicated(statistics$variable)) {
    state <- .goal002_add_reason(
      state,
      "summary_duplicate_rows",
      "Posterior summary contains duplicate monitored rows."
    )
  }
  missing_rows <- setdiff(monitored, statistics$variable)
  if (length(missing_rows) > 0L) {
    state <- .goal002_add_reason(
      state,
      "summary_missing_rows",
      paste(missing_rows, collapse = ", ")
    )
  }
  unexpected_rows <- setdiff(statistics$variable, monitored)
  if (length(unexpected_rows) > 0L) {
    state <- .goal002_add_reason(
      state,
      "summary_unexpected_rows",
      paste(unexpected_rows, collapse = ", ")
    )
  }

  numeric_values <- unlist(
    statistics[c("rhat", "ess_bulk", "ess_tail")],
    use.names = FALSE
  )
  if (anyNA(statistics$variable) ||
      any(!nzchar(statistics$variable)) ||
      anyNA(numeric_values) ||
      any(!is.finite(numeric_values))) {
    state <- .goal002_add_reason(
      state,
      "summary_nonfinite",
      "Posterior summary contains missing or non-finite values."
    )
  }

  summary_invalid <- any(c(
    "summary_schema",
    "summary_duplicate_rows",
    "summary_missing_rows",
    "summary_unexpected_rows",
    "summary_nonfinite",
    "richness_schema",
    "richness_diagnostic_mismatch"
  ) %in% state$reasons)
  if (summary_invalid) {
    return(state)
  }

  state$metrics$max_rhat <- max(statistics$rhat)
  state$metrics$min_bulk_ess <- min(statistics$ess_bulk)
  state$metrics$min_tail_ess <- min(statistics$ess_tail)
  if (state$metrics$max_rhat > thresholds$max_rhat) {
    state <- .goal002_add_reason(
      state,
      "rhat",
      paste0("max R-hat = ", state$metrics$max_rhat)
    )
  }
  if (state$metrics$min_bulk_ess < thresholds$min_bulk_ess) {
    state <- .goal002_add_reason(
      state,
      "bulk_ess",
      paste0("min bulk ESS = ", state$metrics$min_bulk_ess)
    )
  }
  if (state$metrics$min_tail_ess < thresholds$min_tail_ess) {
    state <- .goal002_add_reason(
      state,
      "tail_ess",
      paste0("min tail ESS = ", state$metrics$min_tail_ess)
    )
  }
  state
}

.goal002_sampler_diagnostics <- function(
  sampler_diagnostics,
  state,
  thresholds
) {
  valid_list <- is.list(sampler_diagnostics) &&
    identical(
      names(sampler_diagnostics),
      c(
        "expected_chains",
        "expected_iterations",
        "max_treedepth",
        "draws"
      )
    )
  if (!valid_list) {
    return(.goal002_add_reason(
      state,
      "sampler_schema",
      "Sampler diagnostics have an invalid component contract."
    ))
  }

  expected_chains <- sampler_diagnostics$expected_chains
  expected_iterations <- sampler_diagnostics$expected_iterations
  max_treedepth <- sampler_diagnostics$max_treedepth
  valid_scalars <- is.numeric(expected_chains) &&
    length(expected_chains) == 1L &&
    !is.na(expected_chains) &&
    is.finite(expected_chains) &&
    expected_chains == trunc(expected_chains) &&
    expected_chains == 4L &&
    is.numeric(expected_iterations) &&
    length(expected_iterations) == 1L &&
    !is.na(expected_iterations) &&
    is.finite(expected_iterations) &&
    expected_iterations == trunc(expected_iterations) &&
    expected_iterations >= 1L &&
    expected_iterations <= .Machine$integer.max &&
    is.numeric(max_treedepth) &&
    length(max_treedepth) == 1L &&
    !is.na(max_treedepth) &&
    is.finite(max_treedepth) &&
    max_treedepth == trunc(max_treedepth) &&
    max_treedepth > 0L
  draws <- sampler_diagnostics$draws
  required_fields <- c(
    "divergent__",
    "treedepth__",
    "energy__",
    ".chain",
    ".iteration"
  )
  valid_draws <- is.data.frame(draws) &&
    identical(names(draws), required_fields)
  if (!valid_scalars || !valid_draws) {
    return(.goal002_add_reason(
      state,
      "sampler_schema",
      "Sampler fields, chains, or max_treedepth are invalid."
    ))
  }

  numeric_fields <- vapply(draws, is.numeric, logical(1))
  if (!all(numeric_fields)) {
    return(.goal002_add_reason(
      state,
      "sampler_schema",
      "Sampler diagnostic columns must be numeric."
    ))
  }
  numeric_values <- unlist(draws, use.names = FALSE)
  if (nrow(draws) == 0L ||
      anyNA(numeric_values) ||
      any(!is.finite(numeric_values))) {
    state <- .goal002_add_reason(
      state,
      "sampler_nonfinite",
      "Sampler diagnostics contain missing or non-finite values."
    )
  }

  whole_fields <- c(
    "divergent__",
    "treedepth__",
    ".chain",
    ".iteration"
  )
  valid_whole <- all(vapply(
    draws[whole_fields],
    function(x) all(x == trunc(x)),
    logical(1)
  ))
  valid_support <- valid_whole &&
    all(draws$divergent__ %in% c(0, 1)) &&
    all(draws$treedepth__ >= 0) &&
    all(draws$.chain >= 1) &&
    all(draws$.iteration >= 1)
  if (!valid_support) {
    state <- .goal002_add_reason(
      state,
      "sampler_schema",
      "Sampler diagnostic values are outside their support."
    )
  }

  if (anyDuplicated(draws[c(".chain", ".iteration")])) {
    state <- .goal002_add_reason(
      state,
      "sampler_duplicate_rows",
      "Sampler diagnostics duplicate a chain-iteration row."
    )
  }
  actual_chains <- sort(unique(as.integer(draws$.chain)))
  required_chains <- seq_len(as.integer(expected_chains))
  if (!identical(actual_chains, required_chains)) {
    state <- .goal002_add_reason(
      state,
      "sampler_missing_chains",
      paste0(
        "Expected chains ",
        paste(required_chains, collapse = ","),
        "; found ",
        paste(actual_chains, collapse = ","),
        "."
      )
    )
  }

  if (identical(actual_chains, required_chains)) {
    required_iterations <- seq_len(as.integer(expected_iterations))
    complete_iterations <- all(vapply(
      required_chains,
      function(chain) {
        identical(
          sort(as.integer(
            draws$.iteration[draws$.chain == chain]
          )),
          required_iterations
        )
      },
      logical(1)
    ))
    if (!complete_iterations) {
      state <- .goal002_add_reason(
        state,
        "sampler_missing_iterations",
        paste0(
          "Every chain must contain post-warmup iterations 1:",
          expected_iterations,
          " exactly once."
        )
      )
    }
  }

  sampler_invalid <- any(c(
    "sampler_schema",
    "sampler_nonfinite",
    "sampler_duplicate_rows",
    "sampler_missing_chains",
    "sampler_missing_iterations"
  ) %in% state$reasons)
  if (sampler_invalid) {
    return(state)
  }

  draws$.chain <- as.integer(draws$.chain)
  state$metrics$divergences <- as.integer(sum(draws$divergent__))
  state$metrics$treedepth_hits <- as.integer(sum(
    draws$treedepth__ >= max_treedepth
  ))
  ebfmi <- vapply(
    required_chains,
    function(chain) {
      chain_rows <- draws$.chain == chain
      order_index <- order(draws$.iteration[chain_rows])
      energy <- draws$energy__[chain_rows][order_index]
      numerator <- mean(diff(energy)^2)
      denominator <- stats::var(energy)
      if (!is.finite(numerator) ||
          !is.finite(denominator) ||
          denominator <= 0) {
        return(NA_real_)
      }
      numerator / denominator
    },
    numeric(1)
  )
  names(ebfmi) <- as.character(required_chains)
  state$metrics$ebfmi_by_chain <- ebfmi

  if (anyNA(ebfmi) || any(!is.finite(ebfmi))) {
    state$metrics$min_ebfmi <- NA_real_
    state <- .goal002_add_reason(
      state,
      "ebfmi",
      "At least one chain has undefined E-BFMI."
    )
  } else {
    state$metrics$min_ebfmi <- min(ebfmi)
    if (state$metrics$min_ebfmi < thresholds$min_ebfmi) {
      state <- .goal002_add_reason(
        state,
        "ebfmi",
        paste0("min E-BFMI = ", state$metrics$min_ebfmi)
      )
    }
  }
  if (state$metrics$divergences > thresholds$max_divergences) {
    state <- .goal002_add_reason(
      state,
      "divergences",
      paste0("divergences = ", state$metrics$divergences)
    )
  }
  if (state$metrics$treedepth_hits >
      thresholds$max_treedepth_hits) {
    state <- .goal002_add_reason(
      state,
      "treedepth",
      paste0("max-treedepth hits = ", state$metrics$treedepth_hits)
    )
  }
  state
}

.goal002_generated_contract <- function(
  status,
  reasons = character(),
  n_draws = NA_integer_,
  candidate_pool_size = NA_integer_,
  observed_richness = NA_integer_,
  max_expected_richness_error = NA_real_,
  details = character()
) {
  list(
    status = status,
    reasons = reasons,
    metrics = list(
      n_draws = as.integer(n_draws),
      candidate_pool_size = as.integer(candidate_pool_size),
      observed_richness = as.integer(observed_richness),
      max_expected_richness_error = as.numeric(
        max_expected_richness_error
      )
    ),
    details = details
  )
}

.goal002_not_checked_generated_contract <- function() {
  .goal002_generated_contract(status = "not_checked")
}

.goal002_validate_generated_contract <- function(contract) {
  valid <- is.list(contract) &&
    identical(
      names(contract),
      c("status", "reasons", "metrics", "details")
    ) &&
    is.character(contract$status) &&
    length(contract$status) == 1L &&
    !is.na(contract$status) &&
    contract$status %in% c("not_checked", "passed", "failed") &&
    is.character(contract$reasons) &&
    !anyNA(contract$reasons) &&
    !any(!nzchar(contract$reasons)) &&
    !anyDuplicated(contract$reasons) &&
    is.list(contract$metrics) &&
    identical(
      names(contract$metrics),
      .goal002_generated_metric_fields
    ) &&
    is.character(contract$details)
  if (!valid) {
    return(FALSE)
  }
  integer_metrics <- contract$metrics[
    c("n_draws", "candidate_pool_size", "observed_richness")
  ]
  valid_integer_metrics <- all(vapply(
    integer_metrics,
    function(x) {
      is.integer(x) &&
        length(x) == 1L &&
        (is.na(x) || x >= 0L)
    },
    logical(1)
  ))
  max_error <- contract$metrics$max_expected_richness_error
  valid_error <- is.numeric(max_error) &&
    length(max_error) == 1L &&
    (is.na(max_error) ||
      is.finite(max_error) && max_error >= 0)
  names_match <- if (length(contract$reasons) == 0L) {
    length(contract$details) == 0L
  } else {
    identical(names(contract$details), contract$reasons) &&
      !anyNA(contract$details) &&
      all(nzchar(contract$details))
  }
  status_match <- switch(
    contract$status,
    not_checked = length(contract$reasons) == 0L &&
      all(vapply(contract$metrics, function(x) is.na(x), logical(1))),
    passed = length(contract$reasons) == 0L &&
      all(!vapply(contract$metrics, function(x) is.na(x), logical(1))),
    failed = length(contract$reasons) > 0L
  )
  valid_integer_metrics && valid_error && names_match && status_match
}

.goal002_check_generated_richness <- function(
  draws,
  detected_ever,
  tolerance = 1e-8
) {
  tolerance <- .goal002_assert_numeric(
    tolerance,
    "tolerance",
    positive = TRUE
  )
  valid_detected <- is.integer(detected_ever) &&
    length(detected_ever) > 0L &&
    !anyNA(detected_ever) &&
    all(detected_ever %in% c(0L, 1L))
  candidate_pool_size <- length(detected_ever)
  observed_richness <- if (valid_detected) {
    sum(detected_ever)
  } else {
    NA_integer_
  }
  n_draws <- if (is.matrix(draws)) nrow(draws) else 0L
  reasons <- character()
  details <- character()
  add_reason <- function(reason, detail) {
    if (!reason %in% reasons) {
      reasons <<- c(reasons, reason)
      details <<- c(
        details,
        stats::setNames(as.character(detail), reason)
      )
    }
  }

  if (!valid_detected ||
      !is.matrix(draws) ||
      !is.numeric(draws) ||
      nrow(draws) == 0L ||
      is.null(colnames(draws)) ||
      anyNA(colnames(draws)) ||
      any(!nzchar(colnames(draws))) ||
      anyDuplicated(colnames(draws))) {
    add_reason(
      "generated_draw_schema",
      "Generated draws or detected_ever do not match the contract."
    )
  }

  q_names <- sprintf(
    "q_member[%d]",
    seq_len(candidate_pool_size)
  )
  g_names <- sprintf(
    "g_member[%d]",
    seq_len(candidate_pool_size)
  )
  required <- c(q_names, g_names, "S_grid", "expected_richness")
  if (length(reasons) == 0L &&
      !all(required %in% colnames(draws))) {
    add_reason(
      "generated_draw_schema",
      "Generated richness columns are incomplete."
    )
  }

  max_error <- NA_real_
  if (!"generated_draw_schema" %in% reasons) {
    q <- draws[, q_names, drop = FALSE]
    g <- draws[, g_names, drop = FALSE]
    s_grid <- draws[, "S_grid"]
    expected_richness <- draws[, "expected_richness"]

    q_finite <- all(is.finite(q))
    if (!q_finite) {
      add_reason(
        "q_member_nonfinite",
        "q_member contains a missing or non-finite value."
      )
    }
    if (any(is.finite(q) & (q < 0 | q > 1))) {
      add_reason(
        "q_member_support",
        "q_member contains a value outside [0, 1]."
      )
    }
    g_valid <- all(is.finite(g)) && all(g %in% c(0, 1))
    if (!g_valid) {
      add_reason(
        "g_member_support",
        "g_member must contain only finite binary values."
      )
    }
    if (q_finite && g_valid &&
        (any(q[, detected_ever == 1L, drop = FALSE] != 1) ||
          any(g[, detected_ever == 1L, drop = FALSE] != 1))) {
      add_reason(
        "detected_membership",
        "Detected candidates must have q_member and g_member exactly one."
      )
    }

    s_valid <- all(is.finite(s_grid)) &&
      all(s_grid == trunc(s_grid)) &&
      all(s_grid >= observed_richness & s_grid <= candidate_pool_size)
    if (!s_valid) {
      add_reason(
        "s_grid_support",
        "S_grid violates integer richness support."
      )
    }
    if (g_valid && s_valid && any(s_grid != rowSums(g))) {
      add_reason(
        "s_grid_reconstruction",
        "S_grid does not equal rowSums(g_member)."
      )
    }

    if (q_finite && all(is.finite(expected_richness))) {
      errors <- abs(expected_richness - rowSums(q))
      max_error <- max(errors)
      if (any(errors > tolerance)) {
        add_reason(
          "expected_richness_reconstruction",
          paste0(
            "expected_richness differs from rowSums(q_member) by ",
            max_error,
            "."
          )
        )
      }
    } else {
      add_reason(
        "expected_richness_reconstruction",
        "expected_richness cannot be reconstructed from finite q_member."
      )
    }
  }

  status <- if (length(reasons) == 0L) "passed" else "failed"
  result <- .goal002_generated_contract(
    status = status,
    reasons = reasons,
    n_draws = n_draws,
    candidate_pool_size = candidate_pool_size,
    observed_richness = observed_richness,
    max_expected_richness_error = max_error,
    details = details
  )
  if (!.goal002_validate_generated_contract(result)) {
    .stop_invalid_goal002_fit(
      "Internal generated-richness validation produced an invalid result."
    )
  }
  result
}

classify_goal002_diagnostics <- function(
  summary,
  sampler_diagnostics,
  thresholds
) {
  thresholds <- .goal002_validate_thresholds(thresholds)
  state <- list(
    reasons = character(),
    details = character(),
    metrics = .goal002_empty_diagnostic_metrics(),
    richness = .goal002_invalid_richness(
      "Richness diagnostics were not available."
    )
  )
  state <- .goal002_summary_diagnostics(
    summary,
    state,
    thresholds
  )
  state <- .goal002_sampler_diagnostics(
    sampler_diagnostics,
    state,
    thresholds
  )
  result <- list(
    clean = length(state$reasons) == 0L,
    reasons = state$reasons,
    metrics = state$metrics,
    richness = state$richness,
    generated_richness = .goal002_not_checked_generated_contract(),
    details = state$details
  )
  validate_goal002_diagnostics(result)
  result
}

.goal002_failed_diagnostics <- function(reason, detail) {
  state <- list(
    reasons = character(),
    details = character(),
    metrics = .goal002_empty_diagnostic_metrics(),
    richness = .goal002_invalid_richness(
      "Richness diagnostics were not available because the attempt failed."
    )
  )
  state <- .goal002_add_reason(state, reason, detail)
  result <- list(
    clean = FALSE,
    reasons = state$reasons,
    metrics = state$metrics,
    richness = state$richness,
    generated_richness = .goal002_not_checked_generated_contract(),
    details = state$details
  )
  validate_goal002_diagnostics(result)
  result
}

.goal002_append_diagnostic_failure <- function(
  diagnostics,
  reason,
  detail
) {
  validate_goal002_diagnostics(diagnostics)
  state <- list(
    reasons = diagnostics$reasons,
    details = diagnostics$details,
    metrics = diagnostics$metrics,
    richness = diagnostics$richness
  )
  state <- .goal002_add_reason(state, reason, detail)
  result <- list(
    clean = FALSE,
    reasons = state$reasons,
    metrics = state$metrics,
    richness = state$richness,
    generated_richness = diagnostics$generated_richness,
    details = state$details
  )
  validate_goal002_diagnostics(result)
  result
}

.goal002_attach_generated_richness <- function(
  diagnostics,
  generated_richness
) {
  validate_goal002_diagnostics(diagnostics)
  if (!.goal002_validate_generated_contract(generated_richness) ||
      identical(generated_richness$status, "not_checked")) {
    .stop_invalid_goal002_fit(
      "generated_richness must be a completed generated-draw check."
    )
  }
  state <- list(
    reasons = diagnostics$reasons,
    details = diagnostics$details,
    metrics = diagnostics$metrics,
    richness = diagnostics$richness
  )
  if (identical(generated_richness$status, "failed")) {
    for (reason in generated_richness$reasons) {
      state <- .goal002_add_reason(
        state,
        reason,
        generated_richness$details[[reason]]
      )
    }
  }
  result <- list(
    clean = length(state$reasons) == 0L,
    reasons = state$reasons,
    metrics = state$metrics,
    richness = state$richness,
    generated_richness = generated_richness,
    details = state$details
  )
  validate_goal002_diagnostics(result)
  result
}

validate_goal002_diagnostics <- function(diagnostics) {
  if (!is.list(diagnostics) ||
      !identical(
        names(diagnostics),
        c(
          "clean",
          "reasons",
          "metrics",
          "richness",
          "generated_richness",
          "details"
        )
      )) {
    .stop_invalid_goal002_fit(
      "diagnostics have an invalid component contract."
    )
  }
  .goal002_assert_flag(diagnostics$clean, "diagnostics$clean")
  if (!is.character(diagnostics$reasons) ||
      anyNA(diagnostics$reasons) ||
      any(!nzchar(diagnostics$reasons)) ||
      anyDuplicated(diagnostics$reasons)) {
    .stop_invalid_goal002_fit(
      "diagnostics$reasons must contain unique non-empty labels."
    )
  }
  if (diagnostics$clean != (length(diagnostics$reasons) == 0L)) {
    .stop_invalid_goal002_fit(
      "diagnostics$clean must agree with diagnostics$reasons."
    )
  }
  if (!is.list(diagnostics$metrics) ||
      !identical(
        names(diagnostics$metrics),
        .goal002_diagnostic_metric_fields
      )) {
    .stop_invalid_goal002_fit(
      "diagnostics$metrics have an invalid component contract."
    )
  }
  richness_result <- .goal002_validate_richness_metadata(
    diagnostics$richness
  )
  if (!richness_result$valid ||
      !identical(richness_result$metadata, diagnostics$richness)) {
    .stop_invalid_goal002_fit(
      "diagnostics$richness has an invalid component contract."
    )
  }
  if (!.goal002_validate_generated_contract(
    diagnostics$generated_richness
  )) {
    .stop_invalid_goal002_fit(
      "diagnostics$generated_richness has an invalid contract."
    )
  }

  scalar_metrics <- setdiff(
    .goal002_diagnostic_metric_fields,
    "ebfmi_by_chain"
  )
  for (field in scalar_metrics) {
    value <- diagnostics$metrics[[field]]
    if (!is.numeric(value) ||
        length(value) != 1L ||
        is.nan(value) ||
        is.infinite(value)) {
      .stop_invalid_goal002_fit(
        paste0("diagnostics$metrics$", field, " is invalid.")
      )
    }
  }
  ebfmi <- diagnostics$metrics$ebfmi_by_chain
  if (!is.numeric(ebfmi) ||
      length(ebfmi) != 4L ||
      !identical(names(ebfmi), as.character(1:4)) ||
      any(is.nan(ebfmi)) ||
      any(is.infinite(ebfmi))) {
    .stop_invalid_goal002_fit(
      "diagnostics$metrics$ebfmi_by_chain is invalid."
    )
  }
  details <- diagnostics$details
  names_match <- if (length(diagnostics$reasons) == 0L) {
    length(details) == 0L
  } else {
    identical(names(details), diagnostics$reasons)
  }
  if (!is.character(details) ||
      anyNA(details) ||
      any(!nzchar(details)) ||
      !names_match) {
    .stop_invalid_goal002_fit(
      "diagnostics$details must describe every reason exactly once."
    )
  }
  TRUE
}

.goal002_monitored_variables <- function(data) {
  validate_flexirich_g_data(data)
  C <- data$stan_data$C
  J <- data$stan_data$J
  zero_candidates <- which(data$stan_data$detected_ever == 0L)
  c(
    "omega",
    "mu_alpha",
    "sigma_alpha",
    "sigma_camera",
    sprintf("alpha[%d]", seq_len(C)),
    sprintf("camera_effect[%d]", seq_len(J)),
    sprintf("q_member[%d]", zero_candidates),
    .goal002_richness_variables
  )
}

.goal002_diagnostic_inputs <- function(fit, data, sampler_profile) {
  requested_monitored <- .goal002_monitored_variables(data)
  base_monitored <- setdiff(
    requested_monitored,
    .goal002_richness_variables
  )
  summary <- fit$summary(variables = base_monitored)
  statistics <- tibble::as_tibble(summary)[
    c("variable", "rhat", "ess_bulk", "ess_tail")
  ]
  C <- data$stan_data$C
  q_names <- sprintf("q_member[%d]", seq_len(C))
  q_draws <- posterior::as_draws_df(
    fit$draws(variables = q_names)
  )
  q_frame <- as.data.frame(q_draws)
  richness <- .goal002_build_richness_diagnostics(
    q_draws = as.matrix(q_frame[q_names]),
    detected_ever = data$stan_data$detected_ever,
    chain = q_frame$.chain,
    iteration = q_frame$.iteration,
    expected_iterations = sampler_profile$iter_sampling
  )
  monitored <- base_monitored
  if (identical(richness$metadata$status, "estimated")) {
    monitored <- c(monitored, .goal002_richness_variables)
    statistics <- dplyr::bind_rows(
      statistics,
      richness$metadata$row_diagnostics
    )
  }

  raw_sampler <- fit$sampler_diagnostics(
    inc_warmup = FALSE,
    format = "df"
  )
  sampler_fields <- c(
    "divergent__",
    "treedepth__",
    "energy__",
    ".chain",
    ".iteration"
  )
  sampler_draws <- tibble::as_tibble(
    as.data.frame(raw_sampler)[sampler_fields]
  )

  list(
    summary = list(
      monitored_variables = monitored,
      statistics = statistics,
      richness = richness$metadata
    ),
    sampler = list(
      expected_chains = sampler_profile$chains,
      expected_iterations = sampler_profile$iter_sampling,
      max_treedepth = sampler_profile$max_treedepth,
      draws = sampler_draws
    )
  )
}

validate_goal002_attempt <- function(attempt) {
  if (!is.list(attempt) ||
      !identical(names(attempt), .goal002_attempt_fields)) {
    .stop_invalid_goal002_fit(
      "attempt has an invalid component contract."
    )
  }
  if (!attempt$attempt_id %in% c("primary", "rescue") ||
      length(attempt$attempt_id) != 1L ||
      is.na(attempt$attempt_id)) {
    .stop_invalid_goal002_fit(
      "attempt$attempt_id must be primary or rescue."
    )
  }
  expected_sampler <- if (identical(attempt$attempt_id, "primary")) {
    "primary-sampler-v1"
  } else {
    "rescue-sampler-v1"
  }
  if (!identical(attempt$sampler_profile_id, expected_sampler)) {
    .stop_invalid_goal002_fit(
      "attempt$sampler_profile_id does not match attempt_id."
    )
  }
  .goal002_assert_integer(
    attempt$seed,
    "attempt$seed",
    lower = 0L,
    upper = .Machine$integer.max
  )
  if (!is.character(attempt$started_at_utc) ||
      length(attempt$started_at_utc) != 1L ||
      is.na(attempt$started_at_utc) ||
      !grepl(
        "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$",
        attempt$started_at_utc
      )) {
    .stop_invalid_goal002_fit(
      "attempt$started_at_utc must be an ISO-8601 UTC timestamp."
    )
  }
  if (!is.numeric(attempt$elapsed_seconds) ||
      length(attempt$elapsed_seconds) != 1L ||
      is.na(attempt$elapsed_seconds) ||
      !is.finite(attempt$elapsed_seconds) ||
      attempt$elapsed_seconds < 0) {
    .stop_invalid_goal002_fit(
      "attempt$elapsed_seconds must be one non-negative finite number."
    )
  }
  .goal002_assert_hash(
    attempt$model_source_hash,
    "attempt$model_source_hash"
  )
  .goal002_assert_hash(attempt$data_hash, "attempt$data_hash")
  for (field in c(
    "prior_profile",
    "R_version",
    "cmdstanr_version",
    "cmdstan_version",
    "compiler"
  )) {
    .goal002_assert_text(
      attempt[[field]],
      paste0("attempt$", field)
    )
  }
  if (!is.character(attempt$output_files) ||
      anyNA(attempt$output_files) ||
      any(!nzchar(attempt$output_files)) ||
      anyDuplicated(attempt$output_files)) {
    .stop_invalid_goal002_fit(
      "attempt$output_files must contain unique non-empty paths."
    )
  }
  validate_goal002_diagnostics(attempt$diagnostics)
  .goal002_assert_flag(attempt$clean, "attempt$clean")
  if (!identical(attempt$clean, attempt$diagnostics$clean)) {
    .stop_invalid_goal002_fit(
      "attempt$clean must agree with attempt$diagnostics$clean."
    )
  }
  if (attempt$clean &&
      !identical(
        attempt$diagnostics$generated_richness$status,
        "passed"
      )) {
    .stop_invalid_goal002_fit(
      "A clean attempt must pass the generated-richness contract."
    )
  }
  if (attempt$clean && length(attempt$output_files) != 4L) {
    .stop_invalid_goal002_fit(
      "A clean attempt must retain exactly four CmdStan CSV files."
    )
  }
  TRUE
}

resolve_goal002_attempts <- function(primary, rescue = NULL) {
  validate_goal002_attempt(primary)
  if (!identical(primary$attempt_id, "primary")) {
    .stop_invalid_goal002_fit(
      "primary must have attempt_id = 'primary'."
    )
  }
  if (!is.null(rescue)) {
    validate_goal002_attempt(rescue)
    if (!identical(rescue$attempt_id, "rescue")) {
      .stop_invalid_goal002_fit(
        "rescue must have attempt_id = 'rescue'."
      )
    }
    if (primary$clean) {
      .stop_invalid_goal002_fit(
        "A clean primary attempt must not have a rescue attempt."
      )
    }
  }

  if (primary$clean) {
    terminal_status <- "primary_clean"
    rescue_used <- FALSE
    terminal_attempt_id <- "primary"
    attempts <- list(primary = primary)
  } else if (is.null(rescue)) {
    terminal_status <- "final_nonclean"
    rescue_used <- FALSE
    terminal_attempt_id <- "primary"
    attempts <- list(primary = primary)
  } else {
    terminal_status <- if (rescue$clean) {
      "rescue_clean"
    } else {
      "final_nonclean"
    }
    rescue_used <- TRUE
    terminal_attempt_id <- "rescue"
    attempts <- list(primary = primary, rescue = rescue)
  }

  list(
    terminal_status = terminal_status,
    rescue_used = rescue_used,
    terminal_attempt_id = terminal_attempt_id,
    attempts = attempts
  )
}

.goal002_draw_variables <- function(data) {
  C <- data$stan_data$C
  J <- data$stan_data$J
  G <- data$stan_data$G
  c(
    "omega",
    "mu_alpha",
    "sigma_alpha",
    "sigma_camera",
    sprintf("alpha[%d]", seq_len(C)),
    sprintf("camera_effect[%d]", seq_len(J)),
    sprintf("member_ll[%d]", seq_len(C)),
    sprintf("q_member[%d]", seq_len(C)),
    sprintf("g_member[%d]", seq_len(C)),
    "S_grid",
    "expected_richness",
    sprintf("y_rep[%d]", seq_len(G))
  )
}

.goal002_attempt_output_files <- function(fit, attempt_dir) {
  files <- sort(fit$output_files())
  if (length(files) != 4L ||
      anyNA(files) ||
      any(!file.exists(files)) ||
      anyDuplicated(files)) {
    return(list(
      valid = FALSE,
      files = character(),
      detail = "CmdStan did not retain exactly four unique CSV files."
    ))
  }
  attempt_dir <- normalizePath(attempt_dir, mustWork = TRUE)
  absolute <- vapply(
    files,
    normalizePath,
    character(1),
    mustWork = TRUE
  )
  if (any(!startsWith(
    absolute,
    paste0(attempt_dir, .Platform$file.sep)
  ))) {
    return(list(
      valid = FALSE,
      files = character(),
      detail = "A CmdStan CSV escaped its immutable attempt directory."
    ))
  }
  list(
    valid = TRUE,
    files = .goal002_relative_paths(absolute),
    detail = ""
  )
}

.goal002_partial_output_files <- function(attempt_dir) {
  files <- sort(list.files(
    attempt_dir,
    pattern = "\\.csv$",
    full.names = TRUE
  ))
  files <- files[file.exists(files)]
  .goal002_relative_paths(files)
}

.goal002_attempt_metadata <- function(
  attempt_id,
  sampler_profile,
  seed,
  started_at_utc,
  elapsed_seconds,
  model_source_hash,
  data_hash,
  prior_profile,
  compiler,
  output_files,
  diagnostics
) {
  cmdstan_status <- check_goal002_cmdstan()
  result <- list(
    attempt_id = attempt_id,
    sampler_profile_id = sampler_profile$profile_id,
    seed = seed,
    started_at_utc = started_at_utc,
    elapsed_seconds = elapsed_seconds,
    model_source_hash = model_source_hash,
    data_hash = data_hash,
    prior_profile = prior_profile$profile_id,
    R_version = as.character(getRversion()),
    cmdstanr_version = as.character(
      utils::packageVersion("cmdstanr")
    ),
    cmdstan_version = cmdstan_status$installed_version,
    compiler = compiler,
    output_files = output_files,
    diagnostics = diagnostics,
    clean = diagnostics$clean
  )
  validate_goal002_attempt(result)
  result
}

.goal002_run_attempt <- function(
  model,
  stan_data,
  data,
  prior_profile,
  sampler_profile,
  seed,
  attempt_id,
  attempt_dir,
  model_source_hash,
  compiler
) {
  if (file.exists(attempt_dir) || dir.exists(attempt_dir)) {
    .stop_invalid_goal002_fit(
      "Attempt directory already exists; refusing overwrite."
    )
  }
  if (!dir.create(
    attempt_dir,
    recursive = TRUE,
    showWarnings = FALSE
  )) {
    .stop_invalid_goal002_fit(
      "Could not create the immutable attempt directory."
    )
  }

  started_at_utc <- format(
    Sys.time(),
    "%Y-%m-%dT%H:%M:%SZ",
    tz = "UTC"
  )
  start_time <- proc.time()[["elapsed"]]
  sampling_error <- NULL
  fit <- tryCatch(
    model$sample(
      data = stan_data,
      seed = seed,
      chains = sampler_profile$chains,
      parallel_chains = sampler_profile$parallel_chains,
      iter_warmup = sampler_profile$iter_warmup,
      iter_sampling = sampler_profile$iter_sampling,
      adapt_delta = sampler_profile$adapt_delta,
      max_treedepth = sampler_profile$max_treedepth,
      refresh = sampler_profile$refresh,
      save_warmup = FALSE,
      sig_figs = 18L,
      show_messages = FALSE,
      diagnostics = NULL,
      output_dir = attempt_dir,
      output_basename = paste0("flexirich-g-", attempt_id)
    ),
    error = function(e) {
      sampling_error <<- conditionMessage(e)
      NULL
    }
  )
  elapsed_seconds <- as.numeric(
    proc.time()[["elapsed"]] - start_time
  )

  if (is.null(fit)) {
    diagnostics <- .goal002_failed_diagnostics(
      "sampling_error",
      sampling_error
    )
    metadata <- .goal002_attempt_metadata(
      attempt_id,
      sampler_profile,
      seed,
      started_at_utc,
      elapsed_seconds,
      model_source_hash,
      data$data_hash,
      prior_profile,
      compiler,
      .goal002_partial_output_files(attempt_dir),
      diagnostics
    )
    return(list(metadata = metadata, draws = NULL))
  }

  extraction_error <- NULL
  diagnostic_inputs <- tryCatch(
    .goal002_diagnostic_inputs(fit, data, sampler_profile),
    error = function(e) {
      extraction_error <<- conditionMessage(e)
      NULL
    }
  )
  diagnostics <- if (is.null(diagnostic_inputs)) {
    .goal002_failed_diagnostics(
      "diagnostic_extraction_error",
      extraction_error
    )
  } else {
    classify_goal002_diagnostics(
      diagnostic_inputs$summary,
      diagnostic_inputs$sampler,
      goal002_diagnostic_thresholds()
    )
  }

  output_result <- .goal002_attempt_output_files(fit, attempt_dir)
  if (!output_result$valid) {
    diagnostics <- .goal002_append_diagnostic_failure(
      diagnostics,
      "output_files_error",
      output_result$detail
    )
  }

  draw_error <- NULL
  draws <- tryCatch(
    posterior::as_draws_matrix(fit$draws(
      variables = .goal002_draw_variables(data)
    )),
    error = function(e) {
      draw_error <<- conditionMessage(e)
      NULL
    }
  )
  if (is.null(draws) ||
      nrow(draws) == 0L ||
      !all(.goal002_draw_variables(data) %in% colnames(draws))) {
    diagnostics <- .goal002_append_diagnostic_failure(
      diagnostics,
      "draw_extraction_error",
      if (is.null(draw_error)) {
        "Required posterior draw columns are missing."
      } else {
        draw_error
      }
    )
    draws <- NULL
  } else {
    generated_richness <- .goal002_check_generated_richness(
      draws,
      data$stan_data$detected_ever
    )
    diagnostics <- .goal002_attach_generated_richness(
      diagnostics,
      generated_richness
    )
  }
  if (!diagnostics$clean) {
    draws <- NULL
  }

  metadata <- .goal002_attempt_metadata(
    attempt_id,
    sampler_profile,
    seed,
    started_at_utc,
    elapsed_seconds,
    model_source_hash,
    data$data_hash,
    prior_profile,
    compiler,
    if (output_result$valid) output_result$files else character(),
    diagnostics
  )
  list(metadata = metadata, draws = draws)
}

validate_flexirich_g_fit <- function(fit) {
  if (!is.list(fit) ||
      !identical(class(fit), c("flexirich_g_fit", "list")) ||
      !identical(names(attributes(fit)), c("names", "class")) ||
      !identical(names(fit), .goal002_fit_fields)) {
    .stop_invalid_goal002_fit(
      "fit must be a canonical flexirich_g_fit object."
    )
  }
  if (!is.character(fit$terminal_status) ||
      length(fit$terminal_status) != 1L ||
      is.na(fit$terminal_status) ||
      !fit$terminal_status %in% .goal002_terminal_statuses) {
    .stop_invalid_goal002_fit(
      "fit$terminal_status is invalid."
    )
  }
  .goal002_assert_flag(fit$rescue_used, "fit$rescue_used")
  if (!fit$terminal_attempt_id %in% c("primary", "rescue") ||
      length(fit$terminal_attempt_id) != 1L ||
      is.na(fit$terminal_attempt_id)) {
    .stop_invalid_goal002_fit(
      "fit$terminal_attempt_id is invalid."
    )
  }

  for (field in c("candidate_ids", "camera_ids")) {
    values <- fit[[field]]
    if (!is.character(values) ||
        length(values) == 0L ||
        anyNA(values) ||
        any(!nzchar(values)) ||
        anyDuplicated(values)) {
      .stop_invalid_goal002_fit(
        paste0("fit$", field, " is invalid.")
      )
    }
  }
  valid_detected <- is.integer(fit$detected_ever) &&
    length(fit$detected_ever) == length(fit$candidate_ids) &&
    !anyNA(fit$detected_ever) &&
    all(fit$detected_ever %in% c(0L, 1L))
  if (!valid_detected) {
    .stop_invalid_goal002_fit(
      "fit$detected_ever must be an integer candidate-level 0/1 vector."
    )
  }
  if (!tibble::is_tibble(fit$observed) ||
      !tibble::is_tibble(fit$grouped)) {
    .stop_invalid_goal002_fit(
      "fit observation components must be tibbles."
    )
  }
  .goal002_assert_hash(fit$data_hash, "fit$data_hash")
  prior_profile <- validate_goal002_profile(
    fit$prior_profile,
    type = "prior"
  )
  if (!identical(prior_profile, fit$prior_profile)) {
    .stop_invalid_goal002_fit(
      "fit$prior_profile is not canonical."
    )
  }
  .goal002_assert_hash(
    fit$model_source_hash,
    "fit$model_source_hash"
  )

  if (!is.list(fit$attempts) ||
      !identical(
        names(fit$attempts),
        if (fit$rescue_used) c("primary", "rescue") else "primary"
      )) {
    .stop_invalid_goal002_fit(
      "fit$attempts do not match rescue_used."
    )
  }
  lapply(fit$attempts, validate_goal002_attempt)
  resolution <- resolve_goal002_attempts(
    fit$attempts$primary,
    fit$attempts$rescue
  )
  if (!identical(fit$terminal_status, resolution$terminal_status) ||
      !identical(fit$rescue_used, resolution$rescue_used) ||
      !identical(
        fit$terminal_attempt_id,
        resolution$terminal_attempt_id
      )) {
    .stop_invalid_goal002_fit(
      "fit terminal fields disagree with the immutable attempts."
    )
  }

  attempt_values <- unname(fit$attempts)
  for (attempt in attempt_values) {
    if (!identical(attempt$data_hash, fit$data_hash) ||
        !identical(
          attempt$model_source_hash,
          fit$model_source_hash
        ) ||
        !identical(
          attempt$prior_profile,
          fit$prior_profile$profile_id
        )) {
      .stop_invalid_goal002_fit(
        "fit provenance disagrees with an attempt record."
      )
    }
  }

  if (identical(fit$terminal_status, "final_nonclean")) {
    if (!is.null(fit$draws)) {
      .stop_invalid_goal002_fit(
        "A final_nonclean fit must not expose posterior draws."
      )
    }
  } else {
    if (!inherits(fit$draws, "draws_matrix") ||
        nrow(fit$draws) == 0L ||
        !all(c(
          "omega",
          "mu_alpha",
          "sigma_alpha",
          "sigma_camera",
          "S_grid",
          "expected_richness"
        ) %in% colnames(fit$draws))) {
      .stop_invalid_goal002_fit(
        "A clean fit must expose the contracted posterior draws."
      )
    }
    generated_richness <- .goal002_check_generated_richness(
      fit$draws,
      fit$detected_ever
    )
    if (!identical(generated_richness$status, "passed")) {
      .stop_invalid_goal002_fit(
        "A clean fit violates the generated-richness draw contract."
      )
    }
  }
  TRUE
}

fit_flexirich_g <- function(
  data,
  seed,
  prior_profile,
  output_dir,
  allow_rescue = TRUE
) {
  validate_flexirich_g_data(data)
  seed <- .goal002_assert_integer(
    seed,
    "seed",
    lower = 0L,
    upper = .Machine$integer.max - 500000L
  )
  prior_profile <- validate_goal002_profile(
    prior_profile,
    type = "prior"
  )
  allow_rescue <- .goal002_assert_flag(
    allow_rescue,
    "allow_rescue"
  )
  output_dir <- .goal002_output_directory(output_dir)

  sampler_profiles <- goal002_sampler_profiles()
  sampler_profiles <- lapply(
    sampler_profiles,
    validate_goal002_profile,
    type = "sampler"
  )
  model <- compile_flexirich_g_model(force_recompile = FALSE)
  model_source_hash <- .goal002_source_hash()
  compiler <- .goal002_compiler_identity()
  stan_data <- c(
    data$stan_data,
    prior_profile[setdiff(names(prior_profile), "profile_id")]
  )

  if (!dir.create(
    output_dir,
    recursive = TRUE,
    showWarnings = FALSE
  )) {
    .stop_invalid_goal002_fit(
      "Could not create output_dir."
    )
  }
  primary_result <- .goal002_run_attempt(
    model = model,
    stan_data = stan_data,
    data = data,
    prior_profile = prior_profile,
    sampler_profile = sampler_profiles$primary,
    seed = seed,
    attempt_id = "primary",
    attempt_dir = file.path(output_dir, "primary"),
    model_source_hash = model_source_hash,
    compiler = compiler
  )

  rescue_result <- NULL
  if (!primary_result$metadata$clean && allow_rescue) {
    rescue_result <- .goal002_run_attempt(
      model = model,
      stan_data = stan_data,
      data = data,
      prior_profile = prior_profile,
      sampler_profile = sampler_profiles$rescue,
      seed = seed + 500000L,
      attempt_id = "rescue",
      attempt_dir = file.path(output_dir, "rescue"),
      model_source_hash = model_source_hash,
      compiler = compiler
    )
  }

  resolution <- resolve_goal002_attempts(
    primary_result$metadata,
    if (is.null(rescue_result)) NULL else rescue_result$metadata
  )
  terminal_draws <- if (identical(
    resolution$terminal_status,
    "primary_clean"
  )) {
    primary_result$draws
  } else if (identical(
    resolution$terminal_status,
    "rescue_clean"
  )) {
    rescue_result$draws
  } else {
    NULL
  }

  result <- list(
    terminal_status = resolution$terminal_status,
    rescue_used = resolution$rescue_used,
    terminal_attempt_id = resolution$terminal_attempt_id,
    candidate_ids = data$candidate_ids,
    camera_ids = data$camera_ids,
    detected_ever = data$stan_data$detected_ever,
    observed = data$observed,
    grouped = data$grouped,
    data_hash = data$data_hash,
    prior_profile = prior_profile,
    model_source_hash = model_source_hash,
    attempts = resolution$attempts,
    draws = terminal_draws
  )
  class(result) <- c("flexirich_g_fit", "list")
  validate_flexirich_g_fit(result)
  result
}
