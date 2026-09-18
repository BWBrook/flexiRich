# Exploratory conditional calendar-timing permutation diagnostic for Goal009.
# This script reads only the sealed first-year Goal008 development tables.

if (!dir.exists("R") || !file.exists(file.path("config", "goal003_candidate_pool.csv"))) {
  stop("Run this script from the flexiRich repository root.", call. = FALSE)
}

for (path in sort(list.files("R", pattern = "[.]R$", full.names = TRUE))) {
  source(path, local = FALSE)
}

arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) > 1L) {
  stop("Usage: Rscript scripts/check_goal009_conditional_timing.R [output_dir]",
       call. = FALSE)
}
output_dir <- if (length(arguments) == 1L) arguments[[1L]] else
  file.path("outputs", "goal009", "conditional-timing-v1")
if (!is.character(output_dir) || length(output_dir) != 1L ||
    is.na(output_dir) || !nzchar(output_dir)) {
  stop("output_dir must be one non-empty path.", call. = FALSE)
}
if (file.exists(output_dir) || dir.exists(output_dir)) {
  stop("Refusing to overwrite an existing conditional-timing output directory: ",
       output_dir, call. = FALSE)
}

replicates <- 1999L
seed <- 2026091801L
rng_kind <- c("Mersenne-Twister", "Inversion", "Rejection")
started <- Sys.time()

# Use the project adapter so the candidate universe, weekly keys, effort, and
# missingness contract are checked before any permutation is attempted.
development <- goal009_read_development()
data <- development$data
labels <- development$labels
C <- length(data$candidate_ids)
J <- length(data$camera_ids)
T <- length(data$occasion_ids)
stopifnot(identical(c(C, J, T), c(50L, 9L, 52L)))

observed <- .goal009_observed_array(data, C, J, T)
effort <- matrix(
  data$observed$active_days[seq_len(J * T)],
  nrow = J, ncol = T, byrow = TRUE,
  dimnames = list(data$camera_ids, data$occasion_ids)
)
effort_array <- array(
  rep(as.vector(effort), each = C),
  dim = dim(observed), dimnames = dimnames(observed)
)
observed_species_mask <- data$stan_data$detected_ever == 1L
stopifnot(length(observed_species_mask) == C, sum(observed_species_mask) == 21L)
stopifnot(identical(dim(observed), c(C, J, T)), identical(dim(effort), c(J, T)))
stopifnot(all(effort >= 0L & effort <= 7L), all(effort == round(effort)))
stopifnot(identical(dim(effort_array), dim(observed)),
          all(is.na(observed)[effort_array == 0L]),
          all(!is.na(observed)[effort_array > 0L]),
          all(observed[!is.na(observed)] %in% c(0L, 1L)))

statistic_names <- c(
  "adjacent_switch_count",
  paste0("block_", sprintf("%02d", seq_len(4L)), "_positivecells"),
  paste0("block_", sprintf("%02d", seq_len(4L)), "_richness")
)
observed_values_all <- .goal009_statistic_values(
  observed, labels, effort, data$camera_ids, data$occasion_ids,
  observed_species_mask
)
stopifnot(all(statistic_names %in% names(observed_values_all)))
observed_values <- observed_values_all[statistic_names]
stopifnot(identical(as.integer(observed_values[["adjacent_switch_count"]]), 786L),
          identical(as.integer(observed_values[
            paste0("block_", sprintf("%02d", seq_len(4L)), "_positivecells")
          ]), c(334L, 223L, 51L, 371L)))

