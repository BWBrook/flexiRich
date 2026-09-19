# Goal011 fixed-origin posterior-mixture forecasts.

.goal011_stop <- function(message) {
  stop(message, call. = FALSE)
}

.goal011_logaddexp <- function(a, b) {
  out <- pmax(a, b)
  finite <- is.finite(out)
  if (any(finite)) {
    out[finite] <- out[finite] + log1p(exp(-abs(a[finite] - b[finite])))
  }
  nonfinite <- !is.finite(out)
  take_a <- nonfinite & is.finite(a)
  take_b <- nonfinite & !is.finite(a) & is.finite(b)
  out[take_a] <- a[take_a]
  out[take_b] <- b[take_b]
  out
}

.goal011_logmeanexp <- function(x) {
  x <- as.numeric(x)
  if (!any(is.finite(x))) return(-Inf)
  m <- max(x[is.finite(x)])
  m + log(sum(exp(x - m))) - log(length(x))
}

.goal011_logsumexp <- function(x) {
  x <- as.numeric(x)
  if (!any(is.finite(x))) return(-Inf)
  m <- max(x[is.finite(x)])
  m + log(sum(exp(x - m)))
}

.goal011_log_detection <- function(log_hazard) {
  result <- rep(-Inf, length(log_hazard))
  tiny <- log_hazard < log(.Machine$double.xmin)
  result[tiny] <- log_hazard[tiny]
  regular <- !tiny & is.finite(log_hazard)
  if (any(regular)) {
    result[regular] <- log(-expm1(-exp(log_hazard[regular])))
  }
  result[is.infinite(log_hazard) & log_hazard > 0] <- 0
  result
}

.goal011_log_nondetection <- function(log_hazard) {
  if (any(log_hazard > log(.Machine$double.xmax))) {
    .goal011_stop("Cumulative hazard exceeds the representable log-score range.")
  }
  result <- rep(0, length(log_hazard))
  finite <- is.finite(log_hazard)
  if (any(finite)) {
    result[finite] <- -exp(log_hazard[finite])
  }
  result
}

