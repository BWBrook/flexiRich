#!/usr/bin/env Rscript
# Summarise frozen Goal011 predictive objects and completed assessment tables.
#
# This postprocessor reads only forecast artifacts and score tables.  It never
# reads raw observations or reconstructs outcomes.  The default synthesis path
# is write-once so that a reviewed summary cannot be silently replaced.

options(warn = 2)

fail <- function(...) stop(paste0(...), call. = FALSE)

need_file <- function(path, what) {
  if (!file.exists(path) || dir.exists(path)) fail("Missing ", what, ": ", path)
  path
}

read_csv_checked <- function(path, what) {
  tryCatch(
    utils::read.csv(need_file(path, what), stringsAsFactors = FALSE,
                    check.names = FALSE),
    error = function(e) fail("Could not read ", what, ": ", conditionMessage(e))
  )
}

require_columns <- function(x, columns, what) {
  if (!is.data.frame(x) || !all(columns %in% names(x))) {
    fail(what, " is missing required columns: ",
         paste(setdiff(columns, names(x)), collapse = ", "))
  }
  x
}

assert_finite <- function(x, what, allow_infinite = FALSE) {
  if (!is.numeric(x) || anyNA(x) || any(is.nan(x)) ||
      (!allow_infinite && any(!is.finite(x)))) {
    fail(what, " contains invalid numeric values.")
  }
  x
}

goal011_target_kind <- function(target) {
  x <- tolower(gsub("[^a-z0-9]", "", target))
  if (x %in% c("totaldiscovery", "discovery", "additionaldiscovery")) {
    return("additional_discovery")
  }
  if (x %in% c("redetection", "totalredetection")) return("known_redetection")
  if (x %in% c("alldetection", "totaldetection", "totalfuturedetection")) {
    return("all_detection")
  }
  if (grepl("discovery.*taxon|taxon.*discovery", x)) {
    return("discovery_taxon_class")
  }
  if (grepl("discovery.*encounter|encounter.*discovery", x)) {
    return("discovery_encounter_class")
  }
  NA_character_
}

discrete_quantile <- function(count, probability, level) {
  count[which(cumsum(probability) >= level)[[1L]]]
}

