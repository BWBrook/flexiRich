goal002r_paired_cases <- function() {
  defaults <- flexirich_sim_config()
  tibble::tibble(
    case_id = c(
      "small-easy",
      "small-unseen",
      "standard-short-low",
      "standard-short-high",
      "standard-long-medium",
      "historical-hard"
    ),
    purpose = c(
      "basic equivalence with substantial detection",
      "short low-rate unseen-heavy tail",
      "Goal 002 scale with low richness",
      "Goal 002 scale with high richness",
      "four-year-scale reference",
      "former non-clean membership-sensitivity case"
    ),
    candidate_pool_size = c(8L, 8L, 30L, 30L, 30L, 30L),
    true_richness = c(4L, 6L, 8L, 27L, 20L, 20L),
    n_cameras = c(3L, 3L, 9L, 9L, 9L, 9L),
    n_occasions = c(52L, 13L, 26L, 26L, 208L, 208L),
    simulation_seed = c(940001L, 940006L, 940003L, 940004L, 940005L, 320020503L),
    baseline_fit_seed = c(240001L, 240002L, 240003L, 240004L, 240005L, 520020503L),
    collapsed_fit_seed = c(250001L, 250002L, 250003L, 250004L, 250005L, 720020503L),
    prior_key = c(rep("primary", 5L), "sensitivity_membership"),
    mean_log_rate = c(
      log(0.004),
      log(0.001),
      rep(defaults$mean_log_rate, 4L)
    ),
    sd_log_rate = c(
      0.8,
      0.8,
      rep(defaults$sd_log_rate, 4L)
    ),
    sd_camera = c(
      0.25,
      0.25,
      rep(defaults$sd_camera, 4L)
    ),
    initial_operating_prob = rep(defaults$initial_operating_prob, 6L),
    daily_failure_prob = c(0, 0, rep(defaults$daily_failure_prob, 4L)),
    daily_repair_prob = c(1, 1, rep(defaults$daily_repair_prob, 4L)),
    historical_stress = c(rep(FALSE, 5L), TRUE)
  )
}

goal002r_prepare_paired_case <- function(case) {
  expected_columns <- names(goal002r_paired_cases())
  if (!tibble::is_tibble(case) || nrow(case) != 1L ||
      !identical(names(case), expected_columns)) {
    .goal002r_stop("case must be one canonical Goal002R paired-comparison row.")
  }
  simulation <- simulate_flexirich_g(flexirich_sim_config(
    candidate_pool_size = case$candidate_pool_size,
    true_richness = case$true_richness,
    n_cameras = case$n_cameras,
    n_occasions = case$n_occasions,
    mean_log_rate = case$mean_log_rate,
    sd_log_rate = case$sd_log_rate,
    sd_camera = case$sd_camera,
    initial_operating_prob = case$initial_operating_prob,
    daily_failure_prob = case$daily_failure_prob,
    daily_repair_prob = case$daily_repair_prob,
    seed = case$simulation_seed
  ))
  data <- sim_to_flexirich_g_data(simulation)
  collapsed_data <- prepare_flexirich_g_collapsed_data(data)
  if (!identical(data$data_hash, collapsed_data$source_data_hash)) {
    .goal002r_stop("Original and collapsed paths do not share canonical input data.")
  }
  list(
    specification = case,
    simulation = simulation,
    data = data,
    collapsed_data = collapsed_data
  )
}

goal002r_strict_health_thresholds <- function() {
  thresholds <- goal002_diagnostic_thresholds()
  do.call(goal002r_default_health_thresholds, thresholds)
}

.goal002r_collapsed_sampler <- function(profile) {
  profile <- validate_goal002_profile(profile, type = "sampler")
  do.call(
    goal002r_default_sampler,
    profile[setdiff(names(profile), "profile_id")]
  )
}

.goal002r_run_collapsed_attempt <- function(
  data,
  seed,
  prior_profile,
  sampler,
  output_dir,
  project_root,
  fit_function
) {
  start <- proc.time()[["elapsed"]]
  error_message <- NULL
  fit <- tryCatch(
    fit_function(
      data = data,
      seed = seed,
      prior_profile = prior_profile,
      sampler = sampler,
      quadrature_order = goal002r_contract()$quadrature_default,
      project_root = project_root,
      output_dir = output_dir,
      force_recompile = FALSE,
      health_thresholds = goal002r_strict_health_thresholds()
    ),
    error = function(error) {
      error_message <<- conditionMessage(error)
      NULL
    }
  )
  list(
    clean = !is.null(fit),
    elapsed_seconds = as.numeric(proc.time()[["elapsed"]] - start),
    error = error_message,
    fit = fit
  )
}

