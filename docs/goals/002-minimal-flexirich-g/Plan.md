# Goal 002 Minimal FlexiRich-G Inference Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement, verify and pilot-test the first statistically valid FlexiRich-G estimator for finite known candidate pools under the correctly specified Goal 001 camera-trap process.

**Architecture:** A validated R data layer converts complete species-camera-occasion histories into an exact grouped likelihood without exposing simulator truth. CmdStanR fits a non-centred hierarchical encounter model with analytically marginalised candidate membership; independent R oracles verify every load-bearing likelihood, probability and scoring calculation. Separate configuration, fitting, summary and pilot-protocol modules enforce prior decisions, one-rescue diagnostics, immutable manifests and conservative failure handling before the frozen 96-fit pilot is run.

**Tech Stack:** R 4.6.1, `renv`, `testthat`, `cmdstanr`, CmdStan 2.38.0, `posterior`, `digest`, `tibble`, `dplyr`, `tidyr`, `withr`, `ggplot2`, Quarto.

## Global Constraints

- The candidate universe is finite and known.
- The estimand is whole-grid detectable-use richness during a defined period.
- Input observations are species × camera × seven-day binary detections.
- Effort is exact active camera-days in `0:7`; zero-effort observations are missing and contribute no likelihood term.
- Every eligible candidate is supplied, including candidates with all-zero histories.
- The baseline inference family matches Goal 001: Gaussian species effects and Gaussian camera effects on the log encounter-rate scale, constant through the fitted period.
- Membership is analytically marginalised in Stan; no continuous pseudo-presence variable is permitted.
- Camera effects use a sum-to-zero orthonormal contrast parameterisation.
- The primary candidate-pool size is 30, cameras are nine, true-richness levels are 8, 20 and 27, and durations are 26 and 208 seven-day occasions.
- The primary pilot contains exactly 60 frozen fits; the two sensitivity profiles add exactly 36 fits.
- Development uses exactly one separate seed per pilot cell and may define only one rescue sampler profile.
- Priors, sampler settings, source, formulas, metrics, gates and all frozen seeds are committed before frozen recovery output is viewed.
- No frozen replicate is discarded, replaced or silently omitted.
- Generated executables, CmdStan CSV files, fit objects and reports remain under ignored `outputs/`.
- Judbury observations and all Huon Ridge data, paths and coordinates remain outside Goal 002.
- No comparator, misspecification, alternative occasion length, site-level richness or empirical fit is added.
- Goal 002 supports implementation correctness and correctly specified pilot behaviour only.
- Stop after the frozen pilot, report, one focused repair pass and acceptance decision.

## Audit Corrections Incorporated

### Exact lower-bound-conditioned comparator

Let \(C\) be candidate-pool size, \(O=S_{\mathrm{obs}}\), \(U=C-O\), and
\(\omega\sim\operatorname{Beta}(a,b)\). Conditioning only on the logical fact
that the \(O\) detected candidates are members gives:

\[
\omega\mid D\sim\operatorname{Beta}(a+O,b),
\]

\[
M\mid D\sim\operatorname{BetaBinomial}(U,a+O,b),
\qquad S=O+M.
\]

The baseline probability mass function is therefore:

\[
P_0(S=s\mid D)
=
\binom{U}{s-O}
\frac{B(a+s,\ b+C-s)}{B(a+O,b)},
\qquad s=O,\ldots,C.
\]

It uses no zero-detection histories, effort, encounter rates or encounter
likelihood. For \(C=4\), \(O=2\), and \(a=b=1\), the probabilities at
\(s=(2,3,4)\) are exactly \((0.1,0.3,0.6)\).

The frozen proper score is the unnormalised discrete ranked probability score:

\[
\operatorname{RPS}(\mathbf p,s^\star)
=
\sum_{t=0}^{C-1}
\left[
\sum_{s=0}^{t}p_s-I(s^\star\le t)
\right]^2.
\]

Its range is \([0,C]\). The hand case above has RPS \(0.37\) when
\(s^\star=3\). Normalised RPS may be reported secondarily, but Criterion 28
uses the unnormalised score.

### Immutable terminal-fit and gate policy

Each scheduled fit resolves to exactly one terminal state:

- `primary_clean`;
- `rescue_clean`; or
- `final_nonclean`.

A non-clean primary attempt triggers exactly one prespecified rescue on the
same simulated data. Primary and rescue attempts are both retained. No run,
seed, simulation or manifest row is replaced.

Raw posterior summaries from `final_nonclean` fits are `NA` and are never
presented as inference. Gate-only values prevent non-clean fits from improving
aggregate results:

| Metric | Gate value for `final_nonclean` |
|---|---:|
| interval coverage | `FALSE` |
| posterior probability at truth | `0` |
| absolute error | \(C\) |
| squared error | \(C^2\) |
| RPS | \(C\) |
| absolute sensitivity shift | \(C\) |
| signed error and posterior summaries | `NA` |

Coverage denominators remain fixed at 10 per cell and 30 per duration.
Criteria 26–28 and 33 use the conservative gate values over every scheduled
row, not complete-case medians.

Any `final_nonclean` four-year primary fit automatically fails Criteria 25–29;
their numerical summaries may be shown descriptively but cannot be adjudicated
as passing. Any `final_nonclean` four-year sensitivity fit automatically fails
Criteria 33–34. A six-month `final_nonclean` fit is a noncoverage and remains in
the diagnostic denominator; other six-month summaries state both the planned
and clean counts. Criterion 22 may therefore tolerate terminal non-clean fits
only where the remaining universal gates still permit them.

### Operational prior-predictive decision

Each prior profile is checked using 10,000 fixed-seed draws and one separately
frozen Goal 001 effort history with 208 occasions. The 26-occasion history is
the exact prefix, and each simulated history is nested so that
\(O_{26}\le O_{208}\).

A profile is automatically rejected before recovery fitting if:

1. any \(\mu,\sigma,\eta,r,p\), log-likelihood, richness or observed-richness
   result is invalid or non-finite;
2. any draw violates \(0\le O_{26}\le O_{208}\le S\le C\);
3. its analytical richness PMF has invalid support or fails to sum to one
   within \(10^{-12}\);
4. one observed-richness value has empirical prior mass at least 0.95 at
   either duration; or
5. at either duration,
   \(P(0<O_K<S\mid1<S<C)<0.05\).

For each profile, report the fixed quantiles
`0, 0.001, 0.01, 0.05, 0.5, 0.95, 0.99, 0.999, 1` for
\(\eta,r,p_1,p_7,S,O_{26},O_{208}\), boundary masses, and floating-point
saturation frequencies. These are numerical and design-informativeness gates,
not ecological validation.

Ecological plausibility remains a dated PI decision with exactly one verdict:
`accept_provisionally`, `revise_before_freeze`, or `reject`. The decision must
state that it applies only to the correctly specified synthetic pilot. Any
revision is versioned and rechecked before recovery output is viewed. One
revision cycle is allowed; unresolved concern then blocks the freeze.

---

## Planned File Structure

| Path | Responsibility |
|---|---|
| `R/infer_config.R` | Prior, sampler, diagnostic and backend version contracts |
| `R/infer_data.R` | Input validation, simulator adapter, exact aggregation, contrast matrix and data hash |
| `R/infer_math.R` | Stable hazard calculations, grouped member likelihood and conditional richness arithmetic |
| `R/infer_scores.R` | Beta-binomial comparator, discrete summaries and RPS |
| `R/infer_prior.R` | Nested prior-predictive simulation and automatic profile gates |
| `R/fit_flexirich_g.R` | Source-hashed compilation, sampling, rescue handling and provenance |
| `R/infer_summary.R` | Rao-Blackwellised richness PMF, membership, effects, diagnostics and PPC summaries |
| `R/goal002_pilot.R` | Manifests, immutable fit statuses, pilot execution and acceptance aggregation |
| `stan/flexirich_g.stan` | Marginalised FlexiRich-G likelihood and generated quantities |
| `tests/testthat/helper-goal002-oracles.R` | Independent rowwise and exhaustive-membership oracles used only by tests |
| `tests/testthat/test-infer-config.R` | Configuration and backend contract tests |
| `tests/testthat/test-infer-data.R` | Input, truth-isolation and aggregation tests |
| `tests/testthat/test-infer-likelihood.R` | Hazard, aggregation, membership and Stan-bridge tests |
| `tests/testthat/test-infer-scores.R` | Comparator PMF, discrete summaries and RPS tests |
| `tests/testthat/test-infer-prior.R` | Prior-predictive nesting and rejection-rule tests |
| `tests/testthat/test-fit-contract.R` | Attempt, metadata, diagnostics and rescue tests |
| `tests/testthat/test-infer-summary.R` | PMF, support, membership and PPC tests |
| `tests/testthat/test-goal002-pilot.R` | Manifest, status, denominator, penalty and gate tests |
| `scripts/setup_cmdstan.R` | Explicit CmdStan version check or opt-in installation |
| `scripts/check_stan_model.R` | Source-hashed compilation and Stan-to-R oracle check |
| `scripts/run_goal002_prior_check.R` | Frozen prior-predictive evidence |
| `scripts/run_goal002_smoke.R` | Deterministic end-to-end HMC smoke fit |
| `scripts/run_goal002_pilot.R` | Resume-safe development and frozen run dispatcher |
| `config/goal002_development_manifest.csv` | Six prespecified development runs |
| `config/goal002_frozen_manifest.csv` | Frozen 60 primary and 36 sensitivity runs |
| `config/goal002_freeze.csv` | Source, profile, sampler, manifest and audit hashes |
| `docs/goals/002-minimal-flexirich-g/PriorPredictiveDecision.md` | Prior evidence and dated PI verdict |
| `docs/goals/002-minimal-flexirich-g/Development.md` | Six development-fit diagnostics and frozen sampler decision |
| `docs/goals/002-minimal-flexirich-g/Audit.md` | Pre-freeze independent audit and finding dispositions |
| `analysis/goal002_baseline_recovery.qmd` | Source-only pilot and sensitivity report |
| `docs/goals/002-minimal-flexirich-g/Log.md` | Final acceptance evidence and scientific boundary |
| `README.md` | Canonical Goal 002 setup, check, smoke, pilot and render commands |
| `renv.lock` | Locked R dependencies |

All `R/*.R` files must be safe to source alphabetically and perform no
top-level computation. Expensive compilation and sampling occur only through
explicit scripts.

Test-only fixture functions named in this plan are defined locally at the top
of their owning test file, except for the mathematical fixtures in
`helper-goal002-oracles.R`. They return the exact production-shaped lists
shown in the corresponding `Interfaces` block and may not be called from
production source.

## Goal-to-Task Coverage

