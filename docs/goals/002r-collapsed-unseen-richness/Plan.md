# Goal 002R Paired-Comparison Implementation Plan

> **For agentic workers:** execute this plan task by task with bounded reviews;
> do not recreate the superseded freeze, ledger or publication machinery.

**Goal:** Decide whether the collapsed Goal 002R computation preserves the
original FlexiRich-G posterior while improving sampling geometry.

**Architecture:** One comparison runner will generate or reconstruct six
prespecified datasets, fit the original and collapsed computations with the
same data and prior, and emit compact posterior-fidelity, sampler-health and
runtime tables. Pure comparison functions remain separate from fit execution
and receive direct unit tests.

**Tech stack:** R 4.6.1, CmdStanR 0.9.0, CmdStan 2.38.0, posterior, testthat,
tidyverse packages already locked by the project.

## Global constraints

- Preserve the finite known-pool, whole-grid detectable-use estimand.
- Use species × camera × seven-day incidence and exact active camera-days.
- Use the same canonical `flexirich_g_data` object for both members of a pair.
- Use the same prior profile within each pair.
- Use quadrature order 128 for the collapsed fit and check selected posterior
  draws against the independent adaptive integral.
- Apply the strict Goal 002 diagnostic thresholds to both computations:
  zero divergences, zero max-treedepth hits, minimum E-BFMI 0.3, maximum R-hat
  1.01, and minimum bulk and tail ESS 400.
- Permit one existing rescue sampler after a non-clean primary fit; no further
  rescue, tuning or adaptive replication.
- Keep all generated fits and tables under ignored
  `outputs/goal002r/paired-comparison/`.
- Do not use empirical Judbury or Huon Ridge data.

## Prespecified comparison cases

The runner will contain a small in-code tibble rather than a manifest system.

| Case | Purpose | Pool | Truth | Cameras | Occasions | Simulation seed | Prior |
|---|---|---:|---:|---:|---:|---:|---|
| `small-easy` | Basic equivalence with substantial detection | 8 | 4 | 3 | 52 | 940001 | primary |
| `small-unseen` | Short, low-rate, unseen-heavy tail | 8 | 6 | 3 | 13 | 940006 | primary |
| `standard-short-low` | Goal 002 scale, low richness | 30 | 8 | 9 | 26 | 940003 | primary |
| `standard-short-high` | Goal 002 scale, high richness | 30 | 27 | 9 | 26 | 940004 | primary |
| `standard-long-medium` | Four-year-scale reference | 30 | 20 | 9 | 208 | 940005 | primary |
| `historical-hard` | Exact former non-clean stress case | 30 | 20 | 9 | 208 | 320020503 | membership sensitivity |

The first five cases use fresh deterministic simulation seeds. Seed `940006`
for `small-unseen` was fixed during design preflight because the initially
proposed seed produced no detections and therefore fell outside the declared
data contract; no model was fitted during that preflight. Baseline fit seeds
are `240001:240005`; collapsed fit seeds are `250001:250005`. Standard cases
use the existing Goal 001 defaults.
`small-easy` uses mean encounter rate 0.004/day and perfect effort;
`small-unseen` uses 0.001/day, `sd_log_rate = 0.8`, `sd_camera = 0.25`, and
perfect effort.

`historical-hard` reconstructs the exact simulation with seed `320020503` and
uses `sensitivity-membership-v1`. The original fit seed is `520020503`; the
collapsed fit seed is `720020503`. It is a computational stress test and does
not contribute recovery evidence.

If a fresh case has no detected candidate, record it as outside the current
contract and stop for PI review rather than substituting another seed.

## Posterior-fidelity criteria

Evaluate fidelity only when both terminal fits are clean. Align the richness
PMFs over the full integer support `0:C`, inserting zero probability where a
summary omits unsupported values.

Each clean pair must satisfy:

- total-variation distance between richness PMFs `<= 0.05`;
- absolute difference in posterior mean richness `<= 0.25` species;
- posterior median richness differs by at most one species;
- each endpoint of the central 90% richness interval differs by at most one
  species; and
