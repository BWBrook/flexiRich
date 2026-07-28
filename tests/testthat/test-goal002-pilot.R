goal002_run_fixture <- function(
  status = "primary_clean",
  C = 30L,
  true_richness = 20L,
  observed_richness = 18L
) {
  probability <- numeric(C + 1L)
  probability[true_richness + 1L] <- 1
  pmf <- tibble::tibble(
    richness = seq.int(0L, C),
    probability = probability
  )

  list(
    run_id = "fixture",
    terminal_status = status,
    true_richness = true_richness,
    observed_richness = observed_richness,
    posterior_pmf = if (identical(status, "final_nonclean")) NULL else pmf,
    interval_90_lower = if (identical(status, "final_nonclean")) {
      NA_integer_
    } else {
      true_richness
    },
    interval_90_upper = if (identical(status, "final_nonclean")) {
      NA_integer_
    } else {
      true_richness
    }
  )
}

goal002_pilot_fixture <- function() {
  manifest <- goal002_frozen_manifest()
  pmfs <- lapply(manifest$true_richness, function(truth) {
    probability <- numeric(31L)
    probability[truth + 1L] <- 1
    tibble::tibble(
      richness = 0:30,
      probability = probability
    )
  })
  hash <- paste(rep("a", 64L), collapse = "")

  dplyr::mutate(
    manifest,
    terminal_status = "primary_clean",
    rescue_used = FALSE,
    observed_richness = pmax(0L, true_richness - 1L),
    data_hash = hash,
    model_hash = hash,
    primary_attempt_path = file.path(
      "outputs",
      "goal002",
      "frozen",
      run_id,
      "primary"
    ),
    rescue_attempt_path = NA_character_,
    summary_path = file.path(
      "outputs",
      "goal002",
      "frozen",
      run_id,
      "summary.rds"
    ),
    elapsed_seconds = 1,
    posterior_pmf = pmfs
  )
}

goal002_make_nonclean <- function(results, rows) {
  results$terminal_status[rows] <- "final_nonclean"
  results$rescue_used[rows] <- TRUE
  results$rescue_attempt_path[rows] <- file.path(
    "outputs",
    "goal002",
    "frozen",
    results$run_id[rows],
    "rescue"
  )
  results$posterior_pmf[rows] <- rep(list(NULL), length(rows))
  results
}

testthat::test_that("development manifest has one independent row per cell", {
  manifest <- goal002_development_manifest()
  testthat::expect_equal(nrow(manifest), 6L)
  testthat::expect_setequal(manifest$true_richness, c(8L, 20L, 27L))
  testthat::expect_setequal(manifest$n_occasions, c(26L, 208L))
  testthat::expect_true(all(manifest$prior_profile == "primary"))
  testthat::expect_equal(anyDuplicated(manifest$simulation_seed), 0L)
  testthat::expect_equal(anyDuplicated(manifest$fit_seed), 0L)
})

testthat::test_that("frozen manifest contains exactly 60 plus 36 fits", {
  manifest <- goal002_frozen_manifest()
  testthat::expect_equal(sum(manifest$run_type == "primary"), 60L)
  testthat::expect_equal(sum(manifest$run_type == "sensitivity"), 36L)
  testthat::expect_equal(nrow(manifest), 96L)
  testthat::expect_true(all(
    manifest$replicate[manifest$run_type == "sensitivity"] <= 3L
  ))
  testthat::expect_equal(anyDuplicated(manifest$run_id), 0L)
})

testthat::test_that("non-clean runs receive conservative gate values", {
  result <- goal002_run_fixture(status = "final_nonclean", C = 30L)
  gate <- goal002_gate_values(result, C = 30L)

  testthat::expect_false(gate$covered_90)
  testthat::expect_equal(gate$truth_probability, 0)
  testthat::expect_equal(gate$absolute_error, 30)
  testthat::expect_equal(gate$squared_error, 900)
  testthat::expect_equal(gate$rps, 30)
  testthat::expect_true(is.na(gate$signed_error))
})

