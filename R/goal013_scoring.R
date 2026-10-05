# Exact count scoring and a deliberately conservative descriptive selection rule.
goal013_count_pmf <- function(p) {
  stopifnot(is.numeric(p), all(is.finite(p)), all(p >= 0 & p <= 1))
  out <- 1
  for (prob in p) out <- c(out * (1 - prob), 0) + c(0, out * prob)
  out / sum(out)
}

goal013_select <- function(scores, converged, margin = 2) {
  names_required <- c("static", "harmonic", "array", "station")
  stopifnot(all(names_required %in% names(scores)), length(converged) == 4)
  if (!all(converged) || any(!is.finite(scores[names_required]))) return("numerical_failure")
  dynamic <- sort(scores[c("harmonic", "array", "station")], decreasing = TRUE)
  if (dynamic[1] <= scores["static"] + margin) return("static_compatible")
  if (dynamic[1] - dynamic[2] < margin) return("unresolved")
  names(dynamic)[1]
}

goal013_score_events <- function(p, observed) {
  stopifnot(length(p) == length(observed), all(observed %in% c(0, 1)))
  pmf <- goal013_count_pmf(p)
  qs <- vapply(c(.05, .95), function(q) which(cumsum(pmf) >= q)[1] - 1L, integer(1))
  count <- sum(observed)
  data.frame(n_species = length(p), expected = sum(p), observed = count,
    lower90 = qs[1], upper90 = qs[2], covered90 = count >= qs[1] && count <= qs[2],
    log_probability = log(pmf[count + 1L]),
    brier = if (length(p)) mean((p - observed)^2) else NA_real_)
}

goal013_binomial_summary <- function(k, n) {
  stopifnot(n > 0, k >= 0, k <= n)
  ci <- binom.test(k, n)$conf.int
  data.frame(n = n, count = k, proportion = k / n, lower95 = ci[1], upper95 = ci[2])
}
