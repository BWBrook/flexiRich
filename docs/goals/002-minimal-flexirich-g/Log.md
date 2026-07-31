# Goal 002 Log

## Outcome

Goal 002 is **complete as an informative method failure**.

The full frozen experiment completed: 96/96 scheduled rows, comprising 60
primary and 36 sensitivity fits. The frozen acceptance gate passed 14/17
criteria and failed Criteria 27, 33 and 34. The implementation and evidence
boundary was not blocked, but the method is not accepted for Goal 003
validation or empirical application in its current form.

The three failures are retained without changing any threshold, denominator,
seed, profile or row:

- Criterion 27: four-year posterior-mean richness had median absolute error
  1.096702200826 species versus 1 for raw observed richness. The posterior was
  individually closer to known truth in 18/30 rows, but the frozen gate
  compares medians and requires a strict improvement.
- Criteria 33 and 34: one four-year membership-sensitivity fit,
  `frozen-c05-r03-membership`, remained `final_nonclean` after rescue with
  minimum tail ESS 288.803161976. The frozen policy therefore assigns its
  paired sensitivity shift the 30-species sentinel and fails both gates. The
  sentinel is a conservative penalty, not an interpretable posterior shift.

The independent Task 11 audit approved the evidence for use in this closure
with its provenance correction. It did not scientifically approve
FlexiRich-G. The recorded one-gate-call count is process-local corroborating
provenance, not an externally append-only proof.

## Implemented artefacts

Exact production source:

- `R/fit_flexirich_g.R`
- `R/goal002_pilot.R`
- `R/infer_config.R`
- `R/infer_data.R`
- `R/infer_math.R`
- `R/infer_prior.R`
- `R/infer_scores.R`
- `R/infer_summary.R`
- `R/sim_config.R`
- `R/sim_effort.R`
- `R/sim_flexirich_g.R`
- `R/sim_rng.R`
- `R/sim_summary.R`

Model and executable interfaces:

- `stan/flexirich_g.stan`
- `scripts/setup_cmdstan.R`
- `scripts/check_stan_model.R`
- `scripts/run_goal002_smoke.R`
- `scripts/run_goal002_prior_check.R`
- `scripts/run_goal002_pilot.R`
- `scripts/run_tests.R`

Exact test and oracle files:

- `tests/testthat/helper-load.R`
- `tests/testthat/helper-goal002-oracles.R`
- `tests/testthat/test-fit-contract.R`
- `tests/testthat/test-goal002-pilot.R`
- `tests/testthat/test-infer-config.R`
- `tests/testthat/test-infer-data.R`
- `tests/testthat/test-infer-likelihood.R`
- `tests/testthat/test-infer-prior.R`
- `tests/testthat/test-infer-scores.R`
- `tests/testthat/test-infer-summary.R`
- `tests/testthat/test-sim-config.R`
- `tests/testthat/test-sim-effort.R`
- `tests/testthat/test-sim-flexirich-g.R`
- `tests/testthat/test-sim-input-contract.R`
- `tests/testthat/test-sim-rng-contract.R`
- `tests/testthat/test-sim-summary.R`

Configuration, manifests and lock:

- `config/goal002_development_manifest.csv`
- `config/goal002_frozen_manifest.csv`
- `config/goal002_freeze.csv`
- `renv.lock`

Durable design and decision records:

- `docs/goals/002-minimal-flexirich-g/Goal.md`
- `docs/goals/002-minimal-flexirich-g/Plan.md`
- `docs/goals/002-minimal-flexirich-g/PriorPredictiveDecision.md`
- `docs/goals/002-minimal-flexirich-g/Development.md`
- `docs/goals/002-minimal-flexirich-g/Audit.md`
- `docs/goals/002-minimal-flexirich-g/Log.md`
- `README.md`

Report source and generated output:

- tracked source: `analysis/goal002_baseline_recovery.qmd`
- ignored HTML:
  `outputs/goal002/report/goal002_baseline_recovery.html`
