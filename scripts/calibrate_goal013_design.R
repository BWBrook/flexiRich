#!/usr/bin/env Rscript
# Deterministic, post-assessment truth calibration, before any recovery draws.
options(warn = 2)
source("R/goal013_mechanisms.R")
args <- commandArgs(trailingOnly = TRUE)
dest <- if (length(args)) args[[1L]] else "config/goal013_calibration.rds"
if (file.exists(dest)) stop("Refusing to overwrite calibrated inputs")
d <- readRDS("config/goal013_design.rds")
T <- ncol(d$y)
eligible <- d$effort[, -T] > 0 & d$effort[, -1] > 0 &
  d$group[, -T] == d$group[, -1]
expected_switch <- function(model, theta, cl) {
  pr <- goal013_probabilities(d, model, theta)
  low <- pr$p_low; high <- pr$p_high
  meanp <- (low + high) / 2
  joint <- meanp[, -T] * meanp[, -1]
  if (model %in% c("array", "station")) {
    rho <- theta[2 * d$row_class]
    stay <- matrix((1 + rho) / 2, nrow(d$y), T - 1)
    joint <- .5 * (stay * (low[, -T] * low[, -1] + high[, -T] * high[, -1]) +
      (1 - stay) * (low[, -T] * high[, -1] + high[, -T] * low[, -1]))
  }
  val <- meanp[, -T] + meanp[, -1] - 2 * joint
  sum(val[eligible & d$row_class == cl])
}
static <- goal013_probabilities(d, "static")
theta_h <- theta_a <- numeric(4)
theta_a[c(2, 4)] <- .8
summaries <- list()
curves <- list()
for (cl in 1:2) {
  rr <- which(d$row_class == cl)
  # This phase is only a design anchor derived from already-open records.
  residual <- colSums(d$y[rr, , drop = FALSE] - static$p[rr, , drop = FALSE], na.rm = TRUE)
  direction <- c(sum(residual * sin(d$phase)), sum(residual * cos(d$phase)))
  direction <- if (sum(direction^2) > 0) direction / sqrt(sum(direction^2)) else c(0, 1)
  base <- expected_switch("static", numeric(), cl)
  observed <- sum((d$y[, -T] != d$y[, -1])[eligible & d$row_class == cl])
  theta_for <- function(a, model) {
    z <- numeric(4)
    idx <- 2 * cl - 1:0
    if (model == "harmonic") z[idx] <- a * direction
    else {z[c(2, 4)] <- .8; z[2 * cl - 1] <- a}
    z
  }
  amplitude <- seq(0, 4, length.out = 41)
  hs <- vapply(amplitude, function(a) expected_switch("harmonic", theta_for(a, "harmonic"), cl), 0)
  as <- vapply(amplitude, function(a) expected_switch("array", theta_for(a, "array"), cl), 0)
  deficit <- max(0, min(base - observed, .9 * (base - min(hs)), .9 * (base - min(as))))
  target <- base - deficit
  solve_amplitude <- function(model, values) {
    if (deficit == 0) return(0)
    k <- which(values <= target)[1]
    stopifnot(!is.na(k), k > 1)
    uniroot(function(a) expected_switch(model, theta_for(a, model), cl) - target,
      c(amplitude[k - 1], amplitude[k]), tol = 1e-7)$root
  }
  ah <- solve_amplitude("harmonic", hs); aa <- solve_amplitude("array", as)
  theta_h[2 * cl - 1:0] <- ah * direction
  theta_a[2 * cl - 1] <- aa
  summaries[[cl]] <- data.frame(taxon = c("Aves", "Mammalia")[cl],
    observed_switches = observed, static_expected = base, common_target = target,
    empirical_deficit = base - observed, imposed_deficit = deficit,
    retained_deficit_fraction = if (base > observed) deficit / (base - observed) else NA_real_,
    harmonic_amplitude = ah, hmm_amplitude = aa, hmm_rho = .8,
    phase_sin = direction[1], phase_cos = direction[2],
    harmonic_expected = expected_switch("harmonic", theta_for(ah, "harmonic"), cl),
    hmm_expected = expected_switch("array", theta_for(aa, "array"), cl))
  curves[[cl]] <- data.frame(taxon = c("Aves", "Mammalia")[cl], amplitude,
    harmonic_switches = hs, hmm_switches = as)
}
# Separate omitted-nuisance stress: a factor shared by every species at a
# station and service interval. Its realization is frozen, not estimated from
# species rates or construed as a camera failure history.
set.seed(2026100650)
ids <- sort(unique(na.omit(d$movement$service_id)))
service_log <- setNames(rnorm(length(ids), 0, .6), ids)
J <- length(unique(d$rows$camera_id)); S <- nrow(d$species)
station_factor <- matrix(exp(service_log[d$movement$service_id]), J, T, byrow = TRUE)
factor <- station_factor[rep(seq_len(J), S), ]
factor[d$effort == 0] <- 1
stress <- matrix(NA_real_, nrow(d$y), T)
for (g in seq_along(d$target)) {
  ii <- which(d$group == g)
  exposure <- d$effort[ii] * factor[ii]
  fun <- function(scale) sum(-expm1(-exposure * scale)) - d$target[g]
  hi <- 1
  while (fun(hi) < 0) hi <- hi * 2
  scale <- uniroot(fun, c(0, hi), tol = 1e-13)$root
  stress[ii] <- -expm1(-exposure * scale)
}
stopifnot(max(abs(rowsum(as.vector(stress)[d$group > 0],
  as.vector(d$group)[d$group > 0], reorder = TRUE)[, 1] - d$target)) < 1e-7)
calibration <- list(truth_parameters = list(static = numeric(), harmonic = theta_h,
  array = theta_a, station = theta_a), service_probability = stress,
  service_factors = data.frame(service_id = ids, log_factor = service_log),
  summary = do.call(rbind, summaries), curves = do.call(rbind, curves),
  selection_margin_nats = 2,
  service_metadata = list(seed = 2026100650, log_sd = .6,
    interpretation = "omitted shared nuisance stress, not observed camera history"))
stopifnot(max(abs(calibration$summary$harmonic_expected - calibration$summary$common_target)) < 1e-3,
  max(abs(calibration$summary$hmm_expected - calibration$summary$common_target)) < 1e-3)
saveRDS(calibration, dest, version = 3)
write.csv(calibration$summary, sub("[.]rds$", ".csv", dest), row.names = FALSE)
print(calibration$summary, row.names = FALSE)