| Goal 002 requirements | Implemented and verified in |
|---|---|
| Data and likelihood correctness, Criteria 1–7 | Tasks 2, 3 and 5 |
| Posterior coherence, Criteria 8–14 | Tasks 3, 5, 7 and 8 |
| Prior and truth alignment, Criteria 15–18 | Tasks 2, 3, 6 and 10 |
| Computational validity, Criteria 19–24 | Tasks 7, 9, 10 and 11 |
| Pilot recovery, Criteria 25–31 | Tasks 9, 11 and 12 |
| Prior sensitivity, Criteria 32–35 | Tasks 6, 9, 11 and 12 |
| Reproducible deliverables, Criteria 36–41 | Tasks 1, 5 and 9–12 |
| Hard-failure and stopping rules | Tasks 9–12 and the completion boundary |
| Predefined fallback boundary | Goal 002 completion boundary only; not implemented |

---

### Task 1: Lock inference configuration and the CmdStan toolchain

**Files:**
- Create: `R/infer_config.R`
- Create: `tests/testthat/test-infer-config.R`
- Create: `scripts/setup_cmdstan.R`
- Modify: `README.md`
- Modify: `renv.lock`

**Interfaces:**
- Produces: `goal002_prior_profiles() -> named list`
- Produces: `goal002_sampler_profiles() -> named list`
- Produces: `goal002_diagnostic_thresholds() -> named list`
- Produces: `validate_goal002_profile(profile, type) -> profile` or error
- Produces: `check_goal002_cmdstan(required_version, error) -> list`
- Establishes exact configuration objects consumed by every later task.

- [ ] **Step 1: Write failing configuration tests**

```r
# tests/testthat/test-infer-config.R
testthat::test_that("Goal 002 prior profiles are exact and named", {
  profiles <- goal002_prior_profiles()

  testthat::expect_identical(
    names(profiles),
    c("primary", "sensitivity_membership", "sensitivity_tail")
  )
  testthat::expect_equal(profiles$primary$omega_alpha, 1)
  testthat::expect_equal(profiles$primary$omega_beta, 1)
  testthat::expect_equal(profiles$primary$mu_alpha_location, log(1e-3))
  testthat::expect_equal(profiles$primary$mu_alpha_scale, 2)
  testthat::expect_equal(profiles$primary$sigma_alpha_scale, 1.5)
  testthat::expect_equal(profiles$primary$sigma_camera_scale, 0.75)
  testthat::expect_equal(
    profiles$sensitivity_membership$omega_alpha,
    0.5
  )
  testthat::expect_equal(
    profiles$sensitivity_membership$omega_beta,
    0.5
  )
  testthat::expect_equal(profiles$sensitivity_tail$mu_alpha_scale, 3)
  testthat::expect_equal(
    profiles$sensitivity_tail$sigma_alpha_scale,
    2.5
  )
})

testthat::test_that("sampler and clean-fit profiles are frozen explicitly", {
  sampler <- goal002_sampler_profiles()
  limits <- goal002_diagnostic_thresholds()

  testthat::expect_identical(names(sampler), c("primary", "rescue"))
  testthat::expect_equal(sampler$primary$chains, 4L)
  testthat::expect_equal(sampler$primary$parallel_chains, 4L)
  testthat::expect_equal(sampler$primary$iter_warmup, 1000L)
  testthat::expect_equal(sampler$primary$iter_sampling, 1000L)
  testthat::expect_equal(sampler$primary$adapt_delta, 0.90)
  testthat::expect_equal(sampler$primary$max_treedepth, 12L)
  testthat::expect_equal(sampler$rescue$iter_warmup, 1500L)
  testthat::expect_equal(sampler$rescue$iter_sampling, 1500L)
  testthat::expect_equal(sampler$rescue$adapt_delta, 0.99)
  testthat::expect_equal(sampler$rescue$max_treedepth, 15L)
  testthat::expect_identical(
    limits,
    list(
      max_divergences = 0L,
      max_treedepth_hits = 0L,
      min_ebfmi = 0.3,
      max_rhat = 1.01,
      min_bulk_ess = 400,
      min_tail_ess = 400
    )
  )
})

testthat::test_that("invalid inference profiles fail before sampling", {
  bad <- goal002_prior_profiles()$primary
  bad$omega_alpha <- 0
  testthat::expect_error(
    validate_goal002_profile(bad, "prior"),
    "omega_alpha"
  )

  bad_sampler <- goal002_sampler_profiles()$primary
  bad_sampler$parallel_chains <- 5L
  testthat::expect_error(
    validate_goal002_profile(bad_sampler, "sampler"),
    "parallel_chains"
  )
})
```

- [ ] **Step 2: Run the focused test and confirm the expected failure**

Run:

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-infer-config.R")'
```

Expected: failure because the Goal 002 configuration functions do not exist.

- [ ] **Step 3: Implement the exact configuration contract**

```r
# R/infer_config.R
.goal002_cmdstan_version <- "2.38.0"

goal002_prior_profiles <- function() {
  primary <- list(
    profile_id = "primary-v1",
    omega_alpha = 1,
    omega_beta = 1,
    mu_alpha_location = log(1e-3),
    mu_alpha_scale = 2,
    sigma_alpha_scale = 1.5,
    sigma_camera_scale = 0.75
  )

  list(
    primary = primary,
    sensitivity_membership = utils::modifyList(
      primary,
      list(
        profile_id = "sensitivity-membership-v1",
        omega_alpha = 0.5,
        omega_beta = 0.5
      )
    ),
    sensitivity_tail = utils::modifyList(
      primary,
      list(
        profile_id = "sensitivity-tail-v1",
        mu_alpha_scale = 3,
        sigma_alpha_scale = 2.5
      )
    )
  )
}

goal002_sampler_profiles <- function() {
  list(
    primary = list(
      profile_id = "primary-sampler-v1",
      chains = 4L,
      parallel_chains = 4L,
      iter_warmup = 1000L,
      iter_sampling = 1000L,
      adapt_delta = 0.90,
      max_treedepth = 12L,
      refresh = 100L
    ),
    rescue = list(
      profile_id = "rescue-sampler-v1",
      chains = 4L,
      parallel_chains = 4L,
      iter_warmup = 1500L,
      iter_sampling = 1500L,
      adapt_delta = 0.99,
      max_treedepth = 15L,
      refresh = 100L
    )
  )
}

goal002_diagnostic_thresholds <- function() {
  list(
    max_divergences = 0L,
    max_treedepth_hits = 0L,
    min_ebfmi = 0.3,
    max_rhat = 1.01,
    min_bulk_ess = 400,
    min_tail_ess = 400
  )
}
```

`validate_goal002_profile()` must require exact fields, reject duplicates or
extras, canonicalise field order, require finite scalar values, require
positive prior scales and beta shapes, require four chains with no more than
four parallel chains, and require `adapt_delta` in `(0, 1)`.

`check_goal002_cmdstan()` must return:

```r
list(
  available = TRUE,
  required_version = "2.38.0",
  installed_version = "2.38.0",
  path = cmdstanr::cmdstan_path(),
  matches = TRUE
)
```

It must fail informatively when `cmdstanr` is unavailable, the path is absent,
or the installed version differs.

- [ ] **Step 4: Add the explicit CmdStan setup script**

```r
# scripts/setup_cmdstan.R
args <- commandArgs(trailingOnly = TRUE)
install_requested <- identical(args, "--install")

if (!requireNamespace("cmdstanr", quietly = TRUE)) {
  stop(
    "Restore the project renv before checking CmdStan: Rscript bootstrap_env.R",
    call. = FALSE
  )
}

required <- "2.38.0"
current <- tryCatch(
  as.character(cmdstanr::cmdstan_version()),
  error = function(e) NA_character_
)

if (!identical(current, required) && install_requested) {
  cmdstanr::install_cmdstan(version = required, cores = 4L)
  current <- as.character(cmdstanr::cmdstan_version())
}

if (!identical(current, required)) {
  stop(
    "CmdStan ", required,
    " is required. Install explicitly with: ",
    "Rscript scripts/setup_cmdstan.R --install",
    call. = FALSE
  )
}

cat("CmdStan contract: PASS (", current, ")\n", sep = "")
```

Ordinary tests and model checks must never call the script with `--install`.

- [ ] **Step 5: Install and lock project dependencies**

Run:

```bash
Rscript -e '
options(
  repos = c(
    STAN = "https://stan-dev.r-universe.dev",
    CRAN = "https://cloud.r-project.org"
  )
)
renv::install(c("cmdstanr", "posterior", "digest"))
packages <- unique(c(
  renv::dependencies()$Package,
  "cmdstanr", "posterior", "digest"
))
renv::snapshot(packages = packages, prompt = FALSE)
'
Rscript scripts/setup_cmdstan.R
Rscript -e 'renv::status()'
```

Expected: CmdStan 2.38.0 passes, and `renv::status()` reports no issues.

- [ ] **Step 6: Update the canonical README commands**

Add a Goal 002 section containing:

````markdown
## Goal 002

```sh
Rscript bootstrap_env.R
Rscript scripts/setup_cmdstan.R
Rscript scripts/run_tests.R
Rscript scripts/check_stan_model.R
Rscript scripts/run_goal002_smoke.R
```

CmdStan installation is explicit:

```sh
Rscript scripts/setup_cmdstan.R --install
```

Generated inference artefacts remain under `outputs/` and are not committed.
````

- [ ] **Step 7: Run focused and full checks**

Run:

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-infer-config.R")'
Rscript scripts/run_tests.R
Rscript -e 'renv::status()'
```

Expected: all checks pass without warnings.

- [ ] **Step 8: Commit the environment and configuration tranche**

```bash
git add R/infer_config.R tests/testthat/test-infer-config.R \
  scripts/setup_cmdstan.R README.md renv.lock
git commit -m "feat: establish Goal 002 inference environment"
```

---

### Task 2: Build the exact inference-data contract

**Files:**
- Create: `R/infer_data.R`
- Create: `tests/testthat/test-infer-data.R`

**Interfaces:**
- Consumes: candidate, weekly effort and complete detection tables
- Produces: `prepare_flexirich_g_data(candidate_pool, effort_weekly, detections) -> flexirich_g_data`
- Produces: `sim_to_flexirich_g_data(sim) -> flexirich_g_data`
- Produces: `validate_flexirich_g_data(data) -> TRUE` or error
- Produces the exact `stan_data` structural fields consumed by Task 5.

- [ ] **Step 1: Add failing data-contract tests**

