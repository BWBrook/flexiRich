#!/usr/bin/env Rscript
# Post-assessment, conditional design only. Never reads raw observations.
options(warn = 2)
args <- commandArgs(trailingOnly = TRUE)
dest <- if (length(args)) args[[1L]] else "config/goal013_design.rds"
stopifnot(length(args) <= 1L)
if (file.exists(dest)) stop("Refusing to replace a frozen design")
hash <- function(x) digest::digest(file = x, algo = "sha256", serialize = FALSE)
read <- function(x) read.csv(x, stringsAsFactors = FALSE)
g12 <- "outputs/goal012/timing-v2"
inputs <- read(file.path(g12, "input-receipts.csv"))
stopifnot(all(vapply(inputs$path, hash, "") == inputs$sha256))
receipts <- read(file.path(g12, "output-sha256.csv"))
used <- c("movement-effort.csv", "species-summary.csv")
selected <- receipts[match(used, receipts$path), ]
selected$path <- file.path(g12, selected$path)
stopifnot(!anyNA(selected), all(vapply(selected$path, hash, "") == selected$sha256))
services_path <- "config/goal013_judbury_services.csv"
stopifnot(hash(services_path) ==
  "f33eeac9d70126966717c8e3f4731c00a97cbc3a34c2f44ce5c70d91c7d5283a")
ledger <- read("config/goal012_deployment_ledger.csv")
services <- read(services_path)
movement <- read(file.path(g12, "movement-effort.csv"))
species <- read(file.path(g12, "species-summary.csv"))
species <- species[species$positive_cells > 0, ]
species <- species[order(species$species_id), ]
stations <- sort(unique(movement$camera_id))
T <- max(movement$occasion_index); S <- nrow(species); J <- length(stations)
stopifnot(T == 153L, S == 26L, J == 9L)
incidence <- rbind(read("outputs/goal008/development-v1/detections_weekly.csv"),
  read("outputs/goal011/assessment-v3/future-detections-weekly.csv"))
incidence <- incidence[incidence$species_id %in% species$species_id, ]
rows <- data.frame(species_id = rep(species$species_id, each = J),
  camera_id = rep(stations, S), row_species = rep(seq_len(S), each = J),
  row_class = rep(match(species$taxon_class, c("Aves", "Mammalia")), each = J))
key <- function(x) paste(x$species_id, x$camera_id, sep = "|")
ri <- match(key(incidence), key(rows))
ti <- as.integer(sub("occ_", "", incidence$occasion_id, fixed = TRUE))
y <- matrix(NA_real_, S * J, T)
y[cbind(ri, ti)] <- incidence$detected
movement <- movement[order(match(movement$camera_id, stations), movement$occasion_index), ]
dates <- as.Date(movement$midpoint[movement$camera_id == stations[1]])
movement$placement <- NA_integer_
movement$service_id <- NA_character_
movement$service_boundary <- FALSE
for (k in seq_len(nrow(movement))) {
  v <- movement[k, ]; start <- as.Date(v$start_date); end <- as.Date(v$end_date)
  mid <- as.Date(v$midpoint)
  take <- which(ledger$nominal_grid_station_id == v$camera_id &
    as.Date(ledger$start_date) <= start & as.Date(ledger$end_date) >= end)
  if (v$transition || !length(take)) {
    stopifnot(v$transition || v$active_days == 0)
    next
  }
  stopifnot(length(take) == 1L)
  movement$placement[k] <- take
  service_row <- services[match(ledger$raw_service_site_id[take], services$site), ]
  d <- as.Date(unlist(service_row[grepl("[.]date$", names(service_row))]), "%d/%m/%Y")
  d <- sort(d[!is.na(d)])
  interval <- findInterval(mid, d)
  # Midpoint interval is a synthetic stress convention only, not daily routing.
  movement$service_id[k] <- paste(ledger$physical_location_id[take], interval, sep = ":")
  internal <- d[-c(1L, length(d))]
  movement$service_boundary[k] <- any(internal >= start & internal <= end)
}
e_station <- matrix(movement$active_days, J, T, byrow = TRUE)
p_station <- matrix(movement$placement, J, T, byrow = TRUE)
excluded <- matrix(movement$transition, J, T, byrow = TRUE)
effort_original <- e_station[rep(seq_len(J), S), ]
effort <- effort_original
excluded_rows <- excluded[rep(seq_len(J), S), ]
effort[excluded_rows] <- 0
stopifnot(identical(is.na(y), effort_original == 0), sum(excluded) == 5L)
y_original <- y
y[effort == 0] <- NA_real_
group <- matrix(0L, S * J, T)
groups <- expand.grid(placement = seq_len(nrow(ledger)), species = seq_len(S))
groups$group <- seq_len(nrow(groups))
groups$species_id <- species$species_id[groups$species]
groups$physical_location_id <- ledger$physical_location_id[groups$placement]
for (i in seq_len(S)) {
  ix <- which(rows$row_species == i)
  g <- p_station + (i - 1L) * nrow(ledger)
  g[effort[ix, ] == 0] <- 0L
  stopifnot(!anyNA(g))
  group[ix, ] <- g
}
groups$n <- tabulate(group[effort > 0], nrow(groups))
groups$k <- tabulate(group[which(y == 1)], nrow(groups))
stopifnot(all(groups$n > 0), sum(groups$k) == sum(y, na.rm = TRUE))
# Smooth placement shares with total pseudocount 0.5 per species, preserving
# each species' observed total exactly. Cellwise Jeffreys smoothing would
# manufacture detections for rare taxa across the 13 placements.
total <- ave(groups$k, groups$species, FUN = sum)
groups$target <- total * (groups$k + .5 / nrow(ledger)) / (total + .5)
stopifnot(all(groups$target > 0 & groups$target < groups$n),
  max(abs(tapply(groups$target, groups$species, sum) -
          tapply(groups$k, groups$species, sum))) < 1e-10)
design <- list(y = y, effort = effort, group = group, target = groups$target,
  row_species = rows$row_species, row_class = rows$row_class,
  phase = 2 * pi * as.numeric(dates - as.Date("2020-01-15")) / 365.2425,
  original_y = y_original, original_effort = effort_original,
  species = species, rows = rows, groups = groups, movement = movement,
  ledger = ledger, dates = dates,
  metadata = list(scope = "known-member temporal oracle ceiling",
    marginal_target = "K_i*(k_ig+0.5/13)/(K_i+0.5); preserves species totals",
    ignored_movement_station_weeks = sum(excluded),
    missing_rule = "original zero-effort plus ambiguous movement weeks",
    service_midpoints = "synthetic stress only; run_days unused",
    raw_observations_read = FALSE, huon_ridge_read = FALSE))
dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
saveRDS(design, dest, version = 3)
inputs <- rbind(inputs, selected, data.frame(path = services_path, sha256 = hash(services_path)))
write.csv(inputs, sub("[.]rds$", "-sources.csv", dest), row.names = FALSE)
cat("Saved", dest, "with", S, "known members,", nrow(groups), "placement margins,",
    sum(effort > 0), "likelihood cells;", sum(effort_original > effort) / S,
    "station-weeks excluded.\n")
