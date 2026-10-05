#!/usr/bin/env Rscript
# Explicitly post-assessment development; reads only retained weekly inputs.
options(warn = 2)
for (f in sort(list.files("R", pattern = "[.]R$", full.names = TRUE))) source(f)
suppressPackageStartupMessages({library(dplyr); library(tidyr); library(ggplot2)})
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) <= 1L)
dest <- if (length(args)) args[[1L]] else "outputs/goal012/timing-v2"
if (file.exists(dest)) stop("Refusing to overwrite an existing output directory.")
read_csv <- function(path) read.csv(path, stringsAsFactors = FALSE)
hash <- function(path) digest::digest(file = path, algo = "sha256", serialize = FALSE)
save_csv <- function(x, name) write.csv(x, file.path(dest, name), row.names = FALSE)
dev <- "outputs/goal008/development-v1"
assessment <- "outputs/goal011/assessment-v3"
required <- c(file.path(dev, c("candidate_pool.csv", "effort_weekly.csv",
  "detections_weekly.csv", "occasion_calendar.csv")),
  "config/goal003_candidate_pool.csv", "config/goal003_task4_effort_template.csv",
  "config/goal011_future_effort.csv", "config/goal011_future_calendar.csv")
pinned <- read_csv("config/goal011_inputs.csv")
pinned <- pinned[match(required, pinned$path), ]
stopifnot(!anyNA(pinned), all(vapply(pinned$path, hash, "") == pinned$sha256))
assess_paths <- c("future-detections-weekly.csv", "outcomes.csv")
assess_receipts <- read_csv(file.path(assessment, "output-sha256.csv"))
assess_receipts <- assess_receipts[match(assess_paths, assess_receipts$path), ]
assess_receipts$path <- file.path(assessment, assess_receipts$path)
stopifnot(!anyNA(assess_receipts),
          all(vapply(assess_receipts$path, hash, "") == assess_receipts$sha256))
ledger_path <- "config/goal012_deployment_ledger.csv"
stopifnot(hash(ledger_path) ==
  "0921eb8845c2bb1ad5760271f283ab2783735b7739e254c67e9243bc906f3ebf")
ledger <- read_csv(ledger_path)

calendar <- bind_rows(read_csv(file.path(dev, "occasion_calendar.csv")),
  read_csv("config/goal011_future_calendar.csv") |>
    select(occasion_id, occasion_index, start_date, end_date)) |>
  mutate(start_date = as.Date(start_date), end_date = as.Date(end_date),
         midpoint = start_date + 3, block13 = (occasion_index - 1L) %/% 13L + 1L,
         month = as.integer(format(midpoint, "%m")),
         season = c("DJF", "MAM", "JJA", "SON")[(month %% 12L) %/% 3L + 1L])
stopifnot(identical(calendar$occasion_index, 1:153),
  all(diff(calendar$start_date) == 7), all(calendar$end_date == calendar$start_date + 6))
effort <- bind_rows(read_csv(file.path(dev, "effort_weekly.csv")),
  read_csv("config/goal011_future_effort.csv") |>
    select(camera_id, occasion_id, active_days))
incidence <- bind_rows(read_csv(file.path(dev, "detections_weekly.csv")),
  read_csv(file.path(assessment, "future-detections-weekly.csv")))
pool <- read_csv(file.path(dev, "candidate_pool.csv"))
prepared <- prepare_flexirich_g_data(pool, effort, incidence)
stopifnot(length(prepared$candidate_ids) == 50L,
          length(prepared$camera_ids) == 9L, length(prepared$occasion_ids) == 153L,
          nrow(incidence) == 68850L, sum(effort$active_days) == 7644L)
labels <- read_csv("config/goal003_candidate_pool.csv") |>
  filter(primary_pool == "include") |>
  transmute(species_id = scientific_name, common_name, taxon_class)
panel <- incidence |>
  left_join(effort, by = c("camera_id", "occasion_id")) |>
  left_join(calendar, by = "occasion_id") |>
  left_join(labels, by = "species_id")
stopifnot(!anyNA(panel$active_days), !anyNA(panel$common_name),
          identical(is.na(panel$detected), panel$active_days == 0L))
