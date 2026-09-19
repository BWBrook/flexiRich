# Small, read-only numerical audit of preserved Goal010 result summaries.
options(warn = 2)
root <- "outputs/goal010/spatial-v1"
out <- "outputs/goal010/audit-v1"
if (dir.exists(out)) stop("Refusing to overwrite audit-v1")
status <- read.csv(file.path(root,"fit-status.csv"))
stopifnot(nrow(status)==8, all(grepl("_clean$",status$terminal_status)))
rows <- controls <- bridges <- decomposition <- membership <- list()
for (id in status$fit_id) {
  d <- file.path(root,id)
  a <- readRDS(file.path(d,"attempt-diagnostics.rds"))
  for (n in names(a)) rows[[length(rows)+1L]] <- data.frame(fit_id=id, attempt=n,
    clean=a[[n]]$diagnostics$clean, as.data.frame(a[[n]]$diagnostics$metrics),
    reasons=paste(a[[n]]$diagnostics$reasons,collapse="; "),
    warning_count=length(a[[n]]$warnings))
  b <- read.csv(file.path(d,"stan-r-bridge.csv"))
  bridges[[id]] <- data.frame(fit_id=id,as.list(vapply(b[-1],max,numeric(1))))
  if (startsWith(id,"control")) {
    p <- read.csv(file.path(d,"ppc-summary.csv"))
    controls[[id]] <- data.frame(fit_id=id,p)
  } else {
    p <- read.csv(file.path(d,"camera-decomposition-correlations.csv"))
    decomposition[[id]] <- data.frame(fit_id=id,p)
    m <- read.csv(file.path(d,"membership-probabilities.csv"))
    z <- m$membership_probability[!m$training_detected]
    membership[[id]] <- data.frame(fit_id=id, unseen_count=length(z),
      mean_unseen_membership=mean(z),min_mc_membership=min(z),max_mc_membership=max(z))
  }
}
prior <- read.csv(file.path(root,"prior-predictive.csv"))
prior_summary <- do.call(rbind,lapply(split(prior,list(prior$prior_id,prior$interaction_scale)),function(z) {
  do.call(rbind,lapply(c("detected_richness","unseen_members","mean_member_detection_probability",
                        "fraction_almost_invisible","fraction_almost_certain"),function(v) {
    q<-quantile(z[[v]],c(.05,.5,.95),names=FALSE)
    data.frame(prior_id=z$prior_id[1], interaction_scale=z$interaction_scale[1],
      statistic=v, q05=q[1],q50=q[2],q95=q[3])
  }))
}))
dir.create(out,recursive=TRUE)
for(n in c("rows","controls","bridges","decomposition","membership"))
  write.csv(do.call(rbind,get(n)),file.path(out,paste0(n,".csv")),row.names=FALSE)
write.csv(prior_summary,file.path(out,"prior-predictive-quantiles.csv"),row.names=FALSE)
cat("Preserved-summary audit complete:",out,"\n")
