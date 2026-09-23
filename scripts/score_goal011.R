# Read bounded later Judbury observations only after the committed prediction audit.
options(warn = 2)
options(error = function() {
  if (exists("dest", envir = .GlobalEnv, inherits = FALSE))
    writeLines("FAILED: preserve assessment evidence", file.path(dest, "STATUS.txt"))
  quit(save = "no", status = 1L)
})
for (p in sort(list.files("R", pattern = "[.]R$", full.names = TRUE))) source(p)
args <- commandArgs(trailingOnly = TRUE)
out <- if (length(args)) args[1L] else "outputs/goal011/assessment-v1"
stopifnot(length(args) <= 1L)
root <- normalizePath(".")
base <- "outputs/goal011/forecast-v1"
evidence <- "docs/goals/011-frozen-temporal-forecasts/evidence/goal011-frozen-predictions.tar.gz"
archive_hash <- "13f1482a7e926606d20197ca1d5bf127b172d0f5bd6547c583d6a2c8c8bb2ae2"
audit_path <- "docs/goals/011-frozen-temporal-forecasts/PredictionAudit.md"
if (length(system2("git", c("status", "--porcelain"), stdout = TRUE))) stop("Dirty checkout")
stopifnot(system2("git", c("cat-file", "-e", paste0("HEAD:", evidence))) == 0L,
  system2("git", c("cat-file", "-e", paste0("HEAD:", audit_path))) == 0L,
  identical(digest::digest(file = evidence, algo = "sha256", serialize = FALSE), archive_hash),
  any(grepl("GO.*outcome access", readLines(audit_path), ignore.case = TRUE)))
receipts <- read.csv(file.path(base, "output-sha256.csv"))
for (i in seq_len(nrow(receipts))) stopifnot(identical(
  digest::digest(file = file.path(base, receipts$path[i]), algo = "sha256", serialize = FALSE),
  receipts$sha256[i]))
inputs <- read.csv(file.path(base, "input-receipts.csv"))
# Only verify parent files consumed by this assessment; refitting inputs are
# already recorded in the frozen forecasts and are unnecessary for scoring.
inputs <- inputs[!grepl("prediction-draws[.]rds$|fit-status[.]csv$", inputs$path), ]
for (i in seq_len(nrow(inputs))) stopifnot(identical(
  digest::digest(file = inputs$path[i], algo = "sha256", serialize = FALSE), inputs$sha256[i]))
stopifnot(all(read.csv(file.path(base, "model-status.csv"))$status == "predictions_complete_unscored"))
source_root <- "/home/bwbrook/git/camtrap-workflow"
source_receipts <- verify_goal006_source_receipts(source_root)
contract <- read_goal006_task1_contract(root = root, source_root = source_root, verify_external = FALSE)
models <- read.csv(file.path(base, "model-manifest.csv"))
dev <- goal009_read_development()
# Preserve the scoring function byte-for-byte from the prediction freeze.
frozen_scorer <- system2("git", c("show", "033c21a:R/goal011_scoring.R"), stdout = TRUE)
stopifnot(identical(readLines("R/goal011_scoring.R"), frozen_scorer))
dest <- .goal003_prepare_output_directory(out, "goal011_assessment")
writeLines(c(
  paste0("outcome_access_started_utc=", format(Sys.time(), tz = "UTC", usetz = TRUE)),
  paste0("scoring_git_commit=", system2("git", c("rev-parse", "HEAD"), stdout = TRUE)),
  paste0("prediction_archive_sha256=", archive_hash),
  paste0("prediction_archive_commit=", system2("git", c("log", "-1", "--format=%H", "--", evidence), stdout = TRUE)),
  "prediction_generation_commit=033c21ac13bb830d34e31d40698e5f6a0b4dda6d",
  paste0("observation_source=", source_root, "/data/jc_obs.csv"),
  "bounded_period=2019-06-05_inclusive_to_2022-05-11_exclusive_fixed_UTC+10",
  "outcome_period=occasions_53:153; first_52_reconstructed_for_identity_bridge",
  "event_definition=canonical_15_minute_gap_assigned_to_event_start",
  "effort=retrospective_conditional_on_reviewed_realised_effort",
  "model_refitted=false", "priors_changed=false", "huon_ridge_read=false",
  "historical_exposure=Goal008_three_rows_and_prior_aggregate_disclosures"),
  file.path(dest, "outcome-access.txt"))
write.csv(source_receipts, file.path(dest, "source-receipts.csv"), row.names = FALSE)
writeLines("RUNNING: bounded outcome extraction", file.path(dest, "STATUS.txt"))
protocol <- new.env(parent = globalenv())
sys.source(file.path(source_root, "R", "time_utils.R"), envir = protocol)
setwd(source_root)
tryCatch(sys.source(file.path(source_root, "R", "custom_funcs.R"), envir = protocol),
         finally = setwd(root))
# First semantic access to later observations follows the receipt above.
built <- goal011_build_bounded_weekly(
  .goal008_read_csv(file.path(source_root, "data", "jc_obs.csv")),
  .goal008_read_csv(file.path(source_root, "data", "jc_op.csv")),
  .goal008_read_csv(file.path(source_root, "data", "jc_taxa.csv")),
  .goal008_read_csv(file.path(source_root, "docs/goals/009-analysis-site-vertical-slice/judbury_analysis_site_mapping.csv")),
  data.frame(species_id = dev$data$candidate_ids), protocol)