goal002r_run_collapsed_path <- function(
  data,
  seed,
  prior_profile,
  output_dir,
  project_root = goal002r_project_root(),
  fit_function = goal002r_fit
) {
  .goal002r_validate_collapsed(data)
  seed <- as.integer(.goal002r_scalar(seed, "seed", lower = 1))
  prior_profile <- validate_goal002_profile(prior_profile, type = "prior")
  samplers <- goal002_sampler_profiles()
  primary <- .goal002r_run_collapsed_attempt(
    data,
    seed,
    prior_profile,
    .goal002r_collapsed_sampler(samplers$primary),
    file.path(output_dir, "primary"),
    project_root,
    fit_function
  )
  rescue <- NULL
  if (!primary$clean) {
    rescue <- .goal002r_run_collapsed_attempt(
      data,
      seed + 500000L,
      prior_profile,
      .goal002r_collapsed_sampler(samplers$rescue),
      file.path(output_dir, "rescue"),
      project_root,
      fit_function
    )
  }
  terminal_clean <- primary$clean || isTRUE(rescue$clean)
  terminal_status <- if (primary$clean) {
    "primary_clean"
  } else if (isTRUE(rescue$clean)) {
    "rescue_clean"
  } else {
    "final_nonclean"
  }
  list(
    terminal_status = terminal_status,
    primary_clean = primary$clean,
    terminal_clean = terminal_clean,
    rescue_used = !is.null(rescue),
    primary_seconds = primary$elapsed_seconds,
    terminal_fit = if (primary$clean) primary$fit else rescue$fit,
    attempts = list(primary = primary, rescue = rescue)
  )
}

goal002r_run_baseline_path <- function(
  data,
  seed,
  prior_profile,
  output_dir,
  fit_function = fit_flexirich_g
) {
  validate_flexirich_g_data(data)
  seed <- .goal002r_scalar(seed, "seed", lower = 1)
  if (seed != trunc(seed) || seed > .Machine$integer.max) {
    .goal002r_stop("seed must be one representable positive integer.")
  }
  seed <- as.integer(seed)
  prior_profile <- validate_goal002_profile(prior_profile, type = "prior")
  fit <- fit_function(
    data = data,
    seed = seed,
    prior_profile = prior_profile,
    output_dir = output_dir,
    allow_rescue = TRUE
  )
  terminal_clean <- fit$terminal_status %in% c(
    "primary_clean",
    "rescue_clean"
  )
  list(
    terminal_status = fit$terminal_status,
    primary_clean = isTRUE(fit$attempts$primary$clean),
    terminal_clean = terminal_clean,
    rescue_used = isTRUE(fit$rescue_used),
    primary_seconds = fit$attempts$primary$elapsed_seconds,
    terminal_fit = if (terminal_clean) fit else NULL,
    attempts = fit$attempts
  )
}

.goal002r_attempt_error <- function(attempt) {
  if (is.null(attempt)) return(NA_character_)
  if (!is.null(attempt$error)) {
    return(if (is.null(attempt$error)) NA_character_ else attempt$error)
  }
  reasons <- attempt$diagnostics$reasons
  if (is.null(reasons) || length(reasons) == 0L) NA_character_ else
    paste(reasons, collapse = "; ")
}

.goal002r_terminal_health <- function(path, model) {
  fields <- c(
    "divergences",
    "treedepth_hits",
    "min_ebfmi",
    "max_rhat",
    "min_bulk_ess",
    "min_tail_ess"
  )
  empty <- stats::setNames(rep(NA_real_, length(fields)), fields)
  if (!isTRUE(path$terminal_clean) || is.null(path$terminal_fit)) return(empty)
  metrics <- if (identical(model, "baseline")) {
    fit <- path$terminal_fit
    fit$attempts[[fit$terminal_attempt_id]]$diagnostics$metrics
  } else {
    path$terminal_fit$health$metrics
  }
  if (is.null(metrics) || !all(fields %in% names(metrics))) return(empty)
  stats::setNames(as.numeric(unlist(metrics[fields])), fields)
}

