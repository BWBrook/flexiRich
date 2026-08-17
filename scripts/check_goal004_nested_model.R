if (!dir.exists("R") ||
    !file.exists(file.path("stan", "goal004_nested_flexirich.stan"))) {
  stop("Run this script from the flexiRich repository root.", call. = FALSE)
}

git_status <- system2(
  "git",
  c("status", "--porcelain"),
  stdout = TRUE,
  stderr = TRUE
)
if (length(git_status) > 0L) {
  stop("The nested-model check requires a clean worktree.", call. = FALSE)
}
git_commit <- system2(
  "git",
  c("rev-parse", "HEAD"),
  stdout = TRUE,
  stderr = TRUE
)
if (length(git_commit) != 1L || !grepl("^[0-9a-f]{40}$", git_commit)) {
  stop("Could not identify the committed nested source.", call. = FALSE)
}

for (path in sort(list.files("R", pattern = "[.]R$", full.names = TRUE))) {
  source(path, local = FALSE)
}

manifest <- read_goal004_task4_manifests()
simulation <- simulate_goal004_task4_dataset(
  manifest$datasets |>
    dplyr::filter(
      scenario_id == "aligned_mid",
      train_occasions == 4L,
      replicate == 8L
    ),
  manifest
)
data <- prepare_goal004_nested_data(simulation$training_data)
model <- compile_goal004_nested_model()
output <- file.path(
  "outputs",
  "goal004",
  "task4-nested-check",
  substr(git_commit, 1L, 12L)
)
if (dir.exists(output) || file.exists(output)) {
  stop("The committed nested-model check already exists.", call. = FALSE)
}
dir.create(output, recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(output, "bridge"))

bridge_fit <- suppressMessages(model$sample(
  data = data$stan_data,
  seed = 40061L,
  chains = 1L,
  parallel_chains = 1L,
  iter_warmup = 200L,
  iter_sampling = 20L,
  refresh = 0L,
  sig_figs = 18L,
  show_messages = FALSE,
  output_dir = file.path(output, "bridge"),
  output_basename = "bridge"
))
draws <- posterior::as_draws_matrix(bridge_fit$draws(
  variables = c(
    "expected_core_members", "expected_fringe_members",
    "omega_core", "omega_fringe", "alpha", "camera_effect",
    "member_ll", "q_core", "q_fringe", "expected_core_richness",
    "expected_fringe_richness", "expected_total_richness"
  )
))
C <- length(data$candidate_ids)
J <- length(data$camera_ids)
C_core <- length(data$core_ids)
C_fringe <- length(data$fringe_ids)
errors <- matrix(
  0,
  nrow = nrow(draws),
  ncol = 9L,
  dimnames = list(NULL, c(
    "member_ll", "q_core", "q_fringe", "core_richness",
    "fringe_richness", "total_richness", "camera_sum",
    "core_count_scale", "fringe_count_scale"
  ))
)
for (draw in seq_len(nrow(draws))) {
  alpha <- draws[draw, sprintf("alpha[%d]", seq_len(C))]
  camera <- draws[draw, sprintf("camera_effect[%d]", seq_len(J))]
  reference <- goal004_nested_conditionals(
    data,
    draws[draw, "expected_core_members"],
    draws[draw, "expected_fringe_members"],
    alpha,
    camera
  )
  stan_ll <- draws[draw, sprintf("member_ll[%d]", seq_len(C))]
  stan_core <- draws[draw, sprintf("q_core[%d]", seq_len(C_core))]
  stan_fringe <- draws[draw, sprintf("q_fringe[%d]", seq_len(C_fringe))]
  errors[draw, ] <- c(
    max(abs(stan_ll - reference$member_ll)),
    max(abs(stan_core - reference$q_core)),
    max(abs(stan_fringe - reference$q_fringe)),
    abs(draws[draw, "expected_core_richness"] -
      reference$expected_core_richness),
    abs(draws[draw, "expected_fringe_richness"] -
      reference$expected_fringe_richness),
    abs(draws[draw, "expected_total_richness"] -
      reference$expected_total_richness),
    abs(sum(camera)),
    abs(draws[draw, "expected_core_members"] -
      C_core * draws[draw, "omega_core"]),
    abs(draws[draw, "expected_fringe_members"] -
      C_fringe * draws[draw, "omega_fringe"])
  )
}
max_error <- apply(errors, 2L, max)
tolerance <- c(
  member_ll = 1e-8,
  q_core = 1e-8,
  q_fringe = 1e-8,
  core_richness = 1e-7,
  fringe_richness = 1e-7,
  total_richness = 1e-7,
  camera_sum = 1e-10,
  core_count_scale = 1e-12,
  fringe_count_scale = 1e-12
)
bridge_checks <- tibble::tibble(
  check = names(max_error),
  value = unname(max_error),
  threshold = unname(tolerance),
  passed = unname(max_error <= tolerance)
)
utils::write.csv(
  bridge_checks,
  file.path(output, "bridge-checks.csv"),
  row.names = FALSE
)
if (!all(bridge_checks$passed)) {
  stop("Goal004 nested Stan/R bridge failed.", call. = FALSE)
}

