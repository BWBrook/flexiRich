# Independent, read-only audit of the frozen Goal011 prediction objects.
# This script never reads later Judbury outcomes or Huon Ridge data.
options(warn = 2)

forecast_root <- Sys.getenv(
  "GOAL011_FORECAST_ROOT",
  unset = "outputs/goal011/forecast-v1"
)
audit_root <- Sys.getenv(
  "GOAL011_PREDICTION_AUDIT_OUTPUT",
  unset = "outputs/goal011/prediction-audit-v1"
)
archive_path <- paste0(
  "docs/goals/011-frozen-temporal-forecasts/evidence/",
  "goal011-frozen-predictions.tar.gz"
)
archive_sha256 <- "13f1482a7e926606d20197ca1d5bf127b172d0f5bd6547c583d6a2c8c8bb2ae2"
generation_commit <- "033c21ac13bb830d34e31d40698e5f6a0b4dda6d"

fail <- function(message) stop(message, call. = FALSE)
check <- function(value, message) if (!isTRUE(value)) fail(message)
logsumexp <- function(x) {
  if (!length(x) || !any(is.finite(x))) return(-Inf)
  m <- max(x[is.finite(x)])
  m + log(sum(exp(x - m)))
}
logadd <- function(a, b) {
  m <- pmax(a, b)
  out <- m
  finite <- is.finite(m)
  out[finite] <- m[finite] + log(exp(a[finite] - m[finite]) +
                                  exp(b[finite] - m[finite]))
  take_a <- !finite & is.finite(a)
  take_b <- !finite & !is.finite(a) & is.finite(b)
  out[take_a] <- a[take_a]
  out[take_b] <- b[take_b]
  out
}
keys <- function(x, columns) do.call(paste, c(x[columns], sep = "\r"))
sha256 <- function(path) digest::digest(
  file = path, algo = "sha256", serialize = FALSE
)

# A separate ordinary-probability recurrence is adequate for K <= 50 here and
# deliberately differs from the generator's log-domain implementation.
conditional_poibin <- function(log_p, log_q) {
  D <- nrow(log_p)
  K <- ncol(log_p)
  mass <- matrix(0, nrow = D, ncol = K + 1L)
  mass[, 1L] <- 1
  for (j in seq_len(K)) {
    old <- mass[, seq_len(j), drop = FALSE]
    p <- exp(log_p[, j])
    q <- exp(log_q[, j])
    mass[, seq_len(j + 1L)] <- 0
    mass[, 1L] <- old[, 1L] * q
    if (j > 1L) {
      mass[, 2L:j] <- old[, seq_len(j - 1L), drop = FALSE] * p +
        old[, 2L:j, drop = FALSE] * q
    }
    mass[, j + 1L] <- old[, j] * p
  }
  mass
}

poibin_from_means <- function(p) {
  mass <- c(1, rep(0, length(p)))
  for (j in seq_along(p)) {
    old <- mass
    mass[seq_len(j + 1L)] <- 0
    mass[1L] <- old[1L] * (1 - p[j])
    if (j > 1L) {
      mass[2L:j] <- old[seq_len(j - 1L)] * p[j] +
        old[2L:j] * (1 - p[j])
    }
    mass[j + 1L] <- old[j] * p[j]
  }
  mass
}

mcse_log_mean <- function(x, chains = 4L) {
  check(length(x) %% chains == 0L, "Draw count is not divisible by four chains.")
  scale <- max(x)
  z <- if (scale > 0) x / scale else x
  iterations <- length(z) %/% chains
  draws <- posterior::as_draws_array(array(
    z, dim = c(iterations, chains, 1L),
    dimnames = list(NULL, NULL, "conditional_mass")
  ))
  estimate <- mean(z)
  check(is.finite(estimate) && estimate > 0, "Conditional mass mean is zero.")
  c(
    log_mcse = as.numeric(posterior::mcse_mean(draws)) / estimate,
    ess_mean = as.numeric(posterior::ess_mean(draws)),
    rhat = as.numeric(posterior::rhat(draws))
  )
}

