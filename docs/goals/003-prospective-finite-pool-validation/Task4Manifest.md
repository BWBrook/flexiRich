# Goal003 Task 4 synthetic screening manifest

Status: **frozen before execution**
Prepared: 2026-08-13

## Decision and scope

This manifest defines the bounded synthetic screen that decides whether the
Goal003 FlexiRich candidate merits final calibration. It tests calibration,
comparative richness inference, computational reliability, and two deliberate
forms of model misspecification under known truth.

The screen does not fit Judbury detections, inspect future Judbury detections,
alter the candidate or comparator priors, or choose scenarios after seeing
model performance. Failure is an informative scientific result and stops the
candidate unless preserved evidence demonstrates an implementation defect.

The tracked authorities are:

| File | Rows | SHA-256 |
| --- | ---: | --- |
| `config/goal003_task4_scenarios.csv` | 5 | `c5f1002af029959e38a357e495a41fe31c2398df13aa4a934eef9eb49e20830b` |
| `config/goal003_task4_datasets.csv` | 300 | `464db8a708c5f4eb5b5f2274ab30483d5674df896825b28604907c89e6a60858` |
| `config/goal003_task4_fits.csv` | 840 | `ca91a921da62a3d6a33058ff35c1e72a3ee50b303dc014e9976a370eff6e7a85` |
| `config/goal003_task4_effort_template.csv` | 1,377 | `d46655701ba0427264fc40a4a568b2ee350a34e9683b1cf1daa3d67ceeaeede9` |

`R/goal003_task4_manifest.R` reconstructs the expected scenario, dataset, and
fit rows and rejects any discrepancy. The later batch runner must validate
these files before simulation and record all four hashes in its metadata.

## Screening design

Every dataset contains 50 named candidates and nine cameras. Training lasts
either four or 26 seven-day occasions and is followed immediately by the same
four-occasion forecast horizon used by the empirical contract. Each of the ten
scenario-by-duration cells contains 30 replicates.

| Scenario | Class | True richness | 4-week datasets | 26-week datasets |
| --- | --- | ---: | ---: | ---: |
| `matched_low` | matched | 10 | 30 | 30 |
| `matched_mid` | matched | 25 | 30 | 30 |
| `matched_high` | matched | 40 | 30 | 30 |
| `guild_lower_tail` | misspecified | 25 | 30 | 30 |
| `seasonal_availability` | misspecified | 25 | 30 | 30 |

The 180 matched datasets estimate calibration across 20%, 50%, and 80% pool
membership. The 120 misspecified datasets isolate two consequential failure
modes at intermediate richness without multiplying them across an unnecessarily
large factorial grid.

## Matched generator

For a member species (i), camera (j), and occasion (k),

\[
\alpha_i\sim N\{\log(0.002),1^2\},
\qquad
b_j\sim N(0,0.35^2),
\]

with the realised camera effects centred to sum exactly to zero. Conditional
on membership and active days (E_{jk}),

\[
P(y_{ijk}=1)=1-\exp\{-E_{jk}\exp(\alpha_i+b_j)\}.
\]

Non-members have zero detection probability. Membership, species effects, and
camera effects are constant across the combined training and forecast period.
The median rate of 0.002 encounters per active camera-day is below the fitted
model's prior centre but remains well within its frozen support; it ensures the
four-week experiment is not trivially saturated while allowing substantial
learning over 26 weeks.

## Misspecification mechanisms

### Cryptic lower-tail guild

Exactly five of the 25 members are assigned to a cryptic guild. Ordinary and
cryptic log encounter rates follow

\[
\alpha_i\sim
\begin{cases}
N\{\log(0.003),0.6^2\}, & \text{ordinary},\\
N\{\log(0.00015),0.6^2\}, & \text{cryptic}.
\end{cases}
\]

The fitted candidate retains its single normal species-effect distribution.
This scenario therefore tests whether an unmodelled 20% low-detectability
guild induces undercoverage, excessive richness, or catastrophic tail
extrapolation. Guild assignment uses the dedicated simulation stream at
`simulation_seed + 103` and is independent of effort.

### Seasonal availability

All 25 members retain the matched base-rate distribution, but each is assigned
one of four balanced seasonal phases using `simulation_seed + 104`. A species
has 13 active occasions in each 52-occasion cycle. Its rate multiplier is 3.4
during the active quarter and 0.2 otherwise:

\[
0.25(3.4)+0.75(0.2)=1.
\]

Thus the annual mean exposure is preserved while instantaneous rates vary
seventeen-fold. The fitted model incorrectly assumes a constant rate across
training and forecast occasions. This tests temporary availability and
seasonal transfer without changing the finite-pool richness truth.

## Effort and pairing

The effort template contains only weekly active-day totals. It was derived
from the pinned Judbury operational table and nine-station mapping at
`camtrap-workflow` commit `dbe656e3e423e4c89028965bf79dfa18a441a49a`.
The raw operational and mapping source hashes remain those frozen in the Task 1
contract. The template contains 9 cameras by 153 occasions, 7,644 active
camera-days, and 266 zero-effort camera-weeks. It contains no detections,
species records, coordinates, or model results.

For each duration, 30 admissible contiguous blocks were selected without
replacement using fixed selection seeds 300304 and 300326. A block contains
the complete training and four-week forecast periods. Scenarios with the same
duration and replicate use the same effort block and simulation seed. This
common-random-number design separates scenario effects from avoidable Monte
Carlo noise.

The simulation seed is

\[
430000000+100T+r,
\]

where (T\) is the training duration and (r\) is the replicate. The existing
frozen RNG kinds and separate membership, species, camera, and detection
streams remain in force. Low-, intermediate-, and high-richness memberships
must be nested prefixes of the same seeded candidate permutation. The two
misspecified scenarios share the intermediate-richness members and base random
effects before their declared transformations are applied.

Effort is fixed before detections are generated and is therefore independent
of detection outcomes. Forecasts condition on the realised effort in the
four-occasion future part of the block, exactly as in Goal003 Task 1.

## Scheduled methods and sensitivities

Every dataset receives all deterministic baselines. The 840 Stan fits are:

| Fit role | Datasets | Fits |
| --- | ---: | ---: |
| FlexiRich primary | 300 | 300 |
| Community occupancy primary | 300 | 300 |
| Three one-factor FlexiRich prior sensitivities | 60 matched datasets each | 180 |
| FlexiRich broader-pool sensitivity | 60 matched datasets | 60 |

The sensitivity subset is replicates 1–10 of every matched richness-by-duration
cell. The prior profiles are exactly `membership_regularised`,
`mu_alpha_wide`, and `tail_wide` from Task 3. The broader-pool sensitivity adds
56 declared all-zero non-members to reach the frozen 106-species broader pool;
it does not regenerate detections or alter the original 50 candidates.

Primary and rescue sampler profiles, terminal-clean thresholds, and the sole
rescue rule are unchanged. Fit seeds are unique and follow the formula encoded
and checked in `R/goal003_task4_manifest.R`; a rescue uses the existing
`fit_seed + 1` rule. One-time compilation and environment restoration are not
included in per-fit runtime.

## Scores and fixed denominators

For every dataset, retain true richness, training-observed richness, realised
future-first identities, and the number of new species in the forecast block.
Synthetic truth is passed only to scoring and oracles, never into fitted model
inputs.

Richness scoring includes:

- posterior mean absolute error for every genuine point estimate;
- ranked probability score for observed richness, the lower-bound-conditioned
  prior, occupancy, and FlexiRich;
- equal-tailed 90% interval coverage and width for genuine PMFs; and
- exact logarithmic score, allowing infinity when a method assigns zero mass
  to truth rather than applying a probability floor.

Future-discovery scoring includes count RPS for observed richness, occupancy,
and FlexiRich; expected-count absolute error for every eligible method; and the
mean candidate-level Brier score across species unseen in training. A Brier
score is structurally missing when no candidates remain unseen, and that case
is counted explicitly.

Terminal-non-clean Stan fits produce no estimate or forecast. They count as
noncoverage in the fixed scheduled coverage denominator and remain explicit in
fit-failure summaries. Point and proper scores are computed only when a genuine
prediction exists, with both scheduled and scored denominators reported.
Pairwise RPS comparisons use identical terminal-clean pairs. FlexiRich must
meet the 5% guardrail separately against observed richness and occupancy and
must strictly improve on the lower-bound prior; this is at least as strong as
comparison only with whichever non-FlexiRich method happens to rank best.

