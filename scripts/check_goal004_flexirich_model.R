if (!dir.exists("R") ||
    !file.exists(file.path("stan", "goal004_flexirich.stan"))) {
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
encounter_class <- stats::setNames(
  rep(c("routine", "occasional"), length.out = length(source_data$candidate_ids)),
  source_data$candidate_ids
)
data <- prepare_goal004_flexirich_data(
  source_data,
  encounter_class,
  profile_id = "class_blur"
)
model <- compile_goal004_flexirich_model()
source_hash <- digest::digest(
  file = file.path("stan", "goal004_flexirich.stan"),
  algo = "sha256",
  serialize = FALSE
)
run_dir <- file.path(
  "outputs",
  "goal004",
  "flexirich",
  "bridge",
  substr(source_hash, 1L, 16L)
)
unlink(run_dir, recursive = TRUE, force = TRUE)
dir.create(run_dir, recursive = TRUE, showWarnings = FALSE)

fit <- suppressMessages(model$sample(
  data = data$stan_data,
  seed = 40051L,
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
    "expected_core_members", "omega", "alpha", "camera_effect",
    "member_ll", "q_member", "expected_richness"
  )
))
C <- length(data$candidate_ids)
J <- length(data$camera_ids)
errors <- matrix(
  0,
  nrow = nrow(draws),
  ncol = 5L,
  dimnames = list(NULL, c(
    "member_ll", "q_member", "expected_richness", "camera_sum",
    "count_scale"
  ))
)
for (draw in seq_len(nrow(draws))) {
  alpha <- draws[draw, sprintf("alpha[%d]", seq_len(C))]
  camera_effect <- draws[
    draw,
    sprintf("camera_effect[%d]", seq_len(J))
  ]
  reference <- goal004_flexirich_conditionals(
    data,
    draws[draw, "expected_core_members"],
    alpha,
    camera_effect
  )
  stan_member_ll <- draws[draw, sprintf("member_ll[%d]", seq_len(C))]
  stan_q <- draws[draw, sprintf("q_member[%d]", seq_len(C))]
  errors[draw, ] <- c(
    max(abs(stan_member_ll - reference$member_ll)),
    max(abs(stan_q - reference$q_member)),
    abs(draws[draw, "expected_richness"] - reference$expected_richness),
    abs(sum(camera_effect)),
    abs(
      draws[draw, "expected_core_members"] -
        C * draws[draw, "omega"]
    )
  )
}
max_error <- apply(errors, 2L, max)
tolerance <- c(
  member_ll = 1e-8,
  q_member = 1e-8,
  expected_richness = 1e-7,
  camera_sum = 1e-10,
  count_scale = 1e-12
)
if (any(max_error > tolerance)) {
  stop(
    paste0(
      "Goal004 Stan/R bridge failed: ",
      paste(
        sprintf("%s=%.3g", names(max_error), max_error),
        collapse = ", "
      )
    ),
    call. = FALSE
  )
}

cat("Goal004 FlexiRich Stan/R bridge: PASS\n")
cat(paste(
  sprintf("%s=%.3g", names(max_error), max_error),
  collapse = "\n"
), "\n", sep = "")
