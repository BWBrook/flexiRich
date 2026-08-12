# Goal003 Task 3 implementation plan

Status: proposed
Prepared: 2026-08-12

## Purpose

Implement and verify the single approved regularised finite-pool FlexiRich
candidate. Task 3 establishes a trustworthy executable model on synthetic and
prior-predictive inputs. It does not evaluate empirical Judbury outcomes or
claim estimator calibration.

The work follows test-driven development: each behavioural increment begins
with a focused failing test, receives the smallest implementation that makes it
pass, and is then checked against the relevant regression suite. One focused
self-review and repair pass follows the complete implementation.

## Frozen scientific contract

For candidate species \(i\), camera \(j\), and seven-day occasion \(k\),

\[
g_i\sim\operatorname{Bernoulli}(\omega),
\qquad
\omega\sim\operatorname{Beta}(1,1),
\]

and, conditional on membership,

\[
P(y_{ijk}=1\mid g_i=1)
=1-\exp\{-E_{jk}\exp(\alpha_i+b_j)\}.
\]

The non-centred species and camera effects are

\[
\alpha_i=\mu_\alpha+\sigma_\alpha z_i,
\qquad z_i\sim N(0,1),
\]

\[
\mathbf b=\sigma_b\mathbf Q\mathbf z_b,
\qquad \mathbf z_b\sim N(\mathbf0,\mathbf I),
\]

where \(\mathbf Q\) is the existing orthonormal sum-zero basis. The primary
priors are

\[
\mu_\alpha\sim N\{\log(0.02),1.5\},
\quad
\sigma_\alpha\sim N^+(0,1),
\quad
\sigma_b\sim N^+(0,0.75).
\]

Detected candidates are forced members. For an all-zero candidate with member
log likelihood \(\ell_i\), Stan adds

\[
\log\{(1-\omega)+\omega\exp(\ell_i)\},
\]

and its posterior conditional membership probability is

\[
q_i=\operatorname{logit}^{-1}\{\operatorname{logit}(\omega)+\ell_i\}.
\]

Richness and new-species-count distributions are exact posterior mixtures of
Poisson-binomial PMFs. Posterior membership is never approximated with
Bernoulli RNG draws.

## Scope boundaries

Task 3 may use:

- canonical synthetic `flexirich_g_data` objects;
- the frozen candidate-pool size and nine-station design;
- effort-only structures; and
- existing verified likelihood, support, grouping, and Poisson-binomial code.

Task 3 must not:

- fit or inspect candidate-model results from Judbury detections;
- inspect prospective validation outcomes;
- modify frozen baseline priors or sampler settings;
- revive `R/fit_flexirich_g.R` as the Goal003 engine;
- modify `stan/flexirich_g.stan` to serve the new candidate;
- add traits, site occupancy, temporal states, spatial borrowing, or abundance
  interpretation; or
- add a general modelling framework, compatibility layer, or package API.

## Intended file changes

New production files:

- `R/goal003_sampler.R`
- `R/goal003_flexirich.R`
- `stan/goal003_flexirich.stan`

New focused verification files:

- `tests/testthat/test-goal003-sampler.R`
- `tests/testthat/test-goal003-flexirich.R`
- `scripts/check_goal003_flexirich_model.R`
- `scripts/run_goal003_flexirich_prior_check.R`
- `scripts/run_goal003_flexirich_smoke.R`

Minimal existing-file changes:

- `R/infer_math.R`
- `R/infer_data.R`
- `R/goal003_occupancy.R`
- `tests/testthat/test-infer-likelihood.R`
- `tests/testthat/test-infer-data.R`
- `tests/testthat/test-goal003-occupancy.R`
- `tests/testthat/helper-goal003-fixtures.R`, only if a second small synthetic
  fixture is materially clearer than constructing it within a test;
- `docs/goals/003-prospective-finite-pool-validation/Goal.md` and `README.md`
  only at Task 3 closure.

