# Goal004 Task 4 — bounded development simulation design

Status: proposed and frozen for collaborator review; implementation is not yet authorised
Prepared: 2026-08-14

## Decision question

Does the fixed-class Goal004 model learn enough from four-week camera histories
to improve on its own external-evidence prior, avoid the middle-seeking failure
seen in Goal003, and preserve the 50-candidate core posterior when a separate
rare fringe is added?

Task 4 is a development screen. Its scenarios and thresholds use the completed
Goal003 screen and the Goal004 analytical work as development evidence. A pass
would justify freezing a genuinely new Task 5 screen; it would not be
confirmatory evidence and would not authorise empirical Judbury fitting.

## Protected evidence boundary

Task 4 may use:

- the reviewed candidate labels in `config/goal003_candidate_pool.csv`;
- the operational-effort template in
  `config/goal003_task4_effort_template.csv`;
- the frozen priors in `config/goal004_task2_priors.csv`;
- Goal004 Tasks 1--3, including their prior-only and implementation checks; and
- the aggregate Goal003 Task 4 decision as development evidence.

It may not use Judbury detections, empirical future discoveries, Huon Ridge
data, unpublished coordinates, Task 5 seeds, or a Task 5 outcome. Synthetic
truth remains separate from every fitted object and is available only to
simulation oracles and scoring.

The three tracked inputs above currently have SHA-256 hashes:

| Input | SHA-256 |
| --- | --- |
| Goal003 candidate pool | `60c8900c1904bafa34340e8ea7e2a44fc819836f76746fc7ee80c484166608db` |
| Goal003 weekly effort template | `d46655701ba0427264fc40a4a568b2ee350a34e9683b1cf1daa3d67ceeaeede9` |
| Goal004 prior profiles | `cebff55cb261aedb5ce3a2980764273ef151a1ac741ac6e911383a7db23df3fb` |

Implementation must reject a hash mismatch rather than silently rebuilding or
substituting an input.

## Scientific hypotheses

The design tests three linked claims.

1. **Short-window learning:** under correctly reviewed encounter classes,
   four-week detections move richness, membership, and discovery predictions
   in the right direction and improve proper scores over the matching no-data
   prior.
2. **Graceful misspecification:** weaker or partly wrong encounter labels may
   reduce that gain, but should not create severe miscalibration or make the
   posterior materially worse than the prior it started from.
3. **Core pool stability:** adding a separately parameterised, mostly
   undetectable fringe must not materially change inference about the original
   50 candidates through the shared camera-effect layer.

The first claim is primary. The second and third are guardrails against
obtaining apparent accuracy only when the elicitation is exactly correct or
the candidate boundary is held fixed.

## Primary synthetic grid

The grid contains three true core-richness levels, three encounter-class
fidelity regimes, two training durations, and ten replicates:

\[
3\ \text{richness levels}\times
3\ \text{fidelity regimes}\times
2\ \text{durations}\times
10\ \text{replicates}=180\ \text{datasets}.
\]

Every training window is followed by the next four seven-day occasions. The
candidate universe is the reviewed 50-species core: 44 candidates labelled
`routine` and six labelled `occasional`.

### True membership

True richness is 10, 25, or 40. Membership is stratified to prevent incidental
class imbalance:

| True core richness | Routine members | Occasional members |
| ---: | ---: | ---: |
| 10 | 9 | 1 |
| 25 | 22 | 3 |
| 40 | 35 | 5 |

For each replicate, separate seeded permutations are made within the routine
and occasional candidate lists. The three richness levels are prefixes of
those same permutations, so the low pool is nested within the intermediate
pool and the intermediate pool within the high pool.

Membership prevalence is therefore approximately equal across encounter
classes. The external class label supplies information about encounter rate,
not a hidden prior preference for which species belongs to the reserve pool.

### Encounter-class fidelity

All regimes use candidate-specific lognormal encounter rates and retain the
same latent standard-Normal draw for a candidate within a paired replicate.

| Regime | True rate model | Purpose |
| --- | --- | --- |
| `aligned` | routine median 0.002, occasional median 0.0005, log SD 1 | Matches the frozen primary model |
| `weak_signal` | routine median 0.001840375301250, occasional median 0.000920187650625, log SD 1 | Retains the correct ordering but reduces the median ratio from four to two |
| `ten_percent_flipped` | aligned rates, but exactly five seeded candidates use the opposite class component | Makes 10% of the reviewed labels wrong while fitted labels remain unchanged |

