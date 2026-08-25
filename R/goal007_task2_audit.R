.goal007_audit_read_csv <- function(path) {
  tibble::as_tibble(utils::read.csv(
    path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = c("", "NA")
  ))
}

.goal007_audit_key <- function(data, fields) {
  do.call(paste, c(data[fields], sep = "\r"))
}

.goal007_audit_validate_evidence <- function(contract, status, recovery) {
  expected <- contract$task2_fits |>
    dplyr::left_join(
      contract$task2_datasets[c(
        "dataset_id", "profile_id", "screen_role", "replicate"
      )],
      by = "dataset_id"
    )
  status_fields <- c(
    "fit_id", "dataset_id", "model_id", "profile_id", "screen_role"
  )
  recovery_fields <- c(status_fields, "encounter_class")
  expected_recovery <- tidyr::crossing(
    expected[status_fields],
    encounter_class = c("routine", "occasional")
  )
  valid <- inherits(status, "data.frame") &&
    inherits(recovery, "data.frame") &&
    nrow(status) == 180L && nrow(recovery) == 360L &&
    all(c(status_fields, "terminal_clean", "artifact_pass") %in% names(status)) &&
    all(c(
      recovery_fields, "generating_location", "finite_location",
      "posterior_median", "lower_90", "upper_90", "generator_error",
      "finite_error", "generator_covered_90", "terminal_clean"
    ) %in% names(recovery)) &&
    !anyDuplicated(status$fit_id) &&
    !anyDuplicated(.goal007_audit_key(recovery, recovery_fields)) &&
    setequal(
      .goal007_audit_key(status, status_fields),
      .goal007_audit_key(expected, status_fields)
    ) &&
    setequal(
      .goal007_audit_key(recovery, recovery_fields),
      .goal007_audit_key(expected_recovery, recovery_fields)
    ) &&
    !anyNA(status$terminal_clean) &&
    !anyNA(recovery$terminal_clean) &&
    !anyNA(recovery$generator_covered_90)
  if (!valid) {
    .goal007_stop("Goal007 Task 2 audit evidence differs from the contract.")
  }
  matched_clean <- status$terminal_clean[
    match(recovery$fit_id, status$fit_id)
  ]
  if (!identical(as.logical(recovery$terminal_clean), as.logical(matched_clean))) {
    .goal007_stop("Goal007 Task 2 status and recovery cleanliness disagree.")
  }
  candidate_artifacts <- status$artifact_pass[status$model_id != "independent"]
  baseline_artifacts <- status$artifact_pass[status$model_id == "independent"]
  if (anyNA(candidate_artifacts) || any(!is.na(baseline_artifacts))) {
    .goal007_stop("Goal007 Task 2 artifact evidence is malformed.")
  }
  invisible(TRUE)
}

.goal007_audit_catastrophic <- function(recovery, status, role) {
  selected <- recovery[recovery$screen_role == role, ]
  tail <- selected |>
    dplyr::summarise(
      tail_error = any(
        abs(generator_error) > log(3) | abs(finite_error) > log(3),
        na.rm = TRUE
      ),
      .by = dataset_id
    )
  status_selected <- status[status$screen_role == role, c(
    "dataset_id", "terminal_clean"
  )]
  tail |>
    dplyr::left_join(status_selected, by = "dataset_id") |>
    dplyr::mutate(failed = !terminal_clean | tail_error)
}

.goal007_audit_metrics <- function(status, recovery, model_id) {
  fit <- status[status$model_id == model_id, ]
  rows <- recovery[recovery$model_id == model_id, ]
  core <- rows[rows$screen_role == "core", ]
  stress <- rows[rows$screen_role == "stress", ]
  core_fit <- fit[fit$screen_role == "core", ]
  stress_fit <- fit[fit$screen_role == "stress", ]
  list(
    clean_total = sum(fit$terminal_clean),
    clean_profile = fit |>
      dplyr::summarise(value = sum(terminal_clean), .by = profile_id),
    bias_profile = core |>
      dplyr::summarise(
        value = stats::median(generator_error, na.rm = TRUE),
        .by = c(profile_id, encounter_class)
      ),
    generator_rmse = core |>
      dplyr::summarise(
        value = sqrt(mean(generator_error^2, na.rm = TRUE)),
        .by = encounter_class
      ),
    finite_rmse = core |>
      dplyr::summarise(
        value = sqrt(mean(finite_error^2, na.rm = TRUE)),
        .by = encounter_class
      ),
    coverage = core |>
      dplyr::summarise(
        value = sum(generator_covered_90),
        .by = encounter_class
      ),
    coverage_profile = core |>
      dplyr::summarise(
        value = sum(generator_covered_90),
        .by = c(profile_id, encounter_class)
      ),
    catastrophic = .goal007_audit_catastrophic(core, core_fit, "core"),
    stress_bias = stats::median(
      stress$generator_error[stress$encounter_class == "occasional"],
      na.rm = TRUE
    ),
    stress_coverage = sum(
      stress$generator_covered_90[
        stress$encounter_class == "occasional"
      ]
    ),
    stress_catastrophic = .goal007_audit_catastrophic(
      stress,
      stress_fit,
      "stress"
    ),
    artifact_total = sum(fit$artifact_pass %in% TRUE),
    artifact_profile = fit |>
      dplyr::summarise(
        value = sum(artifact_pass %in% TRUE),
        .by = profile_id
      )
  )
}