- ignored frozen evidence:
  `outputs/goal002/frozen/acceptance/criteria.csv`,
  `gate-object.rds`, `validated-results.rds`,
  `validation-provenance.rds`, `provenance.csv`,
  `validation-checks.csv`, `status-counts.csv` and `path-inventory.csv`

Generated executables, attempts, CmdStan CSV files, fits, summaries,
prior-predictive outputs and rendered reports remain under ignored `outputs/`
paths and are not committed.

## Frozen evidence

### Commits and freeze identity

- prior-profile decision commit:
  `9aab8540692dc3ffd75f81c1821316361cb2f147`
- implementation/development commit:
  `97e276b4b051b596a5f432c526e0b267555681e7`
- pre-freeze audit-record commit:
  `dc88e796fce5087ddcfdf947eacef3cfe571d2f2` (`READY`)
- freeze/execution commit:
  `3f8b7bb743d2cb383b41c115ad7c22fd9a715280`
- freeze time: `2026-07-30T03:51:43Z`

The frozen runtime was R 4.6.1, CmdStanR 0.9.0 and CmdStan 2.38.0. The Stan
source SHA-256 was
`659b335b0e9eaffecb2629d06a768c419d00f3c3a8719fa99f67ea6c4171cb91`.
The frozen prior profiles were `primary-v1`,
`sensitivity-membership-v1` and `sensitivity-tail-v2`; the sampler profiles
were `primary-sampler-v1` and `rescue-sampler-v1`.

### Seeds and run cardinality

The committed manifest records every seed. Its exact constructions are:

- simulation:
  `320020000 + 100 * cell_id + replicate`;
- primary fit:
  `420020000 + 100 * cell_id + replicate`;
- membership-sensitivity fit:
  `520020000 + 100 * cell_id + replicate`; and
- tail-sensitivity fit:
  `620020000 + 100 * cell_id + replicate`.

Primary replicates are 1--10 in each of six cells. Each sensitivity reuses the
matching primary simulation seed for replicates 1--3. The prior-predictive
effort seed was 62002001; profile seeds were 62002101, 62002201 and 62002301,
with 10,000 draws per profile.

Terminal accounting:

| Run type | Frozen prior profile | Primary clean | Rescue clean | Final non-clean | Planned |
|---|---|---:|---:|---:|---:|
| primary | `primary-v1` | 31 | 28 | 1 | 60 |
| sensitivity | `sensitivity-membership-v1` | 6 | 10 | 2 | 18 |
| sensitivity | `sensitivity-tail-v2` | 6 | 11 | 1 | 18 |
| **All** |  | **43** | **49** | **4** | **96** |

There were 92 terminal-clean rows, four terminal-non-clean rows and 53 uses of
the single prespecified rescue. All four non-clean rows and both attempts for
each remain addressable.

### Runtime and immutable hashes

The frozen dispatcher completed 96 rows and skipped zero in 5,385.2 seconds.
Retained attempt time summed to 4,666.148 seconds; median fit time was 27.176
seconds and the range was 4.404--252.321 seconds. The validated preflight,
dispatcher, gate process and first integrity read took approximately 5,615.8
seconds (1 hour 33 minutes 35.8 seconds).

Semantic evidence identifiers:

| Evidence | SHA-256 or canonical hash |
|---|---|
| prior-predictive index | `893ed2149d3608d8f62ce369c48337df46bbbc882e9cf86ba698307b1daf540d` |
| frozen manifest | `7cd056e3c611eb6722396c8671e37a1c496a93d36cb876bbe9542eb3d6e8c995` |
| freeze record | `d2548f2a09bb2a8da67c43c050a69216cf5462f3966484ccb56851f2cbc2f64f` |
| terminal-record collection | `4b429b37c9a7d75c452f50941126fbb0bad065e56df9c14eccc5a96529e3ac8f` |
| validated gate input | `b8cf14ee62bd54e328d638ea922b77f0a9033be6b259e6905d26e2c295f277e1` |
| path inventory | `9de0aec0a07f558df6fc0844ae23e26d9f6be861cd1932cb06b4ee8ce6063812` |
| run-status table | `dff9f71704d197dfdd0cdc71386aefcfe49525ea0cb0f30132a875e3b7dbf5d0` |
| complete gate object | `5bf9f2d8f2a5665c56c769411a5eccbf1f9e9fc166687a96eba86fa1f8c0cab8` |
| flat criteria object | `3a86840dffadf9d2db4e47e82704da4a2e80178e73304904802fbac1caadd0e0` |

Raw acceptance-file SHA-256 values, independently corrected before Task 12:

| File | SHA-256 | Bytes |
|---|---|---:|
| `gate-object.rds` | `87a5a0d941dbb11d03bdcbe0e48d3502742bf1d1d812c3b0281331ea4a26cddb` | 10,406 |
| `criteria.csv` | `20854403357af4d50c98af5f645d5f5295030b239afeb8bb2c679006704058e8` | 2,676 |
| `validated-results.rds` | `1043051b809c9e5ef176d735804e41b6eb14fe48c27a0e9245d70b27b521fb45` | 23,724 |
| `validation-provenance.rds` | `a55f0a5ef7e6ab12587596aef48db542595ecc7729c2f816c4c41b11cc830152` | 10,627 |
| `provenance.csv` | `91b07bdff9a31e18c2b45d544fe9e4b323c7143512d65a5096386294f43189fe` | 1,947 |
| `validation-checks.csv` | `42b659d544c5f7bd0c6a7401bb7b6de17aec9d48ac9d8cb5486e6718cb88270a` | 1,632 |
| `status-counts.csv` | `711df1b881b76f9bf5649a7091cdbc4a58977c8b8d2c180e47c71d395811ded7` | 491 |
| `path-inventory.csv` | `dffa34ca588555bae722672a1ef7da497a8bc0c2a3481d0bd317530dc47ac6dc` | 158,364 |

### Task 12 closure commands

The complete Task 12 acceptance sequence was run in the prescribed order.
Every command exited zero.

| Command | Observed evidence | Wall time (s) |
|---|---|---:|
| `Rscript scripts/run_tests.R` | 14/14 files and 176 named test blocks; zero failure, warning or skip | 127.82 |
| `Rscript scripts/setup_cmdstan.R` | `CmdStan contract: PASS (2.38.0)` | 2.20 |
| `Rscript scripts/check_stan_model.R` | `Goal 002 Stan bridge: PASS` | 4.33 |
| `Rscript scripts/run_goal002_smoke.R` | `PASS`; `rescue_clean`; internal fit time 7.085 s | 10.95 |
| `Rscript scripts/run_goal002_prior_check.R` | all three profiles avoided automatic rejection; 21/21 rules passed | 33.97 |
| `Rscript -e 'renv::status()'` | `No issues found -- the project is in a consistent state.` | 2.19 |
| canonical Quarto render | 25/25 chunks; HTML created at the documented path | 9.08 |
| `git status --short` | intended Task 12 paths plus Quarto-generated `analysis/.gitignore`; generated file removed in the focused repair | 0.00 |

The measured acceptance sequence took 190.54 seconds. The deterministic smoke
primary attempt was non-clean (5 divergences and maximum R-hat 1.010245);
the single rescue was clean with zero divergences, zero treedepth hits,
minimum E-BFMI 0.814811, maximum R-hat 1.003076, minimum bulk ESS 1,892.112
and minimum tail ESS 2,033.791. Its generated-richness contract passed over
6,000 draws.

The acceptance-gate render created
`outputs/goal002/report/goal002_baseline_recovery.html` at 91,694 bytes.
Because an earlier render had populated the out-of-project support directory,
Quarto emitted a cleanup warning while still exiting zero. The focused final
review removed that generated directory and rendered once more.

