# Goal 002R Collapsed Unseen-Richness Computation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: use
> `superpowers:subagent-driven-development` (recommended) or
> `superpowers:executing-plans` to implement this plan task by task. Record
> task acceptance in the execution-progress artefact; do not edit the
> checkboxes in this source plan.

> **Execution gate:** Do not execute any task until the PI explicitly approves
> this Plan, resolves the coverage-verdict decision below, and `Goal.md` says
> `Status: approved for implementation`.

> **Open PI decision from the independent plan audit:** retaining the current
> rule that any stratum with fewer than 7 of 8 nominal 90% intervals covering
> truth selects **REJECT** would falsely reject a calibrated method with
> probability about 0.462 under independent 0.90 coverage. The recommended
> amendment is to keep `>= 7/8` in every stratum as a RETAIN requirement but
> classify a shortfall as **INCONCLUSIVE**. The alternative is to retain the
> approved design's **REJECT** classification knowingly. The implementation
> must encode exactly the PI-selected option in both `Goal.md` and the frozen
> decision tests before Task 1 begins.

**Goal:** Implement, certify and evaluate a computationally collapsed
re-expression of FlexiRich-G that preserves the Goal 002 statistical model
while integrating the encounter effects of never-detected candidates.

**Architecture:** Keep Goal 002 byte-identical as the fresh-data baseline.
Add isolated modules below `R/goal002r/` that partition a validated Goal 002
observation object into detected candidates and an exchangeable all-zero
group, evaluate a certified Gauss--Hermite integral, fit a separate
detected-effects-only Stan model, and reconstruct the complete richness PMF
from a binomial distribution at every posterior draw. Independent adaptive
integration, exhaustive enumeration, fixed-input R/Stan comparison, immutable
phase manifests and pure decision functions separate mathematical
correctness, computation and recovery evidence.

**Tech Stack:** R 4.6.1, `renv`, `testthat`, base-R eigendecomposition,
`stats::integrate`, CmdStanR 0.9.0, CmdStan 2.38.0, `posterior`, `digest`,
`tibble`, `dplyr`, `tidyr`, `withr`, `ggplot2`, Quarto and Git.

## Global Constraints

- The universe is a finite, known regional candidate pool, and the estimand is
  whole-grid detectable-use richness during a defined period.
- Inputs remain complete species × camera × seven-day binary histories with
  exact operational effort in `0:7` active camera-days.
- The Goal 002 ecological model, three accepted prior profiles, two sampler
  profiles and diagnostic thresholds remain unchanged.
- Goal 002 source, configuration, frozen evidence and informative-failure
  verdict remain immutable.
- The fresh baseline is the untouched Goal 002 implementation anchored at
  commit `1c08fb4c372d8961e533c1b3665d1bb9221d9280` and Stan SHA-256
  `659b335b0e9eaffecb2629d06a768c419d00f3c3a8719fa99f67ea6c4171cb91`.
- New R code lives only below `R/goal002r/`; no current top-level `R/*.R`,
  current Goal 002 test, or `stan/flexirich_g.stan` may change.
- Candidate artefacts live below `outputs/goal002r/`. Fresh baseline artefacts
  use only `outputs/goal002/goal002r-baseline/`. Historical Goal 002 output
  namespaces are never overwritten or reused as new evidence.
- Numerical integration replaces only never-detected encounter effects.
  Membership and unseen-count enumeration are exact conditional on sampled
  continuous parameters; the combined computation is not wholly exact.
- The collapsed reduction is valid only while never-detected candidates share
  complete opportunity histories, priors and predictors and are conditionally
  independent given shared parameters.
- Construct one complete `Binomial(U, q_unseen)` PMF per posterior draw and
  average the PMFs. Never evaluate the production PMF at mean `q_unseen`.
- For unseen-member PPC, draw one conditional quadrature node per candidate
  and reuse it over that candidate's complete replicate history.
- Never manufacture a named encounter-effect estimate for a never-detected
  candidate.
- Production uses checked Gauss--Hermite quadrature. Independent adaptive
  integration and exhaustive enumeration remain validation-only code.
- Candidate quadrature orders are `16, 32, 64, 128`; order `256` is the fixed
  convergence reference. Select the first candidate order passing every
  fixture or stop.
- Maximum finite log-integral and load-bearing richness-tail error is `1e-8`;
  PMF normalization tolerance is `1e-12`.
- The adaptive-integration oracle uses `rel.tol = 1e-12`, accepts reported
  relative error only through `1e-11`, and verifies a second expanded-bracket
  result within `1e-10` log units.
- Generated-quantity frequency checks use simultaneous Hoeffding bounds with
  familywise alpha `0.001`. The fixed-input Stan bridge uses seed `62003001`
  and exactly 20,000 generated-quantity replicates.
- Posterior fidelity uses one-dimensional \(W_1\) with a `0.10`-species bound
  for full and split-draw comparisons.
- Absolute loss uses the discrete posterior median; squared loss uses the
  posterior mean.
- Four-year aggregate losses and scores use the unweighted mean of the three
  true-richness-stratum means.
- Bootstrap intervals use exactly 10,000 paired stratified replicates, seed
  `1020021001`, empirical 5th and 95th percentiles and R quantile type 8.
- Fixed confirmation gates are: absolute-loss non-inferiority margin `+0.25`,
  candidate RMSE no greater than raw-richness RMSE, RPS upper bound below
  zero, coverage at least `7/8` per stratum as a RETAIN requirement, no
  posterior-mean absolute error `>= 6`, sensitivity median shift `<= 1`,
  sensitivity maximum shift `<= 3`, lower candidate rescue use, and
  candidate/baseline runtime ratio `<= 2`. The verdict triggered by coverage
  shortfall is the sole unresolved design choice and must be frozen before
  implementation.
- One fit is one scheduled dataset × implementation × prior-profile terminal
  row. Primary and rescue are attempts within that row; failed rows count.
- Development schedules at most 19 fits. Confirmation schedules exactly 78
  fits only after the development and freeze gates pass.
- All fresh development, confirmation, smoke, bootstrap, primary and derived
  rescue seeds are globally distinct and committed before associated evidence
  is read. The historical replay deliberately retains its original
  `320020503`/`520020503` seeds, is labelled audit-only, and collides with no
  fresh or derived Goal 002R seed.
- A completed row is never replaced, excluded or silently rerun. A verified
  interruption remains an immutable incomplete record.
- Truth fields enter scoring only and are unavailable to inference adapters,
  fitters, Stan data, sampler control and posterior summaries.
- A candidate terminal non-clean fit selects **REJECT**. A verified exogenous
  interruption can select **INCONCLUSIVE** only when no prescribed completed
  non-clean attempt exists.
- Decision precedence is **REJECT**, then **INCONCLUSIVE**, then **RETAIN**
  only when every retain requirement passes.
- Permit one focused implementation review and repair before development and
  at most one material defect repair during development. No repair may alter
  the target, prior, sampler, threshold, seed, dataset or decision rule.
- A fit-producing change after a completed development candidate row cannot
  replace that row; it creates a new candidate and stops this goal for a new
  PI design decision.
- No Judbury observations, Huon Ridge data, coordinates, empirical fits,
  site-level model, new comparator or manuscript-performance claim enters
  Goal 002R.
- Stop at a hard failure, after two attempts without material improvement, or
  when another pass would be cosmetic rather than decision-relevant.

## Planned File Structure

### Production and validation code

```text
R/goal002r/
  config.R       # inherited constants, source firewall and path contracts
  data.R         # detected/unseen partition and exchangeability validation
  math.R         # production quadrature, q_unseen and per-draw PMFs
  fit.R          # candidate compile, HMC diagnostics and one rescue
  summary.R      # posterior richness, membership, effects and conditioned PPC
  scores.R       # W1, split-draw checks, losses, RPS and bootstrap
  manifests.R    # truth-separated datasets, fit manifests and seed checks
  artifacts.R    # immutable attempts, hashes, inventories and terminal rows
  dispatch.R     # baseline/candidate phase dispatch and restart policy
  validation.R   # freeze, cardinality, pairing and regeneration checks
  decision.R     # pure criteria and RETAIN/REJECT/INCONCLUSIVE precedence
stan/
  flexirich_g_collapsed.stan
```

### Stable wrappers

```text
scripts/source_goal002r.R
scripts/check_goal002r_environment.R
scripts/check_goal002r_numerics.R
scripts/check_goal002r_stan_model.R
scripts/run_goal002r_smoke.R
scripts/check_goal002r_manifests.R
scripts/run_goal002r.R
scripts/verify_goal002r_freeze.R
scripts/validate_goal002r.R
scripts/audit_goal002r_decision.R
scripts/render_goal002r_report.R
```

### Tracked configuration and phase locks

```text
config/goal002r_quadrature_rules.csv
config/goal002r_numerical_fixtures.csv
config/goal002r_numerical_contract.csv
config/goal002r_goal002_evidence_anchor.csv
config/goal002r_development_datasets.csv
config/goal002r_development_manifest.csv
config/goal002r_confirmation_datasets.csv
config/goal002r_confirmation_manifest.csv
config/goal002r_development_freeze.csv
config/goal002r_confirmation_freeze.csv
config/goal002r_development_repair.csv  # created only if the one repair is used
```

### Tests and independent oracles

```text
tests/testthat/helper-zz-goal002r-load.R
tests/testthat/helper-goal002r-oracles.R
tests/testthat/helper-goal002r-decision-oracle.R
tests/testthat/test-goal002r-config.R
tests/testthat/test-goal002r-data.R
tests/testthat/test-goal002r-numerics.R
tests/testthat/test-goal002r-likelihood.R
tests/testthat/test-goal002r-fit-contract.R
tests/testthat/test-goal002r-summary.R
tests/testthat/test-goal002r-scores.R
tests/testthat/test-goal002r-workflow.R
tests/testthat/test-goal002r-decision.R
tests/testthat/test-goal002r-report.R
```

### Durable records and ignored outputs

