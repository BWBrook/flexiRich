# Goal 002R — Test the collapsed known-pool richness computation

Status: active — lean prototype implemented; paired validation pending
Updated: 2026-08-05

## Objective

Determine whether the collapsed Goal 002R computation preserves the posterior
distribution of the original FlexiRich-G model while improving its sampling
geometry and computational reliability.

This is a bounded computational-repair goal. It is not an empirical analysis,
a search for a new ecological model, or a claim that camera-trap richness is
identified without assumptions.

## Scientific context

Goal 002 implemented the first finite-known-pool FlexiRich-G model and completed
96 frozen synthetic fits. It closed as an informative method failure rather
than an implementation failure:

- richness distributions were often informative and strongly outperformed a
  lower-bound-conditioned prior under ranked probability score;
- posterior point estimates did not strictly improve the frozen median
  absolute-error criterion relative to observed richness; and
- the membership-sensitivity analysis exposed poor sampling geometry among
  never-detected candidates whose absence could not be distinguished cleanly
  from extremely low encounter rates.

Goal 002 remains closed. Its priors, thresholds, results and conclusions are
historical evidence and are not rescored here.

## Estimand and data contract

The estimand is whole-grid detectable-use richness during a defined sampling
period for a finite, named regional candidate pool.

Inputs are:

- one unique identifier for every candidate species;
- complete species × camera × seven-day detection histories;
- binary detection at positive effort and missing observation at zero effort;
- exact operational effort in active camera-days from 0 to 7; and
- at least two cameras and at least one detected candidate in the current
  prototype.

The estimator does not infer anonymous species outside the candidate pool.
The current goal concerns grid-level richness only. Site-level partial pooling
is deferred.

## Original and collapsed computations

Let \(D\) be the number of detected candidates, \(U\) the number never detected,
and \(C=D+U\) the candidate-pool size. Every detected candidate belongs to the
detectable-use pool by definition.

The original Goal 002 model samples a latent encounter effect for every
candidate. For a never-detected candidate, the posterior must distinguish
non-membership from membership combined with an extremely low encounter rate.
Those explanations form the weakly identified membership–detectability ridge
that motivated this repair.

Goal 002R retains explicit encounter effects for detected candidates but
integrates over the encounter-effect distribution for exchangeable all-zero
candidates. Conditional on a posterior draw of the shared parameters, an
all-zero candidate has membership probability

\[
q_{\mathrm{unseen}}
=P(g_i=1\mid \mathbf y_i=\mathbf 0,\text{shared parameters}).
\]

Conditional richness is then

\[
S_{\mathrm{grid}}
=D+\operatorname{Binomial}(U,q_{\mathrm{unseen}}).
\]

The posterior richness PMF is the average of these per-draw binomial PMFs. It
must never be constructed by substituting the posterior mean of
\(q_{\mathrm{unseen}}\).

## Protected invariants

The paired comparison may not change:

- the known candidate pool or grid-level estimand;
- the seven-day incidence and exact-effort observation contract;
- the Goal 002 membership, encounter-rate and camera-effect model;
- the prior profile used within a paired case;
- the data supplied to the two computations;
- the strict Goal 002 sampler-health thresholds used for comparison; or
- the historical Goal 002 result.

The collapsed computation must additionally preserve:

- integer richness support from (D) to (C);
- normalised, non-negative richness PMFs;
- a common all-zero likelihood only when candidate opportunity histories and
  predictors are exchangeable; and
- checked numerical integration of the unseen encounter effect.

## Current implementation and evidence

The lean Goal 002R prototype now includes:

- a collapsed data adapter and exchangeability checks;
- a compact Stan model for detected candidates and the integrated unseen tail;
- Gauss–Hermite quadrature with an independent adaptive-integration oracle;
- per-draw unseen-membership and richness-PMF reconstruction;
- source-hashed model compilation and small fit outputs;
- sampler-health checks for divergences, treedepth, E-BFMI, R-hat and ESS; and
- focused tests, a smoke fit, a numerical certificate and preliminary recovery
  scripts.

Quadrature order 128 is the conservative default from the current numerical
certificate. New posterior regimes still require explicit checking against the
independent reference integral.

A one-replicate 16-cell reconnaissance produced 13 healthy fits. Their 90%
richness intervals all contained truth and their mean absolute error was about
1.11 species. Two cells had no detected candidate, outside the current data
contract, and one short fit failed the R-hat gate. This is useful diagnostic
evidence, not estimator validation or calibration evidence.

## Decision question

The next experiment asks three questions:

1. **Posterior fidelity:** Do the original and collapsed computations produce
   equivalent richness PMFs and shared-parameter posteriors on identical data?
2. **Sampling geometry:** Does collapsing the all-zero encounter effects reduce
   non-clean fits, especially in the historical Goal 002 stress case?
3. **Cost:** Does the collapsed computation achieve this without an
   unacceptable runtime penalty?

Statistical recovery against truth is secondary in this goal because a
mathematically equivalent re-expression should not improve the correctly
sampled posterior of the same ecological model. Broader recovery and
calibration belong to the next goal if this repair is retained.

## Outcomes

### RETAIN

Retain the collapsed computation when:

- all numerical checks pass;
- all clean paired fits meet the posterior-fidelity criteria in `Plan.md`;
- the collapsed computation is terminal-clean in every supported comparison
  case, including the historical stress case;
- its primary-clean count is at least that of the original computation; and
- its median primary-fit runtime is no more than twice the original runtime.

This outcome authorises broader synthetic validation. It does not authorise an
empirical richness claim.

### REVISE

Return for a new scientific decision when posterior fidelity is acceptable but
the geometry or runtime advantage is inconclusive. No automatic sampler,
prior, threshold or model tuning follows from this outcome.

### REJECT

Reject this repair when it produces a material posterior mismatch, fails the
numerical certificate, violates richness support, or introduces worse sampling
geometry that cannot be attributed to Monte Carlo error.

## Scope

In scope:

- deterministic mathematical and numerical checks;
- paired synthetic fits of the original and collapsed computations;
- one historical non-clean Goal 002 case as a computational stress test;
- posterior fidelity, sampler health and runtime comparisons; and
- a concise evidence-backed RETAIN, REVISE or REJECT decision.

Out of scope:

- Judbury and Huon Ridge observations;
- Atlas of Living Australia candidate-pool construction;
- anonymous unseen-species augmentation;
- site-level richness or spatial partial pooling;
- false positives, seasonality, turnover or spatial dependence;
- alternative encounter-distribution families;
- broad replicated calibration or estimator benchmarking; and
- engineering support for datasets with zero detected candidates.

## Stopping rule and next goal

Run the bounded paired experiment once, perform one focused review and repair
only a demonstrated implementation defect. Stop when the evidence supports one
of the three outcomes above; do not expand replication or tune the model in
response to the result.

If retained, the next goal will evaluate recovery, calibration, prior
sensitivity, misspecification and traditional richness comparators across
one-month, six-month and four-year sampling windows. Judbury analysis follows
only after that synthetic validation is credible.

## Current documentation authority

This file defines the active scientific goal. `Plan.md` defines the bounded
execution sequence. Superseded designs remain available in Git history and are
not duplicated in the active checkout.