Independent review then identified sequential `dplyr::summarise()` name
masking in the six-cell display: the logical clean-fit vector had been
overwritten by a scalar count before later statistics indexed it. The focused
repair retained the logical vector, used distinct `clean_n` and `nonclean_n`
outputs, and added a base-index reconstruction of every displayed statistic
for all six cells. The reconstruction matched the grouped result exactly and
confirmed cell 1 at 9/10 clean and 1 non-clean, plus the four-year,
true-richness-8 posterior mean median 8.843630, range 7.333324--10.634249 and
median interval width 5.5. No frozen evidence, criterion, threshold,
denominator or scientific conclusion changed.

The repaired canonical render exited zero without a warning in 7.92 seconds
and produced 91,829 bytes with SHA-256
`5531fe9e1f1dcf69035fc438b7f5004bc6e04c31621a5870d0d8779f57b9fa4b`.
The tracked report source SHA-256 is
`7e20970f8d6848ee5f27b7c0cda0e6fd192124eba7562f4b2aafa66f91bdf4b4`.
Quarto's generated `analysis/.gitignore` was removed after rendering and is
not part of the acceptance record.

## Acceptance criteria

`Fraction` is the criterion-specific numerator/denominator. Criteria 19--35
are transcribed from the immutable frozen `criteria.csv`; other rows are
explicit implementation, prior and Task 12 closure checks.

