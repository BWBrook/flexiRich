# Independent results review of Goal013

9 October 2026. This is a bounded scientific audit of the completed frozen
Goal013 screen at commit `df82740`. It uses only the frozen design, calibration,
code and copied `outputs/goal013/recovery-v1` artifacts. It does not read raw
observations or Huon Ridge, refit a model, alter a frozen result, or select an
empirical mechanism.

## Decision

**REPAIR before scientific mechanism advancement.** The screen passes its
predeclared numerical and core-recovery gates and establishes that the four
deliberately separated templates are distinguishable under the favourable
oracle design. It does not justify advancing either array-wide or
station-specific persistence as a biological account of Judbury. The empirical
fingerprints are inconsistent with important parts of the recovered truths,
the service stress exposes severe and time-window-dependent aliasing, the bird
state amplitude is weakly identified, and sparse-species forecasts gain almost
nothing from the state mechanisms.

The defensible advance is to a nuisance-first comparison, challenged by Fable
before implementation. That comparison should retain seasonality and both
state scales as residual candidates rather than causal winners. The current
result summaries also need a post-hoc boundary reconstruction from the saved
parameter vectors because the stored boundary field omits upper amplitude
bounds. No production rerun is needed for that repair.

Sol Max audit is not justified at this stage. This focused independent review
is sufficient to determine the next experiment. A higher-tier audit would be
justified later if a manuscript uses these results to support an empirical or
causal mechanism, or if the next nuisance-estimation analysis becomes central
to a richness or discovery claim.

## Scientific target and scope of inference

The estimand is a repeated-simulation operating characteristic: conditional on
the fixed Judbury design, 26 known members, fixed truth parameters and exact
full-period species-by-placement expected totals, how often does the fixed
two-nat rule select the generating temporal representation after 52 training
weeks? Secondary estimands are plug-in future-event and known-member count
forecast calibration through weeks 53--153, plus descriptive recovery at the
104-week origin.

This is not an estimate of the probability that a mechanism generated the
Judbury record. It is also not a richness, membership, occupancy, camera-failure
or real-world forecast analysis. The 24 never-recorded candidates are absent.
The stochastic repetitions vary simulated binary observations, not sites,
species pools, parameter settings, harmonic phases, HMM persistence, or
service-effect realizations.

The data-generating and observation pipeline is as follows.

1. The open compact record fixes 26 species, nine nominal stations, 13 physical
   placements, 153 weeks, operation-derived effort and five masked ambiguous
   movement station-weeks. Weekly observations are binary positive cells.
2. All candidates receive the same 338 positive species-by-placement targets.
   These preserve all 3,836 positive cells after a total species-level
   pseudocount of 0.5. The targets and truth calibration use the full 153-week
   record.
3. Static, harmonic, array-HMM and station-HMM truths are simulated 100 times
   each. Dynamic parameters are shared within taxon. The symmetric HMM fixes
   state prevalence at 0.5 and truth persistence at 0.8.
4. A fifth stress uses one frozen realization of lognormal station/service
   factors with log standard deviation 0.6, shared across species. One hundred
   binary panels are drawn conditional on that same nuisance realization.
5. Every candidate is fitted by deterministic bounded multistart optimization
   at weeks 52 and 104. Scales are re-solved at every candidate parameter value
   to retain the known full-period placement targets. Future weekly log scores,
   species event probabilities and Poisson-binomial known-member counts are
   plug-in predictions; parameter uncertainty is not propagated.

The full-period targets do not leak a simulated future realization into its own
fit. They do, however, supply oracle information that would be unavailable in a
genuine week-52 empirical forecast. Goal013 is therefore an information ceiling
conditional on future-informed nuisance totals, rather than validation of the
Goal011 information set.

## Recovery and numerical evidence

At the primary origin, the frozen selections are:

| Truth | Main selection outcome | Other outcomes |
|---|---:|---|
| Static | 95/100 static-compatible | 2 harmonic, 1 station, 1 unresolved, 1 numerical failure |
| Harmonic | 99/100 harmonic | 1 numerical failure |
| Array HMM | 100/100 array | none |
| Station HMM | 100/100 station | none |
| Service stress | 86/100 station | 10 static-compatible, 4 unresolved, 0 array |

Thus all three dynamic own-truth recovery rates exceed 80/100; false array
selection is 0/100 under harmonic, station and primary service truths; and
3,998/4,000 fits converged. The two numerical flags are 0.05% of fits, below the
2% tolerance. The selection result is not marginal: own-model future-score
leads over the best competitor at week 52 ranged from 190.5 to 274.8 nats for
harmonic, 341.0 to 534.3 for array, and 182.0 to 313.0 for station.

