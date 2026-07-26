.stop_invalid_infer_scores <- function(message) {
  stop(message, call. = FALSE)
}

.validate_richness_scalar <- function(x, name, upper = NULL) {
  valid <- is.numeric(x) &&
    !is.complex(x) &&
    !is.logical(x) &&
    length(x) == 1L &&
    !is.na(x) &&
    is.finite(x) &&
    x == trunc(x) &&
    x >= 0 &&
    x <= (.Machine$integer.max - 1)

  if (!valid) {
    .stop_invalid_infer_scores(paste0(
      name,
      " must be one finite, non-negative whole number representable ",
      "on the integer richness support."
    ))
  }
  if (!is.null(upper) && x > upper) {
    .stop_invalid_infer_scores(paste0(
      name,
      " must not exceed candidate_pool_size."
    ))
  }

  as.integer(x)
}

.validate_positive_shape <- function(x, name) {
  valid <- is.numeric(x) &&
    !is.complex(x) &&
    !is.logical(x) &&
    length(x) == 1L &&
    !is.na(x) &&
    is.finite(x) &&
    x > 0

  if (!valid) {
    .stop_invalid_infer_scores(paste0(
      name,
      " must be one positive finite numeric value."
    ))
  }

  as.numeric(x)
}

.log_positive_sum <- function(x, y) {
  larger <- max(x, y)
  smaller <- min(x, y)
  log(larger) + log1p(smaller / larger)
}

.score_log_sum_exp <- function(x) {
  anchor <- max(x)
  anchor + log(sum(exp(x - anchor)))
}

.validate_richness_pmf <- function(pmf) {
  valid_schema <- inherits(pmf, "tbl_df") &&
    identical(names(pmf), c("richness", "probability")) &&
    nrow(pmf) >= 1L
  if (!valid_schema) {
    .stop_invalid_infer_scores(paste0(
      "pmf must be a non-empty tibble with exactly the columns ",
      "richness and probability."
    ))
  }
  if (!is.integer(pmf$richness)) {
    .stop_invalid_infer_scores(
      "pmf richness must use integer storage."
    )
  }
  if (!is.double(pmf$probability)) {
    .stop_invalid_infer_scores(
      "pmf probability must use double storage."
    )
  }

  candidate_pool_size <- nrow(pmf) - 1L
  expected_support <- seq.int(0L, candidate_pool_size)
  if (!identical(pmf$richness, expected_support)) {
    .stop_invalid_infer_scores(
      "pmf richness support must be the ordered integers 0:C."
    )
  }
  if (anyNA(pmf$probability) ||
      any(!is.finite(pmf$probability)) ||
      any(pmf$probability < 0)) {
    .stop_invalid_infer_scores(
      "pmf probabilities must be finite and non-negative."
    )
  }

  probability_sum <- sum(pmf$probability)
  if (abs(probability_sum - 1) > 1e-12) {
    .stop_invalid_infer_scores(
      "pmf probabilities must sum to one."
    )
  }

  list(
    richness = pmf$richness,
    probability = pmf$probability,
    candidate_pool_size = candidate_pool_size
  )
}

.validate_interval_levels <- function(levels) {
  valid <- is.numeric(levels) &&
    !is.complex(levels) &&
    !is.logical(levels) &&
    length(levels) >= 1L &&
    !anyNA(levels) &&
    all(is.finite(levels)) &&
    all(levels > 0) &&
    all(levels < 1)
  if (!valid) {
    .stop_invalid_infer_scores(
      "levels must contain finite numeric values strictly between 0 and 1."
    )
  }
  if (anyDuplicated(levels)) {
    .stop_invalid_infer_scores(
      "levels must not contain duplicate values."
    )
  }

  labels <- trimws(formatC(
    100 * unname(levels),
    format = "fg",
    digits = 15
  ))
  if (anyDuplicated(labels)) {
    .stop_invalid_infer_scores(
      "levels must produce unique interval names."
    )
  }

  list(values = as.numeric(levels), labels = labels)
}

lower_bound_prior_pmf <- function(
  candidate_pool_size,
  observed_richness,
  omega_alpha,
  omega_beta
) {
  candidate_pool_size <- .validate_richness_scalar(
    candidate_pool_size,
    "candidate_pool_size"
  )
  observed_richness <- .validate_richness_scalar(
    observed_richness,
    "observed_richness",
    upper = candidate_pool_size
  )
  omega_alpha <- .validate_positive_shape(
    omega_alpha,
    "omega_alpha"
  )
  omega_beta <- .validate_positive_shape(
    omega_beta,
    "omega_beta"
  )

  unseen_capacity <- candidate_pool_size - observed_richness
  unseen <- seq.int(0L, unseen_capacity)
  log_probability <- numeric(unseen_capacity + 1L)

  # Adjacent beta-binomial probabilities are built as log ratios. This
  # avoids subtracting nearly equal lbeta() values for concentrated priors.
  if (unseen_capacity > 0L) {
    for (u in seq.int(0L, unseen_capacity - 1L)) {
      log_probability[u + 2L] <- log_probability[u + 1L] +
        log(unseen_capacity - u) -
        log(u + 1L) +
        .log_positive_sum(
          omega_alpha,
          as.numeric(observed_richness) + u
        ) -
        .log_positive_sum(
          omega_beta,
          as.numeric(unseen_capacity) - u - 1
        )
    }
  }

  probability <- exp(
    log_probability - .score_log_sum_exp(log_probability)
  )
  probability <- probability / sum(probability)
  full_probability <- numeric(candidate_pool_size + 1L)
  support_index <- observed_richness + unseen + 1L
  full_probability[support_index] <- probability

  tibble::tibble(
    richness = seq.int(0L, candidate_pool_size),
    probability = full_probability
  )
}

discrete_richness_summary <- function(
  pmf,
  levels = c(0.8, 0.9, 0.95)
) {
  validated <- .validate_richness_pmf(pmf)
  interval_levels <- .validate_interval_levels(levels)
  cdf <- cumsum(validated$probability)
  cdf[length(cdf)] <- 1

  quantile_at <- function(probability) {
    validated$richness[which(cdf >= probability)[1L]]
  }
  intervals <- lapply(interval_levels$values, function(level) {
    tail_probability <- (1 - level) / 2
    stats::setNames(
      as.integer(c(
        quantile_at(tail_probability),
        quantile_at(1 - tail_probability)
      )),
      c("lower", "upper")
    )
  })
  names(intervals) <- interval_levels$labels

  list(
    mean = sum(validated$richness * validated$probability),
    median = as.integer(quantile_at(0.5)),
    mode = as.integer(
      validated$richness[which.max(validated$probability)]
    ),
    intervals = intervals
  )
}

ranked_probability_score <- function(pmf, truth) {
  validated <- .validate_richness_pmf(pmf)
  truth <- .validate_richness_scalar(
    truth,
    "truth",
    upper = validated$candidate_pool_size
  )
  candidate_pool_size <- validated$candidate_pool_size
  if (candidate_pool_size == 0L) {
    return(0)
  }

  cdf <- cumsum(validated$probability)[
    seq_len(candidate_pool_size)
  ]
  thresholds <- seq.int(0L, candidate_pool_size - 1L)
  observed_cdf <- as.numeric(truth <= thresholds)
  sum((cdf - observed_cdf)^2)
}