if (!dir.exists(forecast_root)) fail("Frozen forecast directory is missing.")
if (dir.exists(audit_root) || file.exists(audit_root)) {
  fail("Refusing to overwrite an existing Goal011 prediction audit.")
}

# Archive and run-level provenance.
check(file.exists(archive_path), "Committed prediction archive is missing.")
check(identical(sha256(archive_path), archive_sha256),
      "Prediction archive SHA-256 differs from its frozen identity.")
archive_commit <- system2(
  "git", c("log", "-1", "--format=%H", "--", archive_path), stdout = TRUE
)
check(length(archive_commit) == 1L && nzchar(archive_commit),
      "Prediction archive is not committed.")
check(system2("git", c("cat-file", "-e", paste0(archive_commit, ":", archive_path))) == 0L,
      "Prediction archive is absent from its claimed commit.")
exit_code <- trimws(readLines(paste0(forecast_root, ".exitcode"), warn = FALSE))
check(identical(exit_code, "0"), "Remote forecast exit code is not zero.")
check(identical(readLines(file.path(forecast_root, "STATUS.txt"), warn = FALSE),
                "COMPLETE: predictions generated; freeze and audit before outcome access"),
      "Forecast completion marker is not exact.")
metadata_lines <- readLines(file.path(forecast_root, "run-metadata.txt"), warn = FALSE)
check(any(metadata_lines == paste0("git_commit=", generation_commit)),
      "Run metadata do not identify the frozen generation commit.")
check(any(metadata_lines == "later_detection_outcomes_read=false") &&
        any(metadata_lines == "huon_ridge_read=false") &&
        any(metadata_lines == "score_status=unscored_predictions_only"),
      "Run metadata do not preserve the protected-outcome state.")

# Verify all declared inputs and outputs, plus exact output file membership.
output_receipts <- read.csv(file.path(forecast_root, "output-sha256.csv"),
                            stringsAsFactors = FALSE)
actual_relative <- sort(sub(
  paste0("^", forecast_root, "/"), "",
  list.files(forecast_root, recursive = TRUE, full.names = TRUE)
))
expected_relative <- sort(c(output_receipts$path, "output-sha256.csv"))
check(identical(actual_relative, expected_relative),
      "Forecast directory file set differs from the receipt contract.")
output_hashes <- data.frame(
  kind = "output", path = output_receipts$path,
  expected_sha256 = output_receipts$sha256,
  actual_sha256 = vapply(
    file.path(forecast_root, output_receipts$path), sha256, character(1)
  ), stringsAsFactors = FALSE
)
output_hashes$passed <- output_hashes$expected_sha256 == output_hashes$actual_sha256
check(all(output_hashes$passed), "At least one output SHA-256 receipt failed.")

input_receipts <- read.csv(file.path(forecast_root, "input-receipts.csv"),
                           stringsAsFactors = FALSE)
frozen_input_receipts <- read.csv("config/goal011_inputs.csv", stringsAsFactors = FALSE)
check(identical(input_receipts, frozen_input_receipts),
      "Saved input receipts differ from the frozen input manifest.")
input_hashes <- data.frame(
  kind = "input", path = input_receipts$path,
  expected_sha256 = input_receipts$sha256,
  actual_sha256 = vapply(input_receipts$path, sha256, character(1)),
  stringsAsFactors = FALSE
)
input_hashes$passed <- input_hashes$expected_sha256 == input_hashes$actual_sha256
check(all(input_hashes$passed), "At least one input SHA-256 receipt failed.")

manifest <- read.csv(file.path(forecast_root, "model-manifest.csv"),
                     stringsAsFactors = FALSE)
check(identical(manifest, read.csv("config/goal011_models.csv", stringsAsFactors = FALSE)),
      "Saved model manifest differs from the frozen model manifest.")
status <- read.csv(file.path(forecast_root, "model-status.csv"),
                   stringsAsFactors = FALSE)
