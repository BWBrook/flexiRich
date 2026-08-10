# Goal 003 — Baseline contract

Status: comparator definitions frozen; Task 2 implemented
Prepared: 2026-08-10

This document fixes the Task 2 comparator definitions before any Goal 003
baseline is evaluated on Judbury. All comparators receive the same named
candidate pool, camera-week detections, effort, training cutoff, and realised
future effort allowed by their data contract. A method is scored only for
quantities it actually estimates.

## Common incidence sample

The primary incidence sample treats each positive-effort camera-week as one
sampling unit. Its binary history is formed from the canonical Goal 003
`detections` and `effort_weekly` tables. Zero-effort units are omitted rather
than converted to non-detections. Candidate species with no detections remain
explicit in the named pool but do not contribute an observed incidence class.

The equal-effort sensitivity retains only camera-weeks with all seven active
days. It is reported only when the resulting sample meets the estimator's
minimum sample-size requirement. Neither incidence analysis weights a partial
week by its active days; exact effort is reserved for the occupancy model.

For a sample containing \(T\) camera-weeks, let \(S_{obs}\) be observed
richness and \(Q_k\) the number of species detected in exactly \(k\) units.

## Comparator definitions

### 1. Observed richness

The estimate is \(S_{obs}\). On a finite pool of size \(C\), its total-richness
PMF is a point mass at \(S_{obs}\). Prospectively it predicts zero new species
and assigns future-first-detection probability zero to every candidate unseen
at the cutoff. These deliberately strong saturation predictions make observed
richness a genuine, reproducible probabilistic null rather than an artificially
uncertain method.

### 2. Chao2 and iChao2

For \(T\ge2\), Chao2 is

\[
\widehat S_{Chao2}=S_{obs}+\frac{T-1}{T}
\begin{cases}
Q_1^2/(2Q_2), & Q_2>0,\\
Q_1(Q_1-1)/2, & Q_2=0.
\end{cases}
\]

For \(T\ge4\), iChao2 adds the incidence-frequency correction used by the
published estimator and its reference `SpadeR` implementation. When \(Q_4>0\),

\[
\widehat S_{iChao2}=\widehat S_{Chao2}+
\frac{T-3}{4T}\frac{Q_3}{Q_4}
\max\left\{Q_1-\frac{T-3}{2(T-1)}\frac{Q_2Q_3}{Q_4},0\right\}.
\]

When \(Q_4=0\), the package's finite fallback is used:

\[
\widehat S_{iChao2}=\widehat S_{Chao2}+
\frac{T-3}{4T}Q_3
\max\left\{Q_1-\frac{T-3}{2(T-1)}Q_2Q_3,0\right\}.
\]

The unconstrained estimate is retained as `raw_estimate`; the primary finite-
pool estimate is \(\min(\widehat S,C)\). No estimate is rounded. Chao2 and
iChao2 are lower-bound point estimators: they do not receive invented PMFs or
candidate-identity probabilities.

### 3. Incidence accumulation and coverage curves

The locked implementation is `iNEXT` 3.0.2 with Hill order \(q=0\),
`datatype = "incidence_raw"`, and bootstrap standard errors disabled. The
analysis retains the package's sample-size- and coverage-based expected
richness outputs in a small, version-stable table.

Observed species only are passed to `iNEXT`; the external pool size remains a
separate upper bound. Expected richness is capped at \(C\) for the primary
finite-pool summary while the raw package estimate is retained. Extrapolation
does not exceed twice the training sample size. A prospective expected number
of discoveries is reported at \(T+T_{future}\) only when that size is within
the locked extrapolation limit. Curves provide expected richness, not a count
PMF or species identities, so they are ineligible for RPS and Brier scores.

### 4. Lower-bound-conditioned finite-pool prior

The existing exact beta-binomial comparator is used with
\(\omega\sim\operatorname{Beta}(1,1)\), conditioned only on \(S_{obs}\) and
the pool size \(C\). It returns a total-richness PMF over \(0{:}C\), with zero
mass below \(S_{obs}\). It contains no detection or effort model and therefore
does not predict finite-horizon discoveries or candidate identities. It is a
synthetic total-richness comparator, not a prospective empirical competitor.

### 5. Conventional multispecies occupancy

For candidate \(i\), camera \(j\), and training occasion \(k\),

\[
z_{ij}\sim\operatorname{Bernoulli}(\psi_i),\qquad
P(y_{ijk}=1\mid z_{ij}=1)=1-\exp\{-E_{jk}r_i\}.
\]

The site-use state \(z_{ij}\) is closed across each combined training and
four-week forecast interval. Species effects are independently partially
pooled:

\[
\operatorname{logit}(\psi_i)=\mu_\psi+\sigma_\psi u_i,
\qquad
\log r_i=\mu_r+\sigma_r v_i,
\]

