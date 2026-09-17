# First-year-only posterior predictive criticism. No raw source data reader.
if (!file.exists("config/goal009_fits.csv")) {
  stop("Run from the flexiRich repository root.", call. = FALSE)
}
for (path in sort(list.files("R", pattern = "\\.R$", full.names = TRUE))) {
  source(path, local = FALSE)
}

args <- commandArgs(trailingOnly = TRUE)
mode <- if (length(args)) args[[1L]] else "check"
if (!mode %in% c("check", "run") || length(args) > 2L) {
  stop("Usage: Rscript scripts/run_goal009_criticism.R check|run [output_dir]")
}
output_dir <- if (length(args) == 2L) args[[2L]] else
  "outputs/goal009/first-year-v1"

receipts <- read.csv("config/goal009_inputs.csv", stringsAsFactors = FALSE)
for (i in seq_len(nrow(receipts))) {
  path <- receipts$path[[i]]
  if (!file.exists(path) || !identical(
    digest::digest(file = path, algo = "sha256", serialize = FALSE),
    receipts$sha256[[i]]
  )) stop("Frozen input missing or changed: ", path, call. = FALSE)
}
manifest <- read.csv("config/goal009_fits.csv", stringsAsFactors = FALSE)
stopifnot(identical(manifest$fit_id, c("primary", "tail_wide")),
          identical(manifest$prior_id, c("primary", "tail_wide")),
          all(manifest$ppc_draws == 1000L),
          !anyDuplicated(c(manifest$fit_seed, manifest$fit_seed + 1L,
                           manifest$ppc_seed)))
development <- goal009_read_development()
bridge <- goal009_sequential_bridge()
stopifnot(isTRUE(bridge$normalized_same_grid),
          isTRUE(bridge$reverse_period_order_agreement),
          isTRUE(bridge$wrong_reset_control_differs),
          bridge$max_abs_difference <= 1e-12,
          all(is.finite(bridge$error_fields)),
          all(bridge$error_fields[grepl("_error$", names(bridge$error_fields))] <= 1e-12),
          bridge$error_fields[["known_detection_min_membership_probability"]] == 1)
cat("Goal009 first-year input and identity bridge checks passed.\n")
print(bridge$error_fields)
if (mode == "check") quit(status = 0L)

main <- function() {
  if (!identical(unname(Sys.info()[["nodename"]]), "deep-server") ||
      !nzchar(Sys.getenv("TMUX"))) {
    stop("Empirical fitting requires deep-server in a named tmux session.")
  }
  dirty <- system2("git", c("status", "--porcelain"), stdout = TRUE)
  if (length(dirty)) stop("Run requires a clean committed checkout.")
  git_commit <- system2("git", c("rev-parse", "HEAD"), stdout = TRUE)
  if (!isTRUE(renv::status()$synchronized)) {
    stop("Restore the project library to renv.lock before launch.")
  }
  destination <- .goal003_prepare_output_directory(output_dir, "goal009")
  done <- FALSE
  on.exit({
    if (!done) writeLines("FAILED: inspect run.log and retained attempts",
                          file.path(destination, "STATUS.txt"))
  }, add = TRUE)
  writeLines("RUNNING: compiling baseline", file.path(destination, "STATUS.txt"))
  write.csv(manifest, file.path(destination, "fit-manifest.csv"), row.names = FALSE)
  write.csv(receipts, file.path(destination, "input-receipts.csv"), row.names = FALSE)
  saveRDS(bridge, file.path(destination, "sequential-bridge.rds"))
  writeLines(c(
    paste0("git_commit=", git_commit),
    paste0("started_utc=", format(Sys.time(), tz = "UTC", usetz = TRUE)),
    paste0("host=", Sys.info()[["nodename"]]),
    paste0("cmdstan=", cmdstanr::cmdstan_version()),
    "training_occasions=1:52", "later_outcomes_read=false",
    "huon_ridge_read=false", "purpose=development_model_criticism"
  ), file.path(destination, "run-metadata.txt"))
  capture.output(sessionInfo(), file = file.path(destination, "session-info.txt"))
  model <- .goal003_compile_model(
    "stan/goal003_flexirich.stan", "baseline", "goal009-baseline",
    output_namespace = "goal009"
  )
  profiles <- goal003_flexirich_sampler_profiles()
  thresholds <- goal003_flexirich_diagnostic_thresholds()
  statuses <- vector("list", nrow(manifest))
  for (k in seq_len(nrow(manifest))) {
    spec <- manifest[k, ]
    fit_dir <- file.path(destination, spec$fit_id)
    dir.create(fit_dir)
    cat("Starting", spec$fit_id, "at", format(Sys.time()), "\n")
    flush.console()
    writeLines(paste("RUNNING:", spec$fit_id), file.path(destination, "STATUS.txt"))
    data <- prepare_goal003_flexirich_data(development$data, spec$prior_id)
    saveRDS(data, file.path(fit_dir, "model-data.rds"))
    attempts <- list()
    clean <- FALSE
    for (attempt_id in c("primary", "rescue")) {
      result <- .goal003_model_attempt(
        model, data$stan_data, profiles[[attempt_id]], thresholds,
        .goal003_flexirich_monitored_variables(data),
        as.integer(spec$fit_seed + (attempt_id == "rescue")),
        file.path(fit_dir, attempt_id), attempt_id, 100L
      )
      attempts[[attempt_id]] <- result[c("attempt_id", "profile",
                                         "elapsed_seconds", "diagnostics")]
      saveRDS(attempts, file.path(fit_dir, "attempt-diagnostics.rds"))
      capture.output(str(attempts, max.level = 5L),
                     file = file.path(fit_dir, "attempt-diagnostics.txt"))
      if (isTRUE(result$diagnostics$clean)) {
        clean <- TRUE
        break
      }
    }
    statuses[[k]] <- data.frame(
      fit_id = spec$fit_id, terminal_status = if (clean)
        paste0(attempt_id, "_clean") else "final_nonclean"
    )
    write.csv(do.call(rbind, statuses[seq_len(k)]),
              file.path(destination, "fit-status.csv"), row.names = FALSE)
    if (!clean) {
      cat("Nonclean fit retained without scientific summaries:", spec$fit_id, "\n")
      next
    }
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
    cat("Completed", spec$fit_id, statuses[[k]]$terminal_status, "\n")
    flush.console()
  }
  all_clean <- all(vapply(statuses, function(x)
    x$terminal_status != "final_nonclean", logical(1)))
  writeLines(if (all_clean) "COMPLETE: model criticism ready for interpretation" else
    "COMPLETE_WITH_NONCLEAN_FITS: inspect diagnostics; no validation claim",
    file.path(destination, "STATUS.txt"))
  done <- TRUE
  if (!all_clean) return(2L)
  0L
}
exit_status <- main()
quit(status = exit_status)