No dependency or lockfile change is expected.

## Task 3.1 — Share only the existing mathematical and effort summaries

### RED

Add focused tests before moving code:

1. In `test-infer-likelihood.R`, test that averaging draw-level
   Poisson-binomial PMFs gives the hand-computed mixture, remains normalised,
   and handles zero uncertain candidates.
2. In `test-infer-data.R`, test that future effort is a complete
   camera-by-occasion grid, sums active days in canonical camera order, accepts
   zero effort, and rejects missing or foreign cameras.
3. Retain the current occupancy hand cases as regression expectations.

Run the two filtered suites and witness failure because the common helpers do
not yet exist in their correct modules.

### GREEN

Move, without a compatibility alias:

- `.goal003_mean_poisson_binomial()` from `R/goal003_occupancy.R` to
  `R/infer_math.R`; and
- `.goal003_future_active_days()` from `R/goal003_occupancy.R` to
  `R/infer_data.R`.

Keep their current lean contracts unless a failing hand case demonstrates a
real defect. Update occupancy calls, then run the inference and occupancy test
files. Do not add new PMF or effort abstractions.

### Acceptance

- The moved helpers pass their independent hand cases.
- Existing occupancy posterior summaries are byte-for-byte identical for the
  deterministic test fixtures.
- `git diff --check` passes.

## Task 3.2 — Extract the narrow shared CmdStan runtime

### RED

Create `test-goal003-sampler.R` with small in-memory diagnostic fixtures. Test:

1. every frozen threshold at its passing boundary;
2. one failure each for divergence, tree depth, E-BFMI, R-hat, bulk ESS, and
   tail ESS;
3. failure-closed behaviour for missing or non-finite diagnostic fields;
4. monitoring of a caller-supplied variable set; and
5. primary-clean, rescue-clean, and final-non-clean attempt resolution without
   changing sampler profiles.

Add an occupancy regression asserting its public fit-result field names,
profile values, and terminal-status vocabulary before extraction.

### GREEN

Create `R/goal003_sampler.R` containing only:

- repository-root discovery;
- source-hashed CmdStan compilation into ignored Goal003 output directories;
- extraction and classification of sampler diagnostics for an explicit
  monitored-variable vector;
- one sampling attempt; and
- primary/rescue resolution.

Pass the tracked Stan filename, cache ID, and executable stem as plain private
function arguments. Do not introduce a descriptor class, registry, or model
object beyond the `cmdstanr` object already returned by compilation.

Refactor `R/goal003_occupancy.R` so that:

- `compile_goal003_occupancy_model()`, `fit_goal003_occupancy()`, and its public
  result remain unchanged;
- the occupancy comparator still monitors its frozen four population
  parameters; and
- its primary and rescue profiles and diagnostic thresholds remain unchanged.

Remove the superseded private occupancy-specific runtime functions. Do not
leave wrappers solely for backwards compatibility.

### Acceptance

- New sampler fixture tests pass.
- All existing occupancy tests pass unchanged in scientific meaning.
- `Rscript scripts/check_goal003_occupancy_model.R` passes.
- No baseline analysis is rerun and no frozen result is rewritten.

Suggested commit: `refactor: share Goal003 Stan runtime`

## Task 3.3 — Add the candidate profiles, data adapter, and R oracle

### RED

Create `test-goal003-flexirich.R` with tests for:

1. exact primary prior values;
2. the three named one-factor sensitivities, verifying that exactly one
   approved hyperparameter differs from primary in each;
3. exact primary and rescue sampler values;
4. candidate data preservation of IDs, grouped counts, `detected_ever`, and
   the sum-zero basis;
5. data hashes changing with prior profile but not input row order;
6. R conditionals matching exhaustive small-pool membership enumeration;
7. detected species having \(q_i=1\); and
8. finite, bounded conditional membership at extreme but representable
   hazards.

