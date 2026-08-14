# Goal004 Task 3 — minimal fixed-class model design

Status: implemented; all Task 3 gates passed
Prepared: 2026-08-14

## Decision to be tested

Task 3 will implement the smallest model capable of testing the Goal004
hypothesis: can fixed, externally reviewed encounter classes stabilise
short-window inference while leaving the camera data useful for updating
membership?

The model targets richness among the 50 named, camera-accessible core
candidates. It is not a model of total vertebrate richness. The 56 fringe
candidates remain a prior-dominated pool-boundary diagnostic and do not enter
this first fitted candidate.

Task 3 therefore validates only the core model engine. It cannot establish
nested-pool stability: excluding the fringe makes the core invariant by
construction. A later Task 4 diagnostic must add the fringe as an independent
membership stratum and compare the core posterior with and without that
stratum, including any indirect change transmitted through shared camera
effects.

## Retained observation model

The input remains species-by-camera-by-seven-day incidence with exact active
camera-days. Zero-effort camera-weeks are unsampled, not non-detections. The
existing grouped binomial likelihood is retained without alteration.

For species (i), camera (j), and occasion (k), conditional on site-pool
membership,

\[
p_{ijk}=1-\exp\{-E_{jk}\exp(\alpha_i+b_j)\}.
\]

The member log likelihood (\ell_i\) sums the corresponding detection and
non-detection terms over positive-effort cells. Binomial coefficients are
constant in the fitted parameters and may be omitted.

The latent (alpha_i) remains an encounter rate per active camera-day, not an
estimate of animal abundance or density.

## Count-scale membership

Let (C=50) be the fixed core candidate count and let (R_c) denote the
community-level expected number of core members:

\[
0<R_c<C,
\qquad
\omega_c=R_c/C,
\qquad
R_c/C\sim\operatorname{Beta}(a_\omega,b_\omega).
\]

The primary profile uses (a_\omega=b_\omega=1), equivalent to
(R_c\sim\operatorname{Uniform}(0,50)). The model parameter will be (R_c),
not a generic candidate-pool fraction. This makes the scientific scale
explicit and allows a future fringe component to have its own independent
count parameter without rescaling the core.

For fixed (C=50), this is only a reparameterisation of the Goal003 membership
fraction: (R_c) and (\omega_c) contain exactly the same information. It does
not by itself improve identifiability. Any short-window improvement in this
candidate must come from the prespecified encounter-class priors, and the
evaluation must attribute it accordingly.

The Stan density for the bounded count parameter is the proper transformed
Beta density,

\[
\log\pi(R_c)
=\operatorname{beta\_lpdf}(R_c/C\mid a_\omega,b_\omega)-\log C.
\]

The Jacobian term is constant for a fixed pool, but retaining it makes the
probabilistic specification explicit and correct.

Candidate membership indicators are analytically marginalised. For a species
detected during training,

\[
\log L_i=\log\omega_c+\ell_i.
\]

For an undetected candidate,

\[
\log L_i=
\log\{(1-\omega_c)+\omega_c\exp(\ell_i)\}.
\]

The conditional membership probability in each posterior draw is therefore

\[
q_i=
\begin{cases}
1, & \text{if detected in training},\\
\operatorname{logit}^{-1}\{\operatorname{logit}(\omega_c)+\ell_i\},
& \text{otherwise}.
\end{cases}
\]

No discrete parameter, pseudo-membership variable, anonymous species tail or
continuous relaxation is introduced.

## Fixed encounter-class priors

Each core candidate has one externally reviewed label (h_i\in\{
\text{routine},\text{occasional}\}). The primary prior is

\[
\alpha_i\mid h_i=\text{routine}
  \sim N\{\log(0.002),1^2\},
\]

\[
\alpha_i\mid h_i=\text{occasional}
  \sim N\{\log(0.0005),1^2\}.
\]

These locations and spreads are fixed data supplied to Stan. There is no
community mean, learned class mean, learned species variance, mixture tail or
hierarchical feedback from common detected species into the prior for unseen
candidates. Each candidate's own observations can update its (alpha_i).

To support the approved class-blur sensitivity in the same model, define
(w_i) as the prior probability that candidate (i) belongs to the routine
rate component:

\[
\pi(\alpha_i)=
w_iN(\alpha_i\mid m_r,s)+
(1-w_i)N(\alpha_i\mid m_o,s).
\]

For all profiles except `class_blur`, (w_i=1) for a routine label and zero
for an occasional label. Under `class_blur`, the respective values are 0.9 and
0.1. This is a candidate-specific overlapping mixture with fixed components;
there is no exchangeable mixture allocation or label-switching parameter.

Stan samples each (\alpha_i) directly. For (w_i=1) or zero, its target density
uses the corresponding single Normal component; `log_mix` is used only for
strictly interior weights. There is no standard-Normal latent transform or
discrete class allocation. This one direct parameterisation supports both the
fixed-class primary profile and the blurred-class sensitivity without a second
model source.

## Camera effects

The existing exact sum-zero camera layer is retained:

\[
\mathbf b=\sigma_b\mathbf Q\mathbf z_b,
\qquad
\mathbf z_b\sim N(\mathbf0,\mathbf I),
\qquad
\sigma_b\sim\operatorname{half\text{-}Normal}(0,0.75).
\]

This separates relative camera encounter conditions from each species' grid
rate. No site occupancy, spatial covariance or temporal random effect is added.

## Frozen profile mapping

All profiles come from `config/goal004_task2_priors.csv` and use the same Stan
source.

| Profile | Membership prior | Routine median | Occasional median | Log SD | Class weights |
| --- | --- | ---: | ---: | ---: | --- |
| `primary` | Beta(1,1) | 0.002 | 0.0005 | 1.0 | 1 / 0 |
| `rate_lower` | Beta(1,1) | 0.001 | 0.00025 | 1.0 | 1 / 0 |
| `rate_higher` | Beta(1,1) | 0.004 | 0.001 | 1.0 | 1 / 0 |
| `spread_wider` | Beta(1,1) | 0.002 | 0.0005 | 1.25 | 1 / 0 |
| `class_blur` | Beta(1,1) | 0.002 | 0.0005 | 1.0 | 0.9 / 0.1 |
| `membership_regularised` | Beta(2,2) | 0.002 | 0.0005 | 1.0 | 1 / 0 |

Only one factor differs from `primary` in each sensitivity.

## Posterior richness and discovery

Conditional on a posterior draw, candidate membership states are independent
Bernoulli variables with probabilities (q_i). The realised-richness PMF is
therefore computed by the existing exact Poisson-binomial recurrence and then
averaged across posterior draws. Bernoulli simulation is not used for posterior
richness.

For future camera effort (E_j^*), the conditional encounter probability is

\[
d_i^*=1-\exp\left\{-\sum_jE_j^*\exp(\alpha_i+b_j)\right\}.
\]

For a candidate unseen in training, future-first-detection probability is
(q_id_i^*); it is zero for candidates already detected. The count of future
discoveries again uses the exact Poisson-binomial recurrence.

Every fitted result must expose:

- the posterior richness PMF and 90% interval;
- the matching exact prior richness PMF;
- candidate-level prior and posterior membership probabilities and movement;
- the future-discovery count PMF; and
- candidate-level future-first-detection probabilities.

The Task 2 prior-only output remains the canonical no-data comparator. Task 4
will generate the same matching prior forecast for every exact frozen effort
window; the six Task 2 representative forecasts become regression anchors.

## Minimal implementation surface

Task 3 adds only:

- `stan/goal004_flexirich.stan` for the model above;
- a focused R data/model module for profile mapping, validation, the R
  conditional-membership oracle, compilation and fitting;
- a focused R prediction module that reuses the proven exact finite-pool PMF
  calculations;
- one model-contract test file;
- one Stan/R bridge script; and
- one small synthetic smoke runner.

The existing canonical inference data, grouped effort likelihood, sum-zero
basis, sampler attempts, diagnostic classifier and exact PMF machinery are
reused. Historical Goal003 scientific code is not copied into a second
implementation. Task 3 does not trigger a broad Goal003 runtime refactor:
proven private helpers may be reused despite their historical names. A helper
is extracted only if Goal004 would otherwise duplicate material logic, and no
compatibility wrapper is retained.