```r
# tests/testthat/test-infer-data.R
testthat::test_that("simulator adapter retains observations and excludes truth", {
  sim <- simulate_flexirich_g(
    flexirich_sim_config(
      candidate_pool_size = 4L,
      true_richness = 2L,
      n_cameras = 2L,
      n_occasions = 3L,
      seed = 2101L
    )
  )
  data <- sim_to_flexirich_g_data(sim)

  testthat::expect_s3_class(data, "flexirich_g_data")
  testthat::expect_true(validate_flexirich_g_data(data))
  forbidden <- c(
    "member", "true_richness", "alpha", "camera_effect",
    "encounter_rate", "detect_prob", "detect_prob_if_member", "truth"
  )
  testthat::expect_empty(intersect(forbidden, names(data)))
  testthat::expect_empty(intersect(forbidden, names(data$stan_data)))
  testthat::expect_identical(data$stan_data$C, 4L)
  testthat::expect_identical(data$stan_data$J, 2L)
})

testthat::test_that("zero effort contributes no grouped trial", {
  sim <- simulate_flexirich_g(
    flexirich_sim_config(
      candidate_pool_size = 3L,
      true_richness = 2L,
      n_cameras = 2L,
      n_occasions = 2L,
      seed = 2102L
    )
  )
  sim$effort_weekly$active_days[1] <- 0L
  affected <- sim$detections$camera_id ==
    sim$effort_weekly$camera_id[1] &
    sim$detections$occasion_id ==
    sim$effort_weekly$occasion_id[1]
  sim$detections$active_days[affected] <- 0L
  sim$detections$sampled[affected] <- FALSE
  sim$detections$detected[affected] <- NA_integer_

  data <- prepare_flexirich_g_data(
    sim$species["species_id"],
    sim$effort_weekly[c("camera_id", "occasion_id", "active_days")],
    sim$detections[c(
      "species_id", "camera_id", "occasion_id", "detected"
    )]
  )

  testthat::expect_identical(
    sum(data$grouped$n_trials),
    3L * (2L * 2L - 1L)
  )
  testthat::expect_false(any(data$grouped$active_days == 0L))
})

testthat::test_that("aggregation reconstructs every sampled observation", {
  sim <- simulate_flexirich_g(
    flexirich_sim_config(
      candidate_pool_size = 5L,
      true_richness = 3L,
      n_cameras = 3L,
      n_occasions = 8L,
      seed = 2103L
    )
  )
  data <- sim_to_flexirich_g_data(sim)

  testthat::expect_identical(
    sum(data$grouped$n_trials),
    data$audit$n_sampled_rows
  )
  testthat::expect_identical(
    sum(data$grouped$n_detected),
    data$audit$n_detections
  )
  testthat::expect_identical(
    sort(unique(data$grouped$species_id)),
    sort(data$candidate_ids)
  )
})
```

Add cases that reject extra, missing, duplicate and unnamed fields; incomplete
species-camera-occasion keys; candidate IDs absent from detections; detections
outside `0/1`; non-missing outcomes at zero effort; missing outcomes at
positive effort; active days outside `0:7`; duplicated IDs; and non-finite
values. Add a permutation test that returns byte-identical grouped and Stan
data after candidate, camera, occasion and row order are changed.

- [ ] **Step 2: Run the focused test and confirm failure**

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-infer-data.R")'
```

Expected: failure because `prepare_flexirich_g_data()` is undefined.

- [ ] **Step 3: Implement exact validation and aggregation**

The returned object must have this structure:

```r
list(
  candidate_ids = character(C),
  camera_ids = character(J),
  occasion_ids = character(K),
  observed = tibble::tibble(
    species_id = character(),
    camera_id = character(),
    occasion_id = character(),
    active_days = integer(),
    detected = integer()
  ),
  grouped = tibble::tibble(
    species_id = character(),
    camera_id = character(),
    active_days = integer(),
    n_trials = integer(),
    n_detected = integer()
  ),
  stan_data = list(
    C = as.integer(C),
    J = as.integer(J),
    B = as.integer(max(J - 1L, 0L)),
    G = as.integer(G),
    species_index = integer(G),
    camera_index = integer(G),
    active_days = integer(G),
    n_trials = integer(G),
    n_detected = integer(G),
    detected_ever = integer(C),
    Q = matrix(numeric(), nrow = J, ncol = max(J - 1L, 0L))
  ),
  audit = list(
    n_original_rows = as.integer(C * J * K),
    n_sampled_rows = integer(1),
    n_zero_effort_rows = integer(1),
    n_grouped_rows = integer(1),
    n_detections = integer(1)
  ),
  data_hash = character(1)
)
```

Use an exact Helmert basis:

```r
.sum_zero_basis <- function(J) {
  if (J == 1L) {
    return(matrix(numeric(), nrow = 1L, ncol = 0L))
  }
  H <- stats::contr.helmert(J)
  sweep(H, 2L, sqrt(colSums(H^2)), "/")
}
```

After exact key validation, construct the grouped table with:

```r
grouped <- observed |>
  dplyr::filter(active_days > 0L) |>
  dplyr::summarise(
    n_trials = dplyr::n(),
    n_detected = as.integer(sum(detected)),
    .by = c(species_id, camera_id, active_days)
  ) |>
  dplyr::arrange(
    match(species_id, candidate_ids),
    match(camera_id, camera_ids),
    active_days
  )
```

Canonicalise candidate, camera and occasion identifiers with lexical sorting
before constructing keys, indices or hashes. This is what makes the
permutation test return identical data rather than merely an equivalent
likelihood.

Construct `data_hash` with:

```r
digest::digest(
  list(
    candidate_ids = candidate_ids,
    camera_ids = camera_ids,
    occasion_ids = occasion_ids,
    observed = observed,
    grouped = grouped
  ),
  algo = "sha256",
  serialize = TRUE
)
```

`sim_to_flexirich_g_data()` must whitelist only:

```r
candidate_pool <- sim$species["species_id"]
effort_weekly <- sim$effort_weekly[
  c("camera_id", "occasion_id", "active_days")
]
detections <- sim$detections[
  c("species_id", "camera_id", "occasion_id", "detected")
]
```

It must not attach the simulator object or any latent table as an attribute.

- [ ] **Step 4: Run focused and full tests**

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-infer-data.R")'
Rscript scripts/run_tests.R
```

Expected: all tests pass without warnings.

- [ ] **Step 5: Commit the inference-data tranche**

```bash
git add R/infer_data.R tests/testthat/test-infer-data.R
git commit -m "feat: add exact inference data contract"
```

---

### Task 3: Add independent likelihood and membership oracles

**Files:**
- Create: `R/infer_math.R`
- Create: `tests/testthat/helper-goal002-oracles.R`
- Create: `tests/testthat/test-infer-likelihood.R`

**Interfaces:**
- Consumes: `flexirich_g_data`, fixed \(\alpha\), \(b\) and \(\omega\)
- Produces: `member_log_likelihood(data, alpha, camera_effect) -> numeric(C)`
- Produces: `marginal_membership_log_likelihood(member_ll, detected_ever, omega) -> numeric(1)`
- Produces: `conditional_membership_probability(member_ll, detected_ever, omega) -> numeric(C)`
- Produces: `poisson_binomial_pmf(probabilities) -> numeric(length(probabilities) + 1)`
- Test-only exhaustive functions must not be called from production code.

- [ ] **Step 1: Add failing hand and oracle tests**

```r
# tests/testthat/test-infer-likelihood.R
testthat::test_that("stable hazard terms match hand values", {
  log_rate <- log(c(1e-12, 1e-3, 50))
  effort <- c(1L, 7L, 1L)

  testthat::expect_equal(
    log_detect_probability(log_rate, effort),
    log(-expm1(-effort * exp(log_rate))),
    tolerance = 1e-14
  )
  testthat::expect_equal(
    log_nondetect_probability(log_rate, effort),
    -effort * exp(log_rate),
    tolerance = 1e-14
  )
})

testthat::test_that("grouped and rowwise kernels are identical", {
  fixture <- goal002_oracle_fixture()
  grouped <- member_log_likelihood(
    fixture$data,
    fixture$alpha,
    fixture$camera_effect
  )
  rowwise <- oracle_rowwise_member_log_likelihood(
    fixture$data$observed,
    fixture$alpha,
    fixture$camera_effect,
    fixture$data$candidate_ids,
    fixture$data$camera_ids
  )

  tolerance <- 1e-10 * (1 + abs(rowwise))
  testthat::expect_true(all(abs(grouped - rowwise) <= tolerance))
})

testthat::test_that("analytic membership marginalisation matches enumeration", {
  fixture <- goal002_oracle_fixture(C = 4L)
  member_ll <- member_log_likelihood(
    fixture$data,
    fixture$alpha,
    fixture$camera_effect
  )
  analytic <- marginal_membership_log_likelihood(
    member_ll,
    fixture$data$stan_data$detected_ever,
    omega = 0.37
  )
  enumerated <- oracle_enumerated_membership_log_likelihood(
    member_ll,
    fixture$data$stan_data$detected_ever,
    omega = 0.37
  )

  testthat::expect_equal(
    analytic,
    enumerated,
    tolerance = 1e-12 * (1 + abs(enumerated))
  )
})
```

Also test:

- all \(2^C\) membership vectors for \(C\le4\);
- detected candidates have \(q_i=1\);
- all-zero \(q_i\) equals the enumerated posterior ratio;
- increasing sampled zero-detection effort lowers \(q_i\) at fixed parameters;
- reordering grouped rows changes no likelihood;
- centred Goal 001 truth preserves every \(\alpha_i+b_j\);
- Poisson-binomial output is non-negative, has support `0:n`, and sums to one.

`goal002_oracle_fixture()` is defined in
`tests/testthat/helper-goal002-oracles.R`. It returns a complete
`flexirich_g_data`, fixed `alpha`, fixed sum-zero `camera_effect`, and the
corresponding detected-history vector. Its default has \(C=4\), \(J=2\),
both detected and all-zero candidates, and at least two active-days groups.

- [ ] **Step 2: Run the focused tests and confirm failure**

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-infer-likelihood.R")'
```

Expected: failure because the likelihood functions do not exist.

- [ ] **Step 3: Implement stable production mathematics**

```r
# R/infer_math.R
log_detect_probability <- function(log_rate, active_days) {
  hazard <- active_days * exp(log_rate)
  log(-expm1(-hazard))
}

log_nondetect_probability <- function(log_rate, active_days) {
  -active_days * exp(log_rate)
}

