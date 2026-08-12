# Goal 003 — Prospective finite-pool richness validation

Status: active — Tasks 1–2 complete; Task 3 design approved
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

Candidate review separates two quantities that cameras otherwise blur:

- membership in the reserve-wide JCR gamma pool, based on habitat and
  natural-history plausibility; and
- membership in the narrower ground-camera sampling frame, based on a
  prespecified camera-encounter class.

The former can contain species that are effectively undetectable by this
camera design. It is retained as ecological context; the Goal 003 model still
targets grid-level camera-encounter richness. The primary and single broader
camera pools are derived from the two review axes by a frozen rule rather than
chosen after viewing Judbury detections.

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
- Real operational gaps, including prolonged multi-camera failure, are
  retained. Zero-effort weeks are unsampled and partial weeks retain exact
  active-day exposure; no gap is imputed into a non-detection.

The primary short windows are four occasions (approximately one month) and 26
occasions (approximately six months). A 52-occasion window and the full
153-occasion Judbury record describe the sampling-intensity curve and provide
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
\qquad
\omega\sim\operatorname{Beta}(1,1),
\]

and an effort-aware encounter model for members,

\[
P(y_{ijk}=1\mid g_i=1)
=1-\exp\{-E_{jk}\exp(\alpha_i+b_j)\}.
\]

Species effects \(\alpha_i\) and camera effects \(b_j\) are partially pooled
using a non-centred parameterisation,

\[
\alpha_i=\mu_\alpha+\sigma_\alpha z_i,
\qquad z_i\sim\operatorname{Normal}(0,1),
\]

and an exact sum-zero camera basis,

\[
\mathbf b=\sigma_b\mathbf Q\mathbf z_b,
\qquad \mathbf z_b\sim\operatorname{Normal}(\mathbf 0,\mathbf I).
\]

The primary regularising priors are frozen as

\[
\mu_\alpha\sim\operatorname{Normal}\{\log(0.02),1.5\},
\qquad
\sigma_\alpha\sim\operatorname{half\text{-}Normal}(0,1),
\qquad
\sigma_b\sim\operatorname{half\text{-}Normal}(0,0.75).
\]

Encounter rates are per active camera-day. These priors are intentionally more
regularising than the historical Goal002 model and align the central encounter
rate and species heterogeneity with the conventional occupancy comparator.
They are frozen from scientific reasoning and prior prediction, not tuned to
Judbury richness outcomes.

Species detected in the training data are necessarily members. For an all-zero
candidate, membership is analytically marginalised in Stan: the likelihood is
a mixture of non-membership and the member likelihood of no detections. There
are no sampled discrete parameters or continuous pseudo-membership variables.
For each posterior draw, the model returns the exact conditional membership
probability for every candidate.

Grid-richness distributions are computed in R as exact Poisson-binomial
distributions over those conditional probabilities. For each still-unseen
candidate, future-first-detection probability combines its conditional
membership probability, posterior encounter process, and a supplied future
effort schedule. The number of future discoveries is again an exact
Poisson-binomial distribution. Draw-level distributions are averaged across
the posterior; Bernoulli membership simulations are not used to approximate
either result.

Before any candidate fit to Judbury outcomes, prior prediction must examine:

- the implied finite-pool richness distribution;
- species and camera encounter-rate distributions;
- one- and seven-day detection probabilities;
- observed richness under representative four- and 26-occasion designs; and
- the prevalence of members with effectively negligible detection probability
  and of numerically extreme hazards.

Three frozen one-factor sensitivities are retained: replace the membership
prior by \(\operatorname{Beta}(2,2)\); widen the scale of the
\(\mu_\alpha\) prior from 1.5 to 2; or widen the half-normal scale of
\(\sigma_\alpha\) from 1 to 1.5. All other priors remain at their primary
values in each sensitivity. This is a diagnostic envelope, not a route for
choosing the best-looking prior after observing outcomes.

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

### Candidate sampler and terminal-fit contract

The primary sampler uses four chains with 1,000 warmup and 1,000 retained
iterations per chain. A single rescue is permitted only after a non-clean
primary attempt: four chains with 1,500 warmup and 1,500 retained iterations,
`adapt_delta = 0.999`, and maximum tree depth 15.

A terminal fit requires zero divergent transitions, zero maximum-tree-depth
hits, minimum E-BFMI of at least 0.30, maximum rank-normalised R-hat of at most
1.01, and minimum bulk and tail effective sample sizes of at least 400. These
checks cover all population parameters, expected richness, species effects,
and camera effects. A fit still failing after rescue is explicitly unavailable;
it produces no richness or prediction summary and triggers no further tuning.

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

Completed 2026-08-10. All frozen comparators and the pinned Judbury adapter are
implemented and tested. The cumulative reference run retained terminal-clean
occupancy fits at 4, 26, and 153 weeks; the 52-week fit remained non-clean after
its sole rescue and is recorded as a comparator failure. This is a baseline
result, not grounds for further sampler tuning.

### Task 3 — Implement one candidate model

Implement the approved model as a new lean Goal003 path rather than reviving
the historical, much larger FlexiRich-G fitting engine. Reuse only verified
effort, likelihood, support, Poisson-binomial, and data-grouping foundations
that remain directly applicable.

The intended module boundary is:

- `stan/goal003_flexirich.stan`: the minimal marginalised likelihood,
  non-centred effects, exact sum-zero camera effects, and conditional
  membership quantities;
- `R/goal003_flexirich.R`: candidate data adaptation, frozen prior and sampler
  profiles, terminal fit classification, exact richness distributions, and
  future-discovery predictions; and
- `R/goal003_sampler.R`: only the CmdStan compilation, sampling-attempt, and
  diagnostic machinery genuinely shared with the existing occupancy
  comparator.

Extracting the shared sampler must leave the frozen occupancy model and its
public behaviour unchanged. No general model framework, compatibility layer,
or package API is authorised.

Task 3 verification comprises hand-calculated detected and all-zero likelihood
cases; conditional-membership and extreme-hazard checks; exact sum-zero and
data-grouping invariants; an independent Stan/R bridge; hand-verifiable
richness and future-discovery Poisson-binomial cases; prior-predictive checks;
one small synthetic end-to-end sampling smoke; and regression checks for the
occupancy comparator.

Task 3 stops when the candidate runs end to end on synthetic inputs, passes the
mathematical and prior-predictive checks, produces exact richness and discovery
distributions, and leaves the comparator intact. It does not fit or inspect
Judbury detection outcomes, compare empirical performance, or add traits,
site-level states, temporal dynamics, spatial borrowing, or abundance
interpretation. If prior prediction is materially pathological, pause for a
scientific decision rather than tuning against real data.

### Heavy-compute operating rule

Unit tests, mathematical bridges, and genuinely small smoke checks may run on
the local workstation. Stan-intensive simulation grids, calibration batches,
and empirical fitting run on `deep-server` inside a named `tmux` session from a
clean, committed analysis state. Each run records its Git commit and frozen
manifest, writes an inspectable log, and is checked for genuine progress before
monitoring is handed back to the user. The handoff gives exact WSL and macOS
status commands. No running frozen analysis is modified in place.

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
   frozen `deep-server` per-fit allocation, with a 95th percentile below 15
   minutes.

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
- The full 153-week detected pool is a validation reference, not known truth.
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

Tasks 1 and 2 are complete and the Task 3 scientific design is approved. The
next tranche is a focused TDD implementation plan followed by the single
minimal FlexiRich candidate, without reopening baseline settings or fitting it
to prospective Judbury outcomes.