camera_ids <- sort(unique(manifest$effort$camera_id), method = "radix")
mapping <- goal004_task2_candidate_mapping()
zero_effort <- tidyr::expand_grid(
  camera_id = camera_ids,
  occasion_id = "zero_effort"
) |>
  dplyr::mutate(active_days = 0L)
zero_detection <- tidyr::expand_grid(
  species_id = mapping$core$candidate_id,
  camera_id = camera_ids,
  occasion_id = "zero_effort"
) |>
  dplyr::mutate(detected = NA_integer_)
zero_source <- prepare_flexirich_g_data(
  tibble::tibble(species_id = mapping$core$candidate_id),
  zero_effort,
  zero_detection
)
zero_data <- prepare_goal004_nested_data(zero_source)
profiles <- goal003_flexirich_sampler_profiles()
prior_attempt <- .goal003_model_attempt(
  model = model,
  stan_data = zero_data$stan_data,
  sampler_profile = profiles$primary,
  diagnostic_thresholds = goal003_flexirich_diagnostic_thresholds(),
  monitored_variables = .goal004_nested_monitored_variables(zero_data),
  seed = 40062L,
  output_dir = file.path(output, "prior"),
  attempt_id = "prior",
  refresh = 100L
)
if (!isTRUE(prior_attempt$diagnostics$clean)) {
  stop("Goal004 nested prior sampler was non-clean.", call. = FALSE)
}
prior_fit <- list(
  terminal_status = "primary_clean",
  data = zero_data,
  output_dir = file.path(output, "prior"),
  attempts = list(primary = prior_attempt)
)
prediction <- predict_goal004_nested(prior_fit)
summary <- posterior::summarise_draws(
  prior_attempt$fit$draws(
    variables = c("expected_core_members", "expected_fringe_members")
  ),
  "mean",
  "mcse_mean"
)
exact_core_mean <- 25
exact_fringe_mean <- 5 - 56 / expm1(56 / 5)
core_row <- summary[summary$variable == "expected_core_members", ]
fringe_row <- summary[summary$variable == "expected_fringe_members", ]
exact_core_pmf <- goal004_beta_binomial_pmf(50L, 1, 1)
exact_fringe_pmf <- goal004_nested_fringe_prior_pmf()
prior_checks <- tibble::tibble(
  check = c(
    "terminal_sampler_clean",
    "core_mean_within_four_mcse",
    "fringe_mean_within_four_mcse",
    "core_richness_total_variation",
    "fringe_richness_total_variation"
  ),
  value = c(
    1,
    abs(core_row$mean - exact_core_mean),
    abs(fringe_row$mean - exact_fringe_mean),
    goal004_total_variation(
      prediction$core_richness_pmf$probability,
      exact_core_pmf$probability
    ),
    goal004_total_variation(
      prediction$fringe_richness_pmf$probability,
      exact_fringe_pmf$probability
    )
  ),
  threshold = c(
    1,
    4 * core_row$mcse_mean,
    4 * fringe_row$mcse_mean,
    0.05,
    0.05
  ),
  passed = value <= threshold
)
utils::write.csv(
  prior_checks,
  file.path(output, "prior-concordance-checks.csv"),
  row.names = FALSE
)
utils::write.csv(
  prediction$core_richness_pmf,
  file.path(output, "prior-core-richness-pmf.csv"),
  row.names = FALSE
)
utils::write.csv(
  prediction$fringe_richness_pmf,
  file.path(output, "prior-fringe-richness-pmf.csv"),
  row.names = FALSE
)
if (!all(prior_checks$passed)) {
  stop("Goal004 nested prior concordance failed.", call. = FALSE)
}

writeLines(
  c(
    "status=NESTED_CHECK_PASS",
    paste0("git_commit=", git_commit),
    "bridge_seed=40061",
    "prior_seed=40062",
    "empirical_outcomes_used=false"
  ),
  file.path(output, "completion-status.txt")
)
cat("Goal004 nested Stan/R bridge and prior concordance: PASS\n")
print(bridge_checks)
print(prior_checks)
