# Cheap mathematical and prior-predictive checks for the fixed-array comparison.
goal010_theory_checks <- function(source_data) {
  data <- prepare_goal010_spatial_data(source_data)
  C <- length(data$candidate_ids); J <- length(data$camera_ids)
  alpha <- seq(-6, -2, length.out = C)
  camera <- seq(-0.4, 0.4, length.out = J); camera <- camera - mean(camera)
  interaction <- outer(sin(seq_len(C)), seq(-0.7, 0.7, length.out = J))
  interaction <- interaction - rowMeans(interaction)
  base <- goal003_flexirich_conditionals(
    prepare_goal003_flexirich_data(source_data), 0.6, alpha, camera)
  zero <- goal010_spatial_conditionals(data, 0.6, alpha, camera, matrix(0, C, J))
  full <- goal010_spatial_conditionals(data, 0.6, alpha, camera, interaction)
  # b and the across-species mean of u are not separately likelihood-identified.
  shift <- seq(-0.2, 0.2, length.out = J); shift <- shift - mean(shift)
  shifted <- goal010_spatial_conditionals(
    data, 0.6, alpha, camera + shift, sweep(interaction, 2L, shift, "-"))
  occasions <- source_data$occasion_ids
  parts <- lapply(list(head(occasions, floor(length(occasions)/2)),
                      tail(occasions, ceiling(length(occasions)/2))), function(ids) {
    obs <- source_data$observed[source_data$observed$occasion_id %in% ids, ]
    prepare_goal010_spatial_data(prepare_flexirich_g_data(
      data.frame(species_id = source_data$candidate_ids),
      unique(obs[c("camera_id", "occasion_id", "active_days")]),
      obs[c("species_id", "camera_id", "occasion_id", "detected")]
    ))
  })
  ll_parts <- lapply(parts, function(p)
    goal010_spatial_conditionals(p, 0.6, alpha, camera, interaction)$member_ll)
  H <- goal010_interaction_basis(J)
  errors <- c(
    zero_interaction_ll_error = max(abs(base$member_ll - zero$member_ll)),
    zero_interaction_membership_error = max(abs(base$q_member - zero$q_member)),
    persistent_period_ll_error = max(abs(full$member_ll - ll_parts[[1]] - ll_parts[[2]])),
    decomposition_shift_ll_error = max(abs(full$member_ll - shifted$member_ll)),
    finite_array_log_mean_error = max(abs(rowMeans(outer(alpha, camera, "+") + interaction) - alpha)),
    interaction_row_sum_error = max(abs(rowSums(interaction))),
    basis_sum_error = if (ncol(H)) max(abs(colSums(H))) else 0,
    basis_marginal_variance_error = if (J > 1) max(abs(rowSums(H^2) - 1)) else 0
  )
  stopifnot(all(is.finite(errors)), all(errors < 1e-10))
  data.frame(check = names(errors), absolute_error = unname(errors))
}

