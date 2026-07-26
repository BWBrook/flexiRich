# Goal 001 — Minimum viable FlexiRich-G simulator

Status: complete — accepted for Goal 002 planning
Date defined: 2026-07-23

## Objective

Build and verify a small, transparent R simulator that generates camera-trap
detection histories with known grid-level species richness. The simulator will
provide the first controlled test bed for FlexiRich-G without fitting or tuning
the estimator to the Judbury observations.

Goal 001 is complete when the simulator can reproducibly generate a candidate
species pool, its true grid membership, heterogeneous encounter rates, camera
effects, day-resolved operational effort aggregated into seven-day occasions,
and binary detection histories, while preserving all latent truth needed for
later recovery tests.

## Scientific purpose

FlexiRich aims to estimate the number of camera-detectable species using a
study grid when sampling is incomplete and species differ in detectability.
Empirical camera data cannot reveal the true unseen tail directly. Simulation
is therefore required to determine whether the proposed estimator can recover
known richness, quantify its uncertainty, and fail visibly when its assumptions
are inadequate.

This first simulator is deliberately minimal. It establishes a correct
generative core before adding realistic complications or implementing the
FlexiRich-G inference model.

## Decisions already fixed

- The candidate universe is a finite, known regional species pool.
- The first estimand is whole-grid detectable-use richness.
- The empirical reference will later be the four-year Judbury
  detectable-use pool, defined as eligible species detected at least once
  anywhere in the grid during that interval.
- Primary observations are binary detections, not independent-event counts.
- Sampling occasions are seven days, with later sensitivity analysis for other
  occasion lengths.
- Operational effort is measured as active camera-days within each occasion.
- Judbury is the public development and primary empirical dataset.
- Huon Ridge is a private, held-out external validation dataset and is excluded
  from development and tuning.
- FlexiRich-G precedes the standard multispecies occupancy comparator and the
  later site-level FlexiRich-S extension.

## Baseline generative model

Let:

- \(i = 1,\ldots,C\) index candidate species;
- \(j = 1,\ldots,J\) index camera sampling units;
- \(k = 1,\ldots,K\) index seven-day occasions;
- \(g_i \in \{0,1\}\) indicate whether species \(i\) belongs to the true
  grid-level detectable-use pool;
- \(E_{jk} \in [0,7]\) be active camera-days;
- \(r_{ij} > 0\) be encounter intensity per active camera-day; and
- \(y_{ijk} \in \{0,1\}\) indicate at least one valid detection when
  \(E_{jk}>0\); zero-effort observations are stored as missing, not as sampled
  non-detections.

For the baseline simulator,

\[
\log r_{ij} = \alpha_i + b_j,
\]

with the baseline effects

\[
\alpha_i \sim \operatorname{Normal}(\mu_\alpha,\sigma_\alpha)
\quad\text{and}\quad
b_j \sim \operatorname{Normal}(0,\sigma_b).
\]

Exactly \(S_{\mathrm{true}}\) members are selected uniformly without
replacement from the \(C\) candidates. In the baseline, membership is
generated independently of \(\alpha_i\), \(b_j\), and operational effort.
Relationships between membership and detectability belong to later
misspecification scenarios.

The effort-aware detection probability is

\[
p_{ijk} = 1-\exp(-E_{jk}r_{ij}),
\]

and, for camera-occasions with positive effort, observations are generated as

\[
y_{ijk} \sim \operatorname{Bernoulli}(g_i p_{ijk}).
\]

The true richness is

\[
S_{\mathrm{true}} = \sum_{i=1}^{C} g_i.
\]

The baseline distribution family is a simulation choice, not a claim that
real species encounter rates are lognormal. Later goals must test inference
under alternative and misspecified data-generating processes.

## Required simulator contract

One simulation run must return a structured object containing:

1. **Configuration**
   - random seed;
   - candidate-pool size;
   - true richness;
   - number of cameras and occasions;
   - parameter values and distribution settings.
2. **Candidate species table**
   - stable synthetic species identifier;
   - true grid-membership indicator;
   - latent species encounter effect.
3. **Camera table**
   - stable synthetic camera identifier;
   - latent camera effect.
4. **Effort table**
   - camera, occasion and active camera-days;
   - the underlying daily 0/1 operational schedule from which occasion effort
     is derived.
5. **Detection history**
   - binary species × camera × occasion observations;
   - missing observations, plus an explicit sampling indicator, when effort is
     zero.
6. **Truth record**
   - true richness;
   - all latent encounter rates and detection probabilities;
   - observed richness and numbers of unseen true members and correctly absent
     candidate species.
7. **Run metadata**
   - simulator version;
   - timestamp;
   - enough information to reproduce the run exactly.

## Scope

### In scope