.goal011_validate_draws <- function(draws, detected_ever, labels) {
  required <- c(
    "q_member", "alpha", "camera_effect", "candidate_ids", "camera_ids"
  )
  if (!is.list(draws) || !all(required %in% names(draws))) {
    .goal011_stop("draws must contain the Goal009/010 prediction-draw fields.")
  }
  q <- draws$q_member
  alpha <- draws$alpha
  camera <- draws$camera_effect
  if (!is.matrix(q) || !is.numeric(q) || is.logical(q) || nrow(q) < 1L ||
      anyNA(q) || any(!is.finite(q)) || any(q < 0 | q > 1)) {
    .goal011_stop("q_member must be a finite D by C matrix in [0, 1].")
  }
  D <- nrow(q)
  C <- ncol(q)
  J <- length(draws$camera_ids)
  if (C < 1L || J < 1L || !is.character(draws$candidate_ids) ||
      length(draws$candidate_ids) != C || anyNA(draws$candidate_ids) ||
      anyDuplicated(draws$candidate_ids) || !is.character(draws$camera_ids) ||
      anyNA(draws$camera_ids) || anyDuplicated(draws$camera_ids)) {
    .goal011_stop("draws have invalid candidate or camera identifiers.")
  }
  if (!is.matrix(alpha) || !is.numeric(alpha) || is.logical(alpha) ||
      !identical(dim(alpha), c(D, C)) || anyNA(alpha) ||
      any(!is.finite(alpha)) || !is.matrix(camera) || !is.numeric(camera) ||
      is.logical(camera) || !identical(dim(camera), c(D, J)) ||
      anyNA(camera) || any(!is.finite(camera))) {
    .goal011_stop("alpha and camera_effect have invalid dimensions or values.")
  }
  interaction <- if ("interaction" %in% names(draws)) draws$interaction else NULL
  if (!is.null(interaction) &&
      (!is.array(interaction) || !is.numeric(interaction) ||
       length(dim(interaction)) != 3L ||
       !identical(dim(interaction), c(D, C, J)) || anyNA(interaction) ||
       any(!is.finite(interaction)))) {
    .goal011_stop("interaction must be NULL or a finite D by C by J array.")
  }
  if (!is.numeric(detected_ever) || is.logical(detected_ever) ||
      length(detected_ever) != C || anyNA(detected_ever) ||
      any(detected_ever != as.integer(detected_ever)) ||
      any(!detected_ever %in% c(0, 1))) {
    .goal011_stop("detected_ever must be a 0/1 vector with one value per candidate.")
  }
  detected_ever <- as.integer(detected_ever)
  known <- detected_ever == 1L
  if (any(known) && any(q[, known, drop = FALSE] != 1)) {
    .goal011_stop("q_member must equal one for every known candidate and draw.")
  }
  if (!is.data.frame(labels) ||
      !identical(names(labels), c("species_id", "taxon_class", "encounter_class")) ||
      nrow(labels) != C || !is.character(labels$species_id) ||
      anyNA(labels$species_id) || anyDuplicated(labels$species_id) ||
      !setequal(labels$species_id, draws$candidate_ids) ||
      !is.character(labels$taxon_class) || !is.character(labels$encounter_class) ||
      anyNA(labels$taxon_class) || anyNA(labels$encounter_class)) {
    .goal011_stop("labels must identify every candidate with two non-missing classes.")
  }
  list(
    q = matrix(as.numeric(q), nrow = D, ncol = C),
    alpha = matrix(as.numeric(alpha), nrow = D, ncol = C),
    camera = matrix(as.numeric(camera), nrow = D, ncol = J),
    interaction = if (is.null(interaction)) NULL else array(
      as.numeric(interaction), dim = c(D, C, J)
    ), candidate_ids = draws$candidate_ids, camera_ids = draws$camera_ids,
    detected_ever = detected_ever, labels = labels[
      match(draws$candidate_ids, labels$species_id), , drop = FALSE
    ], D = D, C = C, J = J
  )
}

.goal011_validate_effort <- function(future_effort, camera_ids, horizons) {
  if (!is.data.frame(future_effort) ||
      !identical(names(future_effort), c("camera_id", "future_week", "active_days")) ||
      !is.character(future_effort$camera_id) ||
      !is.numeric(future_effort$future_week) ||
      !is.numeric(future_effort$active_days) || is.logical(future_effort$active_days) ||
      anyNA(future_effort$camera_id) || anyNA(future_effort$future_week) ||
      anyNA(future_effort$active_days) ||
      any(!is.finite(future_effort$future_week)) ||
      any(!is.finite(future_effort$active_days)) ||
      any(future_effort$future_week != trunc(future_effort$future_week)) ||
      any(future_effort$future_week < 1 | future_effort$future_week > 101) ||
      any(future_effort$active_days != trunc(future_effort$active_days)) ||
      any(future_effort$active_days < 0 | future_effort$active_days > 7) ||
      !setequal(unique(future_effort$camera_id), camera_ids)) {
    .goal011_stop("future_effort has an invalid weekly camera-effort contract.")
  }
  T <- max(future_effort$future_week)
  if (nrow(future_effort) != length(camera_ids) * T ||
      anyDuplicated(future_effort[c("camera_id", "future_week")]) ||
      !all(as.integer(sort(unique(future_effort$future_week))) == seq_len(T)) ||
      any(!camera_ids %in% future_effort$camera_id) ||
      any(horizons > T)) {
    .goal011_stop("future_effort must be the complete camera by week grid through every horizon.")
  }
  active <- matrix(0, nrow = length(camera_ids), ncol = T,
                   dimnames = list(camera_ids, as.character(seq_len(T))))
  active[cbind(match(future_effort$camera_id, camera_ids),
               as.integer(future_effort$future_week))] <-
    as.numeric(future_effort$active_days)
  active
}