check(identical(status$model_id, manifest$model_id) &&
        identical(status$role, manifest$role) &&
        all(status$status == "predictions_complete_unscored") &&
        identical(status$draw_count, c(4000L, 4000L, 4000L, 6000L, 6000L, 6000L)),
      "Model completion statuses or draw counts are not exact.")

# Frozen calendar, effort, candidate identities, and first-year known flags.
horizons <- c(13L, 26L, 52L, 101L)
future_calendar <- read.csv("config/goal011_future_calendar.csv",
                            stringsAsFactors = FALSE)
saved_horizons <- read.csv(file.path(forecast_root, "horizons.csv"),
                           stringsAsFactors = FALSE)
expected_horizons <- future_calendar[future_calendar$future_week %in% horizons, ]
rownames(expected_horizons) <- NULL
check(identical(saved_horizons, expected_horizons),
      "Saved horizon calendar differs from the frozen calendar.")
check(identical(saved_horizons$occasion_index, c(65L, 78L, 104L, 153L)) &&
        identical(saved_horizons$end_date,
                  c("2020-09-01", "2020-12-01", "2021-06-01", "2022-05-10")),
      "Horizon endpoints are not exact.")
future_effort <- read.csv("config/goal011_future_effort.csv",
                          stringsAsFactors = FALSE)
check(nrow(future_effort) == 909L && sum(future_effort$active_days) == 5303L &&
        identical(sort(unique(future_effort$occasion_index)), 53:153),
      "Frozen future effort dimensions or totals changed.")
effort_reference <- read.csv("config/goal003_task4_effort_template.csv",
                             stringsAsFactors = FALSE)
effort_key <- keys(future_effort, c("camera_id", "occasion_index"))
reference_key <- keys(effort_reference, c("camera_id", "occasion_index"))
check(!anyDuplicated(effort_key) && all(effort_key %in% reference_key) &&
        identical(future_effort$active_days,
                  effort_reference$active_days[match(effort_key, reference_key)]),
      "Future effort differs from the reviewed source template.")

candidate_ids <- read.csv(
  "outputs/goal008/development-v1/candidate_pool.csv",
  stringsAsFactors = FALSE
)$species_id
training <- read.csv(
  "outputs/goal008/development-v1/detections_weekly.csv",
  stringsAsFactors = FALSE
)
known <- vapply(candidate_ids, function(id) {
  any(training$detected[training$species_id == id] == 1L, na.rm = TRUE)
}, logical(1))
check(length(candidate_ids) == 50L && sum(known) == 21L && sum(!known) == 29L,
      "Frozen candidate or 21/29 known-unseen identity changed.")

model_rows <- list()
pmf_rows <- list()
replay_rows <- list()
mcse_rows <- list()

