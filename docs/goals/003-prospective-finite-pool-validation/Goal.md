# Goal 003 — Prospective finite-pool richness validation

Status: active — Task 1 structural contract implemented; candidate review pending
Defined: 2026-08-10

## Decision question

Determine whether a simple, regularised, finite-pool multispecies detection
model improves short-window inference about grid-level camera-encounter
richness and predicts future species discoveries better than transparent
classical and hierarchical baselines.

The Goal003 candidate is retained only if its additional model complexity
earns its place through calibrated uncertainty or out-of-sample predictive
skill. A result showing that observed richness or a simpler comparator is just
as useful is a valid and publishable scientific outcome.

## Product promise

Goal003 will produce one reproducible benchmark, not a general R package:

1. a canonical finite candidate-pool and detection/effort data contract;
2. transparent richness and discovery baselines;
3. one minimal FlexiRich candidate model;
4. synthetic calibration under known truth;
5. temporal validation against the long Judbury record; and
6. a decision to retain or stop the model before any Huon Ridge application.

It will not revive Goal002R, build a numerical-integration framework, or begin
site-level FlexiRich development.

## Estimands and validation targets

### Primary estimand

For a finite, named regional candidate pool, the primary estimand is the
number of candidates with a non-zero camera-encounter-generating process on
the Judbury grid during a prespecified reference period. We call this
**grid-level camera-encounter richness**.

This is an observation-process estimand. It is not abundance, density, local
occupancy at every camera, the number of animals, or all species biologically
present in the surrounding landscape.

### Synthetic truth

In simulations, true membership and true grid richness are known exactly.
Synthetic experiments therefore assess estimation error, interval calibration,
full-distribution scoring, prior sensitivity, and failure under controlled
misspecification.

### Empirical validation target

For Judbury, the long-window detected species pool is an operational reference,
not ecological truth. A species absent from the complete record may still have
used the area, and a species detected once may be transient.

The strongest empirical target is prospective and observable: conditional on
data available through a cutoff, predict the number and identities of species
first detected during a fixed future interval. No method may use post-cutoff
detections, the long-window pool, or statistics derived from them during
training.

The minimal model assumes that pool membership and the encounter process are
stable across each combined training-and-forecast interval. Temporal blocks
must respect season and year. Failure under seasonal turnover counts against
the model; it is not removed by redefining the target after scoring.

## Candidate-pool contract

The regional candidate pool is constructed before model fitting from evidence
external to the focal Judbury detection history. The primary pool will use:

- Atlas of Living Australia records within a prespecified 10 km radius;
- authoritative Tasmanian range information where needed;
- mammals plausibly detectable by ground-based cameras; and
- birds independently flagged as commonly or occasionally ground-using.

Records originating from the focal Judbury monitoring programme must not be
used to justify candidate inclusion. Source dates, spatial rules, taxonomic
decisions, exclusions, and bird ground-use classifications are recorded. The
candidate list is frozen before temporal model scoring.

Reptiles such as blue-tongue lizards and snakes may form a declared secondary
stratum. They are not pooled into the primary mammal-and-ground-bird retention
decision because their seasonal availability and camera encounter process are
materially different.

A single broader-pool sensitivity may add borderline but defensible candidates.
There is no anonymous species augmentation and no inference beyond the named
pool.

## Observation contract

The canonical observation is species-by-camera incidence in seven-day
occasions, accompanied by exact active camera-days from the existing daily
operational table.

- A valid detection is binary within a species-camera-occasion.
- Zero-effort camera-occasions are unsampled, not non-detections.
- Raw classifications are converted to independent events by the established
  `camtrap-workflow` protocol, used read-only and version-pinned when imported.
- Event construction is completed before richness analysis and is identical
  for every method.
- Camera relocations and deployment phases remain explicit in the data. Their
  mapping to nominal station or camera-position units is frozen before model
  fitting and never selected by predictive performance.
- Candidate species with no detections remain explicit all-zero histories.

The primary short windows are four occasions (approximately one month) and 26
occasions (approximately six months). Longer windows, including 52 and 208
occasions where supported, describe the sampling-intensity curve and provide
validation context rather than replacing the short-window decision.

## Transparent comparators

Every method receives the same candidate identities, cutoff date, detections,
and operational effort available under its data contract. Goal003 will report:

1. observed richness;
2. incidence-based Chao2 and iChao2, using positive-effort camera-weeks as the
   sampling units;
3. incidence accumulation and coverage-based rarefaction/extrapolation;
4. a lower-bound-conditioned finite-pool prior that uses only observed
   richness and the candidate-pool limit; and
5. a conventional multispecies occupancy model with repeated detection and an
   effort-aware observation component.

