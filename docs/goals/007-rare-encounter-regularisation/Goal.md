# Goal 007 — rare-encounter regularisation and synthetic downstream validation

Status: active; Task 1 frozen and Task 2 implementation complete, recovery
screen pending
Prepared: 2026-08-25

## Decision question

Can a parsimonious shared-shift hierarchy reduce consequential occasional-class
calibration errors while preserving honest uncertainty and improving the
downstream finite-pool richness and species-discovery predictions for which the
calibration is intended?

This is a new synthetic development goal. It does not revise the failed
Goal006 gates, rerun Goal006 with favourable seeds, or reinterpret two failures
as success.

## Motivation

Goal006 established that the selection-adjusted calibration likelihood was
mathematically correct and computationally clean. Its independent class model
passed 11 of 12 recovery gates, but two of 30 occasional-class posterior
medians differed from the generating location by more than a factor of three.
Only six of the 50 reviewed Judbury candidates are labelled `occasional`, so
the occasional location is informed by a small and variably detected set.

The independent Goal006 priors also discard a plausible source of information.
If a grid, deployment, event definition, or camera configuration shifts all
encounter rates, the 44 routine candidates can estimate much of that common
shift. The six occasional candidates should then need to estimate only how
their contrast with the routine class differs from its prior expectation.

The repair must not be judged only by recovery of a generating hyperparameter.
The target population is the fixed set of named candidates, whose realised
mean log rates can differ from the superpopulation location used to generate
them. More importantly, the scientific products are posterior richness and
future-discovery predictions. Goal007 therefore distinguishes:

1. recovery of the generating class locations;
2. approximation of the realised finite-candidate class locations; and
3. downstream richness and discovery calibration.

A candidate advances only on the third target after first passing the bounded
calibration screen.

## Protected evidence boundary

Goal007 may use:

- the reviewed 50-candidate pool and its 44 routine / six occasional labels;
- the tracked Judbury operational-effort schedule, with no detections;
- the proven Goal006 selection-adjusted likelihood and numerical bridge;
- the frozen Goal005 target model, scoring rules, and synthetic richness
  scenarios;
- the aggregate Goal006 decision evidence as motivation; and
- new Goal007 simulation and fit seeds.

Goal007 may not use:

- the empirical Judbury detection history, including its first 52 weeks;
- later Judbury target or forecast outcomes;
- Huon Ridge detections, effort, or locations;
- candidate-specific information derived from either empirical dataset; or
- the 30 Goal006 recovery streams to select or validate a candidate.

All empirical outcomes remain sealed. A successful Goal007 result permits a
new empirical goal; it does not retrospectively reopen Goal006.

## Candidate hierarchy

Let the prior median rates be

\[
a_R=\log(0.002), \qquad a_O=\log(0.0005),
\]

so the prior occasional-to-routine ratio is one quarter. Goal006 estimated the
two class locations independently:

\[
m_R\sim N(a_R,1.5^2), \qquad m_O\sim N(a_O,1.5^2).
\]

That unchanged model is the paired baseline. The proposed hierarchy instead
uses

\[
\eta\sim N(0,1.5^2), \qquad
\kappa\sim N(0,\tau_\Delta^2),
\]

\[
m_R=a_R+\eta,
\qquad
m_O=a_O+\eta+\kappa.
\]

Here \(\eta\) is a common absolute log-rate shift learned primarily from the
routine candidates, while \(\kappa\) is deviation from the prior log-rate
contrast. The biological species-level spread remains one. No order constraint
is imposed, so sufficiently strong evidence may place the occasional location
above the routine location.

Two fixed contrast uncertainties are examined:

| Candidate | 95% factor around the prior class-rate ratio | \(\tau_\Delta\) | Role |
| --- | ---: | ---: | --- |
| `shared_F5` | 5 | \(\log(5)/1.959964\) | weakest eligible regularisation |
| `shared_F3` | 3 | \(\log(3)/1.959964\) | stronger fallback |

The independent Goal006 prior implies a contrast SD of
\(\sqrt{1.5^2+1.5^2}\), or an approximately F64 ratio uncertainty. F5 and F3
therefore add material but still broad regularisation. Neither can manufacture
the old F2 marginal-location gate directly, because the common shift remains
broad and both contrast priors are wider than F2.

The selection rule is deliberately weak-first: `shared_F5` is chosen if it
passes; `shared_F3` is considered only if F5 fails. There is no continuous
search over prior scales and no post-result interpolation.

## Synthetic truth regimes

The calibration screen uses the actual first-52-week Judbury effort pattern,
fixed between-species log-rate SD one, camera-effect SD 0.35, and six new
rate profiles:

| Profile | Routine median | Occasional median | Common shift | Contrast deviation | Role |
| --- | ---: | ---: | ---: | ---: | --- |
| `nominal` | 0.0020 | 0.0005000 | 0 | 0 | aligned core |
| `common_lower` | 0.0010 | 0.0002500 | \(-\log 2\) | 0 | shared-scale core |
| `common_upper` | 0.0040 | 0.0010000 | \(+\log 2\) | 0 | shared-scale core |
| `compressed` | 0.0015 | 0.0007500 | \(\log 0.75\) | \(+\log 2\) | contrast core |
| `expanded` | 0.0015 | 0.0001875 | \(\log 0.75\) | \(-\log 2\) | rare-tail core |
| `no_separation` | 0.0015 | 0.0015000 | \(\log 0.75\) | \(+\log 4\) | severe misspecification stress |

The five core profiles span common transfer shifts and a twofold error in
either direction in the prior class ratio. `no_separation` asks what happens
when the reviewed classes carry no rate separation at all. It is reported
separately so that a severe class-definition failure does not silently become
the assumed primary ecology.

## Staged sequence

### Task 1 — freeze the synthetic contract

Freeze the candidate parameterisation, truth profiles, fresh seed rules,
paired baseline, metrics, gates, model-selection rule, truth-isolation
requirements, and output contract. Goal006 results may motivate the design but
may not be used as Goal007 observations.

### Task 2 — calibration and regularisation screen

Implement the shared-shift parameterisation as the smallest possible variant
of the proven selection-adjusted model. Establish its Stan/R value and gradient
bridges, prior transformation, selection adjustment, and bivariate artifact
approximation.

Fit the independent baseline, `shared_F5`, and `shared_F3` to 10 new replicates
of each of the six truth profiles: 60 datasets and 180 paired fits. All 50
candidates are members in this mechanistic screen so it isolates rate
regularisation from membership non-identifiability.

Each fit is judged against both the generating location and the realised mean
log rate of the fixed candidates in each class. The screen also checks
coverage, tail error, computation, and non-inferiority of the routine class.
At most one shared candidate is selected under the frozen weak-first rule.

### Task 3 — fresh end-to-end confirmation

Only the selected candidate proceeds. Fresh simulations cross four core rate
profiles (`nominal`, `common_lower`, `compressed`, and `expanded`) with the
Goal005 richness scenarios of 10, 25, and 40 members. Forty-eight paired
streams give four replicates in each rate-by-richness cell, 12 streams per rate
profile, and 16 per richness level.

For each stream, an outcome-isolated 52-week calibration period produces an
aggregate bivariate class artifact. The independent baseline and selected
candidate then receive identical synthetic 12-, 16-, and 26-week target
histories and four-week forecasts under the tracked effort schedule. Neither
target fit receives calibration species identities, histories, candidate
rates, membership, or truth.

The fitted target model is the existing finite-pool effort-hazard model with a
bivariate Gaussian prior for the class locations derived from the aggregate
artifact. Posterior richness and future-discovery predictions are compared
with synthetic truth, the no-data membership prior, and the paired Goal006
baseline. Twelve weeks is retained as the known unstable transition; 16 and 26
weeks are the main candidate durations.

### Task 4 — decision and empirical handoff

Independently replay the compact evidence and choose one of:

- `NO_REGULARISATION_CANDIDATE` — neither shared candidate passes Task 2;
- `CALIBRATION_ONLY` — one candidate passes Task 2 but no contiguous duration
  suffix passes the fresh downstream standard; or
- `SYNTHETIC_CANDIDATE_READY` — the candidate passes Task 2 and at least 26
  weeks passes Task 3, with any selected shorter duration followed by all
  longer durations also passing.

Under the suffix rule, 12 weeks may be selected only if 12, 16, and 26 weeks
pass; 16 weeks may be selected only if 16 and 26 weeks pass. This prevents an
isolated short-duration success from overriding a failed longer anchor.

`SYNTHETIC_CANDIDATE_READY` permits a newly prespecified Judbury calibration
and prospective-validation goal. Huon Ridge remains sealed until that empirical
goal has frozen one method and duration. The old roadmap that labelled Huon
Ridge as Goal007 is therefore superseded; external validation moves to Goal009
at the earliest.

Even a successful synthetic result would remain conditional on the stated
one-quarter prior rate ratio and its F3 or F5 uncertainty. A later empirical
goal must carry that prior transparently and retain a prespecified contrast-
centre sensitivity; Goal007 cannot turn the reviewed qualitative class labels
into independently measured quantitative encounter rates.

## Deferred scope

Goal007 does not add traits, taxonomic random effects, more encounter classes,
candidate-specific empirical calibration, site-level occupancy, spatial
borrowing, seasonal rate dynamics, reptiles, anonymous species, or a package
API. Those are possible later hypotheses, not fallback branches within this
bounded goal.

## Implementation record

The proposed Task 1 design has been encoded without reading an empirical
detection outcome. Its implementation is recorded in
[`Task1Implementation.md`](Task1Implementation.md). The minimal shared-shift
model, Stan/R bridges, leakage-safe artifact, and reduced synthetic smoke are
recorded in [`Task2Implementation.md`](Task2Implementation.md). The resumable
screen, compact gate evaluator, and independent replay are now implemented and
locally verified. The frozen 180-fit recovery screen has not been run.