template <- read_csv("config/goal003_task4_effort_template.csv")
effort_bridge <- effort |> left_join(select(calendar, occasion_id, occasion_index),
  by = "occasion_id") |> left_join(template,
    by = c("camera_id", "occasion_index"), suffix = c("", "_reference"))
stopifnot(all(effort_bridge$active_days == effort_bridge$active_days_reference))
outcomes <- read_csv(file.path(assessment, "outcomes.csv"))
reconstructed <- vapply(seq_len(nrow(outcomes)), function(k) {
  s <- outcomes$species_id[k]; h <- outcomes$horizon[k]
  as.integer(any(panel$detected[panel$species_id == s &
    panel$occasion_index > 52L & panel$occasion_index <= 52L + h] == 1L, na.rm = TRUE))
}, integer(1))
stopifnot(identical(reconstructed, outcomes$detected))

# Build camera-specific calendar strata, never new observation/effort routing.
cam <- sort(unique(effort$camera_id))
movement <- expand_grid(camera_id = cam, occasion_index = 1:153) |>
  left_join(calendar, by = "occasion_index") |>
  mutate(segment = 0L, transition = FALSE, in_declared_gap = FALSE)
move_rows <- which(!is.na(ledger$predecessor_deployment_id) &
                    nzchar(ledger$predecessor_deployment_id))
for (k in move_rows) {
  predecessor <- ledger[match(ledger$predecessor_deployment_id[k], ledger$deployment_id), ]
  stopifnot(nrow(predecessor) == 1L, !is.na(predecessor$deployment_id))
  dates <- sort(unique(as.Date(c(predecessor$end_date, ledger$start_date[k]))))
  take <- which(movement$camera_id == ledger$nominal_grid_station_id[k])
  for (date in as.numeric(dates)) {
    movement$segment[take] <- movement$segment[take] +
      as.integer(movement$midpoint[take] > as.Date(date, origin = "1970-01-01"))
    movement$transition[take] <- movement$transition[take] |
      (movement$start_date[take] <= date & movement$end_date[take] >= date)
  }
  movement$in_declared_gap[take] <- movement$start_date[take] > min(dates) &
    movement$end_date[take] < max(dates)
}
movement <- movement |> left_join(effort, by = c("camera_id", "occasion_id"))
stopifnot(sum(movement$transition) == 5L,
          all(movement$active_days[movement$in_declared_gap] == 0L))
panel <- panel |> left_join(select(movement, camera_id, occasion_index,
  segment, transition, in_declared_gap), by = c("camera_id", "occasion_index"))

species_summary <- panel |> group_by(species_id, common_name, taxon_class) |>
  summarise(positive_cells = sum(detected == 1L, na.rm = TRUE),
    sampled_station_weeks = sum(active_days > 0L),
    positive_weeks = n_distinct(occasion_index[which(detected == 1L)]),
    stations_detected = n_distinct(camera_id[which(detected == 1L)]),
    first_year_cells = sum(detected[occasion_index <= 52] == 1L, na.rm = TRUE),
    future_cells = sum(detected[occasion_index > 52] == 1L, na.rm = TRUE),
    first_week = if (any(detected == 1L, na.rm = TRUE))
      min(occasion_index[which(detected == 1L)]) else NA_integer_,
    last_week = if (any(detected == 1L, na.rm = TRUE))
      max(occasion_index[which(detected == 1L)]) else NA_integer_,
    first_future_week = if (any(detected[occasion_index > 52] == 1L, na.rm = TRUE))
      min(occasion_index[which(detected == 1L & occasion_index > 52)]) else NA_integer_,
    .groups = "drop") |>
  mutate(first_week_start = calendar$start_date[first_week],
    last_week_end = calendar$end_date[last_week],
    first_future_week_start = calendar$start_date[first_future_week],
    first_future_week_end = calendar$end_date[first_future_week],
    detection_history = case_when(first_year_cells > 0 & future_cells > 0 ~ "both periods",
      first_year_cells > 0 ~ "first year only", future_cells > 0 ~ "later addition",
      TRUE ~ "never recorded"))
observed_species <- sort(species_summary$species_id[species_summary$positive_cells > 0])
stopifnot(length(observed_species) == 26L,
          sum(species_summary$first_year_cells > 0) == 21L,
          sum(species_summary$future_cells > 0) == 23L)
