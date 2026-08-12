if (!dir.exists("R") ||
    !file.exists(file.path("stan", "goal003_flexirich.stan"))) {
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
data <- prepare_goal003_flexirich_data(source_data)
model <- compile_goal003_flexirich_model()
source_hash <- digest::digest(
  file = file.path("stan", "goal003_flexirich.stan"),
  algo = "sha256",
  serialize = FALSE
)
run_dir <- file.path(
  "outputs",
  "goal003",
  "flexirich",
  "bridge",
  substr(source_hash, 1L, 16L)
)
unlink(run_dir, recursive = TRUE, force = TRUE)
dir.create(run_dir, recursive = TRUE, showWarnings = FALSE)

fit <- suppressMessages(model$sample(
  data = data$stan_data,
  seed = 30031L,
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
    "omega", "alpha", "camera_effect", "member_ll", "q_member",
    "expected_richness"
  )
))
C <- length(data$candidate_ids)
J <- length(data$camera_ids)
for (draw in seq_len(nrow(draws))) {
  alpha <- draws[draw, sprintf("alpha[%d]", seq_len(C))]
  camera_effect <- draws[
    draw,
    sprintf("camera_effect[%d]", seq_len(J))
  ]
  reference <- goal003_flexirich_conditionals(
    data,
    draws[draw, "omega"],
    alpha,
    camera_effect
  )
  stan_member_ll <- draws[draw, sprintf("member_ll[%d]", seq_len(C))]
  stan_q <- draws[draw, sprintf("q_member[%d]", seq_len(C))]
  if (abs(sum(camera_effect)) > 1e-10 ||
      max(abs(stan_member_ll - reference$member_ll)) > 1e-8 ||
      max(abs(stan_q - reference$q_member)) > 1e-8 ||
      abs(
        draws[draw, "expected_richness"] - reference$expected_richness
      ) > 1e-7) {
    stop(
      "Goal003 FlexiRich Stan transformed quantities disagree with R.",
      call. = FALSE
    )
  }
}

cat("Goal003 FlexiRich Stan/R bridge: PASS\n")