The weak-signal locations preserve the aligned regime's candidate-weighted
mean log rate:

\[
\bar m=\frac{44\log(0.002)+6\log(0.0005)}{50}
=-6.380963421756578.
\]

This changes class contrast without changing the overall log-rate centre. In
the flipped regime, the five candidates are selected without replacement from
all 50 using a stream independent of membership and detection. Their model
labels are never rewritten.

A completely uninformative class label and seasonal availability are reserved
for the newly frozen Task 5 screen. Adding them here would enlarge development
without changing the immediate decision about the leading model.

### Camera and observation process

Nine camera effects are generated as independent `Normal(0, 0.35)` values and
then centred to sum exactly to zero. Candidate-camera-occasion detections use
the same effort hazard as the fitted models:

\[
P(y_{ijk}=1\mid g_i=1)
=1-\exp\{-E_{jk}\exp(\alpha_i+b_j)\}.
\]

Zero-effort cells are unsampled and stored as missing, never as
non-detections. Event counts and individual abundance are not simulated.

## Frozen effort blocks

Effort is selected without reference to synthetic detections. For each
training duration $T\in\{4,26\}$, enumerate every contiguous $T+4$ occasion
block in the 153-week effort template and calculate training active
camera-days. Define ten type-7 empirical-quantile targets at probabilities
$0,1/9,\ldots,1$.

Targets are processed from lowest to highest. For each target, select the
unused start with the closest training effort. If several starts tie, select
the one whose start is furthest from the starts already chosen; an unresolved
tie goes to the earliest start. This secondary rule spreads blocks across the
record rather than selecting adjacent weeks from a long full-effort plateau.

Replicate number is the target order plus one. The exact frozen result is:

| Duration | Replicate | Start | End | Training days | Future days |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 4 | 1 | 31 | 38 | 28 | 28 |
| 4 | 2 | 55 | 62 | 82 | 73 |
| 4 | 3 | 80 | 87 | 171 | 176 |
| 4 | 4 | 69 | 76 | 196 | 196 |
| 4 | 5 | 126 | 133 | 224 | 247 |
| 4 | 6 | 108 | 115 | 224 | 247 |
| 4 | 7 | 97 | 104 | 243 | 252 |
| 4 | 8 | 1 | 8 | 252 | 252 |
| 4 | 9 | 146 | 153 | 252 | 239 |
| 4 | 10 | 15 | 22 | 252 | 175 |
| 26 | 1 | 13 | 42 | 748 | 252 |
| 26 | 2 | 25 | 54 | 884 | 171 |
| 26 | 3 | 49 | 78 | 1009 | 190 |
| 26 | 4 | 58 | 87 | 1065 | 176 |
| 26 | 5 | 39 | 68 | 1160 | 185 |
| 26 | 6 | 72 | 101 | 1293 | 250 |
| 26 | 7 | 83 | 112 | 1440 | 228 |
| 26 | 8 | 100 | 129 | 1513 | 224 |
| 26 | 9 | 91 | 120 | 1525 | 224 |
| 26 | 10 | 124 | 153 | 1591 | 239 |

The first four-week block deliberately represents the firmware-failure
outage. Duration alone is never substituted for realised camera-days.

## Common random numbers and seeds

Within a duration and replicate, all richness and fidelity regimes share:

- the two class-specific membership permutations;
- candidate latent Normal values;
- raw camera-effect values;
- candidate selection uniforms for the flipped-label transformation; and
- candidate-camera-occasion detection uniforms.

The dataset seed is

\[
440000000+100T+r,
\]

where $T$ is training occasions and $r$ is replicate. Scenario transformations
use fixed stream offsets, not a changed master seed. This pairing makes
high-minus-low and model-misspecification comparisons substantially less
noisy.

Fit seeds are unique and follow

\[
540000000+1000000p+10000s+100T+r,
\]

where $p$ is a frozen method/profile code and $s$ is scenario order. A rescue
uses the existing `fit_seed + 1` rule. The implementation tranche must
materialise and exact-check scenario, dataset, and fit manifests before any
batch is launched.