rows <- expand_grid(species_id = observed_species, camera_id = cam)
key <- function(x) paste(x$species_id, x$camera_id, sep = "|")
observed_panel <- filter(panel, species_id %in% observed_species)
ri <- match(key(observed_panel), key(rows)); ti <- observed_panel$occasion_index
matrix_from <- function(column) {
  result <- matrix(column[NA_integer_], nrow(rows), 153L)
  result[cbind(ri, ti)] <- column
  result
}
y <- matrix_from(observed_panel$detected)
e <- matrix_from(observed_panel$active_days)
segment <- matrix_from(observed_panel$segment)
transition <- matrix_from(observed_panel$transition)
left <- 1:152; right <- 2:153
eligible <- e[, left] > 0 & e[, right] > 0 & !transition[, left] &
  !transition[, right] & segment[, left] == segment[, right]
within <- calendar$block13[left] == calendar$block13[right]
observed <- goal012_timing_statistics(y, eligible, rows$species_id, within)
dir.create(dest, recursive = TRUE)
save_csv(bind_rows(pinned, assess_receipts,
  data.frame(path = ledger_path, sha256 = hash(ledger_path))), "input-receipts.csv")
save_csv(calendar, "calendar.csv")
save_csv(movement, "movement-effort.csv")
save_csv(species_summary, "species-summary.csv")
save_csv(panel |> group_by(species_id, common_name, camera_id, block13) |>
  summarise(positive_cells = sum(detected == 1L, na.rm = TRUE),
    sampled_weeks = sum(active_days > 0L), active_days = sum(active_days),
    .groups = "drop"), "species-station-blocks.csv")
save_csv(panel |> group_by(species_id, common_name, season,
    annual_window = (occasion_index - 1L) %/% 52L + 1L) |>
  summarise(positive_cells = sum(detected == 1L, na.rm = TRUE),
    sampled_station_weeks = sum(active_days > 0L), active_days = sum(active_days),
    .groups = "drop"), "species-season-year.csv")
save_csv(movement |> group_by(camera_id, block13) |>
  summarise(active_days = sum(active_days), sampled_weeks = sum(active_days > 0L),
    .groups = "drop"), "station-effort-blocks.csv")

