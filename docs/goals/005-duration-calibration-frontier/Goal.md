# Goal 005 — deployment-duration and encounter-calibration frontier

Status: active; Tasks 2 and 3 complete and audited, Task 4 next
Proposed: 2026-08-20

## Decision question

Across practical camera-deployment durations, how much independently derived
encounter-rate information is required before finite-pool grid-level richness
becomes accurate and decision-stable?

The primary durations are 4, 8, and 12 seven-day occasions, corresponding to
roughly one, two, and three months. Durations of 16 and 26 occasions are
diagnostic anchors rather than preferred survey lengths.

## Motivation

Goal004 solved the declared-pool problem but stopped at its frozen development
gate. Its independent core/fringe construction preserved the 50-candidate core
posterior, and the model was computationally clean. The unresolved failure was
the encounter-rate--richness axis:

- four-week estimates were poorly calibrated in the intermediate-richness
  cell and included catastrophic errors even under substantial realised
  effort;
- halving or doubling plausible class-rate locations shifted mean richness by
  roughly 5--8 species at four weeks; and
- 26-week inference was accurate when the fitted class distribution matched
  the generator, but remained consequentially sensitive to rate location.

Goal005 does not retune Goal004 against those same outcomes. It asks a new
feasibility question with new simulation seeds and a common decision standard
across durations.

## Scientific distinction

More target-survey effort and better external rate calibration attack the same
weak-identification ridge in different ways. Goal005 maps both axes and keeps
two outcomes separate:

1. **conditional accuracy** — performance when the encounter-rate information
   supplied to the model is correct; and
2. **decision stability** — performance when realistic uncertainty or modest
   transfer error remains in that information.

Narrowing Goal004's log-rate spread is not a valid representation of better
calibration. That spread describes genuine between-species heterogeneity as
well as uncertainty about any one candidate. Goal005 must separate uncertainty
in class locations from candidate-specific rate information.

## Estimand and retained data contract

The estimand remains the number of members of the reviewed 50-species
camera-accessible core pool using the nine-camera grid over the defined gamma-
pool reference period. It is not abundance, total vertebrate richness, or the
number photographed during the deployment.

The retained observation contract is species by camera by seven-day incidence,
with exact active camera-days and zero-effort cells treated as unsampled. The
encounter hazard remains

\[
P(y_{ijk}=1\mid g_i=1)
=1-\exp\{-E_{jk}\exp(\alpha_i+b_j)\}.
\]

Every result reports calendar duration, total active camera-days, and the
number of cameras contributing non-zero effort. Calendar duration is the
operational decision axis; realised effort and spatial coverage explain why
two deployments of the same length can carry different information.

## Protected evidence boundary

Goal005 may use:

- the reviewed candidate labels;
- the tracked Judbury operational-effort template, without detections;
- the frozen Goal004 model, priors, design, and aggregate decision evidence;
- fully synthetic membership, rates, camera effects, calibration estimates,
  and detections; and
- new Goal005 seeds and non-overwriting outputs.

Goal005 may not access:

- Judbury detections or future species discoveries;
- a long-period Judbury detectable-use pool;
- Huon Ridge detections, effort, or locations; or
- any Goal006 or Goal007 outcome.

The long Judbury record is reserved for empirical development and validation
in Goal006. Huon Ridge remains untouched private external validation for
Goal007, after the method and decision rules are frozen. Its point locations
need not enter the future grid-level analysis.

## Staged sequence

### Task 1 — freeze calibration semantics and duration design

Define the class-distribution and candidate-rate calibration targets, their
oracle limits, the paired duration/effort design, a common duration-independent
decision standard, and the exact pruning rules. No Stan grid or empirical
outcome is accessed.

### Task 2 — information-ceiling screen

Using new aligned synthetic histories, compare:

- a **class-distribution oracle**, which knows the true routine and occasional
  rate distributions but not each candidate's latent rate; and
- a **candidate-rate oracle**, which knows every candidate's latent rate while
  still estimating target-grid camera effects and membership.

For each duration:

- failure of the candidate-rate oracle means that independent encounter-rate
  calibration alone cannot rescue that duration;
- candidate-oracle success but class-oracle failure means candidate-specific
  information is required; and
- class-oracle success means class-level calibration may be sufficient and
  should be tested before adding candidate-specific information.

### Task 3 — bounded calibration-precision frontier

Only for durations and calibration resolutions retained by Task 2, use fresh
synthetic evidence to find the coarsest independently calibrated rate
information that meets the common decision standard. Calibration precision is
expressed on the log-rate scale and as the multiplicative width of its 95%
interval, not as an arbitrary prior-profile label.

Class-level calibration varies uncertainty in externally estimated class
locations while retaining the biological between-species spread. Candidate-
specific calibration supplies externally estimated candidate log rates and
their uncertainty. Neither source conveys target-grid membership.

### Task 4 — bounded transfer-error stress

At the smallest passing duration/calibration cells, apply a prespecified modest
location bias to the external calibration using new seeds. This is a narrow
guardrail against declaring a precise but non-portable calibration successful;
it is not a large factorial robustness exercise.

### Task 5 — decision and protected handoff

Report the duration--calibration decision surface and choose one of:

- `FRONTIER_FOUND`: at least one practically relevant cell meets the common
  standard and remains acceptable under the bounded transfer stress;
- `CONDITIONAL_FRONTIER_ONLY`: cells work only under effectively oracle or
  non-robust calibration, so point estimates require explicit conditional
  reporting; or
- `NO_RATE_CALIBRATION_FRONTIER`: even the candidate-rate oracle fails at all
  relevant durations, so rate calibration cannot support this estimand.

An execution or evidence-integrity failure is reported separately and cannot
be converted into a scientific decision.

## Goal006 and Goal007 handoff

Goal005 identifies what rate precision is required in principle. It does not
show that real data can supply it.

Goal006 will test the frozen successful cells against Judbury's long-duration
detectable-use reference while preventing future detections from leaking into
short-window calibration. Same-site historical calibration, if examined, is a
separate repeat-monitoring use case rather than evidence for a new-site
snapshot survey.

Goal007 will freeze the successful method and test transfer to Huon Ridge. The
strongest design is to derive transferable calibration from Judbury and apply
it to short Huon Ridge windows before comparing with Huon Ridge's own long-
duration reference. No Huon Ridge result may be used to revise Goal005 or
Goal006 choices.

## Deferred scope

Goal005 does not add site-level borrowing, spatial occupancy, seasonal
dynamics, abundance or density, anonymous unseen species, new encounter
classes, or a package API. These remain separate scientific questions.

## Approval record

The collaborator approved the Goal005--Goal007 sequence on 2026-08-20,
including 4/8/12-week primary durations, 16/26-week anchors, strict leakage
protection, Judbury empirical development before Huon Ridge, and Huon Ridge as
the eventual external validation dataset. The Task 1 design and thresholds
were approved on 2026-08-20. Task 2 used the frozen 180-dataset, 360-fit
information-ceiling contract recorded in `Task1Design.md`; its protected
synthetic implementation is recorded in `Task2Implementation.md`. The run
completed and independently replayed all decision rows: 4 and 8 weeks failed
both information ceilings, while 12, 16, and 26 weeks passed both and are
eligible for class-level calibration. The evidence and interpretation are
recorded in `Task2Decision.md`. The bounded next experiment is specified in
`Task3Design.md`; its implementation and local verification are recorded in
`Task3Implementation.md`. The collaborator approved the frozen calibration
grid and prespecified Task 4 transfer-stress contract on 2026-08-20. The
frozen Task 3 run completed all 108 datasets and 756 fits, and an independent
implementation replayed all 357 decision rows exactly. Class-level frontiers
were F3 at 12 weeks and F5 at 16 and 26 weeks. The evidence, including the
sampler-driven qualification on the 12-week F5 failure, is recorded in
`Task3Decision.md`. The prespecified Task 4 stress therefore proceeds at 12
weeks and F3; its exact paired design and fresh seed contract are recorded in
`Task4Design.md`.
