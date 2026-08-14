if (!dir.exists("R") || !file.exists("renv.lock")) {
  stop("Run this script from the flexiRich repository root.", call. = FALSE)
}

arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) > 1L) {
  stop(
    "Usage: Rscript scripts/correct_goal003_task4_decision.R [source_run]",
    call. = FALSE
  )
}

for (path in sort(list.files("R", pattern = "\\.R$", full.names = TRUE))) {
  source(path, local = FALSE)
}

source_run <- if (length(arguments) == 1L) {
  arguments[[1L]]
} else {
  file.path("outputs", "goal003", "task4-screen-v1")
}
source_run <- normalizePath(source_run, mustWork = TRUE)
results_dir <- file.path(source_run, "results")
required_files <- c(
  "fit-status.csv",
  "richness-scores.csv",
  "screening-gates.csv",
  "cell-summary.csv",
  "sensitivity-pairs.csv",
  "completion-status.txt"
)
source_paths <- file.path(results_dir, required_files)
if (any(!file.exists(source_paths))) {
  stop("The frozen Task 4 result evidence is incomplete.", call. = FALSE)
}

expected_hashes <- c(
  "fit-status.csv" =
    "df8bad2b069f850642ed091269753c61535306b717cade453d4288575fe769c5",
  "richness-scores.csv" =
    "b1f21e92d40a650e03662de7447efc555de1349e3a1e54b8d5a1ba247406586f",
  "screening-gates.csv" =
    "ef0b7ff65266e98607d48694f58f65652957982cdecffc6c0594bf74848686f2",
  "cell-summary.csv" =
    "f5616fc5a560669d2985298c373b4717fb8fac080f26f5c40c4f0295b87a7ea3",
  "sensitivity-pairs.csv" =
    "a23fd7a287fc3599b5f081944485638ef08f78bc8b7dd89ad2d814c1df1336d2",
  "completion-status.txt" =
    "571a3db5cf894c508d3e0d0eee2ed37675bbb139825241321e8b2feb06c22ff6"
)
observed_hashes <- vapply(source_paths, function(path) {
  digest::digest(file = path, algo = "sha256", serialize = FALSE)
}, character(1))
names(observed_hashes) <- required_files
if (!identical(observed_hashes, expected_hashes)) {
  stop("The source result evidence differs from the frozen screen.", call. = FALSE)
}

source_completion <- readLines(
  file.path(source_run, "completion-status.txt"),
  warn = FALSE
)
expected_completion <- c(
  "status=SCREEN_STOP",
  "git_commit=0cf94097513629c72e14f99b94e2222818112ef3",
  "empirical_outcomes_used=false"
)
if (!identical(source_completion, expected_completion)) {
  stop("The source run completion record is not the frozen screen.", call. = FALSE)
}

git_status <- system2("git", c("status", "--porcelain"), stdout = TRUE)
correction_commit <- system2("git", c("rev-parse", "HEAD"), stdout = TRUE)
if (length(git_status) > 0L || length(correction_commit) != 1L ||
    !grepl("^[0-9a-f]{40}$", correction_commit)) {
  stop("Decision correction requires one clean committed Git state.", call. = FALSE)
}

manifest <- read_goal003_task4_manifests()
fit_status <- utils::read.csv(
  file.path(results_dir, "fit-status.csv"),
  stringsAsFactors = FALSE
)
richness_scores <- utils::read.csv(
  file.path(results_dir, "richness-scores.csv"),
  stringsAsFactors = FALSE
)
original <- utils::read.csv(
  file.path(results_dir, "screening-gates.csv"),
  stringsAsFactors = FALSE
)
corrected <- evaluate_goal003_task4_gates(
  manifest,
  fit_status,
  richness_scores
)$gates

catastrophic_id <- "catastrophic_overestimate"
unchanged_ids <- setdiff(original$gate_id, catastrophic_id)
original_unchanged <- original[match(unchanged_ids, original$gate_id), ]
corrected_unchanged <- corrected[match(unchanged_ids, corrected$gate_id), ]
if (!isTRUE(all.equal(
  original_unchanged,
  as.data.frame(corrected_unchanged),
  check.attributes = FALSE
))) {
  stop("The correction changed a gate outside its declared scope.", call. = FALSE)
}
original_catastrophic <- original[original$gate_id == catastrophic_id, ]
corrected_catastrophic <- corrected[corrected$gate_id == catastrophic_id, ]
valid_correction <- nrow(original_catastrophic) == 1L &&
  nrow(corrected_catastrophic) == 1L &&
  original_catastrophic$numerator == 2 &&
  original_catastrophic$denominator == 179 &&
  !original_catastrophic$passed &&
  corrected_catastrophic$numerator == 2 &&
  corrected_catastrophic$denominator == 299 &&
  corrected_catastrophic$passed
if (!valid_correction) {
  stop("The catastrophic-gate correction is not the expected change.", call. = FALSE)
}

expected_failures <- c(
  "matched_coverage_pooled-26w",
  "matched_coverage-matched_high-04w",
  "sensitivity_maximum-membership_regularised",
  "sensitivity_maximum-mu_alpha_wide",
  "sensitivity_maximum-broader_106"
)
failed <- corrected$gate_id[!corrected$passed]
if (!setequal(failed, expected_failures)) {
  stop("The corrected failed-gate set is not the reviewed result.", call. = FALSE)
}

output_parent <- dirname(source_run)
artifact_id <- paste0(basename(source_run), "-decision-correction-v1")
output_path <- publish_goal003_task4_artifact(
  output_parent,
  artifact_id,
  function(staging) {
    .goal003_task4_write_csv(
      original,
      file.path(staging, "original-screening-gates.csv")
    )
    .goal003_task4_write_csv(
      corrected,
      file.path(staging, "corrected-screening-gates.csv")
    )
    .goal003_task4_write_csv(
      dplyr::bind_rows(
        dplyr::mutate(original_catastrophic, decision_version = "original"),
        dplyr::mutate(corrected_catastrophic, decision_version = "corrected")
      ),
      file.path(staging, "changed-gate.csv")
    )
    .goal003_task4_write_csv(
      tibble::tibble(
        path = required_files,
        sha256 = unname(observed_hashes)
      ),
      file.path(staging, "source-evidence-sha256.csv")
    )
    writeLines(
      c(
        "status=SCREEN_STOP",
        "source_status=SCREEN_STOP",
        paste0(
          "source_git_commit=",
          sub("^git_commit=", "", expected_completion[[2L]])
        ),
        paste0("correction_git_commit=", correction_commit),
        "correction=catastrophic_denominator_all_primary_terminal_clean",
        "stan_refit=false",
        "empirical_outcomes_used=false"
      ),
      file.path(staging, "decision.txt")
    )
    writeLines(
      c(
        "status=SCREEN_STOP",
        "correction_complete=true",
        "rows_complete=true"
      ),
      file.path(staging, "completion-status.txt")
    )
  }
)

cat("Goal003 Task 4 corrected decision: SCREEN_STOP\n")
cat("source_run=", source_run, "\n", sep = "")
cat("correction_output=", output_path, "\n", sep = "")
cat("catastrophic_overestimate=2/299\n")
cat("failed_gates=", length(failed), "\n", sep = "")
cat("stan_refit=false\n")
cat("empirical_outcomes_used=false\n")
