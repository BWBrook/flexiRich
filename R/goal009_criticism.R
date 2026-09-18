# Goal009 bounded posterior predictive criticism for the frozen Goal003 model.

.goal009_stop <- function(message) {
  stop(message, call. = FALSE)
}

.goal009_read_csv <- function(path) {
  if (!file.exists(path)) {
    .goal009_stop(paste0("Missing Goal009 development table: ", basename(path), "."))
  }
  tibble::as_tibble(utils::read.csv(
    path,
    stringsAsFactors = FALSE,
    check.names = FALSE,
    na.strings = c("", "NA")
  ))
}

.goal009_project_root <- function() {
  if (exists(".goal003_project_root", mode = "function", inherits = TRUE)) {
    return(.goal003_project_root())
  }
  path <- normalizePath(getwd(), mustWork = TRUE)
  repeat {
    if (dir.exists(file.path(path, "R")) &&
        file.exists(file.path(path, "renv.lock"))) {
      return(path)
    }
    parent <- dirname(path)
    if (identical(parent, path)) break
    path <- parent
  }
  .goal009_stop("Could not locate the flexiRich repository root.")
}

.goal009_exact_columns <- function(x, fields, name) {
  if (!is.data.frame(x) || !identical(names(x), fields)) {
    .goal009_stop(paste0(name, " has an invalid column contract."))
  }
  tibble::as_tibble(x)
}

.goal009_validate_development_calendar <- function(calendar) {
  calendar <- .goal009_exact_columns(
    calendar,
    c("occasion_id", "occasion_index", "start_date", "end_date"),
    "occasion_calendar"
  )
  expected_id <- sprintf("occ_%03d", seq_len(52L))
  if (!identical(calendar$occasion_id, expected_id) ||
      !identical(as.integer(calendar$occasion_index), seq_len(52L))) {
    .goal009_stop("Goal009 development calendar must be exactly occ_001 through occ_052.")
  }
  calendar$start_date <- as.Date(calendar$start_date)
  calendar$end_date <- as.Date(calendar$end_date)
  expected_start <- as.Date("2019-06-05") + 7L * seq_len(52L) - 7L
  expected_end <- as.Date("2019-06-11") + 7L * seq_len(52L) - 7L
  if (anyNA(calendar$start_date) || anyNA(calendar$end_date) ||
      !identical(calendar$start_date, expected_start) ||
      !identical(calendar$end_date, expected_end) ||
      any(calendar$end_date < calendar$start_date) ||
      any(as.integer(diff(calendar$start_date)) != 7L)) {
    .goal009_stop("Goal009 development calendar contains invalid weekly dates.")
  }
  calendar
}

#' Read the sealed first-year Goal008 development tables for Goal009 criticism.
#'
#' Only the three canonical weekly tables are passed to the inference-data
#' constructor.  The calendar is retained as a small descriptive table.
goal009_read_development <- function(
  input_dir = file.path("outputs", "goal008", "development-v1")
) {
  if (!is.character(input_dir) || length(input_dir) != 1L ||
      is.na(input_dir) || !nzchar(input_dir) || !dir.exists(input_dir)) {
    .goal009_stop("input_dir must name an existing Goal008 development directory.")
  }
  root <- .goal009_project_root()
  candidate_config <- .goal009_read_csv(file.path(
    root, "config", "goal003_candidate_pool.csv"
  ))
  included <- candidate_config |>
    dplyr::filter(primary_pool == "include") |>
    dplyr::transmute(
      species_id = scientific_name,
      taxon_class = taxon_class,
      encounter_class = camera_encounter_class
    )
  if (nrow(included) != 50L || anyDuplicated(included$species_id)) {
    .goal009_stop("The Goal003 primary candidate pool must contain 50 species.")
  }
  expected_species <- sort(included$species_id, method = "radix")
  effort <- .goal009_exact_columns(
    .goal009_read_csv(file.path(input_dir, "effort_weekly.csv")),
    c("camera_id", "occasion_id", "active_days"),
    "effort_weekly"
  )
  detections <- .goal009_exact_columns(
    .goal009_read_csv(file.path(input_dir, "detections_weekly.csv")),
    c("species_id", "camera_id", "occasion_id", "detected"),
    "detections_weekly"
  )
  candidate <- .goal009_exact_columns(
    .goal009_read_csv(file.path(input_dir, "candidate_pool.csv")),
    "species_id",
    "candidate_pool"
  )
  calendar <- .goal009_validate_development_calendar(.goal009_read_csv(
    file.path(input_dir, "occasion_calendar.csv")
  ))
  if (!identical(sort(candidate$species_id, method = "radix"), expected_species)) {
    .goal009_stop("Goal009 candidate_pool.csv is not exactly the primary 50-species pool.")
  }
  expected_occasions <- calendar$occasion_id
  template <- .goal009_read_csv(file.path(
    root, "config", "goal003_task4_effort_template.csv"
  ))
  expected_cameras <- sort(unique(template$camera_id), method = "radix")
  actual_cameras <- sort(unique(effort$camera_id), method = "radix")
  if (length(expected_cameras) != 9L || !identical(actual_cameras, expected_cameras) ||
      !identical(expected_occasions, sprintf("occ_%03d", seq_len(52L)))) {
    .goal009_stop("Goal009 development data must contain exactly 52 occasions and 9 cameras.")
  }
  # Canonical construction performs all key, type, grid, and effort/NA checks.
  data <- prepare_flexirich_g_data(
    candidate["species_id"], effort, detections
  )
  if (length(data$candidate_ids) != 50L || length(data$camera_ids) != 9L ||
      length(data$occasion_ids) != 52L ||
      !identical(data$occasion_ids, expected_occasions)) {
    .goal009_stop("Goal009 canonical data is not 50 x 9 x 52.")
  }
  labels <- included[match(data$candidate_ids, included$species_id), ]
  if (anyNA(labels$species_id) || !identical(labels$species_id, data$candidate_ids)) {
    .goal009_stop("Goal009 labels do not align with canonical candidate IDs.")
  }
  list(data = data, calendar = calendar, labels = labels)
}

