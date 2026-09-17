# Exploratory figures and closeout receipts from restricted Goal008 outputs.
# This script never opens raw observations or later-period data.
input <- "outputs/goal008/development-v1"
output <- "outputs/goal008/synthesis-v2"
if (dir.exists(output)) stop("Synthesis output exists; choose a new version to rerun.")
files <- file.path(input, c("effort_weekly.csv", "detections_weekly.csv",
  "weekly_effort.csv", "observed_accumulation.csv"))
stopifnot(all(file.exists(files)))
effort <- read.csv(files[1], stringsAsFactors = FALSE)
y <- read.csv(files[2], stringsAsFactors = FALSE)
weekly <- read.csv(files[3], stringsAsFactors = FALSE)
accumulation <- read.csv(files[4], stringsAsFactors = FALSE)
stopifnot(max(weekly$occasion_index) == 52L,
          max(as.Date(weekly$end_date)) == as.Date("2020-06-02"))

# Chosen after viewing early-development station summaries, not a held-out test.
# Match calendar occasions and complete effort to remove two obvious sources
# of differing incidence denominators; temporal dependence is not removed.
stations <- c("jc_pm12", "jc_pm23")
occasions <- Reduce(intersect, lapply(stations, function(station) {
  effort$occasion_id[effort$camera_id == station & effort$active_days == 7L]
}))
stopifnot(length(occasions) > 0L)
selected <- y[y$camera_id %in% stations & y$occasion_id %in% occasions, ]
stopifnot(!anyNA(selected$detected),
          nrow(selected) == 50L * 2L * length(occasions))
paired <- aggregate(detected ~ species_id + camera_id, selected, sum)
names(paired)[3] <- "positive_stationweeks"
paired$matched_complete_weeks <- length(occasions)
paired$active_days <- 7L * length(occasions)
paired$incidence_fraction <- paired$positive_stationweeks / length(occasions)
dir.create(output, recursive = TRUE)
write.csv(paired, file.path(output, "matched-station-summary.csv"), row.names = FALSE)
write.csv(data.frame(occasion_id = sort(occasions)),
  file.path(output, "matched-occasions.csv"), row.names = FALSE)

draw_overview <- function() {
  par(mfrow = c(2, 1), mar = c(4.2, 4.3, 3.0, 1.2), oma = c(1.5, 0, 0.5, 0))
  plot(weekly$occasion_index, weekly$active_station_days, type = "h",
       lwd = 3, col = "#2166AC", ylim = c(0, 65), xlim = c(1, 52),
       xlab = "", ylab = "Active station-days", main = "Judbury: first-year effort")
  abline(v = c(13.5, 26.5, 39.5), col = "grey65", lty = 3)
  abline(h = 63, col = "grey55", lty = 2)
  plot(accumulation$occasion_index, accumulation$cumulative_detected_species,
       type = "s", lwd = 2.5, col = "#1B7837", ylim = c(0, 25),
       xlab = "Seven-day occasion (5 June 2019 to 2 June 2020)",
       ylab = "Species detected so far", main = "Observed accumulation")
  abline(v = c(13.5, 26.5, 39.5), col = "grey65", lty = 3)
  mtext("Vertical lines delimit four 13-week blocks; effort is retained as observed.",
        outer = TRUE, side = 1, cex = 0.8)
}
draw_stations <- function() {
  ids <- c("Thylogale billardierii", "Bettongia gaimardi")
  rates <- matrix(NA_real_, 2, 2, dimnames = list(ids, stations))
  positives <- rates
  for (i in seq_along(ids)) for (j in seq_along(stations)) {
    row <- paired[paired$species_id == ids[i] & paired$camera_id == stations[j], ]
    stopifnot(nrow(row) == 1L)
    rates[i, j] <- row$incidence_fraction
    positives[i, j] <- row$positive_stationweeks
  }
  par(mar = c(4, 4.6, 3, 1), oma = c(3.5, 0, 0.5, 0))
  mids <- barplot(rates, beside = TRUE, col = c("#2166AC", "#B35806"),
    ylim = c(0, 1.12), ylab = "Fraction of matched weeks with a detection",
    main = "Observed station use differs between species",
    names.arg = stations, xlab = "Analysis station", border = NA)
  text(mids, rates + 0.045, labels = paste0(positives, "/", length(occasions)))
  legend("top", legend = c("Tasmanian pademelon", "Tasmanian bettong"),
         fill = c("#2166AC", "#B35806"), bty = "n", cex = 0.9)
  mtext(paste(length(occasions), "identical calendar weeks, 7 active days at both stations."),
        side = 1, outer = TRUE, line = 0.3, cex = 0.8)
  mtext("Exploratory example; matched effort does not remove temporal dependence.",
        side = 1, outer = TRUE, line = 1.3, cex = 0.8)
}
for (stem in c("effort-accumulation", "matched-station-example")) {
  draw <- if (stem == "effort-accumulation") draw_overview else draw_stations
  pdf(file.path(output, paste0(stem, ".pdf")), width = 8, height = 6)
  draw(); dev.off()
  png(file.path(output, paste0(stem, ".png")), width = 1920, height = 1440, res = 240)
  draw(); dev.off()
}

# Collected at closeout, not mislabelled as a pre-run commit freeze.
source_files <- c(sort(list.files("R", "\\.R$", full.names = TRUE)),
  "scripts/run_goal008_development.R", "scripts/run_goal008_theory.R",
  "scripts/summarise_goal008_legacy_evidence.R", "scripts/synthesise_goal008.R",
  "renv.lock", files)
write.csv(data.frame(path = source_files, sha256 = vapply(source_files,
  function(path) digest::digest(file = path, algo = "sha256", serialize = FALSE), "")),
  file.path(output, "closeout-source-hashes.csv"), row.names = FALSE)
writeLines(c(
  "Receipt timing: collected retrospectively at Goal008 closeout, after development execution.",
  paste0("Base commit: ", system2("git", c("rev-parse", "HEAD"), stdout = TRUE)),
  "Working tree has uncommitted Goal008 additions; base commit alone cannot reproduce them.",
  "Source hashes include all R modules and the empirical/theory/synthesis runners.",
  "Raw later rows were inadvertently displayed during worker orientation: see Exposure.md.",
  "No later-period observations are included in these calculations or figures."
), file.path(output, "provenance-note.txt"))
capture.output(sessionInfo(), file = file.path(output, "session-info.txt"))
cat("Goal008 synthesis complete; matched calendar weeks:", length(occasions), "\n")
print(paired[paired$species_id %in% c("Thylogale billardierii", "Bettongia gaimardi"), ])
