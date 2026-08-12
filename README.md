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

Goal001 and Goal002 remain the runnable scientific foundation. The active
[Goal003 contract](docs/goals/003-prospective-finite-pool-validation/Goal.md)
tests a simpler, regularised finite-pool detection model against transparent
richness baselines, synthetic truth, and temporal species-discovery validation.
Its evaluation-data contract and externally reviewed candidate pool are now
frozen, its transparent comparator suite is complete, and its single
regularised finite-pool candidate has passed prior-predictive, mathematical,
and synthetic end-to-end execution checks. This establishes a trustworthy
candidate implementation, not calibration or predictive superiority; no
candidate model has yet been fitted to empirical Judbury outcomes. The complete
[Task 1 contract](docs/goals/003-prospective-finite-pool-validation/EvaluationDataContract.md)
and [Goal003 contract](docs/goals/003-prospective-finite-pool-validation/Goal.md)
authorise the next tranche: freeze the Task 4 synthetic calibration and
misspecification manifest before launching any calibration batch.