# A stratum is one species x camera x exact positive active-day count.  A
# stratum with at least two cells can contribute calendar information to the
# permutation null; a mixed stratum contains both observed detections and
# non-detections and therefore has non-degenerate timing permutations.
strata <- list()
stratum_linear_indices <- list()
stratum_index <- 0L
for (i in seq_len(C)) {
  for (j in seq_len(J)) {
    positive_days <- sort(unique(effort[j, effort[j, ] > 0L]))
    for (active_days in positive_days) {
      cells <- which(effort[j, ] == active_days)
      values <- observed[i, j, cells]
      stratum_index <- stratum_index + 1L
      stratum_linear_indices[[stratum_index]] <-
        i + C * ((j - 1L) + J * (cells - 1L))
      strata[[stratum_index]] <- data.frame(
        species_id = data$candidate_ids[[i]],
        camera_id = data$camera_ids[[j]],
        active_days = as.integer(active_days),
        n_cells = length(cells),
        n_detected = sum(values == 1L),
        n_nondetected = sum(values == 0L),
        shuffleable = length(cells) >= 2L,
        mixed = any(values == 1L) && any(values == 0L),
        stringsAsFactors = FALSE
      )
    }
  }
}
strata <- tibble::as_tibble(do.call(rbind, strata))
stopifnot(nrow(strata) > 0L,
          all(strata$n_cells >= 1L),
          all(strata$n_detected + strata$n_nondetected == strata$n_cells),
          all(strata$shuffleable == (strata$n_cells >= 2L)),
          all(strata$mixed == (strata$n_detected > 0L & strata$n_nondetected > 0L)))

positive_effort <- effort > 0L
stopifnot(sum(strata$n_cells) == C * sum(positive_effort),
          sum(strata$shuffleable) >= 0L,
          sum(strata$mixed) >= 0L)

all_stratum_indices <- unlist(stratum_linear_indices, use.names = FALSE)
stratum_group <- rep(seq_along(stratum_linear_indices),
                     lengths(stratum_linear_indices))
expected_stratum_counts <- rowsum(
  as.integer(observed[all_stratum_indices] == 1L),
  stratum_group, reorder = FALSE
)[, 1L]
expected_species_totals <- rowSums(
  matrix(!is.na(observed) & observed == 1L, nrow = C, ncol = J * T),
  na.rm = TRUE
)

# Shuffle only detection values within each exact-effort stratum.  Starting
# from the observed array leaves every zero-effort NA untouched by construction.
.goal009_conditional_shuffle <- function(x, effort_matrix) {
  result <- x
  for (i in seq_len(dim(x)[1L])) {
    for (j in seq_len(dim(x)[2L])) {
      positive_days <- sort(unique(effort_matrix[j, effort_matrix[j, ] > 0L]))
      for (active_days in positive_days) {
        cells <- which(effort_matrix[j, ] == active_days)
        if (length(cells) > 1L) {
          permutation <- sample.int(length(cells), size = length(cells), replace = FALSE)
          result[i, j, cells] <- x[i, j, cells[permutation]]
        }
      }
    }
  }
  result
}

.goal009_check_permutation <- function(permuted, original, effort_matrix) {
  stopifnot(identical(dim(permuted), dim(original)),
            identical(is.na(permuted), is.na(original)))
  for (i in seq_len(dim(permuted)[1L])) {
    total_original <- sum(!is.na(original[i, , ]) & original[i, , ] == 1L)
    total_permuted <- sum(!is.na(permuted[i, , ]) & permuted[i, , ] == 1L)
    stopifnot(identical(as.integer(total_permuted), as.integer(total_original)))
    for (j in seq_len(dim(permuted)[2L])) {
      positive_days <- sort(unique(effort_matrix[j, effort_matrix[j, ] > 0L]))
      for (active_days in positive_days) {
        cells <- which(effort_matrix[j, ] == active_days)
        original_count <- sum(original[i, j, cells] == 1L)
        permuted_count <- sum(permuted[i, j, cells] == 1L)
        stopifnot(identical(as.integer(permuted_count), as.integer(original_count)))
      }
    }
  }
  invisible(TRUE)
}

.goal009_check_permutation_fast <- function(permuted, original) {
  stopifnot(identical(dim(permuted), dim(original)),
            identical(is.na(permuted), is.na(original)))
  permuted_species_totals <- rowSums(
    matrix(!is.na(permuted) & permuted == 1L, nrow = C, ncol = J * T),
    na.rm = TRUE
  )
  permuted_stratum_counts <- rowsum(
    as.integer(permuted[all_stratum_indices] == 1L),
    stratum_group, reorder = FALSE
  )[, 1L]
  stopifnot(identical(as.integer(permuted_species_totals),
                      as.integer(expected_species_totals)),
            identical(as.integer(permuted_stratum_counts),
                      as.integer(expected_stratum_counts)))
  invisible(TRUE)
}

