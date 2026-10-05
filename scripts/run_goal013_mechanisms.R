#!/usr/bin/env Rscript
# Frozen simulation recovery; empirical records are used only as a known design.
options(warn = 2)
source("R/goal013_mechanisms.R")
source("R/goal013_scoring.R")
source("R/goal013_diagnostics.R")
args <- commandArgs(trailingOnly = TRUE)
mode <- if (length(args)) args[[1L]] else "check"
dest <- if (length(args) > 1L) args[[2L]] else "outputs/goal013/recovery-v1"
stopifnot(length(args) <= 2L, mode %in% c("check", "smoke", "run"))
hash <- function(x) digest::digest(file = x, algo = "sha256", serialize = FALSE)
receipts <- read.csv("config/goal013_inputs.csv", stringsAsFactors = FALSE)
stopifnot(!anyDuplicated(receipts$path), all(vapply(receipts$path, hash, "") == receipts$sha256))
design <- readRDS("config/goal013_design.rds")
cal <- readRDS("config/goal013_calibration.rds")
manifest <- read.csv("config/goal013_run_manifest.csv", stringsAsFactors = FALSE)
models <- c("static", "harmonic", "array", "station")
stopifnot(nrow(manifest) == 500L, !anyDuplicated(manifest$job_id),
  !anyDuplicated(manifest$seed), identical(dim(cal$service_probability), dim(design$y)),
  all(table(manifest$truth) == 100),
  identical(is.na(cal$service_probability), design$effort == 0))
invisible(.goal013_validate_data(design))
invisible(goal013_probabilities(design, "static")) # Compile once, before fork.
if (mode == "check") {cat("PASS: frozen inputs, 500-job manifest and numerical kernel load\n"); quit(status = 0)}
if (mode == "smoke") {
  # An integration test, not a recovery replicate: two species and stations.
  selected_species <- vapply(c("Aves", "Mammalia"), function(cl) {
    candidates <- which(design$species$taxon_class == cl)
    candidates[which.max(design$species$positive_cells[candidates])]
  }, integer(1))
  selected_stations <- unique(design$rows$camera_id)[1:2]
  ix <- which(design$row_species %in% selected_species & design$rows$camera_id %in% selected_stations)
  old_species <- design$row_species[ix]
  for (nm in c("y", "effort", "group")) design[[nm]] <- design[[nm]][ix, , drop = FALSE]
  groups <- sort(unique(as.vector(design$group[design$group > 0])))
  design$target <- design$target[groups]
  design$group[,] <- ifelse(design$group == 0, 0L, match(design$group, groups))
  selected_species <- sort(selected_species)
  design$row_species <- match(old_species, selected_species)
  design$row_class <- design$row_class[ix]
  design$rows <- design$rows[ix, ]
  design$species <- design$species[selected_species, ]
  cal$service_probability <- cal$service_probability[ix, , drop = FALSE]
}
if (mode == "run") {
  dirty <- system2("git", c("status", "--porcelain", "--untracked-files=no"), stdout = TRUE)
  if (length(dirty)) stop("Run requires a committed clean tracked tree")
  if (Sys.info()[["nodename"]] != "deep-server" || !nzchar(Sys.getenv("TMUX")))
    stop("Production recovery runs on deep-server in tmux")
}
if (file.exists(dest)) stop("Refusing to overwrite recovery output")
dir.create(dest, recursive = TRUE)
options(error = function() {
  writeLines(c("ERROR: preserve outputs before repair", geterrmessage()), file.path(dest, "STATUS.txt"))
  quit(status = 1)
})
writeLines(c(paste("STARTED", format(Sys.time(), tz = "UTC", usetz = TRUE)),
  paste("mode", mode), paste("source_head", system2("git", c("rev-parse", "HEAD"), stdout = TRUE)),
  "scope known-member temporal oracle ceiling; no empirical model fit",
  "full-period placement margins known to every candidate",
  "raw_observations_read false; huon_ridge_read false"), file.path(dest, "metadata.txt"))
file.copy("config/goal013_inputs.csv", file.path(dest, "input-sha256.csv"))
capture.output(sessionInfo(), file = file.path(dest, "session-info.txt"))
jobs <- if (mode == "smoke") manifest[1L, , drop = FALSE] else manifest
write.csv(jobs, file.path(dest, "executed-manifest.csv"), row.names = FALSE)
status <- function(x) writeLines(x, file.path(dest, "STATUS.txt"))
status(paste("RUNNING", nrow(jobs), "datasets"))
pair_plan <- goal013_pair_plan(design)
write.csv(goal013_pair_statistics(design$y, pair_plan),
  file.path(dest, "observed-fingerprints.csv"), row.names = FALSE)

