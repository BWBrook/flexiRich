if (!dir.exists("R") ||
    !file.exists(file.path("stan", "goal003_community_occupancy.stan"))) {
  stop("Run this script from the flexiRich repository root.", call. = FALSE)
}

for (path in sort(list.files(
  "R",
  pattern = "\\.R$",
  full.names = TRUE
))) {
  source(path, local = FALSE)
}
source(
  file.path("tests", "testthat", "helper-goal003-fixtures.R"),
  local = FALSE
)

source_data <- .goal003_baseline_fixture()
data <- prepare_goal003_occupancy_data(source_data)
model <- compile_goal003_occupancy_model()
source_hash <- digest::digest(
  file = file.path("stan", "goal003_community_occupancy.stan"),
  algo = "sha256",
  serialize = FALSE
)
run_dir <- file.path(
  "outputs",
  "goal003",
  "occupancy",
  "bridge",
  substr(source_hash, 1L, 16L)
)
unlink(run_dir, recursive = TRUE, force = TRUE)
dir.create(run_dir, recursive = TRUE, showWarnings = FALSE)

fit <- suppressMessages(model$sample(
  data = data$stan_data,
  seed = 3002L,
  chains = 1L,
  parallel_chains = 1L,
  iter_warmup = 200L,
  iter_sampling = 20L,
  refresh = 0L,
  sig_figs = 18L,
  show_messages = FALSE,
  output_dir = run_dir,
  output_basename = "bridge"
))
draws <- posterior::as_draws_matrix(fit$draws(
  variables = c(
    "psi", "rate", "q_site", "q_grid", "expected_grid_richness"
  )
))
C <- length(data$candidate_ids)
J <- length(data$camera_ids)
for (draw in seq_len(nrow(draws))) {
  reference <- goal003_occupancy_conditionals(
    data,
    draws[draw, sprintf("psi[%d]", seq_len(C))],
    draws[draw, sprintf("rate[%d]", seq_len(C))]
  )
  stan_q_site <- matrix(NA_real_, nrow = C, ncol = J)
  for (i in seq_len(C)) {
    for (j in seq_len(J)) {
      stan_q_site[i, j] <- draws[
        draw,
        sprintf("q_site[%d,%d]", i, j)
      ]
    }
  }
  stan_q_grid <- draws[
    draw,
    sprintf("q_grid[%d]", seq_len(C))
  ]
  if (max(abs(stan_q_site - reference$q_site)) > 1e-8 ||
      max(abs(stan_q_grid - reference$q_grid)) > 1e-8 ||
      abs(
        draws[draw, "expected_grid_richness"] - sum(reference$q_grid)
      ) > 1e-7) {
    stop(
      "Stan and R occupancy conditional quantities disagree.",
      call. = FALSE
    )
  }
}

mock_result <- list(
  terminal_status = "primary_clean",
  data = data,
  prior = goal003_occupancy_prior(),
  output_dir = normalizePath(run_dir, mustWork = TRUE),
  attempts = list(primary = list(fit = fit))
)
future_effort <- tidyr::expand_grid(
  camera_id = data$camera_ids,
  occasion_id = c("future_1", "future_2")
) |>
  dplyr::mutate(active_days = 7L)
prediction <- predict_goal003_occupancy(mock_result, future_effort)
if (abs(sum(prediction$richness_pmf$probability) - 1) > 1e-12 ||
    abs(sum(prediction$new_species_count_pmf$probability) - 1) > 1e-12 ||
    nrow(prediction$future_identity) != C) {
  stop("Occupancy posterior prediction bridge failed.", call. = FALSE)
}

cat("Goal003 occupancy Stan/R bridge: PASS\n")
