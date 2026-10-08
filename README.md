# flexiRich

[Goal013](docs/goals/013-temporal-mechanism-comparison/Decision.md) completed
500 simulated datasets and 4,000 fits. Annual, array-wide and station-specific
templates are distinguishable under known full-period placement totals, but
their diagnostic patterns do not reproduce the complete Judbury pattern.
Shared service variation also produces misleading state-model selections.
The assessment recommends estimating nuisance variation and testing
seasonality before advancing a field mechanism; unseen richness remains
unvalidated. The [Fable review brief](docs/goals/013-temporal-mechanism-comparison/Fable-review-brief.md)
sets out the next scientific questions, and the
[runbook](docs/goals/013-temporal-mechanism-comparison/Runbook.md) gives the
frozen run, assessment command and status commands.

[Goal012](docs/goals/012-post-assessment-timing/Decision.md) completed a
post-assessment diagnosis of the full Judbury timing record. Detections remain
clustered after conditioning on camera movements, recurring seasons and
13-week totals. The result supports a temporal encounter-process repair but
does not identify a unique mechanism or validate unseen richness. The original
incidence, effort and Goal011 forecasts remain unchanged. See the
[runbook](docs/goals/012-post-assessment-timing/Runbook.md) for reproducible
tables, figures and conditional controls.

[Goal011](docs/goals/011-frozen-temporal-forecasts/Decision.md) completed the
frozen retrospective Judbury forecast assessment. The spatial repair produced
no resolved advantage in predicting additions; both primary models predicted
too many redetections, partly offset by more new discoveries than their means
predicted. Full predictive objects, independent audit, outcome-access receipts,
all sensitivities and the manuscript figure are preserved. The final addition
count was historically disclosed, so this is not a blind confirmatory endpoint.
The subsequent Goal012 diagnosis incorporates the recorded camera movements
and Barry's clarification that independent wombat knowledge is from a nearby
site. Huon Ridge remains unopened.

[Goal010](docs/goals/010-persistent-spatial-comparison/Goal.md) completed the persistent species-by-station comparison using only the
first Judbury year. Its [decision](docs/goals/010-persistent-spatial-comparison/Decision.md)
reports repaired spatial discrepancies, remaining temporal failures and almost
unchanged model-dependent richness. See its [design](docs/goals/010-persistent-spatial-comparison/Design.md)
and [runbook](docs/goals/010-persistent-spatial-comparison/Runbook.md).

Research implementation and validation of an effort-aware estimator of
camera-detectable species richness from a finite candidate pool.

The preceding baseline assessment is
[Goal009](docs/goals/009-first-year-model-criticism/Goal.md): first-year
posterior predictive criticism of the persistent-species/shared-station
baseline, followed by frozen temporal forecasts and targeted simulations.
Its [forecast contract](docs/goals/009-first-year-model-criticism/ForecastContract.md)
also specifies the proposed layers of Huon Ridge assessment. `make test-goal009`
and `make goal009-check` are local checks; empirical fits require deep-server
and tmux. No later detection outcomes are read by the Goal009 runner.

The [Goal009 decision](docs/goals/009-first-year-model-criticism/Decision.md)
now reports clear spatial and temporal failures despite adequate overall
detection counts. The original PPC output had an effort-indexing defect;
corrected results are in `outputs/goal009/ppc-repaired-v2`. Complete original
evidence and corrected-result recovery instructions are retained under
`docs/goals/009-first-year-model-criticism/evidence/`. Neither baseline prior
profile is an approved empirical richness estimate.

[Goal008](docs/goals/008-ecological-information/Decision.md) checked
same-species dependence and finite-pool calculations, first-year Judbury
ecological diagnostics, and a coherent repeat-monitoring experiment proposal.
It motivates testing species-specific station structure before further
class-contrast regularisation. Three later raw records were inadvertently
displayed during worker orientation but excluded from calculations; the
[exposure record](docs/goals/008-ecological-information/Exposure.md) qualifies
future temporal-validation claims. Huon Ridge remains untouched.

An incomplete integrated methods-and-application manuscript now lives under
`manuscript/` and builds through `$HOME/work/makedoc` with
`make manuscript-check` and `make manuscript`. See
[manuscript instructions](manuscript/README.md) and the Goal008 reproduction
commands for the required generated figures.

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
