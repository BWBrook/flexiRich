# Goal005 Task 1 — calibration estimands and oracle-screen design

Status: proposed; no Goal005 simulation or Stan fit run
Prepared: 2026-08-20

## Task decision

Task 1 asks whether the planned information levels and paired duration design
cleanly distinguish three possibilities:

1. duration alone can make a correctly specified class model sufficient;
2. a duration requires candidate-specific encounter-rate calibration; or
3. no amount of rate calibration can make that duration decision-ready while
   target-grid camera effects and membership remain unknown.

The output is a frozen Task 2 design, not a richness result.

## Why Goal004's prior profiles are not a calibration frontier

Goal004 used

\[
\alpha_i\sim N(m_{h_i},s_h^2),
\]

with class location \(m_{h_i}\) and predictive spread \(s_h=1\) fixed before
fitting. The `rate_lower` and `rate_higher` profiles shifted both class
locations; they diagnosed sensitivity to rate location. Reducing \(s_h\), by
contrast, would claim that species are biologically more homogeneous. It would
not merely state that an external calibration estimated the same heterogeneous
distribution more precisely.

Goal005 therefore represents external information at the level it estimates.

## Calibration targets

### Level C0 — class-distribution oracle

The model is given the generator's exact routine and occasional class
locations and exact biological predictive spread:

\[
m_h=m_h^{\mathrm{true}},\qquad s_h=s_h^{\mathrm{true}}=1.
\]

Candidate rates remain latent draws from their class distributions. C0 is the
best possible class-only calibration, not an implementable claim of knowing
each species' encounter rate. The aligned Goal004 generator and primary model
formed one version of this condition; Goal005 repeats it with new paired
duration evidence and a common decision standard.

### Level I0 — candidate-rate oracle

The model is given every candidate's true latent log encounter rate
\(\alpha_i\). Membership and target-grid camera effects remain unknown and are
estimated from the target history. This is the information ceiling for what
encounter-rate calibration alone could achieve; external calibration would not
normally be exact.

I0 deliberately does not fix target-camera effects. A calibration transferred
from another array cannot reveal the placement effect of a new target camera.
Failure under I0 therefore means that better rate information alone is not a
credible rescue for that duration.

### Later class-level calibration

If C0 passes at a duration, Task 3 may replace its known class locations with
external calibration summaries. Repeated synthetic calibrations generate

\[
\widehat m_h\mid m_h^{\mathrm{true}}
  \sim N(m_h^{\mathrm{true}},\tau_h^2).
\]

The matching analysis uses

\[
m_h\sim N(\widehat m_h,\tau_h^2),
\qquad
\alpha_i\sim N(m_{h_i},s_h^2).
\]

This separation makes clear which relationship generates independent evidence
and which propagates that evidence into the target analysis. The biological
spread \(s_h\) is not shrunk when \(\tau_h\) becomes smaller. The initial
frontier will fix the externally supported spread at one because Goal004 found
rate location, not the modest spread perturbation, to be load-bearing.

### Later candidate-specific calibration

If I0 passes but C0 fails, Task 3 may generate candidate-specific external
summaries as

\[
\widehat\alpha_i\mid\alpha_i
  \sim N(\alpha_i,\tau_i^2).
\]

The analysis retains the candidate's class-predictive distribution and adds
the matching external calibration likelihood,

\[
\alpha_i\sim N(m_{h_i},s_h^2),
\qquad
\widehat\alpha_i\mid\alpha_i\sim N(\alpha_i,\tau_i^2).
\]

Thus candidate calibration adds information rather than silently replacing
the externally reviewed class evidence. The estimates are generated
independently of target membership and detections. Their precision is reported
both as \(\tau\) and as the factor \(\exp(1.96\tau)\) multiplying or dividing
the median rate at the limits of a nominal 95% interval.

This Gaussian calibration abstraction answers how precise rate information
must be. A later task must test whether a real calibration model and finite
camera effort can attain that precision.

## Shared ecological model

Both oracle paths retain:

- the reviewed 50-candidate core pool: 44 routine and six occasional;
- true richness 10, 25, and 40, with 9/1, 22/3, and 35/5
  routine/occasional members;
- nested membership permutations within a replicate;
- routine median rate 0.002, occasional median rate 0.0005, and log-rate
  predictive SD one;
- nine centred `Normal(0, 0.35)` target-camera effects;
- the exact effort hazard and seven-day incidence likelihood; and
- the broad `Beta(1,1)` membership fraction prior.

Task 2 is deliberately aligned and best-case. Weak class signal, label errors,
seasonality, and transfer bias cannot establish an information ceiling and are
deferred to later bounded tests.

## Paired duration and effort design

The five training durations are 4, 8, 12, 16, and 26 occasions. Each synthetic
base history is generated for a common 26-week window and sliced into nested
prefixes. Within a start/richness replicate, all durations therefore share
membership, candidate rates, camera effects, calibration information, and
detection uniforms for their overlapping observations.

Twelve common starts are selected using effort only:

- the ten frozen Goal004 26-week effort-quantile starts;
- start 31, the exact severe firmware-outage block retained in Goal004; and
- start 1, a full-effort 4--16-week reference block.

