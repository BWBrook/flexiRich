.goal002r_validate_fit <- function(fit) {
  if (!is.list(fit) ||
      !identical(class(fit), c("flexirich_g_collapsed_fit", "list")) ||
      !is.matrix(fit$draws) || nrow(fit$draws) == 0L) {
    .goal002r_stop("fit must be a non-empty flexirich_g_collapsed_fit object.")
  }
  required <- c("q_unseen", "S_grid", "expected_richness")
  if (!all(required %in% colnames(fit$draws))) {
    .goal002r_stop("fit draws do not contain the richness variables.")
  }
  TRUE
}

goal002r_summarise_fit <- function(fit) {
  if (exists("goal002r_validate_fit_health", mode = "function")) {
    goal002r_validate_fit_health(fit)
  } else {
    .goal002r_validate_fit(fit)
  }
  data <- fit$data
  draws <- fit$draws
  candidate_pool_size <- length(data$candidate_ids)
  observed_richness <- length(data$detected_ids)
  pmf <- goal002r_richness_pmf(
    draws[, "q_unseen"],
    observed_richness = observed_richness,
    candidate_pool_size = candidate_pool_size
  )
  summary <- goal002r_richness_summary(pmf)
  membership <- tibble::tibble(
    species_id = data$candidate_ids,
    detected = data$candidate_ids %in% data$detected_ids,
    probability = c(
      rep(1, length(data$detected_ids)),
      rep(mean(draws[, "q_unseen"]), length(data$unseen_ids))
    )
  )
  membership <- membership[match(
    data$candidate_ids,
    membership$species_id
  ), , drop = FALSE]
  result <- list(
    richness = c(
      summary,
      list(
        observed = as.integer(observed_richness),
        candidate_pool = as.integer(candidate_pool_size),
        pmf = pmf
      )
    ),
    membership = membership,
    effects = list(
      mu_alpha = stats::setNames(
        c(mean(draws[, "mu_alpha"]), stats::sd(draws[, "mu_alpha"])),
        c("mean", "sd")
      ),
      sigma_alpha = stats::setNames(
        c(mean(draws[, "sigma_alpha"]), stats::sd(draws[, "sigma_alpha"])),
        c("mean", "sd")
      )
    ),
    diagnostics = list(
      draws = nrow(draws),
      sampler_health = fit$health,
      q_unseen = c(
        mean = mean(draws[, "q_unseen"]),
        sd = stats::sd(draws[, "q_unseen"]),
        min = min(draws[, "q_unseen"]),
        max = max(draws[, "q_unseen"])
      )
    ),
    metadata = list(
      seed = fit$seed,
      quadrature_order = fit$quadrature_order,
      model_source_hash = fit$model_source_hash,
      data_hash = data$data_hash
    )
  )
  class(result) <- c("flexirich_g_collapsed_summary", "list")
  result
}

validate_goal002r_summary <- function(summary) {
  if (!is.list(summary) ||
      !identical(class(summary), c("flexirich_g_collapsed_summary", "list")) ||
      !is.list(summary$richness) ||
      !tibble::is_tibble(summary$richness$pmf)) {
    .goal002r_stop("summary is not a valid Goal002R summary.")
  }
  pmf <- summary$richness$pmf
  if (!identical(names(pmf), c("richness", "probability")) ||
      anyNA(pmf$probability) || any(pmf$probability < 0) ||
      abs(sum(pmf$probability) - 1) > 1e-12 ||
      any(pmf$richness != trunc(pmf$richness))) {
    .goal002r_stop("summary richness PMF violates support or normalisation.")
  }
  TRUE
}