Both numerical flags must remain in the primary frozen result. Neither prevents
the gate-level conclusion, but the saved evidence does not establish that a
converged alternative would give the same predictive vector:

- For `harmonic-024`, the selected station start returned code 52 at objective
  1633.374435305. Four alternative starts converged; the best was worse by only
  `1.00e-8`. The saved flagged fit's harmonic future score exceeds its station
  score by about 500 nats.
- For `static-084`, the selected zero-amplitude array start returned code 52 at
  an objective tied to all four converged alternatives at displayed precision.
  Zero amplitude makes that saved array fit identical to static, but the full
  parameter vectors for the converged alternatives were not retained.

The equal or near-equal training objectives and the saved zero-amplitude
identity make optimizer-status or shallow-minimum explanations plausible.
Alternative-start predictive equivalence remains unverified. These checks do
not authorize rewriting the frozen failure classifications.

## Calibration and discreteness

All 30,000 saved count-score rows have nonempty cohorts. Training-undetected
cohorts contain 2--10 species at week 52 and 1--8 at week 104. Reconstructing
the Poisson-binomial probability mass from all 260,000 saved species-event rows
shows that the nominal central intervals contain 0.901--1.000 probability mass
(median 0.966). There are no degenerate `[0,0]` intervals. High coverage in the
undetected cohort is partly expected from small, discrete counts: 55--75% of
13-week undetected-cohort outcomes contain zero events across the five truths.

Ten of 300 aggregate coverage cells meet the predeclared flag `upper exact 95%
bound < 0.90`. All concern misspecified candidates at the week-52 origin and
13- or 26-week horizons: static, station or array under harmonic truth, or
static, harmonic or station under array truth. Their realised coverage is
0.31--0.79 even though their mean predictive interval mass is 0.943--0.973.
These are substantive misspecification failures, not artifacts of intervals
having less than 90% probability mass.

None of the 60 own-truth candidate coverage cells triggers that criterion.
Own-truth coverage ranges from 0.87 to 1.00; the lowest cell is harmonic-truth,
harmonic-model, all-known 52-week coverage at 87/100, whose exact upper 95%
bound is 0.929. The 300 cells are highly dependent across horizons, cohorts,
models and datasets. The ten flags should be reported as predeclared diagnostic
cells, not as independent hypothesis tests or familywise evidence.

## Template recovery is not empirical mechanism support

The fixed pair diagnostics reveal a mismatch between easy synthetic recovery
and the actual dependence structure. The Mantel-Haenszel odds ratios below
are descriptive because pairs overlap, but simulation envelopes make the scale
of mismatch clear.

- Under array truth, mammal same-species cross-station odds ratios have median
  3.615 and range 2.560--4.557. The observed value is 1.323, below every one of
  the 100 array replicates. Station truth has median 1.006 and range
  0.913--1.129. The predeclared warning that array truth may require materially
  more synchrony than observed is therefore realized for mammals.
- Birds do not show the same comparison. The observed cross-station value is
  4.900, above the maximum array-truth value 4.786. Observed bird lag-52
  association, 3.154, lies within the harmonic 5--95% envelope 1.891--3.598,
  while observed lag-1 association, 6.084, exceeds the 95% envelope of every
  truth (the largest is 3.851 for array truth).
- This taxon contrast is expected to matter because the synthetic bird signal
  was deliberately weakened. The imposed bird switch deficit is 88.69 of the
  observed 164.05, or 54.07%, whereas mammals retain 100%. Strong recovery of
  the weakened bird templates cannot adjudicate the stronger and differently
  scaled observed bird dependence.

No one template reproduces these empirical fingerprints. Array recovery at
the chosen amplitude demonstrates discriminability of an exaggerated mammal
cross-station signal; it does not establish array-wide persistence in the
record. The bird results also warn against pooling biological interpretation
across taxa or treating lag-1 and annual association as one state process.

## Service confounding and the next comparison

The service stress strongly supports Fable's proposed ordering of the next
comparison: estimate or represent nuisance variation before interpreting
residual persistence. At week 52, an omitted shared station/service factor is
classified as station HMM in 86/100 panels even though that candidate contains
no shared service process. The station model can absorb persistent local rate
variation in each species-station series; recovery of its label therefore does
not identify a biological local state.

The attribution is also unstable across forecast origins. At week 104 the same
stress yields 36 static-compatible, 26 array, 26 station and 12 unresolved
selections. The primary service gate of 0/100 false array selections passes as
written, but it is not robust evidence that array inference is protected from
service confounding. It is conditional on one early training window and one
frozen service-effect realization.