## Screening gates

The Goal003 gates are operationalised as follows:

1. All support, likelihood, truth-isolation, PMF, scoring, manifest, and output
   oracles pass.
2. At least 285 of the 300 primary FlexiRich fits are terminal clean and at
   least 27 of 30 are clean in every scenario-by-duration cell.
3. In matched data, fixed-denominator 90% coverage is 0.85–0.95 within each
   duration when richness cells are pooled and at least 0.80 in each of the six
   cells.
4. Across matched terminal-clean datasets, median FlexiRich posterior-mean
   absolute error does not exceed observed richness; its richness RPS is lower
   than the lower-bound prior and no more than 5% worse than observed richness.
   On FlexiRich–occupancy clean pairs, it is no more than 5% worse than
   occupancy.
5. Each of the four misspecified cells has fixed-denominator coverage of at
   least 0.75 and median absolute error no more than 10% above observed
   richness.
6. Among terminal-clean primary FlexiRich fits, fewer than 1% have posterior
   mean richness at least 12.5 species above truth.
7. For every frozen sensitivity, terminal-clean matched pairs have median
   absolute posterior-mean shift no greater than one species and no individual
   shift greater than three species.
8. On terminal-clean FlexiRich–occupancy pairs, the median runtime ratio is at
   most three. FlexiRich median terminal-clean runtime is at most 300 seconds
   and its 95th percentile is below 900 seconds. Rescue time is included;
   compilation is excluded.

Any failed gate stops progression. A missing or non-clean fit is never replaced
with a new replicate. A demonstrated implementation failure may be repaired
only as a new committed run with preserved evidence from this attempt.

## Screening output contract

The future runner must write, beneath one non-overwriting ignored directory:

- exact copies of all four manifests and their hashes;
- `dataset-status.csv` with all 300 scheduled datasets;
- `fit-status.csv` with all 840 scheduled fits, attempts, diagnostics, and
  elapsed time;
- richness and discovery score tables with scheduled and scored denominators;
- sensitivity-pair and cell-summary tables;
- one gate table containing every numerator, denominator, threshold, and
  pass/fail result;
- Git commit, R and package versions, CmdStan version, source hashes, RNG kinds,
  host and concurrency metadata; and
- `completion-status.txt`, written last.

Per-fit sampler CSVs and compact fitted summaries are retained. The runner may
resume only manifest rows that have no output after an interrupted process; it
must never overwrite or silently omit an existing row. The initial remote
screen will use no more than eight concurrent four-chain fits on `deep-server`.

## Prespecified extension after screening

Passing all screening gates authorises, but does not itself execute, a final
calibration. Before that run, a new committed manifest will add replicates
31–100 to every scenario-by-duration cell, giving 100 total per cell, and
replicates 11–30 to each matched sensitivity subset, giving 30 paired
replicates per matched cell. The additional effort blocks and seeds must be
frozen before launch. The same gates apply to the combined results.

This sample size is fixed here before screening results are available. A pass
does not permit changing scenarios, thresholds, methods, or replicate counts;
a failure does not permit searching for a more favourable grid.

## Immediate stopping point

The execution layer is now implemented without launching the screen. It
contains deterministic matched, cryptic-guild, and seasonal generators;
truth-separated canonical model inputs; all frozen deterministic baselines;
exact richness, discovery-count, and identity scoring; fixed-denominator gate
evaluation; and a bounded eight-worker runner.

Each dataset and fit is written through a staging directory and published only
after `completion-status.txt` exists. Published rows are never overwritten.
Interrupted staging is preserved and stops a resume for diagnosis rather than
silently repeating or replacing the row. Final aggregation checks all 300
dataset IDs, all 840 fit IDs, all baseline rows, and all score rows before the
screening gates are evaluated. Scheduled and scored denominators, package and
source versions, sampler diagnostics, compact fit summaries, and per-fit
CmdStan CSVs are retained.

Ten local scenario-by-duration hand cases, the truth-isolation checks, scoring
oracles, gate hand cases, interruption semantics, and aggregate row oracle pass
without executing Stan fits or reading empirical outcomes. The next step is to
commit this exact runner, push it, and launch
`scripts/run_goal003_task4_screen.R` in a named `deep-server` tmux session.