# Internal small-data check exercises the same permutation function, including
# a zero-effort NA and a mixed exact-effort stratum.
toy_effort <- matrix(c(0L, 7L, 7L, 3L, 3L), nrow = 1L)
toy <- array(c(NA_integer_, 1L, 0L, 1L, 0L), dim = c(1L, 1L, 5L))
withr::with_seed(901L, {
  toy_permuted <- .goal009_conditional_shuffle(toy, toy_effort)
}, .rng_kind = rng_kind[[1L]], .rng_normal_kind = rng_kind[[2L]],
   .rng_sample_kind = rng_kind[[3L]])
.goal009_check_permutation(toy_permuted, toy, toy_effort)
stopifnot(is.na(toy_permuted[1L, 1L, 1L]),
          sum(toy_permuted[1L, 1L, 2:3] == 1L) == 1L,
          sum(toy_permuted[1L, 1L, 4:5] == 1L) == 1L)

replicate_values <- matrix(
  NA_real_, nrow = replicates, ncol = length(statistic_names),
  dimnames = list(NULL, statistic_names)
)
withr::with_seed(seed, {
  for (replicate in seq_len(replicates)) {
    permuted <- .goal009_conditional_shuffle(observed, effort)
    .goal009_check_permutation_fast(permuted, observed)
    values <- .goal009_statistic_values(
      permuted, labels, effort, data$camera_ids, data$occasion_ids,
      observed_species_mask
    )
    replicate_values[replicate, ] <- as.numeric(values[statistic_names])
  }
}, .rng_kind = rng_kind[[1L]], .rng_normal_kind = rng_kind[[2L]],
   .rng_sample_kind = rng_kind[[3L]])
stopifnot(all(is.finite(replicate_values)))

finite_n <- colSums(is.finite(replicate_values))
summary <- tibble::tibble(
  statistic = statistic_names,
  observed = as.numeric(observed_values),
  q05 = vapply(seq_along(statistic_names), function(k)
    .goal009_quantile(replicate_values[, k], 0.05), numeric(1)),
  q50 = vapply(seq_along(statistic_names), function(k)
    .goal009_quantile(replicate_values[, k], 0.50), numeric(1)),
  q95 = vapply(seq_along(statistic_names), function(k)
    .goal009_quantile(replicate_values[, k], 0.95), numeric(1)),
  number_ge = vapply(seq_along(statistic_names), function(k)
    sum(replicate_values[, k] >= observed_values[[k]], na.rm = TRUE), integer(1)),
  number_le = vapply(seq_along(statistic_names), function(k)
    sum(replicate_values[, k] <= observed_values[[k]], na.rm = TRUE), integer(1)),
  fraction_ge = vapply(seq_along(statistic_names), function(k)
    mean(replicate_values[, k] >= observed_values[[k]], na.rm = TRUE), numeric(1)),
  fraction_le = vapply(seq_along(statistic_names), function(k)
    mean(replicate_values[, k] <= observed_values[[k]], na.rm = TRUE), numeric(1)),
  finite_replicates = as.integer(finite_n),
  finite_fraction = finite_n / replicates
)
stopifnot(nrow(summary) == length(statistic_names),
          all(summary$finite_replicates == replicates),
          all(summary$number_ge >= 0L & summary$number_ge <= replicates),
          all(summary$number_le >= 0L & summary$number_le <= replicates))

replicate_statistics <- tibble::as_tibble(cbind(
  replicate = seq_len(replicates),
  as.data.frame(replicate_values, check.names = FALSE)
))
stopifnot(nrow(replicate_statistics) == replicates,
          identical(as.integer(replicate_statistics$replicate), seq_len(replicates)))

