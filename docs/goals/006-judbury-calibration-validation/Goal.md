# Goal 006 — leakage-controlled Judbury calibration and prospective grid validation

Status: active; formal design approved, Task 1 contract awaiting confirmation
Proposed and approved: 2026-08-24

## Decision question

Can encounter-class calibration learned from an earlier, outcome-isolated
Judbury period provide sufficiently precise and portable information to
support useful grid-level richness inference and prospective species-discovery
forecasts in later Judbury deployments?

Goal006 is a same-grid repeat-monitoring test. Success would make a frozen
candidate ready for genuine new-site transfer testing at Huon Ridge; it would
not itself establish new-site validity.

## Motivation

Goal005 established three relevant boundaries using protected synthetic truth:

- exact candidate encounter rates did not make four- or eight-week inference
  meet the common richness standard;
- finite class calibration could support accurate inference at 12, 16, and 26
  weeks under favourable streams; and
- the selected 12-week/F3 cell failed its fresh unbiased replication despite
  clean computation, while the additional paired effects of a common 25%
  calibration bias remained modest.

The final Goal005 decision was `CONDITIONAL_FRONTIER_ONLY`, qualified by
`UNBIASED_REPLICATION_FAIL`. Goal006 therefore does not treat 12-week/F3 as a
validated estimator or tune it against Judbury. It asks whether real camera
data can supply a more conservative calibration, whether that calibration
transfers prospectively through time, and whether the resulting model earns
its complexity over simpler empirical comparators.

## Estimands and evidence targets

The latent estimand remains the number of members of the reviewed 50-species
primary camera-accessible pool with a non-zero camera-encounter-generating
process on the nine-station Judbury grid over the 153-occasion reference
period. This is grid-level camera-encounter richness, not abundance, density,
site richness, or total JCR vertebrate richness.

The observation contract remains species by station by seven-day incidence,
with exact active station-days and zero-effort cells treated as unsampled. The
member encounter hazard remains

\[
P(y_{ijk}=1\mid g_i=1)
=1-\exp\{-E_{jk}\exp(\alpha_i+b_j)\}.
\]

The primary empirically observable validation targets are the number and
identities of target-window-unseen candidates detected during the next four
occasions. Count distributions receive ranked-probability and log scores;
candidate probabilities receive Brier scores.

The 26 primary-pool species detected at least once in the complete 153-week
record form an operational lower reference for grid richness. They are not
known ecological truth. Total-richness posteriors may be checked for one-sided
compatibility with this reference, concentration, sensitivity, and convergence
with duration, but they must not receive proper scores against a point mass at
26.

Every duration result reports calendar length, target active station-days,
number of stations with positive effort, and the effort available in its
forecast block.

## Chronological split

The split is fixed for scientific reasons before class-specific calibration
or fold-level outcomes are inspected.

| Role | Occasions | Dates | Purpose |
| --- | ---: | --- | --- |
| Calibration | 1--52 | 2019-06-05 to 2020-06-02 | One full annual cycle for encounter-class calibration |
| Separation gap | 53--54 | 2020-06-03 to 2020-06-16 | Prevent calibration/target overlap under the common fold alignment |
| Evaluation support | 55--152 | 2020-06-17 to 2022-05-03 | Nested target windows and held-out forecasts |
| Calendar remainder | 153 | 2022-05-04 to 2022-05-10 | Retained in the full-record reference but outside the aligned forecasts |

There are 18 common four-occasion forecast blocks, beginning at occasions
81, 85, ..., 149. For every forecast block, target histories comprise the
immediately preceding 4, 8, 12, 16, or 26 occasions. Thus the 26-week target
for the first forecast begins at occasion 55, after the calibration gap.

The forecast outcomes do not overlap. Target histories overlap, as they would
under repeated prospective monitoring, and are paired across durations at the
same cutoff. The forecast blocks span six season-year uncertainty blocks.
Inference on aggregate performance resamples those blocks rather than treating
individual folds, species, or overlapping histories as independent.

Four- and eight-week fits are prespecified negative controls. Goal005 closed
them at the information ceiling, so an attractive Judbury result cannot make
either duration eligible for advancement. Twelve, 16, and 26 weeks are the
eligible duration set; the shortest duration meeting all Goal006 requirements
is selected if more than one passes.