| Criterion | Fraction | Statistic | Threshold | Verdict | Evidence identifier |
|---:|---:|---|---|:---:|---|
| 1 | 1/1 | Validated adapter excludes latent truth; truth mutation leaves input identical | All observed inputs retained; no truth field | PASS | `TEST:data-adapter`; `AUDIT:input-truth` |
| 2 | 1/1 | Zero-effort cells add zero grouped trials | Exactly zero trials | PASS | `TEST:zero-effort` |
| 3 | 2/2 | Grouped trials and detections reconstruct sampled rows and detections | Exact equality for both totals | PASS | `TEST:aggregation-reconstruction` |
| 4 | 1/1 | Grouped and independent rowwise kernels agree | Absolute difference <= `1e-10(1+abs(oracle))` | PASS | `TEST:grouped-rowwise-oracle` |
| 5 | 4/4 | Analytic marginal likelihood agrees for C=1,2,3,4 and all `2^C` vectors | Tolerance `1e-12(1+abs(oracle))` | PASS | `TEST:membership-enumeration` |
| 6 | 2/2 | Stable detection and non-detection log terms match hand values | Absolute tolerance `1e-14` | PASS | `TEST:stable-hazard` |
| 7 | 2/2 | Canonical data are byte-identical and grouped likelihood is identical after permutation | No ordering effect | PASS | `TEST:order-invariance` |
| 8 | 1/1 | Detected-candidate membership is exactly one | `q_member = 1` | PASS | `TEST:posterior-membership`; `BRIDGE:q_member` |
| 9 | 1/1 | All-zero membership values are finite and bounded | `0 <= q_member <= 1` | PASS | `TEST:posterior-membership`; `BRIDGE:q_member` |
| 10 | 1/1 | Generated richness is integer and within exact support | `S_obs <= S_grid <= C` | PASS | `TEST:generated-richness`; `SMOKE:support` |
| 11 | 1/1 | Per-draw `g_member` sums reconstruct `S_grid` | Exact equality | PASS | `TEST:generated-richness`; `SMOKE:reconstruction` |
| 12 | 1/1 | Rao--Blackwellised PMF is non-negative and normalised | Sum error <= `1e-14` | PASS | `TEST:richness-pmf` |
| 13 | 1/1 | Exchangeable all-zero fixture candidates have equal marginal membership | Monte Carlo tolerance contract | PASS | `TEST:exchangeability` |
| 14 | 1/1 | Added sampled zero-detection effort lowers conditional membership | Strict decrease at fixed continuous parameters | PASS | `TEST:zero-effort-monotonicity` |
| 15 | 21/21 | 30,000 prior draws; all profile-rule rows passed before recovery | All 21 fixed rules pass | PASS | `PRIOR:893ed214` |
| 16 | 3/3 | Maximum analytical richness-PMF discrepancy = 0 | <= `1e-12` for each profile | PASS | `PRIOR:richness-pmf` |
| 17 | 2/2 | Centred camera truth preserves linear predictors and likelihood | Eta tolerance `1e-15`; likelihood tolerance `1e-12` | PASS | `TEST:centered-truth` |
| 18 | 1/1 | Mutated latent truth yields byte-identical inference data | No truth field reaches fitted data | PASS | `TEST:truth-isolation`; `AUDIT:input-truth` |
| 19 | 96/96 | 96 | 96/96 terminal rows and unique attempt addresses | PASS | `FROZEN:criteria.csv#C19` |
| 20 | 92/92 | 92 | All terminal-clean fits satisfy the frozen diagnostic contract | PASS | `FROZEN:criteria.csv#C20` |
| 21 | 96/96 | 53 | At most one primary attempt plus one committed rescue | PASS | `FROZEN:criteria.csv#C21` |
| 22 | 59/60 | 9 | At least 57/60 clean and at least 9/10 in every cell | PASS | `FROZEN:criteria.csv#C22` |
| 23 | 4/4 | 4 | Every terminal non-clean fit remains reported | PASS | `FROZEN:criteria.csv#C23` |
| 24 | 3/3 | 3 | No posterior interpretation from terminal non-clean sensitivity fits | PASS | `FROZEN:criteria.csv#C24` |
| 25 | 10/10 | 10 | At least 8/10 covered in every four-year richness cell | PASS | `FROZEN:criteria.csv#C25` |
| 26 | 21/30 | 1.096702200826 | Median absolute error <= 2 species | PASS | `FROZEN:criteria.csv#C26` |
| 27 | 18/30 | 1.096702200826 | Posterior median absolute error < raw median absolute error (1) | **FAIL** | `FROZEN:criteria.csv#C27` |
| 28 | 29/30 | 0.604592182937 | Median posterior RPS < median baseline RPS (9.093747) | PASS | `FROZEN:criteria.csv#C28` |
| 29 | 30/30 | 3.033297045975 | Maximum absolute error < 6 species | PASS | `FROZEN:criteria.csv#C29` |
| 30 | 28/30 | 28 | At least 24/30 six-month intervals cover truth | PASS | `FROZEN:criteria.csv#C30` |
| 31 | 30/30 | 29 | Report six-month behaviour with planned and clean counts | PASS | `FROZEN:criteria.csv#C31` |
| 32 | 36/36 | 3 | All 36 sensitivity fits and non-clean states reported | PASS | `FROZEN:criteria.csv#C32` |
| 33 | 2/2 | 0.203065684623 | Median absolute shift <= 1 in each four-year sensitivity profile | **FAIL** | `FROZEN:criteria.csv#C33` |
| 34 | 17/18 | 30 | No four-year sensitivity shift > 3 species | **FAIL** | `FROZEN:criteria.csv#C34` |
| 35 | 18/18 | 16 | Report six-month sensitivity without a hard stability threshold | PASS | `FROZEN:criteria.csv#C35` |
| 36 | 2/2 | CmdStan 2.38.0 setup and source-hashed Stan/R bridge passed | Stan syntax and model compilation/bridge pass | PASS | `T12:stan-bridge` |
| 37 | 14/14 | 14 files, 176 named test blocks, zero failure/warning/skip | All Goal 001 and Goal 002 tests pass | PASS | `T12:full-tests` |
| 38 | 3/3 | R 4.6.1, CmdStanR 0.9.0 and CmdStan 2.38.0; `renv` consistent | Lock, setup and versions agree | PASS | `T12:environment` |
| 39 | 96/96 | Frozen dispatcher completed 96 rows and skipped zero | Every manifest row and aggregate result regenerates | PASS | `FROZEN:validation-provenance` |
| 40 | 1/1 | Canonical command produced a non-empty HTML report | One documented render command | PASS | `T12:render` |
| 41 | 41/41 | This log records 38 passes, 3 failures and all required provenance | All gates, failures, rescues, runtime and uncertainty recorded without empirical-validation language | PASS | `T12:Log.md` |

