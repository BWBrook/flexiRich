# Follow-up checks on Goals 009-012, run from the flexiRich repository root.
# Reads only compact tables already open for post-assessment development:
# Goal008 first-year incidence, Goal011 assessment-v3 later incidence, Goal012
# movement/effort calendar, frozen candidate pool. No raw observations, no Huon Ridge.
y1 <- read.csv("outputs/goal008/development-v1/detections_weekly.csv", stringsAsFactors = FALSE)
y2 <- read.csv("outputs/goal011/assessment-v3/future-detections-weekly.csv", stringsAsFactors = FALSE)
mv <- read.csv("outputs/goal012/timing-v2/movement-effort.csv", stringsAsFactors = FALSE)
pool <- read.csv("config/goal003_candidate_pool.csv", stringsAsFactors = FALSE)
y <- rbind(y1[, c("species_id", "camera_id", "occasion_id", "detected")], y2)
y <- merge(y, mv[, c("camera_id", "occasion_id", "occasion_index", "start_date", "segment",
                     "season", "active_days")], by = c("camera_id", "occasion_id"))
stopifnot(nrow(y) == 50 * 9 * 153)
y$taxon <- pool$taxon_class[match(y$species_id, pool$scientific_name)]
y$year <- cut(y$occasion_index, c(0, 52, 104, 153), labels = c("y1", "y2", "y3"))
pos <- y[!is.na(y$detected) & y$detected == 1, ]
eff <- unique(y[, c("camera_id", "occasion_index", "season", "year", "active_days")])

cat("1. Rare-species detections and camera placement segments\n")
key <- c("Perameles gunnii", "Dasyurus maculatus", "Canis familiaris", "Tribonyx mortierii",
         "Phaps elegans", "Malurus cyaneus", "Turdus merula", "Vombatus ursinus")
k <- pos[pos$species_id %in% key, c("species_id", "camera_id", "occasion_index", "start_date", "segment")]
print(k[order(k$species_id, k$occasion_index), ], row.names = FALSE)

cat("\n2. Active station-days by season and year\n")
print(xtabs(active_days ~ season + year, eff))
cat("\nBird positive cells per 1000 station-days, season by year\n")
print(round(1000 * xtabs(~ season + year, pos[pos$taxon == "Aves", ]) / xtabs(active_days ~ season + year, eff), 1))
cat("\nMammal positive cells per 1000 station-days, season by year\n")
print(round(1000 * xtabs(~ season + year, pos[pos$taxon == "Mammalia", ]) / xtabs(active_days ~ season + year, eff), 1))

cat("\n3. Positive cells per 1000 station-days at fixed versus moved nominal stations\n")
moved <- c("jc_co1", "jc_co3", "jc_pm14", "jc_pm34")
eff$grp <- ifelse(eff$camera_id %in% moved, "moved", "fixed")
pos$grp <- ifelse(pos$camera_id %in% moved, "moved", "fixed")
for (tx in c("Aves", "Mammalia")) {
  cat(tx, "\n")
  print(round(1000 * xtabs(~ grp + year, pos[pos$taxon == tx, ]) / xtabs(active_days ~ grp + year, eff), 1))
}

cat("\n4. Temporal association, Mantel-Haenszel odds ratios, full-effort weeks only,\n",
    "   species with at least 30 positive full-effort cells\n")