## Methods and scheduled fits

Every dataset receives deterministic observed-richness, Chao2, iChao2, and
iNEXT summaries where eligible. These are descriptive comparators; methods
without a genuine PMF are not assigned invented proper scores.

The 750 scheduled Stan fits are:

| Role | Eligible datasets | Fits |
| --- | ---: | ---: |
| Goal004 primary fixed-class model | all 180 | 180 |
| stopped Goal003 primary model, as a development benchmark | all 180 | 180 |
| conventional community-occupancy comparator | all 180 | 180 |
| all five Goal004 one-factor sensitivities | 30 aligned datasets, replicates 1--5 | 150 |
| Goal004 `class_blur` sensitivity | 30 flipped datasets, replicates 1--5 | 30 |
| Goal004 independent-fringe nested model | 30 aligned datasets, replicates 1--5 | 30 |
| **Total** |  | **750** |

The five one-factor sensitivities are exactly `rate_lower`, `rate_higher`,
`spread_wider`, `class_blur`, and `membership_regularised` from the frozen
Task 2 profile table. No sensitivity is tuned or added after results appear.

All methods retain the existing four-chain primary and one-rescue sampler
contract, diagnostic thresholds, exact PMF calculations, and terminal-status
semantics. A failed fit is not replaced with another synthetic replicate.

## Matching no-data prior forecasts

The Goal004 primary model is compared with its own prior, not merely with
observed richness or another fitted model.

For each of the 20 effort blocks and each fitted Goal004 profile:

- realised core richness uses the exact beta-binomial PMF;
- candidate membership probability is the corresponding prior mean, 0.5 for
  every frozen core profile;
- the joint distribution of training-observed richness and four-week future
  first discoveries uses 50,000 common-random-number prior draws; and
- candidate future-first probabilities are retained for Brier scoring.

These calculations reuse the frozen Task 2 seed 40042 and stream definitions.
They must reproduce the six Task 2 representative-window forecasts within
their recorded Monte Carlo error before extension to the 20 Task 4 blocks.

The no-data discovery forecast is made before seeing a synthetic training
history. It is therefore an unconditional forecast over training and future
detections for the fixed effort block. The posterior forecast receives the
training history. Improvement measures information gained from those data;
it does not imply that the external prior was uninformative.

Sensitivity fits are scored against the prior forecast from their own profile.
The primary candidate is scored only against the primary prior.

## Independent-fringe nested diagnostic

The nested diagnostic appends the 56 reviewed broader-pool candidates to the
same 30 aligned core histories. They are fixed synthetic non-members and hence
have all-zero histories. This deliberately isolates the effect of changing
the declared candidate boundary; it does not claim that the actual JCR fringe
is empty.

Core and fringe membership parameters are independent:

\[
R_c/50\sim\operatorname{Beta}(1,1),
\qquad
R_f\sim\operatorname{TruncatedExponential}(\text{scale}=5;0,56),
\]

with membership probabilities $R_c/50$ and $R_f/56$. The core retains 44
routine and six occasional encounter priors. The fringe retains the frozen
three routine and 53 rare candidates; rare rates have median 0.0002 per active
camera-day and log SD 1.

The two strata share the same exact sum-zero camera effects but have no shared
membership or encounter hyperparameter. Membership is analytically
marginalised within each stratum. The implementation must provide an
independent R/Stan bridge and a no-data prior-concordance check before the
nested fits become batch-eligible.

Primary nested outputs are the core richness PMF and candidate probabilities.
Fringe and total richness are reported separately as prior-sensitivity
diagnostics. Accuracy of the broader total is not a Goal004 success claim.

## Scores and denominators

### Core richness

For every genuine PMF, retain posterior mean, signed and absolute error, ranked
probability score (RPS), logarithmic score, equal-tailed 90% interval coverage,
and interval width. Relative RPS gain over a comparator is

\[
1-\frac{\operatorname{mean}(\mathrm{RPS}_{model})}
        {\operatorname{mean}(\mathrm{RPS}_{comparator})}
\]

on identical available pairs. Prior-only, Goal003, and occupancy comparisons
each use their own pair table. Observed richness and classical estimators are
compared by signed and absolute error only unless they supply a valid PMF.

