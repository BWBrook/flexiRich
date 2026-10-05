# Conditional timing strata and exact pairwise timing summaries.

.goal012_validate_binary_panel <- function(y, effort = NULL, context = NULL) {
  if (!is.matrix(y) || !is.numeric(y)) {
    stop("y must be a numeric matrix", call. = FALSE)
  }
  if (length(dim(y)) != 2L || any(dim(y) < 1L)) {
    stop("y must have positive two-dimensional shape", call. = FALSE)
  }
  if (any(!is.na(y) & !(y %in% c(0, 1)))) {
    stop("y must contain only 0, 1, or NA", call. = FALSE)
  }
  if (!is.null(effort)) {
    if (!is.matrix(effort) || !is.numeric(effort) ||
        !identical(dim(effort), dim(y))) {
      stop("effort must be a numeric matrix with the same dimensions as y",
           call. = FALSE)
    }
    if (any(!is.finite(effort)) || any(effort < 0 | effort > 7) ||
        any(effort != as.integer(effort))) {
      stop("effort must contain integer active days from 0 through 7",
           call. = FALSE)
    }
    if (any(is.na(y) != (effort == 0))) {
      stop("y must be NA exactly when effort is zero", call. = FALSE)
    }
  }
  if (!is.null(context)) {
    if (!is.matrix(context) || !is.character(context) ||
        !identical(dim(context), dim(y))) {
      stop("context must be a character matrix with the same dimensions as y",
           call. = FALSE)
    }
  }
  invisible(TRUE)
}

.goal012_validate_strata <- function(strata, y) {
  if (!is.list(strata) || is.null(strata$indices) ||
      is.null(strata$table)) {
    stop("strata must be the result of goal012_timing_strata", call. = FALSE)
  }
  indices <- strata$indices
  if (!is.list(indices)) stop("strata$indices must be a list", call. = FALSE)
  total <- length(y)
  if (length(indices)) {
    valid <- vapply(indices, function(x) {
      is.numeric(x) && all(is.finite(x)) && all(x == as.integer(x)) &&
        all(x >= 1L & x <= total) && !anyDuplicated(x)
    }, logical(1L))
    if (!all(valid)) stop("strata indices are invalid", call. = FALSE)
    flat <- unlist(indices, use.names = FALSE)
    if (anyDuplicated(flat)) stop("strata indices must be disjoint", call. = FALSE)
  }
  if (!is.data.frame(strata$table) || nrow(strata$table) != length(indices)) {
    stop("strata$table does not match strata$indices", call. = FALSE)
  }
  if (length(indices) && !all(vapply(indices, length, integer(1L)) ==
                                strata$table$n_cells)) {
    stop("strata$table$n_cells does not match strata$indices", call. = FALSE)
  }
  mixed <- strata$mixed
  if (is.null(mixed)) mixed <- integer(0L)
  if (!is.numeric(mixed) || any(!is.finite(mixed)) ||
      any(mixed != as.integer(mixed)) || any(mixed < 1L | mixed > length(indices))) {
    stop("strata$mixed contains invalid stratum indices", call. = FALSE)
  }
  mixed <- as.integer(mixed)
  if (anyDuplicated(mixed)) stop("strata$mixed contains duplicates", call. = FALSE)
  if (length(mixed) && any(!strata$table$mixed[mixed])) {
    stop("strata$mixed must identify mixed strata", call. = FALSE)
  }
  invisible(list(indices = indices, mixed = mixed, table = strata$table))
}

# Partition sampled cells within each species by exact effort and context.
goal012_timing_strata <- function(y, effort, context) {
  .goal012_validate_binary_panel(y, effort, context)
  active <- effort > 0
  active_indices <- which(active)
  if (anyNA(context[active])) {
    stop("context cannot be NA for sampled cells", call. = FALSE)
  }
  if (!length(active_indices)) {
    empty <- data.frame(
      stratum_id = integer(0L), row = integer(0L), n_cells = integer(0L),
      n_detected = integer(0L), nondetected = integer(0L), mixed = logical(0L),
      context = character(0L), active_days = integer(0L),
      stringsAsFactors = FALSE
    )
    return(list(indices = list(), mixed = integer(0L), table = empty))
  }

  dims <- dim(y)
  row <- row(y)[active]
  # interaction combines factor levels rather than pasted strings, so context
  # values containing punctuation cannot create accidental key collisions.
  groups <- interaction(row, effort[active], context[active],
                        drop = TRUE, lex.order = TRUE, sep = "\r")
  indices <- unname(split(active_indices, groups))
  table <- do.call(rbind, lapply(seq_along(indices), function(i) {
    cells <- indices[[i]]
    vals <- y[cells]
    data.frame(
      stratum_id = i,
      row = row(y)[cells[1L]],
      n_cells = length(cells),
      n_detected = sum(vals == 1),
      nondetected = sum(vals == 0),
      mixed = any(vals == 0) && any(vals == 1),
      context = context[cells[1L]],
      active_days = effort[cells[1L]],
      stringsAsFactors = FALSE
    )
  }))
  rownames(table) <- NULL
  list(indices = indices, mixed = which(table$mixed), table = table,
       dimensions = dims)
}

# Shuffle detections conditionally on each mixed stratum's observed count.
goal012_shuffle_timing <- function(y, strata) {
  .goal012_validate_binary_panel(y)
  checked <- .goal012_validate_strata(strata, y)
  out <- y
  for (i in checked$mixed) {
    cells <- checked$indices[[i]]
    n <- length(cells)
    k <- sum(y[cells] == 1)
    chosen <- if (k == 0L) integer(0L) else if (k == n) seq_len(n) else
      sample.int(n, size = k)
    out[cells] <- 0
    if (length(chosen)) out[cells[chosen]] <- 1
  }
  out
}

