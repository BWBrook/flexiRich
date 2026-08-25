# Goal007 Task 2 — shared-shift calibration implementation

Status: model implementation and local validation complete; frozen screen not run
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

## Remaining Task 2 work

The frozen 180-fit screen still requires:

1. compact recovery and artifact summaries for both generator and finite-set
   targets;
2. exact evaluation of the 26 Task 2 gates and weak-first F5/F3 selection;
3. a resumable, non-overwriting remote runner;
4. an independently implemented compact-evidence audit; and
5. a clean pushed run commit before launching on `deep-server`.

No empirical Judbury or Huon Ridge outcome has been read.