with standard-normal \(u_i,v_i\),
\(\mu_\psi\sim N(\operatorname{logit}(0.1),1)\),
\(\sigma_\psi\sim N^+(0,1)\),
\(\mu_r\sim N(\log(0.02),1.5)\), and
\(\sigma_r\sim N^+(0,1)\). These priors are fixed without viewing predictive
performance. They describe camera-neighbourhood use and encounter rate per
active day, not abundance.

Discrete states are marginalised in Stan. Posterior site-use probabilities
yield the probability that each candidate uses at least one camera, the exact
Poisson-binomial grid-richness PMF, future-first-detection probabilities for
training-unseen candidates conditional on realised future effort, and the
corresponding mixture of Poisson-binomial new-species-count PMFs. This is the
principal non-FlexiRich probabilistic comparator.

The primary sampler uses four chains, 1,000 warmup and 1,000 retained draws per
chain, `adapt_delta = 0.90`, `max_treedepth = 12`, and deterministic seeds.
One rescue attempt uses four chains, 1,500 warmup and 1,500 retained draws per
chain, `adapt_delta = 0.999`, and `max_treedepth = 15`, without changing the
model or priors. A fit is retained only with zero
divergences, zero maximum-treedepth hits, \(\widehat R\le1.01\), bulk and tail
ESS at least 400 for monitored population parameters, and E-BFMI at least 0.3
in every chain. A window that remains non-clean after the rescue is recorded as
a comparator failure and contributes no occupancy estimate or forecast; it does
not trigger further sampler tuning or prevent the other frozen baselines from
being evaluated.

## Scoring eligibility

| Comparator | Total-richness point | Total-richness PMF | Expected future new count | Future count PMF | Candidate identity probabilities |
| --- | --- | --- | --- | --- | --- |
| Observed richness | yes | point mass | yes, zero | point mass at zero | yes, zero for training-unseen candidates |
| Chao2 / iChao2 | yes | no | no | no | no |
| iNEXT curve | yes | no | yes | no | no |
| Lower-bound prior | yes | yes | no | no | no |
| Community occupancy | yes | yes | yes | yes | yes |

Point-only estimates are compared using absolute error where truth or an
operational reference exists. Only genuine PMFs receive ranked probability or
logarithmic scores; only genuine identity probabilities receive Brier scores.

## Task 2 implementation record

The comparator-definition and scoring sections above were written before the
first cumulative fit; this implementation record was appended afterward.
The frozen suite was run on the cumulative Judbury windows with a 50-species
primary candidate pool. These are reference fits and forecasts, not validation
scores: no post-cutoff detection was used to fit a method or inspected here as
an outcome.

| Training weeks | Observed | Chao2 | iChao2 | Occupancy mean (90% interval) | Occupancy status | iNEXT expected new, next 4 weeks | Occupancy expected new, next 4 weeks |
| ---: | ---: | ---: | ---: | ---: | --- | ---: | ---: |
| 4 | 11 | 11.00 | 11.00 | 14.36 (11–24) | rescue clean | 0.000 | 1.533 |
| 26 | 18 | 25.96 | 25.96 | 23.85 (18–33) | rescue clean | 0.156 | 0.112 |
| 52 | 21 | 33.46 | 34.58 | — | final non-clean | 0.290 | — |
| 153 | 26 | 29.12 | 29.87 | 30.50 (27–36) | primary clean | — | — |

The complete-seven-day sensitivity was practically identical to the primary
positive-effort incidence analysis: the largest Chao2 or iChao2 difference was
less than 0.002 species. The deliberately weak lower-bound-conditioned prior
remained strongly concentrated near the pool ceiling, with posterior means
from 47.0 to 49.1 species; this confirms that it is a prior-only stress
comparator rather than a plausible empirical forecast.

The 52-week rescue had zero divergences, zero treedepth hits, minimum E-BFMI
0.816, minimum bulk and tail ESS of 482 and 837, but failed the frozen
\(\widehat R\le1.01\) rule at 1.0124. It is therefore recorded as unavailable,
without additional tuning. The first end-to-end run originally stopped at this
failure; the runner was then changed only to retain the failure and continue
the independent baselines. The deterministic rerun reproduced the same
diagnostics. Generated fit and result files remain ignored; the tracked runner
recreates them beneath `outputs/goal003/baselines-task2-v1`.

## References and software authority

- Chao, A. (1987). Estimating the population size for capture–recapture data
  with unequal catchability. *Biometrics*, 43, 783–791.
- Colwell, R.K. & Coddington, J.A. (1994). Estimating terrestrial biodiversity
  through extrapolation. *Philosophical Transactions of the Royal Society B*,
  345, 101–118.
- Chiu, C.-H., Wang, Y.-T., Walther, B.A. & Chao, A. (2014). An improved
  nonparametric lower bound of species richness via a modified Good–Turing
  frequency formula. *Biometrics*, 70, 671–682.
- `SpadeR` reference implementation:
  <https://github.com/AnneChao/SpadeR>.
- `iNEXT` 3.0.2 manual:
  <https://annechao.r-universe.dev/iNEXT/iNEXT.pdf>.