.goal009_validate_draws <- function(
  data, q_member_draws, alpha_draws, camera_effect_draws, labels,
  seed, max_draws
) {
  validate_flexirich_g_data(data)
  C <- length(data$candidate_ids)
  J <- length(data$camera_ids)
  D <- if (is.matrix(q_member_draws)) nrow(q_member_draws) else 0L
  valid <- is.matrix(q_member_draws) && is.numeric(q_member_draws) &&
    nrow(q_member_draws) > 0L && ncol(q_member_draws) == C &&
    all(is.finite(q_member_draws)) && all(q_member_draws >= 0 & q_member_draws <= 1) &&
    is.matrix(alpha_draws) && is.numeric(alpha_draws) &&
    identical(dim(alpha_draws), c(D, C)) && all(is.finite(alpha_draws)) &&
    is.matrix(camera_effect_draws) && is.numeric(camera_effect_draws) &&
    identical(dim(camera_effect_draws), c(D, J)) && all(is.finite(camera_effect_draws)) &&
    all(abs(rowSums(camera_effect_draws)) <=
      1e-10 * (1 + rowSums(abs(camera_effect_draws)))) &&
    is.data.frame(labels) && identical(names(labels),
      c("species_id", "taxon_class", "encounter_class")) &&
    nrow(labels) == C && is.character(labels$species_id) &&
    !anyDuplicated(labels$species_id) &&
    setequal(labels$species_id, data$candidate_ids) &&
    is.character(labels$taxon_class) && is.character(labels$encounter_class) &&
    !anyNA(labels$taxon_class) && !anyNA(labels$encounter_class) &&
    is.numeric(seed) && !is.logical(seed) && length(seed) == 1L &&
    is.finite(seed) && !is.na(seed) && seed == trunc(seed) && seed >= 1 &&
    seed < .Machine$integer.max && is.numeric(max_draws) &&
    !is.logical(max_draws) && length(max_draws) == 1L && !is.na(max_draws) &&
    is.finite(max_draws) && max_draws == trunc(max_draws) && max_draws >= 1
  if (valid && any(q_member_draws[, data$stan_data$detected_ever == 1L, drop = FALSE] != 1)) {
    valid <- FALSE
  }
  if (!valid) .goal009_stop("Goal009 posterior draws, data, or labels have an invalid contract.")
  list(C = C, J = J, D = D, T = length(data$occasion_ids),
       max_draws = as.integer(max_draws), seed = as.integer(seed))
}

.goal009_detection_probability <- function(log_hazard) {
  out <- numeric(length(log_hazard))
  low <- log_hazard < log(.Machine$double.xmin)
  high <- log_hazard > 20
  mid <- !(low | high)
  out[low] <- exp(log_hazard[low])
  out[high] <- 1
  if (any(mid)) out[mid] <- -expm1(-exp(log_hazard[mid]))
  out
}

