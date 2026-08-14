# Goal004 Task 2 — core-pool strata and prior elicitation

Status: approved and frozen for prior-only calibration
Prepared: 2026-08-14

## Estimand decision

Following the Task 1 `CORE_ONLY` result, the collaborator selected the
50-species camera-accessible pool as the primary Goal004 estimand. The target is
the number of these named candidates belonging to the site's camera-accessible
gamma pool over the defined reference period, inferred from a shorter camera
window under the model's stationarity assumptions.

This is not total vertebrate gamma richness. The 56 additional broader-pool
candidates remain a transparent sensitivity showing what a camera-only model
cannot learn about rare or nearly invisible species. Their prior-supplied
contribution must never be merged silently into the primary four-week estimate.

## Evidence boundary

Task 2 may use only:

- the completed expert review in `config/goal003_candidate_pool.csv`;
- the frozen Judbury operational-effort template, without detections;
- the Task 1 analytical outputs; and
- a separately recorded elicitation completed before Judbury outcomes are
  opened.

Huon Ridge remains reserved for private external validation and is not used to
calibrate these priors. The completed Goal003 fits are development evidence,
not a source of posterior-derived prior values.

## Deterministic candidate mapping

The primary-pool mapping is derived directly from the reviewed worksheet; no
second species list is created.

| Rule | Stratum | Candidates |
| --- | --- | ---: |
| `primary_pool == "include"` | membership: `core` | 50 |
| core and `camera_encounter_class == "routine"` | encounter: `routine` | 44 |
| core and `camera_encounter_class == "occasional"` | encounter: `occasional` | 6 |

The routine class contains 28 birds and 16 mammals. The occasional class
contains five birds and one mammal (Dog). Every core candidate is marked
`jcr_gamma_pool == "include"` and `broader_pool == "include"`. No core
candidate is labelled `rare`, `uncertain` or `negligible` for camera encounter.

`ground_use` and taxon identity informed the completed expert classification
but do not create additional model strata. Reusing them would double-count the
same judgement and add parameters unsupported by the 50-candidate pool.

## Minimal prior parameterisation

### Membership

For the fixed core count \(C=50\),

\[
R\sim\operatorname{Uniform}(0,50),
\qquad
\omega=R/50,
\qquad
g_i\sim\operatorname{Bernoulli}(\omega).
\]

This is algebraically the Goal003 \(\omega\sim\operatorname{Beta}(1,1)\)
prior, but its scientific scale is now explicit and it cannot be rescaled by
adding fringe candidates. Marginally, the prior on realised core richness is
uniform on the integers 0 through 50. It is deliberately broad: the camera
data, not an expert richness total, should move core membership.

A `Beta(2,2)` membership sensitivity is retained because it was influential in
Goal003. It is not the primary prior.

### Encounter rate

For candidate \(i\) in externally assigned encounter class \(h_i\), use a
fixed predictive distribution

\[
\alpha_i=\log r_i\sim N(m_{h_i},s_{h_i}^2).
\]

The class locations and spreads are fixed from elicitation rather than learned
as flexible community hyperparameters. Camera histories update each
candidate's \(\alpha_i\), but detections from common species cannot move the
entire unseen-species rate distribution toward a convenient tail. This is the
smallest structural repair consistent with Task 1.

The existing sum-to-zero camera-effect layer and effort hazard are retained:

\[
P(y_{ijk}=1\mid g_i=1)
=1-\exp\{-E_{jk}\exp(\alpha_i+b_j)\}.
\]

The first candidate does not add taxon effects, flexible mixtures, abundance,
spatial occupancy, season dynamics or learned class-level variance.

## Elicitation scale

Raw per-camera-day rates are difficult to assess directly. Elicit instead the
probability that a randomly selected member species from a class is detected
at least once across the lower-median four-week grid effort of 224 active
camera-days:

\[
q_{224}=1-\exp(-224r).
\]

