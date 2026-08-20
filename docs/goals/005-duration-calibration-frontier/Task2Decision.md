# Goal005 Task 2 — information-ceiling decision

Date: 2026-08-20
Decision: **4/8 weeks closed; 12/16/26 weeks eligible for class calibration**

## Evidence and integrity

The frozen Task 2 screen ran on `deep-server` at Git commit
`b453df19d3764bb7a4efecbb5aecb9deb41e195a`. It generated all 180 scheduled
synthetic datasets and completed all 360 scheduled Stan fits. The process
exited normally and both completion records state `TASK2_COMPLETE`.

The canonical remote output remains at:

`/home/bwbrook/papers/flexiRich/outputs/goal005/task2-information-ceiling-v1`

Compact results, manifests, metadata, hashes, and the run log were copied to
the corresponding ignored local output path. The copied evidence matches the
remote files byte for byte. All 51 recorded source-file hashes and all six
manifest hashes were independently reconciled. The run used no Judbury
detections, empirical future discoveries, Huon Ridge data, or unpublished
coordinates.

All 360 fits were terminal clean: 340 were clean on the primary sampler attempt
and 20 after the frozen rescue attempt. There were no divergences or maximum-
treedepth hits. The evidence table contains exactly 180 datasets, 360 fit
statuses, 360 fit scores, and 180 matching no-data prior scores.

An independent implementation replayed all 170 frozen gate rows from the
compact score and pair tables. Every metric, denominator, threshold, and
pass/fail value matched. Its completion record states `AUDIT_PASS`. The
load-bearing SHA-256 hashes are:

- gates: `a8d070480153048cb7eb5a8351f0a7f9f8cd91e171025d4e56fb3daa44234e54`;
- paired contrasts: `1a05c8f08915b8d4c1342e369e0866fcf5c990c33fa8173f317f54cb81f1c701`;
- Task 3 pruning: `473dce0cb934abc0bda7d4881e6c4772c1ace2f13e28555c2df975288b3db0ea`.

## Frozen result

`C0` is the exact class-distribution oracle; `I0` is the stronger oracle that
knows each candidate's true encounter rate while still estimating membership
and target-camera effects.

| Duration | C0 gates | I0 gates | Task 3 decision |
| ---: | ---: | ---: | --- |
| 4 weeks | 13/17 | 13/17 | `CLOSED_ORACLE_FAIL` |
| 8 weeks | 14/17 | 16/17 | `CLOSED_ORACLE_FAIL` |
| 12 weeks | 17/17 | 17/17 | `CLASS_CALIBRATION_ELIGIBLE` |
| 16 weeks | 17/17 | 17/17 | `CLASS_CALIBRATION_ELIGIBLE` |
| 26 weeks | 17/17 | 17/17 | `CLASS_CALIBRATION_ELIGIBLE` |

The failed rows were:

| Oracle | Duration | Criterion | Observed | Required |
| --- | ---: | --- | ---: | ---: |
| C0 | 4 | high-minus-low separation | 24.519 | at least 27 |
| C0 | 4 | absolute median bias, richness 25 | 4.471 | at most 3 |
| C0 | 4 | RPS gain, richness 25 | -0.162 | at least 0 |
| C0 | 4 | catastrophic or non-clean fits | 3/36 | fewer than 2/36 |
| C0 | 8 | high-minus-low separation | 24.684 | at least 27 |
| C0 | 8 | absolute median bias, richness 40 | 4.185 | at most 3 |
| C0 | 8 | catastrophic or non-clean fits | 2/36 | fewer than 2/36 |
| I0 | 4 | high-minus-low separation | 25.354 | at least 27 |
| I0 | 4 | absolute median bias, richness 25 | 5.943 | at most 3 |
| I0 | 4 | RPS gain, richness 25 | -0.058 | at least 0 |
| I0 | 4 | catastrophic or non-clean fits | 3/36 | fewer than 2/36 |
| I0 | 8 | high-minus-low separation | 26.808 | at least 27 |

At 12 weeks, C0's median high-minus-low separation was 27.034 species,
absolute median bias was 0.391, 0.226, and 1.746 species across the three
richness cells, and pooled RPS improved 69.2% over the no-data prior. All three
coverage cells passed, median 90% interval width was 12 species, and no fit was
catastrophic. I0 also passed all criteria, with median interval width 11.5 and
no catastrophic fit.

Median absolute error declined with duration under both oracles:

| Duration | C0 median / maximum | I0 median / maximum |
| ---: | ---: | ---: |
| 4 weeks | 4.06 / 18.17 | 3.57 / 19.58 |
| 8 weeks | 2.64 / 17.26 | 2.59 / 18.24 |
| 12 weeks | 2.30 / 10.65 | 1.81 / 12.10 |
| 16 weeks | 2.00 / 8.65 | 1.48 / 6.94 |
| 26 weeks | 1.94 / 6.55 | 1.83 / 5.36 |

## Scientific interpretation

Exact candidate encounter rates did not make four- or eight-week inference
meet the common standard. Under this frozen design, independently calibrated
rates therefore cannot rescue those durations by themselves. This is stronger
than the Goal004 prior-sensitivity result: the failure persists at the
information ceiling while target-camera effects and membership remain unknown.

The eight-week I0 cell missed only the separation gate, by 0.192 species. It is
scientifically close to the threshold, but it remains a failure under the
prespecified rule. Reopening it now would make the calibration grid responsive
to the observed outcome. Its continuous result remains available for later
interpretation, but Task 3 does not tune against it.

Twelve weeks is the shortest duration that passed under both oracles, and C0's
success means class-level calibration should be tested before candidate-level
calibration. This is a useful positive result, but not a universal claim that
any twelve-week survey is sufficient. The effort blocks ranged from 125 to 756
active camera-days and four to nine active cameras. The largest twelve-week I0
error, 12.10 species, occurred in the 125-day, four-camera block and sat just
inside the catastrophic threshold. Realised effort and spatial coverage must
remain visible alongside calendar duration.

C0's twelve-week separation passed by only 0.034 species. Task 3 therefore
requires fresh synthetic streams and retains an oracle anchor. A failure of
that fresh anchor will be treated as evidence that the twelve-week transition
is not stable, not as permission to relax the gate.

## Decision

Task 2 is complete and independently audited. Four and eight weeks are closed
to Goal005 calibration-frontier work. Task 3 proceeds first with class-level
calibration at 12, 16, and 26 weeks, using new synthetic seeds and the unchanged
decision standard. Candidate-specific calibration remains deferred unless the
finite class-calibration frontier fails despite a reproducible C0 pass.