Chao-type estimates are interpreted as lower-bound extrapolators, not truth.
Primary finite-pool summaries respect the known upper bound; unconstrained raw
Chao estimates are retained diagnostically when they exceed it. Any comparator
unable to return a full predictive distribution is scored only on quantities
it genuinely estimates, rather than being assigned artificial uncertainty.
Because Chao2 and iChao2 cannot use active-days directly, their primary input
uses all positive-effort camera-weeks and an equal-effort sensitivity uses only
complete seven-day units where the remaining sample is adequate.

## Minimal FlexiRich candidate

Let candidate species be indexed by \(i\), cameras by \(j\), and occasions by
\(k\). The model begins with one grid-membership state per candidate,

\[
g_i\sim\operatorname{Bernoulli}(\omega),
\]

and an effort-aware encounter model for members,

\[
P(y_{ijk}=1\mid g_i=1)
=1-\exp\{-E_{jk}\exp(\alpha_i+b_j)\}.
\]

Species effects \(\alpha_i\) and camera effects \(b_j\) are partially pooled
under regularising priors chosen by prior-predictive calibration before frozen
simulation or empirical scoring. The model uses one unimodal species-effect
distribution. Discrete membership is analytically marginalised in Stan, and
the returned richness distribution is reconstructed over the exact support
from observed richness to candidate-pool size.

The candidate deliberately excludes:

- flexible abundance mixtures or nonparametric tails;
- individual-abundance interpretation of camera events;
- custom quadrature or a collapsed all-zero likelihood;
- candidate-specific traits selected after viewing Judbury outcomes;
- seasonal, spatial, or dynamic membership layers; and
- site-level richness as an output.

The membership-versus-low-encounter ambiguity remains a scientific limitation,
not a coding defect. Regularisation must be visible through prior-predictive and
sensitivity results; the model must not manufacture apparent identifiability by
hiding a strong prior.

## Execution sequence and gates

### Task 1 — Build the evaluation contract

Construct and freeze the external candidate pool, taxonomic strata, canonical
seven-day incidence/effort schema, deployment mapping, temporal cutoffs, future
prediction horizons, and non-overlapping or block-resampled scoring units.

This task may inspect the topology and completeness of Judbury records but may
not fit a richness model or compare predictive performance. The number of
available independent temporal blocks determines the uncertainty calculation
for empirical score differences; that calculation is frozen here, before model
results are seen.

### Task 2 — Establish baselines

Implement and test the comparators before the FlexiRich candidate. Produce
sampling-intensity curves and prospective predictions from each eligible
baseline. Freeze their settings; do not weaken a comparator to make FlexiRich
look favourable.

### Task 3 — Implement one candidate model

Reuse the verified Goal001/Goal002 effort, likelihood, support, and posterior-
summary foundations where they remain applicable. Write only the minimal new
model and adapter surface. One non-centred primary parameterisation and one
predeclared rescue sampler configuration are allowed. Persistent non-clean
fits close the candidate; they do not activate a new computational research
programme.

### Task 4 — Synthetic calibration and misspecification

Freeze a simulation manifest before fitting. It must include:

- matched constant-pool data with low, intermediate, and high richness;
- four- and 26-occasion primary windows;
- realistic irregular effort sampled independently of detection outcomes;
- a lower-tail or guild-heterogeneity misspecification; and
- a temporal-availability or seasonal misspecification.

The first bounded run may use 30 replicates per primary cell as a screening
stage. Only methods that clear screening progress to a final calibration sized
before inspecting final results. No replicate is replaced or silently omitted.

The candidate clears the synthetic gate only if:

1. all likelihood, support, truth-isolation, and scoring oracles pass;
2. at least 95% of frozen primary fits are terminal-clean after the one allowed
   rescue, with at least 90% clean in every primary cell;
3. under matched simulation, pooled 90% richness-interval coverage is between
   0.85 and 0.95 for each primary duration and is at least 0.80 in every
   richness cell;
4. under matched simulation, its median posterior-mean absolute error is no
   greater than that of observed richness, and its median richness ranked
   probability score is lower than the lower-bound-conditioned prior and no
   more than 5% worse than the best non-FlexiRich probabilistic comparator;
5. no misspecified primary cell has 90% interval coverage below 0.75 or median
   absolute error more than 10% worse than observed richness;
6. fewer than 1% of retained fits overestimate truth by at least
   \(\max(5,0.25C)\) species, where \(C\) is candidate-pool size; and
7. each prespecified prior or broader-pool sensitivity has median absolute
   posterior-mean shift no greater than one species and no shift greater than
   three species, using only terminal-clean pairs; and