member_log_likelihood <- function(data, alpha, camera_effect) {
  validate_flexirich_g_data(data)
  stopifnot(length(alpha) == data$stan_data$C)
  stopifnot(length(camera_effect) == data$stan_data$J)

  g <- data$grouped
  if (nrow(g) == 0L) {
    return(stats::setNames(
      numeric(length(data$candidate_ids)),
      data$candidate_ids
    ))
  }
  eta <- alpha[match(g$species_id, data$candidate_ids)] +
    camera_effect[match(g$camera_id, data$camera_ids)]
  log_p <- log_detect_probability(eta, g$active_days)
  log_q <- log_nondetect_probability(eta, g$active_days)

  contribution <- numeric(nrow(g))
  positive <- g$n_detected > 0L
  negative <- g$n_trials > g$n_detected
  contribution[positive] <- contribution[positive] +
    g$n_detected[positive] * log_p[positive]
  contribution[negative] <- contribution[negative] +
    (g$n_trials[negative] - g$n_detected[negative]) * log_q[negative]

  summed <- rowsum(
    contribution,
    factor(g$species_id, levels = data$candidate_ids),
    reorder = FALSE
  )
  result <- numeric(length(data$candidate_ids))
  matched <- match(rownames(summed), data$candidate_ids)
  result[matched] <- summed[, 1L]
  stats::setNames(result, data$candidate_ids)
}

marginal_membership_log_likelihood <- function(
  member_ll,
  detected_ever,
  omega
) {
  detected <- detected_ever == 1L
  log_add_exp <- function(x, y) {
    anchor <- max(x, y)
    anchor + log(exp(x - anchor) + exp(y - anchor))
  }
  zero_terms <- vapply(
    member_ll[!detected],
    function(ell) {
      log_add_exp(log1p(-omega), log(omega) + ell)
    },
    numeric(1)
  )
  sum(log(omega) + member_ll[detected]) +
    sum(zero_terms)
}

conditional_membership_probability <- function(
  member_ll,
  detected_ever,
  omega
) {
  result <- stats::plogis(stats::qlogis(omega) + member_ll)
  result[detected_ever == 1L] <- 1
  result
}

poisson_binomial_pmf <- function(probabilities) {
  probabilities <- as.numeric(probabilities)
  if (anyNA(probabilities) ||
      any(!is.finite(probabilities)) ||
      any(probabilities < 0 | probabilities > 1)) {
    stop("probabilities must be finite values in [0, 1].", call. = FALSE)
  }

  pmf <- 1
  for (p in probabilities) {
    pmf <- c(pmf * (1 - p), 0) + c(0, pmf * p)
  }
  pmf / sum(pmf)
}
```

The independent enumeration oracle may additionally use the direct
probability-scale expression in moderate-value hand tests.

- [ ] **Step 4: Implement independent test-only enumeration**

`tests/testthat/helper-goal002-oracles.R` must independently:

1. expand each grouped cell to rowwise Bernoulli trials;
2. compute hazards with `log1p(-exp(-hazard))` as a deliberately different
   expression where numerically safe;
3. enumerate `expand.grid(rep(list(0:1), C))`;
4. assign `-Inf` to any vector that marks a detected species as a non-member;
5. add the Bernoulli membership prior and member observation likelihood; and
6. combine vector log weights with an independent log-sum-exp calculation.

No function from `R/infer_math.R` may be called inside the independent oracle.

- [ ] **Step 5: Run focused and full tests**

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-infer-likelihood.R")'
Rscript scripts/run_tests.R
```

Expected: all oracle comparisons pass at their stated tolerances.

- [ ] **Step 6: Commit the oracle tranche**

```bash
git add R/infer_math.R tests/testthat/helper-goal002-oracles.R \
  tests/testthat/test-infer-likelihood.R
git commit -m "test: add Goal 002 likelihood oracles"
```

---

### Task 4: Implement the comparator PMF and proper scores

**Files:**
- Create: `R/infer_scores.R`
- Create: `tests/testthat/test-infer-scores.R`

**Interfaces:**
- Produces: `lower_bound_prior_pmf(C, observed, a, b) -> tibble`
- Produces: `discrete_richness_summary(pmf, levels) -> list`
- Produces: `ranked_probability_score(pmf, truth) -> numeric(1)`
- Provides frozen scoring functions consumed by summaries and pilot gates.

- [ ] **Step 1: Add failing comparator and score tests**

```r
# tests/testthat/test-infer-scores.R
testthat::test_that("lower-bound comparator matches the exact hand case", {
  pmf <- lower_bound_prior_pmf(
    candidate_pool_size = 4L,
    observed_richness = 2L,
    omega_alpha = 1,
    omega_beta = 1
  )

  testthat::expect_identical(pmf$richness, 0:4)
  testthat::expect_equal(pmf$probability, c(0, 0, 0.1, 0.3, 0.6))
  testthat::expect_equal(sum(pmf$probability), 1, tolerance = 1e-14)
  testthat::expect_equal(
    ranked_probability_score(pmf, truth = 3L),
    0.37,
    tolerance = 1e-14
  )
})

testthat::test_that("discrete summaries use frozen tie and quantile rules", {
  pmf <- tibble::tibble(
    richness = 0:4,
    probability = c(0, 0.2, 0.3, 0.3, 0.2)
  )
  out <- discrete_richness_summary(pmf, levels = c(0.8, 0.9, 0.95))

  testthat::expect_identical(out$median, 2L)
  testthat::expect_identical(out$mode, 2L)
  testthat::expect_identical(names(out$intervals), c("80", "90", "95"))
})

testthat::test_that("complete detection produces a point-mass baseline", {
  pmf <- lower_bound_prior_pmf(4L, 4L, 1, 1)
  testthat::expect_equal(pmf$probability, c(0, 0, 0, 0, 1))
})
```

Add analytical mean and variance checks for the beta-binomial, invalid-input
tests, PMF permutation rejection, truth-outside-support rejection, and RPS
range checks.

- [ ] **Step 2: Run focused tests and confirm failure**

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-infer-scores.R")'
```

- [ ] **Step 3: Implement the exact log-scale comparator and RPS**

```r
# R/infer_scores.R
.log_sum_exp <- function(x) {
  anchor <- max(x)
  anchor + log(sum(exp(x - anchor)))
}

lower_bound_prior_pmf <- function(
  candidate_pool_size,
  observed_richness,
  omega_alpha,
  omega_beta
) {
  C <- as.integer(candidate_pool_size)
  O <- as.integer(observed_richness)
  U <- C - O
  u <- 0:U

  log_probability <- lchoose(U, u) +
    lbeta(omega_alpha + O + u, omega_beta + U - u) -
    lbeta(omega_alpha + O, omega_beta)
  probability <- exp(log_probability - .log_sum_exp(log_probability))

  full <- numeric(C + 1L)
  full[O + u + 1L] <- probability
  tibble::tibble(richness = 0:C, probability = full)
}

ranked_probability_score <- function(pmf, truth) {
  C <- max(pmf$richness)
  if (!identical(pmf$richness, 0:C)) {
    stop("pmf richness support must be the ordered integers 0:C.", call. = FALSE)
  }
  if (truth < 0L || truth > C) {
    stop("truth must lie in 0:C.", call. = FALSE)
  }
  cdf <- cumsum(pmf$probability)[seq_len(C)]
  observed_cdf <- as.numeric(truth <= 0:(C - 1L))
  sum((cdf - observed_cdf)^2)
}
```

`discrete_richness_summary()` must define
\(Q(u)=\min\{s:F(s)\ge u\}\), median \(Q(0.5)\), smallest mode in an exact
tie, and equal-tailed intervals
\([Q(\alpha/2),Q(1-\alpha/2)]\).

- [ ] **Step 4: Run focused and full tests**

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-infer-scores.R")'
Rscript scripts/run_tests.R
```

- [ ] **Step 5: Commit the scoring tranche**

```bash
git add R/infer_scores.R tests/testthat/test-infer-scores.R
git commit -m "feat: add richness comparator and proper scores"
```

---

### Task 5: Implement and compile the marginalised Stan model

**Files:**
- Create: `stan/flexirich_g.stan`
- Create: `scripts/check_stan_model.R`
- Modify: `tests/testthat/test-infer-likelihood.R`

**Interfaces:**
- Consumes: structural `stan_data` from Task 2 plus one prior profile
- Produces transformed draws: `alpha`, `camera_effect`, `member_ll`
- Produces generated draws: `q_member`, `g_member`, `S_grid`, `expected_richness`, `y_rep`
- Produces: `compile_flexirich_g_model(force_recompile) -> CmdStanModel` in Task 7.

- [ ] **Step 1: Add failing Stan source-contract tests**

Append tests that require:

```r
stan_source <- readLines("stan/flexirich_g.stan", warn = FALSE)
stan_text <- paste(stan_source, collapse = "\n")

testthat::expect_match(stan_text, "log_mix")
testthat::expect_match(stan_text, "bernoulli_rng")
testthat::expect_match(stan_text, "binomial_rng")
testthat::expect_match(stan_text, "matrix\\[J, B\\] Q")
testthat::expect_false(grepl("int<lower=0,upper=1> g", stan_text))
```

The final assertion prevents a discrete membership parameter from entering the
Stan parameter block.

- [ ] **Step 2: Create the Stan program**

```stan
// stan/flexirich_g.stan
functions {
  real log_detect_from_log_hazard(real log_hazard) {
    if (log_hazard > 20) {
      return 0;
    }
    return log1m_exp(-exp(log_hazard));
  }

  real log_nondetect_from_log_hazard(real log_hazard) {
    if (log_hazard > 700) {
      return negative_infinity();
    }
    return -exp(log_hazard);
  }

  real detection_probability_from_log_hazard(real log_hazard) {
    if (log_hazard > 20) {
      return 1;
    }
    return -expm1(-exp(log_hazard));
  }
}

data {
  int<lower=1> C;
  int<lower=1> J;
  int<lower=0> B;
  int<lower=0> G;
  array[G] int<lower=1, upper=C> species_index;
  array[G] int<lower=1, upper=J> camera_index;
  array[G] int<lower=1, upper=7> active_days;
  array[G] int<lower=0> n_trials;
  array[G] int<lower=0> n_detected;
  array[C] int<lower=0, upper=1> detected_ever;
  matrix[J, B] Q;

  real<lower=0> omega_alpha;
  real<lower=0> omega_beta;
  real mu_alpha_location;
  real<lower=0> mu_alpha_scale;
  real<lower=0> sigma_alpha_scale;
  real<lower=0> sigma_camera_scale;
}

parameters {
  real<lower=0, upper=1> omega;
  real mu_alpha;
  real<lower=0> sigma_alpha;
  vector[C] z_alpha;
  real<lower=0> sigma_camera;
  vector[B] z_camera;
}

transformed parameters {
  vector[C] alpha;
  vector[J] camera_effect;
  vector[C] member_ll;

  alpha = mu_alpha + sigma_alpha * z_alpha;
  camera_effect = sigma_camera * Q * z_camera;
  member_ll = rep_vector(0, C);

  if (G > 0) {
    for (g in 1:G) {
      int i = species_index[g];
      int j = camera_index[g];
      int y = n_detected[g];
      int n0 = n_trials[g] - y;
      real log_hazard =
        log(active_days[g]) + alpha[i] + camera_effect[j];

      if (y > 0) {
        member_ll[i] += y * log_detect_from_log_hazard(log_hazard);
      }
      if (n0 > 0) {
        member_ll[i] += n0 * log_nondetect_from_log_hazard(log_hazard);
      }
    }
  }
}

model {
  omega ~ beta(omega_alpha, omega_beta);
  mu_alpha ~ normal(mu_alpha_location, mu_alpha_scale);
  sigma_alpha ~ normal(0, sigma_alpha_scale);
  z_alpha ~ std_normal();
  sigma_camera ~ normal(0, sigma_camera_scale);
  z_camera ~ std_normal();

  for (i in 1:C) {
    if (detected_ever[i] == 1) {
      target += log(omega) + member_ll[i];
    } else {
      target += log_mix(omega, member_ll[i], 0);
    }
  }
}

generated quantities {
  vector[C] q_member;
  array[C] int<lower=0, upper=1> g_member;
  int<lower=0, upper=C> S_grid = 0;
  real<lower=0, upper=C> expected_richness = 0;
  array[G] int<lower=0> y_rep;

  for (i in 1:C) {
    if (detected_ever[i] == 1) {
      q_member[i] = 1;
      g_member[i] = 1;
    } else {
      q_member[i] = inv_logit(logit(omega) + member_ll[i]);
      g_member[i] = bernoulli_rng(q_member[i]);
    }
    S_grid += g_member[i];
    expected_richness += q_member[i];
  }

  if (G > 0) {
    for (g in 1:G) {
      int i = species_index[g];
      int j = camera_index[g];
      real log_hazard =
        log(active_days[g]) + alpha[i] + camera_effect[j];
      real p = detection_probability_from_log_hazard(log_hazard);

      if (g_member[i] == 1) {
        y_rep[g] = binomial_rng(n_trials[g], p);
      } else {
        y_rep[g] = 0;
      }
    }
  }
}
```