context_for <- function(control, offset = 0L) {
  context <- matrix("all", nrow(y), ncol(y))
  if (control != "nominal_static") context <- paste0("segment", segment)
  dim(context) <- dim(y)
  if (control == "movement_season")
    context[] <- paste(context, rep(calendar$season, each = nrow(y)), sep = ":")
  if (control == "movement_block13") context[] <- paste(context,
    rep((calendar$occasion_index - 1L + offset) %/% 13L, each = nrow(y)), sep = ":")
  context[transition] <- paste0("fixed_transition", col(y)[transition])
  context
}
replicates <- 1999L
controls <- c("nominal_static", "movement", "movement_season", "movement_block13")
summaries <- supports <- species_support <- list()
all_replicates <- list()
for (a in seq_along(controls)) {
  control <- controls[a]
  strata <- goal012_timing_strata(y, e, context_for(control))
  expected <- goal012_expected_timing(y, strata, eligible, rows$species_id, within)
  draws <- matrix(NA_real_, replicates, length(observed), dimnames = list(NULL, names(observed)))
  RNGkind("Mersenne-Twister", "Inversion", "Rejection"); set.seed(2026100500L + a)
  for (b in seq_len(replicates)) {
    permuted <- goal012_shuffle_timing(y, strata)
    # All margins and zero-effort cells are checked for every permutation.
    stopifnot(identical(is.na(permuted), is.na(y)),
      all(vapply(strata$indices, function(ix) sum(permuted[ix]), 0) == strata$table$n_detected))
    draws[b, ] <- goal012_timing_statistics(permuted, eligible, rows$species_id, within)
  }
  varying <- matrix(FALSE, nrow(y), ncol(y))
  varying[unlist(strata$indices[strata$table$mixed], use.names = FALSE)] <- TRUE
  variable_pairs <- eligible & (varying[, left] | varying[, right])
  supports[[a]] <- data.frame(control, strata = nrow(strata$table),
    mixed_strata = sum(strata$table$mixed), mixed_cells = sum(varying),
    eligible_pairs = sum(eligible), pairs_touching_mixed_cells = sum(variable_pairs),
    within_block_pairs = sum(eligible[, within, drop = FALSE]))
  species_support[[a]] <- data.frame(control, species_id = observed_species,
    eligible_pairs = as.numeric(rowsum(rowSums(eligible), rows$species_id)),
    pairs_touching_mixed_cells = as.numeric(rowsum(rowSums(variable_pairs), rows$species_id)),
    mixed_strata = as.numeric(tapply(strata$table$mixed,
      rows$species_id[strata$table$row], sum)[observed_species]),
    mixed_cells = as.numeric(rowsum(rowSums(varying), rows$species_id)))
  summaries[[a]] <- bind_rows(lapply(seq_along(observed), function(k) {
    lo <- sum(draws[, k] <= observed[k]); hi <- sum(draws[, k] >= observed[k])
    lo_ci <- binom.test(lo, replicates)$conf.int; hi_ci <- binom.test(hi, replicates)$conf.int
    data.frame(control, statistic = names(observed)[k], observed = unname(observed[k]),
      exact_mean = unname(expected[k]), simulation_mean = mean(draws[, k]),
      mean_mcse = sd(draws[, k]) / sqrt(replicates),
      q05 = unname(quantile(draws[, k], .05, type = 1)),
      q95 = unname(quantile(draws[, k], .95, type = 1)),
      observed_minus_exact = unname(observed[k] - expected[k]),
      number_le = lo, number_ge = hi, replicates,
      tail_le_plus_one = (lo + 1) / (replicates + 1),
      tail_ge_plus_one = (hi + 1) / (replicates + 1),
      tail_le_mc95_low = lo_ci[1], tail_le_mc95_high = lo_ci[2],
      tail_ge_mc95_low = hi_ci[1], tail_ge_mc95_high = hi_ci[2])
  }))
  strata$table$species_id <- rows$species_id[strata$table$row]
  strata$table$camera_id <- rows$camera_id[strata$table$row]
  save_csv(strata$table, paste0(control, "-strata.csv"))
  all_replicates[[control]] <- draws
  cat(control, "complete:", sum(strata$table$mixed), "mixed strata\n")
}
summary <- bind_rows(summaries)
save_csv(summary, "conditional-summary.csv")
save_csv(bind_rows(supports), "conditional-support.csv")
save_csv(bind_rows(species_support) |>
  left_join(species_summary, by = "species_id"), "species-conditional-support.csv")
saveRDS(all_replicates, file.path(dest, "conditional-replicates.rds"))
phase <- bind_rows(lapply(c(0L, 4L, 8L), function(offset) {
  strata <- goal012_timing_strata(y, e, context_for("movement_block13", offset))
  phase_block <- (calendar$occasion_index - 1L + offset) %/% 13L
  phase_within <- phase_block[left] == phase_block[right]
  phase_observed <- goal012_timing_statistics(y, eligible, rows$species_id, phase_within)
  expected <- goal012_expected_timing(y, strata, eligible, rows$species_id, phase_within)
  data.frame(offset_weeks = offset, statistic = names(expected),
    observed = unname(phase_observed), exact_mean = unname(expected),
    observed_minus_exact = unname(phase_observed - expected),
    mixed_strata = sum(strata$table$mixed))
}))
save_csv(phase, "block-phase-exact-means.csv")

# Figures describe incidence, with full-zero candidates retained in tables.
date_scale <- function() scale_x_date(date_breaks = "6 months", date_labels = "%b %Y",
  expand = expansion(mult = .01))
plot_theme <- theme_minimal(base_size = 11) + theme(panel.grid = element_blank(),
  axis.title.y = element_blank(), legend.position = "bottom")
origin <- as.Date("2020-06-03")
order_species <- species_summary |> filter(positive_cells > 0) |>
  arrange(first_week, common_name) |> pull(common_name)
weekly_species <- observed_panel |> group_by(species_id, common_name, midpoint) |>
  summarise(stations_detected = sum(detected == 1L, na.rm = TRUE),
    sampled_stations = sum(active_days > 0L), .groups = "drop") |>
  mutate(common_name = factor(common_name, levels = rev(order_species)),
    stations_detected = ifelse(sampled_stations == 0, NA, stations_detected))