### Candidate membership

Retain Brier scores over all candidates and, separately, over candidates not
detected during training. The latter is primary because it tests inference
about the missing pool rather than rewarding the model for assigning
probability one to a detected species. The matching no-data membership Brier
uses probability 0.5.

### Future discovery

Retain count RPS and absolute error for the number of candidates first detected
in the next four weeks. Retain candidate-level Brier score over candidates
unseen in training for future-first identity. The no-data prior is scored from
its joint prior-predictive count PMF and candidate probabilities.

### Failures

A terminal-non-clean Stan fit supplies no posterior score and counts as
noncoverage in fixed scheduled coverage denominators. All tables record both
scheduled and scored denominators. Proper-score comparisons use only identical
terminal-clean pairs, while the separate cleanliness gate prevents selective
omission from making a method appear better.

## Prespecified development gates

These thresholds are intentionally decision-oriented rather than claims of
universal calibration. The Goal003 middle-seeking error, the Goal004 Task 1
analytical screen, the Task 2 prior predictions, and the true 30-species
high-minus-low contrast set their scale.

### G01 — integrity

All manifest, source-hash, effort, truth-isolation, likelihood, support, PMF,
scoring, and output readback oracles pass. The runner produces exactly 180
datasets and 750 scheduled fits and never accesses a protected empirical
source.

### G02 — computational cleanliness

- at least 171/180 Goal004 primary fits are terminal clean;
- every primary fidelity-by-richness-by-duration cell has at least 8/10 clean;
- at least 171/180 Goal003 and 171/180 occupancy comparator fits are clean;
- each 30-fit Goal004 sensitivity profile has at least 29 clean, while the
  60-fit `class_blur` family has at least 57; and
- at least 29/30 nested fits are clean.

### G03 — aligned four-week learning

Among paired aligned fits:

- the median paired high-minus-low posterior-mean separation is at least 20
  species;
- the absolute median signed bias is at most 7.5 species in every richness
  cell;
- pooled mean richness RPS improves by at least 20% over the no-data prior and
  no richness cell has negative mean gain;
- fixed-denominator 90% coverage is at least 8/10 in every richness cell; and
- median interval width is at most 40 species.

### G04 — aligned 26-week learning

The corresponding 26-week requirements are:

- high-minus-low separation at least 27 species;
- absolute median signed bias at most three species in every richness cell;
- pooled richness-RPS gain at least 40%, with no negative-gain cell;
- fixed-denominator coverage at least 8/10 in every cell; and
- median interval width at most 25 species.

There is no upper coverage gate in this ten-replicate development screen;
interval-width limits prevent vacuous overcoverage. Task 5 will use a larger,
newly frozen calibration denominator.

### G05 — weaker and partly wrong classes

For both `weak_signal` and `ten_percent_flipped`:

- paired high-minus-low separation is at least 15 species at four weeks and 24
  at 26 weeks;
- fixed-denominator coverage is at least 7/10 in every richness-duration cell;
- within each fidelity-duration pool, mean richness RPS is no more than 5%
  worse than the no-data prior; and
- fewer than 6/120 scheduled fits are terminal non-clean or have absolute
  posterior-mean error at least 12.5 species.

The last rule counts non-clean fits conservatively rather than omitting them
from the catastrophic-error denominator.

### G06 — unseen-candidate membership

On candidates unseen during training:

- aligned pooled Brier score improves over 0.25 by at least 5% at four weeks
  and 15% at 26 weeks; and
- in each weak/flipped fidelity-duration pool, mean Brier is no more than 5%
  worse than 0.25.

All-candidate Brier is reported but does not determine this gate.

### G07 — prospective discovery

In aligned data, separately for each duration:

- mean future-discovery count RPS is strictly lower than the no-data prior;
  and
- mean unseen-candidate future-identity Brier is at least 5% lower than the
  no-data prior.

### G08 — value beyond existing models

On identical aligned clean pairs:

- at four weeks, Goal004 mean richness RPS is at least 10% lower than Goal003
  and no more than 5% higher than occupancy; and
- at 26 weeks, Goal004 mean richness RPS is no more than 5% higher than either
  Goal003 or occupancy.