```text
docs/goals/002r-collapsed-unseen-richness/
  NumericalDecision.md
  PreDevelopmentAudit.md
  Development.md
  DevelopmentRepairAudit.md  # created only if the one repair is used
  FrozenEvidenceAudit.md
  Log.md
analysis/goal002r_collapsed_repair.qmd

outputs/goal002/goal002r-baseline/{development,confirmation}/
outputs/goal002r/{provenance,cmdstan,numerical,smoke,development,confirmation,report}/
```

All paths stored inside manifests, RDS objects, reports and inventories are
repository-relative. Generated files beneath `outputs/` remain ignored.

## Goal-to-Task Coverage

| Goal requirement | Implemented and verified in |
|---|---|
| AC1: immutable Goal 002 identity | Tasks 1, 9, 10, 13 |
| AC2: unchanged collapsed likelihood | Tasks 3–5 |
| AC3–4: numerical certificate and enumeration | Tasks 3–5, 10 |
| AC5: R/Stan fixed-input agreement | Tasks 5, 10 |
| AC6–7: PMF, support and membership reconstruction | Tasks 4, 7 |
| AC8: truth isolation | Tasks 2, 9, 10 |
| AC9–10: fit budgets, manifests and seeds | Tasks 1, 9, 11, 12 |
| AC11: diagnostics and one rescue | Tasks 6, 9, 11, 12 |
| AC12: confirmation scientific gates | Tasks 8, 12, 13 |
| AC13–14: rescue and runtime | Tasks 8, 12, 13 |
| AC15: immutable rows and reproducibility | Tasks 9–13 |
| AC16: scientific reporting distinctions | Task 13 |
| AC17: independent reviews | Tasks 10 and 13 |

---

### Task 1: Lock inherited contracts and repository boundaries

**Files:**
- Create: `R/goal002r/config.R`
- Create: `scripts/source_goal002r.R`
- Create: `scripts/check_goal002r_environment.R`
- Create: `config/goal002r_goal002_evidence_anchor.csv`
- Create: `tests/testthat/helper-zz-goal002r-load.R`
- Create: `tests/testthat/test-goal002r-config.R`

**Interfaces:**
- `goal002r_contract() -> named list`
- `goal002r_assert_baseline_identity(project_root = ".") -> TRUE` or error
- `goal002r_output_path(implementation, phase, run_id) -> character`
- `source_goal002r(project_root = ".") -> invisible character vector`
- `goal002r_check_environment(project_root = ".") -> data.frame`
- `goal002r_goal002_evidence_snapshot(project_root = ".") -> list`

- [ ] **Step 1: Write RED tests for exact inheritance and isolation**

Assert exact equality with `goal002_prior_profiles()`,
`goal002_sampler_profiles()` and `goal002_diagnostic_thresholds()`. Test the
historical commit/Stan hash, all 13 frozen top-level R hashes, numerical and
decision constants, rejected absolute/unsafe paths, and disjoint baseline and
candidate output namespaces. If historical Goal 002 outputs exist locally,
inventory their repository-relative paths, SHA-256 values and bytes and
verify every acceptance artefact whose identity is recorded in the durable
Goal 002 log. If they are absent, require the recorded identities and closure
commit without recreating the outputs.

The tracked evidence anchor enumerates the eight load-bearing Goal 002
acceptance artefacts, the accepted prior-predictive evidence ID, the aggregate
path-inventory identity and their durable source records. It states explicitly
that Goal 002's legacy raw CmdStan CSVs were path-inventoried but not
individually byte-hashed, so retrospective raw-byte identity is unavailable
and cannot be claimed.

Its schema is:

```text
evidence_role,relative_path,semantic_hash,sha256,bytes,
identity_source,required_when_present,legacy_limitation
```

The acceptance rows are exactly `gate-object.rds`, `criteria.csv`,
`validated-results.rds`, `validation-provenance.rds`, `provenance.csv`,
`validation-checks.csv`, `status-counts.csv` and `path-inventory.csv` below
`outputs/goal002/frozen/acceptance/`, using the SHA-256 and byte counts in the
Goal 002 log. Separate rows bind prior-predictive evidence ID
`893ed2149d3608d8f62ce369c48337df46bbbc882e9cf86ba698307b1daf540d`
and semantic path-inventory hash
`9de0aec0a07f558df6fc0844ae23e26d9f6be861cd1932cb06b4ee8ce6063812`.

```r
testthat::expect_identical(
  goal002r_contract()$quadrature_candidate_orders,
  c(16L, 32L, 64L, 128L)
)
testthat::expect_identical(
  goal002r_contract()$bootstrap_seed,
  1020021001L
)
testthat::expect_identical(
  goal002r_contract()$stan_bridge_ppc,
  list(seed = 62003001L, replicates = 20000L, alpha = 0.001)
)
```

