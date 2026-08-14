# Goal 003 decision — stop the minimal candidate

Date: 2026-08-14  
Decision: **SCREEN_STOP**

## Evidence boundary

The frozen Task 4 screen ran at Git commit
`0cf94097513629c72e14f99b94e2222818112ef3` on `deep-server`. It generated all
300 scheduled synthetic datasets and completed all 840 scheduled Stan fits.
The canonical output is retained without modification at:

`/home/bwbrook/papers/flexiRich/outputs/goal003/task4-screen-v1`

The run used no Judbury detections, future species outcomes, or Huon Ridge
data. Its top-level completion record is `SCREEN_STOP`; its approximately
74 GB of per-fit sampler output remains the immutable source evidence.

## Denominator correction

The original gate evaluator computed catastrophic overestimation from the 179
terminal-clean matched fits. The frozen contract specified all terminal-clean
primary FlexiRich fits. Commit
`d06e41fa192c7c09848945b6acb7f5186a260949` repaired that population and added
a regression test covering a misspecified-scenario fit.

The corrected decision was replayed from hash-locked aggregate tables, without
rerunning or replacing any Stan fit. It is retained separately at:

`/home/bwbrook/papers/flexiRich/outputs/goal003/task4-screen-v1-decision-correction-v1`

Only the declared gate changed: catastrophic overestimation moved from 2/179
(1.12%, fail) to 2/299 (0.67%, pass). Every other gate value was identical.
The SHA-256 of `corrected-screening-gates.csv` is
`d023456f330bc0f83d4a6e7e6e345a97e175ee58fb630a9ed59f96c29c394ac9`.

## What worked

- All execution, likelihood, support, truth-isolation, PMF, scoring, manifest,
  and output oracles passed.
- 299/300 primary FlexiRich fits were terminal clean. The sole non-clean fit
  missed the strict R-hat threshold narrowly (1.01017 versus 1.01), without a
  divergence or maximum-treedepth hit.
- Median terminal-clean runtime was 11.67 seconds and the 95th percentile was
  61.36 seconds. FlexiRich was faster than the occupancy comparator on the
  frozen median runtime ratio.
- Across matched terminal-clean datasets, median absolute error and richness
  ranked probability score substantially improved on observed richness, the
  lower-bound-conditioned prior, and the occupancy comparator.
- All four misspecification accuracy and coverage cells cleared their frozen
  lower gates.
- The widened species-tail prior had a maximum richness shift of 2.01 species
  and passed its sensitivity gates.

## What failed

Five corrected gates failed:

| Gate | Observed | Required |
| --- | ---: | ---: |
| pooled matched 26-week coverage | 88/90 = 97.8% | 85–95% |
| matched-high four-week coverage | 23/30 = 76.7% | at least 80% |
| maximum shift, regularised membership prior | 3.07 species | at most 3 |
| maximum shift, wider mean encounter-rate prior | 5.93 species | at most 3 |
| maximum shift, broader 106-species pool | 17.54 species | at most 3 |

The important failure is not the marginal 26-week overcoverage. In the
four-week matched-high cell, median posterior-mean error was -12.36 species and
all six clean interval misses placed truth above the upper interval limit. The
broader-pool sensitivity had a median absolute shift of 5.10 species at four
weeks, compared with 0.10 at 26 weeks. The wider mean encounter-rate prior was
also influential primarily at four weeks.

The two large overestimates that remain diagnostically important occurred in
the matched-low four-week cell: posterior means of 24.56 and 25.48 for truth
10. They no longer fail the correctly specified aggregate gate, but together
with the matched-high underestimation they show shrinkage toward a
prior/pool-determined middle.

## Scientific interpretation

The minimal candidate is computationally sound and often accurate, but a
four-week camera record does not reliably separate reserve-grid membership
from low encounter rate under its exchangeable membership model. Sparse data
allow the common membership probability, the encounter-rate distribution, and
the chosen candidate-pool boundary to substitute for one another. Low true
richness can be pulled upward, high true richness downward, and adding
plausible but undetected candidates can materially alter the estimate.

This is weak identification and candidate-pool dependence, not conventional
machine-learning overfitting. The 26-week results show that additional data
largely resolve the ambiguity, but Goal003 explicitly required useful
four-week inference.

## Decision and protected next step

The current minimal candidate is stopped. Goal003 Tasks 5 and 6 are not run,
and empirical Judbury outcomes remain unopened. Thresholds or priors will not
be adjusted to make the completed screen pass.

The benchmark remains valuable. A successor may use the Goal003 screen as
development evidence only, must address membership on a count scale or through
externally fixed candidate strata, and must demonstrate improvement over its
own prior-only prediction. Any claim of success requires a newly frozen,
held-out synthetic screen before empirical access.
