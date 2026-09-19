# Goal011 fixed-origin forecast scoring.

.goal011_score_stop <- function(message) stop(message, call. = FALSE)

.goal011_score_logsumexp <- function(x) {
  x <- as.numeric(x)
  if (!length(x) || !any(is.finite(x))) return(-Inf)
  finite <- is.finite(x)
  m <- max(x[finite])
  m + log(sum(exp(x[finite] - m)))
}

.goal011_score_validate <- function(forecast) {
  required <- c("species_probabilities", "count_pmfs", "metadata")
  if (!is.list(forecast) || !all(required %in% names(forecast))) {
    .goal011_score_stop("forecast is missing its frozen scoring objects.")
  }
  species <- forecast$species_probabilities
  species_required <- c(
    "species_id", "known_member", "horizon", "log_detection_probability",
    "log_nondetection_probability"
  )
  if (!is.data.frame(species) || !all(species_required %in% names(species)) ||
      !is.character(species$species_id) || anyNA(species$species_id) ||
      anyDuplicated(species[c("species_id", "horizon")]) ||
      !(is.numeric(species$known_member) || is.logical(species$known_member)) ||
      anyNA(species$known_member) || any(!species$known_member %in% c(0, 1)) ||
      !is.numeric(species$horizon) || is.logical(species$horizon) ||
      anyNA(species$horizon) || any(!is.finite(species$horizon)) ||
      any(species$horizon != trunc(species$horizon)) ||
      !is.numeric(species$log_detection_probability) ||
      !is.numeric(species$log_nondetection_probability) ||
      anyNA(species$log_detection_probability) ||
      anyNA(species$log_nondetection_probability) ||
      any(species$log_detection_probability > 0) ||
      any(species$log_nondetection_probability > 0)) {
    .goal011_score_stop("forecast species probabilities have an invalid schema.")
  }
  event_mass <- vapply(seq_len(nrow(species)),function(i)
    .goal011_score_logsumexp(c(species$log_detection_probability[i],
                              species$log_nondetection_probability[i])),numeric(1))
  if(any(!is.finite(event_mass)) || any(abs(event_mass)>1e-8))
    .goal011_score_stop("saved species event probabilities must be normalized.")
  metadata <- forecast$metadata
  if (!is.list(metadata) || !is.character(metadata$candidate_ids) ||
      anyNA(metadata$candidate_ids) || anyDuplicated(metadata$candidate_ids) ||
      !is.numeric(metadata$horizons) || is.logical(metadata$horizons) ||
      anyNA(metadata$horizons) || any(metadata$horizons != trunc(metadata$horizons)) ||
      any(metadata$horizons < 1L) || anyDuplicated(metadata$horizons) ||
      !is.data.frame(metadata$labels) ||
      !identical(names(metadata$labels), c("species_id", "taxon_class", "encounter_class")) ||
      !is.character(metadata$labels$species_id) ||
      !is.character(metadata$labels$taxon_class) ||
      !is.character(metadata$labels$encounter_class) ||
      anyNA(metadata$labels) || anyDuplicated(metadata$labels$species_id) ||
      !setequal(metadata$labels$species_id, metadata$candidate_ids)) {
    .goal011_score_stop("forecast metadata does not contain frozen candidate labels.")
  }
  ids <- metadata$candidate_ids
  horizons <- as.integer(metadata$horizons)
  species$horizon <- as.integer(species$horizon)
  species$known_member <- as.integer(species$known_member)
  expected <- expand.grid(
    species_id = ids, horizon = horizons,
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  key <- function(x) paste(x$species_id, x$horizon, sep = "\r")
  if (nrow(species) != nrow(expected) || !setequal(key(species), key(expected))) {
    .goal011_score_stop("forecast species probabilities have an invalid candidate-horizon set.")
  }
  known_rows <- split(species$known_member, species$species_id)
  if (any(vapply(known_rows, function(x) length(unique(x)) != 1L, logical(1)))) {
    .goal011_score_stop("known membership must be fixed for each species.")
  }
  counts <- forecast$count_pmfs
  count_required <- c("target", "group", "horizon", "count", "log_probability")
  if (!is.data.frame(counts) || !all(count_required %in% names(counts)) ||
      !is.character(counts$target) || !is.character(counts$group) ||
      !is.numeric(counts$horizon) || !is.numeric(counts$count) ||
      !is.numeric(counts$log_probability) || anyNA(counts$target) ||
      anyNA(counts$group) || anyNA(counts$horizon) || anyNA(counts$count) ||
      anyNA(counts$log_probability) || any(is.nan(counts$log_probability)) ||
      any(!is.finite(counts$horizon)) || any(counts$horizon != trunc(counts$horizon)) ||
      any(!is.finite(counts$count)) || any(counts$count != trunc(counts$count)) ||
      anyDuplicated(counts[c("target", "group", "horizon", "count")]) ||
      any(!counts$horizon %in% horizons) || any(counts$count < 0) ||
      any(counts$log_probability > 0)) {
    .goal011_score_stop("forecast count PMFs have an invalid schema.")
  }
  list(
    species = species, counts = counts, ids = ids, horizons = horizons,
    labels = metadata$labels[match(ids, metadata$labels$species_id), , drop = FALSE],
    known = vapply(ids, function(id) unique(known_rows[[id]])[[1L]] == 1L, logical(1))
  )
}

.goal011_score_validate_outcomes <- function(outcomes, ids, horizons) {
  if (!is.data.frame(outcomes) ||
      !all(c("species_id", "horizon", "detected") %in% names(outcomes)) ||
      !is.character(outcomes$species_id) || anyNA(outcomes$species_id) ||
      !is.numeric(outcomes$horizon) || is.logical(outcomes$horizon) ||
      anyNA(outcomes$horizon) || any(!is.finite(outcomes$horizon)) ||
      any(outcomes$horizon != trunc(outcomes$horizon)) ||
      !is.numeric(outcomes$detected) || is.logical(outcomes$detected) ||
      anyNA(outcomes$detected) || any(!outcomes$detected %in% c(0, 1))) {
    .goal011_score_stop("outcomes must have non-missing binary species-horizon rows.")
  }
  if (any(!outcomes$species_id %in% ids)) {
    .goal011_score_stop("outcomes contain species IDs absent from the forecast.")
  }
  if (any(!outcomes$horizon %in% horizons)) {
    .goal011_score_stop("outcomes contain horizons absent from the forecast.")
  }
  outcomes$horizon <- as.integer(outcomes$horizon)
  outcomes$detected <- as.integer(outcomes$detected)
  expected <- expand.grid(
    species_id = ids, horizon = horizons,
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  key <- function(x) paste(x$species_id, x$horizon, sep = "\r")
  observed_key <- key(outcomes)
  if (anyDuplicated(observed_key)) {
    .goal011_score_stop("outcomes contain duplicate species-horizon rows.")
  }
  if (length(observed_key) != nrow(expected) ||
      !setequal(observed_key, key(expected))) {
    .goal011_score_stop("outcomes must contain the exact forecast candidate-horizon set.")
  }
  outcomes <- outcomes[match(key(expected), observed_key), , drop = FALSE]
  for (id in ids) {
    values <- outcomes$detected[outcomes$species_id == id]
    if (any(diff(values) < 0)) {
      .goal011_score_stop("outcomes must be nested nondecreasing detections by species.")
    }
  }
  outcomes
}

.goal011_score_target_kind <- function(target) {
  x <- tolower(gsub("[^a-z0-9]", "", target))
  if (x %in% c("totaldiscovery", "discovery", "additionaldiscovery")) return("discovery")
  if (x %in% c("redetection", "totalredetection")) return("redetection")
  if (x %in% c("alldetection", "totaldetection", "totalfuturedetection")) return("all")
  if (grepl("discovery.*taxon|taxon.*discovery", x)) return("taxon_class")
  if (grepl("discovery.*encounter|encounter.*discovery", x)) return("encounter_class")
  NA_character_
}

.goal011_score_count_summary <- function(pmf, observed_count) {
  pmf <- pmf[order(pmf$count), , drop = FALSE]
  if (!all(pmf$count == seq.int(0L, nrow(pmf) - 1L))) {
    .goal011_score_stop("saved count PMFs must contain consecutive counts from zero.")
  }
  if (observed_count < 0L || observed_count >= nrow(pmf)) {
    .goal011_score_stop("observed count lies outside the saved count PMF.")
  }
  normalizer <- .goal011_score_logsumexp(pmf$log_probability)
  if (!is.finite(normalizer) || abs(normalizer) > 1e-8) {
    .goal011_score_stop("saved count PMF must be normalized in log space.")
  }
  probabilities <- exp(pmf$log_probability - normalizer)
  cumulative <- cumsum(probabilities)
  lower <- which(cumulative >= 0.05)[[1L]] - 1L
  median <- which(cumulative >= 0.5)[[1L]] - 1L
  upper <- which(cumulative >= 0.95)[[1L]] - 1L
  data.frame(
    observed_count = as.integer(observed_count),
    negative_log_score = -pmf$log_probability[observed_count + 1L],
    pmf_median = as.integer(median),
    central90_lower = as.integer(lower),
    central90_upper = as.integer(upper),
    containment_descriptive = observed_count >= lower && observed_count <= upper,
    stringsAsFactors = FALSE
  )
}

#' Score a frozen Goal011 forecast against supplied future outcomes.
#'
#' This function is data-only. It does not read observations or files and does
#' not refit a model.
goal011_score_forecast <- function(forecast, outcomes) {
  validated <- .goal011_score_validate(forecast)
  outcomes <- .goal011_score_validate_outcomes(
    outcomes, validated$ids, validated$horizons
  )
  species <- validated$species
  species_rows <- vector("list", nrow(species))
  for (r in seq_len(nrow(species))) {
    id <- species$species_id[[r]]
    h <- species$horizon[[r]]
    observed <- outcomes$detected[outcomes$species_id == id & outcomes$horizon == h]
    log_detection <- species$log_detection_probability[[r]]
    log_nondetection <- species$log_nondetection_probability[[r]]
    log_score <- if (observed == 1L) log_detection else log_nondetection
    known <- validated$known[match(id, validated$ids)]
    species_rows[[r]] <- data.frame(
      species_id = id,
      known_member = as.integer(known),
      event_type = if (known) "redetection" else "discovery",
      horizon = h,
      observed_future_detection = observed,
      observed_event = observed,
      predicted_probability = exp(log_detection),
      log_predictive_probability = log_detection,
      brier_score = (exp(log_detection) - observed)^2,
      negative_log_score = -log_score,
      log_nondetection_probability = log_nondetection,
      stringsAsFactors = FALSE
    )
  }
  species_scores <- do.call(rbind, species_rows)
  species_group <- ifelse(validated$known, "known_redetection", "unseen_discovery")
  aggregate_species_scores <- do.call(rbind, lapply(
    c("unseen_discovery", "known_redetection", "all"),
    function(group) {
      keep <- if (group == "all") rep(TRUE, nrow(species_scores)) else
        species_group[match(species_scores$species_id, validated$ids)] == group
      hs <- sort(unique(species_scores$horizon[keep]), method = "radix")
      do.call(rbind, lapply(hs, function(h) {
        rows <- species_scores[keep & species_scores$horizon == h, , drop = FALSE]
        data.frame(
          group = group, horizon = h, n_species = as.integer(nrow(rows)),
          mean_brier_score = mean(rows$brier_score),
          mean_negative_log_score = mean(rows$negative_log_score),
          stringsAsFactors = FALSE
        )
      }))
    }
  ))
  count_keys <- unique(validated$counts[c("target", "group", "horizon")])
  count_scores <- do.call(rbind, lapply(seq_len(nrow(count_keys)), function(k) {
    target <- count_keys$target[[k]]
    group <- count_keys$group[[k]]
    h <- count_keys$horizon[[k]]
    kind <- .goal011_score_target_kind(target)
    if (is.na(kind)) .goal011_score_stop(paste0("unsupported count PMF target: ", target))
    ids_at_h <- outcomes$species_id[outcomes$horizon == h]
    detected_at_h <- outcomes$detected[outcomes$horizon == h]
    known_at_h <- validated$known[match(ids_at_h, validated$ids)]
    if (kind == "discovery") {
      observed_count <- sum(detected_at_h[!known_at_h])
    } else if (kind == "redetection") {
      observed_count <- sum(detected_at_h[known_at_h])
    } else if (kind == "all") {
      observed_count <- sum(detected_at_h)
    } else {
      label_values <- validated$labels[[kind]][match(ids_at_h, validated$ids)]
      observed_count <- sum(detected_at_h[!known_at_h & label_values == group])
    }
    pmf <- validated$counts[
      validated$counts$target == target & validated$counts$group == group &
        validated$counts$horizon == h, , drop = FALSE
    ]
    cbind(
      data.frame(target = target, group = group, horizon = as.integer(h),
                 stringsAsFactors = FALSE),
      .goal011_score_count_summary(pmf, observed_count)
    )
  }))
  rownames(species_scores) <- NULL
  rownames(aggregate_species_scores) <- NULL
  rownames(count_scores) <- NULL
  list(
    species_scores = species_scores,
    aggregate_species_scores = aggregate_species_scores,
    count_scores = count_scores
  )
}
