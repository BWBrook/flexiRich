if (!dir.exists("R") || !file.exists("renv.lock")) {
  stop("Run this script from the flexiRich repository root.", call. = FALSE)
}

for (path in sort(list.files("R", pattern = "[.]R$", full.names = TRUE))) {
  source(path, local = FALSE)
}

output_dir <- file.path("outputs", "goal004", "task1-identifiability-v1")
if (dir.exists(output_dir) || file.exists(output_dir)) {
  stop("The Goal004 Task 1 output directory already exists.", call. = FALSE)
}

git_commit <- system2("git", c("rev-parse", "HEAD"), stdout = TRUE)
git_status <- system2("git", c("status", "--porcelain"), stdout = TRUE)
if (length(git_commit) != 1L || !grepl("^[0-9a-f]{40}$", git_commit)) {
  stop("Could not identify the committed Goal004 source.", call. = FALSE)
}
if (length(git_status) != 0L) {
  stop("Goal004 Task 1 requires a clean committed worktree.", call. = FALSE)
}

manifest <- read_goal003_task4_manifests()
effort_windows <- goal004_task1_effort_windows(manifest)
candidate_path <- file.path("config", "goal003_candidate_pool.csv")
design_path <- file.path(
  "docs",
  "goals",
  "004-pool-stable-membership",
  "Task1IdentifiabilityScreen.md"
)
candidate_pool <- tibble::as_tibble(utils::read.csv(
  candidate_path,
  stringsAsFactors = FALSE,
  check.names = FALSE
))
core_count <- sum(candidate_pool$primary_pool == "include")
broader_count <- sum(candidate_pool$broader_pool == "include")
fringe_count <- sum(
  candidate_pool$broader_pool == "include" &
    candidate_pool$primary_pool != "include"
)
valid_pool <- core_count == 50L && broader_count == 106L &&
  fringe_count == 56L &&
  all(candidate_pool$broader_pool[
    candidate_pool$primary_pool == "include"
  ] == "include")
if (!valid_pool) {
  stop("The reviewed Goal003 candidate-pool counts have changed.", call. = FALSE)
}

input_hashes <- c(
  candidate_pool = digest::digest(
    file = candidate_path,
    algo = "sha256",
    serialize = FALSE
  ),
  effort_template = manifest$hashes[["effort"]],
  task1_design = digest::digest(
    file = design_path,
    algo = "sha256",
    serialize = FALSE
  )
)

truth_memberships <- c(10, 25, 40)
truth_rate <- 0.002
rate_prior_ids <- names(goal004_task1_rate_priors())
fringe_prior_scales <- c(2, 5, 10)
fringe_rate_multipliers <- c(1, 0.1)
summary_rows <- list()
ridge_surfaces <- list()
row_index <- 0L

add_context <- function(value, window) {
  value |>
    dplyr::mutate(
      train_occasions = window$train_occasions,
      effort_label = window$effort_label,
      effort_replicate = window$replicate,
      effort_block_start = window$effort_block_start,
      active_camera_days = window$active_camera_days,
      sampled_cells = window$sampled_cells,
      .before = 1L
    )
}

for (window_index in seq_len(nrow(effort_windows$representatives))) {
  window <- effort_windows$representatives[window_index, ]
  effort <- manifest$effort |>
    dplyr::filter(
      occasion_index >= window$effort_block_start,
      occasion_index < window$effort_block_start + window$train_occasions
    ) |>
    dplyr::pull(active_days)

  for (truth_membership in truth_memberships) {
    for (rate_prior_id in rate_prior_ids) {
      primary <- goal004_task1_exchangeable_surface(
        candidate_count = core_count,
        truth_membership = truth_membership,
        truth_rate = truth_rate,
        effort = effort,
        rate_prior_id = rate_prior_id
      )
      row_index <- row_index + 1L
      summary_rows[[row_index]] <- add_context(primary$summary, window)

      broader <- goal004_task1_exchangeable_surface(
        candidate_count = broader_count,
        truth_membership = truth_membership,
        truth_rate = truth_rate,
        effort = effort,
        rate_prior_id = rate_prior_id
      )
      row_index <- row_index + 1L
      summary_rows[[row_index]] <- add_context(broader$summary, window)

      if (identical(window$effort_label, "lower_median") &&
          truth_membership == 25 &&
          identical(rate_prior_id, "centred_broad")) {
        ridge_surfaces[[as.character(window$train_occasions)]] <- list(
          surface = primary,
          window = window
        )
      }

      for (fringe_prior_scale in fringe_prior_scales) {
        for (fringe_rate_multiplier in fringe_rate_multipliers) {
          stratified <- goal004_task1_stratified_surface(
            truth_membership = truth_membership,
            truth_rate = truth_rate,
            effort = effort,
            rate_prior_id = rate_prior_id,
            fringe_prior_scale = fringe_prior_scale,
            fringe_rate_multiplier = fringe_rate_multiplier,
            core_count = core_count,
            fringe_count = fringe_count
          )
          row_index <- row_index + 1L
          summary_rows[[row_index]] <- add_context(
            stratified$summary,
            window
          )
        }
      }
    }
  }
}

summary_table <- dplyr::bind_rows(summary_rows) |>
  dplyr::arrange(
    train_occasions,
    match(effort_label, c("minimum", "lower_median", "maximum")),
    truth_membership,
    match(rate_prior_id, rate_prior_ids),
    model,
    candidate_count,
    fringe_prior_scale,
    dplyr::desc(fringe_rate_multiplier)
  )

summary_table <- goal004_task1_add_pool_shifts(
  summary_table,
  core_candidate_count = core_count
)

