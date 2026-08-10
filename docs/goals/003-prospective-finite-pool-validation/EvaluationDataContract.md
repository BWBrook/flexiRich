# Goal 003 — Evaluation-data contract

Status: **complete — candidate pool frozen on 2026-08-10**
Prepared: 2026-08-10

This is the sole Task 1 data and temporal-validation specification. It fixes
the evidence already available, the conversion to camera-week incidence, and
the prospective folds before any baseline or FlexiRich result is computed.
It does not fit or score a richness method.

## Decisions now fixed

- The primary analysis unit is the nine-station Judbury `analysis_site`
  resolution, not the 13 physical camera positions.
- Operational events are formed at physical positions before station mapping;
  they are not reclustered after moved positions are reunited.
- One occasion is seven consecutive calendar days, beginning on Wednesday
  5 June 2019. Effort is the exact number of confirmed active station-days.
- The two primary training histories are 4 and 26 occasions.
- Both predict the same next 4 occasions. Future outcome blocks do not overlap
  within either training-duration analysis.
- Empirical uncertainty resamples whole season-year blocks, not individual
  folds or candidate species.
- The current public record contains 153 occasions. Its full 153-occasion
  detected pool is the operational long-window reference. It is not known
  ecological truth.
- Barry confirmed on 10 August 2026 that this pinned 153-occasion extract is
  the intended final Judbury record for Goal 003.
- The four-occasion forecast horizon is confirmed because it represents the
  approximately one-month deployment used in many snapshot camera surveys.
- All observed effort gaps are retained, including the prolonged near-gridwide
  camera outage caused by a firmware fault. They are neither imputed nor
  trimmed away: exact active days determine sampled, partially sampled, and
  unsampled camera-weeks.
- The 52-occasion context is supported. A 208-occasion/four-year Judbury
  analysis is not supported by the pinned data and may not be reported.

The common four-occasion forecast horizon is deliberate. It compares what one
month versus six months of monitoring contributes to the same future question
and retains useful prospective replication. Matching the 26-occasion training
window to a 26-occasion forecast would leave too few non-overlapping outcomes
for the prespecified empirical uncertainty assessment.

The irregular effort is part of the empirical challenge rather than a data
defect to be regularised away. Zero-effort weeks remain `NA`, partial weeks
retain their exact active-day exposure, and future scores remain conditional
on realised effort. Goal 003 therefore tests inference under the failures a
real camera programme experiences, without turning camera-uptime forecasting
into a second modelling problem.

## Read-only Judbury authority

The source is the separate, read-only checkout
`/home/bwbrook/git/camtrap-workflow` at commit
`dbe656e3e423e4c89028965bf79dfa18a441a49a`. No source data or tracked file in
that repository was changed during this assessment.

| Evidence | SHA-256 |
| --- | --- |
| `data/jc_obs.csv` | `deafe2af080726aa8b3ec67baca70f7f9c45b18acbfc56ceed39cb353eab5ae0` |
| `data/jc_op.csv` | `28222586fa232fccc46bfab5e8c07e0c453f07387ebe4eb95b9a90e4687033a3` |
| `data/jc_site.csv` | `7562542edcf809503c147e7ffeb5aac5ca7288eb67d782802cd364a690f4db35` |
| `data/jc_taxa.csv` | `7abcc6ff7fd49d3130b29589dc552ff45d00a8a7dfeb355d1ac61c7eb35ea18a` |
| deployment ledger | `0921eb8845c2bb1ad5760271f283ab2783735b7739e254c67e9243bc906f3ebf` |
| 13-position to 9-station mapping | `6490d7f7021e5c727b9be1c7d6dfbf44ba50a1ef5b0396c66e1dd813a9c77083` |

The imported event definition is
`operational_detection_event.gap/1.0`: within each physical-position and
species series, an event begins when the gap from the preceding image is
strictly greater than 15 minutes. Images on inactive dates and unparseable
timestamps are excluded before event construction. Judbury timestamps use the
source's fixed UTC+10 interpretation (`Etc/GMT-10`), not daylight-saving time.
The Goal 003 adapter receives the resulting one-row-per-event table; it does
not reproduce this event algorithm.

