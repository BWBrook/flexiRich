# Goal 001 Minimum Viable Simulator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a reproducible R simulator that generates known grid-level species richness, daily camera operation, seven-day effort, heterogeneous encounter rates, binary detection histories, and a complete latent-truth record.

**Architecture:** Use a small function-oriented R project rather than committing prematurely to a public package API. A validated configuration feeds separate latent-community and effort generators; `simulate_flexirich_g()` joins those components, applies the effort-aware encounter-hazard observation model, and returns a classed list of tidy tables. Tests exercise each component independently before an illustrated Quarto run closes the Goal 001 acceptance gate.

**Tech Stack:** R 4.6.1, `renv`, `testthat`, `tibble`, `dplyr`, `tidyr`, `withr`, `ggplot2`, Quarto.

## Global Constraints

- The candidate universe is finite and known.
- The estimand is whole-grid detectable-use richness.
- Primary observations are binary detections; independent-event counts are excluded.
- Sampling occasions are exactly seven days in Goal 001.
- Effort is active camera-days and zero-effort observations are missing, not sampled non-detections.
- The baseline species and camera effects are Gaussian on the log encounter-rate scale.
- Exactly `true_richness` members are selected uniformly without replacement, independently of encounter effects and effort.
- Caller-supplied effort must be a complete day-resolved binary camera-date table; occasion totals are always derived internally.
- The default illustrated design has 30 candidates, 20 true members, nine cameras, and 208 seven-day occasions.
- Goal 001 contains no inferential estimator, empirical Judbury fit, ALA query, site-level richness, or Huon Ridge data.
- Core simulation functions must not mutate the caller's global random-number state.
- No generated outputs, local `renv` library, private paths, or external camera data are committed.
- Stop after the Goal 001 acceptance checks and one focused repair pass.

---

## Planned File Structure

| Path | Responsibility |
|---|---|
| `.gitignore` | Exclude local R, `renv`, Quarto and generated-output state |
| `.Rprofile` | Activate the project-local `renv` environment |
| `README.md` | Minimal bootstrap, test and render commands |
| `flexiRich.Rproj` | R project settings |
| `bootstrap_env.R` | Restore the committed `renv` environment |
| `renv.lock` | Reproducible R dependency lock |
| `renv/activate.R` | Committed `renv` activation script |
| `renv/settings.json` | Committed project `renv` settings |
| `R/sim_config.R` | Configuration constructor and validation |
| `R/sim_effort.R` | Daily Markov operation histories and seven-day aggregation |
| `R/sim_flexirich_g.R` | Latent community, encounter rates and binary observations |
| `R/sim_summary.R` | Object validation, summaries, printing and discovery curves |
| `scripts/run_tests.R` | One-command unit-test runner |
| `tests/testthat/helper-load.R` | Deterministically source project functions |
| `tests/testthat/test-sim-config.R` | Configuration tests |
| `tests/testthat/test-sim-effort.R` | Effort-generation tests |
| `tests/testthat/test-sim-flexirich-g.R` | Generative-model and truth-contract tests |
| `tests/testthat/test-sim-summary.R` | Validation and summary tests |
| `analysis/goal001_simulator.qmd` | Illustrated Judbury-shaped scenario |
| `docs/goals/001-minimum-viable-simulator/Log.md` | Goal chronology, commands and acceptance evidence |

---

### Task 1: Establish the reproducible R project and validated configuration

**Files:**
- Create: `.gitignore`
- Generate: `.Rprofile`
- Create: `README.md`
- Create: `flexiRich.Rproj`
- Create: `bootstrap_env.R`
- Create: `R/sim_config.R`
- Create: `scripts/run_tests.R`
- Create: `tests/testthat/helper-load.R`
- Create: `tests/testthat/test-sim-config.R`
- Generate: `renv.lock`
- Generate: `renv/activate.R`
- Generate: `renv/settings.json`

**Interfaces:**
- Produces: `flexirich_sim_config(...) -> flexirich_sim_config`
- Produces: `validate_sim_config(config) -> config` or an informative error
- Establishes the project test and dependency commands used by all later tasks.

- [ ] **Step 1: Add the failing configuration tests**

```r
# tests/testthat/helper-load.R
for (path in sort(list.files("R", pattern = "\\.R$", full.names = TRUE))) {
  source(path, local = FALSE)
}
```

```r
# tests/testthat/test-sim-config.R
testthat::test_that("default configuration is Judbury-shaped and valid", {
  config <- flexirich_sim_config(seed = 42L)

  testthat::expect_s3_class(config, "flexirich_sim_config")
  testthat::expect_identical(config$candidate_pool_size, 30L)
  testthat::expect_identical(config$true_richness, 20L)
  testthat::expect_identical(config$n_cameras, 9L)
  testthat::expect_identical(config$n_occasions, 208L)
  testthat::expect_identical(config$occasion_days, 7L)
  testthat::expect_identical(config$seed, 42L)
})

testthat::test_that("configuration rejects impossible values", {
  testthat::expect_error(
    flexirich_sim_config(candidate_pool_size = 10L, true_richness = 11L),
    "true_richness"
  )
  testthat::expect_error(
    flexirich_sim_config(occasion_days = 14L),
    "occasion_days must equal 7"
  )
  testthat::expect_error(
    flexirich_sim_config(daily_failure_prob = 1.1),
    "daily_failure_prob"
  )
  testthat::expect_error(
    flexirich_sim_config(sd_log_rate = -0.1),
    "sd_log_rate"
  )
})
```

- [ ] **Step 2: Run the focused test and confirm the expected failure**

Run:

```bash
Rscript -e 'source("tests/testthat/helper-load.R"); testthat::test_file("tests/testthat/test-sim-config.R")'
```

Expected: failure because `flexirich_sim_config()` does not yet exist.

- [ ] **Step 3: Implement the configuration contract**

```r
# R/sim_config.R
.assert_scalar_integer <- function(x, name, lower, upper = Inf) {
  valid <- length(x) == 1L && !is.na(x) && is.numeric(x) &&
    x == as.integer(x) && x >= lower && x <= upper
  if (!valid) {
    stop(name, " must be one integer in [", lower, ", ", upper, "].", call. = FALSE)
  }
  as.integer(x)
}

.assert_scalar_numeric <- function(x, name, lower = -Inf, upper = Inf) {
  valid <- length(x) == 1L && !is.na(x) && is.numeric(x) &&
    is.finite(x) && x >= lower && x <= upper
  if (!valid) {
    stop(name, " must be one finite number in [", lower, ", ", upper, "].", call. = FALSE)
  }
  as.numeric(x)
}

validate_sim_config <- function(config) {
  if (!is.list(config)) {
    stop("config must be a list.", call. = FALSE)
  }

  config$candidate_pool_size <- .assert_scalar_integer(
    config$candidate_pool_size, "candidate_pool_size", 1L
  )
  config$true_richness <- .assert_scalar_integer(
    config$true_richness, "true_richness", 0L, config$candidate_pool_size
  )
  config$n_cameras <- .assert_scalar_integer(config$n_cameras, "n_cameras", 1L)
  config$n_occasions <- .assert_scalar_integer(config$n_occasions, "n_occasions", 1L)
  config$occasion_days <- .assert_scalar_integer(config$occasion_days, "occasion_days", 1L)
  if (config$occasion_days != 7L) {
    stop("occasion_days must equal 7 in Goal 001.", call. = FALSE)
  }

  if (!inherits(config$start_date, "Date") || length(config$start_date) != 1L ||
      is.na(config$start_date)) {
    stop("start_date must be one non-missing Date.", call. = FALSE)
  }

  config$mean_log_rate <- .assert_scalar_numeric(config$mean_log_rate, "mean_log_rate")
  config$sd_log_rate <- .assert_scalar_numeric(config$sd_log_rate, "sd_log_rate", 0)
  config$sd_camera <- .assert_scalar_numeric(config$sd_camera, "sd_camera", 0)
  config$initial_operating_prob <- .assert_scalar_numeric(
    config$initial_operating_prob, "initial_operating_prob", 0, 1
  )
  config$daily_failure_prob <- .assert_scalar_numeric(
    config$daily_failure_prob, "daily_failure_prob", 0, 1
  )
  config$daily_repair_prob <- .assert_scalar_numeric(
    config$daily_repair_prob, "daily_repair_prob", 0, 1
  )
  config$seed <- .assert_scalar_integer(
    config$seed, "seed", 0L, .Machine$integer.max - 1000L
  )

  class(config) <- c("flexirich_sim_config", "list")
  config
}

flexirich_sim_config <- function(
  candidate_pool_size = 30L,
  true_richness = 20L,
  n_cameras = 9L,
  n_occasions = 208L,
  occasion_days = 7L,
  start_date = as.Date("2019-06-01"),
  mean_log_rate = log(5e-4),
  sd_log_rate = 1.25,
  sd_camera = 0.35,
  initial_operating_prob = 1,
  daily_failure_prob = 0.002,
  daily_repair_prob = 0.1,
  seed = 1L
) {
  validate_sim_config(list(
    candidate_pool_size = candidate_pool_size,
    true_richness = true_richness,
    n_cameras = n_cameras,
    n_occasions = n_occasions,
    occasion_days = occasion_days,
    start_date = start_date,
    mean_log_rate = mean_log_rate,
    sd_log_rate = sd_log_rate,
    sd_camera = sd_camera,
    initial_operating_prob = initial_operating_prob,
    daily_failure_prob = daily_failure_prob,
    daily_repair_prob = daily_repair_prob,
    seed = seed
  ))
}
```

- [ ] **Step 4: Add the project harness**

```gitignore
# .gitignore
.Rproj.user/
.Rhistory
.RData
.Ruserdata
renv/library/
renv/staging/
outputs/
.quarto/
```

```text
# flexiRich.Rproj
Version: 1.0

RestoreWorkspace: No
SaveWorkspace: No
AlwaysSaveHistory: No

EnableCodeIndexing: Yes
UseSpacesForTab: Yes
NumSpacesForTab: 2
Encoding: UTF-8
RnwWeave: knitr
LaTeX: pdfLaTeX
```

```r
# bootstrap_env.R
if (!requireNamespace("renv", quietly = TRUE)) {
  install.packages("renv", repos = "https://cloud.r-project.org")
}
renv::restore(prompt = FALSE)
```

```r
# scripts/run_tests.R
status <- testthat::test_dir(
  "tests/testthat",
  reporter = "summary",
  stop_on_failure = TRUE,
  stop_on_warning = TRUE
)
invisible(status)
```

````markdown
<!-- README.md -->
# flexiRich

Research implementation and validation of an effort-aware estimator of
camera-detectable species richness from a finite candidate pool.

## Goal 001

```sh
Rscript bootstrap_env.R
Rscript scripts/run_tests.R
quarto render analysis/goal001_simulator.qmd --output-dir outputs/goal001
```

Generated artefacts are written under `outputs/` and are not committed.
Huon Ridge data and locations are outside this repository.
````

- [ ] **Step 5: Initialise and lock the minimal environment**

Run:

```bash
Rscript -e 'renv::init(bare = TRUE); renv::install(c("testthat", "tibble", "dplyr", "tidyr", "withr", "ggplot2", "knitr", "rmarkdown")); renv::snapshot(prompt = FALSE)'
```

Expected: `renv.lock` records R 4.6.1 and the listed direct dependencies.

- [ ] **Step 6: Run the configuration tests**

Run:

```bash
Rscript scripts/run_tests.R
```

Expected: all configuration tests pass with no warnings.

- [ ] **Step 7: Commit the independently testable configuration tranche**

```bash
git add .gitignore .Rprofile README.md flexiRich.Rproj bootstrap_env.R renv.lock renv/activate.R renv/settings.json R/sim_config.R scripts/run_tests.R tests/testthat/helper-load.R tests/testthat/test-sim-config.R
git commit -m "feat: establish Goal 001 simulation config"
```

---

### Task 2: Generate daily operation and aggregate exact seven-day effort

**Files:**
- Create: `R/sim_effort.R`
- Create: `tests/testthat/test-sim-effort.R`

**Interfaces:**
- Consumes: `flexirich_sim_config`
- Produces: `simulate_daily_effort(config) -> tibble(camera_id, date, operating)`
- Produces: `validate_daily_effort(effort_daily, config) -> validated tibble`
- Produces: `aggregate_weekly_effort(effort_daily, config) -> tibble(camera_id, occasion_id, occasion_start, occasion_end, active_days)`

- [ ] **Step 1: Add failing effort tests**

```r
# tests/testthat/test-sim-effort.R
testthat::test_that("daily effort has complete camera-date coverage", {
  config <- flexirich_sim_config(n_cameras = 3L, n_occasions = 4L, seed = 10L)
  daily <- simulate_daily_effort(config)

  testthat::expect_s3_class(daily, "tbl_df")
  testthat::expect_equal(nrow(daily), 3L * 4L * 7L)
  testthat::expect_true(all(daily$operating %in% c(0L, 1L)))
  testthat::expect_equal(length(unique(daily$camera_id)), 3L)
  testthat::expect_equal(length(unique(daily$date)), 28L)
})

testthat::test_that("configured failure and repair probabilities control operation", {
  config <- flexirich_sim_config(
    n_cameras = 1L,
    n_occasions = 1L,
    initial_operating_prob = 1,
    daily_failure_prob = 1,
    daily_repair_prob = 0,
    seed = 11L
  )
  daily <- simulate_daily_effort(config)

  testthat::expect_identical(daily$operating, c(1L, rep(0L, 6L)))
})

testthat::test_that("weekly effort is the exact daily sum", {
  config <- flexirich_sim_config(n_cameras = 2L, n_occasions = 2L, seed = 20L)
  daily <- simulate_daily_effort(config)
  weekly <- aggregate_weekly_effort(daily, config)

  recomputed <- daily |>
    dplyr::mutate(
      occasion_index = as.integer((date - config$start_date) %/% 7L) + 1L,
      occasion_id = sprintf("occ_%03d", occasion_index)
    ) |>
    dplyr::summarise(
      active_days_expected = sum(operating),
      .by = c(camera_id, occasion_id)
    )

  joined <- dplyr::left_join(
    weekly, recomputed, by = c("camera_id", "occasion_id")
  )
  testthat::expect_equal(joined$active_days, joined$active_days_expected)
  testthat::expect_true(all(weekly$active_days >= 0L & weekly$active_days <= 7L))
})

testthat::test_that("effort generation preserves the caller RNG state", {
  config <- flexirich_sim_config(seed = 30L)
  set.seed(999)
  before <- .Random.seed
  invisible(simulate_daily_effort(config))
  testthat::expect_identical(.Random.seed, before)
})
```

- [ ] **Step 2: Run the focused test and confirm failure**

Run:

```bash
Rscript -e 'source("tests/testthat/helper-load.R"); testthat::test_file("tests/testthat/test-sim-effort.R")'
```

Expected: failure because the effort functions do not exist.

- [ ] **Step 3: Implement daily Markov operation and validation**

```r
# R/sim_effort.R
validate_daily_effort <- function(effort_daily, config) {
  required <- c("camera_id", "date", "operating")
  missing <- setdiff(required, names(effort_daily))
  if (length(missing) > 0L) {
    stop("effort_daily is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  }

  expected_cameras <- sprintf("cam_%02d", seq_len(config$n_cameras))
  expected_dates <- seq(
    config$start_date,
    by = "day",
    length.out = config$n_occasions * config$occasion_days
  )
  if (!inherits(effort_daily$date, "Date")) {
    stop("effort_daily$date must have class Date.", call. = FALSE)
  }
  if (!all(effort_daily$operating %in% c(0L, 1L))) {
    stop("effort_daily$operating must contain only 0 and 1.", call. = FALSE)
  }
  if (anyDuplicated(effort_daily[c("camera_id", "date")])) {
    stop("effort_daily must have one row per camera_id and date.", call. = FALSE)
  }
  if (!setequal(effort_daily$camera_id, expected_cameras) ||
      !setequal(effort_daily$date, expected_dates) ||
      nrow(effort_daily) != length(expected_cameras) * length(expected_dates)) {
    stop("effort_daily does not cover the complete configured camera-date grid.", call. = FALSE)
  }

  dplyr::arrange(
    tibble::as_tibble(effort_daily),
    camera_id,
    date
  )
}

simulate_daily_effort <- function(config) {
  config <- validate_sim_config(config)
  n_days <- config$n_occasions * config$occasion_days
  cameras <- sprintf("cam_%02d", seq_len(config$n_cameras))
  dates <- seq(config$start_date, by = "day", length.out = n_days)

  states <- withr::with_seed(config$seed + 301L, {
    result <- matrix(0L, nrow = config$n_cameras, ncol = n_days)
    result[, 1L] <- stats::rbinom(
      config$n_cameras, 1L, config$initial_operating_prob
    )
    if (n_days > 1L) {
      for (day in 2:n_days) {
        previous <- result[, day - 1L]
        result[, day] <- ifelse(
          previous == 1L,
          1L - stats::rbinom(config$n_cameras, 1L, config$daily_failure_prob),
          stats::rbinom(config$n_cameras, 1L, config$daily_repair_prob)
        )
      }
    }
    result
  })

  daily <- tidyr::expand_grid(camera_id = cameras, date = dates) |>
    dplyr::mutate(operating = as.integer(c(t(states))))
  validate_daily_effort(daily, config)
}
```