for (m in seq_len(nrow(manifest))) {
  id <- manifest$model_id[m]
  forecast <- readRDS(file.path(forecast_root, id, "forecast.rds"))
  parent_draws <- readRDS(manifest$draw_path[m])
  D <- status$draw_count[match(id, status$model_id)]
  check(identical(names(forecast),
                  c("species_probabilities", "count_pmfs", "per_draw", "metadata")),
        paste(id, "has an unexpected top-level schema."))
  check(identical(dim(forecast$per_draw$log_detection), c(D, 50L, 4L)) &&
          identical(dim(forecast$per_draw$log_nondetection), c(D, 50L, 4L)),
        paste(id, "has incorrect all-draw dimensions."))
  check(identical(forecast$metadata$candidate_ids, candidate_ids) &&
          identical(forecast$metadata$horizons, horizons) &&
          identical(forecast$metadata$draw_count, D) &&
          identical(forecast$metadata$known_count, 21L) &&
          identical(forecast$metadata$unseen_count, 29L),
        paste(id, "metadata identity is incorrect."))
  expected_interaction <- startsWith(id, "spatial_")
  check(identical(forecast$metadata$interaction_included, expected_interaction) &&
          identical(!is.null(parent_draws$interaction), expected_interaction),
        paste(id, "interaction metadata disagrees with its parent draws."))
  check(identical(dim(parent_draws$q_member), c(D, 50L)) &&
          identical(parent_draws$candidate_ids, candidate_ids) &&
          all(parent_draws$q_member[, known, drop = FALSE] == 1),
        paste(id, "parent draw identities or known-membership flags failed."))

  expected_effort <- matrix(
    0, nrow = length(parent_draws$camera_ids), ncol = 101L,
    dimnames = list(parent_draws$camera_ids, as.character(seq_len(101L)))
  )
  expected_effort[cbind(match(future_effort$camera_id, parent_draws$camera_ids),
                        future_effort$future_week)] <- future_effort$active_days
  check(identical(forecast$metadata$effort, expected_effort),
        paste(id, "embedded effort differs from the frozen forecast effort."))

  ld <- forecast$per_draw$log_detection
  ln <- forecast$per_draw$log_nondetection
  check(!anyNA(ld) && !anyNA(ln) && !any(is.nan(ld)) && !any(is.nan(ln)) &&
          all(ld <= 0) && all(ln <= 0),
        paste(id, "contains invalid per-draw log probabilities."))
  complement_error <- max(abs(logadd(as.vector(ld), as.vector(ln))))
  check(is.finite(complement_error) && complement_error < 5e-13,
        paste(id, "per-draw event complements do not normalize."))
  detection_nested <- all(vapply(seq_len(dim(ld)[3L] - 1L), function(h) {
    all(ld[, , h + 1L] >= ld[, , h] - 1e-14)
  }, logical(1)))
  nondetection_nested <- all(vapply(seq_len(dim(ln)[3L] - 1L), function(h) {
    all(ln[, , h + 1L] <= ln[, , h] + 1e-14)
  }, logical(1)))
  check(detection_nested && nondetection_nested,
        paste(id, "per-draw cumulative probabilities are not nested."))
  q_zero <- parent_draws$q_member == 0
  for (h in seq_along(horizons)) {
    negative_infinity <- is.infinite(ld[, , h]) & ld[, , h] < 0
    check(identical(dim(negative_infinity), dim(q_zero)) &&
            all(negative_infinity == unclass(q_zero)),
          paste(id, "has an unexplained -Inf detection probability."))
  }
  check(!any(is.infinite(ln)),
        paste(id, "has an unexplained infinite non-detection probability."))

  species <- forecast$species_probabilities
  species_csv <- read.csv(file.path(forecast_root, id, "species-probabilities.csv"),
                          stringsAsFactors = FALSE)
  check(isTRUE(all.equal(species, species_csv, tolerance = 5e-15,
                         check.attributes = FALSE)),
        paste(id, "species CSV disagrees with its RDS."))
  known_rows <- known[match(species$species_id, candidate_ids)]
  check(all(species$known_member == known_rows) &&
          all(species$detection_probability >= 0 &
                species$detection_probability <= 1),
        paste(id, "saved known flags or species probabilities are invalid."))
  check(all(is.infinite(species$log_discovery_probability[known_rows])) &&
          all(is.infinite(species$log_first_discovery_bin_probability[known_rows])) &&
          all(is.finite(species$log_detection_probability)) &&
          all(is.finite(species$log_nondetection_probability)) &&
          all(is.finite(species$log_discovery_probability[!known_rows])) &&
          all(is.finite(species$log_first_discovery_bin_probability[!known_rows])),
        paste(id, "species-level structural zeros are not exactly the known-species zeros."))
  unseen_table <- species[!known_rows, ]
  for (h in horizons) {
    z <- unseen_table[unseen_table$horizon == h, ]
    check(length(unique(z$log_detection_probability)) == 1L &&
            length(unique(z$log_nondetection_probability)) == 1L &&
            length(unique(z$log_first_discovery_bin_probability)) == 1L,
          paste(id, "does not preserve exact unseen-label symmetry."))
  }
  first_bins <- vapply(horizons, function(h) unique(
    unseen_table$first_discovery_bin_probability[unseen_table$horizon == h]
  ), numeric(1))
  final_detection <- unique(unseen_table$detection_probability[
    unseen_table$horizon == max(horizons)
  ])
  check(abs(sum(first_bins) - final_detection) < 5e-14,
        paste(id, "first-discovery bins do not sum to final cumulative probability."))

  counts <- forecast$count_pmfs
  counts_csv <- read.csv(file.path(forecast_root, id, "count-pmfs.csv"),
                         stringsAsFactors = FALSE)
  check(isTRUE(all.equal(counts, counts_csv, tolerance = 5e-15,
                         check.attributes = FALSE)),
        paste(id, "count-PMF CSV disagrees with its RDS."))
  groups <- split(counts, keys(counts, c("target", "group", "horizon")))
  for (g in groups) {
    normalizer <- logsumexp(g$log_probability)
    support_ok <- identical(as.integer(g$count), seq.int(0L, nrow(g) - 1L))
    probability_error <- max(abs(g$probability - exp(g$log_probability)))
    pmf_rows[[length(pmf_rows) + 1L]] <- data.frame(
      model_id = id, target = g$target[1L], group = g$group[1L],
      horizon = g$horizon[1L], support_ok = support_ok,
      log_normalizer = normalizer, probability_error = probability_error,
      n_negative_infinity = sum(is.infinite(g$log_probability) &
                                  g$log_probability < 0)
    )
    check(support_ok && is.finite(normalizer) && abs(normalizer) < 5e-13 &&
            probability_error < 5e-15 && all(g$log_probability <= 0),
          paste(id, "has an invalid saved count PMF."))
  }

  # Independent replay of every 101-week discovery-count mass from the saved
  # conditional probabilities. This also supplies chain-aware integration MCSE.
  h <- match(101L, horizons)
  conditional_mass <- conditional_poibin(
    matrix(ld[, !known, h], nrow = D),
    matrix(ln[, !known, h], nrow = D)
  )
  replay <- colMeans(conditional_mass)
  saved <- counts[counts$target == "totaldiscovery" &
                    counts$group == "all" & counts$horizon == 101L, ]
  saved <- saved[order(saved$count), ]
  mean_probability_pmf <- poibin_from_means(colMeans(exp(ld[, !known, h])))
  check(max(abs(replay - saved$probability)) < 2e-13,
        paste(id, "101-week discovery PMF failed independent replay."))
  for (k in seq_along(replay)) {
    diagnostic <- mcse_log_mean(conditional_mass[, k])
    replay_rows[[length(replay_rows) + 1L]] <- data.frame(
      model_id = id, count = k - 1L,
      saved_probability = saved$probability[k], replay_probability = replay[k],
      absolute_replay_error = abs(saved$probability[k] - replay[k]),
      mean_probability_pmf = mean_probability_pmf[k],
      absolute_mean_probability_error = abs(saved$probability[k] -
                                              mean_probability_pmf[k])
    )
    mcse_rows[[length(mcse_rows) + 1L]] <- data.frame(
      model_id = id, role = manifest$role[m], horizon = 101L,
      target = "totaldiscovery", count = k - 1L,
      log_probability = saved$log_probability[k],
      log_probability_mcse = diagnostic[["log_mcse"]],
      ess_mean = diagnostic[["ess_mean"]], rhat = diagnostic[["rhat"]],
      chain_recovery = "four contiguous chains from preserved as_draws_matrix row order"
    )
  }

  # Exact seeded replay of the illustrative paths, including nested horizons.
  path <- read.csv(file.path(forecast_root, id, "joint-count-paths.csv"),
                   stringsAsFactors = FALSE)
  replay_path <- withr::with_seed(as.integer(manifest$path_seed[m]), {
    log_u <- matrix(log(runif(D * 50L)), D, 50L)
    do.call(rbind, lapply(seq_along(horizons), function(j) {
      seen <- log_u < matrix(ld[, , j], D, 50L)
      data.frame(
        draw_index = seq_len(D), horizon = horizons[j],
        totaldiscovery = rowSums(seen[, !known, drop = FALSE]),
        redetection = rowSums(seen[, known, drop = FALSE]),
        all_detection = rowSums(seen)
      )
    }))
  }, .rng_kind = "Mersenne-Twister", .rng_normal_kind = "Inversion",
  .rng_sample_kind = "Rejection")
  check(isTRUE(all.equal(path, replay_path, tolerance = 0,
                         check.attributes = FALSE)) &&
          all(path$all_detection == path$totaldiscovery + path$redetection) &&
          all(vapply(split(path, path$draw_index), function(z) {
            all(diff(z$totaldiscovery) >= 0L) &&
              all(diff(z$redetection) >= 0L) &&
              all(diff(z$all_detection) >= 0L)
          }, logical(1))),
        paste(id, "seeded joint paths failed exact replay or nesting."))

  model_rows[[m]] <- data.frame(
    model_id = id, role = manifest$role[m], draw_count = D,
    interaction_included = forecast$metadata$interaction_included,
    candidate_count = 50L, known_count = sum(known), unseen_count = sum(!known),
    max_per_draw_complement_error = complement_error,
    detection_negative_infinity = sum(is.infinite(ld) & ld < 0),
    nondetection_negative_infinity = sum(is.infinite(ln) & ln < 0),
    path_rows = nrow(path), path_seed = manifest$path_seed[m]
  )
  rm(forecast, parent_draws, ld, ln, conditional_mass)
  gc(verbose = FALSE)
}