The selected-resolution mapping unions confirmed operation across member
positions. One approved same-day handover has two active physical positions
but contributes one station-day. Physical event identities remain conserved.

## Source audit

The raw and resolved tables reconcile as follows.

| Check | Result |
| --- | ---: |
| Operation dates | 2019-06-05 to 2022-05-10 |
| Consecutive calendar days | 1,071 |
| Seven-day occasions | 153 |
| Physical positions / analysis stations | 13 / 9 |
| Physical-position active days | 7,645 |
| Station active days after union | 7,644 |
| Station-days total / inactive | 9,639 / 1,995 |
| Raw observation rows | 15,694 |
| Parsed timestamps | 15,694 |
| Rows excluded on inactive dates | 22 |
| Retained event memberships | 15,672 |
| Operational events | 11,572 |
| Source taxa labels | 28, including `Unknown_Animal` |
| Station-weeks total | 1,377 |
| Positive / zero-effort station-weeks | 1,111 / 266 |
| Complete / partial among positive station-weeks | 1,076 / 35 |

The 180 repeated `imageid`/filename values reflect the observation-row grain,
which can contain more than one classification for an image; `index` is unique.
Counts and image-row duplication do not enter Goal 003 after operational-event
construction. `Unknown_Animal` is never a candidate species or a detection.

## Canonical analysis boundary

`build_goal003_weekly_inputs()` accepts three small canonical tables:

| Table | Exact fields | Grain |
| --- | --- | --- |
| candidate pool | `species_id` | one named candidate |
| daily operation | `camera_id`, `date`, `active` | one analysis station-day |
| events | `event_id`, `camera_id`, `species_id`, `event_time` | one operational event |

For the empirical adapter, `camera_id` is the selected nine-station
`analysis_site_id`; `species_id` is the frozen scientific name. The ALA taxon
concept identifier remains metadata rather than the join key so that documented
expert additions and later taxonomic updates do not create mixed identifier
semantics.

The builder requires a complete camera-by-calendar-day grid, whole seven-day
occasions, unique event IDs, and an active station-day for every event. It
returns:

- `occasion_calendar`: ID, integer index, start date, and end date;
- `effort_weekly`: one camera-occasion row with `active_days` in 0–7; and
- `detections`: the complete candidate-camera-occasion grid, with `1` for at
  least one event, `0` for a sampled non-detection, and `NA` when effort is zero.

Candidates never detected remain explicit all-zero histories over sampled
camera-weeks. The returned tables pass directly to the existing
`prepare_flexirich_g_data()` boundary. Event formation, entity resolution, and
taxonomic review stay outside the estimator code.

Before empirical use, the Judbury taxon table is joined to the frozen pool by
genus and species. Every named in-scope Judbury taxon must resolve exactly once.
An unmatched named taxon is a contract failure, not permission to add a
candidate after viewing the temporal outcomes.

## External candidate-pool evidence

The frozen candidate pool is
[`config/goal003_candidate_pool.csv`](../../../config/goal003_candidate_pool.csv).
Its review template was created without joining, flagging, or sorting by
Judbury detections.

The Atlas of Living Australia occurrence API was queried on 2026-08-10 using
its default quality filtering:

- centre: mean of the nine frozen representative station coordinates,
  latitude `-42.9989338`, longitude `146.9434018`;
- radius: 10 km;
- query: all records, separately filtered to `Mammalia`, `Aves`, and
  `Reptilia`;
- facet: `species`, limit 1,000, index order; and
- focal-programme exclusion: no data resource returned by the query was
identified as Judbury, this camera programme, or LILA.

This is retrospective rolling-origin validation conditional on a regional
pool frozen in 2026, not a claim that the same ALA information was available
at every historical cutoff. The all-date query is intentionally inclusive of
rare regional candidates; it supplies candidate support only, is identical for
all methods, and does not reveal focal membership or future Judbury outcomes.

