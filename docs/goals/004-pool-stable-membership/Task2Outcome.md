# Goal004 Task 2 — prior-only calibration outcome

Status: complete; suitable to proceed to Task 3 design
Completed: 2026-08-14

## Frozen run

The deterministic prior-only calibration completed at Git commit
`2cc12b463a7cd7b0df4e3198074563d5a9f9e21a` with seed 40042 and 50,000
common-random-number draws. It used the reviewed candidate worksheet and exact
Judbury operational effort, but no species detections, fitted models or
empirical outcomes.

Outputs are in `outputs/goal004/task2-prior-only-v1`. All nine numerical and
structural invariants passed. Output readback and recorded SHA-256 hashes were
independently verified after the run.

## Primary prior behaviour

The approved `Beta(1,1)` membership prior gives the exact intended discrete
uniform distribution over core richness 0 through 50: mean 25, SD 14.72 and
90% interval 2–48. The `Beta(2,2)` sensitivity retains mean 25 but narrows the
90% interval to 6–44. Thus the primary prior remains deliberately weak rather
than encoding an expert richness total.

For the lower-median four-week window (224 active camera-days, followed by 247
days in the forecast month), the primary prior predicts:

| Quantity | Mean | Median | 90% interval |
| --- | ---: | ---: | ---: |
| species observed in training | 10.83 | 10 | 1–23 |
| first detected in the following month | 4.57 | 4 | 0–11 |

Conditional on membership, the mean prior probability of at least one
training detection is 0.467 for a routine candidate and 0.187 for an
occasional candidate. These means exceed the elicited median-candidate anchors
because they average over the right tail of the lognormal rate distribution
and camera effects; the class ordering is retained clearly.

For the lower-median 26-week window (1,210 active camera-days, followed by 224
days), expected observed richness is 20.41 (90% interval 2–40), and expected
new discoveries in the following month fall to 0.715 (interval 0–3). The
minimum four-week effort window is a genuine outage period: it contains only
28 training camera-days but is followed by 252 forecast camera-days. Its high
expected subsequent discovery count is therefore a feature of the exact
effort history, not a nesting failure.

## Sensitivity interpretation

Halving or doubling encounter-rate medians is consequential, shifting expected
observed richness by at most about 4.25 species across the six representative
windows. This confirms that the rate prior is load-bearing and must remain a
mandatory sensitivity in all later evaluation.

The other one-factor perturbations are comparatively modest on the mean scale:
the widest shifts in expected observed richness are 0.64 species for class
blur and 0.64 for the wider log-rate spread. `Beta(2,2)` changes expected
observed richness by at most 0.02 species because it preserves mean membership,
but materially reduces predictive dispersion. It must therefore be compared
using full distributions and proper scores, not means alone.

## Broader-pool diagnostic

The 56-species fringe contributes prior mean richness 5.01, taking broader-pool
mean richness from 25.0 to 30.0. Yet its expected observed contribution is only
0.54 species after the lower-median four-week window and 1.76 after 26 weeks.
The camera data will consequently have weak leverage over most of this fringe.
This is the intended demonstration that broader-pool totals are substantially
prior supplied; they remain a labelled sensitivity and cannot replace the
50-species primary estimand.

## Decision

Accept the frozen Task 2 priors as the development contract for the minimal
Goal004 candidate. This is not evidence that FlexiRich succeeds: it establishes
the no-data forecasts that every later posterior must outperform.

Task 3 should now implement one analytically marginalised, 50-candidate model
with fixed routine/occasional predictive priors, the existing effort hazard and
sum-zero camera effects. It must expose the same five prior sensitivities and
retain the Task 2 PMFs as mandatory scoring baselines. No flexible tail,
learned encounter hyperdistribution, spatial layer or empirical Judbury fit is
authorised at this stage.