.goal011_log_hazard <- function(eta, active_days) {
  D <- dim(eta)[1L]
  C <- dim(eta)[2L]
  J <- dim(eta)[3L]
  log_effort <- ifelse(active_days > 0, log(active_days), -Inf)
  terms <- matrix(-Inf, nrow = D * C, ncol = J)
  for (j in seq_len(J)) {
    if (active_days[[j]] > 0) {
      terms[, j] <- as.vector(eta[, , j]) + log_effort[j]
    }
  }
  maximum <- apply(terms, 1L, max)
  result <- rep(-Inf, D * C)
  result[is.infinite(maximum) & maximum > 0] <- Inf
  finite <- is.finite(maximum)
  if (any(finite)) {
    shifted <- exp(terms[finite, , drop = FALSE] - maximum[finite])
    shifted[!is.finite(shifted)] <- 0
    result[finite] <- maximum[finite] + log(rowSums(shifted))
  }
  matrix(result, nrow = D, ncol = C)
}

# Log-space Poisson-binomial recurrence.  Rows are posterior draws and
# columns are the possible counts 0,...,K.
.goal011_log_poisson_binomial <- function(log_probability, log_complement) {
  D <- nrow(log_probability)
  K <- ncol(log_probability)
  pmf <- matrix(-Inf, nrow = D, ncol = 1L)
  pmf[, 1L] <- 0
  if (K == 0L) return(pmf)
  for (k in seq_len(K)) {
    old <- pmf
    next_pmf <- matrix(-Inf, nrow = D, ncol = k + 1L)
    next_pmf[, 1L] <- old[, 1L] + log_complement[, k]
    if (k > 1L) {
      for (s in seq_len(k - 1L)) {
        next_pmf[, s + 1L] <- .goal011_logaddexp(
          old[, s] + log_probability[, k],
          old[, s + 1L] + log_complement[, k]
        )
      }
    }
    next_pmf[, k + 1L] <- old[, k] + log_probability[, k]
    pmf <- next_pmf
  }
  pmf
}

.goal011_count_rows <- function(target, group, horizon, log_probability,
                                log_complement) {
  if (length(dim(log_probability)) == 3L) {
    log_probability <- matrix(
      as.numeric(log_probability), nrow = dim(log_probability)[1L],
      ncol = dim(log_probability)[2L]
    )
    log_complement <- matrix(
      as.numeric(log_complement), nrow = dim(log_complement)[1L],
      ncol = dim(log_complement)[2L]
    )
  }
  row_pmf <- .goal011_log_poisson_binomial(log_probability, log_complement)
  log_probability_mean <- apply(row_pmf, 2L, .goal011_logmeanexp)
  data.frame(
    target = rep(target, length(log_probability_mean)),
    group = rep(group, length(log_probability_mean)),
    horizon = rep(as.integer(horizon), length(log_probability_mean)),
    count = seq.int(0L, length(log_probability_mean) - 1L),
    probability = exp(log_probability_mean),
    log_probability = log_probability_mean,
    stringsAsFactors = FALSE
  )
}

.goal011_hypergeom_split <- function(total_log_pmf, n_group, n_total) {
  result <- rep(-Inf, n_group + 1L)
  if (n_total == 0L) {
    result[[1L]] <- 0
    return(result)
  }
  for (x in 0:n_group) {
    terms <- vapply(seq_along(total_log_pmf) - 1L, function(k) {
      if (x > k || k - x > n_total - n_group) return(-Inf)
      total_log_pmf[k + 1L] + lchoose(n_group, x) +
        lchoose(n_total - n_group, k - x) - lchoose(n_total, k)
    }, numeric(1))
    result[x + 1L] <- .goal011_logsumexp(terms)
  }
  result
}

