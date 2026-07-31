# Goal 002R — Collapsed unseen-richness computation

Status: proposed for PI review
Date defined: 2026-07-31

## Objective

Implement and test a computationally collapsed re-expression of the Goal 002
FlexiRich-G model for a finite, known candidate species pool. The candidate
implementation will integrate over the encounter effects of never-detected
species and reconstruct unseen richness without sampling one weakly identified
encounter effect for every all-zero candidate.

Goal 002R is complete when it supports a prespecified **RETAIN**, **REJECT** or
**INCONCLUSIVE** decision about the collapsed computation. The decision must
be based on:

1. deterministic numerical and mathematical-equivalence evidence;
2. computational behaviour under the unchanged Goal 002 diagnostic contract;
3. fresh-seed recovery and sensitivity evidence;
4. loss-aligned point summaries and a proper full-distribution score; and
5. a frozen, reproducible separation between development and confirmation.

Goal 002R is a repair of computation and evaluation, not an opportunity to
alter the ecological model until a structural defect is demonstrated.

## Scientific purpose

Goal 002 closed as an
[informative method failure](../002-minimal-flexirich-g/Log.md#outcome). Its
three failed criteria represent two different issues.

First, Criterion 27 compared posterior-mean richness with raw observed
richness using absolute error. A posterior mean is the Bayes action under
squared loss, not absolute loss. The frozen result also pooled three very
different richness strata through a median: raw richness was often already
exact in the low-richness four-year cell, while posterior inference recovered
substantial unseen richness in the high-richness cell. The historical failure
must remain unchanged, but it does not by itself diagnose an ecological-model
defect.

Second, Criteria 33 and 34 failed because one four-year
membership-sensitivity fit remained non-clean after rescue. Its assigned
30-species shift was the prespecified fail-closed sentinel, not an estimated
posterior shift. The underlying difficulty is plausibly the
membership--low-encounter-rate ridge: the current model samples an encounter
effect for every never-detected candidate even when the data give little
information about whether that candidate is absent or merely difficult to
detect.

The [Goal 002 recommendation](../002-minimal-flexirich-g/Log.md#recommendation)
stopped that model version and required a separate PI-approved repair design.
The [predefined Goal 002 fallback](../002-minimal-flexirich-g/Goal.md#predefined-fallback)
is therefore activated in a separate, bounded goal. Collapsing the unseen
encounter effects should improve posterior geometry and numerical efficiency.
Because it is intended to preserve the same posterior distribution, it should
not be expected to improve statistical recovery relative to a correctly
sampled Goal 002 fit beyond numerical and Monte Carlo error.

## Decisions already fixed

- The candidate universe remains a finite, known regional species pool.
- The estimand remains whole-grid detectable-use richness during a defined
  period.
- Input observations remain species × camera × seven-day binary detections.
- Operational effort remains exact active camera-days within each occasion.
- The Goal 002 membership, encounter-rate, camera-effect and effort-aware
  observation models remain unchanged.
- The accepted `primary-v1`, `sensitivity-membership-v1` and
  `sensitivity-tail-v2` prior profiles remain unchanged.
- The existing primary and single-rescue sampler profiles and their diagnostic
  thresholds remain unchanged for the comparison.
- Never-detected encounter effects are integrated numerically; candidate
  membership and unseen richness remain analytically marginalised rather than
  being sampled as discrete Stan parameters.
- Checked Gauss--Hermite quadrature is the primary numerical method, with an
  independently implemented adaptive-integration oracle.
- The numerical approximation is fixed using deterministic fixtures before
  any fresh recovery result is inspected.
- Posterior median richness is the point action evaluated under absolute loss.
- Posterior mean richness is the point action evaluated under squared loss.
- Ranked probability score is the primary full-distribution performance
  measure.
- Candidate-versus-Goal-002 comparison is a posterior-fidelity and
  computational comparison, not a search for improved statistical accuracy.
- Historical Goal 002 seeds and results are audit and diagnostic evidence
  only. All new performance evidence uses fresh, prespecified seeds.
- Development and confirmation are separate, with no automatic increase in
  replication after confirmation is inspected.
- Empirical Judbury data, all Huon Ridge data and all site-level modelling
  remain outside this goal.

## Relationship to Goal 002

Goal 002R succeeds Goal 002 but does not amend it. In particular:

- Goal 002 remains complete as an informative method failure;
- its source, priors, manifests, frozen outputs, thresholds, denominators and
  conclusions remain immutable;
- its frozen acceptance results cannot be rescored as replacement evidence;
- its implementation is the fixed baseline comparator on fresh data; and
- the collapsed implementation receives a separate source identity,
  configuration, manifest, output boundary and decision record.

The Goal 002 model source used as the comparator has SHA-256
`659b335b0e9eaffecb2629d06a768c419d00f3c3a8719fa99f67ea6c4171cb91`.
The Goal 002 closure is committed at
`1c08fb4c372d8961e533c1b3665d1bb9221d9280`. These identities are historical
anchors, not permission to modify the old implementation.

The one historical replay in Goal 002R uses
`frozen-c05-r03-membership`, the membership-sensitivity fit that remained
non-clean. It is a labelled computational stress test only. It contributes
nothing to recovery, sensitivity or confirmation metrics, and no numerical,
prior or sampler choice may be selected from its result.

## Estimand and notation

Retain the Goal 002 notation and define:

- \(C\): candidate-pool size;
- \(D\): set of candidates detected at least once;
- \(S_{\mathrm{obs}}=|D|\): observed richness;
- \(Z\): set of candidates never detected;
- \(U=|Z|=C-S_{\mathrm{obs}}\): unseen candidate capacity;
- \(g_i\in\{0,1\}\): candidate membership in the grid-level detectable-use
  pool;
- \(\omega\): community membership prevalence;
- \(\alpha_i\): species encounter effect;
- \(\mu_\alpha,\sigma_\alpha\): encounter-effect hyperparameters;
- \(\mathbf b\): sum-to-zero camera effects; and
- \(S_{\mathrm{grid}}=\sum_i g_i\): target richness.

Every detected candidate has \(g_i=1\) in the conditional posterior. Every
posterior richness value therefore lies in
\(\{S_{\mathrm{obs}},\ldots,C\}\).

## Collapsed unseen-richness computation

For a never-detected candidate, let

\[
\ell_0(\alpha,\mathbf b)
  = \log P(\mathbf y_i=\mathbf 0
      \mid g_i=1,\alpha,\mathbf b)
\]

be the same stable, effort-aware zero-detection log-likelihood used by Goal
002. Under the current exchangeable candidate contract, all candidates in
\(Z\):

- share the same complete sampled camera-effort and all-zero detection
  history;
- have identical membership and encounter-rate priors;
- have no species-specific traits or covariates; and
- are conditionally independent given the shared community parameters.

Conditional on the community hyperparameters and camera effects, their
integrated member likelihood is

\[
m_0(\mu_\alpha,\sigma_\alpha,\mathbf b)
  =
  \int
  \exp\{\ell_0(\alpha,\mathbf b)\}
  \phi(\alpha\mid\mu_\alpha,\sigma_\alpha)\,d\alpha.
\]

The marginal likelihood contribution of the \(U\) all-zero candidates is

\[
\left[
  (1-\omega)+\omega m_0
\right]^U.
\]

Their common conditional membership probability is

\[
q_0
  =
  \frac{\omega m_0}
       {(1-\omega)+\omega m_0}.
\]

Conditional on the sampled continuous community parameters,

\[
K_{\mathrm{unseen}}
  \sim \operatorname{Binomial}(U,q_0),
\qquad
S_{\mathrm{grid}}
  = S_{\mathrm{obs}}+K_{\mathrm{unseen}}.
\]

The complete conditional binomial PMF over
\(K_{\mathrm{unseen}}=0,\ldots,U\) must be constructed separately for every
posterior draw and then averaged across draws. Substituting a binomial PMF
evaluated at posterior-mean \(q_0\) is incorrect and prohibited.

If a future model gives never-detected candidates distinct observation
histories or species-specific predictors, their \(m_{0i}\) and \(q_{0i}\)
values will differ and the conditional unseen-richness distribution becomes
Poisson-binomial. That extension is not part of Goal 002R.

For Gauss--Hermite nodes \(x_h\) and weights \(w_h\),

\[
m_0
  \approx
  \frac{1}{\sqrt{\pi}}
  \sum_{h=1}^{H}
  w_h
  \exp\left\{
    \ell_0\left(
      \mu_\alpha+\sqrt{2}\sigma_\alpha x_h,
      \mathbf b
    \right)
  \right\}.
\]

The implementation must evaluate this expression in stable log space.
Quadrature order \(H\) is fixed from the numerical certificate before
development fitting.

## Mathematical-equivalence requirements

The collapsed candidate must preserve:

- the prior and likelihood for \(\omega\), \(\mu_\alpha\),
  \(\sigma_\alpha\), \(\sigma_b\) and the camera effects;
- the likelihood and encounter-effect posterior for detected candidates;
- the zero-effort and exact occasion-aggregation contracts;
- the marginal likelihood for every never-detected candidate;
- the support and normalization of the richness posterior;
- marginal membership probabilities for detected and never-detected
  candidates;
- the existing lower-bound-conditioned prior comparator; and
- the interpretation of \(S_{\mathrm{grid}}\).

The following language distinctions are mandatory:

- membership and unseen-count enumeration are exact conditional on the
  continuous parameters;
- integration over unseen encounter effects is numerical and certified to a
  declared tolerance;
- the combined computation must not be described as wholly exact;
- close posterior agreement with Goal 002 is evidence of fidelity, not
  independent ecological validation; and
- a material statistical-performance difference from a clean Goal 002 fit
  would indicate Monte Carlo error, numerical error or an unintended model
  change rather than a successful repair.

The bounded prototype must return:

- a complete richness PMF on \(0{:}C\), with zero mass below
  \(S_{\mathrm{obs}}\);
- posterior mean, median, mode and equal-tailed intervals;
- expected membership for every named candidate;
- the detected-candidate encounter-effect summaries;
- community and camera-effect summaries;
- aggregate posterior-predictive summaries sufficient to test total,
  per-camera and detected-species detection counts;
- numerical-integration diagnostics;
- HMC diagnostics, rescue status and elapsed time; and
- source, configuration, data and output provenance.

All discrete posterior quantiles use

\[
Q(p)=\min\{s:F(s)\ge p\}.
\]

Posterior median is \(Q(0.5)\), and the equal-tailed 90% interval is
\([Q(0.05),Q(0.95)]\). These conventions are fixed before loss and coverage
are evaluated.

HMC monitoring must include the community and camera parameters,
detected-species encounter effects, the common unseen \(q_0\) or its integrated
log-likelihood, expected richness, and continuous lower- and upper-tail
richness-mass summaries.

Candidate-specific encounter-effect summaries for never-detected species are
not required in the bounded prototype because those effects have been
integrated out. They must not be silently replaced by prior draws or described
as identified posterior effects.

For posterior-predictive simulation, never-detected candidates must be
conditioned on their observed all-zero histories. At each continuous posterior
draw, define quadrature support

\[
\alpha_h
  = \mu_\alpha+\sqrt{2}\sigma_\alpha x_h
\]

and normalized conditional node weights

\[
\pi_h
  =
  \frac{
    w_h\exp\{\ell_0(\alpha_h,\mathbf b)\}
  }{
    \sum_{r=1}^{H}
    w_r\exp\{\ell_0(\alpha_r,\mathbf b)\}
  }.
\]

For each never-detected candidate in a posterior-predictive replicate:

1. draw membership from \(\operatorname{Bernoulli}(q_0)\);
2. if it is a member, draw one node from
   \(\operatorname{Categorical}(\boldsymbol\pi)\); and
3. generate the complete replicate detection history using that node's
   encounter effect and the unchanged effort-aware observation model.

Using one node for the complete candidate history preserves the dependence
induced by its shared species effect. These generated quantities do not
reintroduce unseen encounter effects into the HMC target and do not support
named unseen-species effect estimates.

## Numerical certificate

No development fit may run until all deterministic checks pass and the
quadrature rule is frozen.

The certificate must include:

1. the Gauss--Hermite convention, including weights summing to
   \(\sqrt{\pi}\) and the
   \(\mu_\alpha+\sqrt{2}\sigma_\alpha x_h\) transformation;
2. exact reproduction of Normal moments on deterministic fixtures;
3. comparison with an independently implemented, high-accuracy adaptive
   integral over a prespecified grid of
   \(\mu_\alpha,\sigma_\alpha\), camera effects, effort and hazard regimes
   spanning prespecified prior-predictive quantiles from the primary and both
   sensitivity profiles, plus boundary and interior values of \(\omega\) and
   unseen capacity \(U\);
4. maximum absolute error no greater than \(10^{-8}\) for each finite,
   load-bearing log-integral and richness-tail quantity on that grid, with
   limiting infinite or point-mass cases checked analytically;
5. convergence of the selected quadrature order against a prespecified
   higher-order rule;
6. stable behaviour for no effort, overwhelming effort, very low encounter
   rates, high encounter rates, \(\sigma_\alpha\) approaching zero and broad
   encounter-rate tails;
7. exhaustive membership-vector and unseen-count agreement for small
   candidate pools;
8. exact richness support, normalization, lower-bound and permutation
   invariants;
9. agreement between the R and Stan likelihood kernels at fixed inputs; and
10. agreement of conditional quadrature weights and integrated
    posterior-predictive moments with an independent adaptive-integration
    reference; and
11. proof that the independent oracles do not call production integration or
    richness code.

The \(10^{-8}\) tolerance is a numerical-certification threshold, not a
posterior Monte Carlo threshold. If the selected quadrature order fails any
fixture, it may be increased before fitting. The fixture grid, reference
implementation and selected order must then be committed and frozen together.

## Development and confirmation separation

Before development:

- define separate development and confirmation seed namespaces;
- commit the candidate mathematical and numerical configuration;
- commit the numerical fixture grid, selected quadrature order and tolerances;
- commit the baseline and candidate source identities;
- commit the sampler, diagnostic, scoring and decision contracts;
- create canonical development and confirmation manifests; and
- verify that truth fields can enter scoring but cannot enter either fit.

For run accounting, one **fit** is one scheduled
dataset × implementation × prior-profile terminal row. A primary attempt and
its permitted rescue are attempts within that one fit. A failed terminal row
still counts against the stated fit budget and can never be replaced.

Development results may expose deterministic implementation defects. One
focused repair pass is permitted before confirmation. The pass may correct
code or numerical implementation, but it may not:

- change the ecological model or candidate-pool estimand;
- change priors or sensitivity profiles;
- change sampler settings or diagnostic thresholds;
- choose quadrature settings from recovery performance;
- replace or add development datasets;
- inspect confirmation outputs; or
- weaken an acceptance criterion.

A changed scientific model or numerical target constitutes a new candidate
and requires a new PI decision and new seed namespaces. Once confirmation
begins, source, settings, seeds, metrics and thresholds are immutable.

## Development design

Development contains at most 19 fits.

### Historical computational stress test

Run the frozen candidate implementation once on the reconstructed observed
data for `frozen-c05-r03-membership`. Its outcome is diagnostic only:

- a clean fit supports the proposed geometry repair;
- a non-clean fit blocks confirmation; and
- neither its posterior nor runtime contributes to performance summaries.

### Six fresh development datasets

Generate one fresh dataset in each Goal 002 cell:

| True richness | Occasions |
|---:|---:|
| 8 | 26 |
| 20 | 26 |
| 27 | 26 |
| 8 | 208 |
| 20 | 208 |
| 27 | 208 |

Fit the Goal 002 baseline and collapsed candidate under the primary profile to
all six datasets, producing 12 fits. On the three four-year datasets, fit the
candidate under both sensitivity profiles, producing six further fits.

Development evaluates interfaces, numerical fidelity, diagnostics, posterior
contracts, posterior-predictive reconstruction, runtime and rescue behaviour.
It contributes no confirmation loss, coverage or sensitivity result.

## Confirmation design

Confirmation contains exactly 78 scheduled fits on 30 new datasets.

Generate:

- eight replicates in each of the three 208-occasion richness cells, giving
  24 four-year datasets; and
- two replicates in each of the three 26-occasion richness cells, giving six
  six-month datasets.

Fit the Goal 002 baseline and collapsed candidate under the primary profile to
all 30 datasets, giving 60 primary fits. On the first three prespecified
four-year replicates in each richness cell, fit the candidate under both
sensitivity profiles, giving 18 sensitivity fits.

Thus confirmation contains:

- 30 Goal 002 baseline primary fits;
- 30 collapsed-candidate primary fits; and
- 18 collapsed-candidate sensitivity fits.

Every scheduled row and every primary or rescue attempt must remain in the
manifest and final report. No failed, inconvenient or incomplete row may be
replaced.

## Comparators and performance measures

### Posterior fidelity

The Goal 002 baseline and collapsed candidate target the same posterior.
Compare their full richness PMFs on every complete clean four-year primary
pair using one-dimensional Wasserstein distance:

\[
W_1(P,Q)
  =
  \sum_{s=0}^{C-1}
  |F_P(s)-F_Q(s)|.
\]

For a chain-aware Monte Carlo check, pool odd-indexed post-warmup draws within
each chain to form one half-draw PMF and pool even-indexed draws to form the
other. For each implementation define \(W_{\mathrm{MC}}\) as the \(W_1\)
distance between those two half-draw PMFs.

Every one of the 24 four-year pairs must satisfy:

- full-draw candidate-versus-baseline \(W_1\le0.10\) species;
- baseline \(W_{\mathrm{MC}}\le0.10\) species; and
- candidate \(W_{\mathrm{MC}}\le0.10\) species.

The 0.10-species bound is a PI-selected posterior-fidelity and Monte Carlo
stability margin, not an ecological effect size. A full-draw \(W_1\) above
0.10 when both within-method values pass is a material fidelity failure. A
within-method value above 0.10 makes the pair **INCONCLUSIVE** because the
posterior comparison is not precise enough.

All 24 four-year Goal 002 baseline fits must be terminal-clean for a complete
confirmation comparison. A baseline failure makes posterior fidelity and
paired scientific value **INCONCLUSIVE** rather than making the candidate
fail.

### Point losses

For each four-year confirmation dataset:

- absolute loss uses the candidate posterior median;
- squared loss uses the candidate posterior mean; and
- raw observed richness is the point comparator.

For a paired loss difference, first take its mean within each true-richness
cell and then take the unweighted mean of the three cell means. This
stratum-balanced mean prevents one richness level from dominating the result.
Report all dataset-level and cell-level results as well as the aggregate.

Use a committed fixed bootstrap seed and exactly 10,000 paired, stratified
bootstrap replicates. Within each replicate, sample eight dataset indices with
replacement separately inside each of the three four-year true-richness
strata, carrying all candidate, raw and comparator values for a selected
dataset together. Recalculate the three stratum means and their unweighted
mean. The 90% percentile interval is the empirical 5th and 95th percentiles,
computed with R quantile type 8. No BCa correction or unpaired resampling is
permitted.

For candidate-minus-raw absolute loss, the upper interval bound must be no
greater than \(+0.25\) species. This is a PI-selected non-inferiority margin,
not an estimate derived from Goal 002. Candidate posterior-mean RMSE must be
no greater than raw-richness RMSE, where each RMSE is the square root of the
stratum-balanced mean squared loss. This is a secondary squared-loss safety
gate.

Candidate-versus-baseline point-accuracy improvement is not an acceptance
criterion because the two implementations target the same posterior.

### Full-distribution score

Compare the candidate richness PMF with the profile-matched Goal 002
lower-bound-conditioned prior comparator using the unnormalised ranked
probability score

\[
\operatorname{RPS}(F,S_{\mathrm{true}})
  =
  \sum_{s=0}^{C-1}
  \left[
    F(s)-I(S_{\mathrm{true}}\le s)
  \right]^2.
\]

The primary probabilistic gate is the stratum-balanced mean paired
candidate-minus-comparator RPS difference across the 24 four-year datasets.
Its stratified-bootstrap 90% upper bound must be below zero.

### Coverage, catastrophic error and sensitivity

- The equal-tailed 90% candidate richness interval must cover true richness in
  at least 7 of 8 replicates in each four-year richness cell.
- No four-year candidate fit may have posterior-mean absolute error of six or
  more species.
- All 18 candidate sensitivity fits must be terminal-clean.
- Within each sensitivity profile, the median absolute shift in posterior-mean
  richness from the paired candidate primary fit must be no greater than one
  species.
- No sensitivity fit may shift posterior-mean richness by more than three
  species.
- Six-month correctness, diagnostics, posterior-predictive behaviour,
  interval width, boundary mass and point performance are reported without a
  hard point-accuracy or sharpness threshold.

## Computational contract

Retain the Goal 002 clean-fit requirements:

- zero post-warmup divergences;
- zero maximum-treedepth hits;
- no chain with E-BFMI below 0.3;
- \(\widehat R\le1.01\) for monitored continuous and integrated-richness
  quantities; and
- bulk and tail effective sample sizes of at least 400 for those quantities.

At most the existing one committed rescue profile may follow a non-clean
primary attempt.

All 48 collapsed-candidate confirmation fits must be terminal-clean after the
allowed rescue. Candidate primary rescue use across the 30 paired datasets
must be lower than Goal 002 baseline rescue use. If it is not lower, the
repair has not shown its intended operational value and the result is
**INCONCLUSIVE**.

Report elapsed time and output size for every attempt. Confirmation runtime is
the sum of sampling elapsed seconds for every primary and rescue attempt
belonging to the 30 primary fits for an implementation. It excludes model
compilation, data simulation, reporting and validation overhead. Baseline and
candidate must run under equivalent processor and chain-parallel settings.

If candidate confirmation runtime divided by paired baseline confirmation
runtime exceeds two, the operational verdict is unconditionally
**INCONCLUSIVE**. Development timing may motivate the single permitted
pre-confirmation repair, but confirmation runtime cannot trigger post hoc
optimization or waive this gate.

## Decision rule

Decision precedence is fixed:

1. any **REJECT** condition overrides every inconclusive or favourable result;
2. if no rejection condition holds but any **INCONCLUSIVE** condition holds,
   the verdict is inconclusive; and
3. **RETAIN** is available only when every retain requirement passes.

### RETAIN

Retain the collapsed computation for the next scientific goal only if all of
the following hold:

1. every deterministic mathematical and numerical certificate passes;
2. posterior-fidelity margins pass on all required complete pairs;
3. all 48 candidate confirmation fits are terminal-clean;
4. candidate primary rescue use is lower than baseline rescue use;
5. the candidate does not exceed the twofold runtime boundary;
6. candidate posterior-median absolute loss is non-inferior to raw richness;
7. candidate posterior-mean RMSE is no greater than raw-richness RMSE;
8. candidate RPS improves on the lower-bound-conditioned comparator;
9. coverage and catastrophic-error requirements pass;
10. all sensitivity requirements pass; and
11. every manifest, provenance and regeneration requirement passes.

### REJECT

Reject the collapsed computation if:

- a deterministic likelihood, integration, enumeration or PMF check fails;
- posterior fidelity fails materially;
- any candidate confirmation fit remains non-clean after rescue;
- a coverage, catastrophic-error or sensitivity hard gate fails;
- the absolute-loss interval lies wholly above the \(+0.25\)-species
  non-inferiority margin;
- the RPS interval lies wholly above zero; or
- confirmation exposes leakage, replacement, provenance or regeneration
  failure.

### INCONCLUSIVE

Classify the result as inconclusive if no rejection condition occurs but:

- any required baseline four-year pair remains non-clean;
- the absolute-loss interval has lower bound at or below \(+0.25\) but upper
  bound above \(+0.25\);
- the RPS interval has lower bound at or below zero and upper bound at or
  above zero;
- a within-method \(W_{\mathrm{MC}}\) value exceeds 0.10 species;
- candidate posterior-mean RMSE exceeds raw-richness RMSE;
- rescue use is not lower than baseline;
- candidate runtime exceeds twice baseline; or
- an exogenous infrastructure or resource interruption prevents creation of a
  valid terminal row under otherwise unchanged settings.

An inconclusive result does not provisionally retain the candidate. It ends
Goal 002R and returns the next step to a PI decision.

A fit that completes the prescribed primary and rescue attempts but remains
non-clean is a candidate computational failure and therefore **REJECT**, not a
resource-based inconclusive result.

## Acceptance criteria

Goal 002R passes with a **RETAIN** verdict only when:

1. Goal 002 source and frozen evidence remain byte- and Git-identifiable and
   unmodified.
2. The collapsed likelihood is derived and implemented without changing the
   Goal 002 statistical model.
3. All numerical-certificate checks pass at their prespecified tolerances.
4. Independent small-case enumeration agrees with production unseen-richness
   probabilities.
5. R and Stan kernels agree at fixed inputs.
6. The collapsed PMF is finite, normalized, permutation invariant and
   supported only on \(S_{\mathrm{obs}}{:}C\).
7. Detected membership is exactly one and never-detected expected memberships
   reconstruct posterior mean richness.
8. Truth fields are unavailable to both baseline and candidate fits.
9. The 19-fit development maximum and 78-fit confirmation manifest are
   respected exactly.
10. Development and confirmation seeds are distinct and frozen before their
    respective outputs are inspected.
11. Every candidate fit passes the computational contract after at most one
    rescue.
12. Posterior fidelity, point-loss, RPS, coverage, catastrophic-error and
    sensitivity gates all pass.
13. Candidate rescue use demonstrates operational improvement.
14. Runtime remains within the operational boundary.
15. All scheduled rows, attempts, diagnostics, hashes and outputs regenerate
    without manual replacement.
16. A concise report distinguishes observation, posterior inference, known
    simulation truth, numerical approximation and decision inference.
17. One focused implementation review precedes development, and one
    independent frozen-evidence review precedes the final verdict.

A **REJECT** or **INCONCLUSIVE** verdict is a valid completion of Goal 002R,
but it does not pass the candidate forward.

## Hard failure conditions

Stop without confirmation if any of the following remains after the single
development repair pass:

- the integrated likelihood disagrees with the independent oracle;
- quadrature convergence or tail fixtures fail;
- exhaustive enumeration or PMF reconstruction fails;
- the Stan and R kernels disagree;
- the historical stress replay remains non-clean;
- any fresh candidate development fit remains non-clean;
- source, seed, truth-isolation or output provenance is ambiguous; or
- a proposed repair requires changing a prior, sampler threshold, model family
  or scientific estimand.

Any such unresolved development failure selects **REJECT**.

After confirmation begins, any candidate terminal non-clean fit or hard
scientific failure selects **REJECT**. No confirmation row may be rerun under
a replacement seed or altered candidate.

## Scope

### In scope

- A parallel collapsed FlexiRich-G implementation.
- Stable log-space Gauss--Hermite integration.
- Independent adaptive-integration and exhaustive-enumeration oracles.
- A PMF-compatible grid-richness summary.
- Detected-species, community, camera and aggregate posterior-predictive
  summaries.
- Numerical, HMC, runtime and provenance diagnostics.
- One historical computational stress replay.
- Six fresh development datasets and at most 18 associated fresh-data fits.
- Thirty fresh confirmation datasets and exactly 78 confirmation fits.
- The unchanged Goal 002 implementation, raw richness and
  lower-bound-conditioned prior as defined comparators.
- One focused development repair pass and bounded independent reviews.
- A concise reproducible report and durable decision record.

### Out of scope

- Any change to Goal 002 source, frozen outputs or verdict.
- Prior, sampler or threshold retuning against recovery results.
- A different membership, encounter-rate or camera-effect model.
- Truncated tails, new abundance mixtures or extra latent classes.
- Species traits, trait-informed priors or membership--detectability
  dependence.
- Alternative or misspecified generative distributions.
- Sampling-intensity curves beyond the existing six-month and four-year
  design.
- Alternative occasion lengths.
- Spatial or temporal dependence, turnover, transient use or false positives.
- Site-level richness or FlexiRich-S.
- Classical, CEGS or multispecies-occupancy comparators.
- Empirical Judbury inference.
- Any Huon Ridge data, coordinates or tuning.
- Package publication or manuscript-performance claims.

## Scientific interpretation boundary

A RETAIN verdict may support the following limited statements:

- the collapsed computation reproduces the Goal 002 posterior within declared
  numerical and Monte Carlo tolerances;
- numerical integration and unseen-richness reconstruction pass independent
  deterministic checks;
- the collapsed computation has acceptable tested HMC geometry and lower
  rescue use;
- the candidate has the recorded best-case recovery, calibration and prior
  sensitivity under the correctly specified Goal 001 family; and
- the candidate is justified for the next synthetic validation goal.

Goal 002R cannot establish:

- empirical validity for Judbury or any other camera array;
- superiority to a different statistical richness model;
- robustness to model misspecification;
- correctness of the candidate pool;
- correct identities of unseen species;
- universal interval calibration;
- site-level richness;
- abundance or density; or
- publication-ready performance.

## Risks and limitations

- Mathematical equivalence does not remove the fundamental confounding between
  absence and very low encounter rate.
- Gauss--Hermite integration may require high order in broad or asymmetric
  posterior tail regimes; the deterministic certificate only bounds the
  tested domain.
- Count-level unseen-richness enumeration relies on exchangeable
  never-detected candidates with common observation opportunities.
- Integrating never-detected encounter effects removes named posterior effect
  summaries for those candidates.
- Twenty-four four-year confirmation datasets provide a bounded screen, not a
  high-precision performance trial.
- Four-year raw richness may be nearly saturated in low-richness communities,
  leaving little room for point-estimate improvement even when uncertainty is
  represented correctly.
- A fixed \(+0.25\)-species non-inferiority margin and posterior-fidelity
  margins are PI-selected decision values, not universal ecological constants.
- Strict all-clean confirmation may reject a useful computation because of a
  rare stochastic HMC failure; the rule is retained because computational
  robustness is the central repair claim.

## Privacy and repository boundary

- No Huon Ridge observations, operational records, locations, reversible
  spatial derivatives or identifying paths may enter this repository.
- Judbury observations are not required and must not enter Goal 002R.
- The separate `camtrap-workflow` checkout remains a read-only methodological
  reference and is not a code dependency.
- Generated fits, numerical grids, sampler outputs and reports must remain
  under ignored output boundaries unless a compact, non-sensitive acceptance
  summary is explicitly designated as tracked.
- No local absolute path may enter a tracked manifest, report or decision
  record.

## Verification and review

The later implementation plan must provide stable, non-interactive wrappers
for:

- environment and CmdStan version checks;
- the full existing Goal 001 and Goal 002 test suite;
- the independent numerical certificate;
- the R-to-Stan fixed-input bridge;
- a collapsed-model smoke fit;
- development dispatch, validation and reporting;
- confirmation dispatch, validation and reporting; and
- one-command regeneration of the final decision report.

Before development, an independent review must examine the derivation,
integration convention, oracle independence, output contracts and
truth-isolation boundary. Before the final verdict, a separate review must
reconstruct the decision metrics from immutable confirmation artefacts and
verify every scheduled row, diagnostic state, hash and failure.

Passing static checks or numerical fixtures is not statistical validation.
Passing the confirmation screen is not empirical validation.

## Stopping rule

Goal 002R permits:

- one candidate computation;
- one deterministic numerical-configuration choice made before recovery;
- one focused implementation repair pass during development;
- at most 19 development fits;
- exactly 78 confirmation fits if development passes; and
- one focused self-review plus the two independent evidence reviews.

Stop immediately when a hard failure makes RETAIN impossible. Do not:

- weaken a threshold after viewing output;
- change priors, samplers or the ecological model to rescue the candidate;
- add or replace seeds;
- increase confirmation replication after an inconclusive result;
- introduce empirical data;
- activate a second computational candidate automatically; or
- run repeated review-and-polish loops after material defects are resolved.

If two consecutive attempts produce no material new evidence or improvement,
record the blocker and return to a PI decision rather than repeating the same
approach.

## Expected next goal

If Goal 002R returns **RETAIN**, Goal 003 may test the retained computation
under misspecified generative processes, additional sampling intensities and
competing richness estimators before any empirical Judbury analysis. Goal 003
must receive its own design, seeds, thresholds and PI approval.

If Goal 002R returns **REJECT** or **INCONCLUSIVE**, stop. A structural model
change is justified only by a new hypothesis-led design, not by tuning this
candidate or moving directly to empirical data.