testthat::test_that("manifest seeds and sensitivity pairing are exact", {
  development <- goal002_development_manifest()
  testthat::expect_equal(
    development$simulation_seed,
    120020000L + development$cell_id
  )
  testthat::expect_equal(
    development$fit_seed,
    220020000L + development$cell_id
  )

  frozen <- goal002_frozen_manifest()
  primary <- dplyr::filter(frozen, run_type == "primary")
  testthat::expect_equal(
    primary$simulation_seed,
    320020000L + 100L * primary$cell_id + primary$replicate
  )
  testthat::expect_equal(
    primary$fit_seed,
    420020000L + 100L * primary$cell_id + primary$replicate
  )
  sensitivity <- dplyr::filter(frozen, run_type == "sensitivity")
  paired <- dplyr::left_join(
    sensitivity,
    dplyr::select(
      primary,
      cell_id,
      replicate,
      primary_simulation_seed = simulation_seed
    ),
    by = c("cell_id", "replicate")
  )
  testthat::expect_equal(
    paired$simulation_seed,
    paired$primary_simulation_seed
  )
  testthat::expect_equal(
    sensitivity$fit_seed[
      sensitivity$prior_profile == "sensitivity_membership"
    ],
    520020000L +
      100L * sensitivity$cell_id[
        sensitivity$prior_profile == "sensitivity_membership"
      ] +
      sensitivity$replicate[
        sensitivity$prior_profile == "sensitivity_membership"
      ]
  )
  testthat::expect_equal(
    sensitivity$fit_seed[
      sensitivity$prior_profile == "sensitivity_tail"
    ],
    620020000L +
      100L * sensitivity$cell_id[
        sensitivity$prior_profile == "sensitivity_tail"
      ] +
      sensitivity$replicate[
        sensitivity$prior_profile == "sensitivity_tail"
      ]
  )
})

testthat::test_that("manifest validation rejects every row-set corruption", {
  for (phase in c("development", "frozen")) {
    manifest <- if (phase == "development") {
      goal002_development_manifest()
    } else {
      goal002_frozen_manifest()
    }
    testthat::expect_true(validate_goal002_manifest(manifest, phase))

    duplicate <- dplyr::bind_rows(manifest, manifest[1L, ])
    testthat::expect_error(
      validate_goal002_manifest(duplicate, phase),
      "differs"
    )
    missing <- manifest[-1L, ]
    testthat::expect_error(
      validate_goal002_manifest(missing, phase),
      "differs"
    )
    altered <- manifest
    altered$fit_seed[1L] <- altered$fit_seed[1L] + 1L
    testthat::expect_error(
      validate_goal002_manifest(altered, phase),
      "differs"
    )
    extra <- manifest
    extra$unexpected <- 1L
    testthat::expect_error(
      validate_goal002_manifest(extra, phase),
      "fields"
    )
  }
})

testthat::test_that("all Criteria 19 through 35 are returned canonically", {
  gates <- evaluate_goal002_gates(goal002_pilot_fixture())
  testthat::expect_identical(
    names(gates)[seq_len(17L)],
    paste0("criterion_", 19:35)
  )
  for (criterion in gates[seq_len(17L)]) {
    testthat::expect_identical(
      names(criterion),
      c(
        "criterion",
        "numerator",
        "denominator",
        "statistic",
        "threshold",
        "passed",
        "reason"
      )
    )
    testthat::expect_true(criterion$passed)
  }
})

testthat::test_that("fixed coverage denominators do not drop non-clean runs", {
  results <- goal002_pilot_fixture()
  six_month <- which(
    results$run_type == "primary" &
      results$n_occasions == 26L
  )[1L]
  results <- goal002_make_nonclean(results, six_month)
  gates <- evaluate_goal002_gates(results)

  testthat::expect_equal(gates$criterion_25$denominator, 10)
  testthat::expect_equal(gates$criterion_30$denominator, 30)
  testthat::expect_equal(
    gates$six_month_primary_summary$planned_n,
    30L
  )
  testthat::expect_equal(
    gates$six_month_primary_summary$clean_n,
    29L
  )
  testthat::expect_true(is.na(
    gates$six_month_primary_summary$signed_bias
  ))
  testthat::expect_equal(
    gates$criterion_30$numerator,
    29
  )
})

testthat::test_that("rescue-clean inference is included and addressable", {
  results <- goal002_pilot_fixture()
  row <- which(results$run_type == "primary")[1L]
  results$terminal_status[row] <- "rescue_clean"
  results$rescue_used[row] <- TRUE
  results$rescue_attempt_path[row] <- file.path(
    "outputs",
    "goal002",
    "frozen",
    results$run_id[row],
    "rescue"
  )
  gates <- evaluate_goal002_gates(results)

  testthat::expect_true(gates$criterion_19$passed)
  testthat::expect_true(gates$criterion_21$passed)
  testthat::expect_true(gates$criterion_22$passed)
  testthat::expect_true(
    gates$primary_gate_values$covered_90[
      gates$primary_gate_values$run_id == results$run_id[row]
    ]
  )
})