- [ ] **Step 4: Implement seven-day aggregation**

```r
# append to R/sim_effort.R
aggregate_weekly_effort <- function(effort_daily, config) {
  config <- validate_sim_config(config)
  daily <- validate_daily_effort(effort_daily, config)

  daily |>
    dplyr::mutate(
      occasion_index = as.integer((date - config$start_date) %/% 7L) + 1L,
      occasion_id = sprintf("occ_%03d", occasion_index)
    ) |>
    dplyr::summarise(
      occasion_start = min(date),
      occasion_end = max(date),
      active_days = as.integer(sum(operating)),
      .by = c(camera_id, occasion_id, occasion_index)
    ) |>
    dplyr::arrange(camera_id, occasion_index)
}
```

- [ ] **Step 5: Run focused and full tests**

Run:

```bash
Rscript -e 'source("tests/testthat/helper-load.R"); testthat::test_file("tests/testthat/test-sim-effort.R")'
Rscript scripts/run_tests.R
```

Expected: all tests pass with no warnings.

- [ ] **Step 6: Commit the effort tranche**

```bash
git add R/sim_effort.R tests/testthat/test-sim-effort.R
git commit -m "feat: simulate exact weekly camera effort"
```

---

### Task 3: Generate latent membership, encounter rates and binary detections

**Files:**
- Create: `R/sim_flexirich_g.R`
- Create: `tests/testthat/test-sim-flexirich-g.R`

**Interfaces:**
- Consumes: validated configuration and optional validated daily effort
- Produces: `simulate_flexirich_g(config, effort_daily = NULL) -> flexirich_sim`
- Returns named elements: `config`, `species`, `cameras`, `rates`, `effort_daily`, `effort_weekly`, `detections`, `truth`, `metadata`

- [ ] **Step 1: Add failing generative-model tests**

```r
# tests/testthat/test-sim-flexirich-g.R
testthat::test_that("simulation returns the complete truth contract", {
  config <- flexirich_sim_config(
    candidate_pool_size = 12L,
    true_richness = 7L,
    n_cameras = 3L,
    n_occasions = 5L,
    seed = 100L
  )
  sim <- simulate_flexirich_g(config)

  testthat::expect_s3_class(sim, "flexirich_sim")
  testthat::expect_named(sim, c(
    "config", "species", "cameras", "rates", "effort_daily",
    "effort_weekly", "detections", "truth", "metadata"
  ))
  testthat::expect_equal(sum(sim$species$member), 7L)
  testthat::expect_equal(nrow(sim$rates), 12L * 3L)
  testthat::expect_equal(nrow(sim$detections), 12L * 3L * 5L)
  testthat::expect_identical(sim$truth$true_richness, 7L)
})

testthat::test_that("non-members and zero effort never generate detections", {
  config <- flexirich_sim_config(
    candidate_pool_size = 8L,
    true_richness = 4L,
    n_cameras = 2L,
    n_occasions = 3L,
    seed = 110L
  )
  no_effort <- tidyr::expand_grid(
    camera_id = sprintf("cam_%02d", 1:2),
    date = seq(config$start_date, by = "day", length.out = 21L)
  ) |>
    dplyr::mutate(operating = 0L)
  sim <- simulate_flexirich_g(config, no_effort)

  testthat::expect_true(all(is.na(sim$detections$detected)))
  testthat::expect_true(all(!sim$detections$sampled))
  testthat::expect_true(all(sim$detections$detect_prob == 0))

  ordinary <- simulate_flexirich_g(config)
  absent_rows <- ordinary$detections[!ordinary$detections$member, ]
  testthat::expect_true(all(
    is.na(absent_rows$detected) | absent_rows$detected == 0L
  ))
})

testthat::test_that("same seed reproduces data and truth without changing global RNG", {
  config <- flexirich_sim_config(seed = 120L)
  set.seed(777)
  before <- .Random.seed
  first <- simulate_flexirich_g(config)
  middle <- .Random.seed
  second <- simulate_flexirich_g(config)

  testthat::expect_identical(first$species, second$species)
  testthat::expect_identical(first$effort_daily, second$effort_daily)
  testthat::expect_identical(first$detections, second$detections)
  testthat::expect_identical(first$truth, second$truth)
  testthat::expect_identical(before, middle)
  testthat::expect_identical(before, .Random.seed)
})

testthat::test_that("baseline membership is independent of encounter-rate settings", {
  first <- simulate_flexirich_g(flexirich_sim_config(
    mean_log_rate = log(1e-5), sd_log_rate = 0.2, seed = 121L
  ))
  second <- simulate_flexirich_g(flexirich_sim_config(
    mean_log_rate = log(0.02), sd_log_rate = 2, seed = 121L
  ))

  testthat::expect_identical(first$species$member, second$species$member)
  testthat::expect_equal(sum(first$species$member), first$config$true_richness)
})
```

