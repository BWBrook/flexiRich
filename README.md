# flexiRich

Research implementation and validation of an effort-aware estimator of
camera-detectable species richness from a finite candidate pool.

## Goal 001

```sh
Rscript bootstrap_env.R
Rscript scripts/run_tests.R
```

The illustrated acceptance scenario is a deterministic explanatory simulation,
not estimator validation or an empirical fit. Render it from the repository
root with:

```sh
quarto render analysis/goal001_simulator.qmd --output-dir ../outputs/goal001
```

Generated artefacts are written under `outputs/` and are not committed.
Huon Ridge data and locations are outside this repository.

## Goal 002

```sh
Rscript bootstrap_env.R
Rscript scripts/setup_cmdstan.R
Rscript scripts/run_tests.R
Rscript scripts/check_stan_model.R
Rscript scripts/run_goal002_smoke.R
Rscript scripts/run_goal002_prior_check.R
Rscript scripts/run_goal002_pilot.R --phase frozen
quarto render analysis/goal002_baseline_recovery.qmd \
  --output-dir ../outputs/goal002/report
```

CmdStan installation is explicit:

```sh
Rscript scripts/setup_cmdstan.R --install
```

Generated inference artefacts remain under `outputs/` and are not committed.

## Goal 003

The current finite-pool candidate and comparator can be checked with:

```sh
Rscript scripts/run_tests.R
Rscript scripts/check_goal003_occupancy_model.R
Rscript scripts/check_goal003_flexirich_model.R
```

The frozen prior-predictive and synthetic smoke runners are non-overwriting
analysis entry points. Stan-intensive batches run on `deep-server` from an
exact committed state; generated artefacts remain under `outputs/`.

## Current research state

Goal002R tested a collapsed computation for the all-zero members of the finite
candidate pool. It failed its locked numerical, richness-PMF, and runtime gates;
the bounded numerical rescue subsequently closed inconclusively. Its executable
path has been retired rather than retained as dormant code. The concise
[closure record](docs/goals/002r-collapsed-unseen-richness/Goal.md) preserves
the decision and the ingredients carried forward.

Goal001 and Goal002 remain the runnable scientific foundation. Goal003 tested a
simpler, regularised finite-pool detection model against transparent richness
baselines and synthetic truth. Its 300-dataset, 840-fit frozen screen completed
successfully, but the candidate failed prespecified short-window calibration
and prior/pool-sensitivity gates. The current model is therefore stopped before
empirical Judbury fitting. The
[Goal003 decision](docs/goals/003-prospective-finite-pool-validation/Decision.md)
records both the original screen and a denominator-only correction that left
the `SCREEN_STOP` decision unchanged.

Goal004 tested whether externally defined encounter classes and independent
core/fringe membership strata could stabilise four-week richness inference.
Its frozen 180-dataset, 750-fit development screen completed without an
execution failure. The candidate solved the nested-pool problem and improved
on Goal003, but failed prespecified short-window calibration, catastrophic-
error, future-identity, and encounter-rate-prior-sensitivity gates. Goal004 is
therefore stopped before a held-out screen or empirical Judbury fitting. The
[Goal004 decision](docs/goals/004-pool-stable-membership/Decision.md) records
both the useful advances and the remaining rate--richness identifiability
limit.

Goal005 maps deployment duration against genuinely independent encounter-rate
calibration. Exact candidate rates did not make four or eight weeks meet the
common standard. A subsequent 108-dataset, 756-fit class-calibration screen was
independently replayed and found conservative frontiers of F3 at 12 weeks and
F5 at 16 and 26 weeks. The selected 12-week/F3 cell then failed its fresh
unbiased replication standard despite clean computation; the imposed 25%
transfer shifts themselves were modest. Goal005 therefore closes as
`CONDITIONAL_FRONTIER_ONLY`: four and eight weeks are not rescued by exact
rates, 12 weeks is an unstable transition, and longer windows retain
conditional promise. Judbury detections remained protected for Goal006 and
Huon Ridge remained untouched for later external validation. See the
[Goal005 decision](docs/goals/005-duration-calibration-frontier/Decision.md).

Goal006 asked whether a leakage-controlled encounter-class
calibration learned from Judbury's first 52 weeks can reach a conservative
F2-or-better precision target and support prospective grid-level inference in
later 12-, 16-, and 26-week windows. Four and eight weeks remain negative
controls. Later fold outcomes are protected behind a calibration-only stop
gate, the full 153-week detected pool remains an operational lower reference
rather than truth, and Huon Ridge remains sealed external validation. See the
[Goal006 contract](docs/goals/006-judbury-calibration-validation/Goal.md).
Its Task 1 freeze is documented in the
[Goal006 Task 1 design](docs/goals/006-judbury-calibration-validation/Task1Design.md);
the approved selection-adjusted calibration implementation and frozen
synthetic-recovery path are documented in the
[Goal006 Task 2 implementation](docs/goals/006-judbury-calibration-validation/Task2Implementation.md).
The frozen recovery run was computationally clean and passed 11/12 gates, but
two occasional-class estimates exceeded the factor-three error guard where
fewer than two were allowed. Goal006 therefore closes as
`CALIBRATION_FEASIBILITY_FAIL`; no empirical class calibration or later
forecast outcome was opened, and the candidate is not ready for Huon Ridge.
See the
[Goal006 decision](docs/goals/006-judbury-calibration-validation/Decision.md).

Goal007 tested a wholly synthetic redesign of the fragile
occasional-class calibration. It compared the unchanged Goal006 model with a
shared-shift hierarchy that lets routine species inform the common encounter-
rate scale while keeping uncertainty in the routine--occasional contrast
explicit. The frozen 180-fit screen was computationally clean and both F5 and
F3 reduced occasional-class RMSE, but both failed profile-bias and severe-
misspecification coverage requirements; F3 also failed the stress-catastrophe
gate. Goal007 therefore closes as `NO_REGULARISATION_CANDIDATE`. Task 3 was not
run, and both Judbury detections and Huon Ridge remain sealed. See the
[Goal007 decision](docs/goals/007-rare-encounter-regularisation/Decision.md).