z <- y[!is.na(y$detected) & y$active_days == 7L, ]
tot <- tapply(z$detected, z$species_id, sum)
z <- z[z$species_id %in% names(tot)[tot >= 30], ]
z$key <- paste(z$species_id, z$camera_id, z$segment, sep = "|")
mh <- function(x1, x2, s) {
  a <- tapply(x1 & x2, s, sum); b <- tapply(x1 & !x2, s, sum)
  c <- tapply(!x1 & x2, s, sum); d <- tapply(!x1 & !x2, s, sum); n <- a + b + c + d
  sum(a * d / n) / sum(b * c / n)
}
lagOR <- function(dat, k) {
  idx <- split(seq_len(nrow(dat)), dat$key); x1 <- x2 <- logical(0); st <- character(0)
  for (s in names(idx)) {
    r <- idx[[s]]; o <- dat$occasion_index[r]; d <- dat$detected[r] == 1
    m <- match(o + k, o); kp <- !is.na(m)
    x1 <- c(x1, d[kp]); x2 <- c(x2, d[m[kp]]); st <- c(st, rep(s, sum(kp)))
  }
  mh(x1, x2, st)
}
lags <- c(1, 2, 4, 8, 13, 20, 26, 32, 39, 52, 65, 78, 104)
lagtab <- sapply(list(all = z, Aves = z[z$taxon == "Aves", ], Mammalia = z[z$taxon == "Mammalia", ]),
                 function(d) sapply(lags, function(k) lagOR(d, k)))
rownames(lagtab) <- lags
cat("Within species x station x placement segment, by lag in weeks\n"); print(round(lagtab, 2))

w <- reshape(z[, c("species_id", "occasion_index", "camera_id", "detected")],
             idvar = c("species_id", "occasion_index"), timevar = "camera_id", direction = "wide")
cams <- grep("^detected", names(w), value = TRUE)
pairOR <- function(lag) {
  w2 <- w; w2$occasion_index <- w2$occasion_index - lag
  ww <- merge(w, w2, by = c("species_id", "occasion_index"), suffixes = c(".a", ".b"))
  x1 <- x2 <- logical(0); st <- character(0)
  for (i in seq_along(cams)) for (j in seq_along(cams)) if (i < j || (lag > 0 && i != j)) {
    a <- ww[[paste0(cams[i], ".a")]]; b <- ww[[paste0(cams[j], ".b")]]; kp <- !is.na(a) & !is.na(b)
    x1 <- c(x1, a[kp] == 1); x2 <- c(x2, b[kp] == 1); st <- c(st, paste(ww$species_id[kp], i, j))
  }
  mh(x1, x2, st)
}
cat("\nSame species, different stations: same week OR", round(pairOR(0), 2),
    "; lag one week OR", round(pairOR(1), 2), "\n")
w3 <- reshape(z[, c("camera_id", "segment", "occasion_index", "species_id", "detected")],
              idvar = c("camera_id", "segment", "occasion_index"), timevar = "species_id", direction = "wide")
sp <- grep("^detected", names(w3), value = TRUE); x1 <- x2 <- logical(0); st <- character(0)
for (i in 1:(length(sp) - 1)) for (j in (i + 1):length(sp)) {
  kp <- !is.na(w3[[sp[i]]]) & !is.na(w3[[sp[j]]])
  x1 <- c(x1, w3[[sp[i]]][kp] == 1); x2 <- c(x2, w3[[sp[j]]][kp] == 1)
  st <- c(st, paste(w3$camera_id[kp], w3$segment[kp], i, j))
}
cat("Same station-week, different species OR", round(mh(x1, x2, st), 2), "\n")

cat("\n5. Year-one summer (DJF) station-days by camera\n")
print(xtabs(active_days ~ camera_id + year, eff[eff$season == "DJF", ]))

cat("\n6. Pooled mammal positive cells per 1000 station-days, station by 13-week block\n",
    "   (NA if fewer than 28 station-days); mammals serve as a common detectability reference\n")
y$q <- (y$occasion_index - 1) %/% 13 + 1
mm <- y[y$taxon == "Mammalia", ]
e6 <- unique(mm[, c("camera_id", "occasion_index", "q", "active_days")])
sd6 <- xtabs(active_days ~ camera_id + q, e6)
r6 <- round(1000 * xtabs(detected ~ camera_id + q, mm[!is.na(mm$detected), ]) / sd6); r6[sd6 < 28] <- NA
print(r6)
cat("Max/min block ratio per station:\n")
print(round(apply(r6, 1, function(v) max(v, na.rm = TRUE) / min(v, na.rm = TRUE)), 1))
cat("Placement changes: co1 new from occasion 20, pm14 new from 39, pm34 new from 108, co3 new from 131\n")