run_job <- function(k) {
  job <- jobs[k, ]; out <- file.path(dest, job$job_id)
  dir.create(out)
  writeLines("RUNNING", file.path(out, "STATUS.txt"))
  cat("START", job$job_id, "seed", job$seed, "\n"); flush.console()
  tryCatch({
    d <- design
    if (job$truth == "service_stress") {
      set.seed(job$seed)
      d$y[,] <- NA_real_; ok <- d$effort > 0
      d$y[ok] <- rbinom(sum(ok), 1, cal$service_probability[ok])
    } else d$y <- goal013_simulate(d, job$truth,
      cal$truth_parameters[[job$truth]], seed = job$seed)$y
    stopifnot(identical(is.na(d$y), d$effort == 0))
    saveRDS(d$y, file.path(out, "simulated-y.rds"))
    write.csv(goal013_pair_statistics(d$y, pair_plan),
      file.path(out, "fingerprints.csv"), row.names = FALSE)
    fits <- list(); scores <- list(); counts <- list(); events <- list(); starts <- list()
    decisions <- list()
    for (origin in c(52L, 104L)) {
      current <- numeric(4); names(current) <- models
      converged <- logical(4); names(converged) <- models
      training <- vapply(seq_len(nrow(d$species)), function(s)
        any(d$y[d$row_species == s, seq_len(origin)] == 1, na.rm = TRUE), logical(1))
      for (model in models) {
        fit <- goal013_fit(d, model, train_end = origin)
        id <- paste(origin, model, sep = ":")
        fits[[id]] <- fit
        current[model] <- goal013_loglik(d, model, fit$theta, end = ncol(d$y)) - fit$loglik_train
        converged[model] <- fit$convergence == 0L && is.finite(current[model])
        scores[[id]] <- data.frame(job_id = job$job_id, truth = job$truth,
          replicate = job$replicate, origin, model,
          loglik_train = fit$loglik_train, joint_future_logscore = current[model],
          convergence = fit$convergence,
          theta = paste(format(fit$theta, digits = 16), collapse = ";"),
          boundary = paste(names(fit$boundary)[fit$boundary], collapse = ";"))
        starts[[id]] <- cbind(data.frame(origin, model), fit$starts)
        horizons <- if (origin == 52L) c(13L, 26L, 52L, 101L) else 49L
        for (horizon in horizons) {
          p <- goal013_forecast_events(d, model, fit$theta, origin, horizon)
          observed <- vapply(seq_len(nrow(d$species)), function(s)
            as.integer(any(d$y[d$row_species == s, (origin + 1L):(origin + horizon)] == 1,
                           na.rm = TRUE)), integer(1))
          eid <- paste(id, horizon, sep = ":")
          events[[eid]] <- data.frame(job_id = job$job_id, truth = job$truth,
            replicate = job$replicate, origin, horizon, model,
            species_id = d$species$species_id, training_detected = training,
            probability = p, observed)
          cohorts <- list(all_known = rep(TRUE, length(p)),
            training_detected = training, training_undetected = !training)
          for (cohort in names(cohorts)) {
            ix <- cohorts[[cohort]]
            counts[[paste(eid, cohort, sep = ":")]] <- cbind(data.frame(
              job_id = job$job_id, truth = job$truth, replicate = job$replicate,
              origin, horizon, model, cohort), goal013_score_events(p[ix], observed[ix]))
          }
        }
        # Save after each fit so the first startup verification shows actual work.
        write.csv(do.call(rbind, scores), file.path(out, "scores.csv"), row.names = FALSE)
      }
      decisions[[as.character(origin)]] <- data.frame(job_id = job$job_id,
        truth = job$truth, replicate = job$replicate, origin,
        selected = goal013_select(current, converged, cal$selection_margin_nats))
    }
    saveRDS(fits, file.path(out, "fits.rds"))
    write.csv(do.call(rbind, starts), file.path(out, "fit-starts.csv"), row.names = FALSE)
    write.csv(do.call(rbind, counts), file.path(out, "event-counts.csv"), row.names = FALSE)
    write.csv(do.call(rbind, events), file.path(out, "species-event-probabilities.csv"), row.names = FALSE)
    write.csv(do.call(rbind, decisions), file.path(out, "selection.csv"), row.names = FALSE)
    bad <- any(vapply(decisions, function(z) z$selected == "numerical_failure", logical(1)))
    writeLines(if (bad) "COMPLETE_WITH_NUMERICAL_FAILURE" else "COMPLETE", file.path(out, "STATUS.txt"))
    cat(job$job_id, "complete;", paste(vapply(decisions, function(z) z$selected, ""), collapse = ", "), "\n")
    flush.console()
    list(job_id = job$job_id, success = TRUE, numerical_failure = bad)
  }, error = function(e) {
    writeLines(c("ERROR", conditionMessage(e)), file.path(out, "STATUS.txt"))
    cat(job$job_id, "ERROR:", conditionMessage(e), "\n"); flush.console()
    list(job_id = job$job_id, success = FALSE, numerical_failure = TRUE)
  })
}
workers <- if (mode == "smoke") 1L else as.integer(Sys.getenv("GOAL013_WORKERS", "8"))
stopifnot(is.finite(workers), workers >= 1L, workers <= 8L)
ans <- parallel::mclapply(seq_len(nrow(jobs)), run_job, mc.cores = workers,
  mc.preschedule = FALSE, mc.set.seed = FALSE)
