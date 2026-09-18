# Synthesis of corrected predictive checks and the separate timing diagnostic.
options(warn = 2)
original <- "outputs/goal009/first-year-v1"
corrected <- "outputs/goal009/ppc-repaired-v2"
timing_path <- "outputs/goal009/conditional-timing-v1/summary.csv"
out <- "outputs/goal009/synthesis-v2"
profiles <- c("primary", "tail_wide")
ppc <- lapply(profiles, function(p) read.csv(file.path(corrected, p, "ppc-summary.csv")))
latent <- lapply(profiles, function(p) read.csv(file.path(original, p, "latent-richness-pmf.csv")))
timing <- read.csv(timing_path)
diag <- lapply(profiles, function(p) readRDS(file.path(original, p, "attempt-diagnostics.rds"))[[1]]$diagnostics$metrics)
stopifnot(readLines(file.path(corrected, "STATUS.txt")) == "COMPLETE: corrected PPC; original fits preserved")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
comparison <- do.call(rbind, lapply(seq_along(profiles), function(i) cbind(profile=profiles[i], ppc[[i]])))
write.csv(comparison, file.path(out, "criticism-comparison.csv"), row.names=FALSE)
richness <- do.call(rbind,lapply(seq_along(profiles),function(i) {
  x <- latent[[i]]
  qs <- vapply(c(.05,.5,.95),function(v) x$richness[which(cumsum(x$probability)>=v)[1]],numeric(1))
  data.frame(profile=profiles[i],mean=sum(x$richness*x$probability),q05=qs[1],median=qs[2],q95=qs[3])
}))
write.csv(richness,file.path(out,"latent-richness-summary.csv"),row.names=FALSE)
write.csv(do.call(rbind,lapply(seq_along(profiles),function(i) cbind(profile=profiles[i],as.data.frame(diag[[i]])))),file.path(out,"sampler-diagnostics.csv"),row.names=FALSE)
inputs <- c(unlist(lapply(profiles,function(p) c(file.path(corrected,p,"ppc-summary.csv"),file.path(original,p,"latent-richness-pmf.csv"),file.path(original,p,"attempt-diagnostics.rds")))), timing_path)
write.csv(data.frame(path=inputs,sha256=vapply(inputs,function(p) digest::digest(file=p,algo="sha256",serialize=FALSE),character(1))),file.path(out,"input-receipts.csv"),row.names=FALSE)
colours <- c("#0072B2", "#D55E00", "#009E73")
interval_panel <- function(stat, title, xlab, include_timing=FALSE) {
  rows <- do.call(rbind,lapply(ppc,function(x) x[x$statistic==stat,c("observed","q05","q50","q95")]))
  labels <- c("Primary prior", "Wider-tail prior")
  if (include_timing) {
    rows <- rbind(rows,timing[timing$statistic==stat,c("observed","q05","q50","q95")])
    labels <- c(labels,"Conditional timing")
  }
  stopifnot(length(unique(rows$observed))==1)
  y <- rev(seq_len(nrow(rows)))
  limits <- range(as.matrix(rows))
  plot(NA,xlim=limits+c(-1,1)*diff(limits)*.10,ylim=c(.4,nrow(rows)+.7),yaxt="n",xlab=xlab,ylab="",main=title,bty="l")
  axis(2,at=y,labels=labels,las=1,cex.axis=.85,tick=FALSE)
  abline(v=rows$observed[1],lty=2,col="grey25",lwd=1.5)
  segments(rows$q05,y,rows$q95,y,lwd=3,col=colours[seq_len(nrow(rows))])
  points(rows$q50,y,pch=16,col=colours[seq_len(nrow(rows))],cex=1.2)
  text(rows$observed[1],nrow(rows)+.5,paste("Observed",rows$observed[1]),cex=.8)
}
draw <- function() {
  par(mfrow=c(2,2),mar=c(4.4,8.5,3.3,1),oma=c(3.3,0,1.5,0),mgp=c(2.7,.7,0))
  interval_panel("pademelon_bettong_crossing","A  Opposite station contrasts","Matched-week crossing statistic")
  interval_panel("global_commonranking_violation","B  Network station pattern","Common-ranking violation statistic")
  interval_panel("adjacent_switch_count","C  Week-to-week switches","Switch count",TRUE)
  par(mar=c(4.4,5,3.3,1))
  plot(latent[[1]]$richness,latent[[1]]$probability,type="h",xlim=c(20,42),ylim=c(0,max(vapply(latent,function(x) max(x$probability),numeric(1)))*1.2),col=colours[1],lwd=2,xlab="Latent candidate-pool richness",ylab="Posterior probability",main="D  Unvalidated richness estimates",bty="l")
  lines(latent[[2]]$richness+.12,latent[[2]]$probability,type="h",col=colours[2],lwd=2)
  legend("topright",c("Primary prior","Wider-tail prior"),col=colours[1:2],lty=1,lwd=2,bty="n",cex=.8)
  mtext("Points: medians; bars: central 90% intervals. Dashed lines: observed statistics.",side=1,outer=TRUE,line=.3,cex=.85)
  mtext("Conditional timing preserves species-by-station-by-effort counts; panels A-C are development checks.",side=1,outer=TRUE,line=1.5,cex=.8)
}
png(file.path(out,"baseline-criticism.png"),width=2200,height=1500,res=200);draw();dev.off()
pdf(file.path(out,"baseline-criticism.pdf"),width=11,height=7.5);draw();dev.off()
print(richness)
