.goal002r_scalar <- function(
  x,
  name,
  lower = -Inf,
  upper = Inf,
  allow_negative_infinity = FALSE
) {
  finite_or_allowed <- is.finite(x) ||
    (allow_negative_infinity && identical(x, -Inf))
  if (!is.numeric(x) || length(x) != 1L || is.na(x) ||
      !finite_or_allowed || x < lower || x > upper) {
    .goal002r_stop(paste0(name, " must be one finite numeric scalar."))
  }
  as.numeric(x)
}

goal002r_gauss_hermite_rule <- function(order) {
  order <- .goal002r_scalar(order, "order", lower = 1)
  if (order != trunc(order)) {
    .goal002r_stop("order must be a whole number.")
  }
  order <- as.integer(order)
  matrix <- matrix(0, nrow = order, ncol = order)
  if (order > 1L) {
    off_diagonal <- sqrt(seq_len(order - 1L) / 2)
    matrix[cbind(seq_len(order - 1L), seq_len(order - 1L) + 1L)] <-
      off_diagonal
    matrix[cbind(seq_len(order - 1L) + 1L, seq_len(order - 1L))] <-
      off_diagonal
  }
  eig <- eigen(matrix, symmetric = TRUE)
  order_index <- order(eig$values)
  nodes <- eig$values[order_index]
  weights <- sqrt(pi) * eig$vectors[1L, order_index]^2
  weights <- weights / sum(weights)
  tibble::tibble(
    node = as.numeric(sqrt(2) * nodes),
    weight = as.numeric(weights)
  )
}

goal002r_log_m0 <- function(
  zero_history,
  mu_alpha,
  sigma_alpha,
  camera_effect,
  rule = goal002r_gauss_hermite_rule(
    goal002r_contract()$quadrature_default
  )
) {
  required <- c("camera_id", "active_days", "n_trials")
  if (!tibble::is_tibble(zero_history) ||
      !identical(names(zero_history), required) ||
      nrow(zero_history) == 0L) {
    if (nrow(zero_history) == 0L) return(0)
    .goal002r_stop("zero_history has an invalid contract.")
  }
  mu_alpha <- .goal002r_scalar(mu_alpha, "mu_alpha")
  sigma_alpha <- .goal002r_scalar(sigma_alpha, "sigma_alpha", lower = 0)
  if (!is.numeric(camera_effect) || is.null(names(camera_effect)) ||
      anyNA(camera_effect) || any(!is.finite(camera_effect))) {
    .goal002r_stop("camera_effect must be a named finite vector.")
  }
  if (any(!zero_history$camera_id %in% names(camera_effect))) {
    .goal002r_stop("zero_history contains an unknown camera.")
  }
  camera <- unname(camera_effect[zero_history$camera_id])
  integrated_log_likelihood <- function(alpha) {
    log_rate <- alpha + camera
    sum(zero_history$n_trials *
      log_nondetect_probability(log_rate, zero_history$active_days))
  }
  if (sigma_alpha == 0 || nrow(rule) == 1L) {
    return(integrated_log_likelihood(mu_alpha))
  }
  log_values <- vapply(
    seq_len(nrow(rule)),
    function(i) integrated_log_likelihood(mu_alpha + sigma_alpha * rule$node[i]),
    numeric(1)
  )
  anchor <- max(log_values)
  anchor + log(sum(rule$weight * exp(log_values - anchor)))
}

goal002r_q_unseen <- function(omega, log_m0) {
  omega <- .goal002r_scalar(omega, "omega", lower = 0, upper = 1)
  log_m0 <- .goal002r_scalar(
    log_m0,
    "log_m0",
    lower = -Inf,
    allow_negative_infinity = TRUE
  )
  if (omega == 0 || !is.finite(log_m0)) return(0)
  if (omega == 1) return(1)
  log_member <- log(omega) + log_m0
  log_nonmember <- log1p(-omega)
  anchor <- max(log_member, log_nonmember)
  as.numeric(exp(log_member - anchor) /
    (exp(log_member - anchor) + exp(log_nonmember - anchor)))
}

goal002r_conditional_richness_pmf <- function(
  q_unseen,
  observed_richness,
  candidate_pool_size
) {
  q_unseen <- .goal002r_scalar(q_unseen, "q_unseen", lower = 0, upper = 1)
  observed_richness <- .goal002r_scalar(
    observed_richness, "observed_richness", lower = 0
  )
  candidate_pool_size <- .goal002r_scalar(
    candidate_pool_size, "candidate_pool_size", lower = observed_richness
  )
  if (any(c(observed_richness, candidate_pool_size) !=
      trunc(c(observed_richness, candidate_pool_size)))) {
    .goal002r_stop("Richness dimensions must be whole numbers.")
  }
  observed_richness <- as.integer(observed_richness)
  candidate_pool_size <- as.integer(candidate_pool_size)
  unseen <- candidate_pool_size - observed_richness
  tibble::tibble(
    richness = seq.int(observed_richness, candidate_pool_size),
    probability = stats::dbinom(
      seq.int(0L, unseen),
      size = unseen,
      prob = q_unseen
    )
  )
}

goal002r_richness_pmf <- function(
  q_unseen,
  observed_richness,
  candidate_pool_size
) {
  if (!is.numeric(q_unseen) || length(q_unseen) == 0L ||
      anyNA(q_unseen) || any(!is.finite(q_unseen)) ||
      any(q_unseen < 0 | q_unseen > 1)) {
    .goal002r_stop("q_unseen must contain finite probabilities in [0, 1].")
  }
  conditional <- lapply(
    q_unseen,
    goal002r_conditional_richness_pmf,
    observed_richness = observed_richness,
    candidate_pool_size = candidate_pool_size
  )
  probability <- rowMeans(do.call(
    cbind,
    lapply(conditional, `[[`, "probability")
  ))
  probability <- probability / sum(probability)
  tibble::tibble(
    richness = conditional[[1L]]$richness,
    probability = as.numeric(probability)
  )
}

goal002r_richness_summary <- function(pmf) {
  if (!tibble::is_tibble(pmf) ||
      !identical(names(pmf), c("richness", "probability")) ||
      nrow(pmf) == 0L || anyNA(pmf$probability) ||
      any(pmf$probability < 0) || abs(sum(pmf$probability) - 1) > 1e-12) {
    .goal002r_stop("pmf must be a normalised richness PMF.")
  }
  cdf <- cumsum(pmf$probability)
  quantile_at <- function(probability) pmf$richness[which(cdf >= probability)[1L]]
  list(
    mean = sum(pmf$richness * pmf$probability),
    median = as.integer(quantile_at(0.5)),
    mode = as.integer(pmf$richness[which.max(pmf$probability)]),
    interval_90 = as.integer(c(quantile_at(0.05), quantile_at(0.95)))
  )
}
