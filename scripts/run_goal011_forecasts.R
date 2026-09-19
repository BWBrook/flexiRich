# Generate predictions only; later species outcomes are never inputs here.
options(warn=2)
for(p in sort(list.files("R",pattern="\\.R$",full.names=TRUE))) source(p)
a <- commandArgs(trailingOnly=TRUE)
mode <- if(length(a)) a[1] else "check"
if(!mode %in% c("check","run") || length(a)>2L) stop("Usage: check|run [output_dir]")
out <- if(length(a)==2L) a[2] else "outputs/goal011/forecast-v1"
receipts <- read.csv("config/goal011_inputs.csv")
for(i in seq_len(nrow(receipts))) stopifnot(identical(
  digest::digest(file=receipts$path[i],algo="sha256",serialize=FALSE),receipts$sha256[i]))
models <- read.csv("config/goal011_models.csv")
effort <- read.csv("config/goal011_future_effort.csv")
calendar <- read.csv("config/goal011_future_calendar.csv")
dev <- goal009_read_development()
horizons <- c(13L,26L,52L,101L)
stopifnot(length(dev$data$candidate_ids)==50L,length(dev$data$camera_ids)==9L,
  sum(dev$data$stan_data$detected_ever)==21L,
  sum(dev$data$stan_data$detected_ever==0L)==29L,nrow(models)==6L,!anyDuplicated(models$model_id),!anyDuplicated(models$path_seed),
  identical(models$model_id[models$role=="main"],c("baseline_primary","spatial_primary")),
  nrow(effort)==909L,sum(effort$active_days)==5303L,
  identical(calendar$occasion_index,53:153),identical(calendar$future_week,1:101),
  all(as.Date(calendar$start_date)==as.Date("2019-06-05")+7*(calendar$occasion_index-1L)),
  all(as.Date(calendar$end_date)==as.Date(calendar$start_date)+6L),
  setequal(effort$camera_id,dev$data$camera_ids),
  all(effort$occasion_index==effort$future_week+52L))
# Validate future rows against their reviewed source rather than a new effort model.
reference <- read.csv("config/goal003_task4_effort_template.csv")
key <- function(x) paste(x$camera_id,x$occasion_index,sep="/")
stopifnot(identical(effort$active_days,reference$active_days[match(key(effort),key(reference))]))
for(p in c("outputs/goal009/first-year-v1/fit-status.csv","outputs/goal010/spatial-v1/fit-status.csv"))
  stopifnot(all(grepl("_clean$",read.csv(p)$terminal_status)))