## Calibration boundary

Only occasions 1--52 may inform the initial calibration artifact. The
calibration analysis estimates the routine and occasional class log-rate
locations under the same effort-aware encounter process used by the target
model. The primary biological between-species spread remains fixed at the
Goal005 value of one; one bounded, prespecified spread sensitivity may test
that simplification, but no flexible mixture is added.

Species contributing positive calibration histories are selected by having at
least one detection. The calibration likelihood must therefore account for
that selection after marginalising the latent species rate. Treating detected
species as an untruncated random sample of members is invalid. A mathematical
likelihood bridge and synthetic recovery check are required before empirical
calibration.

The only object allowed to cross from calibration into a later target fit is
an aggregate, versioned class-calibration artifact containing class-location
estimates, their uncertainty representation, provenance, and diagnostics. It
must not contain or expose:

- calibration-period species identities or detection histories;
- candidate-specific encounter-rate estimates;
- historical membership indicators or probabilities; or
- any target or forecast outcome.

The target model receives the externally reviewed candidate classes and the
aggregate artifact, then re-estimates membership and target-window station
effects from the target history alone. This hard interface makes the test
outcome-isolated through time while retaining its honest interpretation as
same-grid calibration.

## Calibration feasibility standard

Task 1 will freeze the full numerical gate before empirical calibration, but
the load-bearing requirement is already fixed: the marginal 95% uncertainty
factor for each class location must be F2 or better,

\[
F_h=\exp\{q_{0.975}\,\mathrm{sd}(m_h\mid\text{calibration})\}\le 2.
\]

F2 is a new, conservative development target chosen after Goal005 closed F3
as non-replicating; it is not a relabelling of the Goal005 frontier. Precision
alone is insufficient. The calibration fit must also be computationally clean,
recover known synthetic locations, avoid material prior-boundary behaviour,
and remain acceptable under a bounded leave-one-station-out and prior/spread
sensitivity. If a Gaussian artifact is used, its approximation to the joint
class-location posterior must itself pass a frozen check.

Failure of this gate produces `CALIBRATION_FEASIBILITY_FAIL` and stops
FlexiRich target fitting. Transparent empirical baselines may still be
reported, but the later Judbury outcomes cannot be used to redesign the failed
calibration within Goal006.

## Comparators and prospective evaluation

If calibration passes, each of the 90 duration-by-forecast target histories is
analysed using the frozen calibrated FlexiRich candidate. The same histories,
effort, candidate pool, and future effort are supplied to eligible comparators:

1. observed richness and its zero-new-species forecast;
2. Chao2 and iChao2 point estimates;
3. iNEXT incidence accumulation and extrapolation;
4. conventional effort-aware multispecies occupancy; and
5. the matching prior-only finite-pool richness distribution.

No comparator receives an invented probability distribution for a quantity it
does not estimate. Prospectively observable count and identity outcomes are
the primary empirical decision evidence. Total-richness summaries against the
153-week detected pool remain explicitly one-sided and operational.

Task 1 will freeze the exact computational, proper-score, calibration-
sensitivity, and one-sided richness-reference gates before Task 4 outcomes are
opened. The principal requirements are:

- terminally reliable computation across prespecified folds and durations;
- prospective new-species count and identity performance that materially earns
  the calibrated model's complexity over the best eligible comparator;
- no season-year block in which an apparent pooled gain is driven by selective
  omission or non-clean fits;
- richness envelopes that do not systematically exclude the known detected
  lower reference or collapse against the 50-candidate ceiling; and
- posterior-richness shifts under the frozen calibration sensitivities that
  remain within a prespecified Goal005-scale tolerance.

Observed effort failures are never trimmed after outcomes are seen. A calendar
duration may receive a separately reported minimum-effort qualification, but a
poor-effort fold remains in its primary scheduled denominator.

## Staged sequence

### Task 1 — freeze the empirical and decision contract

Re-audit the immutable 153-week Judbury content receipts, candidate pool,
event protocol, nine-station mapping, chronological folds, calibration/target
schemas, comparator eligibility, numerical gates, stop rules, and compact
output contract. Existing aggregate Goal003 results are declared as known
historical context and cannot set new thresholds. No class-specific calibration
or forecast-fold result is inspected.