- [ ] **Step 3: Add the compilation and bridge check**

`scripts/check_stan_model.R` must:

1. source the R files;
2. call `check_goal002_cmdstan()`;
3. compute a SHA-256 hash of `stan/flexirich_g.stan`;
4. compile to
   `outputs/goal002/cmdstan/bin/flexirich_g-<first-16-hash-chars>`;
5. construct the deterministic \(C=4\) oracle fixture;
6. run a short fixed-data model check;
7. compare Stan-emitted `member_ll` and `q_member` from 20 sampled draws with
   independent R recalculations to `1e-8`; and
8. print `Goal 002 Stan bridge: PASS`.

The executable must never be written beside the Stan source.

- [ ] **Step 4: Run syntax, bridge and full tests**

```bash
Rscript scripts/check_stan_model.R
Rscript scripts/run_tests.R
```

Expected: compilation succeeds, the bridge prints `PASS`, and the full suite
passes.

- [ ] **Step 5: Commit the model tranche**

```bash
git add stan/flexirich_g.stan scripts/check_stan_model.R \
  tests/testthat/test-infer-likelihood.R
git commit -m "feat: add marginalised FlexiRich-G model"
```

---

### Task 6: Operationalise prior-predictive profile checks

**Files:**
- Create: `R/infer_prior.R`
- Create: `tests/testthat/test-infer-prior.R`
- Create: `scripts/run_goal002_prior_check.R`

**Interfaces:**
- Produces: `goal002_prior_rules() -> named list`
- Produces: `goal002_prior_effort(seed) -> weekly effort table with hash`
- Produces: `simulate_goal002_prior(profile, effort, n_draws, seed) -> list`
- Produces: `assess_goal002_prior(draws, tolerance) -> list`
- Produces: `goal002_prior_report(draws, assessment) -> list`
- The actual PI decision document is created in Task 10 after source and profiles are stable.

- [ ] **Step 1: Add failing nested-history and gate tests**

```r
# tests/testthat/test-infer-prior.R
testthat::test_that("prior histories are nested and bounded", {
  effort <- goal002_prior_effort(seed = 2601L)
  draws <- simulate_goal002_prior(
    goal002_prior_profiles()$primary,
    effort = effort,
    n_draws = 200L,
    seed = 2602L
  )

  testthat::expect_true(all(draws$observed_26 <= draws$observed_208))
  testthat::expect_true(all(draws$observed_208 <= draws$richness))
  testthat::expect_true(all(draws$richness <= 30L))
  testthat::expect_false(anyNA(draws))
})

testthat::test_that("automatic prior rejection rules are immutable", {
  rules <- goal002_prior_rules()
  testthat::expect_identical(rules$n_draws, 10000L)
  testthat::expect_equal(rules$pmf_tolerance, 1e-12)
  testthat::expect_equal(rules$max_observed_mass, 0.95)
  testthat::expect_equal(rules$min_partial_probability, 0.05)
  testthat::expect_identical(
    rules$quantiles,
    c(0, 0.001, 0.01, 0.05, 0.5, 0.95, 0.99, 0.999, 1)
  )
})
```

Add corrupted-draw tests that trigger each automatic rejection independently,
including non-finite values, order violations, a degenerate observed-richness
distribution, an invalid richness PMF and insufficient partial-observation
probability.

- [ ] **Step 2: Run focused tests and confirm failure**

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-infer-prior.R")'
```

- [ ] **Step 3: Implement efficient nested prior simulation**

`goal002_prior_effort(seed)` must generate one Goal 001 default 208-occasion
effort table and record its hash. For each draw:

1. draw \(\omega\), membership, \(\mu_\alpha\), \(\sigma_\alpha\),
   \(\alpha_i\), \(\sigma_b\) and the sum-zero \(b_j\);
2. compute cumulative effort through occasions 26 and 208;
3. compute each member's probability of at least one detection by duration:

\[
P(O_{iK}=1)
=1-\exp\left\{
-\sum_j E_{jK}\exp(\alpha_i+b_j)
\right\};
\]

4. use one uniform variate per candidate to create nested 26/208 observed
   states; and
5. retain the requested parameter, rate, probability and richness summaries.

Use `withr::with_seed()` without mutating caller RNG state.

- [ ] **Step 4: Implement automatic assessment and report tables**

`assess_goal002_prior()` must return one row per rule with:

```r
tibble::tibble(
  rule_id = character(),
  statistic = numeric(),
  threshold = numeric(),
  comparison = character(),
  passed = logical(),
  automatic_outcome = character()
)
```

`goal002_prior_report()` must include the exact quantiles listed in the global
contract for `eta`, `rate`, `p1`, `p7`, `richness`, `observed_26` and
`observed_208`, plus boundary and floating-saturation frequencies.

- [ ] **Step 5: Add the canonical prior-check script**

The script must run all three profiles with exactly 10,000 draws using:

```r
effort_seed <- 62002001L
prior_seed <- c(
  primary = 62002101L,
  sensitivity_membership = 62002201L,
  sensitivity_tail = 62002301L
)
```

It writes machine-readable results under
`outputs/goal002/prior-predictive/`, exits non-zero for any automatic
rejection, and prints a compact table for PI review. It must not write or infer
an ecological verdict.

- [ ] **Step 6: Run focused and full tests**

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-infer-prior.R")'
Rscript scripts/run_tests.R
```

- [ ] **Step 7: Commit the prior-check machinery**

```bash
git add R/infer_prior.R tests/testthat/test-infer-prior.R \
  scripts/run_goal002_prior_check.R
git commit -m "feat: add frozen prior predictive checks"
```

---

### Task 7: Implement fitting, diagnostics and the one-rescue contract

**Files:**
- Create: `R/fit_flexirich_g.R`
- Create: `tests/testthat/test-fit-contract.R`
- Create: `scripts/run_goal002_smoke.R`

**Interfaces:**
- Consumes: `flexirich_g_data`, prior profile, sampler profiles and seed
- Produces: `compile_flexirich_g_model(force_recompile) -> CmdStanModel`
- Produces: `classify_goal002_diagnostics(summary, sampler_diagnostics, thresholds) -> list`
- Produces: `resolve_goal002_attempts(primary, rescue) -> list`
- Produces: `fit_flexirich_g(data, seed, prior_profile, output_dir, allow_rescue) -> flexirich_g_fit`
- A fit contains immutable primary and optional rescue attempts plus terminal status.

#### Pre-pilot richness-diagnostic amendment

The first deterministic smoke run exposed an undefined default
`posterior::ess_tail(S_grid)`: the bounded discrete richness support was
`2:4`, its 95% quantile was the hard maximum 4, and the implementation's
indicator `S_grid <= 4` was constant. The rescue chains otherwise had zero
divergences, zero maximum-treedepth hits, minimum E-BFMI 0.815 and clean
continuous diagnostics. This is resolved before any frozen pilot fit by
diagnosing the Rao--Blackwellised richness distribution rather than the
additional Bernoulli RNG used to generate `S_grid`.

For HMC draw \(d\), compute the conditional Poisson-binomial PMF

\[
p_d(s)=P(S_{\mathrm{grid}}=s\mid q_{\cdot d})
\]

and its posterior mean
\(\bar p(s)=D^{-1}\sum_{d=1}^{D}p_d(s)\). With \(\tau=0.05\):

1. among proper lower cutoffs
   \(t\in\{S_{\mathrm{obs}},\ldots,C-1\}\), select \(t_L\) for which
   \(0<\sum_{s\le t}\bar p(s)<1\) is closest to \(\tau\);
2. among proper upper cutoffs
   \(t\in\{S_{\mathrm{obs}}+1,\ldots,C\}\), select \(t_U\) analogously from
   \(0<\sum_{s\ge t}\bar p(s)<1\);
3. break equal-distance ties by preferring the larger tail mass, then the more
   extreme cutoff: smaller \(t_L\) or larger \(t_U\); and
4. form continuous draw series
   \(L_d=\sum_{s\le t_L}p_d(s)\) and
   \(U_d=\sum_{s\ge t_U}p_d(s)\).

Apply the unchanged \(\widehat R\le1.01\), bulk ESS \(\ge400\) and tail ESS
\(\ge400\) gates to `expected_richness`, \(L_d\) and \(U_d\), as well as the
other monitored continuous quantities. Persist the selected cutoffs, mean
tail masses and their row-level diagnostics in each attempt's diagnostic
metadata.

`S_grid` receives no \(\widehat R\) or ESS gate because it is a
Bernoulli-RNG generated quantity. It must still be integer-valued, lie in
\([S_{\mathrm{obs}},C]\), reconstruct exactly from `g_member`, and later agree
with the Rao--Blackwellised PMF within the specified Monte Carlo bound. Do not
jitter it, waive a non-finite default ESS opportunistically, or assign a
fabricated ESS.

