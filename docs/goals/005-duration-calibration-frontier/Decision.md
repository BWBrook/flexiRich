# Goal005 decision — conditional duration/calibration frontier only

Date: 2026-08-24
Decision: **CONDITIONAL_FRONTIER_ONLY**

## Decision surface

Goal005 used new protected synthetic evidence to separate deployment duration
from independently supplied encounter-rate information. All heavy runs
completed at frozen, pushed commits and were independently replayed from
compact evidence. Judbury detections remained unopened and Huon Ridge remained
untouched.

| Duration | Information ceiling | Finite class-calibration result | Independent transfer-stage result | Goal005 interpretation |
| ---: | --- | --- | --- | --- |
| 4 weeks | C0 and I0 failed | pruned | not run | closed even with exact candidate rates |
| 8 weeks | C0 and I0 failed | pruned | not run | closed even with exact candidate rates |
| 12 weeks | C0 and I0 passed | F3 passed in Task 3 | fresh unbiased F3 failed | conditional transition, not stable frontier |
| 16 weeks | C0 and I0 passed | F5 passed in Task 3 | not selected by frozen stress rule | conditional positive evidence |
| 26 weeks | C0 and I0 passed | F5 passed in Task 3 | not selected by frozen stress rule | conditional positive evidence |

`C0` knows the true encounter-class distributions; `I0` knows every
candidate's true encounter rate. Their failures at four and eight weeks show
that encounter-rate calibration alone cannot make those snapshot durations
meet the common richness standard while membership and target-camera effects
remain unknown.

At 12 weeks, both information ceilings passed and Task 3 found an F3 class-
calibration frontier. The selected cell then failed its fresh unbiased
replication before transfer robustness could be claimed. Its 36 fits were
computationally clean, but intermediate-richness bias and coverage, high-low
separation, and catastrophic-error frequency failed. All direct paired effects
of the imposed 25% transfer bias were small enough to pass, making fresh-stream
instability under F3 more important than the incremental common bias.

Sixteen- and 26-week F5 cells performed well in Task 3, but the frozen Task 4
rule tested only the smallest passing duration. They therefore remain useful
conditional evidence, not transfer-audited operational frontiers.

## Final scientific judgement

`FRONTIER_FOUND` is not supported: no practically selected cell both met the
common standard and survived the prespecified fresh transfer stage.

`NO_RATE_CALIBRATION_FRONTIER` is also too strong: the 12-, 16-, and 26-week
information ceilings passed, and finite class calibration produced accurate
inference in Task 3. The model can learn richness when duration and rate
information align sufficiently well.

The supported Goal005 decision is therefore `CONDITIONAL_FRONTIER_ONLY`.
Finite-pool point estimates must remain explicitly conditional on the supplied
encounter-rate calibration and realised survey effort. Twelve weeks should not
be advertised as a generally adequate minimum. Longer deployments are more
promising, but Goal005 did not establish a shortest robust duration.

This Goal-level category must be reported with the separate Task 4 qualifier
`UNBIASED_REPLICATION_FAIL`; it is not the milder `TRANSFER_SENSITIVE` branch.

This is an identifiability result, not a Stan failure or ordinary overfitting.
It is also a useful boundary: four- and eight-week point estimation is closed
for this model, while 12 weeks marks an unstable transition and longer windows
retain conditional promise.

## Protected Goal006 handoff

Goal006 should now ask whether independent real data can provide encounter-rate
calibration precise and portable enough to support prospective Judbury
inference. It should not begin by treating 12-week/F3 as a validated estimator.

The high-value empirical design is to:

1. derive every calibration quantity from data strictly outside the target
   short window, with no future-detection or long-pool membership leakage;
2. quantify the achieved uncertainty and transfer error rather than assigning
   a nominal F-level by assumption;
3. evaluate 12-, 16-, and 26-week target windows prospectively against the
   reviewed long-duration detectable-use reference, retaining four and eight
   weeks only as prespecified negative benchmarks;
4. report observed richness, nonparametric lower bounds, and calibration-
   conditional posterior envelopes alongside any point estimate; and
5. freeze a method and decision rule before Huon Ridge is opened in Goal007.

Goal006 may use the Judbury effort and detection record under that leakage
contract. Huon Ridge remains private external validation and cannot be used to
choose the calibration method, duration, or thresholds.

The next goal may test a more conservative calibration target such as F2, or
longer deployment cells, but these are new development hypotheses rather than
post hoc repairs to Goal005.
