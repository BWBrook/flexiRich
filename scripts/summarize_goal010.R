# Summarise completed Goal010 PPCs without refitting or reading observations.
if (!dir.exists("R") || !file.exists("config/goal010_fits.csv"))
  stop("Run this script from the repository root.", call. = FALSE)
a <- commandArgs(trailingOnly = TRUE)
if (length(a) > 2L) stop("Usage: Rscript scripts/summarize_goal010.R [run_dir] [synthesis_dir]", call. = FALSE)
run_dir <- if (length(a)) a[[1L]] else "outputs/goal010/spatial-v1"
out_dir <- if (length(a) == 2L) a[[2L]] else "outputs/goal010/synthesis-v1"
if (file.exists(out_dir) || dir.exists(out_dir))
  stop("Refusing to overwrite existing synthesis path: ", out_dir, call. = FALSE)
fail <- function(...) stop(paste0(...), call. = FALSE)
need <- function(path, what) {
  if (!file.exists(path) || dir.exists(path)) fail("Missing ", what, ": ", path)
  path
}
read_csv <- function(path, what) {
  tryCatch(utils::read.csv(need(path, what), stringsAsFactors = FALSE,
                           check.names = FALSE),
           error = function(e) fail("Could not read ", what, ": ", conditionMessage(e)))
}
read_rds <- function(path, what) {
  tryCatch(readRDS(need(path, what)),
           error = function(e) fail("Could not read ", what, ": ", conditionMessage(e)))
}
complete <- function(path, text, what) {
  if (!identical(trimws(readLines(need(path, what), warn = FALSE)), text))
    fail(what, " is not complete.")
}
fits <- c("control_zero_baseline", "control_zero_spatial", "control_cross_baseline",
          "control_cross_spatial", "spatial_primary", "spatial_wide_interaction",
          "spatial_wide_tail", "spatial_both_wide")
spatial <- fits[5:8]
profiles <- data.frame(
  profile_id = c("baseline_primary", "baseline_wide", spatial),
  profile_label = c("Goal009 primary", "Goal009 wider tail", "Goal010 primary",
                    "Goal010 wider interaction", "Goal010 wider tail", "Goal010 both wider"),
  fit_id = c("primary", "tail_wide", spatial),
  model = c("baseline", "baseline", rep("spatial", 4L)), stringsAsFactors = FALSE)
ppc_cols <- c("statistic", "observed", "q05", "q50", "q95", "tail_ge", "mcse")
parameter_cols <- c("variable", "mean", "median", "sd", "mad", "q5", "q95",
                    "rhat", "ess_bulk", "ess_tail")
check_ppc <- function(x, what) {
  if (!identical(names(x), ppc_cols) || !nrow(x)) fail(what, " has an invalid schema.")
  nums <- x[c("q05", "q50", "q95", "tail_ge", "mcse")]
  values <- as.matrix(nums)
  if (any(!vapply(nums, is.numeric, logical(1))) ||
      any(!is.na(values) & !is.finite(values))) fail(what, " has invalid intervals.")
  complete_rows <- rowSums(!is.na(values)) == ncol(values)
  if (any(is.finite(x$observed) & !complete_rows) ||
      any(complete_rows & (x$q05 > x$q50 | x$q50 > x$q95)))
    fail(what, " has invalid intervals.")
  x
}
check_latent <- function(x, what) {
  if (!identical(names(x), c("richness", "probability")) || !nrow(x) ||
      any(!is.finite(x$richness)) || any(!is.finite(x$probability)) ||
      any(x$probability < 0) || !isTRUE(all.equal(sum(x$probability), 1, tolerance = 1e-8)))
    fail(what, " is not a normalized latent PMF.")
  x[order(x$richness), , drop = FALSE]
}
check_parameters <- function(x, what) {
  if (!identical(names(x), parameter_cols) || !nrow(x)) fail(what, " has an invalid schema.")
  x
}
status <- read_csv(file.path(run_dir, "fit-status.csv"), "Goal010 fit-status.csv")
if (!identical(names(status), c("fit_id", "data_id", "terminal_status")) ||
    anyDuplicated(status$fit_id) || !identical(sort(status$fit_id), sort(fits)) ||
    any(!status$terminal_status %in% c("primary_clean", "rescue_clean")))
  fail("Goal010 fit-status.csv is incomplete or contains nonclean fits.")
