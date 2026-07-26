# Goal 001 Log

## Outcome

The minimum viable FlexiRich-G simulator satisfied all 13 acceptance criteria
in `Goal.md` on 2026-07-26. The accepted boundary is a deterministic,
internally coherent simulator and a reproducible illustrated scenario suitable
for the first model-recovery experiment. Goal 001 does not provide evidence
about estimator performance.

## Implemented artefacts

The accepted implementation consists of:

- simulator source:
  - `R/sim_config.R`;
  - `R/sim_effort.R`;
  - `R/sim_flexirich_g.R`;
  - `R/sim_rng.R`;
  - `R/sim_summary.R`;
- test entry point and test suite:
  - `scripts/run_tests.R`;
  - `tests/testthat/helper-load.R`;
  - `tests/testthat/test-sim-config.R`;
  - `tests/testthat/test-sim-effort.R`;
  - `tests/testthat/test-sim-flexirich-g.R`;
  - `tests/testthat/test-sim-input-contract.R`;
  - `tests/testthat/test-sim-rng-contract.R`;
  - `tests/testthat/test-sim-summary.R`;
- illustrated scenario:
  - `analysis/goal001_simulator.qmd`; and
- reproducible environment and use instructions:
  - `.Rprofile`, `bootstrap_env.R`, `renv.lock`, `renv/activate.R`,
    `renv/settings.json`, `flexiRich.Rproj`, `.gitignore`, and `README.md`.

The initial source-and-test implementation spans
`2153c6affee9e4d42e0fd0b5f686977948638176` through
`a515604cdc845361e1b1b2db82ea39b09e2fe39a`. The illustrated scenario is
commit `3fe7fb590e65d4c5697e416707605820b6ed692f`. Final-review contract repairs
are commit `ee0e7be49a5edf85fe0e61c1263aa93fce9c43cf`, which was the clean
acceptance-gate source and HEAD state. The repaired simulator version is
`0.1.1`.

## Verification

The complete acceptance gate was run from the repository root against
`ee0e7be49a5edf85fe0e61c1263aa93fce9c43cf`.

- `Rscript scripts/run_tests.R` exited zero. The summary reporter emitted 265
  successful expectations across `sim-config` (35), `sim-effort` (45),
  `sim-flexirich-g` (55), `sim-input-contract` (20), `sim-rng-contract` (37),
  and `sim-summary` (73), followed by `DONE`. No failure, warning, skip, or
  error section was emitted. The runner uses `stop_on_failure = TRUE` and
  `stop_on_warning = TRUE`.
- Focused input-contract regressions require the exact configuration and
  daily-effort schemas, canonicalise reordered fields and factor camera
  identifiers, reject extra, missing, duplicate and unnamed fields, and
  immediately validate every object returned from an accepted path.
- Focused RNG regressions verify caller-algorithm independence, full
  RNG-state restoration without warnings, exact RNG metadata, and validator
  rejection of corrupted algorithm metadata.
- `quarto render analysis/goal001_simulator.qmd --output-dir
  ../outputs/goal001` exited zero and created the non-empty
  `outputs/goal001/goal001_simulator.html` (66,454 bytes; SHA-256
  `5666cee10118f6bcaf863832e65d825077e342c56ef62987b80ec4a7b9b57645`).
  The output is covered by the repository `outputs/` ignore rule and was not
  staged.
- `Rscript -e 'renv::status()'` exited zero with the exact conclusion
  `No issues found -- the project is in a consistent state.`
- The independent truth-contract command from the Goal 001 plan exited zero
  with `Goal 001 truth contract: PASS`. It independently validated the object,
  recomputed true richness from membership, recomputed observed richness from
  detections, and checked that observed richness did not exceed true richness.
- The environment was R 4.6.1 (2026-06-24) and Quarto 1.9.38.
- The simulator recorded version `0.1.1` and canonical RNG algorithms
  `Mersenne-Twister`, `Inversion`, and `Rejection`.
- Git was clean before the gate at the repaired source commit. The render
  generated a transient,
  untracked `analysis/.gitignore` containing only Quarto cache ignore entries;
  it was removed as generated output. A subsequent full untracked-file check
  was empty, the rendered HTML remained ignored, and the staging area was
  empty before this acceptance record was written.

