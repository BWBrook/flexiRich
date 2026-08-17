# Goal 004 proposal — pool-stable membership and short-window identifiability

Status: active — Task 4 implementation verified locally; remote batch awaits launch approval
Proposed: 2026-08-14

## Decision question

Can a finite named-pool model use external ecological evidence to stabilise
four-week richness inference across nested candidate pools, while clearly
separating what the camera observations learn from what the prior supplies?

Goal004 is motivated by the Goal003 `SCREEN_STOP`. It is not an opportunity to
retune the failed model against the same 300 datasets. The current Goal003
candidate remains stopped.

## Scientific premise

Goal003 placed one exchangeable membership probability on every candidate.
That probability describes a fraction, so adding 56 undetected candidates also
changes the prior scale of total richness. With sparse detections, membership
and low encounter rate are weakly identified and the pool boundary can dominate
the estimate.

The external candidate worksheet was completed before empirical model fitting
and already distinguishes:

- JCR gamma-pool status (`include`, `borderline`, `exclude`);
- camera encounter class (`routine`, `occasional`, `rare`, `uncertain`, or
  `negligible`);
- ground use for birds; and
- primary versus broader camera pools.

These judgements are legitimate external evidence. If used, their influence
must be visible and stress-tested rather than disguised as information learned
from a four-week camera sample.

## Minimal candidate direction

The leading formulation has a small number of externally defined candidate
strata, initially `core` and `fringe`. For stratum (h), with (C_h)
candidates, parameterise membership through an expected count (R_h),

\[
g_i \sim \operatorname{Bernoulli}(\psi_h),
\qquad
\psi_h = R_h/C_h,
\qquad 0 < R_h < C_h.
\]

The prior is elicited on (R_h), the expected number of members in the
stratum, rather than on a common pool fraction. Adding a separate fringe
stratum therefore does not rescale the core richness prior. The exact prior
is now frozen in `config/goal004_task2_priors.csv`: Task 1 found that the core
could remain data-responsive but the fringe was prior-dominated, and Task 2
fixed the core membership and encounter-class profiles without using Judbury
outcomes. Task 3 therefore begins with the core only; a later nested-pool
diagnostic must give the fringe its own independent count parameter.

Encounter rates retain the effort-aware hazard

\[
P(y_{ijk}=1\mid g_i=1)
=1-\exp\{-E_{jk}\exp(\alpha_i+b_j)\},
\]

but encounter-class information may provide a small number of prespecified
offsets or strata for \(\alpha_i\). No flexible mixture, anonymous species
tail, abundance interpretation, spatial layer, or dynamic occupancy process is
introduced in the first candidate.

This direction remains provisional. If an analytical feasibility screen shows
that count-scale membership merely replaces one influential prior with
another, implementation stops before Stan.

## Required comparison with the prior alone

A model cannot claim four-week success merely because expert knowledge was
informative. Every synthetic and empirical evaluation must include the same
candidate-stratum prior without camera detections as a probabilistic baseline.
The posterior must improve proper scores relative to that prior-only forecast,
and the report must quantify prior-to-posterior movement in expected richness
and candidate membership probabilities.

## Proposed sequence

### Task 1 — analytical identifiability screen

Before implementing another full model:

1. derive or numerically map the likelihood over expected membership count and
   mean encounter rate for representative four- and 26-week effort patterns;
2. quantify the ridge between unseen membership and low encounter rate;
3. compare the exchangeable fraction prior with candidate-stratified
   count-scale alternatives under nested 50- and 106-candidate pools; and
4. determine whether any defensible external prior leaves material information
   for four-week detections to contribute.

Stop if the proposed formulation cannot be pool-stable without a prior narrow
enough to predetermine the answer.

### Task 2 — freeze external-evidence strata and priors

Use only fields already frozen in `config/goal003_candidate_pool.csv` or a
separately documented elicitation completed without Judbury outcomes. Freeze:

- the mapping from candidate evidence to membership and encounter strata;
- priors on expected stratum richness and encounter-rate offsets;
- prior-only predictions for primary and broader pools; and
- sensitivity profiles for plausible expert misclassification.

### Task 3 — implement one minimal candidate

Implement the smallest analytically marginalised model that passes Task 1.
Retain the Goal003 effort likelihood, exact richness/discovery PMFs, sampler
contract, transparent comparators, and truth-isolation checks. Do not revive
the failed Goal002R numerical machinery. For a fixed candidate count, the
expected-count membership parameter is algebraically equivalent to the
Goal003 membership fraction; the fixed external encounter classes, not that
reparameterisation, are the only proposed source of improved short-window
identifiability.

### Task 4 — development simulation

Use the completed Goal003 screen only as development evidence. Add class-aware
generators in which external strata are informative, weakly informative, and
partly wrong. Evaluate four- and 26-week inference, nested-pool stability,
prior-to-posterior information gain, and future discovery prediction.
Nested-pool stability must be tested by adding the fringe as an independent
membership stratum and checking whether the fitted core posterior changes,
including through any camera effects shared by the strata.

The bounded design is now specified in
[`Task4DevelopmentSimulationDesign.md`](Task4DevelopmentSimulationDesign.md).
It freezes 180 class-aware synthetic datasets, 750 scheduled Stan fits,
matching no-data prior forecasts, an independent-fringe diagnostic, and
decision gates before computation. The implementation, nested-model bridge,
prior-concordance check, and one-fit end-to-end smoke are complete and recorded
in [`Task4ImplementationOutcome.md`](Task4ImplementationOutcome.md). No Task 4
development batch has yet been launched, and no scientific gate outcome
exists.

### Task 5 — newly frozen held-out screen

Freeze new seeds and result gates before running. The held-out screen must
include low, intermediate, and high richness; correct and misspecified strata;
seasonal availability; nested candidate pools; and irregular Judbury-derived
effort. Passing requires both calibrated richness and improvement over the
candidate's own prior-only forecast. The old Goal003 datasets cannot serve as
confirmatory evidence.

### Task 6 — empirical and external validation

Only a candidate that clears the new synthetic gate may access Judbury
detections. Huon Ridge remains private external validation after Judbury, with
no publishable point locations.

## Stop conditions

Stop the successor before empirical fitting if:

- four-week estimates remain materially dependent on adding fringe candidates;
- apparent calibration is supplied almost entirely by the external prior;
- low- and high-richness cases still collapse toward a common middle;
- modest prior or evidence-class perturbations produce consequential shifts;
- the model does not improve proper scores over its prior-only baseline; or
- the added structure does not outperform the simpler Goal003 and occupancy
  benchmarks sufficiently to justify it.

## Scope retained from Goal003

- finite named-pool grid-level camera-encounter richness;
- species by camera by seven-day incidence;
- exact active camera-days and zero-effort weeks treated as unsampled;
- four- and 26-week inference with a four-week discovery horizon;
- Judbury as the eventual public empirical validation dataset; and
- Huon Ridge only as private external validation.

Site-level borrowing, abundance or density, anonymous unseen species, dynamic
colonisation/extinction, and package/API development remain deferred.
