# Goal 002R Numerical Revision Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development or superpowers:executing-plans to
> implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Replace the rejected order-128 all-zero integral with one
exposure-reduced, mode-adaptive quadrature candidate and produce a new locked
paired-comparison decision.

**Architecture:** The R numerical layer will expose fixed-reduced and adaptive
all-zero integrals over one aggregated exposure. A deterministic screening
script will select the lowest passing adaptive order from 16, 32 and 64, with
fixed order 256 as the sole fallback. The selected calculation will replace
the current Stan all-zero loop before the same six paired cases are rerun.

**Tech stack:** R 4.6.1, CmdStanR 0.9.0, CmdStan 2.38.0, posterior, testthat,
and tidyverse packages already locked by the project.

## Global constraints

- Preserve every scientific invariant in NumericalRevisionDesign.md.
- Preserve the first paired-comparison output and REJECT decision.
- Add no R package dependency.
- Screen only fixed order 256 and adaptive orders 16, 32 and 64.
- Use absolute log-integral tolerance 1e-8.
- Stop if no numerical candidate passes all 750 checks.
- Do not change paired cases, seeds, priors, samplers, health gates or decision
  thresholds.
- Use one focused review and repair only demonstrated implementation defects.

---

## Task 1: Add exposure-reduced quadrature

**Files:**

- Modify: R/goal002r/math.R
- Modify: tests/testthat/test-goal002r-numerics.R

**Interfaces:**

- Produces **goal002r_zero_exposure(zero_history, camera_ids)**, returning a
  named numeric exposure vector in camera order.
- Produces **goal002r_log_m0_fixed(...)**, retaining fixed Gauss-Hermite
  evaluation after exposure reduction.
- Produces **goal002r_log_m0_adaptive(...)**, implementing the approved
  mode-adaptive formula.
- **goal002r_log_m0(...)** delegates to the adaptive calculation.

- [ ] **Step 1: Write failing exposure-reduction tests**

Compare the reduced fixed integral with the current row-wise formula at
sigma_alpha values 0, 0.4, 1.1 and 2.0, including non-zero camera effects.
Require absolute agreement no worse than 1e-12.

- [ ] **Step 2: Run the numerical test file and verify RED**

Run:

~~~sh
Rscript -e 'testthat::test_dir(
  "tests/testthat",
  filter = "goal002r-numerics",
  reporter = "summary",
  stop_on_failure = TRUE,
  stop_on_warning = TRUE
)'
~~~

Expected: failure because the reduced and adaptive functions do not exist.

- [ ] **Step 3: Implement the minimal reduced and adaptive functions**

Aggregate camera exposure, compute adjusted total exposure with stable
log-sum-exp arithmetic, and evaluate the adaptive mode using base-R uniroot()
on w + log(w) = log(B * sigma_alpha^2). Handle zero history and
sigma_alpha == 0 exactly.

- [ ] **Step 4: Add independent-oracle tests**

For moderate and deliberately shifted integrands, compare adaptive orders 16,
32 and 64 with goal002r_reference_log_m0(). Keep the nine output-derived
failure states in the screening task rather than unit-test fixtures.

- [ ] **Step 5: Verify and commit Task 1**

~~~sh
Rscript -e 'testthat::test_dir(
  "tests/testthat",
  filter = "goal002r-numerics",
  reporter = "summary",
  stop_on_failure = TRUE,
  stop_on_warning = TRUE
)'
Rscript scripts/check_goal002r_numerics.R
git diff --check
git add R/goal002r/math.R tests/testthat/test-goal002r-numerics.R
git commit -m "feat: add adaptive Goal002R quadrature"
~~~

## Task 2: Screen the prespecified candidates

**Files:**

- Create: R/goal002r/screening.R
- Create: scripts/screen_goal002r_quadrature.R
- Create: tests/testthat/test-goal002r-screening.R

**Interfaces:**

- **goal002r_screen_rows(draw_count, original_rows, n_additional = 100L)**
  returns 100 unique deterministic rows excluding the original checks.
- **goal002r_read_terminal_collapsed_draws(case_id, terminal_status,
  output_root)** loads required variables from saved CmdStan CSVs.
- **goal002r_screen_quadrature(v1_output_root, output_file)** returns the
  detailed 3,000-row candidate-by-check table and selected method/order.

- [ ] **Step 1: Write failing screening tests**

Test deterministic row selection, exclusion of the original 25 rows, terminal
primary/rescue path resolution, four exact candidates, 750 checks per
candidate and the locked selection precedence: adaptive 16, 32, 64, then fixed
256.

- [ ] **Step 2: Run the screening tests and verify RED**

Run the testthat filter goal002r-screening and expect missing-function
failures.

- [ ] **Step 3: Implement the screening module and thin script**

The script sources existing project code, refuses to overwrite an existing
screen table, runs against outputs/goal002r/paired-comparison, writes
outputs/goal002r/quadrature-revision/numerical-screen.csv, and prints the
selected method/order.

- [ ] **Step 4: Verify and run the screen once**

~~~sh
Rscript -e 'testthat::test_dir(
  "tests/testthat",
  filter = "goal002r-screening",
  reporter = "summary",
  stop_on_failure = TRUE,
  stop_on_warning = TRUE
)'
Rscript scripts/screen_goal002r_quadrature.R
~~~

