# Goal 002 — Minimal FlexiRich-G inference and pilot recovery

Status: design approved — implementation not started
Date defined: 2026-07-26

## Objective

Implement the first statistically valid Bayesian FlexiRich-G estimator for a
finite, known candidate species pool, then close a bounded
simulation–inference–recovery loop under the correctly specified Goal 001
baseline.

Goal 002 is complete when:

1. the marginal likelihood and posterior richness calculation are verified
   against independent numerical oracles;
2. the model fits reproducibly with acceptable diagnostics;
3. a frozen pilot experiment shows useful four-year richness recovery across
   low, intermediate and high true richness;
4. six-month fits reveal partial-information behaviour without being
   misrepresented as strongly identified;
5. limited prior sensitivity is measured and reported; and
6. the implementation, pilot manifest, diagnostics and report regenerate from
   documented commands.

This goal establishes implementation correctness and best-case pilot
performance only. It does not validate FlexiRich-G for empirical camera-trap
communities or establish superiority over another estimator.

## Scientific purpose

Goal 001 produced a deterministic, effort-aware simulator with known
grid-level detectable-use richness. It deliberately stopped before fitting an
estimator. Goal 002 now asks whether a correctly formulated inference model can
recover that known richness when some true members have all-zero detection
histories.

The load-bearing problem is to distinguish:

- candidates that do not belong to the grid-level detectable-use pool; from
- true pool members that were present but remained undetected.

A finite candidate pool bounds the possible richness, but it does not remove
the trade-off among membership prevalence, the lower encounter-rate tail and
sampling effort. Goal 002 must make that uncertainty visible rather than
forcing a precise estimate.

## Decisions already fixed

- The candidate universe is finite and known.
- The estimand is whole-grid detectable-use richness during a defined period.
- Input observations are species × camera × seven-day binary detections.
- Operational effort is exact active camera-days within each occasion.
- Zero-effort camera-occasions are unsampled and contribute no observation
  information.
- Every eligible candidate species is supplied to the model, including
  candidates with no detections.
- FlexiRich-G is fitted before any standard multispecies occupancy comparator
  or site-level FlexiRich-S extension.
- The first inference model matches the Goal 001 generative family.
- CmdStanR and CmdStan are the primary computational engine.
- Discrete membership is analytically marginalised; it is not approximated by
  a continuous pseudo-presence variable.
- Goal 002 includes a modest replicated pilot at six months and four years.
- Judbury observations and all Huon Ridge data remain outside Goal 002.

## Estimand and notation

Let:

- \(i=1,\ldots,C\) index candidate species;
- \(j=1,\ldots,J\) index cameras;
- \(k=1,\ldots,K\) index seven-day occasions;
- \(e\in\{1,\ldots,7\}\) be active camera-days in a sampled occasion;
- \(g_i\in\{0,1\}\) indicate candidate membership in the grid-level
  detectable-use pool;
- \(y_{ijk}\in\{0,1\}\) indicate at least one valid detection;
- \(r_{ij}>0\) be encounter intensity per active camera-day; and
- \(S_{\mathrm{grid}}=\sum_i g_i\) be the target richness.

Observed richness,

\[
S_{\mathrm{obs}}
  = \sum_{i=1}^{C} I\left(\sum_{j,k} y_{ijk}>0\right),
\]

is a hard lower bound on every posterior richness draw. Candidate-pool size
\(C\) is the hard upper bound.

## Minimal inference model

### Membership model

\[
g_i\mid\omega\sim\operatorname{Bernoulli}(\omega),
\qquad
\omega\sim\operatorname{Beta}(1,1).
\]

After integrating \(\omega\), this hierarchy induces a discrete-uniform prior
on total richness \(S_{\mathrm{grid}}\in\{0,\ldots,C\}\), with membership
subsets of the same size assigned equal prior probability. Conditional on a
fixed total richness, this agrees with the Goal 001 simulator's uniform
selection of member subsets without using the true richness during inference.

The implied richness prior must be calculated and reported directly. The
apparently simple prior on \(\omega\) must not be described as
distribution-free.

### Encounter-rate hierarchy

\[
\alpha_i=\mu_\alpha+\sigma_\alpha z_i,
\qquad
z_i\sim N(0,1),
\]

\[
\log r_{ij}=\alpha_i+b_j.
\]