This gate asks whether fixed expert classes justify a successor model where
Goal003 was weakest, without demanding superiority when 26 weeks already make
the simpler models informative.

### G09 — nested-pool stability

For core-only versus nested fits, separately by duration:

- median absolute shift in posterior mean core richness is at most 0.5 species;
- median total variation between core richness PMFs is at most 0.05; and
- no paired shift exceeds two species or total variation exceeds 0.15.

Fringe posterior movement and total-richness change are reported but are not
used to redefine primary success.

### G10 — prior sensitivity

For aligned replicates 1--5:

- `spread_wider`, `class_blur`, and `membership_regularised` each have median
  absolute posterior-mean shift at most one species within each duration and
  no shift above three;
- `rate_lower` and `rate_higher` each have median absolute shift at most 3.5
  species within each duration and no shift above eight;
- both rate profiles preserve at least 15 species of paired four-week
  high-minus-low separation and retain positive pooled four-week RPS gain over
  their own prior; and
- on flipped-label datasets, `class_blur` mean RPS is no more than 5% worse
  than the primary fixed-class fit within either duration.

The wider limits for rate location are prespecified because Task 2 established
that encounter-rate location is load-bearing. Hiding that fact behind the same
three-species limit as minor prior perturbations would be misleading.

### G11 — runtime

Goal004 terminal-clean primary fits have median runtime at most 300 seconds and
95th percentile below 900 seconds. On paired clean fits, the median runtime
ratio to occupancy is at most three. Rescue time is included; one-time
compilation and prior-only prediction are excluded.

## Decision rule

- `TASK4_PASS`: every G01--G11 gate passes. This authorises Task 5 design only.
- `TASK4_STOP`: any scientific, calibration, robustness, pool-stability, or
  runtime gate fails. The candidate pauses for collaborator review; thresholds
  and priors are not tuned against these same datasets.
- `TASK4_EXECUTION_STOP`: the run is incomplete or a demonstrated
  implementation, infrastructure, or evidence-writing defect prevents a valid
  scientific decision. Evidence is preserved and a repair requires a new
  commit and non-overwriting run directory.

No failed replicate is replaced. No gate changes after the first valid result.

## Lean implementation and output contract

The implementation should extend the proven Goal003 generator, scorer,
manifest, and interruption-safe runner patterns without copying them into a
second framework. Goal004-specific code is limited to class-aware truth,
matching prior forecasts, the nested model, and the gates above. No new ledger,
generic workflow engine, compatibility wrapper, or package API is introduced.

Before a heavy run, the implementation tranche must locally pass:

- exact manifest row/count/seed/effort tests;
- truth-isolation and common-random-number tests;
- Goal004 primary and nested Stan/R likelihood bridges;
- prior-only regression against the six Task 2 anchor windows;
- scoring and gate tests with small hand-calculated fixtures;
- one genuinely small end-to-end smoke; and
- the complete repository unit suite and `renv` status.

The remote run writes to one non-overwriting ignored directory and records:

- exact manifest copies, source/input hashes, Git commit, seed rules, R,
  package, and CmdStan versions;
- dataset and fit status for every scheduled row;
- compact per-fit diagnostics, posterior summaries, PMFs, candidate
  probabilities, proper scores, pair tables, and every gate numerator and
  denominator;
- core-versus-nested comparison and prior-sensitivity tables; and
- a completion record written last.

Raw CmdStan CSVs are compressed after their compact artefacts pass readback;
they remain remote evidence and are not committed to Git. This is materially
leaner than creating a second archive or reporting layer while retaining the
draw-level evidence needed to inspect unexpected fits.

The batch runs on `deep-server` in a named `tmux` session from a clean, pushed
commit, with at most eight concurrent four-chain fits. Once the process is
verified to have started and produced genuine progress, monitoring returns to
the collaborator under the repository's heavy-compute handoff rule.

## Approval gate

Implementation requires collaborator approval of:

1. the 180-dataset, 750-fit development grid;
2. the class-fidelity generators and effort-stratified ten-replicate design;
3. the independent-fringe diagnostic rather than a primary 106-species claim;
4. G01--G11 exactly as prespecified; and
5. the rule that a pass advances only to a new held-out Task 5 design.
