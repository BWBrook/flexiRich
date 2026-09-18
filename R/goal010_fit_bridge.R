.goal010_fit_bridge_stop <- function(message) {
  stop(message, call. = FALSE)
}

.goal010_bridge_plain_matrix <- function(x, name) {
  if (!(is.matrix(x) || is.data.frame(x))) {
    .goal010_fit_bridge_stop(paste0(name, " must be a numeric matrix."))
  }
  result <- matrix(
    as.numeric(x),
    nrow = nrow(x),
    ncol = ncol(x),
    dimnames = NULL
  )
  if (!is.numeric(result) || anyNA(result) || any(!is.finite(result))) {
    .goal010_fit_bridge_stop(paste0(name, " must contain finite values."))
  }
  result
}

.goal010_bridge_plain_array <- function(x, name, D, C, J) {
  if (!is.array(x) || length(dim(x)) != 3L ||
      !identical(dim(x), c(D, C, J))) {
    .goal010_fit_bridge_stop(paste0(
      name,
      " must be a finite D by C by J array in draw, species, station order."
    ))
  }
  result <- array(as.numeric(x), dim = c(D, C, J))
  if (anyNA(result) || any(!is.finite(result))) {
    .goal010_fit_bridge_stop(paste0(name, " must contain finite values."))
  }
  result
}

.goal010_bridge_fit_draw_matrix <- function(fit, variables) {
  draws_method <- if (is.list(fit) || is.environment(fit)) {
    tryCatch(fit$draws, error = function(error) NULL)
  } else {
    NULL
  }
  if (!is.function(draws_method)) {
    .goal010_fit_bridge_stop("fit must provide a draws() method.")
  }
  raw <- tryCatch(
    draws_method(variables = variables),
    error = function(error) {
      tryCatch(draws_method(), error = function(error) NULL)
    }
  )
  if (is.null(raw)) {
    .goal010_fit_bridge_stop("fit$draws() could not return bridge variables.")
  }
  matrix_result <- if (is.matrix(raw) || is.data.frame(raw)) {
    as.matrix(raw)
  } else {
    tryCatch(
      as.matrix(posterior::as_draws_matrix(raw)),
      error = function(error) {
        .goal010_fit_bridge_stop(
          "fit$draws() must return a named posterior draw matrix."
        )
      }
    )
  }
  if (!is.numeric(matrix_result) || nrow(matrix_result) < 1L ||
      is.null(colnames(matrix_result)) || anyNA(colnames(matrix_result))) {
    .goal010_fit_bridge_stop("Bridge draws must be a non-empty named matrix.")
  }
  missing <- setdiff(variables, colnames(matrix_result))
  if (length(missing) > 0L) {
    .goal010_fit_bridge_stop(paste0(
      "Bridge draws are missing variables: ", paste(missing, collapse = ", "),
      "."
    ))
  }
  selected <- matrix_result[, variables, drop = FALSE]
  matrix(
    as.numeric(selected),
    nrow = nrow(selected),
    ncol = ncol(selected),
    dimnames = list(NULL, variables)
  )
}

.goal010_bridge_vector_names <- function(prefix, n) {
  sprintf("%s[%d]", prefix, seq_len(n))
}

.goal010_bridge_prepare_parameter_draws <- function(draws, data, spatial) {
  if (!is.list(draws)) {
    .goal010_fit_bridge_stop("draws must be a list of extracted parameter draws.")
  }
  required <- c("alpha", "camera_effect")
  if (spatial) {
    required <- c(required, "interaction", "station_log_rate")
  }
  missing <- setdiff(required, names(draws))
  if (length(missing) > 0L) {
    .goal010_fit_bridge_stop(paste0(
      "draws is missing: ", paste(missing, collapse = ", "),
      "."
    ))
  }
  alpha <- .goal010_bridge_plain_matrix(draws$alpha, "draws$alpha")
  camera_effect <- .goal010_bridge_plain_matrix(
    draws$camera_effect,
    "draws$camera_effect"
  )
  D <- nrow(alpha)
  C <- length(data$candidate_ids)
  J <- length(data$camera_ids)
  if (!identical(dim(alpha), c(D, C))) {
    .goal010_fit_bridge_stop("draws$alpha has invalid dimensions.")
  }
  if (!identical(dim(camera_effect), c(D, J))) {
    .goal010_fit_bridge_stop("draws$camera_effect has invalid dimensions.")
  }
  result <- list(
    alpha = alpha,
    camera_effect = camera_effect,
    D = D
  )
  if ("q_member" %in% names(draws)) {
    q_member <- .goal010_bridge_plain_matrix(
      draws$q_member,
      "draws$q_member"
    )
    if (!identical(dim(q_member), c(D, C)) ||
        any(q_member < 0 | q_member > 1)) {
      .goal010_fit_bridge_stop("draws$q_member has invalid dimensions or values.")
    }
    result$q_member <- q_member
  }
  if (spatial) {
    result$interaction <- .goal010_bridge_plain_array(
      draws$interaction,
      "draws$interaction",
      D,
      C,
      J
    )
    result$station_log_rate <- .goal010_bridge_plain_array(
      draws$station_log_rate,
      "draws$station_log_rate",
      D,
      C,
      J
    )
  }
  result
}