w <- built$weekly
key <- function(x) do.call(paste, c(x, sep = "/"))
early <- w$detections[w$detections$occasion_id %in% sprintf("occ_%03d", 1:52), ]
reference <- read.csv("outputs/goal008/development-v1/detections_weekly.csv")
keys <- c("species_id", "camera_id", "occasion_id")
stopifnot(nrow(early) == nrow(reference), setequal(key(early[keys]), key(reference[keys])),
  identical(as.integer(early$detected[match(key(reference[keys]), key(early[keys]))]),
            as.integer(reference$detected)))
ek <- c("camera_id", "occasion_id")
stopifnot(nrow(w$effort_weekly) == nrow(contract$effort),
  identical(w$effort_weekly$active_days[match(key(contract$effort[ek]), key(w$effort_weekly[ek]))],
            contract$effort$active_days))
future_effort <- read.csv("config/goal011_future_effort.csv")
stopifnot(identical(
  w$effort_weekly$active_days[match(key(future_effort[ek]), key(w$effort_weekly[ek]))],
  future_effort$active_days))
calendar <- w$occasion_calendar
frozen_calendar <- read.csv("config/goal011_future_calendar.csv")
stopifnot(identical(as.character(calendar$start_date[53:153]), frozen_calendar$start_date),
  identical(as.character(calendar$end_date[53:153]), frozen_calendar$end_date))
# Independently aggregate canonical event rows, then bridge to the weekly table.
observed <- goal011_build_outcomes(built$events,
  data.frame(species_id = dev$data$candidate_ids), contract$effort, calendar)
stopifnot(identical(observed$first52_outcomes$detected,
                   as.integer(dev$data$stan_data$detected_ever)))
outcomes <- observed$future_outcomes
for (i in seq_len(nrow(outcomes))) {
  ids <- sprintf("occ_%03d", 53:(52L + outcomes$horizon[i]))
  direct <- any(w$detections$detected[w$detections$species_id == outcomes$species_id[i] &
    w$detections$occasion_id %in% ids] == 1L, na.rm = TRUE)
  stopifnot(outcomes$detected[i] == as.integer(direct))
}
write.csv(outcomes, file.path(dest, "outcomes.csv"), row.names = FALSE)
write.csv(built$audit, file.path(dest, "observation-audit.csv"), row.names = FALSE)
write.csv(built$excluded_taxa, file.path(dest, "excluded-taxa.csv"), row.names = FALSE)
write.csv(data.frame(check = c("first52_all_incidence_cells", "full_effort", "future_calendar",
                              "first52_membership", "event_weekly_outcome_agreement"),
                    passed = TRUE), file.path(dest, "input-bridge.csv"), row.names = FALSE)
future <- w$detections[!w$detections$occasion_id %in% sprintf("occ_%03d", 1:52), ]
write.csv(future, file.path(dest, "future-detections-weekly.csv"), row.names = FALSE)
new_ids <- dev$data$candidate_ids[dev$data$stan_data$detected_ever == 0L]
discoveries <- observed$presence |>
  dplyr::filter(species_id %in% new_ids, occasion_index > 52L) |>
  dplyr::summarise(first_occasion = min(occasion_index), first_date = min(event_date), .by = species_id) |>
  dplyr::left_join(dev$labels, by = "species_id") |>
  dplyr::arrange(first_date, species_id)
write.csv(discoveries, file.path(dest, "first-discoveries.csv"), row.names = FALSE)
score_tables <- lapply(seq_len(nrow(models)), function(k) {
  f <- readRDS(file.path(base, models$model_id[k], "forecast.rds"))
  s <- goal011_score_forecast(f, outcomes)
  lapply(s, function(table) data.frame(model_id = models$model_id[k], role = models$role[k], table))
})
for (table in c("species_scores", "aggregate_species_scores", "count_scores")) {
  rows <- lapply(score_tables, `[[`, table)
  write.csv(do.call(rbind, rows), file.path(dest, paste0(gsub("_", "-", table), ".csv")), row.names = FALSE)
}
count <- read.csv(file.path(dest, "count-scores.csv"))
focal <- subset(count, role == "main" & target == "totaldiscovery" & horizon == 101L)
contrast <- focal$negative_log_score[focal$model_id == "spatial_primary"] -
  focal$negative_log_score[focal$model_id == "baseline_primary"]
write.csv(data.frame(contrast = "spatial_minus_baseline_discovery_count_NLS_at101weeks", value = contrast),
          file.path(dest, "focal-contrast.csv"), row.names = FALSE)
capture.output(sessionInfo(), file = file.path(dest, "session-info.txt"))
writeLines("COMPLETE: frozen forecasts scored; interpretation required", file.path(dest, "STATUS.txt"))
files <- sort(list.files(dest, recursive = TRUE, full.names = TRUE))
write.csv(data.frame(path = substring(files, nchar(dest) + 2L), sha256 = vapply(files,
  function(p) digest::digest(file = p, algo = "sha256", serialize = FALSE), character(1))),
  file.path(dest, "output-sha256.csv"), row.names = FALSE)
print(focal)
cat("Focal spatial-minus-baseline count negative log score:", contrast, "\n")
