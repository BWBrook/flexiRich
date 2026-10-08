#!/usr/bin/env Rscript
# Post-hoc assessment of sealed simulations; no fits or new simulated outcomes.
options(warn = 2)
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(ggplot2))
source("R/goal013_scoring.R")
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) <= 2L)
src <- if (length(args)) args[1] else "outputs/goal013/recovery-v1"
dest <- if (length(args) > 1L) args[2] else "outputs/goal013/assessment-v1"
if (file.exists(dest)) stop("Refusing to overwrite assessment output")
read <- function(name) read.csv(file.path(src, name), stringsAsFactors = FALSE)
hash <- function(path) digest::digest(file = path, algo = "sha256", serialize = FALSE)
receipt <- read("output-sha256.csv")
stopifnot(nrow(receipt) == 4513L, !anyDuplicated(receipt$path),
  all(vapply(file.path(src, receipt$path), hash, "") == receipt$sha256))
inputs <- read("input-sha256.csv")
stopifnot(all(vapply(inputs$path, hash, "") == inputs$sha256))
design <- readRDS("config/goal013_design.rds")
cal <- readRDS("config/goal013_calibration.rds")
jobs <- read("executed-manifest.csv")
scores <- read("scores.csv")
counts <- read("event-counts.csv")
selection <- read("selections.csv")
stopifnot(nrow(jobs) == 500L, nrow(scores) == 4000L,
  nrow(counts) == 30000L, nrow(selection) == 1000L,
  all(read("job-status.csv")$completed))
dir.create(dest, recursive = TRUE)
write <- function(x, name) write.csv(x, file.path(dest, name), row.names = FALSE)
q <- function(x, p) unname(quantile(x, p, type = 7))

# Reconstruct count scores from saved species probabilities, and event outcomes
# directly from each saved panel. This also verifies cohort assignment.
events <- vector("list", nrow(jobs))
masses <- vector("list", nrow(jobs))
for (j in seq_len(nrow(jobs))) {
  id <- jobs$job_id[j]
  z <- read(file.path(id, "species-event-probabilities.csv"))
  y <- readRDS(file.path(src, id, "simulated-y.rds"))
  stopifnot(nrow(z) == 520L, identical(is.na(y), design$effort == 0))
  endpoints <- unique(z[c("origin", "horizon")])
  for (k in seq_len(nrow(endpoints))) {
    o <- endpoints$origin[k]; h <- endpoints$horizon[k]
    trained <- vapply(seq_len(nrow(design$species)), function(s)
      any(y[design$row_species == s, seq_len(o)] == 1, na.rm = TRUE), logical(1))
    seen <- vapply(seq_len(nrow(design$species)), function(s)
      any(y[design$row_species == s, (o + 1):(o + h)] == 1, na.rm = TRUE), logical(1))
    ix <- z$origin == o & z$horizon == h
    sp <- match(z$species_id[ix], design$species$species_id)
    stopifnot(!anyNA(sp), all(z$training_detected[ix] == trained[sp]),
      all(z$observed[ix] == seen[sp]))
  }
  cc <- counts[counts$job_id == id, ]
  cc$interval_mass <- NA_real_
  for (k in seq_len(nrow(cc))) {
    r <- cc[k, ]
    e <- z[z$origin == r$origin & z$horizon == r$horizon & z$model == r$model, ]
    if (r$cohort != "all_known") e <- e[e$training_detected == (r$cohort == "training_detected"), ]
    reconstructed <- goal013_score_events(e$probability, e$observed)
    stopifnot(isTRUE(all.equal(unname(as.numeric(r[names(reconstructed)])),
      unname(as.numeric(reconstructed)), tolerance = 1e-10)))
    pmf <- goal013_count_pmf(e$probability)
    cc$interval_mass[k] <- sum(pmf[(r$lower90:r$upper90) + 1L])
  }
  events[[j]] <- z
  masses[[j]] <- cc
}
events <- bind_rows(events)
counts <- bind_rows(masses)
stopifnot(nrow(events) == 260000L, !anyNA(events$probability),
  all(events$probability >= 0 & events$probability <= 1))

# Recompute the frozen choice rule, including failures, before reporting it.
check <- scores %>% group_by(job_id, origin) %>% summarise(
  recomputed = goal013_select(setNames(joint_future_logscore, model),
    convergence == 0, margin = cal$selection_margin_nats), .groups = "drop")
check <- left_join(selection, check, by = c("job_id", "origin"))
stopifnot(all(check$selected == check$recomputed))
write(read("recovery-summary.csv"), "recovery-summary.csv")
write(selection %>% count(truth, origin, selected, name = "replicates"), "selection-counts.csv")

