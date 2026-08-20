# Goal005 Task 3 — bounded class-calibration frontier

Status: proposed; awaiting collaborator approval
Prepared: 2026-08-20

## Decision question

For the 12-, 16-, and 26-week durations retained by Task 2, how imprecise can
an independently estimated encounter-class location be while richness still
meets the unchanged Goal005 decision standard?

Task 3 tests class-level calibration first because the exact class-distribution
oracle passed at every retained duration. It does not schedule a
candidate-specific grid unless this cheaper and more transferable information
source proves inadequate.

## External calibration model

For encounter class \(h\), independent calibration generates

\[
\widehat m_h=m_h^{\mathrm{true}}+\tau z_h,
\qquad z_h\sim N(0,1).
\]

The target analysis receives only \(\widehat m_h\) and \(\tau\), and uses

\[
m_h\sim N(\widehat m_h,\tau^2),
\qquad
\alpha_i\sim N(m_{h_i},1).
\]

The biological between-species log-rate SD remains one. Better calibration
narrows uncertainty about each class location; it does not claim that species
within a class become more homogeneous. The target history may update the two
class locations jointly with candidate rates, membership, and camera effects.

The routine and occasional classes receive independent standardised
calibration errors but the same nominal precision. This reduces the first
frontier to one interpretable axis. No order constraint is imposed on their
estimated locations: reversal under very weak calibration is part of the
information loss rather than something the target model silently repairs.

## Precision grid

Precision is reported as the factor \(F=\exp\{q_{0.975}\tau\}\). Conditional
on the Gaussian abstraction, the nominal 95% interval for a median encounter
rate is the external point estimate divided and multiplied by \(F\).

| Level | 95% multiplicative factor \(F\) | Log-scale SD \(\tau\) | Role |
| --- | ---: | ---: | --- |
| C0 | 1 (exact) | 0 | fresh oracle anchor |
| F1.10 | 1.10 | 0.048629 | near-oracle diagnostic |
| F1.25 | 1.25 | 0.113851 | very precise calibration |
| F1.50 | 1.50 | 0.206874 | precise calibration |
| F2 | 2 | 0.353653 | moderate calibration |
| F3 | 3 | 0.560527 | weak calibration |
| F5 | 5 | 0.821157 | broad anchor |

The near-oracle F1.10 level is retained because the Task 2 twelve-week C0
separation gate passed narrowly. The grid is not adaptively refined after
seeing results. The reported frontier is the coarsest passing level among
these prespecified factors, not a continuously estimated threshold.

## Fresh paired evidence

Task 3 retains the Task 2 ecological scenarios, twelve effort-only start
blocks, and 12/16/26-week nested prefixes, but generates new ecological and
detection streams. Within each replicate:

- membership, candidate rates, camera effects, and overlapping detection
  uniforms are paired across richness, duration, and precision;
- one independent pair \((z_{routine},z_{occasional})\) is reused across all
  precision levels, scaled by the corresponding \(\tau\); and
- calibration information is independent of target membership and target
  detections.

The proposed frozen seeds are:

- ecological/detection stream: `660000000 + replicate`;
- external-calibration stream: `670000000 + replicate`;
- fit stream: `760000000 + 1000000 * precision_code +
  10000 * scenario_order + 100 * train_occasions + replicate`.

`precision_code` is 1--7 in the table order from C0 to F5. All streams use
R's `Mersenne-Twister`, `Inversion`, and `Rejection` RNG kinds, matching the
frozen Task 2 convention.

The design contains 3 richness scenarios × 12 paired streams × 3 durations =
108 synthetic datasets and seven fits per dataset, or 756 fits. C0 is rerun on
the fresh streams rather than borrowed from Task 2. This is large enough to
test whether the twelve-week transition repeats, but remains a bounded screen
rather than a general robustness factorial.

## Minimal fitted model

