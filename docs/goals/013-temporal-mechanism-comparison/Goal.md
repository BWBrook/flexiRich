# Goal013: discriminate temporal representations before empirical repair

Barry approved the next scientific comparison on 5 October 2026. Goal012 is
preserved in commit `ba38247`; this work builds on its completed diagnosis and
the subsequent Fable discussion. The scope is an integrated methods and
application programme, with this tranche testing whether the Judbury design
can distinguish temporal mechanisms at all.

## Question and reporting horizon

Can annual variation, species-wide persistence across the array, and independent
persistence at each station be distinguished when species-by-placement
marginal detection information is known? Can omitted shared station/service
variation spuriously favour one of those models?

The immediate reporting horizon is a tested, independently checked, frozen
comparison running on deep-server. Repository instructions require a startup
check and then hand monitoring to Barry. The scientific decision follows the
completed recovery evidence; successful launch is not mechanism validation.

## Conditional scope

This is a deliberately favourable **oracle comparison**: every candidate knows
the same full-period expected positive-cell totals for each species and physical
placement. The 26 species recorded during the open Judbury record are treated
as known members. Their original weekly data determine the sampling design,
spatial information and truth calibration, not a new empirical fit. The 24
never-recorded candidates have no temporal observations and are outside this
comparison. No inference about membership, richness, local extinction,
occupancy or camera malfunction is possible here.

Full-record information enters both placement totals and truth calibration.
Therefore fitting simulated observations through week 52 does not reproduce
the information available to Goal011. Held-out data are independent stochastic
realizations conditional on this known design, not independent sites, original
field outcomes, parameter settings or biological truth. Failure under these
favourable conditions is informative; success must be followed by estimation
of nuisance rates, service effects and uncertainty before empirical use.

Original incidence and operation-derived effort are preserved. Five ambiguous
movement station-weeks are masked consistently in the screen, including event
endpoints. State transitions continue through these weeks and all gaps. The
remaining observations cover 26 species, nine nominal stations, 13 physical
placements and 153 weeks. A placement share pseudocount totalling 0.5 per
species gives target counts

`target_ig = K_i * (k_ig + 0.5/13) / (K_i + 0.5)`.

This preserves each species' total, including one-record species. A preliminary
cellwise Jeffreys proposal was rejected before simulation because it would
inflate rare-species totals. No recovery evidence was generated from it.

## Four fitted candidates

All use `Pr(Y_ijt=1) = 1-exp(-E_jt*s_ig*m_ct)`. For every candidate parameter
value, solve each positive scale `s_ig` so the sum of expected incidences across
that physical placement equals its common target. Binary saturation is handled
explicitly; dividing positive cells by days is not this probability model.

| Candidate | Temporal representation | Fitted parameters |
|---|---|---|
| Static | Multiplier one | None |
| Harmonic | `exp(b_s*sin(phase)+b_c*cos(phase))` | Two coefficients per taxon |
| Array state | One low/high chain per species, shared by all stations | Amplitude and persistence per taxon |
| Station state | Independent low/high chains per species and nominal station | Amplitude and persistence per taxon |

The classes are Aves and Mammalia. Phase follows calendar days with a
365.2425-day cycle. Each state model has stationary probabilities 0.5/0.5,
multipliers `exp(-a)` and `exp(a)`, and switching probability `(1-rho)/2`.
Amplitude is bounded to [0,4] and persistence to [0,0.98]. A zero amplitude
nests the static model and makes persistence unidentified. These are low/high
encounter states, with no structural absence state. Harmonic coefficients
are bounded to [-4,4]. No model receives richer information than another.

The array likelihood multiplies camera emissions **inside** one species-level
forward recursion. The station likelihood multiplies separate forward
likelihoods. Exact scaled/log-space recursion carries filtered states across
the forecast origin. Deterministic multistart optimization replaces MCMC in
this first bridge. All start diagnostics and boundary estimates are retained.

## Synthetic design and comparison

There are 100 independent replicates of each of four core truths plus 100
shared-service stress replicates. Seeds are frozen in
`config/goal013_run_manifest.csv`; the service realization has seed 2026100650.
This is a finite, case-study-anchored screen, not a broad identifiability proof.