coverage <- counts %>% group_by(truth, origin, horizon, model, cohort) %>%
  summarise(n = n(), covered = sum(covered90), coverage = mean(covered90),
    mean_interval_mass = mean(interval_mass), mean_width = mean(upper90 - lower90),
    zero_width = sum(upper90 == lower90), min_species = min(n_species),
    mean_species = mean(n_species), max_species = max(n_species),
    mean_bias = mean(expected - observed), mean_count_logscore = mean(log_probability),
    mean_brier = mean(brier), .groups = "drop")
ci <- t(vapply(seq_len(nrow(coverage)), function(i)
  binom.test(coverage$covered[i], coverage$n[i])$conf.int, numeric(2)))
coverage$lower95 <- ci[, 1]; coverage$upper95 <- ci[, 2]
coverage$undercoverage_flag <- coverage$upper95 < .9
coverage$own_truth <- coverage$truth == coverage$model
write(coverage, "count-calibration.csv")

# Additional bins are descriptive, post-hoc and based on frozen full-record
# positive-cell totals. They do not reproduce prospectively known abundance.
species <- design$species %>% select(species_id, taxon_class, positive_cells) %>%
  mutate(incidence_bin = if_else(positive_cells <= 3, "1-3 cells", ">3 cells"))
write(species, "species-bins.csv")
events <- left_join(events, species, by = "species_id")
events$brier <- (events$probability - events$observed)^2
events$logscore <- ifelse(events$observed == 1,
  log(events$probability), log1p(-events$probability))
event_summary <- events %>% group_by(truth, origin, horizon, model, taxon_class,
  incidence_bin, training_detected) %>% summarise(species_replicates = n(),
    species = n_distinct(species_id), mean_probability = mean(probability),
    event_frequency = mean(observed), brier = mean(brier),
    mean_logscore = mean(logscore), infinite_logscore = sum(!is.finite(logscore)), .groups = "drop")
write(event_summary, "species-event-summary.csv")
paired <- events %>% select(job_id, truth, origin, horizon, model, species_id,
  incidence_bin, brier, logscore) %>%
  left_join(events %>% filter(model == "static") %>%
    select(job_id, origin, horizon, species_id, static_brier = brier,
      static_logscore = logscore), by = c("job_id", "origin", "horizon", "species_id")) %>%
  group_by(job_id, truth, origin, horizon, model, incidence_bin) %>%
  summarise(brier_gain = mean(static_brier - brier),
    logscore_gain = mean(logscore - static_logscore), .groups = "drop")
write(paired %>% group_by(truth, origin, horizon, model, incidence_bin) %>%
  summarise(n = n(), mean_brier_gain = mean(brier_gain),
    brier_gain_se = sd(brier_gain) / sqrt(n()),
    mean_logscore_gain = mean(logscore_gain), .groups = "drop"), "event-gains-over-static.csv")

gain <- scores %>% left_join(scores %>% filter(model == "static") %>%
  select(job_id, origin, static_score = joint_future_logscore), by = c("job_id", "origin")) %>%
  mutate(gain = joint_future_logscore - static_score)
write(gain %>% group_by(truth, origin, model) %>% summarise(
  n = n(), failures = sum(convergence != 0), median_gain = median(gain),
  q05 = q(gain, .05), q95 = q(gain, .95), .groups = "drop"), "joint-score-gains.csv")
parameters <- bind_rows(lapply(which(scores$model != "static"), function(i) {
  r <- scores[i, ]; theta <- as.numeric(strsplit(r$theta, ";", fixed = TRUE)[[1]])
  reference <- if (r$truth == r$model) cal$truth_parameters[[r$truth]] else rep(NA_real_, 4)
  data.frame(job_id = r$job_id, truth = r$truth, origin = r$origin, model = r$model,
    taxon = rep(c("Aves", "Mammalia"), each = 2),
    parameter = rep(if (r$model == "harmonic") c("sin", "cos") else c("amplitude", "rho"), 2),
    estimate = theta, true_value = reference, convergence = r$convergence,
    at_boundary = if (r$model == "harmonic") abs(theta) >= 4 - 1e-8 else
      theta <= 1e-8 | theta >= rep(c(4, .98), 2) - 1e-8)
}))
write(parameters %>% group_by(truth, origin, model, taxon, parameter) %>%
  summarise(n = n(), median = median(estimate), q05 = q(estimate, .05), q95 = q(estimate, .95),
    true_value = first(true_value), boundary_count = sum(at_boundary),
    failures = sum(convergence != 0), .groups = "drop"), "parameter-summary.csv")