goal002r_paired_case_result <- function(prepared, baseline, collapsed) {
  if (!is.list(prepared) || !is.list(baseline) || !is.list(collapsed)) {
    .goal002r_stop("Prepared data and paired fit paths must be lists.")
  }
  specification <- prepared$specification
  truth <- prepared$simulation$truth
  baseline_health <- .goal002r_terminal_health(baseline, "baseline")
  collapsed_health <- .goal002r_terminal_health(collapsed, "collapsed")
  tibble::tibble(
    case_id = specification$case_id,
    purpose = specification$purpose,
    candidate_pool_size = specification$candidate_pool_size,
    true_richness = truth$true_richness,
    camera_count = specification$n_cameras,
    n_occasions = specification$n_occasions,
    simulation_seed = specification$simulation_seed,
    baseline_fit_seed = specification$baseline_fit_seed,
    collapsed_fit_seed = specification$collapsed_fit_seed,
    prior_key = specification$prior_key,
    historical_stress = specification$historical_stress,
    observed_richness = truth$observed_richness,
    total_detections = truth$total_detections,
    baseline_data_hash = prepared$data$data_hash,
    collapsed_source_data_hash = prepared$collapsed_data$source_data_hash,
    data_hash_identical = identical(
      prepared$data$data_hash,
      prepared$collapsed_data$source_data_hash
    ),
    supported = truth$observed_richness > 0L,
    baseline_terminal_status = baseline$terminal_status,
    baseline_primary_clean = baseline$primary_clean,
    baseline_terminal_clean = baseline$terminal_clean,
    baseline_rescue_used = baseline$rescue_used,
    baseline_primary_seconds = baseline$primary_seconds,
    baseline_primary_error = .goal002r_attempt_error(
      baseline$attempts$primary
    ),
    baseline_divergences = baseline_health[["divergences"]],
    baseline_treedepth_hits = baseline_health[["treedepth_hits"]],
    baseline_min_ebfmi = baseline_health[["min_ebfmi"]],
    baseline_max_rhat = baseline_health[["max_rhat"]],
    baseline_min_bulk_ess = baseline_health[["min_bulk_ess"]],
    baseline_min_tail_ess = baseline_health[["min_tail_ess"]],
    collapsed_terminal_status = collapsed$terminal_status,
    collapsed_primary_clean = collapsed$primary_clean,
    collapsed_terminal_clean = collapsed$terminal_clean,
    collapsed_rescue_used = collapsed$rescue_used,
    collapsed_primary_seconds = collapsed$primary_seconds,
    collapsed_primary_error = .goal002r_attempt_error(
      collapsed$attempts$primary
    ),
    collapsed_divergences = collapsed_health[["divergences"]],
    collapsed_treedepth_hits = collapsed_health[["treedepth_hits"]],
    collapsed_min_ebfmi = collapsed_health[["min_ebfmi"]],
    collapsed_max_rhat = collapsed_health[["max_rhat"]],
    collapsed_min_bulk_ess = collapsed_health[["min_bulk_ess"]],
    collapsed_min_tail_ess = collapsed_health[["min_tail_ess"]]
  )
}

goal002r_compare_clean_pair <- function(
  case_id,
  candidate_pool_size,
  camera_count,
  baseline_pmf,
  collapsed_pmf,
  baseline_draws,
  collapsed_draws
) {
  pmf <- goal002r_compare_pmf(
    baseline_pmf,
    collapsed_pmf,
    candidate_pool_size
  )
  parameters <- goal002r_compare_shared_draws(
    baseline_draws,
    collapsed_draws,
    camera_count
  )
  list(
    pmf = dplyr::bind_cols(
      tibble::tibble(case_id = case_id, support_valid = TRUE),
      pmf
    ),
    parameters = dplyr::bind_cols(
      tibble::tibble(case_id = case_id),
      parameters
    )
  )
}