p_species <- ggplot(weekly_species, aes(midpoint, common_name, fill = stations_detected)) +
  geom_tile(width = 7, height = .88) +
  geom_vline(xintercept = origin, linetype = 2, colour = "#9d372d") +
  scale_fill_gradient(low = "#f3f3f3", high = "#006c67", na.value = "#777777",
    name = "Stations with detections", limits = c(0, 9), breaks = c(0, 3, 6, 9)) +
  date_scale() + labs(x = NULL, title = "Judbury: recorded species through 153 weeks",
    subtitle = "Weekly incidence across nine nominal stations; dashed line ends first-year training",
    caption = "Grey: no station sampled. White: sampled without detection. Rows show 26 recorded species; 24 further candidates remain all-zero.") + plot_theme
ggsave(file.path(dest, "species-timing.png"), p_species, width = 12, height = 8, dpi = 160)
ggsave(file.path(dest, "species-timing.pdf"), p_species, width = 12, height = 8)
p_effort <- ggplot(movement, aes(midpoint, camera_id, fill = active_days)) +
  geom_tile(width = 7, height = .85) +
  geom_point(data = filter(movement, transition), shape = 4, size = 3,
    colour = "#b6242f", stroke = 1) +
  geom_vline(xintercept = origin, linetype = 2, colour = "#9d372d") +
  scale_fill_gradient(low = "#dedede", high = "#264d73", name = "Active days",
    limits = c(0, 7), breaks = c(0, 1, 4, 7)) + date_scale() + plot_theme +
  labs(x = NULL, title = "Judbury camera effort and movement boundaries",
    subtitle = "Red crosses: weeks held fixed in timing controls; dashed line: forecast origin",
    caption = "Service dates delimit calendar strata only. Original operation-derived effort is unchanged.")
ggsave(file.path(dest, "station-effort.png"), p_effort, width = 12, height = 4.6, dpi = 160)
ggsave(file.path(dest, "station-effort.pdf"), p_effort, width = 12, height = 4.6)
pdf(file.path(dest, "station-timing.pdf"), width = 12, height = 8)
for (station in cam) {
  z <- observed_panel |> filter(camera_id == station) |>
    mutate(common_name = factor(common_name, levels = rev(order_species)),
      state = factor(ifelse(is.na(detected), "No effort",
        ifelse(detected == 1L, "Detected", "Not detected")),
        levels = c("No effort", "Not detected", "Detected")))
  p <- ggplot(z, aes(midpoint, common_name, fill = state)) +
    geom_tile(width = 7, height = .88) +
    geom_vline(data = filter(movement, camera_id == station & transition),
      aes(xintercept = midpoint), colour = "#ba6058", linewidth = .6) +
    geom_vline(xintercept = origin, linetype = 2, colour = "#9d372d") +
    scale_fill_manual(values = c("#bbbbbb", "#f5f5f5", "#006c67"), name = NULL,
      drop = FALSE) + date_scale() + plot_theme + labs(x = NULL,
      title = paste("Judbury station:", station),
      subtitle = "Weekly incidence; solid red lines mark transition weeks, dashed line the forecast origin")
  print(p)
}
invisible(dev.off())
capture.output(sessionInfo(), file = file.path(dest, "session-info.txt"))
source_paths <- c("R/goal012_timing.R", "scripts/diagnose_goal012_timing.R",
  "docs/goals/012-post-assessment-timing/Goal.md")
save_csv(data.frame(path = source_paths, sha256 = vapply(source_paths, hash, "")),
  "code-receipts.csv")
writeLines(c("COMPLETE: post-assessment timing diagnostics; interpretation required",
  paste("source_head", system2("git", c("rev-parse", "HEAD"), stdout = TRUE)),
  "source_state: local Goal012 additions; code hashes identify executed source",
  "replicates_per_control: 1999; seeds: 2026100501-2026100504",
  "input_grid: 50 candidates x 9 nominal stations x 153 weeks",
  paste("eligible_adjacent_pairs:", sum(eligible)),
  "raw_observations_read: false; huon_ridge_read: false; new_fits: false"),
  file.path(dest, "STATUS.txt"))
files <- sort(list.files(dest, recursive = TRUE, full.names = TRUE))
save_csv(data.frame(path = substring(files, nchar(dest) + 2L),
  sha256 = vapply(files, hash, "")), "output-sha256.csv")
print(filter(summary, !grepl("^species:", statistic)), row.names = FALSE)
