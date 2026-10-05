# Fixed, full-effort pair support. These summaries never select fitted models.
goal013_pair_plan <- function(d) {
  D <- nrow(d$y); T <- ncol(d$y)
  index <- matrix(seq_len(D * T), D, T)
  pairs <- list()
  add <- function(name, a, b) {
    ok <- d$effort[a] == 7 & d$effort[b] == 7
    a <- a[ok]; b <- b[ok]
    cl <- d$row_class[((a - 1L) %% D) + 1L]
    for (c in 1:2) {
      aa <- a[cl == c]; bb <- b[cl == c]
      key <- paste(d$group[aa], d$group[bb], sep = ":")
      pairs[[paste(name, c, sep = ":")]] <<- list(name = name, class = c,
        a = aa, b = bb, strata = match(key, unique(key)))
    }
  }
  for (lag in c(1L, 26L, 52L)) {
    a <- index[, seq_len(T - lag)]; b <- index[, (lag + 1L):T]
    ok <- d$group[a] == d$group[b]
    add(paste0("within_station_lag", lag), a[ok], b[ok])
  }
  a <- b <- integer()
  for (s in unique(d$row_species)) {
    rows <- which(d$row_species == s)
    combinations <- combn(rows, 2)
    for (k in seq_len(ncol(combinations))) {
      a <- c(a, index[combinations[1, k], ])
      b <- c(b, index[combinations[2, k], ])
    }
  }
  add("same_species_cross_station", a, b)
  a <- b <- integer()
  for (station in unique(d$rows$camera_id)) for (cl in 1:2) {
    rows <- which(d$rows$camera_id == station & d$row_class == cl)
    if (length(rows) < 2L) next
    combinations <- combn(rows, 2)
    for (k in seq_len(ncol(combinations))) {
      a <- c(a, index[combinations[1, k], ])
      b <- c(b, index[combinations[2, k], ])
    }
  }
  add("same_station_cross_species", a, b)
  pairs
}

goal013_pair_statistics <- function(y, plan) {
  do.call(rbind, lapply(plan, function(z) {
    a <- y[z$a]; b <- y[z$b]
    stopifnot(!anyNA(a), !anyNA(b))
    n <- if (length(z$strata)) max(z$strata) else 0L
    counts <- matrix(tabulate(1L + 2L * a + b + 4L * (z$strata - 1L), 4L * n), 4L, n)
    denominator <- colSums(counts)
    numerator <- sum(counts[1, ] * counts[4, ] / denominator)
    divisor <- sum(counts[2, ] * counts[3, ] / denominator)
    data.frame(statistic = z$name, taxon = c("Aves", "Mammalia")[z$class],
      pairs = length(a), switches = sum(a != b), positives_both = sum(a == 1 & b == 1),
      mh_or = if (divisor > 0) numerator / divisor else NA_real_)
  }))
}