root <- normalizePath(getwd(), mustWork = TRUE)
relative_sources <- c(
  "outputs/goal008/development-v1/candidate_pool.csv",
  "outputs/goal008/development-v1/effort_weekly.csv",
  "outputs/goal008/development-v1/detections_weekly.csv",
  "outputs/goal008/development-v1/occasion_calendar.csv",
  "config/goal003_candidate_pool.csv",
  "config/goal003_task4_effort_template.csv",
  "R/goal009_criticism.R",
  "R/infer_data.R",
  "scripts/check_goal009_conditional_timing.R"
)
source_hashes <- tibble::tibble(
  relative_path = relative_sources,
  sha256 = vapply(relative_sources, function(relative_path) {
    path <- file.path(root, relative_path)
    stopifnot(file.exists(path))
    digest::digest(file = path, algo = "sha256", serialize = FALSE)
  }, character(1))
)
git_head <- system2("git", c("rev-parse", "HEAD"), stdout = TRUE)
stopifnot(length(git_head) == 1L, grepl("^[0-9a-f]{40}$", git_head))

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
stopifnot(dir.exists(output_dir))
utils::write.csv(replicate_statistics,
                 file.path(output_dir, "replicate-statistics.csv"),
                 row.names = FALSE)
utils::write.csv(summary, file.path(output_dir, "summary.csv"), row.names = FALSE)
utils::write.csv(strata, file.path(output_dir, "strata-summary.csv"), row.names = FALSE)
utils::write.csv(source_hashes, file.path(output_dir, "source-hashes.csv"), row.names = FALSE)

completed <- Sys.time()
metadata <- tibble::tibble(
  key = c(
    "analysis_version", "goal", "purpose", "interpretation",
    "input_directory", "input_data_hash", "n_species", "n_observed_species",
    "n_cameras", "n_occasions", "n_replicates", "seed", "rng_kind",
    "n_positive_effort_cells", "n_strata_total", "n_effective_strata",
    "n_mixed_strata", "n_mixed_stratum_cells", "stratum_definition",
    "fixed_switch_species_mask", "block_definition", "finite_simulation_note",
    "git_head", "started_utc", "completed_utc"
  ),
  value = c(
    "goal009-conditional-timing-v1",
    "Goal009 exploratory conditional calendar-timing criticism",
    "Permutation diagnostic motivated by the frozen Goal009 PPC",
    "Calendar non-exchangeability conditional on species, camera, and exact positive active-day count; this does not identify seasonality or mechanism",
    "outputs/goal008/development-v1",
    data$data_hash,
    as.character(C), as.character(sum(observed_species_mask)), as.character(J),
    as.character(T), as.character(replicates), as.character(seed),
    paste(rng_kind, collapse = ","),
    as.character(C * sum(positive_effort)), as.character(nrow(strata)),
    as.character(sum(strata$shuffleable)), as.character(sum(strata$mixed)),
    as.character(sum(strata$n_cells[strata$mixed])),
    "one species x camera x exact positive active-day count",
    "fixed 21 detected-ever species for adjacent switches",
    "four consecutive 13-week blocks; detected richness counts all 50 species",
    "Quantiles and fractions are finite-sample descriptive summaries over 1999 random permutations; ties are included in both >= and <= counts, and no asymptotic p-value is implied",
    git_head, format(started, tz = "UTC", usetz = TRUE),
    format(completed, tz = "UTC", usetz = TRUE)
  )
)
utils::write.csv(metadata, file.path(output_dir, "run-metadata.csv"), row.names = FALSE)
writeLines(c(
  "status=PASS",
  "analysis_version=goal009-conditional-timing-v1",
  paste0("n_replicates=", replicates),
  paste0("seed=", seed),
  paste0("completed_utc=", format(completed, tz = "UTC", usetz = TRUE))
), file.path(output_dir, "completion-status.txt"))

cat("Goal009 conditional timing permutation diagnostic: PASS\n")
cat("output_dir=", output_dir, "\n", sep = "")
print(summary)