If \(C=S_{\mathrm{obs}}\), record `structural_point_mass`, require exact
`q_member = g_member = 1` and `S_grid = S_obs`, and mark the richness-tail
metrics explicitly not applicable. If \(C>S_{\mathrm{obs}}\), failure to
construct two nontrivial finite tail series, or a constant/non-finite derived
tail diagnostic, fails closed as `richness_tail_degenerate`.

- [ ] **Step 1: Add failing pure diagnostic and attempt tests**

```r
# tests/testthat/test-fit-contract.R
testthat::test_that("clean diagnostics require every frozen threshold", {
  diagnostics <- goal002_diagnostic_fixture(clean = TRUE)
  result <- classify_goal002_diagnostics(
    diagnostics$summary,
    diagnostics$sampler,
    goal002_diagnostic_thresholds()
  )

  testthat::expect_true(result$clean)
  testthat::expect_empty(result$reasons)
})

testthat::test_that("each diagnostic defect makes a fit non-clean", {
  defects <- c(
    "divergences", "treedepth", "ebfmi", "rhat", "bulk_ess", "tail_ess"
  )
  for (defect in defects) {
    diagnostics <- goal002_diagnostic_fixture(clean = TRUE)
    diagnostics <- corrupt_goal002_diagnostic(diagnostics, defect)
    result <- classify_goal002_diagnostics(
      diagnostics$summary,
      diagnostics$sampler,
      goal002_diagnostic_thresholds()
    )
    testthat::expect_false(result$clean, info = defect)
    testthat::expect_true(defect %in% result$reasons, info = defect)
  }
})

testthat::test_that("attempt resolution permits at most one rescue", {
  result <- resolve_goal002_attempts(
    primary = goal002_attempt_fixture(clean = FALSE),
    rescue = goal002_attempt_fixture(clean = TRUE)
  )
  testthat::expect_identical(result$terminal_status, "rescue_clean")
  testthat::expect_true(result$rescue_used)
  testthat::expect_length(result$attempts, 2L)
})
```

At the top of `test-fit-contract.R`, define deterministic list constructors
`goal002_diagnostic_fixture()`, `corrupt_goal002_diagnostic()` and
`goal002_attempt_fixture()`. They must use the same field names returned by
`classify_goal002_diagnostics()` and `fit_flexirich_g()`, so the tests exercise
production contracts without invoking CmdStan.

Tests must monitor `omega`, `mu_alpha`, `sigma_alpha`, `sigma_camera`, every
`alpha[i]`, every reconstructed `camera_effect[j]`, all zero-candidate
`q_member[i]`, `expected_richness`, and both derived richness-tail mass
series. `S_grid` is checked through the exact generated-quantity contract
above, not through continuous-chain diagnostics.

In addition to the generic corruption tests, cover:

- the observed bounded-discrete case in which default `ess_tail(S_grid)` is
  `NA` while the Rao--Blackwellised tail diagnostics are finite;
- lower- and upper-bound-dominant PMFs;
- deterministic cutoff tie-breaking;
- the structural-point-mass case \(C=S_{\mathrm{obs}}\);
- fail-closed constant or non-finite derived tail series when
  \(C>S_{\mathrm{obs}}\);
- sticky or chain-shifted `q_member` draws even when generated `S_grid`
  appears well mixed;
- candidate-order invariance;
- exact threshold-boundary behaviour; and
- malformed, out-of-range or non-normalised membership/PMF inputs.

- [ ] **Step 2: Run focused tests and confirm failure**

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-fit-contract.R")'
```

- [ ] **Step 3: Implement source-hashed compilation**

```r
# R/fit_flexirich_g.R
compile_flexirich_g_model <- function(force_recompile = FALSE) {
  check_goal002_cmdstan()
  stan_file <- "stan/flexirich_g.stan"
  source_hash <- digest::digest(stan_file, algo = "sha256", file = TRUE)
  bin_dir <- file.path("outputs", "goal002", "cmdstan", "bin")
  dir.create(bin_dir, recursive = TRUE, showWarnings = FALSE)
  exe_file <- file.path(
    bin_dir,
    paste0("flexirich_g-", substr(source_hash, 1L, 16L))
  )

  cmdstanr::cmdstan_model(
    stan_file = stan_file,
    exe_file = exe_file,
    compile = force_recompile || !file.exists(exe_file)
  )
}
```

- [ ] **Step 4: Implement attempt metadata and sampling**

Every attempt must record:

```r
list(
  attempt_id = character(1),
  sampler_profile_id = character(1),
  seed = integer(1),
  started_at_utc = character(1),
  elapsed_seconds = numeric(1),
  model_source_hash = character(1),
  data_hash = character(1),
  prior_profile = character(1),
  R_version = character(1),
  cmdstanr_version = character(1),
  cmdstan_version = character(1),
  compiler = character(1),
  output_files = character(),
  diagnostics = list(),
  clean = logical(1)
)
```

`fit_flexirich_g()` must:

1. merge the selected prior hyperparameters into structural `stan_data`;
2. compile once by source hash;
3. write the primary attempt under `<output_dir>/primary/`;
4. classify it against the exact clean thresholds;
5. stop if primary is clean or `allow_rescue=FALSE`;
6. otherwise write exactly one rescue under `<output_dir>/rescue/`, using
   `seed + 500000L`;
7. retain both attempts; and
8. return one terminal status without deleting any CSV.

- [ ] **Step 5: Implement the deterministic smoke script**

The smoke script must:

1. simulate \(C=4\), \(S=2\), \(J=2\), \(K=26\), mean log rate
   `log(0.01)`, species SD `0.5`, camera SD `0.2`, with seed `72002001`;
2. create inference data without truth fields;
3. fit with four chains and fit seed `72002101`;
4. compare 20 Stan `member_ll` and `q_member` draws against R oracles;
5. verify detected membership equals one;
6. verify every richness draw is an integer in
   \([S_{\mathrm{obs}},C]\);
7. verify the conditional PMF sums to one;
8. print all diagnostics and terminal status; and
9. exit non-zero unless terminal status is clean.

- [ ] **Step 6: Run focused, smoke and full checks**

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-fit-contract.R")'
Rscript scripts/run_goal002_smoke.R
Rscript scripts/run_tests.R
```

- [ ] **Step 7: Commit the fitting tranche**

```bash
git add R/fit_flexirich_g.R tests/testthat/test-fit-contract.R \
  scripts/run_goal002_smoke.R
git commit -m "feat: add FlexiRich-G fit and rescue contract"
```

---

### Task 8: Implement posterior and predictive summaries

**Files:**
- Create: `R/infer_summary.R`
- Create: `tests/testthat/test-infer-summary.R`

**Interfaces:**
- Consumes: terminal clean `flexirich_g_fit` and candidate IDs
- Produces: `richness_pmf_from_q(q_draws) -> tibble`
- Produces: `posterior_richness_pmf(fit) -> tibble`
- Produces: `summarise_flexirich_g(fit, species_ids) -> flexirich_g_summary`
- Produces: `validate_flexirich_g_summary(summary) -> TRUE` or error
- Non-clean fits return diagnostic metadata and no posterior summary.

- [ ] **Step 1: Add failing summary-contract tests**

```r
# tests/testthat/test-infer-summary.R
testthat::test_that("Rao-Blackwellised richness PMF is coherent", {
  q <- rbind(
    c(1, 1, 0.2, 0.4),
    c(1, 1, 0.3, 0.5)
  )
  pmf <- richness_pmf_from_q(q)

  testthat::expect_identical(pmf$richness, 0:4)
  testthat::expect_equal(sum(pmf$probability), 1, tolerance = 1e-14)
  testthat::expect_equal(sum(pmf$probability[1:2]), 0)
})

testthat::test_that("non-clean fit cannot expose posterior inference", {
  fit <- goal002_fit_fixture(terminal_status = "final_nonclean")
  summary <- summarise_flexirich_g(fit, fit$candidate_ids)

  testthat::expect_identical(summary$terminal_status, "final_nonclean")
  testthat::expect_null(summary$richness)
  testthat::expect_null(summary$membership)
})
```

Define `goal002_fit_fixture()` at the top of the test file as a minimal
`flexirich_g_fit` with four candidates, classed primary/rescue attempt
metadata, deterministic `q_member`, `g_member`, `S_grid`, `y_rep` and
diagnostic matrices. The `final_nonclean` variant contains diagnostics and
metadata but no valid posterior draws.

Add tests for:

- detected membership exactly one;
- finite all-zero membership in `[0,1]`;
- integer `g_member` reconstructing `S_grid` per draw;
- PMF support `0:C` with zero mass below observed richness;
- PMF mean agreeing with mean `expected_richness`;
- generated-draw richness frequencies agreeing with the Rao-Blackwellised PMF
  within a Monte Carlo bound;
- exchangeable all-zero candidates agreeing within Monte Carlo tolerance;
- discrete median, mode and 80/90/95 intervals;
- boundary mass;
- posterior-predictive totals by species and camera;
- exact metadata and validation rejection of corruption.

- [ ] **Step 2: Run focused tests and confirm failure**

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-infer-summary.R")'
```

- [ ] **Step 3: Implement Rao-Blackwellised richness mass**

```r
# R/infer_summary.R
richness_pmf_from_q <- function(q_draws) {
  q_draws <- as.matrix(q_draws)
  C <- ncol(q_draws)
  per_draw <- t(apply(q_draws, 1L, poisson_binomial_pmf))
  probability <- colMeans(per_draw)

  tibble::tibble(
    richness = 0:C,
    probability = probability / sum(probability)
  )
}
```

The summary must use the conditional Poisson-binomial PMF averaged across
continuous posterior draws. The histogram of one generated `S_grid` draw per
HMC draw is a verification diagnostic, not the primary PMF.

- [ ] **Step 4: Implement the classed summary**

For clean fits, return:

```r
list(
  terminal_status = "primary_clean",
  rescue_used = FALSE,
  richness = list(
    pmf = tibble::tibble(),
    mean = numeric(1),
    median = integer(1),
    mode = integer(1),
    intervals = list(),
    observed = integer(1),
    candidate_pool = integer(1),
    boundary_mass = numeric(2)
  ),
  membership = tibble::tibble(
    species_id = character(),
    detected = logical(),
    probability = numeric()
  ),
  effects = list(),
  posterior_predictive = list(),
  diagnostics = list(),
  metadata = list()
)
```

Posterior predictive summaries must include observed and replicated:

- total detections;
- detections per candidate;
- detections per camera; and
- frequencies of zero-, one- and two-detection candidates.

- [ ] **Step 5: Run focused and full tests**

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-infer-summary.R")'
Rscript scripts/run_tests.R
Rscript scripts/run_goal002_smoke.R
```

- [ ] **Step 6: Commit the summary tranche**

```bash
git add R/infer_summary.R tests/testthat/test-infer-summary.R
git commit -m "feat: add posterior richness summaries"
```

---

### Task 9: Implement manifests, terminal statuses and gate aggregation