- for `omega`, `mu_alpha`, `sigma_alpha`, `sigma_camera` and every
  `camera_effect[j]`, the absolute posterior-mean difference is no greater than
  `0.1 * pooled posterior SD + 3 * combined MCSE`.

These thresholds test computational equivalence, not ecological accuracy.
The historical hard case is exempt from posterior-fidelity criteria when the
original fit remains terminal-non-clean; its purpose is geometry comparison.

## Geometry, numerical and runtime criteria

- Every collapsed terminal fit must be clean under the strict thresholds.
- The collapsed primary-clean count must be at least the original
  primary-clean count.
- The historical hard collapsed fit must be terminal-clean.
- For 25 evenly spaced posterior draws from every clean collapsed fit,
  `log_m0` at order 128 must agree with the independent adaptive integral to
  absolute error `<= 1e-8`.
- The median collapsed/original primary-fit runtime ratio must be `<= 2`.
- All failures, rescues and unsupported cases remain visible in the summary.

## Task 1: Implement pure paired-comparison metrics

**Files:**

- Create: `R/goal002r/comparison.R`
- Create: `tests/testthat/test-goal002r-comparison.R`

**Produces:**

- `goal002r_align_pmf(baseline, collapsed, candidate_pool_size)`
- `goal002r_compare_pmf(baseline, collapsed, candidate_pool_size)`
- `goal002r_compare_shared_draws(baseline_draws, collapsed_draws, camera_count)`
- `goal002r_comparison_decision(case_results, pmf_results, parameter_results,
  quadrature_results)`

Implementation sequence:

1. Write tests using hand-constructed identical and deliberately mismatched
   PMFs and draw matrices.
2. Confirm the tests fail because the functions do not exist.
3. Implement only alignment, total variation, richness-summary differences,
   pooled-SD/MCSE parameter checks and decision precedence.
4. Run `test-goal002r-comparison.R` and the existing Goal 002R tests.

The decision function returns exactly one of `RETAIN`, `REVISE` or `REJECT`
plus a tibble of named criteria and observed values.

## Task 2: Implement the bounded paired runner

**Files:**

- Create: `scripts/run_goal002r_paired_comparison.R`
- Modify: `README.md`

The runner will:

1. source the existing Goal 002 and Goal 002R fitting paths;
2. construct the six cases above;
3. validate that each pair receives byte-identical canonical input data;
4. run the original primary fit and its existing single rescue if required;
5. run the collapsed primary fit and one rescue using the existing rescue
   sampler settings if required;
6. summarise clean terminal fits without interpreting non-clean draws;
7. compute posterior fidelity, sampler health, runtime and quadrature checks;
8. call `goal002r_comparison_decision()` once; and
9. write compact CSV outputs and a plain-text decision summary.

Required outputs:

- `case-results.csv`
- `pmf-fidelity.csv`
- `parameter-fidelity.csv`
- `quadrature-checks.csv`
- `decision-criteria.csv`
- `decision.txt`

No run ledger, immutable manifest, attempt registry, report renderer or
publication bundle is created.

## Task 3: Verify once and report the decision

Run, in order:

```sh
Rscript scripts/check_goal002r_numerics.R
Rscript scripts/run_tests.R
Rscript scripts/run_goal002r_paired_comparison.R
git diff --check
```

Then perform one focused review that checks:

- identical paired data hashes;
- complete accounting of six cases and both model paths;
- no posterior summaries from terminal-non-clean fits;
- faithful implementation of every threshold in this plan;
- quadrature checks use the independent reference path; and
- `decision.txt` agrees with `decision-criteria.csv`.

Repair only a demonstrated implementation defect and rerun the affected check
plus the full test suite once. Do not change cases, seeds, priors, sampler
settings or thresholds after results are visible.

## Acceptance and stopping point

The implementation tranche is complete when all files above exist, tests pass,
the six cases are fully accounted for, and one evidence-backed RETAIN, REVISE
or REJECT decision is produced.

Stop and return the result for PI assessment. Do not begin broader calibration,
comparator benchmarking, candidate-pool construction or empirical analysis in
the same tranche.