.goal007_audit_class_value <- function(table, encounter_class) {
  value <- table$value[table$encounter_class == encounter_class]
  if (length(value) != 1L) {
    .goal007_stop("Goal007 Task 2 audit class summary is incomplete.")
  }
  value
}

.goal007_audit_gate_row <- function(specification, model_id, value) {
  comparison <- specification$comparison[[1L]]
  threshold <- specification$threshold[[1L]]
  passed <- switch(
    comparison,
    at_most = value <= threshold,
    at_least = value >= threshold,
    equal = value == threshold,
    strictly_greater = value > threshold,
    .goal007_stop("Unknown Goal007 Task 2 audit comparison.")
  )
  tibble::tibble(
    stage = specification$stage,
    gate_id = specification$gate_id,
    model_id = model_id,
    value = as.numeric(value),
    threshold = threshold,
    comparison = comparison,
    numerator = if (is.finite(specification$denominator)) {
      as.numeric(value)
    } else {
      NA_real_
    },
    denominator = specification$denominator,
    passed = isTRUE(passed)
  )
}

#' Independently replay the Goal007 Task 2 gates from compact evidence
#'
#' This implementation deliberately does not call the production gate
#' evaluator or its metric helpers.
replay_goal007_task2_gates_independent <- function(
  contract,
  fit_status,
  recovery,
  prior_bridge,
  likelihood_bridge
) {
  .goal007_audit_validate_evidence(contract, fit_status, recovery)
  if (!isTRUE(prior_bridge$passed) || !isTRUE(likelihood_bridge$passed)) {
    .goal007_stop("Goal007 Task 2 deterministic bridges did not pass.")
  }
  specifications <- contract$gates[contract$gates$stage == "task2", ]
  candidates <- contract$model$candidate_selection_order
  baseline <- .goal007_audit_metrics(
    fit_status,
    recovery,
    "independent"
  )
  evaluate <- function(model_id) {
    metric <- .goal007_audit_metrics(fit_status, recovery, model_id)
    value_for <- function(gate_id) {
      switch(
        gate_id,
        "T2-transform" = prior_bridge$maximum_transform_error,
        "T2-covariance" = prior_bridge$maximum_covariance_error,
        "T2-likelihood-value" = likelihood_bridge$maximum_value_error,
        "T2-likelihood-gradient" = likelihood_bridge$maximum_gradient_error,
        "T2-clean" = metric$clean_total,
        "T2-clean-profile" = min(metric$clean_profile$value),
        "T2-routine-generator-bias" = max(abs(
          metric$bias_profile$value[
            metric$bias_profile$encounter_class == "routine"
          ]
        )),
        "T2-occasional-generator-bias" = max(abs(
          metric$bias_profile$value[
            metric$bias_profile$encounter_class == "occasional"
          ]
        )),
        "T2-routine-generator-rmse" = .goal007_audit_class_value(
          metric$generator_rmse, "routine"
        ),
        "T2-occasional-generator-rmse" = .goal007_audit_class_value(
          metric$generator_rmse, "occasional"
        ),
        "T2-routine-finite-rmse" = .goal007_audit_class_value(
          metric$finite_rmse, "routine"
        ),
        "T2-occasional-finite-rmse" = .goal007_audit_class_value(
          metric$finite_rmse, "occasional"
        ),
        "T2-routine-coverage" = .goal007_audit_class_value(
          metric$coverage, "routine"
        ),
        "T2-occasional-coverage" = .goal007_audit_class_value(
          metric$coverage, "occasional"
        ),
        "T2-profile-coverage" = min(metric$coverage_profile$value),
        "T2-catastrophic" = sum(metric$catastrophic$failed),
        "T2-rare-rmse-ratio" = max(
          .goal007_audit_class_value(metric$generator_rmse, "occasional"),
          .goal007_audit_class_value(metric$finite_rmse, "occasional")
        ) / max(
          .goal007_audit_class_value(baseline$generator_rmse, "occasional"),
          .goal007_audit_class_value(baseline$finite_rmse, "occasional")
        ),
        "T2-rare-coverage-loss" =
          .goal007_audit_class_value(baseline$coverage, "occasional") -
          .goal007_audit_class_value(metric$coverage, "occasional"),
        "T2-catastrophic-difference" =
          sum(metric$catastrophic$failed) -
          sum(baseline$catastrophic$failed),
        "T2-routine-generator-rmse-ratio" =
          .goal007_audit_class_value(metric$generator_rmse, "routine") /
          .goal007_audit_class_value(baseline$generator_rmse, "routine"),
        "T2-routine-finite-rmse-ratio" =
          .goal007_audit_class_value(metric$finite_rmse, "routine") /
          .goal007_audit_class_value(baseline$finite_rmse, "routine"),
        "T2-stress-occasional-bias" = abs(metric$stress_bias),
        "T2-stress-occasional-coverage" = metric$stress_coverage,
        "T2-stress-catastrophic" = sum(metric$stress_catastrophic$failed),
        "T2-artifact" = metric$artifact_total,
        "T2-artifact-profile" = min(metric$artifact_profile$value),
        .goal007_stop("Unknown Goal007 Task 2 audit gate.")
      )
    }
    gates <- lapply(seq_len(nrow(specifications)), function(index) {
      specification <- specifications[index, ]
      .goal007_audit_gate_row(
        specification,
        model_id,
        value_for(specification$gate_id[[1L]])
      )
    }) |>
      dplyr::bind_rows()
    list(gates = gates, metrics = metric)
  }
  candidate_results <- stats::setNames(lapply(candidates, evaluate), candidates)
  gates <- dplyr::bind_rows(lapply(candidate_results, `[[`, "gates"))
  eligibility <- gates |>
    dplyr::summarise(
      gates_passed = sum(passed),
      gates_total = dplyr::n(),
      eligible = all(passed),
      .by = model_id
    ) |>
    dplyr::mutate(selection_priority = match(model_id, candidates)) |>
    dplyr::arrange(selection_priority)
  selected <- eligibility$model_id[eligibility$eligible][1L]
  if (length(selected) == 0L || is.na(selected)) {
    selected <- NA_character_
  }
  catastrophic <- dplyr::bind_rows(lapply(candidates, function(model_id) {
    candidate_results[[model_id]]$metrics$catastrophic |>
      dplyr::mutate(model_id = model_id, .before = 1L)
  }))
  list(
    gates = gates,
    eligibility = eligibility,
    catastrophic = catastrophic,
    selected_model_id = selected,
    decision = if (is.na(selected)) "TASK2_STOP" else "TASK2_PASS"
  )
}