summarise_pmfs <- function(pmfs, model_id, role, horizons) {
  required <- c("target", "group", "horizon", "count", "probability",
                "log_probability")
  require_columns(pmfs, required, paste0(model_id, " count PMFs"))
  if (!is.character(pmfs$target) || !is.character(pmfs$group) ||
      anyNA(pmfs$target) || anyNA(pmfs$group) ||
      anyDuplicated(pmfs[c("target", "group", "horizon", "count")])) {
    fail(model_id, " count PMFs have invalid target keys.")
  }
  for (column in c("horizon", "count", "probability", "log_probability")) {
    assert_finite(pmfs[[column]], paste0(model_id, " count PMFs$", column),
                  allow_infinite = column == "log_probability")
  }
  if (any(pmfs$horizon != trunc(pmfs$horizon)) ||
      any(!pmfs$horizon %in% horizons) ||
      any(pmfs$count != trunc(pmfs$count)) || any(pmfs$count < 0) ||
      any(pmfs$probability < 0 | pmfs$probability > 1) ||
      any(pmfs$log_probability > 0)) {
    fail(model_id, " count PMFs contain values outside their frozen ranges.")
  }
  keys <- unique(pmfs[c("target", "group", "horizon")])
  rows <- lapply(seq_len(nrow(keys)), function(i) {
    key <- keys[i, , drop = FALSE]
    x <- pmfs[pmfs$target == key$target[[1L]] &
                pmfs$group == key$group[[1L]] &
                pmfs$horizon == key$horizon[[1L]], , drop = FALSE]
    x <- x[order(x$count), , drop = FALSE]
    expected_count <- seq.int(0L, nrow(x) - 1L)
    if (!identical(as.integer(x$count), expected_count) ||
        !isTRUE(all.equal(sum(x$probability), 1, tolerance = 1e-8))) {
      fail(model_id, " count PMF is not consecutive and normalized for ",
           key$target[[1L]], "/", key$group[[1L]], "/", key$horizon[[1L]], ".")
    }
    # A displayed probability may underflow or round at subnormal magnitudes
    # while its saved stable log-probability remains accurate.  The saved logs
    # are retained for scoring; do not reconstruct them from display values.
    data.frame(
      model_id = model_id,
      role = role,
      target = key$target[[1L]],
      group = key$group[[1L]],
      target_kind = goal011_target_kind(key$target[[1L]]),
      horizon = as.integer(key$horizon[[1L]]),
      predicted_mean = sum(x$count * x$probability),
      pmf_median = discrete_quantile(x$count, x$probability, .5),
      central90_lower = discrete_quantile(x$count, x$probability, .05),
      central90_upper = discrete_quantile(x$count, x$probability, .95),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  if (anyNA(out$target_kind)) fail(model_id, " contains an unsupported PMF target.")
  out[order(out$target_kind, out$group, out$horizon), , drop = FALSE]
}

check_species_probabilities <- function(x, model_id, horizons) {
  required <- c("species_id", "known_member", "horizon", "detection_probability",
                "discovery_probability", "log_detection_probability",
                "log_nondetection_probability")
  require_columns(x, required, paste0(model_id, " species probabilities"))
  if (!is.character(x$species_id) || anyNA(x$species_id) ||
      anyDuplicated(x[c("species_id", "horizon")]) ||
      any(!x$known_member %in% c(0, 1)) ||
      any(!x$horizon %in% horizons)) {
    fail(model_id, " species probabilities have invalid identities or horizons.")
  }
  for (column in c("detection_probability", "discovery_probability")) {
    assert_finite(x[[column]], paste0(model_id, " species probabilities$", column))
    if (any(x[[column]] < 0 | x[[column]] > 1)) {
      fail(model_id, " species probabilities are outside [0, 1].")
    }
  }
  for (column in c("log_detection_probability", "log_nondetection_probability")) {
    assert_finite(x[[column]], paste0(model_id, " species probabilities$", column),
                  allow_infinite = TRUE)
    if (any(x[[column]] > 0)) fail(model_id, " ", column, " contains positive logs.")
  }
  invisible(x)
}

check_paths <- function(x, model_id, horizons) {
  required <- c("draw_index", "horizon", "totaldiscovery", "redetection",
                "all_detection")
  require_columns(x, required, paste0(model_id, " joint paths"))
  for (column in required) assert_finite(x[[column]], paste0(model_id, " joint paths$", column))
  if (any(x$horizon != trunc(x$horizon)) || !all(x$horizon %in% horizons) ||
      any(x$draw_index != trunc(x$draw_index)) ||
      any(x$totaldiscovery + x$redetection != x$all_detection)) {
    fail(model_id, " joint paths have invalid horizons or count decomposition.")
  }
  counts <- table(x$horizon)
  if (length(counts) != length(horizons) || any(counts != counts[[1L]])) {
    fail(model_id, " joint paths do not contain the same draw count per horizon.")
  }
  invisible(x)
}

read_assessment_file <- function(assessment_dir, filename, what) {
  read_csv_checked(file.path(assessment_dir, filename), what)
}

build_plot <- function(summary, paths, observed, out_dir) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    fail("ggplot2 is required to render the Goal011 synthesis figure.")
  }
  main <- summary[summary$model_id %in% c("baseline_primary", "spatial_primary") &
                    summary$target_kind %in% c("additional_discovery", "known_redetection") &
                    summary$group == "all", , drop = FALSE]
  main$event_type <- factor(main$target_kind,
                            levels = c("additional_discovery", "known_redetection"),
                            labels = c("Additional discovery", "Known redetection"))
  main$model <- factor(main$model_id,
                       levels = c("baseline_primary", "spatial_primary"),
                       labels = c("Baseline primary", "Spatial primary"))
  main$observed_count <- observed$observed_count[match(
    paste(main$model_id, main$target_kind, main$horizon),
    paste(observed$model_id, observed$target_kind, observed$horizon)
  )]
  if (anyNA(main$observed_count)) fail("Assessment count scores lack plot observations.")

  path_rows <- lapply(c("baseline_primary", "spatial_primary"), function(id) {
    x <- paths[[id]]
    ids <- sort(unique(x$draw_index), method = "radix")
    selected <- ids[unique(round(seq(1, length(ids), length.out = min(20L, length(ids)))))]
    x <- x[x$draw_index %in% selected,
           c("draw_index", "horizon", "totaldiscovery", "redetection")]
    discovery <- data.frame(
      draw_index = x$draw_index, horizon = x$horizon,
      count = x$totaldiscovery, target_kind = "additional_discovery",
      model_id = id, stringsAsFactors = FALSE
    )
    redetection <- data.frame(
      draw_index = x$draw_index, horizon = x$horizon,
      count = x$redetection, target_kind = "known_redetection",
      model_id = id, stringsAsFactors = FALSE
    )
    rbind(discovery, redetection)
  })
  path_rows <- do.call(rbind, path_rows)
  path_rows$event_type <- factor(path_rows$target_kind,
                                 levels = c("additional_discovery", "known_redetection"),
                                 labels = c("Additional discovery", "Known redetection"))
  path_rows$model <- factor(path_rows$model_id,
                            levels = c("baseline_primary", "spatial_primary"),
                            labels = c("Baseline primary", "Spatial primary"))
  path_rows$path_id <- interaction(path_rows$model_id, path_rows$draw_index,
                                   drop = TRUE, lex.order = TRUE)

  p <- ggplot2::ggplot(main, ggplot2::aes(x = horizon)) +
    ggplot2::geom_line(
      ggplot2::aes(y = predicted_mean), colour = "#0072B2", linewidth = .7
    ) +
    ggplot2::geom_linerange(
      ggplot2::aes(ymin = central90_lower, ymax = central90_upper),
      colour = "#0072B2", linewidth = 1.2
    ) +
    ggplot2::geom_point(
      ggplot2::aes(y = pmf_median), colour = "#0072B2", shape = 18, size = 2.6
    ) +
    ggplot2::geom_line(
      data = path_rows,
      ggplot2::aes(x = horizon, y = count, group = path_id),
      inherit.aes = FALSE, colour = "#777777", alpha = .16, linewidth = .35
    ) +
    ggplot2::geom_point(
      ggplot2::aes(y = observed_count), colour = "#D55E00", shape = 4,
      stroke = 1.1, size = 3
    ) +
    ggplot2::facet_grid(event_type ~ model) +
    ggplot2::scale_x_continuous(breaks = sort(unique(main$horizon))) +
    ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = c(0, .08))) +
    ggplot2::labs(
      x = "Cumulative future weeks",
      y = "Detected candidates",
      title = "Goal011 cumulative detection forecasts",
      subtitle = "Blue line: PMF mean; diamonds: PMF median; orange crosses: observed count",
      caption = "Vertical ranges are pointwise central 90% PMF intervals. Grey lines are 20 evenly selected coherent joint paths.") +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      strip.text = ggplot2::element_text(face = "bold"),
      plot.title = ggplot2::element_text(face = "bold"),
      legend.position = "none"
    )
  ggplot2::ggsave(file.path(out_dir, "goal011-count-forecasts.png"), p,
                  width = 11, height = 8, units = "in", dpi = 220)
  ggplot2::ggsave(file.path(out_dir, "goal011-count-forecasts.pdf"), p,
                  width = 11, height = 8, units = "in", device = grDevices::cairo_pdf)
}