### GREEN

In `R/goal003_flexirich.R`, implement:

- `goal003_flexirich_prior_profiles()`;
- `goal003_flexirich_sampler_profiles()`;
- `goal003_flexirich_diagnostic_thresholds()`;
- `prepare_goal003_flexirich_data(data, prior_id = "primary")`;
- a strict private data validator; and
- `goal003_flexirich_conditionals(data, omega, alpha, camera_effect)`.

The adapter must reuse the canonical grouped data and basis rather than
recomputing observations. Its Stan input appends only the selected frozen prior
hyperparameters. The data hash records the source-data hash and prior profile
ID.

The R oracle must use the existing production hazard and membership
mathematics. Independent test enumeration must not call those production
functions.

### Acceptance

- Primary and sensitivity profiles are exact and immutable by convention.
- The data adapter cannot access synthetic truth fields.
- All-zero candidates remain explicit.
- No Judbury input file is opened by the tests or implementation.

## Task 3.4 — Implement and bridge the Stan kernel

### RED

Add a source-contract test requiring:

- analytic `log_mix` membership marginalisation;
- the existing sum-zero basis `Q`;
- `q_member` and `expected_richness`; and
- no `bernoulli_rng`, `binomial_rng`, sampled discrete membership, or
  replicated-data generator.

Create `scripts/check_goal003_flexirich_model.R` before the model exists. It
must use a synthetic fixture only and fail because the new Stan file is absent.

### GREEN

Create `stan/goal003_flexirich.stan`. Retain the already verified stable hazard
algebra from the historical kernel, but include only:

- the approved priors and non-centred parameters;
- `alpha`, exact sum-zero `camera_effect`, and per-species `member_ll`;
- the marginal membership likelihood;
- `q_member`; and
- `expected_richness`.

Do not include posterior membership RNG or posterior predictive RNG.

Add `compile_goal003_flexirich_model()` as a thin wrapper over the shared
runtime. Complete the bridge so that, for every retained draw from one small
synthetic fit, independently recomputed R values agree with Stan for:

- `alpha`;
- `camera_effect` and its zero sum;
- `member_ll`;
- `q_member`; and
- `expected_richness`.

The bridge uses one chain and a small retained sample solely to compare
deterministic transformed quantities; it is not a convergence or recovery
claim.

### Acceptance

- Candidate source-contract tests pass.
- `Rscript scripts/check_goal003_flexirich_model.R` passes locally.
- The existing occupancy bridge still passes.
- Neither tracked historical FlexiRich file is modified.

Suggested commit: `feat: add Goal003 FlexiRich kernel`

## Task 3.5 — Add exact posterior richness and discovery prediction

### RED

Extend `test-goal003-flexirich.R` with hand cases covering:

1. exact richness PMFs from two posterior draws;
2. zero probability below observed richness;
3. candidate identity probabilities as posterior means of `q_member`;
4. zero future effort producing zero new-species probability;
5. one-camera and multiple-camera future hazards with non-zero camera effects;
6. already-detected candidates contributing zero future-first discoveries;
7. the new-species-count PMF over exactly `0:number_unseen`; and
8. malformed draw matrices or incomplete future effort failing clearly.

### GREEN

Implement:

- `summarise_goal003_flexirich_draws()` for pure draw-level summaries;
- a private terminal-clean fit extractor; and
- `predict_goal003_flexirich(result, future_effort = NULL)`.

For draw \(d\) and unseen species \(i\), calculate future-first-detection
probability as

\[
q_{di}\left[1-\exp\left\{-\sum_j
E^{future}_j\exp(\alpha_{di}+b_{dj})\right\}\right].
\]

Use stable hazard arithmetic and ignore zero-effort cameras before exponentiation
so `0 * Inf` cannot create `NaN`. Average exact draw-level PMFs, not draw-level
richness realizations.

Return the same top-level prediction components as the occupancy comparator:

- `richness_pmf`;
- `grid_identity`;
- `new_species_count_pmf`; and
- `future_identity`.

Field names may describe membership rather than occupancy, but the objects must
be directly scoreable by the existing Goal003 evaluation code.

### Acceptance

- Every hand case agrees to numerical tolerance.
- PMFs are finite, non-negative, correctly supported, and normalised.
- A terminal-non-clean result cannot be passed to prediction.

Suggested commit: `feat: add exact Goal003 FlexiRich predictions`

## Task 3.6 — Add candidate fitting and terminal diagnostics

### RED

Add tests using small attempt-record fixtures and a pure resolution helper for:

1. primary-clean return;
2. exactly one rescue after a non-clean primary;
3. final non-clean status after a failed rescue;
4. no predictions from final-non-clean fits;
5. a new output directory beneath `outputs/goal003` being mandatory; and
6. the candidate monitored-variable set including `omega`, all population
   parameters, `expected_richness`, every `alpha`, and every `camera_effect`.

Do not add dependency injection solely to mock `cmdstanr`; unit-test the pure
diagnostic and resolution boundaries, then exercise the real wrapper in the
bounded smoke run.

### GREEN

Implement `fit_goal003_flexirich()` using the shared runtime and the frozen
profiles. Its result has the compact occupancy-like structure:

- `terminal_status`;
- `data`;
- `prior`;
- `output_dir`; and
- `attempts`.

The primary attempt uses four chains, 1,000 warmup, and 1,000 retained draws.
The sole rescue uses four chains, 1,500 warmup, 1,500 retained draws,
`adapt_delta = 0.999`, and tree depth 15. No third attempt or adaptive tuning is
allowed.

### Acceptance

- All diagnostic boundaries are enforced.
- Fit errors are preserved as explicit non-clean attempt reasons.
- Output directories are never overwritten.
- The candidate and occupancy wrappers both use the same verified runtime
  without changing their distinct monitored-variable sets.

Suggested commit: `feat: complete Goal003 FlexiRich fitting`

## Task 3.7 — Freeze and run the prior-predictive check

### RED

Add pure tests for a deterministic prior simulator, including profile
selection, seed reproducibility, exact sum-zero camera effects, finite hazards,
membership support, and the four- versus 26-occasion ordering of expected
detections.

Create `scripts/run_goal003_flexirich_prior_check.R` with a non-overwriting
output contract before the simulator is implemented.

### GREEN

Implement a pure-R prior-predictive function and the runner with:

- 50 candidates;
- nine cameras;
- complete seven-day effort for four and 26 occasions;
- 50,000 draws under a fixed recorded seed;
- primary plus the three frozen one-factor prior profiles; and
- no empirical detection outcomes.

Generative membership draws are appropriate for prior prediction; they are not
used for posterior richness computation. Compute detections analytically over
the accumulated effort and use at most one Bernoulli draw per
candidate-by-prior draw for observed/not-observed status.

Write compact ignored outputs beneath
`outputs/goal003/flexirich-task3-prior-v1/` containing:

- profile-level richness and observed-richness summaries;
- encounter-rate and one-/seven-day detection summaries;
- the fraction of members with less than 0.05 probability of any detection
  over the complete 26-occasion grid;
- finite-value and PMF invariants; and
- seed, Git commit, R/package versions, and profile IDs.

The runner requires a clean committed worktree. Commit and push the prior
simulator and runner before consuming the one frozen prior-predictive run.

Computational invariants are hard gates. Distributional summaries are reviewed
scientifically; they are not compared with Judbury outcomes. Materially
pathological behaviour pauses Task 3 rather than activating prior tuning.

### Acceptance

- The prior runner is deterministic and non-overwriting.
- No Judbury detection or long-window richness file is read.
- All numerical invariants pass.
- The primary and sensitivity summaries are concise enough for a direct user
  decision.