.goal007_audit_compare <- function(recorded, replayed, keys, fields) {
  if (nrow(recorded) != nrow(replayed) ||
      anyDuplicated(.goal007_audit_key(recorded, keys)) ||
      anyDuplicated(.goal007_audit_key(replayed, keys))) {
    return(FALSE)
  }
  recorded <- recorded[order(.goal007_audit_key(recorded, keys)), c(keys, fields)]
  replayed <- replayed[order(.goal007_audit_key(replayed, keys)), c(keys, fields)]
  isTRUE(all.equal(
    recorded,
    replayed,
    tolerance = 1e-12,
    check.attributes = FALSE
  ))
}

#' Audit one completed frozen Goal007 Task 2 run
audit_goal007_task2_results <- function(output_dir, expected_commit = NULL) {
  output_dir <- normalizePath(output_dir, mustWork = TRUE)
  result_dir <- file.path(output_dir, "results")
  metadata <- readRDS(file.path(output_dir, "run-metadata.rds"))
  if (is.null(expected_commit)) {
    expected_commit <- metadata$git_commit
  }
  root_status <- readLines(
    file.path(output_dir, "completion-status.txt"),
    warn = FALSE
  )
  result_status <- readLines(
    file.path(result_dir, "completion-status.txt"),
    warn = FALSE
  )
  status_value <- function(lines, field) {
    values <- sub(paste0("^", field, "="), "", lines[
      grepl(paste0("^", field, "="), lines)
    ])
    if (length(values) != 1L) NA_character_ else values
  }
  decision_recorded <- status_value(root_status, "status")
  selected_recorded <- status_value(root_status, "selected_model_id")
  valid <- decision_recorded %in% c("TASK2_PASS", "TASK2_STOP") &&
    identical(decision_recorded, status_value(result_status, "status")) &&
    identical(
      selected_recorded,
      status_value(result_status, "selected_model_id")
    ) &&
    identical(metadata$git_commit, expected_commit) &&
    identical(metadata$empirical_outcomes_used, FALSE) &&
    "empirical_outcomes_used=false" %in% root_status &&
    "empirical_outcomes_used=false" %in% result_status &&
    !file.exists(file.path(output_dir, "execution-stop.txt"))
  if (!valid) {
    .goal007_stop("Goal007 Task 2 completed-run metadata are invalid.")
  }
  .goal007_task2_validate_manifests(output_dir, metadata)
  current_hashes <- .goal007_task2_source_hashes(.goal003_project_root())
  recorded_hashes <- .goal007_audit_read_csv(
    file.path(output_dir, "source-hashes.csv")
  )
  if (!isTRUE(all.equal(
    recorded_hashes,
    current_hashes,
    check.attributes = FALSE
  ))) {
    .goal007_stop("Goal007 Task 2 source hashes differ from the run commit.")
  }
  status <- .goal007_audit_read_csv(file.path(result_dir, "fit-status.csv"))
  recovery <- .goal007_audit_read_csv(file.path(result_dir, "recovery.csv"))
  for (field in c("terminal_clean", "artifact_pass")) {
    status[[field]] <- as.logical(status[[field]])
  }
  for (field in c("terminal_clean", "generator_covered_90")) {
    recovery[[field]] <- as.logical(recovery[[field]])
  }
  prior_recorded <- .goal007_audit_read_csv(
    file.path(result_dir, "prior-bridge.csv")
  )
  likelihood_recorded <- .goal007_audit_read_csv(
    file.path(result_dir, "likelihood-bridge.csv")
  )
  prior_recorded$passed <- as.logical(prior_recorded$passed)
  likelihood_recorded$passed <- as.logical(likelihood_recorded$passed)
  prior_replayed <- goal007_prior_bridge_metrics()
  likelihood_replayed <- goal006_likelihood_bridge_metrics()
  if (!isTRUE(all.equal(
    prior_recorded, prior_replayed, tolerance = 1e-12,
    check.attributes = FALSE
  )) || !isTRUE(all.equal(
    likelihood_recorded, likelihood_replayed, tolerance = 1e-12,
    check.attributes = FALSE
  ))) {
    .goal007_stop("Goal007 Task 2 deterministic bridge evidence changed.")
  }
  contract <- read_goal007_task1_contract(verify_external = FALSE)
  replay <- replay_goal007_task2_gates_independent(
    contract,
    status,
    recovery,
    prior_replayed,
    likelihood_replayed
  )
  recorded_gates <- .goal007_audit_read_csv(
    file.path(result_dir, "decision-gates.csv")
  )
  recorded_gates$passed <- as.logical(recorded_gates$passed)
  recorded_eligibility <- .goal007_audit_read_csv(
    file.path(result_dir, "candidate-eligibility.csv")
  )
  recorded_eligibility$eligible <- as.logical(recorded_eligibility$eligible)
  recorded_catastrophic <- .goal007_audit_read_csv(
    file.path(result_dir, "catastrophic-cases.csv")
  )
  for (field in c("tail_error", "terminal_clean", "failed")) {
    recorded_catastrophic[[field]] <- as.logical(recorded_catastrophic[[field]])
  }
  gate_match <- .goal007_audit_compare(
    recorded_gates,
    replay$gates,
    c("stage", "gate_id", "model_id"),
    c(
      "value", "threshold", "comparison", "numerator", "denominator",
      "passed"
    )
  )
  eligibility_match <- .goal007_audit_compare(
    recorded_eligibility,
    replay$eligibility,
    "model_id",
    c("gates_passed", "gates_total", "eligible", "selection_priority")
  )
  catastrophic_match <- .goal007_audit_compare(
    recorded_catastrophic,
    replay$catastrophic,
    c("model_id", "dataset_id"),
    c("tail_error", "terminal_clean", "failed")
  )
  selected_replayed <- if (is.na(replay$selected_model_id)) {
    "none"
  } else {
    replay$selected_model_id
  }
  if (!gate_match || !eligibility_match || !catastrophic_match ||
      !identical(decision_recorded, replay$decision) ||
      !identical(selected_recorded, selected_replayed)) {
    .goal007_stop("Goal007 Task 2 independent audit disagrees.")
  }
  files <- sort(list.files(result_dir, full.names = TRUE))
  list(
    decision = replay$decision,
    selected_model_id = replay$selected_model_id,
    gates = replay$gates,
    eligibility = replay$eligibility,
    catastrophic = replay$catastrophic,
    artifact_hashes = tibble::tibble(
      path = basename(files),
      sha256 = vapply(files, function(path) {
        digest::digest(file = path, algo = "sha256", serialize = FALSE)
      }, character(1))
    ),
    run_commit = metadata$git_commit
  )
}