This is a grid-total camera-access probability conditional on membership, not
a single-station occupancy detection probability. Published camera studies
show strong interspecific detectability and effort effects, but their numeric
probabilities are not directly portable across camera placement, habitat and
sampling scale. For example, community camera models have found species
differences larger than session differences and substantial gains from much
larger total effort ([Tobler et al. 2015](https://doi.org/10.1111/1365-2664.12399));
time-to-detection analyses likewise show widely differing 30-day detection
probabilities among species ([Bischof et al. 2014](https://doi.org/10.1111/2041-210X.12115)).

## Proposed calibration anchors

The following values turn the successful Task 1 feasibility profile into an
ecologically interpretable prior. The collaborator approved these anchors on
2026-08-14, before any Judbury detections were accessed.

| Class | Median rate/day | Log SD | Median \(q_{224}\) | 90% interval for \(q_{224}\) |
| --- | ---: | ---: | ---: | ---: |
| routine | 0.0020 | 1.0 | 36% | 8–90% |
| occasional | 0.0005 | 1.0 | 11% | 2–44% |

The routine distribution is the broad Task 1 profile. The occasional median is
one quarter of the routine median while retaining the same broad
between-species predictive spread. These values make the external information
visible; they must be judged against the meanings assigned during worksheet
review, not against Judbury detections.

For reference, at 224 active camera-days, cumulative detection probabilities
of 10%, 36%, 50%, 75% and 90% correspond to rates of approximately 0.00047,
0.0020, 0.0031, 0.0062 and 0.0103 per active camera-day.

## Bounded sensitivities

The primary prior should be accompanied by one-factor sensitivities, not a
large factorial search:

1. `rate_lower`: halve both class median rates;
2. `rate_higher`: double both class median rates;
3. `spread_wider`: increase both log-rate SDs from 1.0 to 1.25;
4. `class_blur`: give each candidate 10% prior probability of belonging to the
   other encounter class; and
5. `membership_regularised`: replace the uniform membership fraction with
   `Beta(2,2)`.

`class_blur` is the direct sensitivity to plausible expert encounter-class
misclassification. The broader 106-candidate analysis remains a separate
pool-boundary sensitivity and is not eligible to redefine primary richness.

For that diagnostic only, the 56 fringe candidates retain the Task 1
count-scale prior

\[
R_f\sim\operatorname{TruncatedExponential}(5;0,56),
\qquad \psi_f=R_f/56.
\]

The three fringe candidates classified `routine` use the routine encounter
prior. The 53 classified `rare` use median rate 0.0002 per active camera-day
and log SD 1. This deliberately prior-dominated fringe is reported separately
from the core and total, never as the primary estimate.

## Prior-only output contract

Once the calibration is approved, Task 2 will generate without detections:

- the exact prior PMF for realised 50-species core richness;
- candidate-level prior membership probabilities;
- prior-predictive distributions of observed richness for the minimum,
  lower-median and maximum exact four- and 26-week effort windows;
- four-week future-discovery distributions following each training window;
- the same summaries under each one-factor sensitivity; and
- an explicitly labelled broader-pool sensitivity separating core and fringe
  contributions.

These become mandatory comparators in later synthetic and empirical work. A
posterior must improve proper scores over its own matching prior-only forecast;
comparison with observed richness alone is insufficient.

## Approval record

The collaborator approved both load-bearing choices on 2026-08-14:

1. fixed externally calibrated class distributions, rather than relearning
   their hyperparameters from the same sparse camera window; and
2. whether the proposed routine and occasional \(q_{224}\) distributions match
   the intended ecological meanings of those worksheet labels.

The numerical profiles are frozen in `config/goal004_task2_priors.csv`. Task 2
uses 50,000 common-random-number draws with seed 40042. The beta-binomial core
richness PMF is exact; effort-dependent observed-richness and discovery
distributions are Monte Carlo predictions with reported Monte Carlo error.
No Stan model or empirical outcome is accessed in this task.
