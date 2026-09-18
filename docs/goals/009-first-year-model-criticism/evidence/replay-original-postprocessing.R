# Replay frozen postprocessing only; never calls a sampler or reads raw data.
# Load the original functions, including the defect, from the immutable commit.
frozen_commit <- "e183888960c6ff5cdc7146e6549bf876f6e3484a"
paths <- system2("git", c("ls-tree", "-r", "--name-only", frozen_commit, "R"), stdout=TRUE)
for (path in sort(paths[grepl("[.]R$", paths)])) {
  eval(parse(text=system2("git", c("show", paste0(frozen_commit, ":", path)), stdout=TRUE)), envir=.GlobalEnv)
}
development <- goal009_read_development()
manifest <- read.csv("config/goal009_fits.csv")
destination <- "outputs/goal009/original-postprocessing-replay"
if (file.exists(destination)) stop("Replay destination already exists")
dir.create(destination, recursive=TRUE)
records <- list()
for (k in seq_len(nrow(manifest))) {
  spec <- manifest[k, ]
  input <- file.path("outputs/goal009/first-year-v1", spec$fit_id)
  fit_dir <- file.path(destination, spec$fit_id)
  dir.create(fit_dir, showWarnings=FALSE)
  data <- readRDS(file.path(input, "model-data.rds"))
  withCallingHandlers({
    result <- list(fit=cmdstanr::as_cmdstan_fit(sort(list.files(file.path(input,"primary"), pattern="\\.csv$", full.names=TRUE))))
    fit <- result$fit
    write.csv(fit$summary(variables = .goal003_flexirich_monitored_variables(data)),
              file.path(fit_dir, "parameter-summary.csv"), row.names = FALSE)
    core_names <- c("omega", "mu_alpha", "sigma_alpha", "sigma_camera", "expected_richness")
    core <- posterior::as_draws_array(fit$draws(variables = core_names))
    core_matrix <- posterior::as_draws_matrix(core)
    write.csv(stats::cor(core_matrix), file.path(fit_dir, "core-correlations.csv"))
    write.csv(data.frame(
      event = c("omega_below_0.01", "omega_above_0.99", "species_sd_below_0.01",
                "camera_sd_below_0.01"),
      probability = c(mean(core_matrix[, "omega"] < 0.01),
                      mean(core_matrix[, "omega"] > 0.99),
                      mean(core_matrix[, "sigma_alpha"] < 0.01),
                      mean(core_matrix[, "sigma_camera"] < 0.01))
    ), file.path(fit_dir, "boundary-mass-descriptive.csv"), row.names = FALSE)
    pdf(file.path(fit_dir, "core-chain-diagnostics.pdf"), width = 9, height = 7)
    colours <- c("#0072B2", "#D55E00", "#009E73", "#CC79A7")
    for (variable in core_names) {
      par(mfrow = c(2, 1), mar = c(4, 4, 3, 1))
      values <- matrix(as.numeric(core[, , variable]), nrow = dim(core)[1L],
                       ncol = dim(core)[2L])
      matplot(values, type = "l", lty = 1, col = colours, xlab = "Retained iteration",
              ylab = variable, main = paste(variable, "by chain"))
      ranks <- matrix(rank(as.vector(values)), nrow = nrow(values))
      breaks <- seq(0, length(values) + 1, length.out = 21L)
      counts <- vapply(seq_len(ncol(values)), function(chain)
        hist(ranks[, chain], breaks = breaks, plot = FALSE)$counts, integer(20L))
      matplot((head(breaks, -1L) + tail(breaks, -1L)) / 2, counts,
              type = "l", lty = 1, col = colours, xlab = "Pooled rank",
              ylab = "Count", main = "Rank histograms by chain")
      abline(h = nrow(values) / 20, lty = 2, col = "grey50")
    }
    dev.off()
    C <- length(data$candidate_ids)
    J <- length(data$camera_ids)
    draws <- posterior::as_draws_matrix(fit$draws(
      variables = c("q_member", "alpha", "camera_effect")
    ))
    q <- as.matrix(draws[, sprintf("q_member[%d]", seq_len(C)), drop = FALSE])
    alpha <- as.matrix(draws[, sprintf("alpha[%d]", seq_len(C)), drop = FALSE])
    camera <- as.matrix(draws[, sprintf("camera_effect[%d]", seq_len(J)), drop = FALSE])
    # These matrices share exactly the same retained joint-draw order.
    saveRDS(list(q_member = q, alpha = alpha, camera_effect = camera,
                 candidate_ids = data$candidate_ids, camera_ids = data$camera_ids),
            file.path(fit_dir, "prediction-draws.rds"))
    latent <- summarise_goal003_flexirich_draws(
      q, alpha, camera, data$candidate_ids, data$camera_ids, data$detected_ever
    )
    write.csv(latent$richness_pmf, file.path(fit_dir, "latent-richness-pmf.csv"),
              row.names = FALSE)
    write.csv(latent$grid_identity, file.path(fit_dir, "membership-probabilities.csv"),
              row.names = FALSE)
    ppc <- goal009_ppc(development$data, q, alpha, camera, development$labels,
                       as.integer(spec$ppc_seed), as.integer(spec$ppc_draws))
    write.csv(ppc$summary, file.path(fit_dir, "ppc-summary.csv"), row.names = FALSE)
    write.csv(ppc$draw_statistics, file.path(fit_dir, "ppc-draw-statistics.csv"),
              row.names = FALSE)
    write.csv(ppc$species_station, file.path(fit_dir, "ppc-species-station.csv"),
              row.names = FALSE)
    write.csv(ppc$species_counts, file.path(fit_dir, "ppc-species-counts.csv"),
              row.names = FALSE)
    write.csv(ppc$species_block, file.path(fit_dir, "ppc-species-block.csv"),
              row.names = FALSE)
    saveRDS(ppc$metadata, file.path(fit_dir, "ppc-metadata.rds"))
    pdf(file.path(fit_dir, "ppc-overview.pdf"), width = 10, height = 8)
    par(mfrow = c(3, 3), mar = c(3, 3, 3, 1))
    for (i in seq_len(nrow(ppc$summary))) {
      row <- ppc$summary[i, ]
      limits <- range(c(row$observed, row$q05, row$q95))
      if (diff(limits) == 0) limits <- limits + c(-0.5, 0.5)
      plot(NA, xlim = limits, ylim = c(0, 1), yaxt = "n", ylab = "", xlab = "",
           main = gsub("_", " ", row$statistic), cex.main = 0.8)
      segments(row$q05, 0.5, row$q95, 0.5, lwd = 3, col = "steelblue")
      points(row$q50, 0.5, pch = 16, col = "steelblue")
      abline(v = row$observed, col = "firebrick", lwd = 2)
      mtext("Blue: predictive median/90% interval; red: observed", side = 1,
            line = 2, cex = 0.55)
    }
    dev.off()

  }, warning=function(w) {
    records[[length(records)+1L]] <<- data.frame(profile=spec$fit_id,
      message=conditionMessage(w), call=paste(deparse(conditionCall(w)),collapse=" "))
    invokeRestart("muffleWarning")
  })
  cat("Replayed", spec$fit_id, "\n")
  flush.console()
}
warnings <- if (length(records)) do.call(rbind,records) else data.frame(profile=character(),message=character(),call=character())
write.csv(warnings,file.path(destination,"warnings.csv"),row.names=FALSE)
print(as.data.frame(table(warnings$profile,warnings$message)))
checks <- list()
for (profile in manifest$fit_id) {
  replay_dir <- file.path(destination,profile)
  original_dir <- file.path("outputs/goal009/first-year-v1",profile)
  for (file in list.files(replay_dir,pattern="\\.csv$")) {
    a <- read.csv(file.path(original_dir,file),check.names=FALSE)
    b <- read.csv(file.path(replay_dir,file),check.names=FALSE)
    checks[[length(checks)+1L]] <- data.frame(profile=profile,file=file,
      exact=isTRUE(all.equal(a,b,tolerance=0)),
      within_tolerance=isTRUE(all.equal(a,b,tolerance=1e-10)))
  }
}
checks <- do.call(rbind,checks)
write.csv(checks,file.path(destination,"csv-comparison.csv"),row.names=FALSE)
print(checks)
stopifnot(all(checks$within_tolerance))