testthat::test_that("Criterion 22 enforces overall and per-cell limits", {
  results <- goal002_pilot_fixture()
  primary <- which(results$run_type == "primary")
  one_per_cell <- vapply(
    1:3,
    function(cell) {
      which(
        results$run_type == "primary" &
          results$cell_id == cell
      )[1L]
    },
    integer(1)
  )
  gates <- evaluate_goal002_gates(
    goal002_make_nonclean(results, one_per_cell)
  )
  testthat::expect_true(gates$criterion_22$passed)

  gates <- evaluate_goal002_gates(
    goal002_make_nonclean(results, primary[1:4])
  )
  testthat::expect_false(gates$criterion_22$passed)

  same_cell <- which(
    results$run_type == "primary" &
      results$cell_id == 1L
  )[1:2]
  gates <- evaluate_goal002_gates(
    goal002_make_nonclean(results, same_cell)
  )
  testthat::expect_false(gates$criterion_22$passed)
})

testthat::test_that("four-year non-clean runs fail recovery gates", {
  results <- goal002_pilot_fixture()
  row <- which(
    results$run_type == "primary" &
      results$n_occasions == 208L
  )[1L]
  gates <- evaluate_goal002_gates(
    goal002_make_nonclean(results, row)
  )

  testthat::expect_false(gates$criterion_25$passed)
  testthat::expect_false(gates$criterion_26$passed)
  testthat::expect_false(gates$criterion_27$passed)
  testthat::expect_false(gates$criterion_28$passed)
  testthat::expect_false(gates$criterion_29$passed)
})

testthat::test_that("four-year non-clean sensitivity fails stability gates", {
  results <- goal002_pilot_fixture()
  row <- which(
    results$run_type == "sensitivity" &
      results$n_occasions == 208L
  )[1L]
  gates <- evaluate_goal002_gates(
    goal002_make_nonclean(results, row)
  )

  testthat::expect_false(gates$criterion_33$passed)
  testthat::expect_false(gates$criterion_34$passed)
  testthat::expect_true(gates$criterion_32$passed)
})

testthat::test_that("non-clean sensitivity cannot expose inference", {
  results <- goal002_pilot_fixture()
  row <- which(results$run_type == "sensitivity")[1L]
  results <- goal002_make_nonclean(results, row)
  results$posterior_pmf[row] <- list(
    goal002_pilot_fixture()$posterior_pmf[[row]]
  )
  gates <- evaluate_goal002_gates(results)
  testthat::expect_false(gates$criterion_24$passed)
})

testthat::test_that("primary and rescue attempt addresses are audited", {
  results <- goal002_pilot_fixture()
  results$primary_attempt_path[1L] <- NA_character_
  gates <- evaluate_goal002_gates(results)
  testthat::expect_false(gates$criterion_19$passed)

  results <- goal002_pilot_fixture()
  results <- goal002_make_nonclean(results, 1L)
  results$rescue_attempt_path[1L] <- NA_character_
  gates <- evaluate_goal002_gates(results)
  testthat::expect_false(gates$criterion_19$passed)
  testthat::expect_false(gates$criterion_21$passed)
})

goal002_terminal_fixture <- function(
  row = goal002_development_manifest()[1L, ],
  manifest_hash = paste(rep("b", 64L), collapse = ""),
  freeze_hash = NA_character_
) {
  hash <- paste(rep("a", 64L), collapse = "")
  c(
    as.list(row),
    list(
      terminal_status = "primary_clean",
      rescue_used = FALSE,
      observed_richness = max(0L, row$true_richness - 1L),
      data_hash = hash,
      model_hash = hash,
      primary_attempt_path = file.path(
        "outputs",
        "goal002",
        "development",
        row$run_id,
        "primary"
      ),
      rescue_attempt_path = NA_character_,
      summary_path = file.path(
        "outputs",
        "goal002",
        "development",
        row$run_id,
        "summary.rds"
      ),
      elapsed_seconds = 1,
      manifest_hash = manifest_hash,
      freeze_hash = freeze_hash
    )
  )
}

