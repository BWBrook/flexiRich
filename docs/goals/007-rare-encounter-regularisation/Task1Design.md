# Goal007 Task 1 — proposed frozen synthetic contract

Status: executable and locally verified; proposed scientific contract not yet frozen
Prepared: 2026-08-25

## Task decision

Task 1 fixes a two-stage synthetic decision before any Goal007 fit is run. The
design deliberately separates candidate selection from independent downstream
confirmation and keeps every empirical detection outcome sealed.

The numerical thresholds below reuse the scale of Goal005 and Goal006 where
possible. Their purpose is not to guarantee a successful model. They define
what improvement would be large and reliable enough to justify consuming the
protected Judbury calibration outcome in a later goal.

## Candidate codes and prior transformation

The paired models are:

| Code | Model ID | Parameterisation | Selection priority |
| ---: | --- | --- | ---: |
| 1 | `independent` | unchanged Goal006 independent class locations | comparator only |
| 2 | `shared_F5` | shared shift plus F5 contrast deviation | 1 |
| 3 | `shared_F3` | shared shift plus F3 contrast deviation | 2 |

For a requested factor \(F\),

\[
\tau_\Delta=\frac{\log F}{q_{0.975}},
\qquad q_{0.975}=1.95996398454005.
\]

The executable contract must verify the transformation to within `1e-12`, the
derived class locations to within `1e-12`, and the covariance implied by
independent \(\eta\) and \(\kappa\). The Stan likelihood and its gradient must
match an independent R implementation within `1e-8` and `1e-5`, retaining the
64-node Gauss--Hermite selection integral.

## Task 2 paired calibration screen

### Design

The screen contains six profiles by 10 replicates = 60 datasets. Each dataset
is fitted by all three models, giving 180 fits. Profiles and rates are fixed in
[`Goal.md`](Goal.md). All simulations use the first 52 occasions of the frozen
Judbury effort schedule, 50 true members, biological log-rate SD one, and
camera-effect SD 0.35.

The seed rules are:

- simulation: `710000000 + 100 * profile_code + replicate`;
- fit: `720000000 + 1000000 * model_code + 100 * profile_code + replicate`.

Profile codes follow the table order in `Goal.md` from 1 to 6. Replicates are
1--10. Models share each simulated dataset exactly. The Goal006 streams and
seeds are not read.

The ordinary sampler and single frozen rescue remain unchanged. Terminal
cleanliness retains zero divergences and treedepth hits, maximum R-hat 1.01,
minimum bulk and tail ESS 400, and minimum chain E-BFMI 0.3.

### Recovery targets

For class \(h\) in dataset \(d\), define:

- generator error
  \(e^{G}_{dh}=\tilde m_{dh}-m^{true}_{dh}\); and
- finite-set error
  \(e^{F}_{dh}=\tilde m_{dh}-\overline\alpha^{true}_{dh}\),

where \(\tilde m\) is the posterior median and \(\overline\alpha^{true}\) is
the mean latent log rate among the fixed class candidates. The latter is a
diagnostic target, not a redefinition of the fitted superpopulation parameter.

A dataset is catastrophic if its fit is not terminal clean or either class
has `abs(eG) > log(3)` or `abs(eF) > log(3)`. This composite rule prevents a
candidate from looking safe only because one of the two legitimate location
targets was ignored.

### Candidate eligibility gates

The five core profiles contribute 50 fixed-denominator datasets. For each
shared candidate:

1. at least 58/60 fits are terminal clean and every profile has at least 9/10;
2. maximum absolute profile-median generator bias is at most 0.35 log units
   for routine and 0.50 for occasional;
3. pooled generator RMSE is at most 0.60 for routine and 0.75 for occasional;
4. pooled finite-set RMSE is at most 0.60 for routine and 0.75 for occasional;
5. generator-location 90% coverage is at least 42/50 for each class and at
   least 8/10 within every class-profile cell;