The complete Goal ledger is therefore 38 PASS and 3 FAIL. A criterion's
numerator is not interpreted as a pass count when the frozen contract uses
another universal condition: Criterion 33, for example, retains both profile
summaries but fails because one prespecified pair is non-clean.

## Scientific interpretation

Known simulation truth, observed richness and posterior inference are
different quantities:

- known truth is the latent richness used to generate each synthetic row and
  is available only for recovery assessment;
- observed richness is the number of detected candidate species and is the
  lower bound supplied by the data; and
- posterior richness integrates membership uncertainty for undetected
  candidates, but only for terminal-clean fits.

The four-year posterior showed useful distributional concentration and had a
much lower median RPS than the lower-bound-conditioned prior comparator.
Nevertheless, it did not meet the frozen median point-error improvement over
raw observed richness. Clean sensitivity pairs shifted little, but the
prespecified fail-closed rule treats the non-clean membership pair as a hard
sensitivity failure. These results apply only to the correctly specified Goal
001 family with 30 named candidates, nine cameras and the frozen effort
process.

This outcome does not show empirical validity, robustness to
misspecification, candidate-pool completeness, correct unseen-species
identity, universal interval calibration, superiority to an external
estimator, or transferability to another camera array, taxon or duration.

## Residual limitations

Scientific limitations:

- membership prevalence and the lower encounter-rate tail remain weakly
  identified for never-detected candidates;
- the pilot has only 10 primary replicates per cell and three paired
  sensitivity replicates per cell;
- 53/96 rows required rescue and four remained terminal non-clean;
- the tests cover only the correctly specified Gaussian log-rate baseline;
- candidate-pool construction and uncertainty were fixed rather than
  estimated; and
- six-month means involving non-clean rows are intentionally unavailable
  under the fixed-denominator/fixed-mean contract.

Deferred scientific work includes misspecified encounter distributions,
membership--detectability dependence, temporal and spatial dependence,
seasonality and turnover, false positives, alternative occasion lengths,
sampling-intensity curves, empirical candidate-pool construction, external
comparators, Judbury observations and all Huon Ridge data.

Residual implementation/provenance limitations retained from review:

- a completely unsampled data set reaches Stan but its zero-column posterior
  predictive output is not currently summarised;
- freeze-record Git commit keys were explicitly inspected but the verifier
  does not itself prove their semantic role and ordering;
- resume validation does not byte-hash each raw CmdStan CSV; and
- the single gate invocation is process-local corroboration, not an
  independently append-only execution proof.

None changes the frozen outcome. They should be addressed only in a new
design or archival-hardening tranche.

## Recommendation

Stop this model version at the informative failure. Do not tune priors,
samplers, thresholds, denominators, seeds or replication against the observed
frozen result, and do not proceed directly to empirical analysis.

The next high-value decision is a PI-approved model-repair design. If the
priority is the membership/low-rate geometry exposed by the non-clean
sensitivity pair, consider the predefined exact unseen-richness enumeration
with checked Gauss--Hermite integration. That route requires a separate plan,
new numerical oracles and a new freeze; it is not activated by this log.

Goal 003 planning may then test the repaired or explicitly retained model
against misspecification, sampling-intensity curves and competing estimators
under newly frozen decisions. If no scientifically justified repair is
approved, stop rather than carrying the current model into empirical work.