- An R implementation with small, explicit functions.
- Configurable \(C\), \(S_{\mathrm{true}}\), \(J\), \(K\), encounter-rate
  heterogeneity, camera heterogeneity, and effort completeness.
- Synthetic daily operational histories and aggregation to seven-day effort.
- Optional ingestion of a supplied day-resolved effort table containing
  exactly one binary operating state for every configured camera-date
  combination, without embedding Judbury observations or Huon Ridge data.
- A small illustrated Judbury-shaped scenario with nine nominal cameras,
  approximately four years (208 seven-day occasions), and synthetic outages.
- Deterministic unit tests and scientific invariant checks.
- A concise vignette or report showing the generated truth, observed richness,
  effort, detection frequencies, and species-discovery trajectory.

### Out of scope

- Fitting FlexiRich-G or any Bayesian model.
- Chao, CEGS, multispecies occupancy, or other estimator comparisons.
- Empirical inference from Judbury.
- Any access to, storage of, or tuning against Huon Ridge.
- Site-level richness or FlexiRich-S.
- ALA candidate-pool acquisition.
- Species traits or trait-informed priors.
- Spatial autocorrelation, seasonal turnover, transient species, false
  positives, classification uncertainty, group size, or event counts.
- Exhaustive simulation scenarios, package publication, or a manuscript claim.

These exclusions define later goals; they are not claims that the omitted
processes are unimportant.

## Acceptance criteria

Goal 001 passes when all of the following are demonstrated:

1. Identical configurations and seeds return identical simulated data and
   truth.
2. Candidate-pool size, true richness and array dimensions match the requested
   values.
3. Non-members (\(g_i=0\)) are never detected.
4. Zero-effort camera-occasions are explicitly unsampled and cannot generate
   detections.
5. Aggregated effort \(E_{jk}\) equals the exact sum of the corresponding
   day-resolved operating states.
6. Returned encounter rates and probabilities independently reproduce
   \(r_{ij}=\exp(\alpha_i+b_j)\),
   \(p_{ijk}=1-\exp(-E_{jk}r_{ij})\), and the observation probability
   \(g_i p_{ijk}\).
7. Seed-controlled Bernoulli draws reproduce the returned detection history,
   demonstrating that observations were sampled from the returned
   probabilities.
8. All detection probabilities lie in \([0,1]\), all encounter rates are
   positive, and every sampled observation is binary.
9. Detection probability is analytically non-decreasing with operational
   effort for fixed encounter rate.
10. Observed richness never exceeds true richness, and true richness never
   exceeds candidate-pool size.
11. The truth record is sufficient to calculate missed-member and false-member
   classifications without reconstructing latent values.
12. At least one low-detection and one high-detection scenario run successfully
   and show the expected qualitative difference in observed richness.
13. Automated tests pass, and the illustrated scenario can be regenerated
    from one documented command.

The illustrated scenario is explanatory evidence, not a statistical validation
study.

## Verification and review

Verification will include:

- unit tests for dimensions, types, bounds, deterministic behaviour, exact
  effort aggregation, and independent reconstruction of every generative
  equation;
- targeted edge cases, including no effort, complete effort, no true species,
  and all candidate species present where mathematically supported;
- independent recomputation of true and observed richness from returned
  tables;
- one focused self-review and repair pass; and
- PI review of the simulator contract and illustrated output before Goal 002.

## Risks and limitations

- A simulator can make its paired estimator look successful if both share the
  same assumptions. Goal 001 only establishes the baseline; later hostile
  simulations are mandatory.
- A finite known candidate pool reduces but does not remove confounding between
  absence and extremely low encounter rate.
- A Judbury-shaped design improves relevance but does not establish
  generality.
- Seven-day aggregation may not remove all temporal dependence.
- Grid membership is an operational detectable-use estimand, not abundance,
  density, strict residency, or proof of ecological absence.

## Privacy and repository boundary

- No Huon Ridge observations, operational records, camera coordinates,
  reversible spatial derivatives, or identifying paths may enter this
  repository.
- The separate `camtrap-workflow` checkout is a read-only methodological
  reference, not a code dependency or shared pipeline.
- Judbury data may be incorporated only under an appropriate public-data or
  project-data decision in a later goal.

## Stopping rule

Stop Goal 001 after the acceptance criteria, illustrated scenario, and one
focused repair pass are complete. Do not expand into additional ecological
processes merely to polish the simulator. If two consecutive attempts yield no
material improvement, document the limitation and seek a design decision
rather than repeating the same approach.

## Expected next goal

Goal 002 should implement the minimal FlexiRich-G inference model and close the
first simulation-recovery loop under the correctly specified baseline. Model
misspecification, competing estimators and empirical Judbury analysis should
follow only after that vertical slice is working and reviewed.