.goal009_quantile <- function(x, probability) {
  x <- x[is.finite(x)]
  if (length(x) == 0L) return(NA_real_)
  as.numeric(stats::quantile(x, probability, names = FALSE, type = 7))
}

.goal009_observed_array <- function(data, C, J, T) {
  result <- array(NA_integer_, dim = c(C, J, T), dimnames = list(
    data$candidate_ids, data$camera_ids, data$occasion_ids
  ))
  block <- J * T
  for (i in seq_len(C)) {
    rows <- ((i - 1L) * block + 1L):(i * block)
    result[i, , ] <- matrix(data$observed$detected[rows], nrow = J, byrow = TRUE)
  }
  result
}

.goal009_common_ranking_violation <- function(
  x, effort, camera_ids, occasion_ids, species_mask
) {
  J <- dim(x)[2L]
  T <- dim(x)[3L]
  result <- 0
  if (!any(species_mask) || J < 2L) return(result)
  detected <- !is.na(x) & x == 1L
  for (j1 in seq_len(J - 1L)) for (j2 in (j1 + 1L):J) {
    matched <- effort[j1, ] == 7L & effort[j2, ] == 7L
    if (!any(matched)) next
    ids <- which(species_mask)
    differences <- vapply(ids, function(i) {
      sum(detected[i, j1, matched]) - sum(detected[i, j2, matched])
    }, numeric(1))
    result <- result + min(sum(pmax(differences, 0)), sum(pmax(-differences, 0)))
  }
  result
}

.goal009_week_columns <- function(weeks, J) {
  unlist(lapply(weeks, function(t) ((t - 1L) * J + 1L):(t * J)),
         use.names = FALSE)
}

.goal009_statistic_values <- function(
  x, labels, effort, camera_ids, occasion_ids, species_mask = NULL
) {
  C <- dim(x)[1L]
  J <- dim(x)[2L]
  T <- dim(x)[3L]
  detected <- !is.na(x) & x == 1L
  species_any <- rowSums(detected, dims = 1L) > 0L
  values <- c(
    richness = sum(species_any),
    totalpositivecells = sum(detected),
    mammal_richness = sum(species_any & labels$taxon_class == "Mammalia"),
    mammal_positivecells = sum(detected[labels$taxon_class == "Mammalia", , , drop = FALSE]),
    bird_richness = sum(species_any & labels$taxon_class == "Aves"),
    bird_positivecells = sum(detected[labels$taxon_class == "Aves", , , drop = FALSE])
  )
  if (is.null(species_mask)) species_mask <- rep(TRUE, C)
  species_mask <- as.logical(species_mask)
  occasion_index <- suppressWarnings(as.integer(sub("^occ_", "", occasion_ids)))
  adjacent_occasion <- if (length(occasion_index) > 1L &&
                           !anyNA(occasion_index)) {
    diff(occasion_index) == 1L
  } else {
    rep(FALSE, max(0L, T - 1L))
  }
  block_starts <- seq.int(1L, T, by = 13L)
  for (b in seq_along(block_starts)) {
    idx <- block_starts[b]:min(T, block_starts[b] + 12L)
    block <- detected[, , idx, drop = FALSE]
    any_species <- apply(block, 1L, any)
    values[[paste0("block_", sprintf("%02d", b), "_positivecells")]] <- sum(block)
    values[[paste0("block_", sprintf("%02d", b), "_richness")]] <- sum(any_species)
  }
  switches <- 0L
  if (T > 1L) {
    for (t in seq_len(T - 1L)) {
      valid <- effort[, t] > 0L & effort[, t + 1L] > 0L
      if (!adjacent_occasion[[t]]) valid[] <- FALSE
      if (any(valid) && any(species_mask)) switches <- switches + sum(
        x[species_mask, valid, t, drop = FALSE] !=
          x[species_mask, valid, t + 1L, drop = FALSE],
        na.rm = TRUE
      )
    }
  }
  values[["adjacent_switch_count"]] <- switches
  pm <- match("Thylogale billardierii", labels$species_id)
  bt <- match("Bettongia gaimardi", labels$species_id)
  p12 <- match("jc_pm12", camera_ids)
  p23 <- match("jc_pm23", camera_ids)
  matched <- if (all(!is.na(c(p12, p23)))) effort[p12, ] == 7L & effort[p23, ] == 7L else rep(FALSE, T)
  values[["pademelon_bettong_matchedcount"]] <- sum(matched)
  if (all(!is.na(c(pm, bt, p12, p23))) && any(matched)) {
    pdiff <- sum(detected[pm, p12, matched]) - sum(detected[pm, p23, matched])
    bdiff <- sum(detected[bt, p23, matched]) - sum(detected[bt, p12, matched])
    values[["pademelon_bettong_crossing"]] <- min(pdiff, bdiff)
  } else {
    values[["pademelon_bettong_crossing"]] <- NA_real_
  }
  as.numeric(values) |> stats::setNames(names(values))
}