If no candidate passes all 750 checks, record REJECT and stop the tranche.

- [ ] **Step 5: Audit and commit Task 2**

Check that every case contributes 25 original plus 100 distinct additional
rows, the oracle errors are finite, only four candidates occur, and selection
follows the locked precedence.

~~~sh
git add R/goal002r/screening.R scripts/screen_goal002r_quadrature.R \
  tests/testthat/test-goal002r-screening.R
git commit -m "feat: screen Goal002R quadrature candidates"
~~~

## Task 3: Replace the Stan all-zero calculation

**Files:**

- Modify: R/goal002r/config.R
- Modify: R/goal002r/data.R
- Modify: R/goal002r/fit.R
- Modify: stan/flexirich_g_collapsed.stan
- Modify: tests/testthat/test-goal002r-config.R
- Modify: tests/testthat/test-goal002r-data.R
- Modify: tests/testthat/test-goal002r-numerics.R

**Interfaces:**

- stan_core replaces G0 and the three zero-history arrays with zero_exposure,
  a length-J non-negative vector.
- goal002r_contract()$quadrature_default becomes the screened order.
- Stan log_m0_from_nodes() accepts zero_exposure, computes adjusted exposure
  once, then uses lambert_w0 and the approved adaptive formula.

- [ ] **Step 1: Write failing data and configuration tests**

Require zero_exposure to equal the camera-wise sum of active_days * n_trials,
require obsolete Stan fields to be absent, and require the screened order as
the new default.

- [ ] **Step 2: Verify RED**

Run Goal 002R config/data/numerics tests and confirm failures against the old
Stan interface.

- [ ] **Step 3: Implement the compact R-to-Stan interface**

Remove obsolete zero-history arrays from stan_core and goal002r_stan_data().
Pass the exposure vector and screened nodes/weights.

- [ ] **Step 4: Implement the Stan adaptive integral**

Use the following core:

~~~stan
real log_A = log_sum_exp(log(zero_exposure) + camera_effect);
real log_B = mu_alpha + log_A;
real w = lambert_w0(exp(log_B + 2 * log(sigma_alpha)));
real mode = -w / sigma_alpha;
real scale = inv_sqrt(1 + w);
~~~

Evaluate the approved transformed log-sum-exp. Return zero when total exposure
is zero and the deterministic expression when sigma_alpha == 0.

- [ ] **Step 5: Compile, smoke-test and commit**

~~~sh
Rscript scripts/check_goal002r_numerics.R
Rscript scripts/run_goal002r_smoke.R
Rscript -e 'testthat::test_dir(
  "tests/testthat",
  filter = "goal002r",
  reporter = "summary",
  stop_on_failure = TRUE,
  stop_on_warning = TRUE
)'
git diff --check
git add R/goal002r/config.R R/goal002r/data.R R/goal002r/fit.R \
  stan/flexirich_g_collapsed.stan tests/testthat/test-goal002r-config.R \
  tests/testthat/test-goal002r-data.R tests/testthat/test-goal002r-numerics.R
git commit -m "feat: use adaptive quadrature in Goal002R Stan"
~~~

## Task 4: Run the revised paired decision

**Files:**

- Modify: R/goal002r/paired.R
- Modify: scripts/run_goal002r_paired_comparison.R
- Modify: tests/testthat/test-goal002r-paired-runner.R
- Modify: README.md

**Interfaces:**

- The existing runner targets outputs/goal002r/paired-comparison-v2.
- It uses the screened adaptive order but otherwise preserves all six cases,
  fit seeds, sampler paths, thresholds and six evidence filenames.

- [ ] **Step 1: Write failing version-2 output tests**

Require the revised output root, selected quadrature order, identical paired
data hashes, and unchanged decision thresholds.

- [ ] **Step 2: Implement the minimal runner revision**

Change only the output root and numerical-method metadata needed to identify
the revised candidate. Do not add a manifest, ledger or report renderer.

- [ ] **Step 3: Run the locked verification sequence**

~~~sh
Rscript scripts/check_goal002r_numerics.R
Rscript scripts/run_tests.R
Rscript scripts/run_goal002r_paired_comparison.R
git diff --check
~~~

- [ ] **Step 4: Perform one focused audit**

Verify six identical data hashes, complete original and collapsed path
accounting, no summaries from non-clean fits, 150 passing independent
quadrature checks, faithful thresholds, and reconciliation between
decision.txt and decision-criteria.csv.

Repair only a demonstrated implementation defect, rerun its affected test and
the full suite once, then stop.

- [ ] **Step 5: Commit and push**

~~~sh
git add R/goal002r/paired.R scripts/run_goal002r_paired_comparison.R \
  tests/testthat/test-goal002r-paired-runner.R README.md
git commit -m "feat: evaluate revised Goal002R quadrature"
git push origin main
~~~

## Acceptance and stopping point

The tranche ends with one reconciled revised RETAIN, REVISE or REJECT
decision. Report what passed, what failed, residual scientific risk and the
highest-value next tranche. Do not begin broader calibration or empirical
analysis.