- [ ] **Step 2: Run the focused test and confirm failure**

Run:

```bash
Rscript -e 'source("tests/testthat/helper-load.R"); testthat::test_file("tests/testthat/test-sim-flexirich-g.R")'
```

Expected: failure because `simulate_flexirich_g()` does not exist.

- [ ] **Step 3: Implement latent state and observation generation**

```r
# R/sim_flexirich_g.R
simulate_flexirich_g <- function(config = flexirich_sim_config(), effort_daily = NULL) {
  config <- validate_sim_config(config)

  species <- tibble::tibble(
    species_id = sprintf("sp_%03d", seq_len(config$candidate_pool_size))
  )
  member_index <- withr::with_seed(config$seed + 101L, {
    if (config$true_richness == 0L) {
      integer()
    } else {
      sample.int(config$candidate_pool_size, config$true_richness)
    }
  })
  species$member <- seq_len(config$candidate_pool_size) %in% member_index
  species$alpha <- withr::with_seed(
    config$seed + 102L,
    stats::rnorm(
      config$candidate_pool_size,
      mean = config$mean_log_rate,
      sd = config$sd_log_rate
    )
  )

  cameras <- tibble::tibble(
    camera_id = sprintf("cam_%02d", seq_len(config$n_cameras)),
    camera_effect = withr::with_seed(
      config$seed + 201L,
      stats::rnorm(config$n_cameras, mean = 0, sd = config$sd_camera)
    )
  )

  rates <- tidyr::crossing(
    species_id = species$species_id,
    camera_id = cameras$camera_id
  ) |>
    dplyr::left_join(species, by = "species_id") |>
    dplyr::left_join(cameras, by = "camera_id") |>
    dplyr::mutate(encounter_rate = exp(alpha + camera_effect))
  if (any(!is.finite(rates$encounter_rate) | rates$encounter_rate <= 0)) {
    stop(
      "Configured effects must generate finite, positive encounter rates.",
      call. = FALSE
    )
  }

  if (is.null(effort_daily)) {
    effort_daily <- simulate_daily_effort(config)
  } else {
    effort_daily <- validate_daily_effort(effort_daily, config)
  }
  effort_weekly <- aggregate_weekly_effort(effort_daily, config)

  detections <- tidyr::crossing(
    species_id = species$species_id,
    effort_weekly
  ) |>
    dplyr::left_join(
      rates |>
        dplyr::select(species_id, camera_id, member, encounter_rate),
      by = c("species_id", "camera_id")
    ) |>
    dplyr::mutate(
      sampled = active_days > 0L,
      detect_prob_if_member = -expm1(-active_days * encounter_rate),
      detect_prob = as.numeric(member) * detect_prob_if_member
    )

  detections$detected <- withr::with_seed(config$seed + 401L, {
    value <- rep(NA_integer_, nrow(detections))
    sampled_rows <- which(detections$sampled)
    value[sampled_rows] <- stats::rbinom(
      length(sampled_rows),
      size = 1L,
      prob = detections$detect_prob[sampled_rows]
    )
    value
  })

  observed_species <- unique(
    detections$species_id[!is.na(detections$detected) & detections$detected == 1L]
  )
  observed_richness <- length(observed_species)
  truth <- tibble::tibble(
    candidate_pool_size = config$candidate_pool_size,
    true_richness = config$true_richness,
    observed_richness = as.integer(observed_richness),
    unseen_true_members = as.integer(config$true_richness - observed_richness),
    nonmembers = as.integer(config$candidate_pool_size - config$true_richness),
    total_detections = as.integer(sum(detections$detected, na.rm = TRUE))
  )

  result <- list(
    config = config,
    species = species,
    cameras = cameras,
    rates = rates,
    effort_daily = effort_daily,
    effort_weekly = effort_weekly,
    detections = detections,
    truth = truth,
    metadata = list(
      simulator_version = "0.1.0",
      seed = config$seed,
      generated_at = format(Sys.time(), tz = "UTC", usetz = TRUE)
    )
  )
  class(result) <- c("flexirich_sim", "list")
  result
}
```

- [ ] **Step 4: Add edge-case and monotonicity tests**