Species effects use a non-centred parameterisation. Camera effects obey the
identifying constraint

\[
\sum_{j=1}^{J}b_j=0.
\]

The Stan implementation should construct the camera effects from an
orthonormal \(J\times(J-1)\) contrast matrix:

\[
\mathbf b=\sigma_b Q\mathbf z_b,
\qquad
\mathbf z_b\sim N(\mathbf 0,I).
\]

The raw Goal 001 camera effects are not exactly sum-to-zero in a finite draw.
Recovery comparisons must therefore use the equivalent centred truth:

\[
b_j^\star=b_j-\bar b,
\qquad
\alpha_i^\star=\alpha_i+\bar b,
\]

which preserves every combined \(\alpha_i+b_j\) and every encounter rate.

### Effort-aware observation model

For a member species:

\[
p_{ije}
  = 1-\exp\{-e\exp(\alpha_i+b_j)\}.
\]

The observation model for a sampled occasion is:

\[
y_{ijk}\mid g_i,\alpha_i,b_j
\sim\operatorname{Bernoulli}(g_i p_{ijk}).
\]

The likelihood must be evaluated on the log scale using stable hazard-scale
expressions:

\[
\log p_{ije}
  = \log\{1-\exp[-e\exp(\alpha_i+b_j)]\},
\]

\[
\log(1-p_{ije})
  = -e\exp(\alpha_i+b_j).
\]

Stan's stable `log1m_exp` or an algebraically equivalent checked function must
be used for the first expression. The implementation must not form very small
probabilities and then take their logarithms.

## Exact occasion aggregation

Under the Goal 001 baseline, encounter rates are constant across occasions.
Observations may therefore be grouped by species, camera and active-days
category.

Let:

- \(N_{je}\) be the number of occasions at camera \(j\) with \(e\) active
  days; and
- \(Y_{ije}\) be the number of detections for species \(i\) in those
  occasions.

The parameter-dependent log-likelihood kernel is:

\[
Y_{ije}\log p_{ije}
  +(N_{je}-Y_{ije})\log(1-p_{ije}).
\]

This equals the sum of the corresponding Bernoulli log-likelihood terms
exactly. The implementation should use this kernel directly, or an
unnormalised binomial mass function that omits the parameter-constant
combinatorial term.

The data-preparation layer must:

- exclude zero-effort occasions rather than convert them to non-detections;
- include all \(C\) candidates;
- preserve stable candidate and camera identifiers;
- require binary observed outcomes and active days in \(0,\ldots,7\);
- reject duplicate or incomplete species-camera-occasion keys;
- return the original and grouped dimensions for audit; and
- prove that grouped detections and trials reconstruct the sampled input.

For the default \(C=30\), \(J=9\) design, aggregation reduces the likelihood
from approximately 56,000 candidate-camera-occasion rows to at most
\(30\times9\times7=1,890\) grouped cells without losing parameter information.

## Analytical membership marginalisation

Stan does not sample the discrete \(g_i\). Let \(\ell_i\) denote the complete
log-likelihood for candidate \(i\) conditional on \(g_i=1\).

If candidate \(i\) has at least one detection, \(g_i=0\) is impossible and:

\[
\log L_i=\log\omega+\ell_i.
\]

If its detection history is entirely zero:

\[
\log L_i
  = \log\{(1-\omega)+\omega\exp(\ell_i)\}
  = \operatorname{log\_mix}(\omega,\ell_i,0).
\]

For each posterior draw of the continuous parameters, an all-zero candidate's
conditional membership probability is:

\[
q_i
  = P(g_i=1\mid\omega,\alpha_i,\mathbf b,\mathbf y)
  = \operatorname{logit}^{-1}\{\operatorname{logit}(\omega)+\ell_i\}.
\]

Detected candidates have \(q_i=1\). Generated quantities draw

\[
g_i^{(m)}\sim\operatorname{Bernoulli}(q_i^{(m)})
\]

for all-zero candidates and calculate the integer richness draw

\[
S_{\mathrm{grid}}^{(m)}=\sum_i g_i^{(m)}.
\]

This preserves uncertainty in the discrete estimand. Reporting only
\(\sum_i q_i\) is insufficient.

Under the baseline, candidates with identical all-zero histories, effort and
no traits are exchangeable. Their marginal membership probabilities should
agree up to Monte Carlo error and should be reported symmetrically. Goal 002
does not claim to identify which particular unseen candidate is a member.