**Files:**
- Create: `R/goal002_pilot.R`
- Create: `tests/testthat/test-goal002-pilot.R`
- Create: `scripts/run_goal002_pilot.R`
- Create: `config/goal002_development_manifest.csv`

**Interfaces:**
- Produces: `goal002_development_manifest() -> tibble(6 rows)`
- Produces: `goal002_frozen_manifest() -> tibble(96 rows)`
- Produces: `validate_goal002_manifest(manifest, phase) -> TRUE` or error
- Produces: `goal002_gate_values(run_result, C) -> one-row tibble`
- Produces: `evaluate_goal002_gates(results) -> list`
- Produces a resume-safe dispatcher that never replaces a run.

- [ ] **Step 1: Add failing manifest-cardinality tests**

```r
# tests/testthat/test-goal002-pilot.R
testthat::test_that("development manifest has one independent row per cell", {
  manifest <- goal002_development_manifest()
  testthat::expect_equal(nrow(manifest), 6L)
  testthat::expect_setequal(manifest$true_richness, c(8L, 20L, 27L))
  testthat::expect_setequal(manifest$n_occasions, c(26L, 208L))
  testthat::expect_true(all(manifest$prior_profile == "primary"))
  testthat::expect_false(anyDuplicated(manifest$simulation_seed))
  testthat::expect_false(anyDuplicated(manifest$fit_seed))
})

testthat::test_that("frozen manifest contains exactly 60 plus 36 fits", {
  manifest <- goal002_frozen_manifest()
  testthat::expect_equal(sum(manifest$run_type == "primary"), 60L)
  testthat::expect_equal(sum(manifest$run_type == "sensitivity"), 36L)
  testthat::expect_equal(nrow(manifest), 96L)
  testthat::expect_true(all(
    manifest$replicate[manifest$run_type == "sensitivity"] <= 3L
  ))
  testthat::expect_false(anyDuplicated(manifest$run_id))
})
```

- [ ] **Step 2: Add failing non-clean policy tests**

```r
testthat::test_that("non-clean runs receive conservative gate values", {
  result <- goal002_run_fixture(status = "final_nonclean", C = 30L)
  gate <- goal002_gate_values(result, C = 30L)

  testthat::expect_false(gate$covered_90)
  testthat::expect_equal(gate$truth_probability, 0)
  testthat::expect_equal(gate$absolute_error, 30)
  testthat::expect_equal(gate$squared_error, 900)
  testthat::expect_equal(gate$rps, 30)
  testthat::expect_true(is.na(gate$signed_error))
})

testthat::test_that("four-year non-clean runs cannot pass recovery gates", {
  results <- goal002_pilot_fixture()
  results$terminal_status[
    results$n_occasions == 208L
  ][1] <- "final_nonclean"
  gates <- evaluate_goal002_gates(results)

  testthat::expect_false(gates$criterion_25$passed)
  testthat::expect_false(gates$criterion_26$passed)
  testthat::expect_false(gates$criterion_27$passed)
  testthat::expect_false(gates$criterion_28$passed)
  testthat::expect_false(gates$criterion_29$passed)
})
```

Define `goal002_run_fixture()` and `goal002_pilot_fixture()` at the top of the
test file. The pilot fixture has all 60 primary and 36 sensitivity rows, clean
terminal statuses, exact truths and deliberately passing synthetic gate
values; each corruption test changes only the field named in that test.

Add tests that:

- fixed coverage denominators remain 10 per cell and 30 per duration;
- rescue-clean results enter inference metrics but retain `rescue_used=TRUE`;
- no default summary call drops `NA`;
- a non-clean four-year sensitivity run fails Criteria 33–34;
- a non-clean six-month run is noncoverage and remains in counts;
- Criterion 22 requires at least 57/60 clean and at least 9/10 per cell;
- every primary and rescue attempt remains addressable;
- duplicate, missing, altered or extra manifest rows are rejected.

- [ ] **Step 3: Implement deterministic seed manifests**

Use these seed namespaces:

```r
development_simulation_seed <- 120020000L + cell_id
development_fit_seed <- 220020000L + cell_id
frozen_simulation_seed <- 320020000L + 100L * cell_id + replicate
frozen_primary_fit_seed <- 420020000L + 100L * cell_id + replicate
frozen_membership_fit_seed <- 520020000L + 100L * cell_id + replicate
frozen_tail_fit_seed <- 620020000L + 100L * cell_id + replicate
```

Define cells in immutable order:

| `cell_id` | true richness | occasions |
|---:|---:|---:|
| 1 | 8 | 26 |
| 2 | 20 | 26 |
| 3 | 27 | 26 |
| 4 | 8 | 208 |
| 5 | 20 | 208 |
| 6 | 27 | 208 |

Primary rows use replicates `1:10`. Sensitivity rows use the identical
simulation seed from primary replicates `1:3` and their profile-specific fit
seed. Write and commit only the six-row development CSV in this task. The
96-row frozen CSV is generated but not committed until Task 10.

- [ ] **Step 4: Implement immutable attempt and gate records**

Every run result must contain:

```r
c(
  "run_id", "run_type", "prior_profile", "cell_id",
  "true_richness", "n_occasions", "replicate",
  "simulation_seed", "fit_seed", "terminal_status",
  "rescue_used", "observed_richness", "data_hash",
  "model_hash", "primary_attempt_path", "rescue_attempt_path",
  "summary_path", "elapsed_seconds"
)
```

`evaluate_goal002_gates()` must use the immutable policy at the top of this
plan. It must return every Criterion 19–35 decision with numerator,
denominator, statistic, threshold, pass status and explanatory reason.

- [ ] **Step 5: Implement the resume-safe dispatcher**

`scripts/run_goal002_pilot.R` accepts exactly:

```sh
Rscript scripts/run_goal002_pilot.R --phase development
Rscript scripts/run_goal002_pilot.R --phase frozen
```

For each manifest row it must:

1. verify manifest and freeze hashes;
2. refuse to run a frozen row without `config/goal002_freeze.csv`;
3. skip only a row with a complete, hash-matching terminal record;
4. reject a partial or mismatched record rather than overwrite it;
5. simulate and fit from manifest seeds;
6. write attempts and terminal summaries atomically below
   `outputs/goal002/<phase>/<run_id>/`; and
7. update a derived run-status table without changing the committed manifest.

- [ ] **Step 6: Run focused and full tests**

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-goal002-pilot.R")'
Rscript scripts/run_tests.R
```

- [ ] **Step 7: Write and verify the development manifest**

```bash
Rscript -e '
for (path in sort(list.files("R", pattern = "\\.R$", full.names = TRUE))) {
  source(path)
}
manifest <- goal002_development_manifest()
stopifnot(validate_goal002_manifest(manifest, "development"))
utils::write.csv(
  manifest,
  "config/goal002_development_manifest.csv",
  row.names = FALSE,
  quote = TRUE
)
'
```

- [ ] **Step 8: Commit the pilot-protocol tranche**

```bash
git add R/goal002_pilot.R tests/testthat/test-goal002-pilot.R \
  scripts/run_goal002_pilot.R config/goal002_development_manifest.csv
git commit -m "feat: freeze Goal 002 pilot protocol"
```

---

### Task 10: Run development checks, adjudicate priors, audit and freeze

**Files:**
- Create: `docs/goals/002-minimal-flexirich-g/PriorPredictiveDecision.md`
- Create: `docs/goals/002-minimal-flexirich-g/Development.md`
- Create: `docs/goals/002-minimal-flexirich-g/Audit.md`
- Create: `config/goal002_frozen_manifest.csv`
- Create: `config/goal002_freeze.csv`
- Modify only if a material pre-freeze defect is found: Goal 002 source or tests

**Interfaces:**
- Consumes: Tasks 1–9 at a clean implementation commit
- Produces: six development results, dated prior decision, independent audit,
  final profiles/settings and an immutable 96-run freeze record
- Frozen fitting is blocked until every gate in this task passes.

- [ ] **Step 1: Run the complete pre-development gate**

```bash
Rscript scripts/run_tests.R
Rscript scripts/check_stan_model.R
Rscript scripts/run_goal002_smoke.R
Rscript -e 'renv::status()'
git status --short --branch
```

Expected: all checks pass, environment is consistent and no unexpected file is
present.

- [ ] **Step 2: Run prior-predictive checks before any recovery fit**

```bash
Rscript scripts/run_goal002_prior_check.R
```

Expected: all automatic rules pass or the freeze stops.

- [ ] **Step 3: Record the dated PI prior decision**

`PriorPredictiveDecision.md` must contain:

```markdown
# Goal 002 Prior-Predictive Decision

## Frozen evidence

Record source commit, profile hashes, effort hash, draw count, seeds,
automatic-rule table, fixed quantile table and generated output identifiers.

## Numerical decision

State pass or fail for every automatic rule without changing a threshold.

## Ecological judgement

Record the PI, UTC date, one permitted verdict for each profile, and a concise
rationale based only on the frozen prior-predictive summaries.

## Interpretation boundary

State explicitly that provisional acceptance applies only to the correctly
specified synthetic pilot and is not empirical camera-trap validation.
```

Replace each instruction with observed evidence. If any verdict is
`revise_before_freeze`, revise once, version the profile, rerun all prior
checks, and update the decision before proceeding. A `reject` verdict or
unresolved second concern blocks the freeze.

- [ ] **Step 4: Commit the prior decision before development fitting**

```bash
git add docs/goals/002-minimal-flexirich-g/PriorPredictiveDecision.md
git commit -m "docs: adjudicate Goal 002 prior profiles"
```

This commit is the immutable evidence that prior decisions preceded recovery
output.

- [ ] **Step 5: Run exactly six development benchmarks**

```bash
Rscript scripts/run_goal002_pilot.R --phase development
```

Record for every cell:

- terminal status and rescue use;
- divergences, treedepth, E-BFMI, maximum R-hat and minimum ESS;
- elapsed time, peak output size and projected 96-fit runtime; and
- whether Stan-to-R oracle checks remain valid.

Development results may set the final primary and rescue sampler profiles.
They may not change priors, recovery metrics, thresholds, pilot replication or
frozen seeds.

Write `Development.md` with the six manifest rows, observed diagnostic and
runtime evidence, any permitted sampler change, the final primary and rescue
profiles, and a statement that no frozen output was viewed.

- [ ] **Step 6: Commit the final development state**

If development requires a sampler-profile change, modify only the explicit
sampler values and profile IDs in `R/infer_config.R`, update their tests, and
rerun the smoke and full suite. Then commit:

```bash
git add R/infer_config.R tests/testthat/test-infer-config.R \
  docs/goals/002-minimal-flexirich-g/Development.md
