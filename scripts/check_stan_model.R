if (!dir.exists("R") ||
    !file.exists(file.path("stan", "flexirich_g.stan"))) {
  stop(
    "Run this script from the flexiRich repository root.",
    call. = FALSE
  )
}

for (path in sort(list.files(
  "R",
  pattern = "\\.R$",
  full.names = TRUE
))) {
  source(path, local = FALSE)
}
source(
  file.path("tests", "testthat", "helper-goal002-oracles.R"),
  local = FALSE
)

cmdstan_status <- check_goal002_cmdstan()
if (!isTRUE(cmdstan_status$matches)) {
  stop("The frozen CmdStan contract was not satisfied.", call. = FALSE)
}

stan_source <- file.path("stan", "flexirich_g.stan")
source_hash <- digest::digest(
  file = stan_source,
  algo = "sha256",
  serialize = FALSE
)
hash_prefix <- substr(source_hash, 1L, 16L)

output_root <- file.path("outputs", "goal002", "cmdstan")
copied_source_dir <- file.path(
  output_root,
  "source",
  hash_prefix
)
binary_dir <- file.path(output_root, "bin")
run_dir <- file.path(output_root, "bridge", hash_prefix)
dir.create(copied_source_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(binary_dir, recursive = TRUE, showWarnings = FALSE)

copied_source <- file.path(copied_source_dir, "flexirich_g.stan")
copy_required <- !file.exists(copied_source)
if (!copy_required) {
  copied_hash <- digest::digest(
    file = copied_source,
    algo = "sha256",
    serialize = FALSE
  )
  copy_required <- !identical(copied_hash, source_hash)
}
if (copy_required &&
    !file.copy(stan_source, copied_source, overwrite = TRUE)) {
  stop("Could not copy the Stan source beneath outputs/goal002/.", call. = FALSE)
}
if (!identical(
  digest::digest(
    file = copied_source,
    algo = "sha256",
    serialize = FALSE
  ),
  source_hash
)) {
  stop("The copied Stan source does not match its source hash.", call. = FALSE)
}

executable <- file.path(
  binary_dir,
  paste0("flexirich_g-", hash_prefix)
)
model <- cmdstanr::cmdstan_model(
  stan_file = copied_source,
  exe_file = executable,
  compile = FALSE
)
model$compile(
  quiet = TRUE,
  force_recompile = !file.exists(executable)
)
if (!file.exists(executable) ||
    !identical(
      normalizePath(model$exe_file(), mustWork = TRUE),
      normalizePath(executable, mustWork = TRUE)
    )) {
  stop(
    "CmdStanR did not compile to the required hash-specific executable.",
    call. = FALSE
  )
}

fixture <- goal002_oracle_fixture(C = 4L)
prior <- validate_goal002_profile(
  goal002_prior_profiles()$primary,
  type = "prior"
)
stan_data <- c(
  fixture$data$stan_data,
  prior[setdiff(names(prior), "profile_id")]
)

if (dir.exists(run_dir)) {
  unlink(run_dir, recursive = TRUE, force = TRUE)
}
dir.create(run_dir, recursive = TRUE, showWarnings = FALSE)

data_file <- file.path(run_dir, "data.json")
init_file <- file.path(run_dir, "init.json")
cmdstanr::write_stan_json(stan_data, data_file)
cmdstanr::write_stan_json(
  list(
    omega = 0.6,
    mu_alpha = log(0.01),
    sigma_alpha = 0.8,
    z_alpha = c(1.2, 0.3, -0.8, -1.4),
    sigma_camera = 0.2,
    z_camera = array(0, dim = fixture$data$stan_data$B)
  ),
  init_file
)

fit <- suppressMessages(model$sample(
  data = data_file,
  seed = 2505L,
  chains = 1L,
  parallel_chains = 1L,
  iter_warmup = 250L,
  iter_sampling = 20L,
  refresh = 0L,
  init = init_file,
  adapt_delta = 0.95,
  max_treedepth = 12L,
  sig_figs = 18L,
  diagnostics = c("divergences", "treedepth"),
  show_messages = FALSE,
  output_dir = run_dir,
  output_basename = paste0("bridge-", hash_prefix)
))

diagnostics <- fit$diagnostic_summary(
  diagnostics = c("divergences", "treedepth"),
  quiet = TRUE
)
if (sum(diagnostics$num_divergent) > 0L ||
    sum(diagnostics$num_max_treedepth) > 0L) {
  stop(
    "The deterministic bridge run had divergent or max-treedepth transitions.",
    call. = FALSE
  )
}

draws <- posterior::as_draws_matrix(fit$draws(
  variables = c(
    "omega",
    "alpha",
    "camera_effect",
    "member_ll",
    "q_member",
    "g_member",
    "S_grid",
    "expected_richness",
    "y_rep"
  )
))
if (nrow(draws) != 20L) {
  stop("The deterministic bridge must contain exactly 20 draws.", call. = FALSE)
}

indexed_names <- function(variable, size) {
  sprintf("%s[%d]", variable, seq_len(size))
}

C <- fixture$data$stan_data$C
J <- fixture$data$stan_data$J
G <- fixture$data$stan_data$G
alpha_names <- indexed_names("alpha", C)
camera_names <- indexed_names("camera_effect", J)
member_names <- indexed_names("member_ll", C)
q_names <- indexed_names("q_member", C)
g_names <- indexed_names("g_member", C)
y_rep_names <- indexed_names("y_rep", G)

required_columns <- c(
  "omega",
  alpha_names,
  camera_names,
  member_names,
  q_names,
  g_names,
  "S_grid",
  "expected_richness",
  y_rep_names
)
missing_columns <- setdiff(required_columns, colnames(draws))
if (length(missing_columns) > 0L) {
  stop(
    "Stan draws are missing variables: ",
    paste(missing_columns, collapse = ", "),
    ".",
    call. = FALSE
  )
}

stan_member <- draws[, member_names, drop = FALSE]
stan_q <- draws[, q_names, drop = FALSE]
stan_g <- draws[, g_names, drop = FALSE]
stan_y_rep <- draws[, y_rep_names, drop = FALSE]

for (draw in seq_len(nrow(draws))) {
  expected_member <- member_log_likelihood(
    fixture$data,
    draws[draw, alpha_names],
    draws[draw, camera_names]
  )
  expected_q <- conditional_membership_probability(
    expected_member,
    fixture$data$stan_data$detected_ever,
    draws[draw, "omega"]
  )

  if (any(abs(stan_member[draw, ] - expected_member) > 1e-8)) {
    stop(
      "Stan and R member log likelihoods differ by more than 1e-8.",
      call. = FALSE
    )
  }
  if (any(abs(stan_q[draw, ] - expected_q) > 1e-8)) {
    stop(
      "Stan and R membership probabilities differ by more than 1e-8.",
      call. = FALSE
    )
  }
}

camera_sums <- rowSums(draws[, camera_names, drop = FALSE])
if (any(abs(camera_sums) > 1e-10)) {
  stop("Transformed camera effects are not sum-zero.", call. = FALSE)
}

detected <- fixture$data$stan_data$detected_ever == 1L
if (any(stan_q[, detected, drop = FALSE] != 1) ||
    any(stan_g[, detected, drop = FALSE] != 1)) {
  stop("Detected species must have q_member = g_member = 1.", call. = FALSE)
}
if (any(stan_q < 0 | stan_q > 1) ||
    any(stan_g < 0 | stan_g > 1) ||
    any(stan_g != round(stan_g))) {
  stop("Generated membership draws are outside their support.", call. = FALSE)
}

S_grid <- draws[, "S_grid"]
expected_richness <- draws[, "expected_richness"]
if (any(S_grid != rowSums(stan_g)) ||
    any(S_grid < sum(detected) | S_grid > C) ||
    any(S_grid != round(S_grid)) ||
    any(abs(expected_richness - rowSums(stan_q)) > 1e-8) ||
    any(expected_richness < sum(detected) | expected_richness > C)) {
  stop("Generated richness draws are outside their support.", call. = FALSE)
}

trial_limits <- matrix(
  fixture$data$stan_data$n_trials,
  nrow = nrow(stan_y_rep),
  ncol = G,
  byrow = TRUE
)
if (any(stan_y_rep < 0) ||
    any(stan_y_rep > trial_limits) ||
    any(stan_y_rep != round(stan_y_rep))) {
  stop("Generated replicated counts are outside group bounds.", call. = FALSE)
}
for (draw in seq_len(nrow(draws))) {
  absent_group <- stan_g[
    draw,
    fixture$data$stan_data$species_index
  ] == 0
  if (any(stan_y_rep[draw, absent_group] != 0)) {
    stop(
      "Non-member species generated a replicated detection.",
      call. = FALSE
    )
  }
}

source_artifacts <- c(
  file.path("stan", "flexirich_g"),
  file.path("stan", "flexirich_g.hpp"),
  file.path("stan", "flexirich_g.o"),
  file.path("stan", "flexirich_g.d")
)
if (any(file.exists(source_artifacts))) {
  stop(
    "Compilation artefacts were written beside the tracked Stan source.",
    call. = FALSE
  )
}

cat("Goal 002 Stan bridge: PASS\n")