cat("Goal011 six model receipts, first-year identity and future effort/calendar checks passed.\n")
if(mode=="check") {
  # Two retained draws per model are a tiny integration smoke, not frozen
  # scientific forecasts. No prediction or fabricated score is written.
  for(k in seq_len(nrow(models))) {
    z <- readRDS(models$draw_path[k])
    stopifnot(identical(z$candidate_ids,dev$data$candidate_ids),
      identical(z$camera_ids,dev$data$camera_ids))
    selected <- c(1L,nrow(z$q_member))
    for(field in c("q_member","alpha","camera_effect")) z[[field]] <- z[[field]][selected,,drop=FALSE]
    if(!is.null(z$interaction)) z$interaction <- z$interaction[selected,,,drop=FALSE]
    f <- goal011_forecast(z,dev$data$stan_data$detected_ever,
      effort[,c("camera_id","future_week","active_days")],horizons,dev$labels)
    paths <- goal011_draw_paths(f,as.integer(models$path_seed[k]))
    fake <- expand.grid(species_id=z$candidate_ids,horizon=horizons,stringsAsFactors=FALSE)
    fake$detected <- 0L
    invisible(goal011_score_forecast(f,fake))
    stopifnot(all(paths$all_detection==paths$totaldiscovery+paths$redetection))
    rm(z,f,paths);gc(verbose=FALSE)
  }
  cat("Two-draw core/path/scoring integration smoke passed for all six saved fits; no outputs written.\n")
  quit(status=0L)
}
main <- function() {
  stopifnot(Sys.info()[["nodename"]]=="deep-server",nzchar(Sys.getenv("TMUX")))
  if(length(system2("git",c("status","--porcelain"),stdout=TRUE))) stop("Dirty checkout")
  stopifnot(isTRUE(renv::status()$synchronized))
  dest <- .goal003_prepare_output_directory(out,"goal011")
  complete <- FALSE
  on.exit(if(!complete) writeLines("FAILED: preserve and inspect forecasts",file.path(dest,"STATUS.txt")))
  write.csv(receipts,file.path(dest,"input-receipts.csv"),row.names=FALSE)
  write.csv(models,file.path(dest,"model-manifest.csv"),row.names=FALSE)
  write.csv(calendar[calendar$future_week %in% horizons,],file.path(dest,"horizons.csv"),row.names=FALSE)
  writeLines(c(paste0("git_commit=",system2("git",c("rev-parse","HEAD"),stdout=TRUE)),
    paste0("started_utc=",format(Sys.time(),tz="UTC",usetz=TRUE)),
    "training_occasions=1:52","forecast_occasions=53:153",
    "effort=retrospective_conditional_on_reviewed_realised_effort",
    "later_detection_outcomes_read=false","huon_ridge_read=false",
    "known_historical_exposure=Goal008_three_rows_and_prior_aggregate_disclosures",
    "probabilities=all_retained_joint_draws_log_domain_Poisson_binomial_mixture",
    "score_status=unscored_predictions_only","warnings_are_errors=true"),
    file.path(dest,"run-metadata.txt"))
  capture.output(sessionInfo(),file=file.path(dest,"session-info.txt"))
  status <- list()
  for(k in seq_len(nrow(models))) {
    m <- models[k,]; id <- m$model_id
    writeLines(paste("RUNNING:",id),file.path(dest,"STATUS.txt"))
    cat("Forecasting",id,"at",format(Sys.time()),"\n");flush.console()
    draws <- readRDS(m$draw_path)
    if(!"interaction" %in% names(draws)) draws["interaction"] <- list(NULL)
    stopifnot(identical(draws$candidate_ids,dev$data$candidate_ids),
      identical(draws$camera_ids,dev$data$camera_ids))
    f <- goal011_forecast(draws,dev$data$stan_data$detected_ever,
      effort[,c("camera_id","future_week","active_days")],horizons,dev$labels)
    paths <- goal011_draw_paths(f,as.integer(m$path_seed))
    d <- file.path(dest,id);dir.create(d)
    saveRDS(f,file.path(d,"forecast.rds"))
    write.csv(f$species_probabilities,file.path(d,"species-probabilities.csv"),row.names=FALSE)
    write.csv(f$count_pmfs,file.path(d,"count-pmfs.csv"),row.names=FALSE)
    write.csv(paths,file.path(d,"joint-count-paths.csv"),row.names=FALSE)
    status[[k]] <- data.frame(model_id=id,role=m$role,draw_count=f$metadata$draw_count,
      status="predictions_complete_unscored")
    write.csv(do.call(rbind,status),file.path(dest,"model-status.csv"),row.names=FALSE)
    rm(draws,f,paths);gc(verbose=FALSE)
  }
  writeLines("COMPLETE: predictions generated; freeze and audit before outcome access",file.path(dest,"STATUS.txt"))
  files <- sort(list.files(dest,recursive=TRUE,full.names=TRUE))
  hashes <- vapply(files,function(p) digest::digest(file=p,algo="sha256",serialize=FALSE),character(1))
  write.csv(data.frame(path=substring(files,nchar(dest)+2L),sha256=hashes),
    file.path(dest,"output-sha256.csv"),row.names=FALSE)
  complete <- TRUE
  0L
}
quit(status=main())
