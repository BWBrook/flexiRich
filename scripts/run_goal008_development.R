if (!dir.exists("R") || !file.exists(file.path("config", "goal003_candidate_pool.csv"))) {
  stop("Run this script from the flexiRich repository root.", call. = FALSE)
}

for (path in sort(list.files("R", pattern = "[.]R$", full.names = TRUE))) {
  source(path, local = FALSE)
}

# Exercise the pinned parser and the half-open local-date boundary before any
# observation bytes are read by the development adapter.
protocol <- new.env(parent = globalenv())
source_root <- "/home/bwbrook/git/camtrap-workflow"
sys.source(file.path(source_root, "R", "time_utils.R"), envir = protocol)
sentinels <- data.frame(
  datetime = c(
    "4/06/2019 23:59:59",
    "5/06/2019 00:00:00",
    "2/06/2020 23:59:59",
    "3/06/2020 00:00:00",
    "3/06/2020 09:59:59"
  ),
  stringsAsFactors = FALSE
)
sentinel_result <- goal008_filter_early_observations(
  sentinels,
  protocol$parse_datetime_local
)
if (!identical(nrow(sentinel_result), 2L)) {
  stop("Goal008 fixed UTC+10 boundary preflight failed.", call. = FALSE)
}

arguments <- commandArgs(trailingOnly = TRUE)
output_dir <- if (length(arguments) >= 1L) arguments[[1L]] else
  file.path("outputs", "goal008", "development-v1")
run_goal008_development(output_dir = output_dir, source_root = source_root)
