# Correct predictive postprocessing from frozen posterior draws; no refitting.
options(warn = 2)
for (path in sort(list.files("R", pattern = "\\.R$", full.names = TRUE))) source(path)
invisible(loadNamespace("posterior")) # Exercise the draw-class regression path.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) > 1L) stop("Usage: Rscript scripts/reprocess_goal009_ppc.R [output_dir]")
destination <- if (length(args)) args[[1]] else "outputs/goal009/ppc-repaired-v2"
if (file.exists(destination)) stop("Refusing to replace existing output: ", destination)
if (length(system2("git", c("status", "--porcelain"), stdout = TRUE))) {
  stop("Commit the postprocessing repair before execution.")
}
original <- "outputs/goal009/first-year-v1"
original_commit <- "e183888960c6ff5cdc7146e6549bf876f6e3484a"
stopifnot(paste0("git_commit=", original_commit) %in%
            readLines(file.path(original, "run-metadata.txt")))
receipts <- read.csv("config/goal009_postprocess_inputs.csv")
for (i in seq_len(nrow(receipts))) {
  stopifnot(identical(digest::digest(file = receipts$path[i], algo = "sha256",
                                   serialize = FALSE), receipts$sha256[i]))
}
manifest <- read.csv("config/goal009_fits.csv")
development <- goal009_read_development()
dir.create(destination, recursive = TRUE)
write.csv(receipts, file.path(destination, "input-receipts.csv"), row.names = FALSE)
writeLines(c(
  paste0("git_commit=", system2("git", c("rev-parse", "HEAD"), stdout = TRUE)),
  paste0("original_fit_commit=", original_commit),
  paste0("started_utc=", format(Sys.time(), tz = "UTC", usetz = TRUE)),
  "purpose=correct_draw_class_effort_indexing_in_predictive_simulation",
  "new_sampling=false", "later_outcomes_read=false", "huon_ridge_read=false",
  "warnings_are_errors=true"
), file.path(destination, "run-metadata.txt"))
writeLines("RUNNING: corrected PPC from preserved draws", file.path(destination, "STATUS.txt"))
for (k in seq_len(nrow(manifest))) {
  spec <- manifest[k, ]
  fit_dir <- file.path(destination, spec$fit_id)
  dir.create(fit_dir)
  draws <- readRDS(file.path(original, spec$fit_id, "prediction-draws.rds"))
  stopifnot(identical(draws$candidate_ids, development$data$candidate_ids),
            identical(draws$camera_ids, development$data$camera_ids))
  ppc <- goal009_ppc(development$data, draws$q_member, draws$alpha,
                    draws$camera_effect, development$labels,
                    as.integer(spec$ppc_seed), as.integer(spec$ppc_draws))
  fields <- c(summary = "ppc-summary.csv", draw_statistics = "ppc-draw-statistics.csv",
              species_station = "ppc-species-station.csv", species_counts = "ppc-species-counts.csv",
              species_block = "ppc-species-block.csv")
  for (field in names(fields)) write.csv(ppc[[field]], file.path(fit_dir, fields[[field]]),
                                        row.names = FALSE)
  saveRDS(ppc$metadata, file.path(fit_dir, "ppc-metadata.rds"))
  # Recheck the separate latent calculation; it explicitly coerces each vector.
  plain_q <- matrix(as.numeric(draws$q_member), nrow = nrow(draws$q_member))
  latent <- .goal003_mean_poisson_binomial(plain_q)
  preserved <- read.csv(file.path(original, spec$fit_id, "latent-richness-pmf.csv"))
  stopifnot(isTRUE(all.equal(as.data.frame(latent), preserved, tolerance = 1e-12)))
  writeLines("PASS: latent PMF unchanged within 1e-12", file.path(fit_dir, "latent-check.txt"))
  cat("Corrected", spec$fit_id, "without warnings or new sampling\n")
  flush.console()
}
capture.output(sessionInfo(), file = file.path(destination, "session-info.txt"))
writeLines("COMPLETE: corrected PPC; original fits preserved", file.path(destination, "STATUS.txt"))
