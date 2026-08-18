# Goal004 decision — stop the fixed-class candidate

Date: 2026-08-18
Decision: **TASK4_STOP**

## Evidence boundary

The frozen Task 4 development screen ran at Git commit
`d9e1833ddd1fee9d69b87ddb9573a2ab827d2c4d` on `deep-server`. It generated all
180 scheduled synthetic datasets and completed all 750 scheduled Stan fits.
The process exited normally with code zero. The canonical output is retained
without modification at:

`/home/bwbrook/papers/flexiRich/outputs/goal004/task4-development-v1`

The complete remote output is about 16 GB. Its compact 1.3 MB result tables,
manifests, metadata, source hashes, and matching-prior artefacts were copied to
the corresponding ignored local output directory and verified byte-for-byte
against the remote evidence.

The run used no Judbury detections, empirical future discoveries, Huon Ridge
data, or unpublished coordinates. Both completion records state
`TASK4_STOP`, all 180 dataset and 750 fit artefacts are complete, and no
execution-stop record exists.

Re-evaluating G01--G11 from the compact tables and frozen committed source
exactly reproduced all 128 criterion rows and their pass/fail states. Sixteen
criteria failed across G02, G03, G05, G07, and G10. Direct arithmetic from the
score and pair tables independently reproduced the failed values; no result-
writing, key, denominator, or decision-precedence defect was found.
The SHA-256 of `development-gates.csv` is
`1713b55f65fee236dcbefb844f62e4540f3ba36e20bd57bf99a94fcdc228498a`.

## Computational outcome

Goal004 itself was computationally clean and fast:

- all 180 primary Goal004 fits, all 180 Goal003 fits, all 30 nested fits, and
  all 180 sensitivity fits were terminal clean;
- median Goal004 runtime was 6.08 seconds and its 95th percentile was 11.71
  seconds, well inside the respective 300- and 900-second gates; and
- Goal004's median paired runtime ratio to occupancy was 0.089.

The occupancy comparator supplied 168/180 terminal-clean fits instead of the
required 171. Its 12 non-clean fits had no divergences or maximum-treedepth
hits, but failed the frozen R-hat or effective-sample-size limits after rescue.
This G02 failure is retained. It is not the reason Goal004 stops: the candidate
independently failed four scientific gate groups.

## Failed criteria

| Gate | Criterion | Observed | Required |
| --- | --- | ---: | ---: |
| G02 | clean occupancy fits | 168/180 | at least 171/180 |
| G03 | aligned four-week coverage, richness 25 | 7/10 | at least 8/10 |
| G03 | aligned four-week RPS gain, richness 25 | -30.16% | at least 0% |
| G05 | catastrophic-error or non-clean misspecified fits | 9/120 | fewer than 6/120 |
| G07 | four-week future-identity Brier gain | 2.44% | at least 5% |
| G07 | 26-week future-identity Brier gain | 2.70% | at least 5% |
| G10 | regularised-membership median four-week shift | 1.24 species | at most 1 |
| G10 | regularised-membership maximum four-week shift | 3.74 species | at most 3 |
| G10 | lower-rate median four-week shift | 7.97 species | at most 3.5 |
| G10 | lower-rate maximum four-week shift | 9.82 species | at most 8 |
| G10 | lower-rate median 26-week shift | 5.80 species | at most 3.5 |
| G10 | higher-rate median four-week shift | 5.30 species | at most 3.5 |
| G10 | higher-rate maximum four-week shift | 10.35 species | at most 8 |
| G10 | higher-rate median 26-week shift | 3.59 species | at most 3.5 |
| G10 | higher-rate four-week high-minus-low separation | 14.45 species | at least 15 |
| G10 | higher-rate four-week RPS gain over its own prior | -0.48% | greater than 0% |

The G05 count contains nine catastrophic Goal004 errors; all relevant
Goal004 fits were clean. Every catastrophe occurred at four weeks. Four were
associated with the deliberately retained 28-camera-day firmware-outage
block, but five occurred with 224 or 252 active camera-days. Unequal effort
therefore amplifies the problem but does not explain it away.

The aligned four-week data showed the same instability diagnostically: five
of 30 fits had absolute posterior-mean error of at least 12.5 species. For the
intermediate-richness cell, mean model RPS was 5.53 versus 4.25 for the
matching no-data prior. The camera history therefore worsened the proper score
in the cell centred on the prior mean, even though pooled four-week RPS gain
was positive.

## What worked

Goal004 materially improved several aspects of the problem.

1. **Candidate-pool stability was repaired.** Adding 56 all-zero fringe
   candidates under an independent membership stratum shifted core posterior
   mean richness by a median 0.066 species at four weeks and 0.030 at 26 weeks;
   the maximum shifts were 0.642 and 0.101. All nested total-variation gates
   passed comfortably.
2. **The externally reviewed classes contained information.** Aligned
   unseen-candidate membership Brier scores improved over the 0.25 prior by
   9.69% at four weeks and 41.81% at 26 weeks. The class-blur and wider-spread
   sensitivities passed their stability gates.
3. **Twenty-six-week inference was accurate under the primary rate prior.**
   All aligned coverage cells were 10/10, absolute median signed bias was at
   most 1.56 species, median high-minus-low separation was 29.92 species, and
   pooled richness RPS improved 84.86% over the matching prior.
4. **Goal004 improved on the existing fitted models.** On aligned clean pairs,
   its richness-RPS ratios to Goal003 and occupancy were respectively 0.692
   and 0.767 at four weeks, and 0.634 and 0.258 at 26 weeks.
5. **Prospective discovery counts improved.** Future-discovery count RPS was
   13% lower than the no-data prior at both durations, although identity-level
   gains were too small to pass G07.

These are substantive advances over Goal003. In particular, the core/fringe
construction solves the declared-pool instability rather than hiding it.

## Scientific interpretation

The remaining failure is the encounter-rate--richness axis. Fixed external
classes help identify which unseen candidates are more plausible, but the
absolute rate location within those classes remains load-bearing. Halving the
routine and occasional prior medians increased inferred richness by median
amounts of 7.97 species at four weeks and 5.80 at 26 weeks. Doubling them
decreased richness by 5.30 and 3.59 species. These are prespecified, plausible
one-factor sensitivities, not post hoc stress tests.

Four-week data cannot consistently distinguish many low-encounter members from
fewer high-encounter members under this formulation. More effort greatly
improves recovery under a fixed rate prior, but even 26-week point estimates
remain consequentially dependent on external rate calibration. This is weak
identification, not a Stan failure, ordinary predictive overfitting, or the
candidate-pool dependence seen in Goal003.

The model is therefore useful as a demonstration of how external ecological
knowledge and independent pool strata can improve inference, but it is not yet
a defensible general four-week richness estimator.

## Decision and protected next step

Goal004 Tasks 5 and 6 are not run. The failed development scenarios are not
used to tune priors, thresholds, or encounter classes, and empirical Judbury
outcomes remain unopened. The Goal004 implementation and immutable evidence
are retained as a successful computational model with a failed scientific
development decision.

A scientifically distinct successor should begin with a feasibility question,
not another prior adjustment: **how precise must independent encounter-rate
calibration be before four-week richness becomes decision-stable, and can a
real external or strictly held-out camera dataset supply that precision?** A
new goal could compare externally trained species- or class-level rate priors,
explicit sensitivity-envelope reporting, and a longer minimum survey duration
using new simulation seeds. If defensible independent calibration cannot make
the four-week estimand stable, the project should stop presenting it as a
point-estimation problem and instead report lower bounds or prior-conditional
richness envelopes.
