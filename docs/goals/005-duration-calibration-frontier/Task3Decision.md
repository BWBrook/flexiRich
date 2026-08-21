# Goal005 Task 3 — class-calibration frontier decision

Date: 2026-08-21
Decision: **12 weeks / F3 selected for the prespecified transfer stress**

## Evidence and integrity

The frozen Task 3 screen ran on `deep-server` at Git commit
`da53f6c88e4ffc6028cf5297fd3d6d77a29e5763`. It generated all 108 scheduled
synthetic datasets and completed all 756 scheduled Stan fits. The process
exited normally and both completion records state `TASK3_COMPLETE`.

The canonical remote output remains at:

`/home/bwbrook/papers/flexiRich/outputs/goal005/task3-class-frontier-v1`

Compact results, manifests, metadata, source hashes, and the run log were
copied to the corresponding ignored local output path. All 23 copied artifacts
match their remote counterparts byte for byte, and all 59 recorded source-file
hashes match the frozen checkout. The run used no Judbury detections, future
species discoveries, Huon Ridge data, or unpublished coordinates.

Of the 756 fits, 753 were terminal clean: 727 on the primary sampler attempt
and 26 after the frozen rescue attempt. There were no divergences or
maximum-treedepth hits. The three terminal non-clean fits were all low-richness
`F5` fits. Their only terminal defects were marginal R-hat failures, with one
also below the bulk-ESS threshold; they did not show divergent or
maximum-treedepth behaviour.

An independent implementation replayed all 357 frozen gate rows and all three
precision frontiers from the compact pair evidence. Every metric, denominator,
threshold, pass/fail value, and frontier decision matched. Its completion
record states `AUDIT_PASS`. The load-bearing SHA-256 hashes are:

- gates: `bc3a54f52857cbb7c37740ccfa11423830be49d10168015bab6f8798c402bda2`;
- paired contrasts: `4aeee041e78300976d43a7c92a634fc2749f2112a20895eb43bfc8711ecb0355`;
- frontier: `dcb6c2bfdfdbf659e776513791d7c2caacf5e137cb962db1a36140db4cbe4df8`.

## Frozen result

Each duration passed its fresh exact-class anchor and at least five finite
calibration levels under the conservative prefix rule.

| Duration | C0 gates | Coarsest passing precision | Nominal 95% factor | Decision |
| ---: | ---: | --- | ---: | --- |
| 12 weeks | 17/17 | F3 | 3 | `CLASS_FRONTIER_FOUND` |
| 16 weeks | 17/17 | F5 | 5 | `CLASS_FRONTIER_FOUND` |
| 26 weeks | 17/17 | F5 | 5 | `CLASS_FRONTIER_FOUND` |

At the selected 12-week/F3 cell, all 36 fits were terminal clean. Median
high-minus-low posterior-mean separation was 28.967 species; absolute median
bias was 2.300, 2.042, and 1.020 species across richness 10, 25, and 40;
pooled RPS improved 67.8% over the no-data prior; all three fixed-denominator
coverage cells passed; median 90% interval width was 14 species; and no fit was
catastrophic. Median absolute error was 2.95 species and the maximum was 8.62.

The 12-week effort blocks were deliberately heterogeneous, ranging from 125
to 756 active camera-days and four to nine contributing cameras. At 16 and 26
weeks, active-camera-day ranges were 265--1008 and 748--1591, respectively.

## Interpreting the F3 boundary

The 12-week/F5 cell passed nine of its 17 rows. Its failure was caused by two
low-richness fits being classified terminal non-clean. This directly failed
the total-clean, low-richness-clean, and catastrophic-fit rows, and reduced
the eligible denominators below their frozen minima for separation,
low-richness bias, pooled and low-richness RPS gain, and interval width.
The available point metrics themselves remained on the acceptable side of
their numerical thresholds.

Consequently, the screen supports F3 as a conservative operational frontier,
but does not establish that factor-five calibration is scientifically
inadequate at 12 weeks. The apparent edge is partly a sampler-reliability
boundary under the frozen fitting protocol. Re-running or relaxing the cell
after seeing this outcome would compromise the prespecified screen, so the
recorded frontier remains F3. The continuous F5 evidence is retained for
transparent interpretation rather than converted into a pass.

Longer deployments substantially weakened the calibration requirement. The
16-week/F5 cell passed despite one terminal non-clean fit, and all 36
26-week/F5 fits were clean. Median absolute errors at F5 were 2.09 and 1.81
species at 16 and 26 weeks, compared with 2.84 among the 34 clean 12-week fits.

## Decision

Task 3 is complete and independently audited. It provides a finite
class-calibration frontier at all three retained durations and therefore does
not trigger candidate-specific calibration work.

Under the outcome-independent Task 4 contract, the next experiment is fixed
at the smallest passing duration and its coarsest passing finite precision:
12 weeks and F3. Using new synthetic streams, Task 4 will compare unbiased
external class calibration with common downward and upward class-location
shifts of `log(1.25)`. All three profiles must meet the unchanged 17-row
standard, and each biased profile must meet the frozen paired richness-shift
limits. No empirical outcome enters that stress.