C0 reuses the proven Goal004 fixed-class model. Positive-\(\tau\) levels require
one minimal Stan variant that adds only two latent class locations and their
external Gaussian priors. It retains:

- the 50 named core candidates and fixed reviewed class labels;
- the broad uniform membership-count prior;
- candidate log rates with biological SD one;
- exact active-camera-day hazard and seven-day incidence likelihood;
- sum-zero target-camera effects; and
- exact posterior Poisson-binomial richness calculations.

The fitted adapter may receive candidate labels, \(\widehat m_h\), and \(\tau\).
It must reject true class locations, true candidate rates, membership, and true
richness. Calibration summaries and their hashes become explicit frozen input
artifacts. Judbury detections and Huon Ridge remain inaccessible.

## Unchanged gates and frontier rule

Each duration × precision cell uses the same 17 frozen rows and seven
scientific requirements as Task 2. There is no duration-specific relaxation.

Precision levels are ordered from C0 through F5. A finite level is accepted
only if:

1. the fresh C0 cell passes;
2. that finite cell passes all 17 rows; and
3. every more precise preceding level also passes.

The third condition is a conservative prefix rule: an isolated pass at a weak
precision cannot define the frontier if a stronger paired level failed. The
coarsest accepted factor is the class-calibration frontier for that duration.

The duration outcomes are:

- `CLASS_FRONTIER_FOUND` — at least one finite precision level passes the
  prefix rule;
- `ORACLE_ONLY` — C0 passes but no finite level passes; or
- `FRESH_ORACLE_FAIL` — the independent C0 anchor fails, so the Task 2 pass is
  not stable enough to support a precision frontier.

Twelve weeks is the practical primary duration; 16 and 26 weeks show how much
calibration precision longer deployments can trade away. A passing duration is
always reported with its distribution of active camera-days and active-camera
counts. It is not converted into a claim that all windows of that calendar
length are adequate.

If no finite class level passes at a duration where C0 passes, the I0 result
leaves a candidate-specific route scientifically possible. That route requires
a separate bounded design and is not silently added to this grid.

## Task 4 stress frozen before Task 3 outcomes

To prevent a successful Task 3 cell from choosing its own robustness test, the
proposed transfer stress is fixed now. At the smallest duration with a finite
class frontier, Task 4 will use the coarsest passing precision and new seeds to
compare:

- an unbiased external calibration;
- both class location estimates shifted down by \(\log(1.25)\); and
- both shifted up by \(\log(1.25)\).

The two shifts correspond to common multiplicative transfer biases of 0.8 and
1.25 in median encounter rate. Both biased profiles must meet the unchanged
17-row standard. In addition, relative to the paired unbiased profile, each
must have median absolute posterior-mean richness shift at most 3.5 species
and maximum shift at most 8 species, reusing the Goal004 decision scale. If no
finite Task 3 frontier exists, this stress is not run.

The exact Task 4 fit manifest and fresh seeds will be frozen only after Task 3
selects the cell; its bias magnitude and acceptance rules will not change.

## Implementation and verification boundary

Task 3 implementation should add only:

- one calibration manifest and deterministic generator;
- one two-location Stan model plus a thin adapter;
- reuse of the existing simulation, scoring, gate, publication, and sampler
  machinery; and
- focused tests for the Gaussian calibration generator, common random
  numbers, truth isolation, the Stan/R likelihood bridge, the C0 limit, grid
  completeness, and prefix decision rule.

One reduced local two-level smoke must fit C0 and one positive-\(tau\) level
cleanly before the frozen heavy run. The 756-fit grid runs on `deep-server`
only from a clean pushed commit. Raw sampler artifacts remain remote; compact
decision evidence is copied and independently replayed locally.

Task 3 stops before the heavy run if the finite-calibration model does not
reduce to the existing class model as \(\tau\) approaches zero, target fitting
can access truth, the prior-only bridge disagrees, or the additional class
locations introduce unresolved sampling pathology.
