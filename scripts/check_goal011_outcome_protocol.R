# Integration check using pinned protocol code and synthetic observations only.
options(warn = 2)
for (p in sort(list.files("R", pattern = "[.]R$", full.names = TRUE))) source(p)
source_root <- "/home/bwbrook/git/camtrap-workflow"
for (p in c("R/time_utils.R", "R/custom_funcs.R")) stopifnot(identical(
  digest::digest(file = file.path(source_root, p), algo = "sha256", serialize = FALSE),
  .goal003_judbury_sources[[p]]))
protocol <- new.env(parent = globalenv())
sys.source(file.path(source_root, "R/time_utils.R"), envir = protocol)
root <- getwd()
setwd(source_root)
tryCatch(sys.source(file.path(source_root, "R/custom_funcs.R"), envir = protocol),
         finally = setwd(root))
dates <- seq(as.Date("2019-06-05"), as.Date("2022-05-10"), by = "day")
op <- data.frame(date = format(dates, "%d/%m/%Y"), a = 1L)
obs <- data.frame(datetime = c("02/06/2020 23:59:00", "03/06/2020 00:01:00",
  "01/09/2020 23:59:00", "02/09/2020 00:01:00", "03/06/2020 00:05:00",
  "04/05/2022 00:00:00"), site = "a",
  species = c("old", "old", "horizon", "horizon", "new", "last"))
taxa <- data.frame(short = c("old", "horizon", "new", "last"), genus = "Test",
                   species = c("old", "horizon", "new", "last"))
pool <- data.frame(species_id = paste(taxa$genus, taxa$species))
z <- goal011_build_bounded_weekly(obs, op, taxa,
  data.frame(physical_location_id = "a", analysis_site_id = "cam_a"), pool, protocol)
effort <- z$weekly$effort_weekly |>
  dplyr::left_join(z$weekly$occasion_calendar[c("occasion_id", "occasion_index")], by = "occasion_id")
y <- goal011_build_outcomes(z$events, pool, effort, z$weekly$occasion_calendar)
stopifnot(nrow(z$events) == 4L,
  y$first52_outcomes$detected[y$first52_outcomes$species_id == "Test old"] == 1L,
  all(y$future_outcomes$detected[y$future_outcomes$species_id == "Test old"] == 0L),
  all(y$future_outcomes$detected[y$future_outcomes$species_id == "Test horizon"] == 1L),
  y$presence$occasion_index[y$presence$species_id == "Test horizon"] == 65L,
  y$presence$occasion_index[y$presence$species_id == "Test new"] == 53L,
  y$presence$occasion_index[y$presence$species_id == "Test last"] == 153L)
cat("Pinned-protocol synthetic event-start boundary checks passed; no real observations read.\n")