The committed worksheet is the evidence snapshot because ALA is a mutable
aggregator. Re-querying it after method results are inspected is prohibited.
Its pre-review SHA-256 is
`0e8da17e0657cb446e6797da9fb79fecd22f8b3d85d21f56eb0c5b379a459429`;
this remains the original extraction receipt. The expanded review template,
which adds independent JCR-membership and camera-encounter judgements without
changing the 198 candidate rows or ALA counts, has SHA-256
`6fae28e315b8bf898cc4e74c7f63c5675cd1bdb2e9083660e2de9e78293a073c`.
The final reviewed hash is recorded in the frozen result below rather than
confused with either receipt.
The initial extraction contains:

| Class | Named ALA taxa | Named records | Other records | Review disposition |
| --- | ---: | ---: | ---: | --- |
| Mammalia | 25 | 523 | 5 not taxonomically supplied | 23 require JCR and camera review; dolphin and thylacine excluded |
| Aves | 164 | 15,658 | 209 not taxonomically supplied | all require JCR, ground-use, and camera review |
| Reptilia | 8 | 44 | 0 | secondary-stratum review only |

`Canis familiaris` is an explicit expert-review row with zero ALA records,
added from the surrounding settled/rural site context rather than from focal
detections. The expert review includes it in the primary pool; its taxon concept
identifier remains blank because it was not supplied by the ALA extraction.

