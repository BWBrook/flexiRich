# Draw coherent nested event-count paths from the conditional posterior mixture.
goal011_draw_paths <- function(forecast, seed) {
  x <- forecast$per_draw$log_detection
  stopifnot(is.array(x),length(dim(x))==3L,all(!is.na(x)),all(x<=0),
    is.numeric(seed),length(seed)==1L,is.finite(seed),seed>0,seed==as.integer(seed))
  D <- dim(x)[1]; C <- dim(x)[2]; H <- dim(x)[3]
  ids <- forecast$metadata$candidate_ids; horizons <- forecast$metadata$horizons
  known <- forecast$species_probabilities$known_member[
    match(ids,forecast$species_probabilities$species_id)]
  stopifnot(length(known)==C,!anyNA(known),all(known %in% c(0,1)),length(horizons)==H)
  known <- as.logical(known)
  withr::with_seed(seed, {
    # A single uniform follows each candidate through all horizons. The CDF
    # q_i*(1-exp(-H_i)) already includes the persistent membership mixture.
    log_u <- matrix(log(runif(D*C)),D,C)
    old <- matrix(FALSE,D,C)
    rows <- vector("list",H)
    for(h in seq_len(H)) {
      seen <- log_u < matrix(x[,,h],D,C)
      if(any(old & !seen)) stop("Cumulative event probabilities are not nested")
      rows[[h]] <- data.frame(draw_index=seq_len(D),horizon=horizons[h],
        totaldiscovery=rowSums(seen[,!known,drop=FALSE]),
        redetection=rowSums(seen[,known,drop=FALSE]),all_detection=rowSums(seen))
      old <- seen
    }
    do.call(rbind,rows)
  }, .rng_kind="Mersenne-Twister",.rng_normal_kind="Inversion",.rng_sample_kind="Rejection")
}