main <- function(
  assessment_dir = "outputs/goal011/assessment-v3",
  forecast_dir = "outputs/goal011/forecast-v1",
  out_dir = "outputs/goal011/synthesis-v1"
) {
  if (file.exists(out_dir) || dir.exists(out_dir)) {
    fail("Refusing to overwrite existing synthesis path: ", out_dir)
  }
  need_file(file.path(forecast_dir, "model-manifest.csv"), "model manifest")
  need_file(file.path(forecast_dir, "model-status.csv"), "model status")
  need_file(file.path(forecast_dir, "horizons.csv"), "forecast horizons")
  if (!dir.exists(assessment_dir)) fail("Missing assessment directory: ", assessment_dir)

  horizons_table <- read_csv_checked(file.path(forecast_dir, "horizons.csv"), "forecast horizons")
  require_columns(horizons_table, c("future_week", "occasion_index"), "forecast horizons")
  horizons <- as.integer(horizons_table$future_week)
  if (!identical(horizons, c(13L, 26L, 52L, 101L))) {
    fail("Goal011 horizons are not the frozen 13/26/52/101 sequence.")
  }
  manifest <- read_csv_checked(file.path(forecast_dir, "model-manifest.csv"), "model manifest")
  require_columns(manifest, c("model_id", "role"), "model manifest")
  expected_models <- c("baseline_primary", "spatial_primary", "baseline_wide",
                       "spatial_wide_interaction", "spatial_wide_tail", "spatial_both_wide")
  if (anyDuplicated(manifest$model_id) || !identical(sort(manifest$model_id), sort(expected_models)) ||
      any(!manifest$role %in% c("main", "sensitivity"))) {
    fail("Goal011 model manifest is incomplete or malformed.")
  }
  status <- read_csv_checked(file.path(forecast_dir, "model-status.csv"), "model status")
  require_columns(status, c("model_id", "status"), "model status")
  if (any(status$status != "predictions_complete_unscored")) {
    fail("Goal011 forecast status is not predictions_complete_unscored for every model.")
  }

  count_scores <- read_assessment_file(
    assessment_dir, "count-scores.csv", "count scores"
  )
  aggregate_scores <- read_assessment_file(
    assessment_dir, "aggregate-species-scores.csv", "aggregate species scores"
  )
  species_scores <- read_assessment_file(
    assessment_dir, "species-scores.csv", "species scores"
  )
  first_discoveries <- read_assessment_file(
    assessment_dir, "first-discoveries.csv", "first discoveries"
  )
  require_columns(count_scores, c("model_id", "role", "target", "group", "horizon",
                                  "observed_count", "negative_log_score"), "count scores")
  require_columns(aggregate_scores, c("model_id", "role", "group", "horizon",
                                      "mean_brier_score", "mean_negative_log_score"),
                  "aggregate species scores")
  require_columns(species_scores, c("model_id", "role", "species_id", "horizon"),
                  "species scores")
  require_columns(first_discoveries, c("species_id", "first_occasion", "first_date"),
                  "first discoveries")
  if (any(!count_scores$model_id %in% expected_models) ||
      any(!aggregate_scores$model_id %in% expected_models) ||
      any(!species_scores$model_id %in% expected_models)) {
    fail("Assessment tables contain an unknown model ID.")
  }
  role_key <- setNames(manifest$role, manifest$model_id)
  if (any(count_scores$role != unname(role_key[count_scores$model_id])) ||
      any(aggregate_scores$role != unname(role_key[aggregate_scores$model_id])) ||
      any(species_scores$role != unname(role_key[species_scores$model_id]))) {
    fail("Assessment table roles do not match the frozen model manifest.")
  }
  if (anyDuplicated(count_scores[c("model_id", "target", "group", "horizon")])) {
    fail("Count scores contain duplicate model-target-horizon rows.")
  }
  if (any(count_scores$horizon != trunc(count_scores$horizon)) ||
      any(!count_scores$horizon %in% horizons)) fail("Count scores contain invalid horizons.")
  if (any(!is.finite(count_scores$observed_count)) ||
      any(count_scores$observed_count < 0 | count_scores$observed_count != trunc(count_scores$observed_count))) {
    fail("Count scores contain invalid observed counts.")
  }

  summaries <- list(); paths <- list(); receipts <- character()
  for (i in seq_len(nrow(manifest))) {
    id <- manifest$model_id[[i]]
    role <- manifest$role[[i]]
    model_dir <- file.path(forecast_dir, id)
    pmf_path <- file.path(model_dir, "count-pmfs.csv")
    species_path <- file.path(model_dir, "species-probabilities.csv")
    paths_path <- file.path(model_dir, "joint-count-paths.csv")
    pmfs <- read_csv_checked(pmf_path, paste0(id, " count PMFs"))
    species <- read_csv_checked(species_path, paste0(id, " species probabilities"))
    path_table <- read_csv_checked(paths_path, paste0(id, " joint paths"))
    summaries[[id]] <- summarise_pmfs(pmfs, id, role, horizons)
    check_species_probabilities(species, id, horizons)
    check_paths(path_table, id, horizons)
    paths[[id]] <- path_table
    receipts <- c(receipts, pmf_path, species_path, paths_path)
  }
  count_comparison <- do.call(rbind, summaries)
  score_key <- paste(count_scores$model_id, count_scores$target,
                     count_scores$group, count_scores$horizon)
  summary_key <- paste(count_comparison$model_id, count_comparison$target,
                       count_comparison$group, count_comparison$horizon)
  if (!all(summary_key %in% score_key)) fail("Assessment count scores do not cover every frozen PMF.")
  matched <- count_scores[match(summary_key, score_key), c(
    "observed_count", "negative_log_score", "pmf_median", "central90_lower",
    "central90_upper", "containment_descriptive"
  ), drop = FALSE]
  names(matched) <- c("observed_count", "negative_log_score", "scored_pmf_median",
                      "scored_central90_lower", "scored_central90_upper",
                      "containment_descriptive")
  count_comparison <- cbind(count_comparison, matched)
  aggregate_scores <- aggregate_scores[order(aggregate_scores$model_id,
                                             aggregate_scores$group,
                                             aggregate_scores$horizon), , drop = FALSE]
  count_comparison <- count_comparison[order(count_comparison$model_id,
                                             count_comparison$target_kind,
                                             count_comparison$group,
                                             count_comparison$horizon), , drop = FALSE]

  focal <- count_comparison[count_comparison$role == "main" &
                              count_comparison$target_kind == "additional_discovery" &
                              count_comparison$group == "all" & count_comparison$horizon == 101L &
                              count_comparison$model_id %in% c("baseline_primary", "spatial_primary"), ]
  if (nrow(focal) != 2L) fail("Could not resolve the frozen 101-week focal contrast.")
  focal <- focal[match(c("baseline_primary", "spatial_primary"), focal$model_id), ]
  contrast <- focal$negative_log_score[[2L]] - focal$negative_log_score[[1L]]
  focal_out <- data.frame(
    contrast = "spatial_minus_baseline_discovery_count_NLS_at101weeks",
    baseline_primary = focal$negative_log_score[[1L]],
    spatial_primary = focal$negative_log_score[[2L]],
    value = contrast,
    stringsAsFactors = FALSE
  )

  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(out_dir)) fail("Could not create synthesis path: ", out_dir)
  utils::write.csv(count_comparison, file.path(out_dir, "count-comparison.csv"), row.names = FALSE)
  utils::write.csv(aggregate_scores, file.path(out_dir, "aggregate-species-scores.csv"), row.names = FALSE)
  utils::write.csv(focal_out, file.path(out_dir, "focal-contrast.csv"), row.names = FALSE)
  input_paths <- c(file.path(forecast_dir, "model-manifest.csv"),
                   file.path(forecast_dir, "model-status.csv"),
                   file.path(forecast_dir, "horizons.csv"), receipts,
                   file.path(assessment_dir, "count-scores.csv"),
                   file.path(assessment_dir, "aggregate-species-scores.csv"),
                   file.path(assessment_dir, "species-scores.csv"),
                   file.path(assessment_dir, "first-discoveries.csv"))
  input_paths <- input_paths[file.exists(input_paths)]
  utils::write.csv(data.frame(
    path = input_paths,
    sha256 = vapply(input_paths, digest::digest, character(1), file = TRUE,
                    algo = "sha256", serialize = FALSE),
    stringsAsFactors = FALSE
  ), file.path(out_dir, "input-receipts.csv"), row.names = FALSE)
  observed_plot <- count_comparison[count_comparison$target_kind %in%
                                      c("additional_discovery", "known_redetection") &
                                      count_comparison$group == "all", ]
  build_plot(count_comparison, paths, observed_plot, out_dir)
  invisible(list(count_comparison = count_comparison,
                 aggregate_species_scores = aggregate_scores,
                 focal_contrast = focal_out))
}

args <- commandArgs(trailingOnly = TRUE)
if (length(args) > 3L) {
  fail("Usage: Rscript scripts/summarise_goal011_assessment.R [assessment_dir] [forecast_dir] [synthesis_dir]")
}
assessment_dir <- if (length(args) >= 1L) args[[1L]] else "outputs/goal011/assessment-v3"
forecast_dir <- if (length(args) >= 2L) args[[2L]] else "outputs/goal011/forecast-v1"
out_dir <- if (length(args) >= 3L) args[[3L]] else "outputs/goal011/synthesis-v1"
main(assessment_dir, forecast_dir, out_dir)