Evidence services and authoritative context are documented by the
[ALA occurrence API](https://docs.ala.org.au/openapi/index.html?urls.primaryName=occurrences),
the Tasmanian Government's
[mammal list](https://nre.tas.gov.au/wildlife-management/fauna-of-tasmania/mammals/complete-listing-of-tasmanias-mammals),
[bird list](https://nre.tas.gov.au/wildlife-management/fauna-of-tasmania/birds/complete-list-of-tasmanian-birds),
and its educational account of
[ground-foraging forest birds](https://nre.tas.gov.au/Documents/Kit10.pdf).

### Review and freeze rule

Barry reviews the CSV without a Judbury-detection column.

Two judgements are deliberately kept separate.

1. `jcr_gamma_pool` describes ecological membership in the reserve-scale
   species pool, irrespective of this camera design. Its values are `include`,
   `borderline`, or `exclude`. Include a species if it plausibly used JCR
   habitat at least occasionally during the 153-week reference period;
   `borderline` is for genuine uncertainty or transient use. Species tied to
   habitat absent from JCR, such as marine or unsuitable wetland taxa, are
   excluded even when they have records elsewhere in the 10 km circle.
2. `camera_encounter_class` describes natural-history plausibility of encounter
   by the ground-camera array. Its values are `routine`, `occasional`, `rare`,
   `negligible`, or `uncertain`. This is an ordinal sampling-frame judgement,
   not an estimate of detection probability. `Rare` means a non-zero but
   exceptional ground-camera encounter; `negligible` means the species is
   effectively outside this camera method's sampling frame.

For birds, `ground_use` additionally becomes one of `common`, `occasional`,
`rare`, `none`, or `uncertain`. It records the natural-history basis for the
camera judgement; a bird can belong to the JCR gamma pool while being outside
the ground-camera pool.

Barry need only edit the applicable review fields above, plus any explanatory
`decision_reason`, `reviewer`, and `review_date`; the derived pool columns can
remain `review`. After those fields are completed, the primary and sensitivity
pools are generated by the following frozen rules and returned for
confirmation:

- `primary_pool = include` for mammals and birds only when
  `jcr_gamma_pool = include` and `camera_encounter_class` is `routine` or
  `occasional`; otherwise it is excluded;
- `broader_pool` contains every primary include and additionally admits
  mammals and birds classed `borderline` for JCR use, `rare` for camera
  encounter, or `uncertain` for camera encounter, but never a JCR exclusion or a
  `negligible` camera encounter; and
- reptiles remain primary exclusions. If the secondary reptile analysis is
  retained, `secondary_pool = include` uses the same strict rule as the
  primary pool.

The JCR gamma pool is a scientifically useful reserve-wide reference, not a
replacement estimand for Goal 003. The model's primary target remains
grid-level **camera-encounter richness**. Reporting both prevents a camera
sampling frame from being mistaken for all vertebrate diversity in JCR.

- Any authoritative addition absent from ALA is added with its source and an
  explicit reason. The focal detection history is not a permitted reason.
- `decision_reason` records any non-obvious classification; `reviewer` and
  `review_date` are completed for every decided row.

The pool freezes only after there are no `review` values in the applicable
review fields, no unexplained duplicate names or concept IDs, every include
has an external evidence reason, and the derived columns satisfy the rules
above. Its SHA-256 is then recorded here before Task 2 begins.

### Frozen pool result

Barry completed the expert review on 10 August 2026. The returned worksheet
had reordered the linked identity-and-review columns while leaving the
template's derived columns in their original row positions. Finalisation
therefore rejoined the five expert fields to the immutable extraction snapshot
by unique `scientific_name`, restored the canonical evidence and row order,
and recomputed every derived pool field. No expert classification was changed.
The two ground-use synonyms supplied in the review were normalised from
`routine` to `common` and from `negligible` to `none`.

| Class | JCR include | JCR borderline | JCR exclude | Primary camera pool | Broader camera pool | Secondary pool |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Mammalia | 18 | 4 | 4 | 17 | 21 | — |
| Aves | 42 | 43 | 79 | 33 | 85 | — |
| Reptilia | 7 | 1 | 0 | — | — | 2 |
| **All taxa** | **67** | **48** | **83** | **50** | **106** | **2** |

The final file has 198 unique scientific names, no unresolved review values,
no duplicated nonblank taxon concept identifiers, complete evidence reasons,
and a broader pool containing every primary include. Its frozen SHA-256 is
`60c8900c1904bafa34340e8ea7e2a44fc819836f76746fc7ee80c484166608db`.

Only after that freeze, the 27 named labels in the pinned Judbury taxon table
were joined by genus and species. All resolved exactly once. Twenty-six belong
to the primary pool; `Zanda funerea` (yellow-tailed black-cockatoo) is the sole
broader-only label because its JCR membership is included but its camera
encounter class is `rare`. `Unknown_Animal` remains outside every pool. This
post-freeze reconciliation did not alter the candidate review.

## Prospective validation folds

The frozen fold manifest is
[`config/goal003_judbury_validation_folds.csv`](../../../config/goal003_judbury_validation_folds.csv),
SHA-256
`4620d18e5db4caf11e2a42e71f2dbcf12325abd3851f66e2fd1f7c1a3378ba4c`.

Complete four-occasion future blocks partition occasions 1–152. Occasion 153
is retained in long-window summaries but is not stretched into an incomplete
forecast block. For each training duration, a fold is eligible when the exact
number of immediately preceding occasions exists.

| Training history | Forecast horizon | Folds | Season-year blocks |
| ---: | ---: | ---: | ---: |
| 4 occasions | 4 occasions | 37 | 12 |
| 26 occasions | 4 occasions | 31 | 10 |

The forecast midpoint assigns each fold to an austral season (`DJF`, `MAM`,
`JJA`, or `SON`) and season year; December belongs to the following DJF year.
The observed score is the equally weighted mean across eligible folds within a
training duration.

Each method trains only on events and effort through `train_end_date`. For
scoring, prediction is conditional on the realised station effort in the
four-occasion future block. This deliberately tests richness/detection
inference rather than camera-uptime forecasting; no future species detection
or statistic derived from it enters training.

Paired method contrasts use a deterministic 9,999-draw season-year cluster
bootstrap with seed `3003`. Each draw samples the available season-year block
IDs with replacement and includes all folds belonging to each sampled block;
the 2.5th and 97.5th percentiles form the interval. A primary duration is
topologically eligible only with at least 24 forecast folds and eight distinct
season-year blocks. Both current durations pass that pre-result check. Wide
intervals still yield an inconclusive empirical decision; they do not license
additional cutoffs or overlapping future outcomes.

## Task 1 closure

Task 1 is complete. The source record, occasion length, training windows,
four-occasion forecast horizon, operational-effort treatment, candidate-pool
rules, expert classifications, derived pools, fold manifest, and frozen hashes
are all fixed before any baseline result is computed. Task 2 may now begin.