```r
# append to tests/testthat/test-sim-flexirich-g.R
testthat::test_that("zero and complete membership are supported", {
  empty <- simulate_flexirich_g(flexirich_sim_config(
    candidate_pool_size = 5L, true_richness = 0L, seed = 130L
  ))
  complete <- simulate_flexirich_g(flexirich_sim_config(
    candidate_pool_size = 5L, true_richness = 5L, seed = 131L
  ))

  testthat::expect_equal(empty$truth$true_richness, 0L)
  testthat::expect_equal(empty$truth$observed_richness, 0L)
  testthat::expect_true(all(complete$species$member))
})

testthat::test_that("numerically invalid encounter-rate settings fail visibly", {
  testthat::expect_error(
    simulate_flexirich_g(flexirich_sim_config(
      mean_log_rate = -1000,
      sd_log_rate = 0,
      seed = 132L
    )),
    "finite, positive encounter rates"
  )
})

testthat::test_that("hazard detection probability is non-decreasing with effort", {
  effort <- 0:7
  rate <- 0.02
  probability <- 1 - exp(-effort * rate)

  testthat::expect_true(all(diff(probability) >= 0))
  testthat::expect_equal(probability[1], 0)
  testthat::expect_true(all(probability >= 0 & probability <= 1))
})

testthat::test_that("returned tables exactly reproduce the generative equations", {
  config <- flexirich_sim_config(
    candidate_pool_size = 10L,
    true_richness = 6L,
    n_cameras = 3L,
    n_occasions = 4L,
    seed = 140L
  )
  sim <- simulate_flexirich_g(config)

  expected_effort <- sim$effort_daily |>
    dplyr::mutate(
      occasion_index = as.integer((date - config$start_date) %/% 7L) + 1L
    ) |>
    dplyr::summarise(
      expected_active_days = as.integer(sum(operating)),
      .by = c(camera_id, occasion_index)
    )
  effort_check <- dplyr::left_join(
    sim$effort_weekly,
    expected_effort,
    by = c("camera_id", "occasion_index")
  )
  testthat::expect_identical(
    effort_check$active_days,
    effort_check$expected_active_days
  )

  expected_rate <- exp(sim$rates$alpha + sim$rates$camera_effect)
  testthat::expect_equal(sim$rates$encounter_rate, expected_rate)

  expected_member_probability <- 1 - exp(
    -sim$detections$active_days * sim$detections$encounter_rate
  )
  testthat::expect_equal(
    sim$detections$detect_prob_if_member,
    expected_member_probability
  )
  testthat::expect_equal(
    sim$detections$detect_prob,
    as.numeric(sim$detections$member) * expected_member_probability
  )

  sampled <- sim$detections$sampled
  expected_detection <- withr::with_seed(config$seed + 401L, {
    stats::rbinom(
      sum(sampled),
      size = 1L,
      prob = sim$detections$detect_prob[sampled]
    )
  })
  testthat::expect_identical(
    sim$detections$detected[sampled],
    expected_detection
  )
})
```

- [ ] **Step 5: Run focused and full tests**

Run:

```bash
Rscript -e 'source("tests/testthat/helper-load.R"); testthat::test_file("tests/testthat/test-sim-flexirich-g.R")'
Rscript scripts/run_tests.R
```

Expected: all tests pass with no warnings.

- [ ] **Step 6: Commit the generative-model tranche**

```bash
git add R/sim_flexirich_g.R tests/testthat/test-sim-flexirich-g.R
git commit -m "feat: simulate FlexiRich-G detection histories"
```

---

### Task 4: Validate simulation objects and expose scientific summaries

**Files:**
- Create: `R/sim_summary.R`
- Create: `tests/testthat/test-sim-summary.R`

**Interfaces:**
- Consumes: `flexirich_sim`
- Produces: `validate_flexirich_sim(sim) -> TRUE invisibly` or an informative error
- Produces: `summary.flexirich_sim(object, ...) -> one-row tibble`
- Produces: `print.flexirich_sim(x, ...) -> x invisibly`
- Produces: `discovery_curve(sim) -> tibble(occasion_index, occasion_id, occasion_start, cumulative_richness)`

- [ ] **Step 1: Add failing validation and summary tests**

```r
# tests/testthat/test-sim-summary.R
testthat::test_that("simulation validation recomputes core invariants", {
  sim <- simulate_flexirich_g(flexirich_sim_config(seed = 200L))
  testthat::expect_true(validate_flexirich_sim(sim))

  broken <- sim
  broken$truth$true_richness <- broken$truth$true_richness + 1L
  testthat::expect_error(validate_flexirich_sim(broken), "true richness")
})

testthat::test_that("summary and discovery curve are coherent", {
  sim <- simulate_flexirich_g(flexirich_sim_config(seed = 210L))
  summary <- summary(sim)
  curve <- discovery_curve(sim)

  testthat::expect_s3_class(summary, "tbl_df")
  testthat::expect_equal(summary$true_richness, sim$truth$true_richness)
  testthat::expect_equal(nrow(curve), sim$config$n_occasions)
  testthat::expect_true(all(diff(curve$cumulative_richness) >= 0))
  testthat::expect_equal(
    tail(curve$cumulative_richness, 1L),
    sim$truth$observed_richness
  )
})

testthat::test_that("high encounter rate reveals more species than a very low rate", {
  low <- simulate_flexirich_g(flexirich_sim_config(
    mean_log_rate = log(1e-5),
    sd_log_rate = 0,
    sd_camera = 0,
    daily_failure_prob = 0,
    seed = 220L
  ))
  high <- simulate_flexirich_g(flexirich_sim_config(
    mean_log_rate = log(0.02),
    sd_log_rate = 0,
    sd_camera = 0,
    daily_failure_prob = 0,
    seed = 220L
  ))

  testthat::expect_gt(high$truth$observed_richness, low$truth$observed_richness)
})
```

- [ ] **Step 2: Run the focused test and confirm failure**

Run:

```bash
Rscript -e 'source("tests/testthat/helper-load.R"); testthat::test_file("tests/testthat/test-sim-summary.R")'
```

Expected: failure because summary and validation functions do not exist.

- [ ] **Step 3: Implement object validation**

