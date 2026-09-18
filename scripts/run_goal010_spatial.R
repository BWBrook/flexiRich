# Frozen first-year species-by-station comparison and two tiny mechanism controls.
options(warn = 1)
if (!file.exists("config/goal010_fits.csv")) stop("Run from the repository root")
for (path in sort(list.files("R", pattern = "\\.R$", full.names = TRUE))) source(path)
args <- commandArgs(trailingOnly = TRUE)
mode <- if (length(args)) args[[1]] else "check"
if (!mode %in% c("check", "run") || length(args) > 2L) stop("Usage: check|run [output_dir]")
output_dir <- if (length(args) == 2L) args[[2]] else "outputs/goal010/spatial-v1"
receipts <- read.csv("config/goal010_inputs.csv")
for (i in seq_len(nrow(receipts))) stopifnot(identical(
  digest::digest(file = receipts$path[i], algo = "sha256", serialize = FALSE), receipts$sha256[i]))
manifest <- read.csv("config/goal010_fits.csv")
stopifnot(nrow(manifest) == 8L, !anyDuplicated(manifest$fit_id),
          !anyDuplicated(c(manifest$fit_seed, manifest$fit_seed+1L, manifest$ppc_seed)),
          all(manifest$ppc_draws == 1000L))
development <- goal009_read_development()
theory <- goal010_theory_checks(development$data)
synthetic <- goal010_synthetic_cases()
# Exercise each adapter and monitoring contract before compilation or launch.
for (k in seq_len(nrow(manifest))) {
  spec <- manifest[k, ]
  case <- if (spec$data_id == "first_year") development else synthetic[[spec$data_id]]
  if (spec$model_id == "spatial") {
    data <- prepare_goal010_spatial_data(case$data, spec$prior_id, spec$interaction_scale)
    stopifnot("station_log_rate" %in% goal010_monitored_variables(data))
  } else {
    data <- prepare_goal003_flexirich_data(case$data, spec$prior_id)
    stopifnot("alpha" %in% .goal003_flexirich_monitored_variables(data))
  }
}
print(theory)
cat("Goal010 first-year inputs, mathematical checks and paired control construction passed.\n")
if (mode == "check") quit(status = 0L)