## Provisional prior profiles

Priors must be checked with prior-predictive simulation and frozen before the
frozen recovery seeds are fitted. They may be revised before that freeze if,
and only if, the prior-predictive check reveals numerical or ecological
pathology. Any revision must be recorded before recovery results are viewed.

### Primary profile

\[
\omega\sim\operatorname{Beta}(1,1),
\]

\[
\mu_\alpha\sim N(\log 10^{-3},2^2),
\]

\[
\sigma_\alpha\sim\operatorname{HalfNormal}(0,1.5),
\qquad
\sigma_b\sim\operatorname{HalfNormal}(0,0.75).
\]

### Sensitivity A — membership boundaries

Replace only:

\[
\omega\sim\operatorname{Beta}(0.5,0.5).
\]

### Sensitivity B — broader encounter-rate tail

Retain the primary membership and camera-effect priors, but replace:

\[
\mu_\alpha\sim N(\log 10^{-3},3^2),
\]

\[
\sigma_\alpha\sim\operatorname{HalfNormal}(0,2.5).
\]

The two sensitivities are kept separate so that membership-prior sensitivity
is not conflated with lower-tail sensitivity.

Prior-predictive reporting must show:

- the induced prior distribution of \(S_{\mathrm{grid}}\);
- encounter rates and detection probabilities at efforts 1 and 7;
- prior distributions of observed richness for 26 and 208 occasions; and
- the frequency of numerically extreme or ecologically implausible draws.

Prior checks may reject a profile; they may not tune it toward favourable
recovery.

## Software and artefact design

Goal 002 remains a research project rather than becoming an R package.
Proposed components are:

```text
stan/
  flexirich_g.stan
R/
  infer_data.R
  fit_flexirich_g.R
  infer_summary.R
tests/testthat/
  test-infer-data.R
  test-fit-contract.R
  test-infer-summary.R
scripts/
  setup_cmdstan.R
  check_stan_model.R
  run_goal002_smoke.R
  run_goal002_pilot.R
analysis/
  goal002_baseline_recovery.qmd
docs/goals/002-minimal-flexirich-g/
  Goal.md
  Plan.md
  Log.md
```

Expected R interfaces are:

```r
prepare_flexirich_g_data(candidate_pool, effort_weekly, detections)
sim_to_flexirich_g_data(sim)
compile_flexirich_g_model()
fit_flexirich_g(data, seed, chains, parallel_chains, ...)
summarise_flexirich_g(fit, species_ids)
```

The fit and summary interfaces must not require a `flexirich_sim`; empirical
tables with the same validated contract will be supported later. The simulator
adapter exists to prevent latent truth from entering the inference data.

The fit contract must return:

- the full posterior mass function of integer \(S_{\mathrm{grid}}\);
- posterior mean, median, mode and equal-tailed 80%, 90% and 95% intervals;
- observed richness and candidate-pool bounds;
- membership probability for every candidate;
- summaries of encounter effects and hyperparameters;
- posterior-predictive detection-frequency summaries;
- HMC diagnostics and any rescue-run flag;
- prior profile, model version, data hash, seed, R version, CmdStanR version,
  CmdStan version and sampler configuration; and
- paths or stable identifiers for the raw CmdStan outputs.

Compiled executables, CmdStan CSV files, fitted objects and generated reports
must be placed under ignored `outputs/` paths. Stan source, R source, tests,
run manifests and concise acceptance logs are committed.

## Environment and reproducibility

- Add and lock `cmdstanr` and `posterior` in the project `renv`.
- Use the verified local CmdStan 2.38.0 installation during development.
- Provide a setup/check script that records the required version and gives an
  explicit installation instruction when it is absent.
- Do not silently install or upgrade CmdStan during ordinary tests.
- Compile the Stan model once per source hash and reuse the executable.
- Use four chains for acceptance fits, with no more than four chains running
  concurrently under the 12 GB WSL memory limit.
- Record deterministic R simulation seeds and CmdStan chain seeds.
- Require statistical reproducibility of summaries and diagnostics within
  Monte Carlo error; do not require bitwise equality across compiler, Stan or
  platform versions.

## Development and validation separation

Development uses one prespecified benchmark seed in each of the six pilot
cells. These six fits may be used to:

- verify compilation and data flow;
- choose a stable non-centred parameterisation;
- benchmark runtime and storage;
- fix primary sampler settings; and
- define one, and only one, more conservative rescue profile.

Development seeds do not enter pilot results.

Before any frozen pilot fit:

1. the Stan source, priors and data contract are fixed;
2. primary and rescue sampler configurations are fixed;
3. the primary and sensitivity profiles are fixed;
4. pilot and sensitivity seeds are recorded in a committed manifest;
5. performance metrics and gates are fixed; and
6. one independent methodological/code audit is completed.

No frozen replicate may be silently discarded or replaced.

## Pilot design

The primary pilot uses Goal 001 defaults for candidate-pool size, cameras,
encounter effects and operational outages, while crossing three true-richness
levels with two sampling durations.

| Candidate pool | True richness | Occasions | Approximate duration | Frozen replicates |
|---:|---:|---:|---:|---:|
| 30 | 8  | 26  | six months | 10 |
| 30 | 20 | 26  | six months | 10 |
| 30 | 27 | 26  | six months | 10 |
| 30 | 8  | 208 | four years | 10 |
| 30 | 20 | 208 | four years | 10 |
| 30 | 27 | 208 | four years | 10 |

This yields 60 primary fits. Testing low, intermediate and high richness
protects against apparent recovery caused by a favourable prior centre.

Each sensitivity profile is applied to the first three frozen seeds in every
cell. This adds:

\[
2\text{ profiles}\times
6\text{ cells}\times
3\text{ seeds}=36
\]

sensitivity fits, for 96 frozen fits in total.

This is a pilot, not a publication-grade calibration experiment. Replication
must not be increased or reduced after viewing recovery results. A larger
study belongs in a later goal.

## Pilot metrics

For every fit, record:

- observed richness;
- posterior mean, median and mode of richness;
- 80%, 90% and 95% interval bounds and widths;
- whether each interval contains true richness;
- signed error, absolute error and squared error;
- posterior probability assigned to true richness;
- ranked probability score for the full richness distribution;
- the same score for a lower-bound-conditioned prior baseline;
- posterior mass at the observed-richness and candidate-pool boundaries;
- HMC diagnostics, elapsed time and rescue status; and
- posterior-predictive summaries of total, per-species and per-camera
  detections.

Primary performance summaries are stratified by duration and true richness.
Pooled summaries may supplement but must not replace the six cell-level
results.

The lower-bound-conditioned prior baseline treats every detected candidate as
a certain member, retains the specified membership prior for the remaining
candidates, and omits all encounter-history likelihood contributions. Thus it
has the same observed-richness lower bound as the fitted posterior. Comparing
against the unconditional prior would give the estimator an artificial
advantage merely for recognising detected species.

## Acceptance criteria

### A. Data and likelihood correctness

1. A validated adapter converts a Goal 001 simulation to inference input
   without exposing membership, true richness, latent rates or detection
   probabilities to the fit.
2. Zero-effort occasions contribute exactly zero trials.
3. Grouped counts reconstruct the sampled binary observations exactly.
4. The grouped parameter-dependent log-likelihood kernel agrees with the
   unaggregated Bernoulli kernel to a prespecified numerical tolerance.
5. A deterministic \(C\le4\) example agrees with exhaustive enumeration over
   all \(2^C\) membership vectors.
6. Hand-calculated single-cell cases verify the stable hazard likelihood.
7. Species, camera and grouped-cell ordering do not alter the likelihood or
   posterior summaries beyond Monte Carlo error.

### B. Posterior coherence

8. Every detected candidate has posterior membership probability exactly one.
9. Every all-zero membership probability is finite and lies in \([0,1]\).
10. Every richness draw is an integer in
    \([S_{\mathrm{obs}},C]\).
11. Per-draw membership values independently reconstruct the returned
    richness draw.
12. Posterior mass over the allowed richness support sums to one within
    numerical tolerance.
13. Exchangeable all-zero candidates have equal marginal membership
    probabilities within Monte Carlo tolerance.
14. Increased sampled zero-detection effort decreases conditional membership
    probability when continuous parameters are held fixed.

### C. Prior and truth alignment

15. Prior-predictive checks are completed and recorded before frozen recovery.
16. The implied richness prior agrees numerically with its analytical form.
17. The centred camera truth preserves every simulated combined log rate and
    encounter probability.
