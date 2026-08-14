# Goal004 Task 1 — analytical identifiability screen

Status: prespecified before execution
Prepared: 2026-08-14

## Decision

This bounded, pre-Stan screen asks whether four weeks of Judbury-like camera
effort can separate expected grid membership from mean encounter rate well
enough to justify eliciting a candidate-stratified model. It is a feasibility
test, not a validation of FlexiRich and not an opportunity to tune the stopped
Goal003 candidate.

The screen may use:

- the frozen 153-week operational-effort template;
- the 30 frozen Goal003 effort-window starts for each duration;
- the externally reviewed counts and labels in the candidate-pool worksheet;
  and
- the matched Goal003 design values of 10, 25, and 40 expected members and a
  mean encounter rate of 0.002 per active camera-day.

It must not use Judbury detections, Goal003 posterior outputs, future discovery
outcomes, or Huon Ridge data. The matched design values are synthetic design
points, not empirical estimates or candidate priors.

Repeated observations are what allow occupancy models to distinguish ecological
state from imperfect detection ([Dorazio et al. 2006](https://doi.org/10.1890/0012-9658(2006)87%5B842:ESRAAB%5D2.0.CO;2)).
Without that separation, observations principally identify the product of state
and cumulative detection probabilities ([Guillera-Arroita et al. 2014](https://doi.org/10.1371/journal.pone.0099571)).
This screen measures how much separation the exact Judbury effort supplies in a
deliberately favourable homogeneous-rate case.

## Expected-likelihood diagnostic

For one stratum containing \(C\) candidates, let

\[
g_i\sim\operatorname{Bernoulli}(\psi),
\qquad \psi=R/C,
\]

where \(R\) is the expected number of members. For sampled camera-week cell
\(t\), active effort is \(e_t>0\), encounter rate is \(r\), and

\[
p_t(r)=1-\exp(-e_t r),
\qquad
q(r)=1-\exp\left(-r\sum_t e_t\right).
\]

Cells with zero effort are omitted rather than treated as non-detections. Under
design values \(R_*\) and \(r_*\), the expected number of candidates detected
at least once is \(D_*=R_*q(r_*)\), and the expected detections in cell \(t\)
are \(m_t=R_*p_t(r_*)\). Up to an additive constant, the expected log likelihood
is

\[
\begin{split}
\ell(R,r)={}&D_*\log(R/C)\\
&+\sum_t\left[m_t\log p_t(r)
 +(D_*-m_t)\log\{1-p_t(r)\}\right]\\
&+(C-D_*)\log\left[1-(R/C)q(r)\right].
\end{split}
\]

This is the expectation of the complete candidate-history log likelihood, not
a simulated dataset and not a likelihood fitted to fractional observations. It
retains the information in repeated camera-week detections while removing
Monte Carlo noise. A common rate is favourable: unmodelled species
heterogeneity would make the unseen tail harder, not easier, to identify.

The diagnostic targets \(R\), the membership-distribution parameter. It does
not claim that \(R\) is the realised integer richness of one community.

## Frozen design

### Effort

For each of the four- and 26-week durations, calculate total active camera-days
for all 30 frozen window starts. Analyse three exact windows:

- the minimum-effort window;
- the lower median (15th of 30 after sorting by total effort, then start and
  replicate); and
- the maximum-effort window, with the smallest start used to break a tie.

All 60 window summaries are retained so the selected patterns remain auditable.

### Likelihood design points

Cross expected membership \(R_*\in\{10,25,40\}\) with both durations and the
three effort patterns. The homogeneous design rate is \(r_*=0.002\). Evaluate
the likelihood on fixed grids

\[
R=0,0.25,\ldots,C,
\qquad
\log r\in[\log(10^{-5}),\log(0.1)]
\]

using 241 equally spaced log-rate values and trapezoidal quadrature weights.

### Encounter-rate prior profiles

Three prespecified log-rate priors distinguish a known failed profile from two
calibration-feasibility profiles:

| ID | Prior on \(\log r\) | Role |
| --- | --- | --- |
| `goal003_wide` | \(N\{\log(0.02),1.5^2\}\) | reproduces the Goal003 scale problem |
| `centred_broad` | \(N\{\log(0.002),1^2\}\) | broad optimistic external-calibration target |
| `centred_moderate` | \(N\{\log(0.002),0.5^2\}\) | narrow diagnostic; cannot qualify the model |

The centred profiles deliberately use the design truth. They answer how much
independent rate calibration would be needed; they are not admissible final
priors unless Task 2 can justify them without Judbury outcomes.

### Membership formulations

The exchangeable comparison uses \(R\sim\operatorname{Uniform}(0,C)\) for
both \(C=50\) and \(C=106\), exactly equivalent to the Goal003
\(\psi\sim\operatorname{Beta}(1,1)\) prior.

The candidate-stratified comparison keeps

\[
R_{core}\sim\operatorname{Uniform}(0,50)
\]

when 56 fringe candidates are added. Independently,

\[
R_{fringe}\sim\operatorname{Exponential}(1/s)
\]

truncated to \([0,56]\), for scales \(s\in\{2,5,10\}\) species. These are a
sensitivity envelope, not proposed final priors. The fringe encounter rate is
either equal to the core rate or ten-fold lower. The latter represents the
consequential case in which broader-pool candidates are labelled rare or
otherwise difficult to sample.

The synthetic community has zero fringe members. Its fringe data contribution
is therefore the exact all-zero likelihood; no outcome is simulated.

## Diagnostics

For every surface retain:

- the two-log-unit spans of the profile likelihood in \(R\) and \(r\);
- posterior mean, standard deviation, and central 90% interval for \(R\);
- posterior correlation between \(R\) and \(\log r\);
- Jensen-Shannon divergence from the membership prior;
- continuous ranked probability score (CRPS) at \(R_*\), for the prior and
  posterior; and
- proportional CRPS improvement over the same prior-only forecast.

For stratified models also retain the posterior core and fringe means, the core
shift relative to the 50-candidate analysis, the total expected-membership
shift, and the proportional reduction in fringe mean from its prior-only value.

## Prespecified interpretation

The lower-median four-week window and `centred_broad` rate profile form the
decision checkpoint. Minimum and maximum effort, 26 weeks, `goal003_wide`, and
`centred_moderate` are explanatory sensitivities.

Core membership is considered materially data-responsive only if:

1. the posterior-mean separation between \(R_*=40\) and \(R_*=10\) is at
   least 15 species;
2. mean CRPS improvement across the three membership points is at least 20%;
   and
3. CRPS does not worsen at any of the three points.

The prespecified broad-pool checkpoint uses fringe scale \(s=5\) and the
ten-fold lower encounter rate. It is considered pool-stable and
data-responsive only if:

1. the maximum absolute core shift across the three membership points is at
   most two species;
2. the maximum total expected-membership shift is at most three species; and
3. all-zero camera histories reduce the fringe posterior mean by at least 25%
   from its prior-only mean at every membership point.

The outcome is:

- `PROCEED` if both core and broad-pool checkpoints pass with
  `centred_broad`;
- `CORE_ONLY` if the core checkpoint passes but the broad-pool checkpoint
  fails; or
- `STOP` if the core checkpoint fails.

Passing only under `centred_moderate`, a fringe scale below five, or an assumed
fringe encounter rate equal to the core rate cannot rescue a failed checkpoint.
`CORE_ONLY` pauses Goal004 for an estimand decision; it does not silently
discard the broader-pool requirement.

## Outputs and stopping point

The deterministic runner writes an effort audit, posterior summaries, decision
metrics, provenance, and one likelihood-ridge figure beneath
`outputs/goal004/task1-identifiability-v1`. It refuses to overwrite an existing
directory and records the Git commit and hashes of both frozen inputs.

After one focused implementation review and a clean test run, commit and push
the frozen runner before executing it. Run once locally. Document the result
and stop for collaborator assessment before Task 2.