main <- function() {
  stopifnot(identical(unname(Sys.info()[["nodename"]]), "deep-server"), nzchar(Sys.getenv("TMUX")))
  if (length(system2("git", c("status", "--porcelain"), stdout = TRUE))) stop("Dirty checkout")
  stopifnot(isTRUE(renv::status()$synchronized))
  destination <- .goal003_prepare_output_directory(output_dir, "goal010")
  done <- FALSE
  on.exit(if (!done) writeLines("FAILED: preserved outputs require inspection", file.path(destination,"STATUS.txt")))
  writeLines("RUNNING: prior checks and compilation", file.path(destination,"STATUS.txt"))
  write.csv(manifest, file.path(destination,"fit-manifest.csv"), row.names=FALSE)
  write.csv(receipts, file.path(destination,"input-receipts.csv"), row.names=FALSE)
  write.csv(theory, file.path(destination,"theory-checks.csv"), row.names=FALSE)
  saveRDS(synthetic,file.path(destination,"paired-controls.rds"))
  writeLines(c(paste0("git_commit=",system2("git",c("rev-parse","HEAD"),stdout=TRUE)),
    paste0("started_utc=",format(Sys.time(),tz="UTC",usetz=TRUE)),
    paste0("host=",Sys.info()[["nodename"]]), paste0("cmdstan=",cmdstanr::cmdstan_version()),
    "training_occasions=1:52", "later_outcomes_read=false", "huon_ridge_read=false",
    "purpose=development_spatial_mechanism_comparison",
    "controls=two_paired_fixed_mechanisms_not_coverage", "synthetic_seed=7300401",
    "prior_seed=7300301", "prior_draws_per_profile=2000",
    "postprocessing_warnings_are_errors=true"),file.path(destination,"run-metadata.txt"))
  capture.output(sessionInfo(),file=file.path(destination,"session-info.txt"))
  prior <- withr::with_options(list(warn=2),goal010_prior_predictive(development$data))
  write.csv(prior,file.path(destination,"prior-predictive.csv"),row.names=FALSE)
  models <- list(
    baseline=.goal003_compile_model("stan/goal003_flexirich.stan","baseline","goal010-baseline","goal010"),
    spatial=.goal003_compile_model("stan/goal010_spatial.stan","spatial","goal010-spatial","goal010"))
  profiles <- goal003_flexirich_sampler_profiles()
  # More cautious initial integration for the additional hierarchical effects.
  profiles$primary$adapt_delta <- 0.95
  profiles$primary$profile_id <- "goal010-primary-sampler-v1"
  thresholds <- goal003_flexirich_diagnostic_thresholds()
  statuses <- list()
  for (k in seq_len(nrow(manifest))) {
    spec <- manifest[k, ]
    case <- if (spec$data_id == "first_year") development else synthetic[[spec$data_id]]
    data <- if (spec$model_id == "spatial") prepare_goal010_spatial_data(
      case$data,spec$prior_id,spec$interaction_scale) else
        prepare_goal003_flexirich_data(case$data,spec$prior_id)
    monitored <- if (spec$model_id == "spatial") goal010_monitored_variables(data) else
      .goal003_flexirich_monitored_variables(data)
    fit_dir <- file.path(destination,spec$fit_id); dir.create(fit_dir)
    saveRDS(data,file.path(fit_dir,"model-data.rds"))
    if (!is.null(case$truth)) saveRDS(case$truth,file.path(fit_dir,"truth.rds"))
    writeLines(paste("RUNNING:",spec$fit_id),file.path(destination,"STATUS.txt"))
    cat("Starting",spec$fit_id,"at",format(Sys.time()),"\n");flush.console()
    attempts <- list(); clean <- FALSE
    for (attempt_id in c("primary","rescue")) {
      captured_warnings <- character()
      result <- withCallingHandlers(.goal003_model_attempt(models[[spec$model_id]],
        data$stan_data,profiles[[attempt_id]],thresholds,monitored,
        as.integer(spec$fit_seed+(attempt_id=="rescue")),
        file.path(fit_dir,attempt_id),attempt_id,100L),warning=function(w) {
          captured_warnings <<- c(captured_warnings,conditionMessage(w))
        })
      attempts[[attempt_id]] <- c(result[c("attempt_id","profile","elapsed_seconds","diagnostics")],
                                  list(warnings=captured_warnings))
      saveRDS(attempts,file.path(fit_dir,"attempt-diagnostics.rds"))
      capture.output(str(attempts,max.level=5),file=file.path(fit_dir,"attempt-diagnostics.txt"))
      if (isTRUE(result$diagnostics$clean)) {clean <- TRUE;break}
    }
    statuses[[k]] <- data.frame(fit_id=spec$fit_id,data_id=spec$data_id,
      terminal_status=if (clean) paste0(attempt_id,"_clean") else "final_nonclean")
    write.csv(do.call(rbind,statuses),file.path(destination,"fit-status.csv"),row.names=FALSE)
    if (!clean) {cat("Nonclean fit retained:",spec$fit_id,"\n");next}
    withr::with_options(list(warn=2), {
      fit <- result$fit
      write.csv(fit$summary(variables=monitored),file.path(fit_dir,"parameter-summary.csv"),row.names=FALSE)
      if (spec$model_id == "spatial") {
        draws <- goal010_extract_draws(fit,data)
      } else {
        m <- posterior::as_draws_matrix(fit$draws(variables=c("q_member","alpha","camera_effect")))
        plain <- matrix(as.numeric(m),nrow=nrow(m),dimnames=dimnames(m))
        C <- length(data$candidate_ids); J <- length(data$camera_ids)
        draws <- list(q_member=plain[,sprintf("q_member[%d]",seq_len(C)),drop=FALSE],
          alpha=plain[,sprintf("alpha[%d]",seq_len(C)),drop=FALSE],
          camera_effect=plain[,sprintf("camera_effect[%d]",seq_len(J)),drop=FALSE],
          interaction=NULL,candidate_ids=data$candidate_ids,camera_ids=data$camera_ids)
      }
      bridge <- goal010_fit_bridge(fit, data, draws)
      write.csv(bridge,file.path(fit_dir,"stan-r-bridge.csv"),row.names=FALSE)
      saveRDS(draws,file.path(fit_dir,"prediction-draws.rds"))
      latent <- .goal003_mean_poisson_binomial(draws$q_member)
      write.csv(latent,file.path(fit_dir,"latent-richness-pmf.csv"),row.names=FALSE)
      write.csv(data.frame(species_id=data$candidate_ids,training_detected=data$detected_ever==1L,
        membership_probability=colMeans(draws$q_member)),file.path(fit_dir,"membership-probabilities.csv"),row.names=FALSE)
      ppc <- goal009_ppc(case$data,draws$q_member,draws$alpha,draws$camera_effect,
        case$labels,as.integer(spec$ppc_seed),as.integer(spec$ppc_draws),interaction_draws=draws$interaction)
      fields <- c(summary="ppc-summary.csv",draw_statistics="ppc-draw-statistics.csv",
        species_station="ppc-species-station.csv",species_counts="ppc-species-counts.csv",species_block="ppc-species-block.csv")
      for (field in names(fields)) write.csv(ppc[[field]],file.path(fit_dir,fields[[field]]),row.names=FALSE)
      saveRDS(ppc$metadata,file.path(fit_dir,"ppc-metadata.rds"))
      core_names <- c("omega","mu_alpha","sigma_alpha","sigma_camera",
        if (spec$model_id == "spatial") "sigma_interaction", "expected_richness")
      core <- posterior::as_draws_array(fit$draws(variables=core_names))
      core_matrix <- as.matrix(posterior::as_draws_matrix(core))
      write.csv(cor(core_matrix),file.path(fit_dir,"core-correlations.csv"))
      if (spec$model_id == "spatial") {
        observed_mean_u <- apply(draws$interaction[,data$detected_ever==1L,,drop=FALSE],c(1,3),mean)
        correlations <- vapply(seq_along(data$camera_ids),function(j)
          cor(draws$camera_effect[,j],observed_mean_u[,j]),numeric(1))
        write.csv(data.frame(camera_id=data$camera_ids,cor_b_mean_observed_u=correlations),
          file.path(fit_dir,"camera-decomposition-correlations.csv"),row.names=FALSE)
        write.csv(data.frame(event=c("interaction_sd_below_0.05","interaction_sd_above_2"),
          probability=c(mean(core_matrix[,"sigma_interaction"]<.05),mean(core_matrix[,"sigma_interaction"]>2))),
          file.path(fit_dir,"boundary-mass-descriptive.csv"),row.names=FALSE)
      }
      pdf(file.path(fit_dir,"core-chain-diagnostics.pdf"),width=9,height=7)
      for (variable in core_names) {
        par(mfrow=c(2,1),mar=c(4,4,3,1))
        values <- matrix(as.numeric(core[,,variable]),nrow=dim(core)[1],ncol=dim(core)[2])
        matplot(values,type="l",lty=1,col=1:4,xlab="Retained iteration",ylab=variable,main=paste(variable,"by chain"))
        ranks <- matrix(rank(as.vector(values)),nrow=nrow(values))
        breaks <- seq(0,length(values)+1,length.out=21)
        counts <- vapply(seq_len(ncol(values)),function(j) hist(ranks[,j],breaks=breaks,plot=FALSE)$counts,integer(20))
        matplot((head(breaks,-1)+tail(breaks,-1))/2,counts,type="l",lty=1,col=1:4,xlab="Pooled rank",ylab="Count")
        abline(h=nrow(values)/20,lty=2,col="grey50")
      }
      dev.off()
    })
    cat("Completed",spec$fit_id,statuses[[k]]$terminal_status,"\n");flush.console()
  }
  all_clean <- all(vapply(statuses,function(x) x$terminal_status!="final_nonclean",logical(1)))
  writeLines(if (all_clean) "COMPLETE: spatial comparison ready for interpretation" else
    "COMPLETE_WITH_NONCLEAN_FITS: inspect retained attempts",file.path(destination,"STATUS.txt"))
  done <- TRUE
  if (all_clean) 0L else 2L
}
quit(status=main())