The proposed executable contract, numerical gates, and outcome-free fold
manifest are recorded in [`Task1Design.md`](Task1Design.md). They remain
unexercised against a class-specific calibration or forecast outcome pending
collaborator confirmation.

### Task 2 — implement and validate the calibration layer

Derive the selection-adjusted calibration likelihood, prove its numerical
bridge on small cases, implement the smallest valid Stan/R path, and test
recovery under a bounded synthetic design with known class locations. Verify
that the aggregate artifact excludes identity and membership leakage. This
task uses no empirical Judbury detections.

### Task 3 — first-year calibration feasibility gate

Fit only occasions 1--52, publish the immutable aggregate calibration artifact,
and adjudicate the frozen F2, computation, recovery, approximation, and bounded
sensitivity requirements. Stop on failure without opening the later target
screen.

### Task 4 — prospective Judbury screen

Provided Task 3 passes, fit the calibrated candidate and comparators to the 18
paired cutoffs across five durations. Score the held-out four-week discovery
counts and identities, summarise total richness against the operational lower
reference, and evaluate the frozen decision rows with season-year block
uncertainty. Stan-intensive batches run on `deep-server` only from a clean,
pushed, frozen commit.

### Task 5 — decision and external-validation release

Choose one of the scientific outcomes below. If the candidate advances, refit
the unchanged calibration model to all 153 Judbury occasions, compare the
full-record artifact with the first-year artifact under a predeclared temporal-
consistency check, and freeze the accepted calibration, target model, duration,
candidate pool, and decision rules before Huon Ridge is opened.

## Goal decision

Provided execution and evidence integrity pass, Goal006 chooses one of:

- `CALIBRATION_FEASIBILITY_FAIL` — the first-year record cannot supply a valid
  F2-or-better class calibration under the frozen calibration model, so no
  calibrated target claim is made;
- `JUDBURY_CONDITIONAL_ONLY` — calibration is feasible and the model may be
  empirically informative, but no eligible duration clears the complete
  prospective, robustness, and richness-reference standard; or
- `READY_FOR_HUON_RIDGE` — at least one of 12, 16, or 26 weeks clears the full
  frozen standard, the shortest passing duration is selected, and the
  full-record Judbury calibration remains temporally consistent enough to
  freeze for external validation.

`READY_FOR_HUON_RIDGE` means ready to be tested, not validated or generally
transportable. Execution failure, corrupted evidence, or leakage is reported
separately and cannot be converted into a scientific outcome.

## Known historical context and blindness limitation

Goal006 is not a virgin-blind Judbury analysis. Goal003 already recorded
cumulative observed richness of 11, 18, 21, and 26 species at 4, 26, 52, and
153 occasions, together with selected cumulative comparator summaries. Those
facts cannot be forgotten and are declared here before Task 1.

The new evidence that remains procedurally protected consists of the
class-specific first-year calibration result, the 18 fold-level target and
forecast outcomes, their season-year score distribution, and all Goal006
model comparisons. Neither the known aggregate values nor the full-record
detected pool may be used to choose calibration structure, folds, thresholds,
or eligible durations.

The separate `camtrap-workflow` checkout remains read only. Although its Git
HEAD has advanced since Goal003, the six source files used by the canonical
Judbury adapter still match their frozen SHA-256 receipts as of 2026-08-24.
Task 1 will make content hashes, not a mutable working-tree position, the
Goal006 data authority.

## Huon Ridge and later scope

Huon Ridge detections, effort, point locations, and long-duration pool remain
outside Goal006. No Huon Ridge result may choose or revise the Judbury
calibration, duration, target model, pool, or gates. Goal007 begins only from a
committed `READY_FOR_HUON_RIDGE` release.

Site-level richness and borrowing among cameras remain deferred until after
the grid-level candidate has faced external validation. Goal006 also excludes
spatial occupancy, seasonal dynamics, abundance or density, anonymous unseen
species, new encounter classes, reptiles, repeated candidate-pool expansion,
and package/API development.

## Approval record

On 2026-08-24 the collaborator approved Goal006 as the next formal goal,
including the first-52-week calibration block, gap, paired later-duration
screen, F2-or-better calibration target, prospective four-week forecasts,
one-sided treatment of the 153-week detected pool, and Huon Ridge as the later
external validation rather than a development dataset.