The deterministic illustrated draw used seed 20260723 and returned 30
candidate species, 20 true members, 20 observed members, no unseen true
members, 12,990 active camera-days, and 245 binary detections. These values
describe one explanatory simulation only.

### Acceptance criteria

1. **Reproducibility — pass.** The suite compares every returned data and
   truth component from repeated runs with the same seed, demonstrates
   identical output under changed caller RNG algorithms, and verifies that
   simulator and effort functions restore the caller's complete RNG kinds and
   seed state, including an initially absent `.Random.seed`.
2. **Requested sizes and dimensions — pass.** Configuration tests pin the
   requested candidate pool, richness, cameras, occasions and occasion length;
   object-contract tests verify species, rate and detection table dimensions.
3. **No detections of non-members — pass.** Focused generation and validator
   tests require all sampled non-member outcomes to be zero and reject a
   corrupted non-member detection.
4. **Zero effort is unsampled — pass.** Focused tests require missing outcomes,
   `sampled = FALSE`, and zero detection probabilities at zero effort; the
   validator rejects any observed outcome in such a cell.
5. **Exact effort aggregation — pass.** Weekly effort is independently
   recomputed as the sum of daily binary operating states, and the validator
   rejects corrupted weekly effort.
6. **Generative equations — pass.** Tests independently recompute
   `exp(alpha + camera_effect)`, the effort-aware conditional probability, and
   membership-weighted observation probability from returned tables.
7. **Seed-controlled Bernoulli observations — pass.** The observation stream
   is independently regenerated with its specified seed offset and compared
   exactly with every sampled detection; every simulator stream is pinned to
   the recorded canonical RNG algorithms.
8. **Bounds and types — pass.** Tests and validator checks require finite
   positive encounter rates, finite probabilities in `[0, 1]`, binary sampled
   outcomes, and missing unsampled outcomes.
9. **Monotonic effort response — pass.** A fixed-rate test evaluates efforts
   0, 1, 3 and 7 active days and verifies a non-decreasing conditional
   detection probability, including probability zero at zero effort.
10. **Richness ordering — pass.** Configuration validation requires true
    richness not to exceed the candidate pool; the truth reconstruction and
    independent truth contract require observed richness not to exceed true
    richness.
11. **Sufficient truth record — pass.** The returned membership, detection and
    truth tables contain candidate, true, observed, unseen-member, non-member
    and total-detection fields; corruption tests independently recompute and
    reject every altered truth-summary field.
12. **Low- and high-detection scenarios — pass.** The deterministic paired
    scenario test holds membership and seed fixed while changing encounter
    rate, and verifies greater observed richness in the high-rate scenario.
13. **Automated suite and documented regeneration — pass.** All 265
    expectations passed, and the documented Quarto command regenerated the
    non-empty root output in one invocation.

## Scientific interpretation

Demonstrated facts are limited to the simulator contract: fixed seeds
reproduce the generated data and latent truth; daily effort aggregates
exactly; non-members and unsampled cells cannot create detections; returned
rates, probabilities and Bernoulli outcomes satisfy their stated equations;
truth summaries are independently reconstructible; and the explanatory
scenario renders from the documented command.

The illustrated scenario is not an estimator fit or validation study. No
FlexiRich-G estimator was fitted, and Goal 001 does not demonstrate
identifiability, unbiasedness, interval calibration, superiority to another
estimator, robustness to misspecification, or validity for empirical
camera-trap processes. No empirical or held-out data were accessed.

## Residual limitations

The simulator deliberately uses a finite known candidate pool, independent
membership and detectability effects, lognormal encounter heterogeneity,
seven-day occasions, and a baseline binary-detection process. It does not yet
represent false positives, classification uncertainty, abundance, spatial or
temporal dependence, turnover, transient use, alternative candidate-pool
sizes, or hostile misspecification. The single illustrated draw and the
qualitative low/high-rate test do not quantify recovery bias, uncertainty
coverage, calibration, catastrophic overestimation, or comparative
performance.

## Recommendation

Begin Goal 002 planning for the minimal FlexiRich-G inference model and the
first correctly specified simulation-recovery loop. Preserve the Goal 001
simulator as the generative reference, and keep claims about estimator
performance blocked until replicated recovery, uncertainty and sensitivity
evidence exists.