No Goal004 detection or fitted outcome informed this union. All starts leave
room for 26 training occasions and the four subsequent occasions retained by
the source template, although prospective discovery is not a Goal005 gate.

Exact training active camera-days are:

| Start | 4 weeks | 8 weeks | 12 weeks | 16 weeks | 26 weeks |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 252 | 504 | 756 | 1008 | 1395 |
| 13 | 252 | 493 | 609 | 667 | 748 |
| 25 | 58 | 97 | 125 | 265 | 884 |
| 31 | 28 | 56 | 308 | 560 | 1021 |
| 39 | 252 | 504 | 745 | 916 | 1160 |
| 49 | 207 | 335 | 393 | 530 | 1009 |
| 58 | 46 | 218 | 410 | 606 | 1065 |
| 72 | 196 | 386 | 557 | 733 | 1293 |
| 83 | 162 | 386 | 610 | 839 | 1440 |
| 91 | 224 | 453 | 705 | 943 | 1525 |
| 100 | 252 | 482 | 706 | 953 | 1513 |
| 124 | 224 | 457 | 709 | 961 | 1591 |

At four weeks the blocks contain 28--252 active camera-days and 1--9 active
cameras. At eight weeks they contain 56--504 active camera-days and 1--9
active cameras. All 16- and 26-week blocks include all nine cameras. These
extremes are retained: a nominal survey duration is not treated as equivalent
to realised spatial effort.

The design contains 12 paired random streams, each producing three nested-
richness histories, for 36 truth histories and 180 nested duration slices.
Task 2 schedules C0 and I0 only, for 360 primary fits. No Goal003, occupancy,
nested-fringe, discovery, or large sensitivity grid is repeated: Goal004
already answered those questions sufficiently for this feasibility screen.

## Common decision standard

A minimum defensible duration must meet one standard; shorter durations do not
receive looser accuracy gates. The proposed Task 2 criteria reuse the scale of
Goal004's 26-week requirements.

For each information level and duration:

1. at least 35/36 fits are terminal clean and every richness cell has at least
   11/12 clean;
2. median paired high-minus-low posterior-mean separation is at least 27 of
   the true 30 species;
3. absolute median signed bias is at most three species in every richness
   cell;
4. pooled mean richness RPS improves by at least 40% over the matching no-data
   membership prior, and no richness cell has negative mean gain;
5. fixed-denominator 90% interval coverage is at least 10/12 in every richness
   cell;
6. median 90% interval width is at most 25 species; and
7. fewer than two of the 36 scheduled fits are terminal non-clean or have
   absolute posterior-mean error of at least 12.5 species.

Terminal-non-clean fits count as noncoverage and as catastrophic outcomes in
their fixed scheduled denominators; they are never silently omitted from a
decision cell. Proper-score means use identical available pairs, with the
separate cleanliness rule preventing selective omission.

The richness prior remains the same discrete uniform distribution under both
oracles because encounter-rate information supplies no membership evidence.
The model must improve over that prior rather than merely recover a plausible
point estimate.

Results are also reported continuously against duration, active camera-days,
and active-camera count. Passing a calendar duration does not imply that its
one-camera outage window is adequate; the output must expose any effort-
specific failure.

## Task 2 pruning rule

For each duration:

- if I0 fails, the duration is closed to Task 3 because no independently
  derived rate calibration can exceed that information ceiling;
- if I0 passes and C0 fails, only candidate-specific calibration is eligible;
- if C0 passes, class-level calibration is tested first; candidate-specific
  calibration is unnecessary unless the later class-precision frontier fails;
  and
- if a duration passes only after excluding a prespecified low-effort block,
  it is not declared generally adequate. A separate minimum-effort condition
  may be reported, but the failure remains visible.

The 4/8/12-week cells are the practical decision focus. Sixteen and 26 weeks
bound the transition and prevent a false conclusion that failure at 12 weeks
means the method never becomes informative.

## Implementation boundary

Task 2 should add only:

- a Goal005 manifest/generator that reuses the existing effort, candidate, and
  Goal004 scoring contracts;
- one minimal fixed-candidate-rate Stan model or an exactly equivalent tested
  likelihood path for I0;
- the C0 path through the existing Goal004 model; and
- focused manifest, common-random-number, likelihood-bridge, scoring, and gate
  tests plus one genuine small smoke.

It must not copy the Goal004 execution framework into a parallel workflow,
introduce adaptive duration selection, or add empirical-data readers. The
heavy 360-fit screen runs on `deep-server` only after code, manifests, seeds,
gates, and outputs are committed and pushed.

## Task 1 acceptance

Task 1 is ready to close when the collaborator approves:

1. the C0/I0 distinction and later class-versus-candidate calibration branches;
2. the 4/8/12 primary durations and 16/26 anchors;
3. the twelve paired effort starts and 360-fit ceiling screen;
4. the common seven-part decision standard; and
5. the pruning rule that prevents calibration work on an oracle-infeasible
   duration.

Until then, no Goal005 simulation seed, Stan model, or decision grid is frozen
or run.