decision <- goal004_task1_decision(summary_table)
if (nrow(summary_table) != 432L ||
    length(ridge_surfaces) != 2L ||
    nrow(decision$metrics) != 6L) {
  stop("The Goal004 Task 1 result grid is incomplete.", call. = FALSE)
}

core_sensitivity <- summary_table |>
  dplyr::filter(
    model == "exchangeable",
    candidate_count == .env$core_count
  ) |>
  dplyr::group_by(train_occasions, effort_label, rate_prior_id) |>
  dplyr::summarise(
    high_low_mean_separation =
      posterior_membership_mean[truth_membership == 40] -
      posterior_membership_mean[truth_membership == 10],
    mean_crps_improvement = mean(crps_improvement),
    minimum_crps_improvement = min(crps_improvement),
    maximum_profile_membership_span = max(profile_membership_span),
    maximum_profile_rate_ratio = max(profile_rate_ratio),
    .groups = "drop"
  )
exchangeable_pool_sensitivity <- summary_table |>
  dplyr::filter(
    model == "exchangeable",
    candidate_count == .env$broader_count
  ) |>
  dplyr::group_by(train_occasions, effort_label, rate_prior_id) |>
  dplyr::summarise(
    maximum_total_shift = max(abs(total_shift_vs_primary50)),
    median_total_shift = stats::median(total_shift_vs_primary50),
    .groups = "drop"
  )
stratified_sensitivity <- summary_table |>
  dplyr::filter(model == "core_fringe") |>
  dplyr::group_by(
    train_occasions,
    effort_label,
    rate_prior_id,
    fringe_prior_scale,
    fringe_rate_multiplier
  ) |>
  dplyr::summarise(
    maximum_core_shift = max(abs(core_shift_vs_primary50)),
    maximum_total_shift = max(abs(total_shift_vs_primary50)),
    minimum_fringe_mean_reduction = min(fringe_mean_reduction),
    minimum_fringe_crps_improvement = min(fringe_crps_improvement),
    .groups = "drop"
  )

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
utils::write.csv(
  effort_windows$audit,
  file.path(output_dir, "effort-window-audit.csv"),
  row.names = FALSE,
  na = ""
)
utils::write.csv(
  summary_table,
  file.path(output_dir, "surface-summaries.csv"),
  row.names = FALSE,
  na = ""
)
utils::write.csv(
  decision$metrics,
  file.path(output_dir, "decision-metrics.csv"),
  row.names = FALSE,
  na = ""
)
utils::write.csv(
  decision$broad_rows,
  file.path(output_dir, "broad-checkpoint-rows.csv"),
  row.names = FALSE,
  na = ""
)
utils::write.csv(
  core_sensitivity,
  file.path(output_dir, "core-sensitivity.csv"),
  row.names = FALSE,
  na = ""
)
utils::write.csv(
  exchangeable_pool_sensitivity,
  file.path(output_dir, "exchangeable-pool-sensitivity.csv"),
  row.names = FALSE,
  na = ""
)
utils::write.csv(
  stratified_sensitivity,
  file.path(output_dir, "stratified-sensitivity.csv"),
  row.names = FALSE,
  na = ""
)

grDevices::png(
  file.path(output_dir, "likelihood-ridge.png"),
  width = 1800,
  height = 850,
  res = 180
)
graphics::par(mfrow = c(1, 2), mar = c(4.5, 4.5, 3.2, 1.2))
colours <- grDevices::hcl.colors(40L, "YlOrRd", rev = TRUE)
for (duration in c("4", "26")) {
  item <- ridge_surfaces[[duration]]
  surface <- item$surface
  relative <- pmax(surface$relative_log_likelihood, -20)
  graphics::image(
    x = log10(exp(surface$log_rate)),
    y = surface$membership,
    z = t(relative),
    col = colours,
    xlab = expression(log[10] * " encounter rate"),
    ylab = "Expected core membership R",
    main = sprintf(
      "%s weeks; %s active camera-days",
      duration,
      item$window$active_camera_days
    )
  )
  graphics::contour(
    x = log10(exp(surface$log_rate)),
    y = surface$membership,
    z = t(surface$relative_log_likelihood),
    levels = c(-10, -5, -2),
    add = TRUE,
    drawlabels = TRUE,
    lwd = 1.2
  )
  graphics::points(log10(truth_rate), 25, pch = 4, lwd = 2, cex = 1.2)
}
grDevices::dev.off()

metadata <- tibble::tibble(
  field = c(
    "analysis_id",
    "status",
    "git_commit",
    "r_version",
    "candidate_pool_sha256",
    "effort_template_sha256",
    "task1_design_sha256",
    "core_candidate_count",
    "fringe_candidate_count",
    "broader_candidate_count",
    "surface_count",
    "empirical_outcomes_used"
  ),
  value = c(
    "goal004-task1-identifiability-v1",
    decision$status,
    git_commit,
    R.version.string,
    input_hashes[["candidate_pool"]],
    input_hashes[["effort_template"]],
    input_hashes[["task1_design"]],
    core_count,
    fringe_count,
    broader_count,
    nrow(summary_table),
    "false"
  )
)
utils::write.csv(
  metadata,
  file.path(output_dir, "metadata.csv"),
  row.names = FALSE,
  na = ""
)

metric_lines <- sprintf(
  "%s=%s (required %s %s; pass=%s)",
  decision$metrics$metric,
  format(decision$metrics$observed, digits = 8),
  decision$metrics$comparison,
  format(decision$metrics$threshold, digits = 8),
  tolower(decision$metrics$pass)
)
completion <- c(
  paste0("status=", decision$status),
  paste0("git_commit=", git_commit),
  "empirical_outcomes_used=false",
  metric_lines
)
writeLines(completion, file.path(output_dir, "completion-status.txt"))
cat("Goal004 Task 1 identifiability screen: ", decision$status, "\n", sep = "")
