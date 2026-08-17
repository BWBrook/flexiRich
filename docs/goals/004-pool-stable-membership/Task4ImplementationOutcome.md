# Goal004 Task 4 implementation outcome

Status: implementation verified locally; development batch not run
Recorded: 2026-08-17
Implementation commit: `eed27da7e996a46e8ee8f81089805c9ad29d73af`

## Outcome

The frozen Goal004 Task 4 development screen is implemented and ready for a
separate remote launch decision. This is an implementation result only. The
180 synthetic datasets and 750 scheduled fits have not been run, so none of
G01--G11 has a scientific outcome.

The implementation provides:

- exact, hash-checked scenario, dataset, and fit manifests with 9 scenarios,
  180 datasets, and 750 scheduled fits;
- the class-aware, common-random-number generator with the 20 frozen effort
  blocks;
- matching no-data prior forecasts and Task 2 anchor regression;
- proper scoring for richness, unseen-candidate membership, and prospective
  discovery;
- the fixed-class Goal004, Goal003, occupancy, prior-sensitivity, and
  independent-fringe fit paths;
- exact G01--G11 evaluation with fixed denominators;
- interruption-safe, non-overwriting execution and compact evidence output;
  and
- one production runner, one non-Stan execution check, one nested-model check,
  and one genuine end-to-end smoke.

## Verification evidence

Before the implementation commit:

- the complete repository test suite passed;
- `renv::status()` reported a consistent project;
- the execution hand cases passed without fitting Stan models;
- the generated manifests reproduced the exact 9/180/750 contract; and
- staged-diff and whitespace checks passed.

The clean committed source then passed two checks whose evidence is retained
under ignored, commit-addressed output directories.

### Independent-fringe model

`scripts/check_goal004_nested_model.R` returned `NESTED_CHECK_PASS`.

- Every Stan/R bridge difference passed; the largest reported numerical
  difference was `9.06e-15` for the sum-zero camera effect.
- Core and fringe expected-count identities were exact at the reported
  precision.
- The four-chain no-data fit was terminal clean.
- Core and fringe prior-richness total variation distances were `0.00997` and
  `0.00792`, both below the frozen `0.05` limit.
- Posterior mean discrepancies from the exact core and fringe prior means were
  `0.00844` and `0.0261`, both within four Monte Carlo standard errors.
- No empirical outcomes were used.

### End-to-end Task 4 smoke

`scripts/run_goal004_task4_smoke.R` returned `SMOKE_PASS` for frozen dataset
`g004t4-aligned_mid-26w-r08` and its Goal004 primary fit.

- The sampler was terminal `primary_clean` without rescue.
- There were zero divergences and zero maximum-treedepth hits; maximum R-hat
  was `1.0048`.
- A richness prediction was available and its PMF summed to one within the
  required tolerance.
- The compact fit evidence passed readback and all four raw chain CSVs were
  compressed.
- The fitted-data object excluded synthetic truth fields.
- No empirical outcomes were used.

The smoke's posterior mean richness was `24.50` for a true richness of 25, but
that single favourable example is only a pipeline check and is not evidence
for model accuracy.

## Decision boundary

The implementation is suitable for the frozen development batch. Launching it
will be a new, committed heavy-compute action on `deep-server`. A completed
batch may return `TASK4_PASS`, `TASK4_STOP`, or `TASK4_EXECUTION_STOP`; this
document does not prejudge that result.