testthat::test_that("pilot CLI accepts exactly the two documented phases", {
  testthat::expect_identical(
    goal002_parse_pilot_args(c("--phase", "development")),
    "development"
  )
  testthat::expect_identical(
    goal002_parse_pilot_args(c("--phase", "frozen")),
    "frozen"
  )
  for (bad in list(
    character(),
    "--phase",
    c("--phase", "other"),
    c("--phase", "development", "extra"),
    c("development", "--phase")
  )) {
    testthat::expect_error(
      goal002_parse_pilot_args(bad),
      "Usage"
    )
  }
})

testthat::test_that("terminal action skips only complete matching records", {
  root <- withr::local_tempdir()
  run_dir <- file.path(root, "run")
  manifest_hash <- paste(rep("b", 64L), collapse = "")
  freeze_hash <- paste(rep("c", 64L), collapse = "")
  row <- goal002_development_manifest()[1L, ]

  testthat::expect_identical(
    goal002_terminal_action(
      run_dir,
      row,
      manifest_hash,
      freeze_hash
    ),
    "run"
  )

  dir.create(run_dir)
  testthat::expect_error(
    goal002_terminal_action(
      run_dir,
      row,
      manifest_hash,
      freeze_hash
    ),
    "partial"
  )

  record <- goal002_terminal_fixture(
    row,
    manifest_hash,
    freeze_hash
  )
  saveRDS(record, file.path(run_dir, "terminal.rds"))
  testthat::expect_identical(
    goal002_terminal_action(
      run_dir,
      row,
      manifest_hash,
      freeze_hash
    ),
    "skip"
  )

  record$manifest_hash <- paste(rep("d", 64L), collapse = "")
  saveRDS(record, file.path(run_dir, "terminal.rds"))
  testthat::expect_error(
    goal002_terminal_action(
      run_dir,
      row,
      manifest_hash,
      freeze_hash
    ),
    "hash"
  )
})

testthat::test_that("development dispatcher resumes without replacing a run", {
  root <- withr::local_tempdir()
  dir.create(file.path(root, "config"))
  utils::write.csv(
    goal002_development_manifest(),
    file.path(root, "config", "goal002_development_manifest.csv"),
    row.names = FALSE,
    quote = TRUE
  )
  calls <- new.env(parent = emptyenv())
  calls$n <- 0L
  fake_runner <- function(row, run_dir, manifest_hash, freeze_hash) {
    calls$n <- calls$n + 1L
    goal002_terminal_fixture(row, manifest_hash, freeze_hash)
  }

  first <- dispatch_goal002_pilot(
    phase = "development",
    project_root = root,
    run_row = fake_runner
  )
  testthat::expect_equal(calls$n, 6L)
  testthat::expect_true(all(first$action == "completed"))

  second <- dispatch_goal002_pilot(
    phase = "development",
    project_root = root,
    run_row = fake_runner
  )
  testthat::expect_equal(calls$n, 6L)
  testthat::expect_true(all(second$action == "skipped"))

  terminal_path <- file.path(
    root,
    "outputs",
    "goal002",
    "development",
    goal002_development_manifest()$run_id[1L],
    "terminal.rds"
  )
  terminal_before <- readRDS(terminal_path)
  terminal_before$manifest_hash <- paste(rep("d", 64L), collapse = "")
  saveRDS(terminal_before, terminal_path)
  testthat::expect_error(
    dispatch_goal002_pilot(
      phase = "development",
      project_root = root,
      run_row = fake_runner
    ),
    "hash"
  )
  testthat::expect_identical(readRDS(terminal_path), terminal_before)
  testthat::expect_equal(calls$n, 6L)
})

testthat::test_that("frozen dispatch requires a matching freeze record", {
  root <- withr::local_tempdir()
  dir.create(file.path(root, "config"))
  frozen <- goal002_frozen_manifest()
  utils::write.csv(
    frozen,
    file.path(root, "config", "goal002_frozen_manifest.csv"),
    row.names = FALSE,
    quote = TRUE
  )
  never_run <- function(...) {
    testthat::fail("Frozen runner must not be reached.")
  }

  testthat::expect_error(
    dispatch_goal002_pilot(
      phase = "frozen",
      project_root = root,
      run_row = never_run
    ),
    "freeze"
  )

  utils::write.csv(
    tibble::tibble(
      key = "frozen_manifest_hash",
      value = paste(rep("d", 64L), collapse = "")
    ),
    file.path(root, "config", "goal002_freeze.csv"),
    row.names = FALSE,
    quote = TRUE
  )
  testthat::expect_error(
    dispatch_goal002_pilot(
      phase = "frozen",
      project_root = root,
      run_row = never_run
    ),
    "manifest hash"
  )
})