Dynamic truths have the same marginal information and the same class-specific
expected adjacent-switch deficit. State truth persistence is fixed at 0.8.
Harmonic phase is anchored by the full-record class residual sine/cosine
resultant, used only for truth calibration. A common attainable deficit is
the minimum of the observed deficit and 90% of the smaller maximum attainable
deficit of the harmonic and state models over amplitudes 0 to 4. Any weakening
is recorded, not disguised as exact matching to the observed effect.

The frozen calibration matches all of the mammal switch deficit (3198.46
expected under static versus 2520 observed). For birds, static expectation
581.05 versus 417 observed is reduced to the common target 492.35: only 54.07%
of the observed deficit. The binding constraint is the symmetric state
template at fixed truth persistence 0.8, not the harmonic. Its fixed 0.5 state
prevalence limits how concentrated rare encounters can become. Conclusions
therefore concern these templates at this matched strength; a negative screen
does not rule out asymmetric or more flexible state processes.

The fifth truth multiplies hazard by a fixed station/service-interval factor
with log standard deviation 0.6, shared across species. It preserves the same
species-by-placement targets. All four candidates deliberately omit that
factor, making this a confounding stress, not a fifth recoverable core model.
Actual service dates define intervals; assignment by weekly midpoint is solely
a synthetic convention. `run_days` never overrides the existing effort.
The factor is simulated and does not represent measured camera performance.

Every model is fitted at week 52 and scored on the joint distribution of weeks
53–153. The secondary split fits weeks 1–104 and scores 105–153. The comparison
uses proper joint predictive log scores, including the state distribution
filtered by training observations. If no dynamic model exceeds static by more
than two nats, classify the panel as static-compatible. Otherwise the best
dynamic model needs a two-nat lead over each competitor; smaller gaps are
unresolved. This margin is a fixed descriptive resolution rule, not a Bayes
factor or significance threshold. Failed optimization invalidates selection
for that dataset/origin instead of removing the failed candidate.

Analytic probabilities of at least one future detection are also scored at
13, 26, 52 and 101 weeks after the primary origin, and 49 weeks after the secondary
origin. Exact Poisson-binomial count distributions separate training-detected
and training-undetected cohorts of these **known members**. These are plug-in
forecasts conditional on estimated temporal parameters: parameter uncertainty
has not been propagated. Undercoverage is evidence against immediate use.

Fixed full-effort pair diagnostics record within-station associations at lags
1, 26 and 52, same-species cross-station synchrony, and same-station cross-species
synchrony, split by taxon and stratified by physical placement(s). They compare
the actual and generated signals; they do not select models. All pairs overlap,
so descriptive odds ratios are not treated as independent hypothesis tests.

## Decision rules and next scientific step

At the primary forecast origin, an individual mechanism is provisionally
recoverable only with at least 80/100 own-truth selections (two-sided exact
95% lower bound about 0.708). Array false selections under each harmonic and
station truth must be at most 4/100 (upper bound about 0.099). Report numerical
failure against a 2% tolerance, rather than dropping failures. Count coverage
receives exact binomial intervals; an upper bound below nominal 0.90 is a
clear undercoverage failure, whereas discrete conservative coverage is reported
separately. Inspect sparse species' event scores and boundary fits rather than
generalizing aggregate recovery to them.

Array versus station confusion, false array selection under seasonal/local
truths, or array truth requiring substantially more cross-station synchrony
than observed is evidence against advancing the array state. A gain appearing
only at week 104 does not rescue the original 52-week information problem.
Array selection under the omitted-service stress must also be at most 4/100;
exceeding that threshold blocks advancement of the array candidate despite
core recovery. Selection of other misspecified dynamics in this stress is
descriptive and not an undefined additional pass/fail criterion.

These gates are necessary screening conditions, not empirical approval. If
the representations are distinguishable, the next comparison estimates the
placement/service nuisance structure and adds combined seasonal/drift truths.
If they are not, keep the mechanisms unresolved and pursue the simpler
service/seasonal observation-model comparison without claiming biological
identification. No bird trend is interpreted until labeling provenance is
clarified. New Judbury weeks, if they exist, and Huon Ridge require separate
data and candidate-pool decisions. Huon Ridge remains unopened.

## Frozen outputs

The run saves simulated panels, all fitted parameters and start diagnostics,
joint future scores, per-species event probabilities, count scores, pair
diagnostics, selections, exact recovery/coverage intervals, input/output hashes,
source commit, environment and per-job status. Errors remain in place. Repair
requires a new committed run. Results from this tranche do not change any
Goal011 forecast or Goal012 diagnostic.
