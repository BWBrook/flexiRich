#!/usr/bin/env Rscript
# Render the completed conditional summaries without rerunning randomisations.
suppressPackageStartupMessages(library(ggplot2))
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) <= 2L)
input <- if (length(args)) args[1] else "outputs/goal012/timing-v2"
dest <- if (length(args) == 2L) args[2] else "outputs/goal012/synthesis-v1"
if (file.exists(dest)) stop("Refusing to overwrite an existing figure directory.")
source_path <- file.path(input, "conditional-summary.csv")
hash <- function(p) digest::digest(file = p, algo = "sha256", serialize = FALSE)
receipt <- read.csv(file.path(input, "output-sha256.csv"))
stopifnot(hash(source_path) == receipt$sha256[receipt$path == "conditional-summary.csv"])
x <- read.csv(source_path)
x <- x[x$statistic == "switches_all", ]
keys <- c("movement_block13", "movement_season", "movement", "nominal_static")
labels <- c("Movement periods + 13-week blocks", "Movement periods + recurring seasons",
            "Movement periods", "Nominal stations")
stopifnot(setequal(x$control, keys), length(unique(x$observed)) == 1L)
x$control <- factor(x$control, levels = keys, labels = labels)
observed <- unique(x$observed)
p <- ggplot(x, aes(exact_mean, control)) +
  geom_vline(xintercept = observed, colour = "#b44334", linewidth = .8) +
  geom_segment(aes(x = q05, xend = q95, yend = control),
    linewidth = 1.2, colour = "#25566b") +
  geom_point(size = 3, colour = "#25566b") +
  annotate("text", x = observed, y = 4.5,
    label = paste0("Observed: ", format(observed, big.mark = ",")),
    colour = "#b44334", size = 3.5) +
  coord_cartesian(ylim = c(.6, 4.7), xlim = c(2800, 4050)) +
  scale_x_continuous(breaks = seq(2800, 4000, 200)) +
  labs(x = "Switches between detection and nondetection in adjacent sampled weeks", y = NULL,
    title = "Judbury detections remain clustered after temporal conditioning",
    subtitle = "The same 27,846 eligible pairs are compared under every control",
    caption = "Dots: exact conditional means. Bars: central 90% ranges from 1,999 randomisations per control.\nPost-assessment model criticism; these are not ecological confidence intervals.") +
  theme_minimal(base_size = 11) + theme(panel.grid.major.y = element_blank(),
    panel.grid.minor = element_blank(), plot.caption = element_text(hjust = 0))
dir.create(dest, recursive = TRUE)
ggsave(file.path(dest, "conditional-timing.png"), p, width = 11, height = 4.6, dpi = 170)
ggsave(file.path(dest, "conditional-timing.pdf"), p, width = 11, height = 4.6)
write.csv(data.frame(path = c(source_path, "scripts/plot_goal012_summary.R"),
  sha256 = vapply(c(source_path, "scripts/plot_goal012_summary.R"), hash, "")),
  file.path(dest, "source-receipts.csv"), row.names = FALSE)