git commit -m "docs: freeze Goal 002 development settings"
```

If no sampler change is needed, the same commit contains only
`Development.md`.

- [ ] **Step 7: Perform one focused implementation self-review**

Check once:

- every Goal criterion maps to implemented code, a future frozen run, or an
  explicit closure check;
- every production likelihood calculation has an independent oracle;
- no truth field reaches inference;
- no profile, sampler or gate remains implicit;
- no private path or empirical input exists;
- no generated output is staged; and
- no unresolved instructional marker remains.

Repair only material defects, rerun focused and full checks, and stop after one
repair pass.

- [ ] **Step 8: Obtain the independent pre-freeze audit**

The read-only audit must examine the exact clean commit and return:

- mathematical and Stan-to-R oracle verdicts;
- input/truth-isolation verdict;
- diagnostic/rescue verdict;
- prior/scoring/status-policy verdict;
- manifest and privacy verdict;
- exact tests and commands reviewed;
- severity-ranked findings; and
- `READY`, `READY WITH CORRECTIONS`, or `BLOCKED`.

The audit examines the exact clean pre-audit commit. Repair only Blocker or
Major findings before freeze, rerun the required checks once, and obtain a
focused re-review of those findings. Commit any material repair before that
focused re-review: inspect `git diff --name-only`, stage each audited repair
path explicitly, and commit with message
`fix: address Goal 002 pre-freeze audit`. Never use `git add -A`. Minor polish
is recorded and deferred. If a repair changes a prior profile, the
prior-predictive implementation, the inference-data contract, or the model's
prior interpretation, rerun all prior checks and obtain a replacement dated PI
decision before the focused re-review.

- [ ] **Step 9: Record and commit the audit**

Write `Audit.md` with the exact audited commit, audit evidence, findings,
dispositions, any repair commit, focused re-review result and final verdict.
Then:

```bash
git add docs/goals/002-minimal-flexirich-g/Audit.md
git commit -m "docs: record Goal 002 pre-freeze audit"
```

The audit-record commit must precede the freeze record so its Git hash can be
stored immutably.

- [ ] **Step 10: Generate and verify the frozen manifest**

```bash
Rscript -e '
for (path in sort(list.files("R", pattern = "\\.R$", full.names = TRUE))) {
  source(path)
}
manifest <- goal002_frozen_manifest()
stopifnot(validate_goal002_manifest(manifest, "frozen"))
stopifnot(sum(manifest$run_type == "primary") == 60L)
stopifnot(sum(manifest$run_type == "sensitivity") == 36L)
utils::write.csv(
  manifest,
  "config/goal002_frozen_manifest.csv",
  row.names = FALSE,
  quote = TRUE
)
'
```

- [ ] **Step 11: Create the freeze record**

`config/goal002_freeze.csv` must contain one `key,value` row for:

- implementation Git commit;
- audit Git commit and audit verdict;
- prior-decision Git commit;
- Stan source SHA-256;
- every production R source SHA-256;
- prior profile IDs and combined hash;
- sampler profile IDs and combined hash;
- diagnostic-threshold hash;
- scoring-contract hash;
- development-manifest hash;
- frozen-manifest hash;
- CmdStanR and CmdStan versions;
- R version; and
- UTC freeze time.

The frozen pilot dispatcher must verify these values before every run.

- [ ] **Step 12: Commit and verify the freeze boundary**

```bash
git add config/goal002_frozen_manifest.csv config/goal002_freeze.csv
git commit -m "docs: freeze Goal 002 recovery pilot"
git status --short --branch
```

Expected: clean worktree. No model, prior, sampler, gate or manifest change is
permitted after this commit without PI invalidation of the frozen run.

---

### Task 11: Execute the frozen 96-fit pilot

**Files:**
- Generate under ignored paths only:
  `outputs/goal002/frozen/<run_id>/`
- Do not modify committed source, profiles, manifests or gates.

**Interfaces:**
- Consumes: exact Task 10 freeze record
- Produces: one terminal result for every 60 primary and 36 sensitivity row
- Produces no committed fit artefact.

- [ ] **Step 1: Verify the freeze immediately before execution**

```bash
Rscript scripts/run_tests.R
Rscript scripts/check_stan_model.R
Rscript -e 'renv::status()'
git status --short --branch
```

Expected: checks pass and Git is clean at the recorded freeze commit.

- [ ] **Step 2: Run the frozen manifest without alteration**

```bash
Rscript scripts/run_goal002_pilot.R --phase frozen
```

The command may be resumed, but it may not replace a complete run or alter a
seed. Polling intervals are monitoring intervals, not run deadlines.

- [ ] **Step 3: Verify cardinality and immutable statuses**

Run a read-only validation command that asserts:

```r
stopifnot(nrow(results) == 96L)
stopifnot(sum(results$run_type == "primary") == 60L)
stopifnot(sum(results$run_type == "sensitivity") == 36L)
stopifnot(all(results$terminal_status %in% c(
  "primary_clean", "rescue_clean", "final_nonclean"
)))
stopifnot(!anyDuplicated(results$run_id))
stopifnot(all(results$manifest_hash == frozen_manifest_hash))
```

Also verify that each rescue-clean or final-non-clean run retains both attempt
records and that no output identifier occurs under two manifest rows.

- [ ] **Step 4: Apply frozen gate logic once**

Create machine-readable criterion results under
`outputs/goal002/frozen/acceptance/`. Do not change source or thresholds after
viewing them. A code defect invalidates affected results and requires explicit
PI adjudication; weak recovery is a scientific result, not a reason to retune.

- [ ] **Step 5: Stop for the evidence boundary**

Do not add replication, comparators, misspecification or empirical data. Move
only to Task 12 reporting and acceptance.

---

### Task 12: Render the report and close Goal 002

**Files:**
- Create: `analysis/goal002_baseline_recovery.qmd`
- Create: `docs/goals/002-minimal-flexirich-g/Log.md`
- Modify: `docs/goals/002-minimal-flexirich-g/Goal.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: frozen results, immutable gates and all verification evidence
- Produces: a concise regenerated report, durable Goal log and status decision

- [ ] **Step 1: Create the source-only Quarto report**

The report must contain these independently editable sections:

1. estimand, model and interpretation boundary;
2. frozen design and status accounting;
3. prior-predictive evidence and PI decision;
4. HMC diagnostics and rescue use;
5. four-year recovery by true-richness cell;
6. six-month partial-information behaviour;
7. full posterior RPS versus the lower-bound-conditioned comparator;
8. prior sensitivity;
9. posterior predictive checks;
10. every acceptance gate, including failures; and
11. limitations and Goal 003 recommendation.

Every result table must distinguish:

- observed richness;
- posterior inference;
- known simulation truth;
- clean versus non-clean fits; and
- primary versus sensitivity profiles.

Update the README Goal 002 block to include the frozen commands:

```sh
Rscript scripts/run_goal002_prior_check.R
Rscript scripts/run_goal002_pilot.R --phase frozen
quarto render analysis/goal002_baseline_recovery.qmd \
  --output-dir ../outputs/goal002/report
```

No pooled result may replace the six cell-level summaries.

- [ ] **Step 2: Render from one canonical command**

```bash
rm -rf outputs/goal002/report
quarto render analysis/goal002_baseline_recovery.qmd \
  --output-dir ../outputs/goal002/report
```

Expected: a non-empty HTML report under `outputs/goal002/report/`, with no
generated file staged.

- [ ] **Step 3: Run the complete acceptance gate**

```bash
Rscript scripts/run_tests.R
Rscript scripts/setup_cmdstan.R
Rscript scripts/check_stan_model.R
Rscript scripts/run_goal002_smoke.R
Rscript scripts/run_goal002_prior_check.R
Rscript -e 'renv::status()'
quarto render analysis/goal002_baseline_recovery.qmd \
  --output-dir ../outputs/goal002/report
git status --short
```

Record exact test counts, diagnostics, hashes, runtime, render path and file
size.

- [ ] **Step 4: Write the acceptance log**

`Log.md` must contain:

```markdown
# Goal 002 Log

## Outcome

State whether Goal 002 passed, failed informatively, or is blocked.

## Implemented artefacts

List exact source, test, model, configuration, manifest and report files.

## Frozen evidence

Record commits, hashes, versions, seeds, run cardinality, terminal statuses,
rescue use and runtime.

## Acceptance criteria

Record all 41 criteria with numerator, denominator, statistic, threshold,
verdict and evidence identifier.

## Scientific interpretation

Separate observed values, posterior inference and simulation truth. Limit
claims to the correctly specified Goal 001 family.

## Residual limitations

Record prior dependence, weak identification, small pilot replication and all
deferred empirical, comparative and misspecification work.

## Recommendation

Recommend Goal 003, a model repair, the predefined fallback design, or stopping
based on the recorded gates.
```

Replace every instruction with observed evidence.

- [ ] **Step 5: Set Goal status without weakening a gate**

If and only if all hard conditions pass:

```markdown
Status: complete — accepted for Goal 003 planning
```

If a hard condition fails:

```markdown
Status: complete — informative method failure; see Log.md
```

Use this only when the full frozen experiment completed and the method failed
scientifically. Use:

```markdown
Status: blocked — see Log.md
```

when implementation, environment, data integrity or incomplete execution
prevents the scientific decision.

- [ ] **Step 6: Perform one focused final self-review**

Check:

- every Goal criterion maps to exact evidence;
- non-clean fits follow the frozen penalty and denominator policy;
- no threshold or denominator changed after freeze;
- no empirical-validity or superiority claim appears;
- no private data, coordinates or identifying paths appear;
- no generated output is staged;
- no unresolved instructional marker remains; and
- Git diff contains only intended Goal 002 source and records.

Repair material defects once. Do not repeat review-and-polish loops.

- [ ] **Step 7: Commit the acceptance record**

```bash
git add analysis/goal002_baseline_recovery.qmd \
  docs/goals/002-minimal-flexirich-g/Goal.md \
  docs/goals/002-minimal-flexirich-g/Log.md README.md
git commit -m "docs: close Goal 002 recovery pilot"
git status --short --branch
```

Expected: clean current worktree after the commit.

---

## Goal 002 Completion Boundary

Passing Goal 002 demonstrates that the implemented marginal likelihood agrees
with independent small-case oracles, posterior richness is coherent and
bounded, sampling is adequate for the frozen correctly specified scenarios,
and the pilot has the recorded recovery, uncertainty and prior-sensitivity
behaviour.

It does not demonstrate empirical validity, robustness to misspecification,
candidate-pool completeness, unseen-species identity, universal interval
calibration, superiority to another estimator, or applicability beyond the
tested camera-array process.

If the marginalised Stan model is oracle-correct but persistently
pathological, stop and seek PI approval for the separately designed
unseen-richness enumeration and Gauss-Hermite fallback. Do not implement that
fallback inside this plan.