goal002r_check_collapsed_quadrature <- function(
  case_id,
  fit,
  data,
  n_checks = 25L
) {
  .goal002r_validate_collapsed(data)
  if (!is.character(case_id) || length(case_id) != 1L ||
      is.na(case_id) || !nzchar(case_id) ||
      !is.list(fit) || !is.matrix(fit$draws)) {
    .goal002r_stop("Quadrature-check inputs are invalid.")
  }
  n_checks <- as.integer(.goal002r_scalar(n_checks, "n_checks", lower = 1))
  if (nrow(fit$draws) < n_checks) {
    .goal002r_stop("The collapsed fit has too few draws for quadrature checks.")
  }
  camera_names <- sprintf(
    "camera_effect[%d]",
    seq_along(data$camera_ids)
  )
  required <- c("mu_alpha", "sigma_alpha", camera_names)
  if (!all(required %in% colnames(fit$draws))) {
    .goal002r_stop("The collapsed fit lacks quadrature-check variables.")
  }
  posterior_rows <- as.integer(round(seq(
    1,
    nrow(fit$draws),
    length.out = n_checks
  )))
  if (anyDuplicated(posterior_rows)) {
    .goal002r_stop("Even posterior-row selection produced duplicates.")
  }
  rule <- goal002r_gauss_hermite_rule(
    goal002r_contract()$quadrature_default
  )
  dplyr::bind_rows(lapply(seq_along(posterior_rows), function(index) {
    row <- posterior_rows[[index]]
    camera_effect <- stats::setNames(
      as.numeric(fit$draws[row, camera_names]),
      data$camera_ids
    )
    quadrature <- goal002r_log_m0(
      data$zero_history,
      mu_alpha = fit$draws[row, "mu_alpha"],
      sigma_alpha = fit$draws[row, "sigma_alpha"],
      camera_effect = camera_effect,
      rule = rule
    )
    reference <- goal002r_reference_log_m0(
      data$zero_history,
      mu_alpha = fit$draws[row, "mu_alpha"],
      sigma_alpha = fit$draws[row, "sigma_alpha"],
      camera_effect = camera_effect
    )$log_m0
    absolute_error <- abs(quadrature - reference)
    tibble::tibble(
      case_id = case_id,
      draw_index = as.integer(index),
      posterior_row = row,
      log_m0_quadrature = quadrature,
      log_m0_reference = reference,
      absolute_error = absolute_error,
      passed = is.finite(absolute_error) && absolute_error <= 1e-8
    )
  }))
}

goal002r_write_paired_outputs <- function(evidence, output_dir) {
  required <- c(
    "case_results",
    "pmf_results",
    "parameter_results",
    "quadrature_results",
    "decision"
  )
  if (!is.list(evidence) || !identical(names(evidence), required) ||
      !is.list(evidence$decision) ||
      !evidence$decision$decision %in% c("RETAIN", "REVISE", "REJECT") ||
      !tibble::is_tibble(evidence$decision$criteria)) {
    .goal002r_stop("Paired-comparison evidence has an invalid output contract.")
  }
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  output_dir <- normalizePath(output_dir, mustWork = TRUE)
  paths <- c(
    case_results = file.path(output_dir, "case-results.csv"),
    pmf_results = file.path(output_dir, "pmf-fidelity.csv"),
    parameter_results = file.path(output_dir, "parameter-fidelity.csv"),
    quadrature_results = file.path(output_dir, "quadrature-checks.csv"),
    decision_criteria = file.path(output_dir, "decision-criteria.csv"),
    decision = file.path(output_dir, "decision.txt")
  )
  utils::write.csv(evidence$case_results, paths[["case_results"]], row.names = FALSE)
  utils::write.csv(evidence$pmf_results, paths[["pmf_results"]], row.names = FALSE)
  utils::write.csv(
    evidence$parameter_results,
    paths[["parameter_results"]],
    row.names = FALSE
  )
  utils::write.csv(
    evidence$quadrature_results,
    paths[["quadrature_results"]],
    row.names = FALSE
  )
  utils::write.csv(
    evidence$decision$criteria,
    paths[["decision_criteria"]],
    row.names = FALSE
  )
  writeLines(evidence$decision$decision, paths[["decision"]])
  paths
}

.goal002r_empty_pmf_results <- function() {
  tibble::tibble(
    case_id = character(),
    support_valid = logical(),
    passed = logical()
  )
}

.goal002r_empty_parameter_results <- function() {
  tibble::tibble(
    case_id = character(),
    parameter = character(),
    passed = logical()
  )
}

.goal002r_empty_quadrature_results <- function() {
  tibble::tibble(
    case_id = character(),
    draw_index = integer(),
    passed = logical()
  )
}

.goal002r_preflight_rows <- function(prepared) {
  dplyr::bind_rows(lapply(prepared, function(case) {
    specification <- case$specification
    truth <- case$simulation$truth
    tibble::tibble(
      case_id = specification$case_id,
      candidate_pool_size = specification$candidate_pool_size,
      true_richness = truth$true_richness,
      camera_count = specification$n_cameras,
      n_occasions = specification$n_occasions,
      simulation_seed = specification$simulation_seed,
      observed_richness = truth$observed_richness,
      total_detections = truth$total_detections,
      data_hash = case$data$data_hash,
      supported = truth$observed_richness > 0L
    )
  }))
}