The Goal004 adapter accepts a candidate-ID-aligned encounter-class vector. It
does not infer classes from detections. Its hash covers the canonical source
data, candidate classes and complete frozen prior profile. Synthetic truth
fields are forbidden from the fitted object. The reviewed Judbury mapping is
fixed at 50 candidates, but the adapter accepts any positive candidate count so
the bridge and smoke fixtures can remain genuinely small.

## Verification gates

### 1. Static and unit contract

- exactly 50 reviewed core candidates map to 44 routine and six occasional;
- all six profiles produce only the prespecified one-factor change;
- the model contains no learned encounter hypermean or hypervariance;
- membership is marginalised analytically and has no membership RNG;
- the encounter prior uses a single Normal at class weights zero or one and
  `log_mix` only at interior class weights;
- the transformed-Beta count prior includes its (1/C) Jacobian;
- zero effort remains unsampled;
- detected candidates have (q_i=1);
- all probabilities and PMFs are finite, bounded and normalised; and
- data hashes change when either a class label or profile changes.

### 2. Stan/R bridge

Using the existing small synthetic fixture, compare at least 20 retained Stan
draws with the independent R calculation. Required maximum absolute errors are:

| Quantity | Tolerance |
| --- | ---: |
| member log likelihood | (10^{-8}) |
| conditional membership probability | (10^{-8}) |
| expected realised richness | (10^{-7}) |
| sum of camera effects | (10^{-10}) |

The bridge must also verify that the reported count-scale parameter satisfies
(R_c=50\omega_c) at every draw (or (C\omega_c) for a reduced fixture).

### 3. Prior-concordance check

Fit the primary model to a canonical 50-candidate dataset whose effort grid has
zero active days and therefore produces no grouped likelihood rows ((G=0)).
For this dataset the posterior must equal the prior; prospective effort is
passed separately to the prediction layer. Require clean sampler diagnostics,
the exact uniform richness mean to fall within four Monte Carlo standard
errors, and total-variation distance at most 0.05 between the Stan-derived
richness PMF and the exact Task 2 beta-binomial PMF.

Using the lower-median four-week effort as prospective effort, require
total-variation distance at most 0.05 between the Stan-derived first-detection
count PMF and the frozen Task 2 `primary` observed-richness PMF. This validates
that the fitted model and the external prior-only engine describe the same
no-data process.

### 4. Synthetic smoke

Run one genuinely small, truth-isolated synthetic fit locally. It must:

- compile from a clean committed state;
- exclude `truth`, `member` and `true_richness` from fitted data;
- finish `primary_clean` or `rescue_clean` under the existing strict
  diagnostic thresholds;
- return normalised richness and discovery PMFs over valid supports;
- assign posterior membership one to every detected candidate; and
- write completion metadata with code commit and seeds.

This smoke is mechanical evidence only. It does not establish calibration or
scientific superiority.

## Stop conditions

Stop Task 3 before development simulation if:

- the Stan and R marginal likelihoods disagree;
- the Stan prior does not reproduce the Task 2 no-data forecast;
- fixed class priors still require a learned tail parameter to sample cleanly;
- the class-blur mixture creates unresolved multimodality or non-identifiability;
- posterior PMFs require membership simulation rather than exact recurrence;
- the candidate adapter can access truth or Judbury detections; or
- implementation requires adding spatial, temporal, abundance or anonymous-tail
  structure to make the smoke pass.

No empirical Judbury outcome, old Goal003 screen outcome, Huon Ridge datum or
new held-out synthetic seed is accessed in Task 3.

Passing Task 3 will show that the minimal fixed-class core model is implemented
correctly and reproduces its frozen prior forecast. It will not show that the
model is calibrated, superior to its prior, or stable to a broader candidate
pool; those are Task 4 and Task 5 questions.

## Approval gate

Implementation requires collaborator approval of three linked choices:

1. fit the membership parameter directly on the 0–50 expected-count scale;
2. use a fixed candidate-specific Normal or two-component class-blur mixture
   for encounter rates, with no learned class hyperparameters; and
3. limit Task 3 to the primary 50-species model, leaving the demonstrably
   prior-dominated fringe as a later diagnostic rather than fitting it now.