#' Generate bounded posterior predictive criticism for the Goal003 candidate.
goal009_ppc <- function(
  data, q_member_draws, alpha_draws, camera_effect_draws, labels, seed,
  max_draws = 1000L
) {
  spec <- .goal009_validate_draws(
    data, q_member_draws, alpha_draws, camera_effect_draws,
    labels, seed, max_draws
  )
  C <- spec$C; J <- spec$J; T <- spec$T
  n_draws <- min(spec$D, spec$max_draws)
  draw_indices <- unique(as.integer(floor(seq(0, spec$D - 1L, length.out = n_draws))) + 1L)
  # posterior::draws_matrix keeps dimensions on row extraction when its S3
  # method is registered. as.matrix() retains that subclass. Strip it before
  # outer(): two 1-row matrices otherwise produce a four-dimensional array,
  # so sweep(..., 2, effort) applies station effort along the species axis.
  q <- matrix(as.numeric(q_member_draws), nrow = spec$D, ncol = C)[
    draw_indices, , drop = FALSE]
  alpha <- matrix(as.numeric(alpha_draws), nrow = spec$D, ncol = C)[
    draw_indices, , drop = FALSE]
  camera <- matrix(as.numeric(camera_effect_draws), nrow = spec$D, ncol = J)[
    draw_indices, , drop = FALSE]
  labels <- tibble::as_tibble(labels[
    match(data$candidate_ids, labels$species_id), , drop = FALSE
  ])
  observed <- .goal009_observed_array(data, C, J, T)
  effort <- matrix(
    data$observed$active_days[seq_len(J * T)],
    nrow = J, ncol = T,
    byrow = TRUE,
    dimnames = list(data$camera_ids, data$occasion_ids)
  )
  observed_species_mask <- data$stan_data$detected_ever == 1L
  observed_values <- .goal009_statistic_values(
    observed, labels, effort, data$camera_ids, data$occasion_ids,
    observed_species_mask
  )
  observed_values[["global_commonranking_violation"]] <-
    .goal009_common_ranking_violation(
      observed, effort, data$camera_ids, data$occasion_ids,
      observed_species_mask
    )
  stat_names <- names(observed_values)
  replicated_values <- matrix(NA_real_, nrow = n_draws, ncol = length(stat_names),
                              dimnames = list(NULL, stat_names))
  station_values <- matrix(0, nrow = n_draws, ncol = C * J)
  block_count <- ceiling(T / 13)
  species_total_values <- matrix(0, nrow = n_draws, ncol = C)
  species_block_values <- matrix(0, nrow = n_draws, ncol = C * block_count)
  withr::with_seed(spec$seed, for (d in seq_len(n_draws)) {
    membership <- stats::rbinom(C, 1L, q[d, ])
    membership[data$stan_data$detected_ever == 1L] <- 1L
    probability <- matrix(0, nrow = C, ncol = J * T)
    for (t in seq_len(T)) {
      log_hazard <- outer(alpha[d, ], camera[d, ], "+")
      log_hazard <- sweep(log_hazard, 2L, log(effort[, t]), "+")
      probability[, ((t - 1L) * J + 1L):(t * J)] <-
        .goal009_detection_probability(as.vector(log_hazard)) |>
        matrix(nrow = C, ncol = J)
    }
    replicated <- matrix(stats::rbinom(C * J * T, 1L, as.vector(probability)),
                          nrow = C, ncol = J * T)
    replicated <- replicated * membership
    zero <- rep(effort == 0L, each = C)
    replicated[zero] <- NA_integer_
    replicated_array <- array(replicated, dim = c(C, J, T))
    replicated_values[d, ] <- {
      values <- .goal009_statistic_values(
        replicated_array, labels, effort, data$camera_ids, data$occasion_ids,
        observed_species_mask
      )
      values[["global_commonranking_violation"]] <-
        .goal009_common_ranking_violation(
          replicated_array, effort, data$camera_ids, data$occasion_ids,
          observed_species_mask
        )
      values
    }
    station_values[d, ] <- rowSums(
      matrix(replicated_array == 1L, nrow = C * J, ncol = T),
      na.rm = TRUE
    )
    cell_values <- matrix(!is.na(replicated_array) & replicated_array == 1L,
                          nrow = C, ncol = J * T)
    species_total_values[d, ] <- rowSums(cell_values, na.rm = TRUE)
    for (b in seq_len(block_count)) {
      idx <- ((b - 1L) * 13L + 1L):min(T, b * 13L)
      species_block_values[d, ((b - 1L) * C + 1L):(b * C)] <- rowSums(
        cell_values[, .goal009_week_columns(idx, J), drop = FALSE]
      )
    }
  }, .rng_kind = "Mersenne-Twister", .rng_normal_kind = "Inversion",
     .rng_sample_kind = "Rejection")
  summary <- tibble::tibble(
    statistic = stat_names,
    observed = as.numeric(observed_values),
    q05 = vapply(seq_along(stat_names), function(k) .goal009_quantile(
      replicated_values[, k], 0.05
    ), numeric(1)),
    q50 = vapply(seq_along(stat_names), function(k) .goal009_quantile(
      replicated_values[, k], 0.50
    ), numeric(1)),
    q95 = vapply(seq_along(stat_names), function(k) .goal009_quantile(
      replicated_values[, k], 0.95
    ), numeric(1)),
    tail_ge = vapply(seq_along(stat_names), function(k) {
      if (is.na(observed_values[[k]])) return(NA_real_)
      mean(replicated_values[, k] >= observed_values[[k]], na.rm = TRUE)
    }, numeric(1)),
    mcse = NA_real_
  )
  summary$mcse <- ifelse(
    is.na(summary$tail_ge), NA_real_,
    sqrt(summary$tail_ge * (1 - summary$tail_ge) / n_draws)
  )
  draw_statistics <- tibble::as_tibble(cbind(
    draw_index = draw_indices,
    as.data.frame(replicated_values, check.names = FALSE)
  ))
  for (i in seq_len(C)) {
    draw_statistics[[paste0("species_total_", make.names(data$candidate_ids[[i]]))]] <-
      species_total_values[, i]
  }
  species_station <- tidyr::expand_grid(
    species_id = data$candidate_ids,
    camera_id = data$camera_ids
  )
  station_order <- as.vector(t(matrix(seq_len(C * J), nrow = C, ncol = J)))
  station_values <- station_values[, station_order, drop = FALSE]
  observed_station <- rowSums(
    matrix(observed == 1L, nrow = C * J, ncol = T), na.rm = TRUE
  )
  species_station$observed <- as.numeric(observed_station[station_order])
  species_station$q05 <- apply(station_values, 2L, .goal009_quantile, probability = 0.05)
  species_station$q50 <- apply(station_values, 2L, .goal009_quantile, probability = 0.50)
  species_station$q95 <- apply(station_values, 2L, .goal009_quantile, probability = 0.95)
  observed_cells <- matrix(!is.na(observed) & observed == 1L,
                            nrow = C, ncol = J * T)
  species_counts <- tibble::tibble(
    species_id = data$candidate_ids,
    observed = rowSums(observed_cells),
    q05 = apply(species_total_values, 2L, .goal009_quantile, probability = 0.05),
    q50 = apply(species_total_values, 2L, .goal009_quantile, probability = 0.50),
    q95 = apply(species_total_values, 2L, .goal009_quantile, probability = 0.95)
  )
  species_block <- tidyr::expand_grid(
    species_id = data$candidate_ids,
    block_id = sprintf("block_%02d", seq_len(block_count))
  )
  species_block_order <- as.vector(t(matrix(seq_len(C * block_count), nrow = C,
                                            ncol = block_count)))
  observed_block_values <- matrix(0, nrow = C, ncol = block_count)
  for (b in seq_len(block_count)) {
    idx <- ((b - 1L) * 13L + 1L):min(T, b * 13L)
    observed_block_values[, b] <- rowSums(
      observed_cells[, .goal009_week_columns(idx, J), drop = FALSE]
    )
  }
  species_block$observed <- as.vector(observed_block_values)[species_block_order]
  species_block$q05 <- apply(species_block_values, 2L, .goal009_quantile, probability = 0.05)[species_block_order]
  species_block$q50 <- apply(species_block_values, 2L, .goal009_quantile, probability = 0.50)[species_block_order]
  species_block$q95 <- apply(species_block_values, 2L, .goal009_quantile, probability = 0.95)[species_block_order]
  occasion_index <- suppressWarnings(as.integer(sub("^occ_", "", data$occasion_ids)))
  adjacent <- if (T > 1L && !anyNA(occasion_index)) diff(occasion_index) == 1L else rep(FALSE, max(0L, T - 1L))
  switch_pairs <- if (T > 1L) sum(
    (effort[, seq_len(T - 1L)] > 0L) &
      (effort[, seq_len(T - 1L) + 1L] > 0L) &
      matrix(rep(adjacent, each = J), nrow = J)
  ) else 0L
  list(
    summary = summary,
    draw_statistics = draw_statistics,
    species_station = species_station,
    species_counts = species_counts,
    species_block = species_block,
    metadata = list(
      goal = "Goal009 first-year model criticism",
      n_input_draws = spec$D,
      n_draws = n_draws,
      n_candidate_species = C,
      n_cameras = J,
      n_occasions = T,
      max_draws = spec$max_draws,
      draw_indices = draw_indices,
      draw_selection = "deterministic evenly spaced posterior draws",
      membership = "one Bernoulli membership draw per species per posterior draw; known species fixed at one",
      replicated_quantity = "weekly detected richness and positive cells; latent richness is not used",
      tail_ge_note = "posterior predictive tail probability P(replicated >= observed), not a uniform p-value",
      mcse_note = "naive Monte Carlo approximation; posterior draws may be correlated",
      seed = spec$seed,
      rng_kind = c("Mersenne-Twister", "Inversion", "Rejection"),
      observed_species_count = sum(observed_species_mask),
      switch_denominator = as.integer(switch_pairs * sum(observed_species_mask)),
      ranking_species_mask = "fixed observed detected-ever species for observed and replicated arrays"
    )
  )
}