6. no more than two of 50 core datasets are catastrophic;
7. relative to the paired independent model,
   `max(RMSE_generator, RMSE_finite)` for the occasional class is reduced by
   at least 10%, occasional coverage is no lower by more than two datasets,
   and the catastrophic count is no larger; and
8. routine generator and finite-set RMSE are each no more than 10% worse than
   the paired independent model.

In the 10-dataset `no_separation` stress, the occasional profile-median
generator bias must be at most `log(2)`, generator coverage at least 7/10, and
no more than two datasets may be catastrophic. This is deliberately a wider
guardrail than the core standard.

If both candidates pass, F5 is selected. F3 can be selected only when F5 fails
at least one eligibility row and F3 passes every row. If neither passes, the
goal stops as `NO_REGULARISATION_CANDIDATE`. There is no best-score override.

### Artifact guard

Every terminal-clean shared fit is reduced to the same aggregate bivariate
class-location artifact intended for the downstream model. Across empirical
draws versus its Gaussian approximation:

- maximum marginal error at the 2.5%, 50%, and 97.5% quantiles is at most
  0.10 log units;
- Mahalanobis-radius KS distance from chi-square(2) is at most 0.10; and
- maximum absolute marginal skewness is at most 0.50.

At least 58/60 candidate artifacts and 9/10 per profile must pass all three
checks. A failed approximation cannot be hidden by labelling the sampler fit
clean.

## Task 3 fresh downstream confirmation

### Paired design

The selected shared candidate and independent baseline are compared on 48 new
ecological streams. The design crosses:

- rate profiles `nominal`, `common_lower`, `compressed`, and `expanded`;
- true richness 10, 25, and 40, with the fixed Goal005 routine/occasional
  member counts 9/1, 22/3, and 35/5; and
- four replicates in every rate-by-richness cell.

Membership permutations are nested within each rate-profile/replicate stream,
as in Goal005. Both models receive identical membership, latent rates, camera
effects, calibration histories, target histories, effort, and forecast
outcomes. The target durations are 12, 16, and 26 occasions and the forecast
horizon is four occasions.

Calibration always uses the synthetic analogue of occasions 1--52. Target and
forecast effort use forecast starts 81, 105, 129, and 149 from the frozen
post-gap Goal006 fold schedule, assigned in replicate order. Every rate profile
therefore receives the same four effort patterns, ranging from the sparsest
26-week Goal006 history to the most complete. The same fold is assigned to
both models, all three richness scenarios, and all nested durations.

Candidate latent log rates persist between calibration and target periods,
representing stable relative encounter behaviour of the same named species.
The aggregate interface deliberately discards their identities and estimates.
Calibration and target camera effects are generated independently to test
transport of the class distribution rather than persistence of a fitted
camera effect. Temporal rate dynamics remain deferred.

The seed rules are:

- ecological and detection stream:
  `730000000 + 100 * rate_profile_code + replicate`;
- calibration fit:
  `740000000 + 1000000 * model_code + 10000 * rate_profile_code +
  100 * richness_code + replicate`;
- target fit:
  `750000000 + 10000000 * model_code + 100000 * duration_code +
  10000 * rate_profile_code + 100 * richness_code + replicate`.

Rate codes are 1--4 in the order above, richness codes are 1--3, duration
codes are 1--3 for 12/16/26 weeks, and replicates are 1--4. These rules stay
within R's exact integer range.

The complete schedule is 96 calibration fits and 288 target fits = 384 Stan
fits. Only the selected candidate is scheduled; the unselected shared model is
not carried into confirmation.

### Information boundary

The calibration artifact may contain only model/prior metadata, class order,
class-location mean and covariance, fit diagnostics, approximation checks,
source hashes, and seed provenance. It may not contain candidate or species
identifiers, histories, latent rates, membership, or posterior membership
quantities.

The target adapter must reject synthetic truth and any calibration object that
contains a prohibited field. It re-estimates candidate membership, candidate
rates, and target camera effects from the target history. The independent
baseline uses its own paired independent-class artifact; it does not receive
the shared candidate's posterior.