complete(file.path(run_dir, "STATUS.txt"), "COMPLETE: spatial comparison ready for interpretation", "Goal010 STATUS.txt")
fit_data <- list(); diagnostics <- list()
for (id in fits) {
  d <- file.path(run_dir, id); attempt <- sub("_clean$", "", status$terminal_status[match(id, status$fit_id)])
  ad <- read_rds(file.path(d, "attempt-diagnostics.rds"), paste0(id, " attempt diagnostics"))
  if (!isTRUE(ad[[attempt]]$diagnostics$clean)) fail(id, " has nonclean attempt diagnostics.")
  m <- ad[[attempt]]$diagnostics$metrics
  diagnostics[[id]] <- data.frame(fit_id = id, terminal_attempt = attempt,
    divergences = m$divergences, treedepth_hits = m$treedepth_hits,
    min_ebfmi = m$min_ebfmi, max_rhat = m$max_rhat,
    min_bulk_ess = m$min_bulk_ess, min_tail_ess = m$min_tail_ess)
  fit_data[[id]] <- list(
    ppc = check_ppc(read_csv(file.path(d, "ppc-summary.csv"), paste0(id, " PPC summary")), paste0(id, " PPC summary")),
    latent = check_latent(read_csv(file.path(d, "latent-richness-pmf.csv"), paste0(id, " latent PMF")), paste0(id, " latent PMF")),
    parameters = check_parameters(read_csv(file.path(d, "parameter-summary.csv"), paste0(id, " parameter summary")), paste0(id, " parameter summary")))
}
complete("outputs/goal009/ppc-repaired-v2/STATUS.txt", "COMPLETE: corrected PPC; original fits preserved", "Goal009 corrected PPC STATUS.txt")
complete("outputs/goal009/first-year-v1/STATUS.txt", "COMPLETE: model criticism ready for interpretation", "Goal009 first-year STATUS.txt")
old_status <- read_csv("outputs/goal009/first-year-v1/fit-status.csv", "Goal009 first-year fit-status.csv")
if (!identical(sort(old_status$fit_id), c("primary", "tail_wide")) ||
    any(!old_status$terminal_status %in% c("primary_clean", "rescue_clean"))) fail("Goal009 baseline fits are incomplete or nonclean.")