#' Check that sequential membership updating agrees with the joint model.
goal009_sequential_bridge <- function(
  omega_grid = c(0.2, 0.5, 0.8),
  alpha_grid = c(-3, -1, 1),
  seed = 9009L
) {
  if (!is.numeric(omega_grid) || any(!is.finite(omega_grid)) ||
      any(omega_grid <= 0 | omega_grid >= 1) ||
      !is.numeric(alpha_grid) || any(!is.finite(alpha_grid)) ||
      length(omega_grid) == 0L || length(alpha_grid) == 0L ||
      !is.numeric(seed) || length(seed) != 1L || !is.finite(seed) ||
      seed < 1 || seed >= .Machine$integer.max) {
    .goal009_stop("The sequential bridge grids are invalid.")
  }
  # Two species, two stations, and two periods.  The b vector is shared by
  # species and sum-to-zero, while the species identities persist between
  # periods.  At least one detection for each species makes the non-member
  # likelihood exactly zero and therefore tests the known-detection boundary.
  species_ids <- c("species_1", "species_2")
  camera_ids <- c("station_1", "station_2")
  b <- c(-0.25, 0.25)
  case_observations <- list()
  both_detected <- array(0L, dim = c(2L, 2L, 2L))
  both_detected[, 1L, 1L] <- 1L
  both_detected[, 2L, 2L] <- 1L
  case_observations$both_detected <- both_detected
  one_allzero <- both_detected
  one_allzero[1L, , ] <- 0L
  case_observations$one_allzero <- one_allzero
  period2_first <- array(0L, dim = c(2L, 2L, 2L))
  period2_first[1L, 1L, 2L] <- 1L
  period2_first[2L, 2L, 1L] <- 1L
  case_observations$period2_first <- period2_first
  parameter_grid <- tidyr::expand_grid(
    case_id = names(case_observations),
    omega = omega_grid, alpha_1 = alpha_grid, alpha_2 = alpha_grid
  ) |>
    dplyr::mutate(grid_id = dplyr::row_number()) |>
    dplyr::select(grid_id, dplyr::everything())
  parameter_grid[c(
    "joint_likelihood", "sequential_likelihood",
    "reverse_sequential_likelihood", "wrong_reset_likelihood",
    "q_after_period1", "q_after_period2", "joint_q_species1",
    "joint_q_species2"
  )] <- NA_real_
  weights <- vector("list", nrow(parameter_grid))
  probabilities <- vector("list", nrow(parameter_grid))
  memberships <- vector("list", nrow(parameter_grid))
  for (g in seq_len(nrow(parameter_grid))) {
    observations <- case_observations[[parameter_grid$case_id[g]]]
    alpha <- c(parameter_grid$alpha_1[g], parameter_grid$alpha_2[g])
    p <- array(0, dim = c(2L, 2L, 2L))
    for (s in 1:2) for (j in 1:2) for (t in 1:2) {
      p[s, j, t] <- .goal009_detection_probability(log(7) + alpha[s] + b[j])
    }
    probabilities[[g]] <- p
    member_period <- matrix(1, nrow = 2L, ncol = 2L)
    for (s in 1:2) for (t in 1:2) {
      member_period[s, t] <- prod(
        p[s, , t]^observations[s, , t] *
          (1 - p[s, , t])^(1 - observations[s, , t])
      )
    }
    member_likelihood <- apply(member_period, 1L, prod)
    state <- tidyr::expand_grid(member_1 = 0:1, member_2 = 0:1)
    state$prior_weight <- parameter_grid$omega[g] ^
      (state$member_1 + state$member_2) *
      (1 - parameter_grid$omega[g]) ^ (2L - state$member_1 - state$member_2)
    state$member_likelihood <- vapply(seq_len(nrow(state)), function(k) {
      members <- c(state$member_1[k], state$member_2[k])
      prod(vapply(seq_len(2L), function(s) {
        if (members[s] == 1L) return(member_likelihood[s])
        if (any(observations[s, , ] == 1L)) return(0)
        1
      }, numeric(1)))
    }, numeric(1))
    state$weight <- state$prior_weight * state$member_likelihood
    state$posterior_mass <- state$weight / sum(state$weight)
    state$grid_id <- parameter_grid$grid_id[g]
    state$case_id <- parameter_grid$case_id[g]
    weights[[g]] <- state
    q1 <- q2 <- q_reverse <- q_rev2 <- numeric(2L)
    period_evidence <- matrix(0, nrow = 2L, ncol = 2L)
    for (s in 1:2) for (t in 1:2) {
      l0 <- if (any(observations[s, , t] == 1L)) 0 else 1
      period_evidence[s, t] <- (1 - parameter_grid$omega[g]) * l0 +
        parameter_grid$omega[g] * member_period[s, t]
    }
    for (s in 1:2) {
      q1[s] <- parameter_grid$omega[g] * member_period[s, 1L] /
        period_evidence[s, 1L]
      l0_2 <- if (any(observations[s, , 2L] == 1L)) 0 else 1
      q2[s] <- q1[s] * member_period[s, 2L] /
        ((1 - q1[s]) * l0_2 + q1[s] * member_period[s, 2L])
      q_reverse_period2 <- parameter_grid$omega[g] * member_period[s, 2L] /
        period_evidence[s, 2L]
      q_rev2[s] <- q_reverse_period2
      l0_1 <- if (any(observations[s, , 1L] == 1L)) 0 else 1
      q_reverse[s] <- q_reverse_period2 * member_period[s, 1L] /
        ((1 - q_reverse_period2) * l0_1 + q_reverse_period2 * member_period[s, 1L])
    }
    joint <- sum(state$weight)
    sequential <- prod(period_evidence[, 1L]) *
      prod((1 - q1) * ifelse(rowSums(observations[, , 2L]) > 0, 0, 1) +
        q1 * member_period[, 2L])
    reverse <- prod(period_evidence[, 2L]) *
      prod((1 - q_rev2) * ifelse(rowSums(observations[, , 1L]) > 0, 0, 1) +
        q_rev2 * member_period[, 1L])
    reset <- prod(period_evidence[, 1L]) * prod(period_evidence[, 2L])
    parameter_grid$joint_likelihood[g] <- joint
    parameter_grid$sequential_likelihood[g] <- sequential
    parameter_grid$reverse_sequential_likelihood[g] <- reverse
    parameter_grid$wrong_reset_likelihood[g] <- reset
    parameter_grid$q_after_period1[g] <- q1[1L]
    parameter_grid$q_after_period2[g] <- q2[1L]
    parameter_grid$joint_q_species1[g] <- sum(vapply(seq_len(nrow(state)), function(k) {
      state$weight[k] * state$member_1[k]
    }, numeric(1))) / joint
    parameter_grid$joint_q_species2[g] <- sum(vapply(seq_len(nrow(state)), function(k) {
      state$weight[k] * state$member_2[k]
    }, numeric(1))) / joint
    memberships[[g]] <- tibble::tibble(
      grid_id = parameter_grid$grid_id[g], species_id = species_ids,
      q_period1 = q1, q_period2 = q2, q_reverse_after_period2 = q_rev2,
      q_reverse_final = q_reverse,
      joint_membership_probability = c(parameter_grid$joint_q_species1[g],
                                       parameter_grid$joint_q_species2[g])
    )
  }
  parameter_grid$correct_abs_difference <- abs(
    parameter_grid$joint_likelihood - parameter_grid$sequential_likelihood
  )
  parameter_grid$reverse_abs_difference <- abs(
    parameter_grid$joint_likelihood - parameter_grid$reverse_sequential_likelihood
  )
  parameter_grid$wrong_abs_difference <- abs(
    parameter_grid$joint_likelihood - parameter_grid$wrong_reset_likelihood
  )
  # Each case is a different observed dataset: normalize its parameter grid
  # separately rather than treating case labels as uncertain parameters.
  normalize_by_case <- function(likelihood) {
    likelihood / ave(likelihood, parameter_grid$case_id, FUN = sum)
  }
  parameter_grid$joint_posterior_mass <- normalize_by_case(parameter_grid$joint_likelihood)
  parameter_grid$sequential_posterior_mass <- normalize_by_case(parameter_grid$sequential_likelihood)
  parameter_grid$reverse_posterior_mass <- normalize_by_case(parameter_grid$reverse_sequential_likelihood)
  likelihood_weights <- dplyr::bind_rows(weights)
  membership_probabilities <- dplyr::bind_rows(memberships)
  case_errors <- parameter_grid[c(
    "grid_id", "case_id", "correct_abs_difference",
    "reverse_abs_difference", "wrong_abs_difference"
  )]
  known_final <- unlist(lapply(seq_len(nrow(parameter_grid)), function(g) {
    known <- rowSums(case_observations[[parameter_grid$case_id[g]]], dims = 1L) > 0L
    memberships[[g]]$q_period2[known]
  }), use.names = FALSE)
  error_fields <- c(
    joint_sequential_max_abs_error = max(parameter_grid$correct_abs_difference),
    normalized_mass_max_abs_error = max(abs(parameter_grid$joint_posterior_mass -
      parameter_grid$sequential_posterior_mass)),
    reverse_period_max_abs_error = max(parameter_grid$reverse_abs_difference),
    final_membership_max_abs_error = max(abs(
      membership_probabilities$q_period2 -
        membership_probabilities$joint_membership_probability)),
    reverse_membership_max_abs_error = max(abs(
      membership_probabilities$q_reverse_final -
        membership_probabilities$joint_membership_probability)),
    wrong_reset_max_abs_difference = max(parameter_grid$wrong_abs_difference),
    known_detection_min_membership_probability = min(known_final),
    detection_implies_membership1 = as.numeric(all(abs(known_final - 1) <= 1e-12))
  )
  list(
    grid = parameter_grid,
    likelihood_weights = likelihood_weights,
    case_errors = case_errors,
    membership_probabilities = membership_probabilities,
    joint_likelihood = parameter_grid$joint_likelihood,
    sequential_likelihood = parameter_grid$sequential_likelihood,
    wrong_reinitialised_likelihood = parameter_grid$wrong_reset_likelihood,
    q_after_period1 = parameter_grid$q_after_period1,
    q_after_period2 = parameter_grid$q_after_period2,
    error_fields = error_fields,
    max_abs_difference = unname(error_fields[["joint_sequential_max_abs_error"]]),
    max_wrong_abs_difference = unname(error_fields[["wrong_reset_max_abs_difference"]]),
    normalized_same_grid = isTRUE(error_fields[["normalized_mass_max_abs_error"]] <= 1e-12),
    normalized_posterior_masses = parameter_grid[c(
      "grid_id", "joint_posterior_mass", "sequential_posterior_mass",
      "reverse_posterior_mass"
    )],
    reverse_period_order_agreement = unname(error_fields[["reverse_period_max_abs_error"]] <= 1e-12),
    wrong_reset_control_differs = unname(error_fields[["wrong_reset_max_abs_difference"]] > 1e-12),
    species_ids = species_ids, camera_ids = camera_ids, periods = c("period_1", "period_2"),
    shared_camera_effect = b,
    shared_omega = TRUE,
    seed = as.integer(seed)
  )
}