## Task 3.8 — Synthetic terminal-fit smoke on `deep-server`

Create `scripts/run_goal003_flexirich_smoke.R` using one small Goal001 synthetic
scenario: 12 candidates, true richness 8, three cameras, 26 occasions, mean log
rate `log(0.02)`, species standard deviation 0.6, camera standard deviation
0.2, complete effort, simulation seed 30032, and fitting seed 30033. This is
large enough to exercise the posterior without becoming a calibration batch.
Truth may be used only to construct the simulation and to verify that it is
absent from fitted inputs; Task 3 does not score recovery.

The runner must:

- require a clean, recorded Git commit;
- validate the synthetic adapter and prior profile;
- fit the primary candidate with the one permitted rescue if needed;
- preserve all terminal diagnostics;
- produce predictions only for a terminal-clean fit;
- verify PMF and output-schema invariants; and
- write a completion-status record without overwriting a prior run.

Before launch:

1. run the full local test suite and both Stan/R bridges;
2. commit and push the complete Task 3 implementation;
3. prepare or update a clean checkout of that exact commit on `deep-server`;
4. restore the locked R 4.6.1 environment and verify CmdStan 2.38.0; and
5. record the remote working directory and output path.

Launch the smoke in a named `tmux` session with a persistent log and completion
status. Verify that compilation or sampling has begun and the log is advancing.
Then stop and report:

- session name;
- exact Git commit;
- remote working directory;
- log and output paths;
- WSL status command; and
- macOS status command.

Do not poll indefinitely. The user will monitor and wake Codex after completion.

## Task 3.9 — Resumed closeout after remote completion

After the user reports completion:

1. inspect the preserved log, completion status, diagnostics, and output
   invariants;
2. distinguish implementation failure from a scientifically non-clean fit;
3. permit one focused repair only for a demonstrated material implementation
   defect, committed as a new run;
4. rerun the full local tests, both Stan/R bridges, `renv::status()`, and
   `git diff --check`;
5. append a concise Task 3 outcome and residual limitations to `Goal.md`;
6. update `README.md` to identify Task 4 as next only if Task 3 closes cleanly;
7. remove or condense this plan if it no longer provides decision-relevant
   information; and
8. commit and push a clean worktree.

If the synthetic fit is terminal non-clean after its permitted rescue, report
that result without tuning and close the candidate unless a demonstrated
material implementation defect justifies the single repair.

## Verification commands

Focused TDD suites use the repository helper-loading path, for example:

```bash
Rscript -e 'testthat::test_dir(
  "tests/testthat",
  filter = "goal003-flexirich",
  reporter = "summary",
  stop_on_failure = TRUE,
  stop_on_warning = TRUE
)'
```

Before the remote smoke:

```bash
Rscript scripts/run_tests.R
Rscript scripts/check_goal003_occupancy_model.R
Rscript scripts/check_goal003_flexirich_model.R
# Run once, from the clean committed candidate implementation:
Rscript scripts/run_goal003_flexirich_prior_check.R
Rscript -e 'renv::status()'
git diff --check
```

The prior check is local pure-R work. The Stan bridge is deliberately bounded
and local. The terminal-profile smoke and all later simulation/calibration or
empirical batches follow the repository `deep-server`/`tmux` policy.

## Task 3 completion decision

Task 3 is complete only when:

- the R and Stan likelihoods agree independently;
- exact richness and discovery PMFs pass hand cases;
- prior-predictive numerical invariants pass and the distributions are judged
  scientifically tolerable without reference to outcomes;
- the occupancy comparator remains unchanged;
- the synthetic terminal smoke is terminal clean or an explicit user decision
  accepts a scientifically informative non-clean closure; and
- code, inputs, diagnostics, and provenance are committed and reproducible.

The next scientific task is then Goal003 Task 4: freeze the synthetic
calibration and misspecification manifest before any calibration batch is run.