baseline <- list()
for (p in c("primary", "tail_wide")) {
  b <- file.path("outputs/goal009/ppc-repaired-v2", p); f <- file.path("outputs/goal009/first-year-v1", p)
  baseline[[p]] <- list(
    ppc = check_ppc(read_csv(file.path(b, "ppc-summary.csv"), paste0("Goal009 ", p, " PPC summary")), paste0("Goal009 ", p, " PPC summary")),
    latent = check_latent(read_csv(file.path(f, "latent-richness-pmf.csv"), paste0("Goal009 ", p, " latent PMF")), paste0("Goal009 ", p, " latent PMF")),
    parameters = check_parameters(read_csv(file.path(f, "parameter-summary.csv"), paste0("Goal009 ", p, " parameter summary")), paste0("Goal009 ", p, " parameter summary")))
}
get <- function(id) if (id == "baseline_primary") baseline$primary else if (id == "baseline_wide") baseline$tail_wide else fit_data[[id]]
comparison <- setNames(lapply(profiles$profile_id, get), profiles$profile_id)
stats <- comparison[[1L]]$ppc$statistic
if (any(!vapply(comparison, function(x) identical(x$ppc$statistic, stats), logical(1)))) fail("Comparison PPC schemas differ.")
for (s in stats) {
  z <- vapply(comparison, function(x) x$ppc$observed[match(s, x$ppc$statistic)], numeric(1))
  if (any(!is.na(z)) && length(unique(z[!is.na(z)])) > 1L) fail("Observed PPC value differs for ", s, ".")
}
ppc_out <- do.call(rbind, lapply(seq_len(nrow(profiles)), function(i) {
  p <- profiles[i, ]; x <- comparison[[p$profile_id]]$ppc
  cbind(profile_id = rep(p$profile_id, nrow(x)), profile_label = rep(p$profile_label, nrow(x)),
        model = rep(p$model, nrow(x)), fit_id = rep(p$fit_id, nrow(x)), x)
}))
latent_out <- do.call(rbind, lapply(seq_len(nrow(profiles)), function(i) {
  p <- profiles[i, ]; x <- comparison[[p$profile_id]]$latent; q <- cumsum(x$probability)
  data.frame(p, mean = sum(x$richness * x$probability), median = x$richness[which(q >= .5)[1L]], q05 = x$richness[which(q >= .05)[1L]], q95 = x$richness[which(q >= .95)[1L]])
}))
core <- c("omega", "mu_alpha", "sigma_alpha", "sigma_camera", "sigma_interaction", "expected_richness")
hyper_out <- do.call(rbind, lapply(seq_len(nrow(profiles)), function(i) {
  p <- profiles[i, ]; x <- comparison[[p$profile_id]]$parameters; x <- x[x$variable %in% core, , drop = FALSE]
  x <- x[match(core[core %in% x$variable], x$variable), , drop = FALSE]
  cbind(profile_id = rep(p$profile_id, nrow(x)), profile_label = rep(p$profile_label, nrow(x)),
        model = rep(p$model, nrow(x)), fit_id = rep(p$fit_id, nrow(x)), x)
}))
diagnostics_out <- do.call(rbind, diagnostics)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
if (!dir.exists(out_dir)) fail("Could not create synthesis path: ", out_dir)
write.csv(ppc_out, file.path(out_dir, "ppc-comparison.csv"), row.names = FALSE)
write.csv(latent_out, file.path(out_dir, "latent-richness-summary.csv"), row.names = FALSE)
write.csv(hyper_out, file.path(out_dir, "core-hyperparameter-summary.csv"), row.names = FALSE)
write.csv(diagnostics_out, file.path(out_dir, "sampler-diagnostics.csv"), row.names = FALSE)
panel <- function(stat, title) {
  x <- ppc_out[ppc_out$statistic == stat, , drop = FALSE]; y <- rev(seq_len(nrow(x))); lim <- range(c(x$q05, x$q95, x$observed), na.rm = TRUE); d <- diff(lim); if (!d) d <- 1
  plot(NA, xlim = lim + c(-.12, .12) * d, ylim = c(.3, nrow(x) + .7), yaxt = "n", xlab = "Statistic value", ylab = "", main = title, bty = "l")
  axis(2, y, x$profile_label, las = 1, tick = FALSE, cex.axis = .72); abline(v = x$observed[which(!is.na(x$observed))[1L]], lty = 2, col = "grey35")
  segments(x$q05, y, x$q95, y, lwd = 3, col = "#0072B2"); points(x$q50, y, pch = 16, col = "#0072B2")
}
draw <- function() { par(mfrow = c(2, 2), mar = c(4.2, 14, 3, 1)); panel("global_commonranking_violation", "Spatial: global ranking"); panel("pademelon_bettong_crossing", "Spatial: selected crossing"); panel("adjacent_switch_count", "Temporal: adjacent switches"); panel("block_04_positivecells", "Temporal: fourth-block positives") }
png(file.path(out_dir, "spatial-temporal-discrepancies.png"), 2600, 1800, res = 200); draw(); dev.off()
pdf(file.path(out_dir, "spatial-temporal-discrepancies.pdf"), 13, 9); draw(); dev.off()
writeLines(c("Goal010 synthesis complete: preserved summaries only.", paste0("run_dir=", normalizePath(run_dir, mustWork = TRUE)), "protected_raw_data_read=false", "stan_run=false"), file.path(out_dir, "provenance-note.txt"))
cat("Goal010 synthesis complete: ", out_dir, "\n", sep = "")