goal010_prior_predictive <- function(source_data, n_draws = 2000L, seed = 7300301L) {
  validate_flexirich_g_data(source_data)
  stopifnot(n_draws > 0, n_draws == as.integer(n_draws))
  C <- length(source_data$candidate_ids); J <- length(source_data$camera_ids)
  T <- length(source_data$occasion_ids)
  effort <- matrix(source_data$observed$active_days[seq_len(J*T)], J, T, byrow = TRUE)
  station_effort <- rowSums(effort)
  Q <- source_data$stan_data$Q
  H <- goal010_interaction_basis(J)
  profiles <- expand.grid(prior_id = c("primary", "tail_wide"),
                          interaction_scale = c(0, 0.5, 1), stringsAsFactors = FALSE)
  output <- vector("list", nrow(profiles))
  for (p in seq_len(nrow(profiles))) {
    profile <- profiles[p, ]; prior <- goal003_flexirich_prior_profiles()[[profile$prior_id]]
    # Common random numbers across profiles isolate prior changes; not independent trials.
    output[[p]] <- withr::with_seed(seed, {
      rows <- vector("list", n_draws)
      for (d in seq_len(n_draws)) {
        omega <- rbeta(1, prior$omega_alpha, prior$omega_beta)
        mu <- rnorm(1, prior$mu_alpha_location, prior$mu_alpha_scale)
        sigma <- abs(rnorm(1, 0, prior$sigma_alpha_scale))
        sigma_camera <- abs(rnorm(1, 0, prior$sigma_camera_scale))
        tau <- abs(rnorm(1, 0, 1)) * profile$interaction_scale
        alpha <- rnorm(C, mu, sigma)
        b <- as.numeric(sigma_camera * Q %*% rnorm(ncol(Q)))
        u <- tau * matrix(rnorm(C*ncol(H)), C, ncol(H)) %*% t(H)
        rates <- outer(alpha, b, "+") + u
        # Work on log hazards; no arithmetic rate means with heavy-tailed priors.
        terms <- sweep(rates, 2L, log(station_effort), "+")
        log_hazard <- apply(terms, 1L, function(x) {
          m <- max(x)
          if (is.infinite(m) && m < 0) return(-Inf)
          m + log(sum(exp(x-m)))
        })
        detect <- .goal009_detection_probability(log_hazard)
        member <- as.integer(runif(C) < omega)
        seen <- as.integer(runif(C) < member * detect)
        rows[[d]] <- data.frame(draw = d, prior_id = profile$prior_id,
          interaction_scale = profile$interaction_scale, sigma_interaction = tau,
          latent_richness = sum(member), detected_richness = sum(seen),
          unseen_members = sum(member) - sum(seen),
          mean_member_detection_probability = mean(detect),
          fraction_almost_invisible = mean(detect < 0.01),
          fraction_almost_certain = mean(detect > 0.99))
      }
      do.call(rbind, rows)
    }, .rng_kind = "Mersenne-Twister", .rng_normal_kind = "Inversion",
       .rng_sample_kind = "Rejection")
  }
  do.call(rbind, output)
}

# Two matched mechanism controls, not a coverage/calibration experiment.
goal010_synthetic_cases <- function(seed = 7300401L) {
  C <- 8L; J <- 4L; T <- 26L
  species <- sprintf("sp_%02d", seq_len(C))
  cameras <- sprintf("cam_%02d", seq_len(J))
  occasions <- sprintf("occ_%03d", seq_len(T))
  effort <- matrix(7L, J, T)
  effort[4, 7:10] <- 0L; effort[2, 13] <- 3L
  alpha <- log(c(0.08, 0.08, 0.035, 0.02, 0.003, 0.0008, 0.01, 0.01))
  b <- c(-0.3, 0.3, -0.1, 0.1)
  member <- c(rep(1L, 6), 0L, 0L)
  uniforms <- withr::with_seed(seed, array(runif(C*J*T), c(C,J,T)),
    .rng_kind = "Mersenne-Twister", .rng_normal_kind = "Inversion",
    .rng_sample_kind = "Rejection")
  effort_table <- expand.grid(camera_id=cameras, occasion_id=occasions,
                              stringsAsFactors=FALSE)
  effort_table$active_days <- as.vector(effort)
  labels <- data.frame(species_id=species, taxon_class="Mammalia", encounter_class="synthetic")
  results <- list()
  for (case in c("zero", "cross")) {
    u <- matrix(0, C, J)
    if (case == "cross") {
      u[1, ] <- c(1.5, -1.5, 0, 0)
      u[2, ] <- c(-1.5, 1.5, 0, 0)
    }
    y <- array(NA_integer_, c(C,J,T))
    for (t in seq_len(T)) for (j in seq_len(J)) for (i in seq_len(C)) {
      if (effort[j,t] > 0) {
        p <- -expm1(-effort[j,t]*exp(alpha[i]+b[j]+u[i,j]))
        y[i,j,t] <- as.integer(member[i] == 1L && uniforms[i,j,t] < p)
      }
    }
    observations <- expand.grid(species_id=species, camera_id=cameras,
      occasion_id=occasions, stringsAsFactors=FALSE)
    observations$detected <- as.vector(y)
    results[[case]] <- list(data=prepare_flexirich_g_data(
      data.frame(species_id=species), effort_table, observations), labels=labels,
      truth=list(alpha=alpha,camera_effect=b,interaction=u,membership=member,
                 richness=sum(member),seed=seed,
                 purpose="paired fixed mechanisms; no population variance truth or coverage claim"))
  }
  results
}