```r
# R/sim_summary.R
validate_flexirich_sim <- function(sim) {
  if (!inherits(sim, "flexirich_sim")) {
    stop("sim must inherit from flexirich_sim.", call. = FALSE)
  }

  required <- c(
    "config", "species", "cameras", "rates", "effort_daily",
    "effort_weekly", "detections", "truth", "metadata"
  )
  if (!identical(names(sim), required)) {
    stop("sim has an invalid component contract.", call. = FALSE)
  }

  true_richness <- as.integer(sum(sim$species$member))
  observed_richness <- length(unique(
    sim$detections$species_id[
      !is.na(sim$detections$detected) & sim$detections$detected == 1L
    ]
  ))

  if (!identical(sim$truth$true_richness, true_richness)) {
    stop("truth record does not match recomputed true richness.", call. = FALSE)
  }
  if (!identical(sim$truth$observed_richness, as.integer(observed_richness))) {
    stop("truth record does not match recomputed observed richness.", call. = FALSE)
  }
  if (observed_richness > true_richness) {
    stop("observed richness exceeds true richness.", call. = FALSE)
  }
  if (any(sim$detections$detected[!sim$detections$member] == 1L, na.rm = TRUE)) {
    stop("a non-member species was detected.", call. = FALSE)
  }
  if (any(!is.na(sim$detections$detected[!sim$detections$sampled]))) {
    stop("zero-effort observations must be missing.", call. = FALSE)
  }
  if (any(!(sim$detections$detected[sim$detections$sampled] %in% c(0L, 1L)))) {
    stop("sampled observations must be binary.", call. = FALSE)
  }
  if (any(sim$detections$detect_prob_if_member < 0 |
          sim$detections$detect_prob_if_member > 1, na.rm = TRUE)) {
    stop("detection probabilities must lie in [0, 1].", call. = FALSE)
  }
  if (any(sim$rates$encounter_rate <= 0)) {
    stop("encounter rates must be positive.", call. = FALSE)
  }

  invisible(TRUE)
}
```

- [ ] **Step 4: Implement summary, printing and discovery**

```r
# append to R/sim_summary.R
summary.flexirich_sim <- function(object, ...) {
  validate_flexirich_sim(object)
  tibble::tibble(
    candidate_pool_size = object$truth$candidate_pool_size,
    true_richness = object$truth$true_richness,
    observed_richness = object$truth$observed_richness,
    unseen_true_members = object$truth$unseen_true_members,
    detection_completeness = if (object$truth$true_richness == 0L) {
      1
    } else {
      object$truth$observed_richness / object$truth$true_richness
    },
    camera_days = sum(object$effort_weekly$active_days),
    total_detections = object$truth$total_detections
  )
}

print.flexirich_sim <- function(x, ...) {
  print(summary(x), row.names = FALSE)
  invisible(x)
}

discovery_curve <- function(sim) {
  validate_flexirich_sim(sim)
  occasions <- sim$effort_weekly |>
    dplyr::distinct(occasion_index, occasion_id, occasion_start) |>
    dplyr::arrange(occasion_index)

  first_detection <- sim$detections |>
    dplyr::filter(detected == 1L) |>
    dplyr::summarise(
      first_occasion = min(occasion_index),
      .by = species_id
    )

  occasions |>
    dplyr::mutate(
      cumulative_richness = vapply(
        occasion_index,
        function(index) sum(first_detection$first_occasion <= index),
        integer(1)
      )
    )
}
```

- [ ] **Step 5: Run focused and full tests**

Run:

```bash
Rscript -e 'source("tests/testthat/helper-load.R"); testthat::test_file("tests/testthat/test-sim-summary.R")'
Rscript scripts/run_tests.R
```

Expected: all tests pass with no warnings, including low/high-detection comparison.

- [ ] **Step 6: Commit the validation and summary tranche**

```bash
git add R/sim_summary.R tests/testthat/test-sim-summary.R
git commit -m "feat: validate and summarise simulations"
```

---

### Task 5: Produce the illustrated Judbury-shaped acceptance scenario

**Files:**
- Create: `analysis/goal001_simulator.qmd`
- Modify: `README.md`

**Interfaces:**
- Consumes: all Goal 001 simulator functions
- Produces: `outputs/goal001/goal001_simulator.html`
- Provides the documented one-command illustrated acceptance run.

- [ ] **Step 1: Create the executable Quarto analysis**

````qmd
---
title: "Goal 001: minimum viable FlexiRich-G simulator"
format:
  html:
    toc: true
execute:
  echo: true
  warning: false
  message: false
---

```{r}
for (path in sort(list.files("../R", pattern = "\\.R$", full.names = TRUE))) {
  source(path, local = FALSE)
}
```

## Scenario

This is an explanatory simulation with 30 candidate species, 20 true
grid members, nine cameras, 208 seven-day occasions and synthetic operational
outages. It is not an inferential validation study.

```{r}
config <- flexirich_sim_config(seed = 20260723L)
sim <- simulate_flexirich_g(config)
validate_flexirich_sim(sim)
summary(sim)
```

## Operational effort

```{r}
effort_plot_data <- sim$effort_weekly |>
  dplyr::mutate(camera_id = factor(camera_id))

ggplot2::ggplot(
  effort_plot_data,
  ggplot2::aes(x = occasion_start, y = camera_id, fill = active_days)
) +
  ggplot2::geom_tile() +
  ggplot2::scale_fill_viridis_c(limits = c(0, 7)) +
  ggplot2::labs(
    x = NULL,
    y = "Synthetic camera",
    fill = "Active days",
    title = "Weekly operational effort"
  ) +
  ggplot2::theme_minimal()
```

## Species encounter heterogeneity

```{r}
ggplot2::ggplot(
  sim$species,
  ggplot2::aes(x = exp(alpha), fill = member)
) +
  ggplot2::geom_histogram(bins = 20, position = "identity", alpha = 0.65) +
  ggplot2::scale_x_log10() +
  ggplot2::labs(
    x = "Baseline encounter rate per active camera-day",
    y = "Candidate species",
    fill = "True member",
    title = "Simulated species encounter rates"
  ) +
  ggplot2::theme_minimal()
```

## Discovery trajectory