model_audit <- do.call(rbind, model_rows)
pmf_audit <- do.call(rbind, pmf_rows)
pmf_replay <- do.call(rbind, replay_rows)
mcse <- do.call(rbind, mcse_rows)
primary_mcse <- merge(
  mcse[mcse$model_id == "baseline_primary",
       c("count", "log_probability", "log_probability_mcse")],
  mcse[mcse$model_id == "spatial_primary",
       c("count", "log_probability", "log_probability_mcse")],
  by = "count", suffixes = c("_baseline", "_spatial")
)
primary_mcse$spatial_minus_baseline_log_probability <-
  primary_mcse$log_probability_spatial - primary_mcse$log_probability_baseline
primary_mcse$conservative_difference_mcse <- sqrt(
  primary_mcse$log_probability_mcse_baseline^2 +
    primary_mcse$log_probability_mcse_spatial^2
)

dir.create(audit_root, recursive = TRUE)
write.csv(rbind(input_hashes, output_hashes),
          file.path(audit_root, "hash-verification.csv"), row.names = FALSE)
write.csv(model_audit, file.path(audit_root, "model-audit.csv"), row.names = FALSE)
write.csv(pmf_audit, file.path(audit_root, "pmf-normalization.csv"), row.names = FALSE)
write.csv(pmf_replay, file.path(audit_root, "discovery-pmf-replay.csv"), row.names = FALSE)
write.csv(mcse, file.path(audit_root, "discovery-logpmf-mcse.csv"), row.names = FALSE)
write.csv(primary_mcse, file.path(audit_root, "primary-logpmf-contrast-mcse.csv"),
          row.names = FALSE)
writeLines(c(
  "status=AUDIT_PASS",
  "verdict=GO_FOR_OUTCOME_ACCESS_AFTER_COMMITTED_AUDIT",
  paste0("generation_commit=", generation_commit),
  paste0("prediction_archive_commit=", archive_commit),
  paste0("prediction_archive_sha256=", archive_sha256),
  "later_judbury_outcomes_read=false",
  "huon_ridge_read=false",
  "all_six_models_complete=true",
  "all_hashes_match=true",
  "all_probability_invariants_pass=true",
  "all_seeded_paths_exact=true"
), file.path(audit_root, "completion-status.txt"))

cat("Goal011 frozen prediction-object audit: PASS\n")
cat("GO for bounded Judbury outcome access after this audit is committed.\n")
cat("Audit output:", audit_root, "\n")