#' Compare fitted Goal003 or Goal010 transformed quantities with R references.
goal010_fit_bridge <- function(fit, data, draws, max_draws = 20L) {
  spatial <- is.list(data) && "interaction_scale" %in% names(data)
  if (spatial) {
    .validate_goal010_spatial_data(data)
  } else {
    .validate_goal003_flexirich_data(data)
  }
  valid_max_draws <- is.numeric(max_draws) &&
    !is.logical(max_draws) &&
    length(max_draws) == 1L &&
    !is.na(max_draws) &&
    is.finite(max_draws) &&
    max_draws == trunc(max_draws) &&
    max_draws >= 1L
  if (!valid_max_draws) {
    .goal010_fit_bridge_stop("max_draws must be one positive integer.")
  }
  parameter_draws <- .goal010_bridge_prepare_parameter_draws(
    draws,
    data,
    spatial
  )
  C <- length(data$candidate_ids)
  J <- length(data$camera_ids)
  D <- parameter_draws$D
  core_names <- c(
    "omega",
    .goal010_bridge_vector_names("member_ll", C),
    .goal010_bridge_vector_names("q_member", C),
    "expected_richness"
  )
  core <- .goal010_bridge_fit_draw_matrix(fit, core_names)
  if (nrow(core) != D) {
    .goal010_fit_bridge_stop(
      "fit and extracted parameter draws have different draw counts."
    )
  }
  n_selected <- min(as.integer(max_draws), D)
  draw_index <- as.integer(round(seq.int(1L, D, length.out = n_selected)))
  draw_index <- unique(draw_index)
  result <- data.frame(
    draw_index = draw_index,
    member_ll_error = NA_real_,
    q_error = NA_real_,
    expected_richness_error = NA_real_,
    camera_center_error = NA_real_,
    interaction_center_error = NA_real_,
    station_log_rate_error = NA_real_,
    stringsAsFactors = FALSE
  )
  member_names <- .goal010_bridge_vector_names("member_ll", C)
  q_names <- .goal010_bridge_vector_names("q_member", C)
  for (row in seq_len(nrow(result))) {
    index <- result$draw_index[[row]]
    alpha <- parameter_draws$alpha[index, ]
    camera_effect <- parameter_draws$camera_effect[index, ]
    interaction <- if (spatial) {
      matrix(
        parameter_draws$interaction[index, , , drop = FALSE],
        nrow = C,
        ncol = J
      )
    } else {
      NULL
    }
    reference <- if (spatial) {
      goal010_spatial_conditionals(
        data,
        omega = core[index, "omega"],
        alpha = alpha,
        camera_effect = camera_effect,
        interaction = interaction
      )
    } else {
      goal003_flexirich_conditionals(
        data,
        omega = core[index, "omega"],
        alpha = alpha,
        camera_effect = camera_effect
      )
    }
    stan_member_ll <- core[index, member_names]
    stan_q <- core[index, q_names]
    result$member_ll_error[[row]] <- max(
      abs(stan_member_ll - unname(reference$member_ll))
    )
    q_error <- max(abs(stan_q - unname(reference$q_member)))
    if (!is.null(parameter_draws$q_member)) {
      q_error <- max(q_error, abs(
        parameter_draws$q_member[index, ] - unname(reference$q_member)
      ))
    }
    result$q_error[[row]] <- q_error
    result$expected_richness_error[[row]] <- abs(
      core[index, "expected_richness"] - reference$expected_richness
    )
    result$camera_center_error[[row]] <- abs(sum(camera_effect))
    if (spatial) {
      result$interaction_center_error[[row]] <- max(
        abs(rowSums(interaction))
      )
      expected_station_log_rate <- outer(alpha, camera_effect, "+") + interaction
      result$station_log_rate_error[[row]] <- max(abs(
        matrix(
          parameter_draws$station_log_rate[index, , , drop = FALSE],
          nrow = C,
          ncol = J
        ) - expected_station_log_rate
      ))
    } else {
      result$interaction_center_error[[row]] <- 0
      result$station_log_rate_error[[row]] <- 0
    }
  }
  limits <- c(
    member_ll_error = 1e-8,
    q_error = 1e-8,
    expected_richness_error = 1e-7,
    camera_center_error = 1e-10,
    interaction_center_error = 1e-10,
    station_log_rate_error = 1e-10
  )
  maxima <- vapply(names(limits), function(name) max(result[[name]]), numeric(1))
  failed <- maxima > limits | !is.finite(maxima)
  if (any(failed)) {
    .goal010_fit_bridge_stop(paste0(
      "Goal010 Stan/R bridge failed: ",
      paste(sprintf("%s=%.6g", names(maxima)[failed], maxima[failed]),
            collapse = ", "),
      "."
    ))
  }
  result
}