```{r}
curve <- discovery_curve(sim)

ggplot2::ggplot(
  curve,
  ggplot2::aes(x = occasion_start, y = cumulative_richness)
) +
  ggplot2::geom_step(linewidth = 0.8) +
  ggplot2::geom_hline(
    yintercept = sim$truth$true_richness,
    linetype = "dashed"
  ) +
  ggplot2::labs(
    x = NULL,
    y = "Cumulative observed richness",
    title = "Species discovery through simulated monitoring",
    subtitle = "Dashed line is known true richness"
  ) +
  ggplot2::theme_minimal()
```

## Acceptance interpretation

The scenario demonstrates the simulator contract and produces inspectable
effort, encounter-rate and discovery patterns. It does not demonstrate that a
richness estimator is unbiased, calibrated or robust to misspecification.
Those questions begin in Goal 002.
````

- [ ] **Step 2: Render from a clean output directory**

Run:

```bash
quarto render analysis/goal001_simulator.qmd --output-dir ../outputs/goal001
test -s outputs/goal001/goal001_simulator.html
```

Expected: Quarto exits zero and the HTML file exists with non-zero size.

- [ ] **Step 3: Inspect the rendered output once**

Check:

- the summary reports \(0 \leq S_{\mathrm{obs}} \leq S_{\mathrm{true}} = 20\);
- the effort heatmap has nine cameras and visible synthetic outages;
- encounter rates are positive and heterogeneous;
- the discovery curve is non-decreasing and never exceeds 20;
- no Huon Ridge or empirical Judbury paths/data appear.

If a material error is visible, repair it once and rerun Task 5. Do not iterate
on cosmetic minutiae.

- [ ] **Step 4: Commit the illustrated scenario source**

```bash
git add analysis/goal001_simulator.qmd README.md
git commit -m "docs: add Goal 001 simulation scenario"
```

Do not add `outputs/`.

---

### Task 6: Close the Goal 001 acceptance gate

**Files:**
- Create: `docs/goals/001-minimum-viable-simulator/Log.md`
- Modify: `docs/goals/001-minimum-viable-simulator/Goal.md`

**Interfaces:**
- Consumes: completed simulator, test evidence, rendered scenario and Git state
- Produces: durable acceptance record and Goal 001 status

- [ ] **Step 1: Run the complete acceptance commands**

Run:

```bash
Rscript scripts/run_tests.R
quarto render analysis/goal001_simulator.qmd --output-dir ../outputs/goal001
Rscript -e 'renv::status()'
git status --short
```

Expected:

- all tests pass without warnings;
- the Quarto render exits zero;
- `renv::status()` reports no issues;
- Git status contains no unexpected files and generated `outputs/` remains ignored.

- [ ] **Step 2: Verify the truth contract independently**

Run:

```bash
Rscript -e '
for (path in sort(list.files("R", pattern = "\\.R$", full.names = TRUE))) source(path)
x <- simulate_flexirich_g(flexirich_sim_config(seed = 20260723L))
stopifnot(validate_flexirich_sim(x))
stopifnot(sum(x$species$member) == x$truth$true_richness)
detected_rows <- !is.na(x$detections$detected) & x$detections$detected == 1L
stopifnot(length(unique(x$detections$species_id[detected_rows])) == x$truth$observed_richness)
stopifnot(x$truth$observed_richness <= x$truth$true_richness)
cat("Goal 001 truth contract: PASS\n")
'
```

Expected: `Goal 001 truth contract: PASS`.

- [ ] **Step 3: Write the goal log with exact evidence**

```markdown
# Goal 001 Log

## Outcome

Record whether the minimum viable FlexiRich-G simulator satisfied every
acceptance criterion in `Goal.md`.

## Implemented artefacts

List the exact source, test and analysis files delivered.

## Verification

Record the test count, Quarto output path, `renv::status()` result, truth-contract
command result, R version and commit hashes.

## Scientific interpretation

Distinguish demonstrated facts (deterministic simulation, invariants and
illustrated behaviour) from untested inference claims.

## Residual limitations

Record only material limitations remaining within or deliberately deferred
beyond Goal 001.

## Recommendation

State whether Goal 002 should begin, whether a targeted repair is required, or
whether a scientific design decision is blocking progress.
```

Replace each instruction in this template with observed evidence; no
instructional placeholder text may remain.

- [ ] **Step 4: Set the goal status from observed evidence**

If and only if every acceptance criterion passes, change the header in
`Goal.md` to:

```markdown
Status: complete — accepted for Goal 002 planning
```

Otherwise set:

```markdown
Status: blocked — see Log.md
```

and describe the unmet criterion rather than weakening it.

- [ ] **Step 5: Perform one focused self-review**

Check:

- every Goal 001 acceptance criterion maps to recorded evidence;
- no `TBD`, `TODO`, `FIXME` or instructional placeholder remains;
- no private data, coordinates or paths were introduced;
- no generated output is staged;
- no inference claim is made from the illustrated scenario.

Repair material defects once. Stop if further passes would only polish wording
or layout.

- [ ] **Step 6: Commit the acceptance record**

```bash
git add docs/goals/001-minimum-viable-simulator/Goal.md docs/goals/001-minimum-viable-simulator/Log.md renv.lock
git commit -m "docs: close Goal 001 simulator"
git status --short --branch
```

Expected: clean `main` worktree after the commit.

---

## Goal 001 Completion Boundary

Completion demonstrates that the simulator is reproducible, internally
coherent and suitable for the first model-recovery experiment. It does **not**
demonstrate that FlexiRich-G is identifiable, unbiased, calibrated, superior
to existing estimators, or robust under real camera-trap processes.