goal002r_run_paired_comparison <- function(
  project_root = goal002r_project_root(),
  output_dir = file.path(
    project_root,
    goal002r_contract()$output_root,
    "paired-comparison"
  )
) {
  project_root <- normalizePath(project_root, mustWork = TRUE)
  if (dir.exists(output_dir) &&
      length(list.files(output_dir, all.files = TRUE, no.. = TRUE)) > 0L) {
    .goal002r_stop("Paired-comparison output directory is not empty.")
  }
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  output_dir <- normalizePath(output_dir, mustWork = TRUE)

  cases <- goal002r_paired_cases()
  prepared <- lapply(seq_len(nrow(cases)), function(index) {
    goal002r_prepare_paired_case(cases[index, , drop = FALSE])
  })
  preflight <- .goal002r_preflight_rows(prepared)
  if (any(!preflight$supported)) {
    utils::write.csv(
      preflight,
      file.path(output_dir, "case-results.csv"),
      row.names = FALSE
    )
    .goal002r_stop(
      "A prespecified case has no detected candidate; review case-results.csv."
    )
  }

  cmdstan <- check_goal002_cmdstan(error = FALSE)
  if (!isTRUE(cmdstan$matches)) {
    .goal002r_stop(paste0(
      "CmdStan ",
      cmdstan$required_version,
      " is required for the paired comparison."
    ))
  }
  compile_flexirich_g_model(force_recompile = FALSE)
  goal002r_compile_model(
    project_root = project_root,
    force_recompile = FALSE
  )

  case_results <- list()
  pmf_results <- list()
  parameter_results <- list()
  quadrature_results <- list()
  priors <- goal002_prior_profiles()

  for (index in seq_along(prepared)) {
    current <- prepared[[index]]
    specification <- current$specification
    case_id <- specification$case_id
    prior <- priors[[specification$prior_key]]
    fit_root <- file.path(output_dir, "fits", case_id)
    baseline <- goal002r_run_baseline_path(
      current$data,
      seed = specification$baseline_fit_seed,
      prior_profile = prior,
      output_dir = file.path(fit_root, "baseline")
    )
    collapsed <- goal002r_run_collapsed_path(
      current$collapsed_data,
      seed = specification$collapsed_fit_seed,
      prior_profile = prior,
      output_dir = file.path(fit_root, "collapsed"),
      project_root = project_root
    )
    case_results[[index]] <- goal002r_paired_case_result(
      current,
      baseline,
      collapsed
    )

    if (baseline$terminal_clean && collapsed$terminal_clean) {
      comparison <- goal002r_compare_clean_pair(
        case_id = case_id,
        candidate_pool_size = specification$candidate_pool_size,
        camera_count = specification$n_cameras,
        baseline_pmf = posterior_richness_pmf(baseline$terminal_fit),
        collapsed_pmf = goal002r_summarise_fit(
          collapsed$terminal_fit
        )$richness$pmf,
        baseline_draws = baseline$terminal_fit$draws,
        collapsed_draws = collapsed$terminal_fit$draws
      )
      pmf_results[[index]] <- comparison$pmf
      parameter_results[[index]] <- comparison$parameters
    }
    if (collapsed$terminal_clean) {
      quadrature_results[[index]] <- goal002r_check_collapsed_quadrature(
        case_id,
        collapsed$terminal_fit,
        current$collapsed_data
      )
    }
  }

  case_results <- dplyr::bind_rows(case_results)
  pmf_results <- if (length(Filter(Negate(is.null), pmf_results)) == 0L) {
    .goal002r_empty_pmf_results()
  } else {
    dplyr::bind_rows(pmf_results)
  }
  parameter_results <- if (length(Filter(
      Negate(is.null), parameter_results
    )) == 0L) {
    .goal002r_empty_parameter_results()
  } else {
    dplyr::bind_rows(parameter_results)
  }
  quadrature_results <- if (length(Filter(
      Negate(is.null), quadrature_results
    )) == 0L) {
    .goal002r_empty_quadrature_results()
  } else {
    dplyr::bind_rows(quadrature_results)
  }
  decision <- goal002r_comparison_decision(
    case_results,
    pmf_results,
    parameter_results,
    quadrature_results
  )
  evidence <- list(
    case_results = case_results,
    pmf_results = pmf_results,
    parameter_results = parameter_results,
    quadrature_results = quadrature_results,
    decision = decision
  )
  paths <- goal002r_write_paired_outputs(evidence, output_dir)
  list(evidence = evidence, paths = paths)
}