failed <- scores %>% filter(convergence != 0)
failed$best_converged_objective_gap <- vapply(seq_len(nrow(failed)), function(i) {
  r <- failed[i, ]; z <- read(file.path(r$job_id, "fit-starts.csv"))
  z <- z[z$origin == r$origin & z$model == r$model, ]
  min(z$value[z$convergence == 0]) + r$loglik_train
}, numeric(1))
write(failed, "numerical-failures.csv")

fingerprints <- read("fingerprints.csv")
observed <- read("observed-fingerprints.csv") %>%
  select(statistic, taxon, observed = mh_or, observed_pairs = pairs)
fingerprint_summary <- fingerprints %>% group_by(truth, statistic, taxon) %>%
  summarise(n = n(), finite = sum(is.finite(mh_or)), min_pairs = min(pairs), max_pairs = max(pairs),
    median = median(mh_or), q05 = q(mh_or, .05), q95 = q(mh_or, .95), .groups = "drop") %>%
  left_join(observed, by = c("statistic", "taxon"))
stopifnot(all(fingerprint_summary$finite == 100),
  all(fingerprint_summary$min_pairs == fingerprint_summary$observed_pairs),
  all(fingerprint_summary$max_pairs == fingerprint_summary$observed_pairs))
write(fingerprint_summary, "fingerprint-envelopes.csv")
fingerprint_summary$statistic <- factor(fingerprint_summary$statistic,
  levels = c("within_station_lag1", "within_station_lag26", "within_station_lag52",
    "same_species_cross_station", "same_station_cross_species"),
  labels = c("Within station\n1 week", "Within station\n26 weeks", "Within station\n52 weeks",
    "Same species\nacross stations", "Same station\nacross species"))
fingerprint_summary$truth <- factor(fingerprint_summary$truth,
  levels = c("static", "harmonic", "array", "station", "service_stress"))
plot <- ggplot(fingerprint_summary, aes(x = truth, y = median, colour = truth)) +
  geom_hline(yintercept = 1, colour = "grey85") +
  geom_hline(aes(yintercept = observed), colour = "black", linetype = "dashed") +
  geom_linerange(aes(ymin = q05, ymax = q95), linewidth = .7) + geom_point(size = 2) +
  facet_grid(taxon ~ statistic) + scale_y_log10(breaks = c(.25, .5, 1, 2, 4, 8)) +
  scale_colour_manual(values = c("#777777", "#009E73", "#D55E00", "#0072B2", "#CC79A7"),
    labels = c("Static", "Annual harmonic", "Array state", "Station state", "Service stress")) +
  labs(x = NULL, y = "Stratified odds ratio (log scale)", colour = NULL,
    title = "Recovery success does not establish a match to Judbury",
    subtitle = "Points and bars: simulated median and 5–95% range; dashed lines: observed diagnostics",
    caption = "26 recorded species; fixed full-effort pair support. Descriptive comparison, not a posterior predictive test.\nTruth calibration uses this field record; overlapping pairs do not supply independent replication.") +
  theme_bw(base_size = 11) + theme(axis.text.x = element_blank(), axis.ticks.x = element_blank(),
    panel.grid.minor = element_blank(), panel.grid.major.x = element_blank(),
    legend.position = "bottom", plot.caption = element_text(hjust = 0), strip.background = element_rect(fill = "grey95"))
ggsave(file.path(dest, "temporal-fingerprints.png"), plot, width = 13, height = 6.3, dpi = 180)
ggsave(file.path(dest, "temporal-fingerprints.pdf"), plot, width = 13, height = 6.3, device = cairo_pdf)
writeLines(c("COMPLETE: post-hoc assessment; frozen run unmodified",
  "4513 production file hashes and all frozen input hashes verified",
  "260000 species event rows checked against saved simulated panels",
  "30000 count scores reconstructed; 1000 selections reproduced",
  "Post-hoc summaries/bins do not replace the frozen decision rules",
  paste("production_manifest_sha256", hash(file.path(src, "output-sha256.csv"))),
  paste("assessment_script_sha256", hash("scripts/assess_goal013_results.R"))), file.path(dest, "verification.txt"))
files <- sort(list.files(dest, full.names = TRUE))
write(data.frame(path = basename(files), sha256 = vapply(files, hash, "")), "output-sha256.csv")
cat("PASS: sealed output hashes, event/cohort reconstruction, count scores, selections and fixed pair support\n")