18. No fitted data object contains or can reconstruct the simulation truth
    fields other than from the observed data.

### D. Computational validity

19. Every frozen fit appears in the run manifest with success, primary failure,
    rescue result and diagnostics; no fit is omitted.
20. A clean fit has:
    - zero post-warmup divergences;
    - zero maximum-treedepth hits;
    - no chain with E-BFMI below 0.3;
    - \(\widehat R\le1.01\) for monitored continuous parameters and richness
      summaries; and
    - bulk and tail effective sample sizes of at least 400 for monitored
      continuous parameters and richness summaries.
21. At most one committed rescue configuration may be used after a primary
    fit fails.
22. At least 57 of the 60 primary fits are clean after the allowed rescue, and
    no pilot cell has fewer than 9 of 10 clean fits.
23. A non-clean fit remains in all diagnostic and failure summaries.
24. A sensitivity result is not interpreted if its corresponding fit remains
    non-clean after the allowed rescue.

### E. Pilot recovery

25. In each four-year richness cell, the equal-tailed 90% richness interval
    contains true richness in at least 8 of 10 replicates.
26. Across the 30 four-year primary fits, median absolute error of posterior
    mean richness is no greater than two species.
27. Across the 30 four-year primary fits, posterior-mean richness has lower
    median absolute error than raw observed richness.
28. Across the 30 four-year primary fits, the median posterior ranked
    probability score is lower than the median score from the
    lower-bound-conditioned prior baseline.
29. No four-year primary fit has
    \(\lvert E[S_{\mathrm{grid}}\mid y]-S_{\mathrm{true}}\rvert\ge6\).
30. Across the 30 six-month primary fits, the equal-tailed 90% richness
    interval contains true richness in at least 24 replicates.
31. Six-month bias, absolute error, interval width, prior contraction and
    boundary mass are reported without a hard point-accuracy or sharpness
    threshold.

The coverage thresholds are coarse screening gates for a small pilot. Passing
them does not establish nominal interval calibration.

### F. Prior sensitivity

32. Every prespecified sensitivity fit and any non-clean result is reported.
33. Within the nine four-year fits for each sensitivity profile, the median
    absolute shift in posterior mean richness from the primary profile is no
    greater than one species.
34. No four-year sensitivity fit shifts posterior mean richness by more than
    three species.
35. Six-month sensitivity is reported without a hard stability threshold.

### G. Reproducible deliverables

36. Stan syntax and model compilation succeed from documented commands.
37. Existing Goal 001 tests and all Goal 002 unit/oracle tests pass with no
    failure or warning.
38. The environment lock, CmdStan version check and setup instructions are
    internally consistent.
39. The frozen pilot and sensitivity manifest regenerates every fit and
    aggregate result without manual intervention.
40. A concise Quarto report regenerates from one documented command and
    distinguishes observation, posterior inference and known simulation
    truth.
41. Goal 002's log records all gates, failures, rescue fits, runtime and
    material uncertainty without describing the pilot as empirical
    validation.

## Hard failure conditions

Goal 002 is not accepted if any of the following remains after one focused
repair pass:

- the grouped likelihood disagrees with the unaggregated oracle;
- the marginal membership likelihood disagrees with exhaustive enumeration;
- posterior richness violates its exact support or reconstruction contract;
- HMC remains persistently pathological under the allowed rescue profile;
- a frozen fit is silently excluded or replaced;
- four-year recovery fails a hard pilot gate;
- prior sensitivity exceeds the four-year gates; or
- the results require tuning the model or priors after frozen recovery was
  inspected.

An informative failure is a valid scientific outcome. It should be recorded
and used to decide whether the fallback model is justified.

## Predefined fallback

If the marginalised Stan model is correct by oracle but has persistent
geometry problems, the preferred fallback is exact unseen-richness
enumeration with numerical integration over the unseen-species encounter-rate
distribution, initially using checked Gauss–Hermite quadrature.

The fallback is not part of Goal 002 automatically. Activating it requires:

1. a documented diagnosis of the Stan geometry;
2. PI approval of a revised design;
3. new numerical-oracle requirements; and
4. a separate implementation plan.

Direct discrete membership sampling in NIMBLE is a secondary alternative, not
the default fallback, because mixing along the low-rate/membership ridge may
be poor and the required tooling is not currently part of the project.

