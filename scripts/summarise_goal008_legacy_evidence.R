# Retrospective decomposition of frozen synthetic scores; no model/data rerun.
root <- "outputs/goal005/task2-information-ceiling-v1/results"
out <- "outputs/goal008/legacy-v1"
if (dir.exists(out)) stop("Legacy output exists; choose a new version to rerun.")
paths <- file.path(root, c("richness-scores.csv", "dataset-status.csv"))
if (!all(file.exists(paths))) stop("Frozen Goal005 compact results are missing.")
scores <- read.csv(paths[1], stringsAsFactors = FALSE)
datasets <- read.csv(paths[2], stringsAsFactors = FALSE)
stopifnot(!anyDuplicated(datasets$dataset_id), nrow(datasets) == 180L)
scores <- scores[scores$run_role != "prior_only", ]
stopifnot(nrow(scores) == 360L, !anyDuplicated(scores$fit_id))
idx <- match(scores$dataset_id, datasets$dataset_id)
stopifnot(!anyNA(idx), all(scores$true_richness == datasets$true_richness[idx]))
keep <- c("train_occasions", "training_active_camera_days", "active_camera_count",
          "replicate", "pair_id")
joined <- cbind(scores, datasets[idx, keep, drop = FALSE])
stopifnot(all(joined$terminal_clean), all(joined$prediction_available))
joined$catastrophic <- joined$absolute_error >= 12.5
groups <- split(joined, interaction(joined$information_level,
  joined$train_occasions, joined$training_active_camera_days,
  joined$active_camera_count, drop = TRUE))
summary <- do.call(rbind, lapply(groups, function(x) data.frame(
  information_level = x$information_level[1], weeks = x$train_occasions[1],
  active_camera_days = x$training_active_camera_days[1],
  active_cameras = x$active_camera_count[1], fits = nrow(x),
  ecological_streams = length(unique(x$pair_id)),
  median_absolute_error = median(x$absolute_error),
  maximum_absolute_error = max(x$absolute_error),
  covered = sum(x$interval_90_covered),
  median_interval_width = median(x$interval_90_width),
  catastrophic = sum(x$catastrophic))))
summary <- summary[order(summary$weeks, summary$active_camera_days,
                         summary$information_level), ]
catastrophes <- joined[joined$train_occasions %in% c(4L, 8L) &
                        joined$catastrophic, ]
dir.create(out, recursive = TRUE)
write.csv(summary, file.path(out, "oracle-effort-summary.csv"), row.names = FALSE)
write.csv(catastrophes, file.path(out, "short-window-catastrophes.csv"),
          row.names = FALSE)
provenance_paths <- c(paths, "scripts/summarise_goal008_legacy_evidence.R")
write.csv(data.frame(path = provenance_paths, sha256 = vapply(provenance_paths,
  function(p) digest::digest(file = p, algo = "sha256", serialize = FALSE), "")),
  file.path(out, "source-hashes.csv"), row.names = FALSE)
writeLines(c(
  "Retrospective descriptive decomposition; no historical gate is changed.",
  "Effort groupings describe these existing runs, not a validated effort threshold.",
  "Richness scenarios and durations share streams; fit counts are not independent replicates.",
  "No empirical observations or new synthetic realisations were used."
), file.path(out, "interpretation.txt"))
cat("Frozen short-window oracle catastrophes:", nrow(catastrophes), "\n")
print(unique(catastrophes[c("train_occasions", "training_active_camera_days",
                           "active_camera_count")]), row.names = FALSE)