8. median cost to a terminal-clean fit is no more than three times that of the
   conventional occupancy comparator and no more than five minutes on the
   reference workstation, with a 95th percentile below 15 minutes.

These are screening boundaries, not proof of universal calibration. Failure of
any item stops empirical FlexiRich fitting unless a demonstrated implementation
defect, rather than model behaviour, caused it.

### Task 5 — Judbury temporal validation

Fit only methods that cleared their preceding gates. Use rolling-origin or
blocked temporal validation with all cutoffs and horizons fixed in Task 1.
Primary predictive outcomes are:

- the distribution of the number of newly detected species;
- future-first-detection probability for candidates still unseen at the
  training cutoff; and
- the implied long-window richness distribution, interpreted against the
  detected reference pool rather than assumed truth.

Primary scores are ranked probability score for new-species count and Brier
score for candidate identities. Calibration, interval width, point error,
logarithmic score where finite, runtime, and failure rate are secondary.
Uncertainty in method contrasts must respect temporal blocks.

FlexiRich clears the Judbury gate only if it:

1. reduces the equally weighted mean new-species-count ranked probability
   score across the four- and 26-occasion durations by at least 10% relative to
   the best non-FlexiRich probabilistic comparator;
2. is not more than 5% worse on that score within either primary duration;
3. is not more than 5% worse than the best eligible comparator on candidate-
   identity Brier score;
4. shows no material calibration failure or catastrophic overprediction hidden
   by the average score; and
5. retains the same conclusion under the prespecified prior and candidate-pool
   sensitivities.

The 95% block-based uncertainty interval for each primary paired score
difference must exclude deterioration beyond the corresponding 5% guardrail.
If effective replication is too small to support that inference, the empirical
result is inconclusive rather than positive.

### Task 6 — Private external validation

Huon Ridge is used only after the synthetic and Judbury gates pass. Model and
comparator settings are frozen before access. Camera identifiers may be
anonymised and non-identifying effort/detection summaries retained, but point
locations and any reconstructable location information remain outside the
repository.

Huon Ridge tests transferability; it is not another tuning dataset. A reversal
of the Judbury result must be reported and limits any general estimator claim.

## Final decisions

### RETAIN

Retain the minimal FlexiRich candidate for paper-level development only if it
passes the synthetic and Judbury gates, remains computationally usable, and
offers information beyond the simpler comparators. External confirmation is
still required before a general performance claim.

### STOP MODEL DEVELOPMENT

Stop if the candidate is uncalibrated, pathologically prior- or pool-sensitive,
computationally unreliable, or predictively indistinguishable from a simpler
method. Preserve the benchmark and consider a paper on richness identifiability,
sampling saturation, and prospective discovery instead.

### INCONCLUSIVE

Record an inconclusive result when available empirical validation blocks cannot
resolve the prespecified predictive contrast. Do not convert inconclusive to
success through additional cutoffs, alternative horizons, or post hoc pooling.

## Protected boundaries

- Goal002 and Goal002R outcomes are historical and are not rescored.
- The candidate pool is external, finite, named, and frozen before scoring.
- Seven-day incidence and exact active effort are common to all methods.
- The four-year detected pool is a validation reference, not known truth.
- Synthetic truth never enters fitted inputs.
- Judbury is the primary development/validation dataset.
- Huon Ridge is private external validation, with no point locations committed.
- Grid-level inference precedes any site-level partial pooling or spatial model.
- One candidate model, one primary parameterisation, one rescue configuration,
  and one focused implementation-repair pass are allowed.

## Explicitly deferred

- site-level richness and spatial borrowing;
- anonymous unseen-species estimation;
- abundance or density estimation;
- false-positive classification models;
- dynamic colonisation/extinction models;
- trait-rich, phylogenetic, or nonparametric abundance mixtures;
- alternative occasion lengths selected by performance;
- automated Atlas of Living Australia publication pipelines; and
- packaging or public API design before the scientific method is retained.

## Lean artefact policy

Goal003 adds only artefacts needed to make the next decision reproducible:

- this goal contract;
- one canonical evaluation-data specification;
- one frozen simulation/validation manifest per decision stage;
- focused model, comparator, and scoring code;
- compact machine-readable results; and
- one concise decision report.

No per-task ledger, compatibility layer, duplicate design document, or archive
copy is required. Git history is the archive. A task-specific implementation
plan may be written immediately before a substantial code tranche and removed
or condensed when that tranche closes.

## Immediate stopping point

The next tranche is Task 1 only: specify and validate the evaluation-data and
candidate-pool contract. Baseline or model implementation begins only after
that contract and the feasible temporal-validation design have been reviewed.