Before target fitting, at least 47/48 calibration fits for each model must be
terminal clean, with at least 15/16 per richness level and 11/12 per rate
profile. Their Gaussian artifacts must pass the same quantile, radial, and
skew checks as Task 2 at the same fixed denominators. Failure stops the
downstream screen rather than allowing unequal or selectively valid artifacts
to define the paired comparison.

Goal007 does not retain Goal006's standalone F2 marginal-precision gate. F2
would no longer distinguish information learned from data from precision
introduced by the explicit contrast prior. Marginal uncertainty factors are
still reported for every artifact, but advancement is determined by synthetic
recovery, coverage, prior-misspecification stress, and downstream performance.

### Absolute downstream gates

Each model and duration is evaluated over 48 fixed scheduled fits. A duration
passes the absolute standard only if:

1. at least 47/48 fits are terminal clean, every richness level has at least
   15/16, and every rate profile has at least 11/12;
2. median paired high-minus-low posterior-mean richness separation is at least
   27 of the true 30 species;
3. absolute median signed richness bias is at most three species within every
   richness level and every rate profile;
4. pooled mean richness RPS improves by at least 40% over the matching no-data
   membership prior, with positive mean improvement within every richness
   level and rate profile;
5. fixed-denominator 90% richness coverage is at least 13/16 within every
   richness level and 10/12 within every rate profile;
6. median 90% richness-interval width is at most 25 species; and
7. no more than two of 48 scheduled fits are terminal non-clean or have
   absolute posterior-mean richness error of at least 12.5 species.

These are the Goal005 common scientific scales with denominators adjusted to
the balanced Goal007 design.

### Paired improvement and forecast guards

The selected shared candidate must additionally, at every duration in its
passing suffix:

1. have pooled mean richness RPS no more than 5% worse than the paired
   independent baseline;
2. have no more catastrophic richness cases than the independent baseline;
3. have overall 90% richness coverage no lower than the baseline by more than
   two of 48 fits;
4. have mean future-new-species count RPS no more than 5% worse than baseline;
5. have mean future-identity Brier score no more than 5% worse than baseline;
   and
6. produce finite future-count log scores for every terminal-clean fit.

At the selected shortest duration, the candidate must also earn the redesign
by either improving pooled richness RPS by at least 5% or producing at least
one fewer catastrophic richness case than the independent baseline. Thus a
longer anchor may establish non-inferiority without being forced to show a
large gain after abundant target data have already weakened the calibration's
influence.

The two forecast rows are non-inferiority guards rather than required gains:
Goal007 is designed to stabilise richness calibration, and sparse four-week
discoveries may not support a precise claim of forecast superiority.

### Duration rule

The shortest eligible duration is the beginning of the longest contiguous
passing suffix:

- 12 weeks is selected only when 12, 16, and 26 weeks pass;
- 16 weeks is selected only when 16 and 26 weeks pass; and
- 26 weeks is selected when 26 weeks alone passes.

Failure at 26 weeks prevents empirical advancement irrespective of an isolated
shorter-duration pass.

## Output and audit contract

Task 2 and Task 3 use separate non-overwriting output roots. Each publishes:

- frozen manifests and gate tables;
- Git commit, input hashes, seed rules, package and CmdStan versions;
- one row per logical fit with terminal diagnostics;
- compact class-recovery or downstream-scoring tables;
- complete fixed-denominator gate rows; and
- a plain-text terminal status explicitly stating
  `empirical_outcomes_used=false`.

Raw CmdStan outputs remain on `deep-server`. A separate audit entry point must
reconstruct every gate from compact row-level evidence without importing the
execution evaluator. Heavy batches begin only from a clean, pushed commit and
are not altered while running.

## Approval boundary

The executable Task 1 contract is implemented, but collaborator approval is
still required to freeze the candidates, profiles, denominators, thresholds,
selection order, duration rule, and evidence boundary before Task 2 model code
is written or any Goal007 fit is run.