Conversely, this stress does not show that actual service variation explains
Judbury. Its observed-data fingerprints are poor: for example, service-stress
bird lag-1 odds ratios have a 5--95% envelope of 0.822--1.530 versus observed
6.084; mammal lag-1 has 1.140--1.392 versus observed 2.746. The result diagnoses
aliasing under a plausible nuisance class. It does not validate the specific
factor realization, camera malfunction, service dates as causal breakpoints,
or log standard deviation 0.6.

The discriminating next experiment should compare a training-estimated
placement/service nuisance model and seasonality against residual array and
station states under equal information. It should vary service realizations,
seasonal phases and strengths; include service-only, seasonal-only, state-only
and combined truths; estimate all nuisance quantities from training data; and
score future observations without supplying full-period marginal totals.
Known service boundaries can later support held-out-interval or held-out-station
checks, with shuffled boundaries as a negative control. Cross-species
synchrony, cross-station synchrony and taxon-specific lag structure should be
validation targets, not post-hoc model labels. Parameter and model-selection
uncertainty must be propagated before any empirical discovery or richness use.

Evidence that would favour service/observation variation is repeatable
cross-species change aligned with known service intervals and improved
out-of-sample calibration after accounting for it. Evidence favouring a
biological station state is residual within-species persistence that transfers
across service intervals without corresponding cross-species shifts. Evidence
favouring array-wide state is residual cross-station synchrony within species
at a magnitude compatible with the observed taxon-specific fingerprints.

## Sparse species and parameter identifiability

The panel has a natural sparsity gap: ten species have only 1--3 positive cells,
two have 10--18, and 14 have 87 or more. Only 33--38% of sparse species are
detected in the first 52 simulated weeks, depending on truth. Their apparently
reasonable event calibration is heavily assisted by the known full-period
placement totals.

For the ten sparse species, the mean origin-52 event log-score gain over static,
pooled across four horizons, is only 0.00057 nats per event for the true array
model and 0.00010 for the true station model; the true harmonic gain is 0.0182.
The corresponding gains for common species are 0.0375, 0.00186 and 0.0942.
Near-perfect panel recovery therefore comes mainly from abundant species and
shared taxon parameters. It does not show that a rare species' temporal process
or discovery probability is identified.

Parameter recovery exposes a second distinction between label recovery and
identifiability. For bird amplitude at week 52, the array estimator has mean
2.354 versus truth 1.982 and RMSE 0.931; the station estimator has mean 2.406
and RMSE 1.207. Bird amplitude equals its upper bound of four in 18/100
own-array fits and 30/100 own-station fits (7/100 and 24/100 at week 104).
Mammal state parameters are much better recovered.

The saved `boundary` field does not record these upper-bound amplitudes. In
`R/goal013_mechanisms.R`, state flags cover amplitude at zero and persistence at
0 or 0.98, but not amplitude at four; harmonic coefficient bounds are also not
flagged. All parameter vectors are retained, so the result report can reconstruct
complete boundary diagnostics without refitting. Any claim that boundary fits
were rare based only on the saved field would be incorrect.

## Recommendation and residual limits

Preserve Goal013 as a successful conditional template-discrimination screen
and a negative result for direct biological interpretation. Repair the result
summary to include complete parameter boundaries, the full origin-104 service
confusion, actual interval probability mass, sparse-species score contrasts,
and taxon-specific empirical fingerprint mismatches. Then ask Fable to attack
the nuisance-first design before implementation.

Do not change the frozen selections, relax gates, fit the current templates to
Judbury as causal competitors, revise Goal011, or infer real camera performance.
Even after the proposed repair, conclusions remain conditional on a finite
case-study design, fixed templates, one harmonic phase, one service realization,
full-period oracle margins and plug-in uncertainty. Those limits require a new
prespecified comparison, rather than reinterpretation of the present 500
panels.

Primary evidence paths:

- `outputs/goal013/recovery-v1/recovery-summary.csv`
- `outputs/goal013/recovery-v1/coverage-summary.csv`
- `outputs/goal013/recovery-v1/event-counts.csv`
- `outputs/goal013/recovery-v1/fingerprints.csv`
- `outputs/goal013/recovery-v1/observed-fingerprints.csv`
- per-job `fit-starts.csv`, `scores.csv` and
  `species-event-probabilities.csv`
- `config/goal013_design.rds` and `config/goal013_calibration.csv`
- `R/goal013_mechanisms.R`, `R/goal013_scoring.R`,
  `R/goal013_diagnostics.R` and `scripts/run_goal013_mechanisms.R`