failed <- vapply(ans, function(z) !is.list(z) || !isTRUE(z$success), logical(1))
write.csv(data.frame(job_id = jobs$job_id, completed = !failed),
  file.path(dest, "job-status.csv"), row.names = FALSE)
if (any(failed)) {
  status(paste("INCOMPLETE", sum(failed), "job errors; preserve before repair"))
  quit(status = 1)
}
read_all <- function(name) do.call(rbind, lapply(jobs$job_id,
  function(j) read.csv(file.path(dest, j, name), stringsAsFactors = FALSE)))
selection <- read_all("selection.csv")
counts <- read_all("event-counts.csv")
scores <- read_all("scores.csv")
fingerprints <- do.call(rbind, lapply(seq_len(nrow(jobs)), function(k) {
  z <- read.csv(file.path(dest, jobs$job_id[k], "fingerprints.csv"))
  info <- jobs[rep(k, nrow(z)), , drop = FALSE]
  rownames(info) <- NULL
  cbind(info, z)
}))
write.csv(fingerprints, file.path(dest, "fingerprints.csv"), row.names = FALSE)
write.csv(selection, file.path(dest, "selections.csv"), row.names = FALSE)
write.csv(counts, file.path(dest, "event-counts.csv"), row.names = FALSE)
write.csv(scores, file.path(dest, "scores.csv"), row.names = FALSE)
recovery <- do.call(rbind, lapply(split(selection, interaction(selection$truth, selection$origin, drop = TRUE)), function(z) {
  do.call(rbind, lapply(c("static_compatible", "harmonic", "array", "station", "unresolved", "numerical_failure"), function(choice)
    cbind(data.frame(truth = z$truth[1], origin = z$origin[1], selected = choice),
      goal013_binomial_summary(sum(z$selected == choice), nrow(z)))))
}))
coverage <- do.call(rbind, lapply(split(counts, interaction(counts$truth, counts$origin,
  counts$horizon, counts$model, counts$cohort, drop = TRUE)), function(z) {
    cbind(z[1, c("truth", "origin", "horizon", "model", "cohort")],
      goal013_binomial_summary(sum(z$covered90), nrow(z)),
      mean_brier = mean(z$brier, na.rm = TRUE), mean_log_probability = mean(z$log_probability))
}))
write.csv(recovery, file.path(dest, "recovery-summary.csv"), row.names = FALSE)
write.csv(coverage, file.path(dest, "coverage-summary.csv"), row.names = FALSE)
numeric_fail <- any(selection$selected == "numerical_failure")
status(paste(if (numeric_fail) "COMPLETE_WITH_NUMERICAL_FAILURES" else "COMPLETE",
  nrow(jobs), "datasets; scientific adjudication pending"))
files <- sort(list.files(dest, recursive = TRUE, full.names = TRUE))
write.csv(data.frame(path = substring(files, nchar(dest) + 2L),
  sha256 = vapply(files, hash, "")), file.path(dest, "output-sha256.csv"), row.names = FALSE)
cat("Finished", nrow(jobs), "datasets; scientific interpretation remains separate.\n")
