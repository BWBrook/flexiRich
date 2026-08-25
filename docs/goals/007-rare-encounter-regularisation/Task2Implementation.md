# Goal007 Task 2 — shared-shift calibration implementation

Status: implementation and local validation complete; frozen screen not run
Implemented: 2026-08-25

## Model

`stan/goal007_shared_shift_calibration.stan` is a minimal variant of the proven
Goal006 selection-adjusted likelihood. It changes only the prior
parameterisation of the two class locations:

\[
m_R=a_R+\eta, \qquad m_O=a_O+\eta+\kappa,
\]

with the common shift and contrast deviation sampled directly. Detection-
history likelihoods, fixed between-species spread, Gauss--Hermite selection
adjustment, and sum-zero camera effects are unchanged.

The R adapter in `R/goal007_calibration.R` first creates canonical Goal006
detected-only calibration data, removes the independent prior fields, and adds
only the shared-shift prior inputs. It rejects the independent comparator,
truth, membership, and all-zero-candidate fields; the independent baseline
continues to use the unchanged Goal006 implementation.

`R/goal007_simulation.R` converts frozen Goal007 Task 2 rows into the exact
internal schema of the Goal006 generator. This reuses the proven ecological and
observation process while preserving new Goal007 identifiers and seeds.

## Mathematical and computational evidence

The deterministic and sampled bridge is:

```bash
Rscript scripts/check_goal007_calibration_model.R
```

At committed state `6629cb5f9671afbbcffc4ea86fe75a4b91a17207`, it passed with:

- prior-factor transformation error `8.88e-16`;
- implied-covariance error `0`;
- Stan/R class-location error `3.55e-15`;
- history-likelihood error `2.84e-14`;
- selection-probability error `1.11e-15`;
- selection-adjusted likelihood error `5.00e-12`; and
- sum-zero camera-effect error `8.05e-16`.

The leakage-safe 10-field Gaussian artifact also passed its schema validator.

The reduced two-chain synthetic smoke is:

```bash
Rscript scripts/run_goal007_task2_smoke.R
```

It returned `SMOKE_PASS` at the same clean commit with
`empirical_outcomes_used=false`. The smoke checks compilation, finite posterior
summaries, basic R-hat, and divergences only; its recovery estimates were not
used to alter candidates, profiles, thresholds, or seeds.

The complete local R test suite passed after the model and adapter were added.

## Recovery and decision layer

`R/goal007_recovery.R` creates one compact fit-status row and two recovery rows
per fit. The two recovery targets are the generating class location and the
realised finite-candidate class mean. Non-clean fits retain their fixed
denominators. A core replicate is catastrophic if its fit is non-clean or if
either class has a factor-three error against either target.

The production evaluator applies all 26 frozen gates separately to `shared_F5`
and `shared_F3`, yielding 52 rows. It chooses F5 whenever F5 passes every gate,
considers F3 only if F5 fails, and returns `TASK2_STOP` if neither candidate is
eligible.

`R/goal007_task2_execution.R` freezes the 60 datasets, 180 fits, gate table,
candidate table, first-52-week effort, source hashes, contract hashes, seed
rules, Git commit, software versions, and explicit
`empirical_outcomes_used=false` record. Each fit is published atomically and
can be resumed only from the same commit, manifests, and worker count. Sampler
CSV files are compressed after compact summaries and diagnostics have been
written.

`R/goal007_task2_audit.R` independently recomputes the 52 gate rows,
eligibility table, catastrophic cases, weak-first decision, and deterministic
bridges from the compact evidence. It does not call the production gate
evaluator or its metric helpers. Tests confirm exact agreement on valid
evidence and rejection after deliberate corruption of a recorded gate.

## Entry points

```bash
Rscript scripts/check_goal007_calibration_model.R
Rscript scripts/run_goal007_task2_smoke.R
Rscript scripts/run_goal007_task2_execution_smoke.R
Rscript scripts/run_goal007_task2_screen.R
Rscript scripts/audit_goal007_task2_results.R
```

The execution smoke runs one shared synthetic dataset through the independent,
F5, and F3 production fit-and-publication paths. The 180-fit screen is
Stan-intensive and must run on `deep-server` from a clean pushed commit. Its
compact results must then pass the separate audit before Task 2 is adjudicated.

## Local verification

The recovery evaluator, execution contract, independent replay, manifest
freezing, output confinement, and tamper detection pass their focused tests.
The complete local R suite also passes. An exact-commit execution smoke remains
the final launch check after the implementation is committed and pushed.

No empirical Judbury or Huon Ridge outcome has been read.