## Scope

### In scope

- CmdStanR and posterior dependency setup under `renv`.
- A version-checked external CmdStan toolchain.
- Validated inference-data construction and exact occasion aggregation.
- One marginalised FlexiRich-G Stan model.
- Prior-predictive checks and two limited prior-sensitivity profiles.
- Fit, summary, diagnostics and metadata contracts.
- Exact likelihood and membership-enumeration oracles.
- Six development benchmarks.
- The frozen 60-fit primary pilot and 36 sensitivity fits.
- A deterministic smoke fit and concise Quarto recovery report.
- One focused repair pass and one bounded independent review before the frozen
  pilot.

### Out of scope

- Empirical Judbury inference.
- Any Huon Ridge data, coordinates or tuning.
- Chao, iChao, CEGS, multispecies occupancy or other estimator comparisons.
- One-month and full sampling-intensity curves.
- Alternative or misspecified encounter distributions.
- Membership–detectability correlation.
- Spatial or temporal dependence, seasonality, turnover or transient use.
- Alternative occasion lengths.
- Candidate-pool construction, uncertainty or ALA acquisition.
- Species traits or trait-informed priors.
- False positives, classification uncertainty, event counts, abundance or
  density.
- Site-level richness or FlexiRich-S.
- Publication-grade replication, package release or manuscript claims.

## Scientific interpretation boundary

If Goal 002 passes, supported statements are limited to:

- the implemented marginal likelihood agrees with exact small-case oracles;
- the posterior richness calculation is coherent and bounded;
- the sampler is adequate for the tested correctly specified scenarios;
- the pilot has the recorded recovery, uncertainty and prior-sensitivity
  behaviour under the Goal 001 baseline.

Goal 002 cannot establish:

- empirical validity;
- robustness to misspecification;
- candidate-pool completeness;
- correct unseen-species identities;
- universal interval calibration;
- superiority to a classical or hierarchical comparator; or
- applicability to other camera arrays, taxa or temporal scales.

## Privacy and repository boundary

- No Huon Ridge observations, operational data, locations, reversible spatial
  derivatives or identifying paths may enter this repository.
- Judbury data are not required and must not enter Goal 002.
- The separate `camtrap-workflow` checkout remains a read-only methodological
  reference and is not a code dependency.
- Generated Stan outputs, fit objects and reports are ignored and must not be
  committed.

## Verification commands

The implementation plan must provide stable wrappers for, at minimum:

```sh
Rscript -e 'renv::status()'
Rscript scripts/run_tests.R
Rscript scripts/check_stan_model.R
Rscript scripts/run_goal002_smoke.R
Rscript scripts/run_goal002_pilot.R
quarto render analysis/goal002_baseline_recovery.qmd \
  --output-dir ../outputs/goal002
```

The CmdStan version check must be performed through the R setup/check wrapper
rather than a machine-specific path in the canonical command list.

## Stopping rule

Complete the likelihood oracle, minimal fit, frozen pilot, report and one
focused repair pass. Stop when the acceptance evidence is sufficient for a PI
decision.

Do not:

- add empirical data to rescue weak synthetic performance;
- add comparator models to make Goal 002 look favourable;
- retune priors or sampler settings after viewing frozen recovery;
- silently increase replication after a promising result;
- enter the fallback without a new design decision; or
- perform repeated review-and-polish loops after the material issues are
  resolved.

If two consecutive attempts yield no material improvement or evidence, record
the blocker and seek a changed methodological decision.

## Expected next goal

If Goal 002 passes, Goal 003 should test misspecification, sampling-intensity
curves and competing estimators under frozen FlexiRich-G priors and model
settings before any empirical Judbury analysis. Huon Ridge remains held out
until after public-data development choices are frozen.

## Methodological references

- Stan Development Team. *Stan User's Guide: Latent discrete parameters*.
  <https://mc-stan.org/docs/stan-users-guide/latent-discrete.html>
- Stan Development Team. *CmdStanR: the R interface to CmdStan*.
  <https://mc-stan.org/cmdstanr/>
- Royle, J. A., Dorazio, R. M. & Link, W. A. (2007). Analysis of multinomial
  models with unknown index using data augmentation. *Journal of Computational
  and Graphical Statistics*, 16, 67–85.
  <https://pubs.usgs.gov/publication/5224819>