.goal012_validate_statistics_inputs <- function(y, eligible, row_species,
                                                within_block) {
  .goal012_validate_binary_panel(y)
  if (!is.matrix(eligible) || !is.logical(eligible) ||
      !identical(dim(eligible), c(nrow(y), ncol(y) - 1L))) {
    stop("eligible must be a logical matrix with one fewer column than y",
         call. = FALSE)
  }
  if (anyNA(eligible)) stop("eligible cannot contain NA", call. = FALSE)
  if (length(within_block) != ncol(y) - 1L ||
      !is.logical(within_block) || anyNA(within_block)) {
    stop("within_block must be a complete logical vector of length ncol(y)-1",
         call. = FALSE)
  }
  if (!is.character(row_species) || length(row_species) != nrow(y) ||
      anyNA(row_species)) {
    stop("row_species must be a complete character vector for y's rows",
         call. = FALSE)
  }
  active_pairs <- eligible
  if (any(active_pairs & is.na(y[, -ncol(y), drop = FALSE]))) {
    stop("eligible pairs cannot use NA y cells", call. = FALSE)
  }
  if (any(active_pairs & is.na(y[, -1L, drop = FALSE]))) {
    stop("eligible pairs cannot use NA y cells", call. = FALSE)
  }
  invisible(TRUE)
}

.goal012_statistic_names <- function(row_species) {
  c("switches_all", "positive_pairs_all", "switches_within_block",
    paste0("species:", sort(unique(row_species))))
}

# Summarise observed adjacent-week timing pairs selected by eligible.
goal012_timing_statistics <- function(y, eligible, row_species, within_block) {
  .goal012_validate_statistics_inputs(y, eligible, row_species, within_block)
  left <- y[, -ncol(y), drop = FALSE]
  right <- y[, -1L, drop = FALSE]
  switches <- left != right
  positive <- left == 1 & right == 1
  pair_species <- row_species
  row_switches <- rowSums(switches & eligible)
  species <- sort(unique(row_species))
  species_switches <- rowsum(row_switches, pair_species, reorder = TRUE)
  out <- c(
    switches_all = sum(row_switches),
    positive_pairs_all = sum(positive & eligible),
    switches_within_block = sum(switches & eligible &
                                  matrix(within_block, nrow(y), ncol(y) - 1L,
                                         byrow = TRUE)),
    setNames(as.numeric(species_switches[species, 1L]), paste0("species:", species))
  )
  out[.goal012_statistic_names(row_species)]
}

.goal012_expected_pair <- function(n1, k1, n2 = NULL, k2 = NULL) {
  p1 <- k1 / n1
  if (is.null(n2)) {
    if (n1 < 2L) stop("a same-stratum pair requires at least two cells",
                      call. = FALSE)
    denom <- n1 * (n1 - 1)
    return(c(switch = 2 * k1 * (n1 - k1) / denom,
             positive = k1 * (k1 - 1) / denom))
  }
  p2 <- k2 / n2
  c(switch = p1 + p2 - 2 * p1 * p2, positive = p1 * p2)
}

# Compute exact conditional expectations under the stratum-wise shuffle law.
goal012_expected_timing <- function(y, strata, eligible, row_species,
                                    within_block) {
  .goal012_validate_statistics_inputs(y, eligible, row_species, within_block)
  checked <- .goal012_validate_strata(strata, y)
  D <- nrow(y); T <- ncol(y)
  membership <- rep(NA_integer_, length(y))
  if (length(checked$indices)) for (i in seq_along(checked$indices)) {
    cells <- checked$indices[[i]]
    if (any(!is.na(membership[cells]))) {
      stop("strata indices must be disjoint", call. = FALSE)
    }
    membership[cells] <- i
  }
  pair_n <- numeric(length(eligible)); pair_k <- numeric(length(eligible))
  for (i in seq_along(checked$indices)) {
    cells <- checked$indices[[i]]
    pair_n[i] <- length(cells)
    pair_k[i] <- sum(y[cells] == 1)
  }

  expected_switch <- matrix(0, D, T - 1L)
  expected_positive <- expected_switch
  eligible_indices <- which(eligible)
  for (flat_left in eligible_indices) {
    row_i <- ((flat_left - 1L) %% D) + 1L
    col_i <- ((flat_left - 1L) %/% D) + 1L
    flat_right <- flat_left + D
    stratum_left <- membership[flat_left]
    stratum_right <- membership[flat_right]
    if (is.na(stratum_left) || is.na(stratum_right)) {
      stop("eligible pairs must belong to timing strata", call. = FALSE)
    }
    if (stratum_left == stratum_right) {
      pair <- .goal012_expected_pair(pair_n[stratum_left],
                                     pair_k[stratum_left])
    } else {
      pair <- .goal012_expected_pair(pair_n[stratum_left],
                                     pair_k[stratum_left],
                                     pair_n[stratum_right], pair_k[stratum_right])
    }
    expected_switch[row_i, col_i] <- pair[["switch"]]
    expected_positive[row_i, col_i] <- pair[["positive"]]
  }
  row_switches <- rowSums(expected_switch * eligible)
  species <- sort(unique(row_species))
  species_switches <- rowsum(row_switches, row_species, reorder = TRUE)
  within <- matrix(within_block, D, T - 1L, byrow = TRUE)
  out <- c(
    switches_all = sum(row_switches),
    positive_pairs_all = sum(expected_positive * eligible),
    switches_within_block = sum(expected_switch * eligible * within),
    setNames(as.numeric(species_switches[species, 1L]), paste0("species:", species))
  )
  out[.goal012_statistic_names(row_species)]
}