- [ ] **Step 2: Verify RED**

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-goal002r-config.R")'
```

Expected: failure because the Goal 002R contract and loaders do not exist.

- [ ] **Step 3: Implement the single-source contract and loader**

Source sorted top-level `R/*.R` first, then an explicit sorted inventory below
`R/goal002r/`. The test helper loads only the nested directory because the
existing helper already loads top-level files. Recompute the frozen source
hashes bytewise; require the historical closure commit to exist without
requiring `HEAD` to equal it. The environment wrapper checks locked R,
CmdStanR and CmdStan versions without installing or changing software. The
identity check never requires ignored historical outputs in a fresh clone and
never writes into a Goal 002 namespace.

On its first invocation, the snapshot function atomically writes the
presence, symlink target where applicable, path/SHA-256/byte inventory and
aggregate hash to the absent file:

```text
outputs/goal002r/provenance/goal002-starting-inventory.rds
```

Later invocations recompute in memory and require exact agreement; they never
replace the starting inventory.

- [ ] **Step 4: Run focused and historical checks**

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-goal002r-config.R")'
Rscript scripts/check_goal002r_environment.R
Rscript scripts/check_stan_model.R
```

Expected: all pass, including `Goal 002 Stan bridge: PASS`.

- [ ] **Step 5: Review and commit**

```bash
git diff --check
git add R/goal002r/config.R scripts/source_goal002r.R \
  scripts/check_goal002r_environment.R \
  config/goal002r_goal002_evidence_anchor.csv \
  tests/testthat/helper-zz-goal002r-load.R \
  tests/testthat/test-goal002r-config.R
git commit -m "feat: lock Goal 002R contracts"
```

---

### Task 2: Build the collapsed data and exchangeability contract

**Files:**
- Create: `R/goal002r/data.R`
- Create: `tests/testthat/test-goal002r-data.R`

**Interfaces:**
- `prepare_flexirich_g_collapsed_data(data) ->
  flexirich_g_collapsed_data`
- `validate_flexirich_g_collapsed_data(data) -> TRUE` or error
- `.goal002r_common_zero_history(data) -> tibble`

The returned object has exactly:

```r
c(
  "candidate_ids", "detected_ids", "unseen_ids", "camera_ids",
  "detected_ever", "observed", "grouped", "zero_history",
  "stan_core", "source_data_hash", "data_hash", "audit"
)
```

- [ ] **Step 1: Write RED partition, invariance and leakage tests**

Cover detected/unseen complementarity; pool-order and row-order invariance;
`D=0`, `U=0`, `G_all=0`; zero-effort rows; duplicate identifiers; non-binary
detections; corrupted hashes; positive detections assigned to unseen
candidates; and removal of `truth`, `member`, `true_richness`, latent effects
and arbitrary candidate fields.

- [ ] **Step 2: Verify RED**

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-goal002r-data.R")'
```

Expected: failure because the collapsed constructor is absent.

- [ ] **Step 3: Implement canonical partitioning**

Validate the original Goal 002 data first. Derive detected IDs in candidate
order and unseen IDs as the exact complement. Compare every unseen
candidate's ordered
`camera_id, occasion_id, active_days, detected` tuple with the canonical
all-zero history rather than trusting one representative row. Retain identity
metadata with `G_all = 0` for no effort. Reconstruct and validate every
derived field and SHA-256 identity from canonical content.

- [ ] **Step 4: Run focused and Goal 002 data regressions**

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-goal002r-data.R")'
Rscript -e 'testthat::test_file("tests/testthat/test-infer-data.R")'
```

Expected: both pass; existing data code is unchanged.

- [ ] **Step 5: Review and commit**

```bash
git diff --check
git add R/goal002r/data.R tests/testthat/test-goal002r-data.R
git commit -m "feat: add collapsed data contract"
```

---

### Task 3: Establish independent integration and enumeration oracles

**Files:**
- Create: `tests/testthat/helper-goal002r-oracles.R`
- Create: `tests/testthat/test-goal002r-numerics.R`

**Interfaces:**
- `oracle_goal002r_log_m0(...) -> numeric scalar`
- `oracle_goal002r_membership_weights(...) -> data.frame`
- `oracle_goal002r_richness_pmf(...) -> numeric vector`
- `oracle_goal002r_conditional_ppc_moments(...) -> named numeric`

- [ ] **Step 1: Implement validation-only oracles test first**

Use a separately coded, log-scaled `stats::integrate()` oracle and explicitly
enumerate all membership vectors for small pools. For the standardized-Normal
log integrand, expand a finite bracket until both endpoints are decreasing
and at least 40 log units below the current maximum, optimize the mode, and
integrate the mode-scaled left and right pieces. Use
`rel.tol = 1e-12`, `abs.tol = 0`, at most 5,000 subdivisions and
`stop.on.error = TRUE`; require reported relative error `<= 1e-11`, agreement
of the split total with a second expanded-bracket calculation within `1e-10`
log units, or fail the oracle rather than return zero. Preserve `log_m0`
without exponentiating a value that can underflow.

Self-test a finite extreme whose correct log integral is below `-1000`, no
effort (`log_m0 = 0`), deterministic encounter variance, `omega` boundaries,
`U=0`, PMF support and Normal analytic moments.

- [ ] **Step 2: Prove oracle independence**

Use `codetools::findGlobals()` plus source inspection to reject calls to any
production `goal002r_*` integration, node-weight, `q_unseen`, PMF, summary,
scoring or Stan function. The oracle uses its own literal implementation of
the elementary effort-aware hazard; a separate test compares that literal
formula with Goal 002 rather than calling Goal 002 from inside the oracle.

- [ ] **Step 3: Run oracle self-tests**

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-goal002r-numerics.R")'
```

Expected: oracle-only tests pass; production-kernel expectations remain
outside the file until Task 4 adds them.

- [ ] **Step 4: Review and commit**

```bash
git diff --check
git add tests/testthat/helper-goal002r-oracles.R \
  tests/testthat/test-goal002r-numerics.R
git commit -m "test: add independent collapsed-model oracles"
```

---

### Task 4: Implement and freeze the numerical collapsed-richness kernel

**Files:**
- Create: `R/goal002r/math.R`
- Modify: `tests/testthat/test-goal002r-numerics.R`
- Create: `scripts/check_goal002r_numerics.R`
- Create: `config/goal002r_quadrature_rules.csv`
- Create: `config/goal002r_numerical_fixtures.csv`
- Create: `config/goal002r_numerical_contract.csv`

**Interfaces:**
- `goal002r_gauss_hermite_rule(order) -> tibble`
- `goal002r_log_m0(zero_history, mu_alpha, sigma_alpha,
  camera_effect, rule) -> numeric scalar`
- `goal002r_conditional_node_weights(...) -> numeric vector`
- `goal002r_q_unseen(omega, log_m0) -> numeric scalar`
- `goal002r_conditional_richness_pmf(q_unseen, observed_richness,
  candidate_pool_size) -> tibble`
- `goal002r_richness_pmf(q_draws, observed_richness,
  candidate_pool_size) -> tibble`
- `goal002r_read_numerical_contract(project_root = ".") -> list`

- [ ] **Step 1: Extend RED tests for production computation**

Test the physicists' Gauss--Hermite convention, moments through order four,
stable `omega` boundaries, `log_m0 = -Inf`, `sigma_alpha = 0`, `U=0`,
exact support `S_obs:C`, PMF normalization, node-weight normalization,
permutation invariance and equality with exhaustive enumeration.

Include a load-bearing counterexample:

```r
q <- c(0.05, 0.95)
expected <- rowMeans(vapply(
  q,
  function(probability) stats::dbinom(0:2, 2L, probability),
  numeric(3)
))
wrong <- stats::dbinom(0:2, 2L, mean(q))
testthat::expect_gt(max(abs(expected - wrong)), 0.2)
```

- [ ] **Step 2: Verify production RED**

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-goal002r-numerics.R")'
```

Expected: production assertions fail while Task 3 oracle self-tests pass.

- [ ] **Step 3: Implement stable quadrature and PMF reconstruction**

Generate physicists' nodes and weights with the Golub--Welsch
eigendecomposition: zero diagonal and off-diagonal
`sqrt(seq_len(order - 1L) / 2)`. Sort nodes, require finite positive weights,
normalize them to `sqrt(pi)`, and store
`log(weight / sqrt(pi))`. Compute:

```r
alpha_node <- mu_alpha + sqrt(2) * sigma_alpha * rule$node
log_term <- rule$log_standard_weight +
  goal002r_zero_log_likelihood(alpha_node, camera_effect, zero_history)
log_m0 <- goal002r_log_sum_exp(log_term)
```

Handle no effort, `sigma_alpha = 0`, `omega` in `{0, 1}`, `U=0` and
all-`-Inf` terms before generic arithmetic.

- [ ] **Step 4: Materialize the prespecified bounded fixture suite**

The deterministic generator uses:

- all three accepted profiles;
- Normal `mu_alpha` and half-Normal `sigma_alpha`/`sigma_camera` quantiles
  `0.001, 0.01, 0.5, 0.99, 0.999`, plus `sigma_alpha = 1e-8`;
- four centered nine-camera patterns: zero, one opposing pair, and normalized
  first and fourth sum-to-zero basis directions;
- no effort, the canonical 26-occasion prefix and 208-occasion record from
  effort seed `62002001`, and a deterministic overwhelming-effort history;
- `omega = 0, 1e-12, 0.01, 0.5, 0.99, 1 - 1e-12, 1`; and
- `U = 0, 1, 3, 10, 22, 30`.

To avoid an uninformative full factorial, freeze four named families:

1. profile anchors crossed with every camera × effort pattern;
2. one-factor prior-quantile sweeps around each profile anchor;
3. the complete `omega × U` boundary grid at the primary-profile median,
   crossed with all four effort patterns; and
4. all \(2^3\) low/high (`0.001`/`0.999`) corners of
   `mu_alpha`, `sigma_alpha` and `sigma_camera` for each profile, crossed
   with all four camera and four effort patterns.
5. the explicit underflow interaction: the `0.999` `mu_alpha` quantile,
   `sigma_alpha = 1e-8` and overwhelming-effort history for each profile,
   crossed with all four camera patterns.

The script records the family and every realized parameter, so coverage is
auditable. The five families contain at most 712 rows before exact duplicate
removal. Materialize exactly once while all three tracked files are absent:

```bash
Rscript scripts/check_goal002r_numerics.R --materialize
```

For every fixture, compare candidates `16,32,64,128` with both the adaptive
oracle and order 256. Publish the first order passing every finite `1e-8`
log-integral/richness-tail check. If none passes, exit nonzero and publish
nothing.

Tracked schemas are:

```text
goal002r_quadrature_rules.csv:
rule_id,order,node_index,node,weight,log_standard_weight,selected

goal002r_numerical_fixtures.csv:
fixture_id,fixture_family,profile_id,mu_alpha,sigma_alpha,
sigma_camera,camera_pattern_id,effort_pattern_id,omega,
unseen_capacity,analytic_limit

goal002r_numerical_contract.csv:
key,value
```

- [ ] **Step 5: Verify the immutable certificate**

```bash
Rscript scripts/check_goal002r_numerics.R --verify
Rscript -e 'testthat::test_file("tests/testthat/test-goal002r-numerics.R")'
```

Expected: finite maximum errors `<= 1e-8`, PMF error `<= 1e-12`, all analytic
limits and conditional PPC moments pass, oracle independence passes, and
the verifier's before/after SHA-256 inventory proves it left every materialized
byte unchanged.

- [ ] **Step 6: Review and commit**

```bash
git diff --check
git add R/goal002r/math.R tests/testthat/test-goal002r-numerics.R \
  scripts/check_goal002r_numerics.R \
  config/goal002r_quadrature_rules.csv \
  config/goal002r_numerical_fixtures.csv \
  config/goal002r_numerical_contract.csv
git commit -m "feat: certify collapsed richness numerics"
```

---

### Task 5: Implement the parallel collapsed Stan target and R/Stan bridge

**Files:**
- Create: `stan/flexirich_g_collapsed.stan`
- Create: `tests/testthat/test-goal002r-likelihood.R`
- Create: `scripts/check_goal002r_stan_model.R`

**Interfaces:**
- Samples: `omega`, `mu_alpha`, `sigma_alpha`, `z_alpha_detected`,
  `sigma_camera`, `z_camera`
- Transforms: `alpha_detected`, `camera_effect`,
  `member_ll_detected`, `log_m0`, `q_unseen`, `expected_richness`
- Generates: `q_member`, `g_member`, `S_grid` and `y_rep`
- Generates for PPC audit only: `ppc_node_index_unseen[U]`, equal to zero for
  an absent candidate and otherwise the single reused quadrature-node index
- Derives only in R after sampling: the posterior-mean-PMF cutoffs and
  continuous lower/upper richness-tail series
- `Rscript scripts/check_goal002r_stan_model.R` exits zero only after
  fixed-input agreement

- [ ] **Step 1: Write structural and bridge RED tests**

Require `vector[D] z_alpha_detected`, prohibit `vector[C] z_alpha` and every
`alpha_unseen` symbol, and test ordinary data, `D=0`, `U=0`, no effort,
near-zero and broad `sigma_alpha`, overwhelming effort and effectively
all-`-Inf` quadrature terms.

- [ ] **Step 2: Verify RED**

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-goal002r-likelihood.R")'
```

Expected: failure because the candidate Stan source and bridge are absent.

- [ ] **Step 3: Implement the collapsed target**

The load-bearing target is:

```stan
if (D > 0) {
  target += D * log(omega) + sum(member_ll_detected);
}
if (U > 0) {
  target += U * log_mix(omega, log_m0, 0);
}
```

Use the unchanged stable effort-hazard kernel and sum-to-zero camera basis.
Compute `log_m0` by `log_sum_exp` over frozen quadrature terms and
`q_unseen` through stable limiting branches. In generated quantities:

- detected membership is exactly one;
- sample each unseen `g_member` exactly once from its common probability
  `q_unseen`;
- set `S_grid = sum(g_member)` rather than taking an independent binomial
  draw;
- for the same sampled unseen membership, draw one conditional node and reuse
  it for all replicate groups, recording that index in
  `ppc_node_index_unseen`; and
- absent candidates generate only zeros.

The analytic conditional richness PMF remains `Binomial(U, q_unseen)` for
each continuous draw. The generated membership vector and `S_grid` are a
joint PPC realization of that law and must agree exactly on every draw. The
node-index field is PPC provenance only. It must never be summarized or
described as an encounter-effect posterior.

- [ ] **Step 4: Implement the independent fixed-input bridge**

The wrapper first verifies the numerical certificate, compiles a
source-hashed copy below `outputs/goal002r/cmdstan/`, and compares independent
R and Stan target deltas, detected likelihoods, `log_m0`, `q_unseen`,
expected richness and the complete conditional PMF. It verifies generated
support, exact `S_grid == rowSums(g_member)`, absence/node consistency and
exact per-candidate node reuse from the node-index audit field. Using seed
`62003001`, it then takes exactly 20,000 generated-quantity replicates at the
fixed continuous inputs. For the \(K=U+1\) richness-support cells it requires

\[
\max_s\left|\widehat P(S_{\mathrm{grid}}=s)-P(S_{\mathrm{grid}}=s)\right|
\le
\sqrt{\frac{\log(2K/0.001)}{2N}},
\qquad N=20000.
\]

For each bounded PPC aggregate, apply the analogous range-scaled Hoeffding
bound. If \(T\) scalar aggregates are fixed before generation and aggregate
\(t\) lies in \([a_t,b_t]\), require

\[
\left|\widehat E(Z_t)-N^{-1}\sum_d E(Z_{td}\mid\theta_d)\right|
\le
(b_t-a_t)\sqrt{\frac{\log(2T/0.001)}{2N}}.
\]

Tolerances are `1e-8` for finite targets and integrals and `1e-12` for PMF
normalization.

- [ ] **Step 5: Run candidate and historical bridges**

```bash
Rscript scripts/check_goal002r_stan_model.R
Rscript -e 'testthat::test_file("tests/testthat/test-goal002r-likelihood.R")'
Rscript scripts/check_stan_model.R
```

Expected:

```text
Goal 002R Stan bridge: PASS
Goal 002 Stan bridge: PASS
```

No compiled artefact may appear beside a tracked Stan source.

- [ ] **Step 6: Review and commit**

```bash
git diff --check
git add stan/flexirich_g_collapsed.stan \
  tests/testthat/test-goal002r-likelihood.R \
  scripts/check_goal002r_stan_model.R
git commit -m "feat: add collapsed FlexiRich-G target"
```

---

### Task 6: Implement fitting, continuous diagnostics and one rescue

**Files:**
- Create: `R/goal002r/fit.R`
- Create: `tests/testthat/test-goal002r-fit-contract.R`

**Interfaces:**
- `compile_flexirich_g_collapsed_model(force_recompile = FALSE) ->
  CmdStanModel`
- `fit_flexirich_g_collapsed(data, seed, prior_profile, output_dir,
  allow_rescue = TRUE) -> flexirich_g_collapsed_fit`
- `validate_flexirich_g_collapsed_fit(fit) -> TRUE` or error
- `classify_goal002r_diagnostics(...) -> named list`

- [ ] **Step 1: Write RED fit, diagnostic and provenance tests**

Test exact monitored variables, zero divergences and treedepth hits,
E-BFMI `>= 0.3`, R-hat `<= 1.01`, bulk/tail ESS `>= 400`, all equality
boundaries, missing chains/iterations, malformed split draws, source or
numerical-config changes, unsafe directories, partial CSV inventories,
primary-clean/no-rescue, primary-nonclean/rescue-clean and final-nonclean.

- [ ] **Step 2: Verify RED**

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-goal002r-fit-contract.R")'
```

Expected: failure because the candidate fit contract is absent.

- [ ] **Step 3: Implement source-hashed compilation and attempts**

Compile from:

```text
outputs/goal002r/cmdstan/source/<stan-hash-prefix>/
```

and place executables below `outputs/goal002r/cmdstan/bin/`. Every attempt
records SHA-256 and bytes for every raw CmdStan CSV, R/CmdStan/compiler
versions, model and numerical hashes, data hash, seed, sampler ID, elapsed
seconds and diagnostics. Reject existing attempt directories, absolute
recorded paths, the baseline namespace and every path outside the repository.

- [ ] **Step 4: Implement continuous integrated-richness diagnostics**

At draw \(d\), form the conditional binomial PMF
\(p_d(s)=P(S_{\mathrm{grid}}=s\mid q_d)\) and its posterior mean
\(\bar p(s)\). With \(\tau=0.05\):

1. among \(t\in\{S_{\mathrm{obs}},\ldots,C-1\}\), select the proper lower
   mass \(0<\sum_{s\le t}\bar p(s)<1\) closest to \(\tau\);
2. among \(t\in\{S_{\mathrm{obs}}+1,\ldots,C\}\), select the proper upper
   mass \(0<\sum_{s\ge t}\bar p(s)<1\) closest to \(\tau\);
3. break equal-distance ties by preferring the larger mass, then the more
   extreme cutoff: smaller lower cutoff or larger upper cutoff; and
4. monitor continuous series \(L_d=\sum_{s\le t_L}p_d(s)\) and
   \(U_d=\sum_{s\ge t_U}p_d(s)\).

Derive the cutoffs and both tail series in R after sampling from
chain/iteration-indexed `q_unseen` draws; Stan does not generate them because
their cutoffs depend on the posterior-mean PMF across all retained draws.
Apply chain-aware R-hat and ESS to expected richness, \(L_d\), \(U_d\),
community parameters, all detected effects, all camera effects, `log_m0` and
`q_unseen`. Persist cutoffs, mean tail masses and row diagnostics. Check
`S_grid` support, exact reconstruction from `g_member`, and generated
frequencies, but do not gate a bounded discrete RNG on its tail ESS. For
`U=0`, record an explicit structural point mass and mark only tail diagnostics
not applicable. If `U>0` and two finite nonconstant proper tail series cannot
be formed, classify the fit non-clean. No effort remains a valid prior-driven
case.

For \(N\) retained generated draws and \(K=U+1\) support cells, condition on
the continuous draw sequence and compare empirical `S_grid` frequencies with
the mean per-draw PMF using
\(\epsilon=\sqrt{\log(2K/0.001)/(2N)}\). Test exact equality
`S_grid == rowSums(g_member)` separately, so marginal frequency agreement
cannot conceal an incoherent joint realization.

- [ ] **Step 5: Implement the one-rescue wrapper**

The primary uses `primary-sampler-v1` and the manifest seed. Only a non-clean
primary triggers `rescue-sampler-v1` with `fit_seed + 500000L`. Return exactly:

```r
c("primary_clean", "rescue_clean", "final_nonclean")
```

A final-nonclean object retains immutable attempt metadata and diagnostics but
does not expose inferential summaries as valid.

- [ ] **Step 6: Run focused and Goal 002 regressions**

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-goal002r-fit-contract.R")'
Rscript -e 'testthat::test_file("tests/testthat/test-fit-contract.R")'
```

Expected: both pass; Goal 002 tests never dispatch candidate code.

- [ ] **Step 7: Review and commit**

```bash
git diff --check
git add R/goal002r/fit.R \
  tests/testthat/test-goal002r-fit-contract.R
git commit -m "feat: add collapsed fitting contract"
```

---

### Task 7: Implement posterior summaries and conditioned PPC

**Files:**
- Create: `R/goal002r/summary.R`
- Create: `tests/testthat/test-goal002r-summary.R`

**Interfaces:**
- `posterior_richness_pmf_collapsed(fit,
  draws = c("full", "odd", "even")) -> tibble`
- `summarise_flexirich_g_collapsed(fit) ->
  flexirich_g_collapsed_summary`
- `validate_flexirich_g_collapsed_summary(summary) -> TRUE` or error

- [ ] **Step 1: Write RED summary tests**

Require a PMF on `0:C` with exact zero mass below `D`; per-draw averaging;
the fixed discrete quantile definition; detected membership exactly one;
common unseen posterior membership; posterior mean richness reconstructed by
the membership sum; detected-only effect summaries; complete community and
camera summaries; full/odd/even PMFs; valid `D=0`, `U=0` and no-effort
summaries; exact generated `S_grid == rowSums(g_member)` on every retained
draw; absent unseen candidates with zero PPC counts and node index; one-node
reuse for present unseen candidates; and inferential suppression for
final-nonclean fits.

The summary schema contains:

```text
schema_version,implementation,candidate_ids,detected_ids,unseen_ids,
observed_richness,candidate_pool_size,richness,membership,
detected_candidate_effects,community,camera_effects,ppc,
diagnostics,provenance
```

No field named `unseen_candidate_effects` or equivalent is permitted.

- [ ] **Step 2: Verify RED**

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-goal002r-summary.R")'
```

Expected: failure because the collapsed summary is absent.

- [ ] **Step 3: Implement richness and named membership summaries**

Build the PMF from each retained draw's binomial, then average. Reuse the
unchanged Goal 002 discrete summary convention:

\[
Q(p)=\min\{s:F(s)\ge p\}.
\]

Report mean, median, mode, 50%/80%/90% equal-tailed intervals and boundary
mass. Each detected candidate has membership one; every unseen named
candidate receives the posterior mean of the common `q_unseen`, clearly
labelled as marginal membership rather than an identified species effect.

- [ ] **Step 4: Implement conditioned posterior-predictive summaries**

Use the Stan generated quantities after validating one-node-per-unseen-member
reuse against `ppc_node_index_unseen`. Retain that field only inside PPC
provenance; do not expose it as a candidate effect. Report:

- total detected occasions;
- totals by camera;
- totals by detected species;
- frequency-of-detection-count summaries; and
- unseen-member aggregate detections, without presenting named unseen effects.

Check generated means and variances against independent conditional
quadrature moments. Conditioned on the continuous draw sequence, define the
complete scalar PPC aggregate inventory and each statistic's finite range
before inspection; use a familywise-alpha `0.001` Bonferroni/Hoeffding bound
scaled by that range:
\((b_t-a_t)\sqrt{\log(2T/0.001)/(2N)}\) for \(T\) prespecified scalar
aggregates and \(N\) retained GQ draws. Production uses the GQ draws and RNG
stream fixed by the manifest fit seed and sampler profile; it may not add
draws or choose a seed after seeing a discrepancy. No effort returns
structurally valid zero-count summaries rather than a zero-column error.

- [ ] **Step 5: Run focused and existing summary regressions**

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-goal002r-summary.R")'
Rscript -e 'testthat::test_file("tests/testthat/test-infer-summary.R")'
```

Expected: both pass; existing Goal 002 summary behaviour is unchanged.

- [ ] **Step 6: Review and commit**

```bash
git diff --check
git add R/goal002r/summary.R tests/testthat/test-goal002r-summary.R
git commit -m "feat: add collapsed posterior summaries"
```

---

### Task 8: Implement frozen scores, bootstrap and decision precedence

**Files:**
- Create: `R/goal002r/scores.R`
- Create: `R/goal002r/decision.R`
- Create: `tests/testthat/helper-goal002r-decision-oracle.R`
- Create: `tests/testthat/test-goal002r-scores.R`
- Create: `tests/testthat/test-goal002r-decision.R`
- Create: `scripts/audit_goal002r_decision.R`

**Interfaces:**
- `goal002r_wasserstein(p, q) -> numeric scalar`
- `goal002r_split_draw_pmfs(fit_or_draws) -> named list`
- `goal002r_row_metrics(candidate, baseline, truth) -> tibble`
- `goal002r_stratified_bootstrap(rows, statistic,
  replicates = 10000L, seed = 1020021001L) -> list`
- `goal002r_build_criteria(validated_results, scoring_truth,
  deterministic_evidence) -> tibble`
- `evaluate_goal002r_decision(criteria) -> list`

- [ ] **Step 1: Write RED mathematical score tests**

Test \(W_1=\sum_{s=0}^{C-1}|F_P(s)-F_Q(s)|\), point masses, mismatched
support, full/odd/even chain splitting, absolute loss from the median, squared
loss from the mean, the unchanged lower-bound-conditioned comparator and
unnormalized RPS.

Within every chain, assign odd and even post-warmup iterations separately,
then pool the respective halves across chains. Never split a flattened draw
table without chain identity.

- [ ] **Step 2: Write RED stratification and bootstrap tests**

Test dataset-level paired contrasts first, then means within truth strata,
then the unweighted mean across the three strata. Freeze 10,000 paired
within-stratum bootstrap replicates, seed `1020021001`, type-8 5%/95%
quantiles, exact equality on repeated runs and invariance to input row order.

- [ ] **Step 3: Write the exhaustive decision-boundary table**

The pure decision tests cover:

| Evidence | PASS | REJECT | INCONCLUSIVE |
|---|---|---|---|
| deterministic/provenance | all pass | any failure | — |
| candidate terminal fits | all clean | any completed non-clean | verified exogenous interruption only |
| baseline four-year fits | all clean | — | any non-clean/interrupted |
| within-method \(W_{\rm MC}\) | `<= 0.10` | — | `> 0.10` |
| full \(W_1\), when both MC checks pass | `<= 0.10` | `> 0.10` | — |
| absolute-loss interval | upper `<= 0.25` | lower `> 0.25` | otherwise |
| RPS interval | upper `< 0` | lower `> 0` | otherwise, including zero |
| RMSE | candidate `<=` raw | — | candidate `>` raw |
| coverage | every stratum `>= 7/8` | **PI choice:** any lower, if retained as a hard rejection | **recommended PI choice:** any lower |
| catastrophic error | every error `< 6` | any `>= 6` | — |
| sensitivity | median `<= 1`, max `<= 3` | any excess/non-clean | — |
| rescue use | candidate `<` baseline | — | candidate `>=` baseline |
| runtime ratio | `<= 2` | — | `> 2` |

Verify reject precedence over simultaneous inconclusive conditions, then
inconclusive precedence over favourable conditions.

- [ ] **Step 4: Pin every operational denominator**

Tests require:

- full/split fidelity, point losses, RPS and coverage use only the 24
  four-year primary datasets;
- the all-clean candidate gate uses all 48 candidate confirmation fits;
- rescue-use and runtime comparisons use only the 30 baseline-primary versus
  30 candidate-primary fits, summing every primary and rescue attempt; and
- sensitivity uses exactly the 18 candidate sensitivity rows.

- [ ] **Step 5: Verify RED**

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-goal002r-scores.R")'
Rscript -e 'testthat::test_file("tests/testthat/test-goal002r-decision.R")'
```

Expected: failure because production scoring and decision functions are
absent.

- [ ] **Step 6: Implement pure scoring and decision functions**

The functions accept separately validated terminal artefacts, scoring truth
and deterministic evidence. They never read arbitrary directories, fit
models, expose truth to inference, mutate random state outside
`withr::with_seed()`, or publish output.

Return predicate rows with:

```text
criterion_id,criterion_group,required_for_retain,trigger_verdict,
numerator,denominator,statistic,comparison,threshold,triggered,
details,evidence_id
```

Encode separate predicates whenever one gate can produce different verdicts:

- absolute loss has a REJECT predicate for `lower > 0.25` and an
  INCONCLUSIVE predicate for `lower <= 0.25 && upper > 0.25`;
- RPS has a REJECT predicate for `lower > 0` and an INCONCLUSIVE predicate
  for `lower <= 0 && upper >= 0`; and
- each full-fidelity REJECT predicate is enabled only when both split-draw
  checks pass, while split-draw failures have their own INCONCLUSIVE rows.

Before writing these tests, assert that `Goal.md` records exactly one
PI-approved coverage-shortfall verdict, `REJECT` or `INCONCLUSIVE`. The test
table and contract must use that value literally; an absent, conflicting or
later-mutated value is a deterministic provenance failure.

Return a decision object with the verdict, criteria hash, reject and
inconclusive trigger counts, complete retain-group coverage and ordered
reasons.

- [ ] **Step 7: Implement and isolate the frozen-evidence audit oracle**

The audit helper independently reconstructs W1, split-draw W1, quantiles,
losses, RPS, stratum aggregation, bootstrap intervals and precedence directly
from immutable terminal artefacts. `codetools::findGlobals()` and source
inspection must prove that it calls no production Goal 002R score, bootstrap
or decision function. The stable script writes a comparison table but cannot
publish the production decision.

- [ ] **Step 8: Run focused and Goal 002 score regressions**

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-goal002r-scores.R")'
Rscript -e 'testthat::test_file("tests/testthat/test-goal002r-decision.R")'
Rscript -e 'testthat::test_file("tests/testthat/test-infer-scores.R")'
```

Expected: all pass.

- [ ] **Step 9: Review and commit**

```bash
git diff --check
git add R/goal002r/scores.R R/goal002r/decision.R \
  tests/testthat/helper-goal002r-decision-oracle.R \
  tests/testthat/test-goal002r-scores.R \
  tests/testthat/test-goal002r-decision.R \
  scripts/audit_goal002r_decision.R
git commit -m "feat: add Goal 002R decision metrics"
```

---

### Task 9: Freeze manifests and implement immutable phase dispatch

**Files:**
- Create: `R/goal002r/manifests.R`
- Create: `R/goal002r/artifacts.R`
- Create: `R/goal002r/dispatch.R`
- Create: `R/goal002r/validation.R`
- Create: `tests/testthat/test-goal002r-workflow.R`
- Create: `config/goal002r_development_datasets.csv`
- Create: `config/goal002r_development_manifest.csv`
- Create: `config/goal002r_confirmation_datasets.csv`
- Create: `config/goal002r_confirmation_manifest.csv`
- Create: `scripts/check_goal002r_manifests.R`
- Create: `scripts/run_goal002r.R`
- Create: `scripts/verify_goal002r_freeze.R`
- Create: `scripts/validate_goal002r.R`

**Interfaces:**
- `goal002r_development_datasets() -> tibble`
- `goal002r_development_manifest() -> tibble`
- `goal002r_confirmation_datasets() -> tibble`
- `goal002r_confirmation_manifest() -> tibble`
- `validate_goal002r_manifests(...) -> TRUE` or error
- `materialize_goal002r_manifests(project_root = ".") -> invisible list`
- `dispatch_goal002r(phase, run_id = NULL) -> invisible tibble`
- `validate_goal002r_phase(phase) -> list`
- `verify_goal002r_freeze(phase) -> TRUE` or error

- [ ] **Step 1: Write RED schema, seed and truth-isolation tests**

Dataset tables use:

```text
dataset_id,evidence_role,cell_id,true_richness,n_occasions,replicate,
simulation_seed,source_run_id,expected_data_hash
```

Fit manifests deliberately exclude truth:

```text
run_id,dataset_id,evidence_role,implementation,prior_profile,fit_seed
```

Require unique dataset/run IDs; exact profile pairing; exact dataset counts;
19 development and 78 confirmation fit rows; globally unique fresh primary,
simulation, rescue (`fit_seed + 500000`), smoke and bootstrap seeds;
unchanged, non-colliding historical replay seeds; representable R integers;
and no truth available to the dispatcher's fit call. Include bridge seed
`62003001` and numerical-fixture effort seed `62002001` in the global
collision check. The complete prespecified inventory has exactly 236 unique
integers, with maximum `1320521603`, safely below `.Machine$integer.max`.

Pin these manifest enums:

```text
implementation: goal002_baseline | goal002r_collapsed
prior_profile: primary | sensitivity_membership | sensitivity_tail
evidence_role: historical_stress | fresh_development | fresh_confirmation
```

Fresh run IDs are:

```text
<phase>-c<cell:02>-r<replicate:02>-<implementation>-<prior_profile>
```

The historical run ID is
`development-historical-c05-r03-goal002r_collapsed-sensitivity_membership`.
Development order is historical first, paired baseline/candidate primaries by
cell, then membership and tail sensitivities. Confirmation order is paired
baseline/candidate primaries by cell and replicate, then membership and tail
sensitivities.

Run and preserve the expected RED result:

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-goal002r-workflow.R")'
```

Expected: failure because manifest, materialization, ledger, dispatch and
validation functions are absent.

- [ ] **Step 2: Implement and test the exact development schedule**

Development has seven datasets:

- reconstructed `frozen-c05-r03-membership`, simulation seed `320020503`,
  expected observed-data hash
  `b91f4f5708a67852eabd2650bda4b82ef2ff526b336d9bc2cecd70f96c942945`;
- one fresh dataset in each cell `c01:c06`, with simulation seed
  `120021000 + cell_id`.

Here and below `cell_id` is the integer `1:6`; dataset and run IDs format it
as `c01:c06`.

The 19 fit rows are:

- historical collapsed membership-sensitivity, fit seed `520020503`;
- six fresh baseline-primary rows, seeds `220021000 + cell_id`;
- six fresh collapsed-primary rows, seeds `720021000 + cell_id`;
- collapsed membership-sensitivity in `c04:c06`, seeds
  `820021000 + cell_id`; and
- collapsed tail-sensitivity in `c04:c06`, seeds
  `920021000 + cell_id`.

The historical row is labelled `historical_stress` and is mechanically
excluded from every loss, sensitivity, runtime and confirmation summary.

- [ ] **Step 3: Implement and test the exact confirmation schedule**

Confirmation dataset seed is:

```r
320021000L + 100L * cell_id + replicate
```

with two replicates in `c01:c03` and eight in `c04:c06`. Fit seeds are:

```text
baseline primary:              420021000 + 100 * cell_id + replicate
collapsed primary:            1120021000 + 100 * cell_id + replicate
collapsed membership (r01:03):1220021000 + 100 * cell_id + replicate
collapsed tail (r01:03):      1320021000 + 100 * cell_id + replicate
```

Sensitivity rows exist only for replicates 1–3 in `c04:c06`. This yields
30 baseline primary, 30 collapsed primary and 18 collapsed sensitivity rows.

- [ ] **Step 4: Materialize and verify exact tracked manifests**

```bash
Rscript scripts/check_goal002r_manifests.R --materialize
Rscript scripts/check_goal002r_manifests.R --verify
```

Materialization refuses any pre-existing target file, simulates only to
derive canonical expected observation hashes, and publishes all four CSVs
atomically. Verification regenerates them in memory, checks exact row order
and bytes, and writes nothing.

- [ ] **Step 5: Implement truth-separated phase materialization**

The tracked dataset table is the only design record containing generative
truth. Phase materialization publishes:

```text
outputs/goal002r/<phase>/datasets/<dataset_id>/fit-data.rds
outputs/goal002r/<phase>/scoring/truth.rds
```

`fit-data.rds` must pass a reserved-name scan proving that truth and latent
simulation fields are absent. The dispatcher receives only this object plus
one truth-free fit-manifest row. Scoring joins `truth.rds` only after every
applicable terminal row and dataset hash has been validated.

- [ ] **Step 6: Implement immutable attempt and terminal artefacts**

Each terminal RDS carries:

```text
run_id,dataset_id,evidence_role,implementation,prior_profile,fit_seed,
terminal_status,rescue_used,observed_richness,data_hash,model_hash,
numerical_hash,runner_hash,primary_attempt_path,rescue_attempt_path,
fit_path,summary_path,elapsed_seconds,output_bytes,manifest_hash,
protocol_hash,artifacts_verified,diagnostic_evidence,
posterior_pmf,posterior_pmf_odd,posterior_pmf_even
```

Each `attempts.csv` carries:

```text
run_id,attempt_id,sampler_profile_id,seed,started_at_utc,elapsed_seconds,
output_bytes,clean,divergences,treedepth_hits,min_ebfmi,max_rhat,
min_bulk_ess,min_tail_ess,richness_diagnostics_passed,
generated_richness_passed
```

Each raw/derived artefact inventory carries:

```text
run_id,attempt_id,artifact_role,relative_path,sha256,bytes
```

Record SHA-256 and bytes for every raw CmdStan CSV and every derived
artefact. Inventory repository-relative paths only. A valid existing terminal
row is revalidated and skipped; a partial or corrupted directory is retained,
recorded and halts dispatch. It is never deleted or silently replaced.

- [ ] **Step 7: Implement the manifest-complete phase ledger and stop record**

`run-status.csv` always has one row per scheduled manifest row:

```text
run_id,manifest_index,action,terminal_status,attempt_count,
terminal_record_path,stop_record_id
```

`action` is exactly one of:

```text
completed,verified_existing,infrastructure_incomplete,
not_run_after_hard_stop
```

Completed rows retain terminal status only from
`primary_clean,rescue_clean,final_nonclean`. A phase stop is a single
immutable `phase-stop.rds` with:

```text
phase,trigger_run_id,stop_class,decision_effect,manifest_hash,
freeze_hash,source_hash,partial_inventory_hash,details
```

`stop_class` is exactly
`candidate_final_nonclean`, `truth_or_provenance_failure`, or
`exogenous_infrastructure`. Tests prove the first two imply REJECT, the last
implies INCONCLUSIVE absent an earlier reject, and remaining scheduled rows
become `not_run_after_hard_stop`.

Classify `exogenous_infrastructure` only when process exit, signal, scheduler
or system evidence demonstrates an external interruption, the raw partial
path/hash inventory is preserved, and no completed candidate primary-plus-
rescue row is non-clean. An ambiguous, corrupt or partial attempt without
external evidence is `truth_or_provenance_failure`, not infrastructure.
A partial artefact discovered after a completed `final_nonclean` candidate
cannot downgrade its REJECT effect to INCONCLUSIVE.

- [ ] **Step 8: Implement isolated baseline and candidate dispatch**

Before every baseline row, verify all frozen Goal 002 R and Stan hashes, then
call untouched `fit_flexirich_g()` under:

```text
outputs/goal002/goal002r-baseline/<phase>/<run_id>/
```

Candidate rows call `fit_flexirich_g_collapsed()` under:

```text
outputs/goal002r/<phase>/fits/<run_id>/
```

Materialize each dataset once through Step 5, pass only the truth-free
inference object and manifest row to either fitter, and retain truth only in
the scoring boundary. Never call the old Goal 002 pilot dispatcher or gate.

- [ ] **Step 9: Implement freeze, repair-overlay and phase validation**

The stable validators check manifests bytewise, exact cardinality and pairing,
global seed disjointness, source/Stan/numerical identities, commit ancestry
and path roles, one rescue maximum, raw-output hashes, terminal-to-attempt
consistency, relative-only paths, dataset hash equality across paired
implementations, truth isolation, and regeneration from a clean absent output
directory.

As the first Task 1 action and at every development/confirmation/final
validation boundary, snapshot the presence and, when present, repository-relative
path/SHA-256/byte inventory of the historical
`outputs/goal002/{development,frozen,prior-predictive,report}` namespaces.
Require exact before/after equality. A fresh clone may record their shared
absence; no Goal 002R command may recreate them.

The verifier also supports one optional, additive
`config/goal002r_development_repair.csv`. It may authorize only enumerated
non-fit source changes after development, records old/new hashes and commit
ancestry, and redirects regenerated derived artefacts to `repair-01/`. It
never makes the original development freeze or raw attempts mutable.

- [ ] **Step 10: Run workflow tests without scientific fits**

Use fake fit functions and temporary directories:

```bash
Rscript -e 'testthat::test_file("tests/testthat/test-goal002r-workflow.R")'
Rscript -e 'testthat::test_file("tests/testthat/test-goal002-pilot.R")'
```

Expected: all pass; exact tracked manifest hashes are stable and no directory
under `outputs/goal002r/{development,confirmation}` is created.

- [ ] **Step 11: Review and commit**

```bash
git diff --check
git add R/goal002r/manifests.R R/goal002r/artifacts.R \
  R/goal002r/dispatch.R R/goal002r/validation.R \
  tests/testthat/test-goal002r-workflow.R \
  config/goal002r_development_datasets.csv \
  config/goal002r_development_manifest.csv \
  config/goal002r_confirmation_datasets.csv \
  config/goal002r_confirmation_manifest.csv \
  scripts/check_goal002r_manifests.R \
  scripts/run_goal002r.R scripts/verify_goal002r_freeze.R \
  scripts/validate_goal002r.R
git commit -m "feat: add Goal 002R frozen workflow"
```

---

### Task 10: Certify the integrated implementation and freeze development

**Files:**
- Create: `scripts/run_goal002r_smoke.R`
- Create: `scripts/render_goal002r_report.R`
- Create: `tests/testthat/test-goal002r-report.R`
- Create: `analysis/goal002r_collapsed_repair.qmd`
- Create: `docs/goals/002r-collapsed-unseen-richness/NumericalDecision.md`
- Create: `docs/goals/002r-collapsed-unseen-richness/PreDevelopmentAudit.md`
- Create: `config/goal002r_development_freeze.csv`

**Entry gate:** Tasks 1–9 are accepted commits; no development or confirmation
fit directory exists; the working tree is clean.

- [ ] **Step 1: Write and test the bounded smoke and report contracts**

The smoke uses simulator seed `62002998` and fit seed `62002999` on a small,
fixed, non-development fixture. It may use shortened iterations because it
tests compile/data/draw/summary plumbing, finite target and PMF invariants,
not recovery or the production HMC gate. It is labelled `smoke_only`, excluded
from both manifests and never used to select quadrature, priors or samplers.

The QMD and render wrapper read only validated frozen artefacts, assert
cardinalities and hashes before rendering, resolve relative paths, and support
both a full confirmation and a prespecified early-stop report. Fake-artifact
tests verify every displayed aggregate against direct reconstruction.

- [ ] **Step 2: Run the complete pre-development verification surface**

```bash
Rscript scripts/check_goal002r_environment.R
Rscript scripts/run_tests.R
Rscript scripts/check_goal002r_numerics.R --verify
Rscript scripts/check_goal002r_stan_model.R
Rscript scripts/check_stan_model.R
Rscript scripts/run_goal002r_smoke.R
Rscript -e 'testthat::test_file("tests/testthat/test-goal002r-report.R")'
```

Expected: every command exits zero. The smoke produces only ignored
`outputs/goal002r/smoke/` artefacts.

- [ ] **Step 3: Perform one focused root review of the integrated core**

Review the derivation, stable limits, per-draw PMF, conditional PPC,
continuous diagnostics, truth boundary, baseline firewall, seed namespaces,
raw-output hashes, manifest cardinalities, decision boundaries and absence of
confirmation output. If this review finds a material defect, use the single
total pre-development repair tranche now: record its exact path scope, stage
only those paths, inspect the cached inventory, commit
`fix: repair Goal 002R pre-development defect`, and repeat Step 2 once. Record
that the repair allowance has been consumed. Do not leave a Task 1–9 change
uncommitted while advancing to Step 4.

- [ ] **Step 4: Commit the exact integrated-verification tree**

`NumericalDecision.md` records the fixture and rule hashes, selected order,
reference order, maximum observed discrepancies, analytic-limit results,
commands and the language boundary between exact enumeration and numerical
integration.

```bash
git diff --check
git add scripts/run_goal002r_smoke.R scripts/render_goal002r_report.R \
  tests/testthat/test-goal002r-report.R \
  analysis/goal002r_collapsed_repair.qmd \
  docs/goals/002r-collapsed-unseen-richness/NumericalDecision.md
git commit -m "test: add Goal 002R integrated verification"
```

Before committing, require `git status --short` to list only those exact
paths; inspect `git diff --cached --name-only`, then require a clean tree after
the commit. Re-run Step 2 at the committed `HEAD`; the reviewer audits this
committed tree, not an uncommitted workspace.

- [ ] **Step 5: Obtain the independent pre-development review**

Provide a bounded evidence packet to an independent reviewer. The reviewer
must inspect:

- collapsed likelihood algebra and Gauss--Hermite convention;
- adaptive/enumeration oracle independence;
- R/Stan fixed-input evidence;
- `D=0`, `U=0` and no-effort behaviour;
- output, terminal and raw-CSV provenance;
- truth isolation and baseline immutability; and
- manifest/seed/decision contracts.

If the review finds a material defect and Step 3 did not consume the repair
allowance, use the single total pre-development repair tranche: stage only the
exact scoped paths named in the review memo, confirm the staged inventory and
that no unrelated path is dirty, commit with
`fix: repair Goal 002R pre-development defect`, then regenerate and commit
every affected integrated-verification record. A numerical, Stan, source,
fixture or contract repair must at minimum regenerate and recommit
`NumericalDecision.md`; report-contract changes also regenerate the QMD and
its fake-artifact evidence as applicable. Inspect the exact staged inventory,
rerun Step 2 on that final committed `HEAD`, and obtain one re-review of that
exact state. `PreDevelopmentAudit.md` must name the source-repair and
evidence-refresh commits separately. If Step 3 already consumed the
allowance, a new material finding is the second material failure and selects
REJECT. Two attempts without material improvement also select REJECT and stop
before development.

- [ ] **Step 6: Commit the independent audit record**

Record exact evidence, audited commit identities, any one repair and a
`READY` or `BLOCKED` verdict in `PreDevelopmentAudit.md`.

```bash
git diff --check
git add docs/goals/002r-collapsed-unseen-richness/PreDevelopmentAudit.md
git commit -m "docs: audit Goal 002R pre-development implementation"
```

- [ ] **Step 7: Create and verify the development freeze**

The two-column `key,value` freeze records:

- implementation, numerical-decision and audit commit roles and ancestry;
- every Goal 002 frozen hash;
- every `R/goal002r/`, Stan, script, test, QMD and tracked config hash;
- locked environment, prior, sampler, diagnostic, scoring and decision hashes;
- exact development and confirmation manifest/dataset hashes;
- all seed namespaces and rescue derivation;
- selected quadrature/order/reference/tolerances; and
- expected empty confirmation output boundary.

```bash
Rscript scripts/verify_goal002r_freeze.R \
  --phase development --materialize
Rscript scripts/verify_goal002r_freeze.R --phase development
git diff --check
git add config/goal002r_development_freeze.csv
git commit -m "docs: freeze Goal 002R development protocol"
```

Re-verification must leave the freeze byte-identical. No development fit may
start unless this task is accepted.

---

### Task 11: Execute bounded development and freeze confirmation

**Files:**
- Create: `docs/goals/002r-collapsed-unseen-richness/Development.md`
- Create after PI approval: `config/goal002r_confirmation_freeze.csv`
- Create only if the permitted repair is used:
  `config/goal002r_development_repair.csv`
- Create only if the permitted repair is used:
  `docs/goals/002r-collapsed-unseen-richness/DevelopmentRepairAudit.md`
- Modify only if a permitted non-fit repair is needed:
  files in `R/goal002r/` named `summary.R`, `scores.R`, `decision.R`,
  `artifacts.R` or `validation.R`
- Modify only if a permitted non-fit repair is needed:
  the corresponding `test-goal002r-summary.R`,
  `test-goal002r-scores.R`, `test-goal002r-decision.R`,
  `test-goal002r-workflow.R` or `test-goal002r-report.R`
- Modify only if a permitted non-fit repair is needed:
  `scripts/audit_goal002r_decision.R`, `scripts/validate_goal002r.R`,
  `scripts/render_goal002r_report.R`, or
  `analysis/goal002r_collapsed_repair.qmd`

**Entry gate:** The development freeze passes bytewise, confirmation output is
absent, and the PI has accepted Task 10.

- [ ] **Step 1: Recheck the freeze and dispatch the 19 scheduled rows once**

```bash
Rscript scripts/verify_goal002r_freeze.R --phase development
Rscript scripts/run_goal002r.R --phase development
Rscript scripts/validate_goal002r.R --phase development
```

Expected: one immutable terminal record for every scheduled row, or an
explicit prespecified stop record. The historical observed-data hash must be
exactly
`b91f4f5708a67852eabd2650bda4b82ef2ff526b336d9bc2cecd70f96c942945`.
The validator atomically publishes a development `validated/` inventory
sufficient for either the continuation gate or Task 13's development-stop
audit. No confirmation path may exist.

- [ ] **Step 2: Apply the development hard gate**

Proceed only if:

- the historical collapsed stress fit is terminal-clean;
- all six fresh collapsed-primary fits are terminal-clean;
- all six fresh collapsed-sensitivity fits are terminal-clean;
- mathematical, PMF, PPC, truth and provenance invariants still pass; and
- the candidate/baseline clean pairs show no material `W1 > 0.10` with stable
  split-draw comparisons.

Development baseline non-clean rows are reported but do not become candidate
failures. Any listed candidate/provenance hard failure selects REJECT and
skips confirmation.

- [ ] **Step 3: Apply at most one permitted repair**

After a fit row exists, a repair may only correct deterministic summaries,
validation, provenance, scoring, decision or reporting while reusing the same
immutable raw draws and preserving the fitted target and data. Dispatch and
the phase runner are fit-producing paths and are frozen once the first fit
exists. Re-run the focused tests, full verification surface and independent
check of the repaired evidence.

A change to Stan, quadrature/numerical target, data adapter, fitted
likelihood, prior, sampler or any fit-producing path constitutes a new
candidate. Do not replace or rerun a development row; select REJECT and
return that candidate change to a new PI design and seed namespace.

The original freeze, attempts, terminals and summaries remain byte-immutable.
Any allowed regenerated summary/validation/report artefact is written below
`outputs/goal002r/development/repair-01/` with an additive repair index.
`goal002r_development_repair.csv` records the freeze parent, repair commit,
allowed paths, old/new hashes and independent re-review. Decision/scoring
repairs may correct implementation to the already frozen tests but may not
change a rule, denominator, threshold or seed.

- [ ] **Step 4: Record development evidence**

If a permitted repair occurred, commit, re-review and bind it before the
development record. Commit its explicit paths first:

```bash
git add R/goal002r/summary.R R/goal002r/artifacts.R \
  R/goal002r/scores.R R/goal002r/decision.R \
  R/goal002r/validation.R \
  tests/testthat/test-goal002r-summary.R \
  tests/testthat/test-goal002r-scores.R \
  tests/testthat/test-goal002r-decision.R \
  tests/testthat/test-goal002r-workflow.R \
  tests/testthat/test-goal002r-report.R \
  scripts/audit_goal002r_decision.R \
  scripts/validate_goal002r.R \
  scripts/render_goal002r_report.R \
  analysis/goal002r_collapsed_repair.qmd
git commit -m "fix: repair Goal 002R development defect"
```

Repeat the affected verification surface and obtain one independent re-review
of the repair commit. Record it in `DevelopmentRepairAudit.md`, then bind both
commits:

```bash
git add \
  docs/goals/002r-collapsed-unseen-richness/DevelopmentRepairAudit.md
git commit -m "docs: audit Goal 002R development repair"
test "$(
  git diff-tree --no-commit-id --name-only -r HEAD
)" = "docs/goals/002r-collapsed-unseen-richness/DevelopmentRepairAudit.md"
repair_commit="$(git rev-parse HEAD^)"
repair_audit_commit="$(git rev-parse HEAD)"
Rscript scripts/verify_goal002r_freeze.R \
  --phase development \
  --materialize-repair-overlay \
  --repair-commit "$repair_commit" \
  --repair-audit-commit "$repair_audit_commit"
git add config/goal002r_development_repair.csv
git commit -m "docs: bind Goal 002R development repair"
```

`Development.md` then records all 19 scheduled rows, all attempts, hashes,
diagnostics, rescues, runtimes, output bytes, development-only fidelity/PPC
checks, the exact repair/overlay identities when applicable, and the pass/stop
recommendation. It states explicitly that development contributes no
confirmation loss, coverage or sensitivity estimate.

```bash
git diff --check
git add docs/goals/002r-collapsed-unseen-richness/Development.md
git commit -m "docs: record Goal 002R development"
```

- [ ] **Step 5: Stop for the PI confirmation decision**

Present the development record, residual limitations and recommendation. Do
not prepare or dispatch confirmation until the PI explicitly approves
continuation. A rejection or request for a scientific/fit-producing change
ends Goal 002R at Task 13.

- [ ] **Step 6: Record approval and freeze confirmation**

After explicit approval, append the dated PI verdict and exact development
commit to `Development.md`, then commit:

```bash
git add docs/goals/002r-collapsed-unseen-richness/Development.md
git commit -m "docs: approve Goal 002R confirmation"
```

Create `goal002r_confirmation_freeze.csv` from the final source identities,
development freeze, immutable development terminal inventory, approval
commit, unchanged confirmation rows/seeds, environment and all score,
decision, audit and report code:

```bash
Rscript scripts/verify_goal002r_freeze.R \
  --phase confirmation --materialize
Rscript scripts/verify_goal002r_freeze.R --phase confirmation
git add config/goal002r_confirmation_freeze.csv
git commit -m "docs: freeze Goal 002R confirmation"
```

The freeze must also prove that confirmation output is absent. Task 12 requires
separate PI acceptance of this final lock.

---

### Task 12: Execute and validate immutable confirmation

**Files:**
- No tracked source or configuration changes
- Generate only ignored artefacts below:
  `outputs/goal002r/confirmation/` and
  `outputs/goal002/goal002r-baseline/confirmation/`

**Entry gate:** The PI accepts the confirmation freeze, the working tree is
clean, and `verify_goal002r_freeze.R --phase confirmation` passes.

- [ ] **Step 1: Recheck lock, hardware equivalence and empty outputs**

Record processor, core, chain-parallel and software identity. Baseline and
candidate fits run sequentially under the same four-chain parallel setting;
compilation is excluded from runtime. Reject pre-existing, partial or
unverifiable confirmation output on the initial invocation. On a restarted
invocation, revalidate and skip only complete terminals bound to the identical
freeze. A partial attempt is never replaced: it creates an immutable
`exogenous_infrastructure` stop record only when the external-evidence
requirements in Task 9 are met; otherwise it creates a
`truth_or_provenance_failure` stop record and selects REJECT.

```bash
Rscript scripts/check_goal002r_environment.R
Rscript scripts/verify_goal002r_freeze.R --phase confirmation
```

- [ ] **Step 2: Dispatch in frozen manifest order**

```bash
Rscript scripts/run_goal002r.R --phase confirmation
```

The manifest interleaves baseline and candidate primary fits by dataset,
followed by the prespecified sensitivity rows. It schedules exactly 78 rows.
Run all 78 if no hard failure occurs.

If a candidate completes primary and rescue non-clean, or a deterministic
truth/provenance failure appears, retain the row, stop immediately and select
REJECT; unrun scheduled rows remain explicitly `not_run_after_hard_stop`.
If a verified external interruption prevents a valid terminal row, retain the
partial inventory, stop without rerun and select INCONCLUSIVE unless an
earlier reject condition exists.

- [ ] **Step 3: Validate terminal and raw evidence**

```bash
Rscript scripts/validate_goal002r.R --phase confirmation
```

For a complete run require:

- exactly 78 terminal rows and 30 unique dataset hashes;
- byte-identical observed-data hashes across each baseline/candidate pair;
- 30 baseline-primary, 30 candidate-primary and 18 candidate-sensitivity
  rows;
- all 48 candidate rows terminal-clean;
- at most one rescue and exact derived rescue seed per fit;
- every raw CmdStan CSV and derived file present with matching SHA-256/bytes;
- exact manifest, source, numerical, protocol and freeze hashes;
- relative-only path inventories; and
- no truth field in a fit or summary object.

- [ ] **Step 4: Publish validated evidence atomically**

The validator writes to an absent staging directory, re-reads every output,
then atomically publishes:

```text
outputs/goal002r/confirmation/validated/
  validated-results.rds
  run-status.csv
  attempts.csv
  validation-checks.csv
  status-counts.csv
  path-inventory.csv
  provenance.csv
  validation-provenance.rds
```

It does not yet publish `criteria.csv` or the final decision. Re-running
against an existing validated directory verifies bytes and exits without
replacement.

- [ ] **Step 5: Perform one focused execution review and hand off**

Check scheduled/executed/stopped cardinalities, diagnostic classification,
runtime accounting, rescue counts, output inventories and data pairing.
Do not tune, repair source, add seeds or rerun a fit after confirmation begins.
Hand immutable evidence to Task 13.

---

### Task 13: Independently reconstruct, decide, report and close Goal 002R

**Files:**
- Create: `docs/goals/002r-collapsed-unseen-richness/FrozenEvidenceAudit.md`
- Create: `docs/goals/002r-collapsed-unseen-richness/Log.md`
- Modify: `docs/goals/002r-collapsed-unseen-richness/Goal.md`
- Modify: `README.md`
- Use unchanged: `analysis/goal002r_collapsed_repair.qmd`
- Generate ignored:
  `outputs/goal002r/{development,confirmation}/{audit,decision}/`
  and `outputs/goal002r/report/`

**Entry gate:** Either Task 12 has complete/early-stop confirmation evidence,
or Task 11 has an immutable development hard-stop record and confirmation was
never frozen or run. No source change has occurred after the applicable
freeze/repair overlay.

- [ ] **Step 1: Run the independent frozen-evidence reconstruction**

```bash
scope="$(Rscript scripts/validate_goal002r.R --print-final-scope)"
Rscript scripts/audit_goal002r_decision.R \
  --scope "$scope"
```

The scope is exactly `confirmation` or `development-stop`. For confirmation,
the independent path reconstructs every applicable full/split W1, posterior
quantile, point loss, RPS, stratum mean, bootstrap interval, coverage count,
catastrophic error, sensitivity shift, rescue count, runtime ratio and
decision boundary directly from terminal artefacts. For a development stop,
it independently verifies the exact hard/infrastructure stop, repair state,
scheduled ledger and corresponding REJECT/INCONCLUSIVE effect without
inventing confirmation metrics. Both scopes verify every applicable row,
attempt, data/source/config hash and stop reason and must not read a
production criteria or decision file.

- [ ] **Step 2: Obtain and commit the independent evidence review**

Give a bounded evidence packet to an independent reviewer. The reviewer
compares audit-oracle output with a fresh production validation in memory,
checks observation/truth/posterior/numerical/decision distinctions, and
records exact agreements or discrepancies in `FrozenEvidenceAudit.md`.

Any unexplained mismatch, leakage, replacement or regeneration failure is a
provenance REJECT; do not repair frozen scoring code or regenerate fits after
confirmation.

```bash
git add docs/goals/002r-collapsed-unseen-richness/FrozenEvidenceAudit.md
git commit -m "docs: audit Goal 002R frozen evidence"
```

- [ ] **Step 3: Publish the production decision exactly once**

With the independent-audit commit as an input:

```bash
Rscript scripts/validate_goal002r.R \
  --scope "$scope" \
  --publish-decision \
  --independent-review-commit "$(git rev-parse HEAD)"
```

The finalizer verifies that the supplied audit commit descends from the
applicable confirmation freeze or development freeze/repair overlay and that
its diff changes only `FrozenEvidenceAudit.md`. Commit existence alone is
insufficient.

Atomically publish into an absent decision directory:

```text
criteria.csv
decision.csv
decision.rds
scored-results.rds
bootstrap.rds
decision-provenance.csv
```

`decision.csv` contains:

```text
verdict,decision_contract_hash,criteria_hash,reject_count,
inconclusive_count,retain_requirements_passed,
evidence_manifest_hash,freeze_hash,independent_review_commit
```

Apply REJECT → INCONCLUSIVE → RETAIN precedence once. A second invocation may
verify the existing bytes but cannot republish or change the verdict.

- [ ] **Step 4: Render and verify the decision report**

```bash
Rscript scripts/render_goal002r_report.R
```

For complete confirmation the report contains:

1. estimand, candidate and baseline identities;
2. numerical-certificate evidence;
3. scheduled/executed/terminal fit accounting;
4. all 24 four-year fidelity and split-draw checks;
5. dataset-, cell- and stratum-balanced point losses;
6. RPS comparison;
7. coverage, catastrophic error and sensitivity;
8. rescue, runtime and output-size evidence;
9. PPC and six-month descriptive evidence;
10. every decision criterion and precedence outcome;
11. provenance, regeneration commands and residual limitations; and
12. an explicit separation of observation, known simulation truth,
    posterior inference, numerical approximation and decision inference.

For `development-stop`, the report instead presents the complete development
ledger, verified stop trigger, relevant deterministic/computational evidence
and why confirmation metrics are not applicable.

Reconstruct every displayed aggregate directly and compare it with the
machine-readable decision before accepting the render.

- [ ] **Step 5: Write the durable record and propose the final status**

`Log.md` records hashes, cardinalities, all criteria, the independent audit,
the deterministic verdict, interpretation boundaries, limitations and the
highest-value next tranche. Set exactly one proposed status:

```text
Status: complete — RETAIN; accepted for Goal 003 planning
Status: complete — REJECT; candidate not retained; see Log.md
Status: complete — INCONCLUSIVE; PI decision required; see Log.md
```

For RETAIN, README points only to the retained computation and states that
empirical validity remains untested. For REJECT/INCONCLUSIVE, README records
the stop without presenting the candidate as usable.

- [ ] **Step 6: Stop for PI acceptance, then commit**

Present the proposed status, report, audit, complete versus residual
limitations and next tranche. The PI gate accepts the faithful recording and
scientific interpretation of the deterministic verdict; it cannot change the
frozen verdict or thresholds. Do not commit the closure status until the PI
explicitly accepts the record.

After approval:

```bash
git diff --check
git add analysis/goal002r_collapsed_repair.qmd \
  docs/goals/002r-collapsed-unseen-richness/Goal.md \
  docs/goals/002r-collapsed-unseen-richness/Log.md \
  README.md
git commit -m "docs: close Goal 002R collapsed repair"
```

Push `main` only after a separate explicit push instruction. No generated fit,
raw CSV, HTML report or local absolute path enters Git.

---

## Goal 002R Completion Boundary

Goal 002R is complete after one of the following evidence-backed outcomes:

- **RETAIN:** all deterministic, computational, fidelity, recovery,
  sensitivity, provenance and reporting gates pass. The computation may enter
  a separately designed Goal 003 for misspecification, sampling-intensity and
  comparator testing.
- **REJECT:** a prespecified mathematical, numerical, computational,
  scientific or provenance hard failure occurs. Stop; do not automatically
  start another computational candidate.
- **INCONCLUSIVE:** no rejection occurs, but Monte Carlo stability, baseline
  completeness, RMSE, rescue, runtime or verified infrastructure evidence
  prevents retention. Stop for a new PI decision.

The completion record must state:

- what was directly observed in simulation output;
- what was inferred from posterior distributions;
- what was certified only over the finite numerical fixture domain;
- what decision followed from prespecified thresholds;
- which empirical, spatial, temporal and misspecification questions remain
  untested; and
- why another pass would or would not provide material decision value.

Even RETAIN does not authorize Judbury or Huon Ridge inference, site-level
richness, publication claims or model-family expansion. Those require later
goals and fresh PI approval.