#' Fixed-origin Goal011 forecast from saved joint posterior prediction draws.
goal011_forecast <- function(
  draws, detected_ever, future_effort,
  horizons = c(13L, 26L, 52L, 101L), labels
) {
  if (!is.numeric(horizons) || is.logical(horizons) || length(horizons) < 1L ||
      anyNA(horizons) || any(!is.finite(horizons)) ||
      any(horizons != trunc(horizons)) || any(horizons < 1) ||
      anyDuplicated(horizons) || !identical(as.integer(horizons), sort(as.integer(horizons)))) {
    .goal011_stop("horizons must be distinct positive integers in increasing order.")
  }
  horizons <- as.integer(horizons)
  validated <- .goal011_validate_draws(draws, detected_ever, labels)
  active <- .goal011_validate_effort(
    future_effort, validated$camera_ids, horizons
  )
  D <- validated$D
  C <- validated$C
  J <- validated$J
  Hn <- length(horizons)
  eta <- array(0, dim = c(D, C, J))
  for (j in seq_len(J)) {
    eta[, , j] <- validated$alpha + validated$camera[, j]
    if (!is.null(validated$interaction)) {
      eta[, , j] <- eta[, , j] + validated$interaction[, , j]
    }
  }
  cumulative_active <- matrix(0, nrow = J, ncol = ncol(active))
  for (j in seq_len(J)) cumulative_active[j, ] <- cumsum(active[j, ])
  log_detection <- array(-Inf, dim = c(D, C, Hn))
  log_nondetection <- array(0, dim = c(D, C, Hn))
  log_first_interval <- array(-Inf, dim = c(D, C, Hn))
  log_q <- ifelse(validated$q > 0, log(validated$q), -Inf)
  previous_effort <- numeric(J)
  for (h in seq_along(horizons)) {
    effort_h <- cumulative_active[, horizons[[h]]]
    log_hazard <- .goal011_log_hazard(eta, effort_h)
    interval_hazard <- .goal011_log_hazard(
      eta, effort_h - previous_effort
    )
    log_conditional_detection <- .goal011_log_detection(as.vector(log_hazard))
    log_conditional_nondetection <- .goal011_log_nondetection(as.vector(log_hazard))
    log_one_minus_q <- ifelse(validated$q < 1, log1p(-validated$q), -Inf)
    log_detection[, , h] <- matrix(
      log_q + matrix(log_conditional_detection, nrow = D, ncol = C),
      nrow = D, ncol = C
    )
    log_nondetection[, , h] <- matrix(.goal011_logaddexp(
      as.vector(log_one_minus_q),
      as.vector(log_q) + log_conditional_nondetection
    ), nrow = D, ncol = C)
    log_survival_previous <- if (h == 1L) {
      rep(0, D * C)
    } else {
      .goal011_log_nondetection(as.vector(
        .goal011_log_hazard(eta, previous_effort)
      ))
    }
    log_first_interval[, , h] <- matrix(
      log_q + log_survival_previous +
        .goal011_log_detection(as.vector(interval_hazard)),
      nrow = D, ncol = C
    )
    previous_effort <- effort_h
  }
  known <- validated$detected_ever == 1L
  unseen <- !known
  species_rows <- vector("list", C * Hn)
  row <- 0L
  cumulative_unseen_log <- if (any(unseen)) vapply(seq_len(Hn), function(h) {
    .goal011_logmeanexp(log_detection[, unseen, h, drop = FALSE])
  }, numeric(1)) else rep(-Inf, Hn)
  cumulative_unseen_none_log <- if (any(unseen)) vapply(seq_len(Hn), function(h) {
    .goal011_logmeanexp(log_nondetection[, unseen, h, drop = FALSE])
  }, numeric(1)) else rep(0, Hn)
  for (i in seq_len(C)) {
    for (h in seq_len(Hn)) {
      row <- row + 1L
      detection_log <- if (known[i]) {
        .goal011_logmeanexp(log_detection[, i, h])
      } else {
        cumulative_unseen_log[[h]]
      }
      nondetection_log <- if (known[i]) {
        .goal011_logmeanexp(log_nondetection[, i, h])
      } else {
        cumulative_unseen_none_log[[h]]
      }
      discovery_log <- if (known[i]) -Inf else detection_log
      first_log <- if (known[i]) -Inf else {
        .goal011_logmeanexp(log_first_interval[, unseen, h, drop = FALSE])
      }
      species_rows[[row]] <- data.frame(
        species_id = validated$candidate_ids[[i]],
        known_member = as.integer(known[[i]]),
        horizon = horizons[[h]],
        detection_probability = exp(detection_log),
        discovery_probability = exp(discovery_log),
        first_discovery_bin_probability = exp(first_log),
        log_detection_probability = detection_log,
        log_nondetection_probability = nondetection_log,
        log_discovery_probability = discovery_log,
        log_first_discovery_bin_probability = first_log,
        stringsAsFactors = FALSE
      )
    }
  }
  species_probabilities <- do.call(rbind, species_rows)

  count_rows <- list()
  n_rows <- 0L
  append_count <- function(target, group, h, mask) {
    n_rows <<- n_rows + 1L
    count_rows[[n_rows]] <<- .goal011_count_rows(
      target, group, horizons[[h]], log_detection[, mask, h, drop = FALSE],
      log_nondetection[, mask, h, drop = FALSE]
    )
  }
  for (h in seq_len(Hn)) {
    append_count("totaldiscovery", "all", h, unseen)
    append_count("redetection", "all", h, known)
    append_count("all_detection", "all", h, rep(TRUE, C))
  }
  # All-zero candidates are exchangeable in the named summaries.  Split the
  # exact heterogeneous total-discovery mixture by fixed label counts.
  total_log_pmfs <- lapply(seq_len(Hn), function(h) {
    lp <- log_detection[, unseen, h, drop = FALSE]
    ln <- log_nondetection[, unseen, h, drop = FALSE]
    lp <- matrix(as.numeric(lp), nrow = D, ncol = sum(unseen))
    ln <- matrix(as.numeric(ln), nrow = D, ncol = sum(unseen))
    row_pmf <- .goal011_log_poisson_binomial(
      lp, ln
    )
    apply(row_pmf, 2L, .goal011_logmeanexp)
  })
  for (class_name in c("taxon_class", "encounter_class")) {
    groups <- sort(unique(validated$labels[[class_name]][unseen]), method = "radix")
    for (group in groups) {
      n_group <- sum(unseen & validated$labels[[class_name]] == group)
      for (h in seq_len(Hn)) {
        split_log <- .goal011_hypergeom_split(
          total_log_pmfs[[h]], n_group, sum(unseen)
        )
        count_rows[[length(count_rows) + 1L]] <- data.frame(
          target = rep(paste0("discovery_", class_name), length(split_log)),
          group = rep(group, length(split_log)),
          horizon = rep(horizons[[h]], length(split_log)),
          count = seq.int(0L, length(split_log) - 1L),
          probability = exp(split_log),
          log_probability = split_log,
          stringsAsFactors = FALSE
        )
      }
    }
  }
  count_pmfs <- do.call(rbind, count_rows)
  rownames(species_probabilities) <- NULL
  rownames(count_pmfs) <- NULL
  list(
    species_probabilities = species_probabilities,
    count_pmfs = count_pmfs,
    per_draw = list(
      log_detection = log_detection,
      log_nondetection = log_nondetection
    ),
    metadata = list(
      candidate_ids = validated$candidate_ids,
      camera_ids = validated$camera_ids,
      labels = validated$labels,
      horizons = horizons,
      draw_count = D,
      fixed_origin_weeks = 52L,
      forecast_weeks = max(as.integer(future_effort$future_week)),
      known_count = sum(known),
      unseen_count = sum(unseen),
      interaction_included = !is.null(validated$interaction),
      effort = active
    )
  )
}
