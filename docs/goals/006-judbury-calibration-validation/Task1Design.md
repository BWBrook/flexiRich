# Goal006 Task 1 — frozen empirical and decision contract

Status: proposed and executable; awaiting collaborator confirmation before
Task 2 heavy computation

Prepared: 2026-08-24

## Task decision

Task 1 fixes the evidence boundary and the complete decision surface before a
class-specific Judbury calibration or later forecast outcome is inspected. It
does not fit the calibration model or score an empirical forecast.

The executable authority is `R/goal006_contract.R`. It deterministically
generates the simulation, calibration-fit, target-fit, seed, gate, and output
contracts. Only the 90-row temporal fold table is also committed as CSV because
it is useful for direct human inspection. This avoids maintaining parallel
ledgers for information already fixed in code.

## Immutable source authority

The separate `camtrap-workflow` checkout remains read only. Goal006 no longer
requires its working tree to remain at the old Goal003 Git commit. Instead,
the six files actually used by the canonical adapter must match their content
receipts:

| Evidence | SHA-256 |
| --- | --- |
| `data/jc_obs.csv` | `deafe2af080726aa8b3ec67baca70f7f9c45b18acbfc56ceed39cb353eab5ae0` |
| `data/jc_op.csv` | `28222586fa232fccc46bfab5e8c07e0c453f07387ebe4eb95b9a90e4687033a3` |
| `data/jc_taxa.csv` | `7abcc6ff7fd49d3130b29589dc552ff45d00a8a7dfeb355d1ac61c7eb35ea18a` |
| analysis-site mapping | `6490d7f7021e5c727b9be1c7d6dfbf44ba50a1ef5b0396c66e1dd813a9c77083` |
| `R/custom_funcs.R` | `9bd5ea8508867a52dc58635b5023a9cdd8ae3fa89a7666af2555fb1579432866` |
| `R/time_utils.R` | `ec7901a10024e9833194426701a3ed7a3ef29e9cd6daf0bb9e4d405932b08067` |

The current checkout commit is recorded as provenance but is not scientific
authority when these hashes agree. The reviewed 198-row candidate worksheet
remains fixed at SHA-256
`60c8900c1904bafa34340e8ea7e2a44fc819836f76746fc7ee80c484166608db`.
The primary pool contains 50 unique candidates: 44 routine and six occasional.

The outcome-free weekly effort authority is
`config/goal003_task4_effort_template.csv`, SHA-256
`d46655701ba0427264fc40a4a568b2ee350a34e9683b1cf1daa3d67ceeaeede9`.
It contains 9 × 153 station-weeks, 7,644 active station-days, and 266
zero-effort station-weeks. Zero effort remains unsampled, not a non-detection.

Task 2 uses only the candidate classes and effort. If its synthetic gate
passes, Task 3 may mechanically create a calibration-only input containing
occasions 1--52. Later detections must not be materialised as a Goal006 run
input until Task 3 has passed. This staged input release is the practical
leakage barrier.

## Temporal folds

The committed manifest is
[`config/goal006_validation_folds.csv`](../../../config/goal006_validation_folds.csv),
SHA-256 `aa881d46343ea6ec0f15b706ad15f3e97b43783b62db9bb723e48bc9cb3f9f8e`.
It is derived from calendar and effort only.

- Calibration: occasions 1--52.
- Separation gap: occasions 53--54.
- Forecast starts: 81, 85, ..., 149.
- Forecast horizon: four occasions, with no overlap among forecast outcomes.
- Target histories: the immediately preceding 4, 8, 12, 16, or 26 occasions.
- Uncertainty unit: six season-year blocks.
- Four and eight weeks: negative controls only.
- Twelve, 16, and 26 weeks: eligible durations.

There are 18 forecasts × five durations = 90 analysis histories. Each row
records target and forecast active station-days, active stations, and
zero-effort station-weeks. The observed effort range is deliberately retained:

| Target duration | Role | Active station-days, range | Median | Minimum active stations |
| ---: | --- | ---: | ---: | ---: |
| 4 weeks | negative control | 168--252 | 226 | 6 |
| 8 weeks | negative control | 354--504 | 466.5 | 8 |
| 12 weeks | eligible | 544--756 | 692.5 | 8 |
| 16 weeks | eligible | 740--1,008 | 918 | 8 |
| 26 weeks | eligible | 1,007--1,584 | 1,493 | 9 |

Primary fold summaries never drop a scheduled history for low effort. Effort
may explain a result but cannot redefine the primary denominator.

## Calibration model fixed for Task 2

For detected calibration species (i), let (h_i) be its externally reviewed
encounter class, (alpha_i\sim N(m_{h_i},1)), and let (L_i(y_i\mid
\alpha_i,b)) be the effort-hazard detection-history likelihood. Because a
species enters the calibration sample only after at least one detection, its
contribution is

\[
\log \int L_i(y_i\mid\alpha_i,b)f(\alpha_i\mid m_{h_i},1)d\alpha_i
-
\log \int \{1-L_i(0\mid\alpha_i,b)\}
f(\alpha_i\mid m_{h_i},1)d\alpha_i.
\]

The second term is load-bearing: omitting it would fit the class distribution
as though detected species were an unselected sample. All-zero candidate
histories and membership indicators are excluded from calibration rather than
being silently treated as known absence.

The primary class priors are independent

\[
m_{routine}\sim N(\log 0.002,1.5^2),\qquad
m_{occasional}\sim N(\log 0.0005,1.5^2).
\]

Camera effects are sum-centred with half-normal scale 0.75. The biological
between-species log-rate SD is fixed at one. Priors are deliberately much
wider than F2, so passing precision cannot be manufactured directly by the
prior.

The target model retains the finite 50-candidate pool, a `Beta(1,1)` membership
fraction, the same class predictive spread, and separately estimated target-
window camera effects. It receives the joint class-location calibration but
no calibration species identity, history, membership estimate, or candidate-
specific rate.

## Task 2 synthetic recovery

The frozen recovery design has 30 datasets, ten under each of three class-rate
profiles:

| Profile | Routine median rate | Occasional median rate |
| --- | ---: | ---: |
| nominal | 0.0020 | 0.00050 |
| lower | 0.0010 | 0.00025 |
| compressed | 0.0015 | 0.00075 |

All 50 candidates are true calibration-population members. Their latent rates
retain SD one and detections use the actual first-52-week effort. Only species
with a positive simulated history enter the fitted calibration likelihood.
This isolates selection adjustment without adding membership nonidentifiability
to a mathematical recovery test. Simulation seeds begin at `610000101`; fit
seeds begin at `620000101` and are generated exactly by the contract.

Task 2 passes only if:

- deterministic value and gradient bridges agree within `1e-8` and `1e-5`;
- at least 29/30 fits are terminal clean and each profile has at least 9/10;
- maximum absolute median bias across profiles is at most 0.35 log units for
  routine and 0.50 for occasional;
- pooled RMSE is at most 0.60 and 0.80 log units, respectively;
- fixed-denominator 90% coverage is at least 25/30 for each class and at least
  8/10 within every class-profile cell; and
- fewer than two datasets are non-clean or have a factor-three error in either
  class location.

Failure stops empirical calibration. A coding defect may be repaired under a
new commit, but a scientifically clean recovery failure cannot be retuned.

## Task 3 empirical calibration gate

There are 17 prespecified logical fits: primary, a prior-SD-three sensitivity,
log-rate spreads 0.75 and 1.25, nine leave-one-station-out fits, and four
leave-one-13-week-quarter-out fits. The last group is a bounded guard against
treating temporally clustered weekly detections as fully independent. Every fit
uses the standard four-chain sampler and at most one frozen rescue. A fit is
clean only with zero divergences and treedepth hits, maximum R-hat 1.01,
minimum bulk and tail ESS 400, and minimum chain E-BFMI 0.3.

The primary fit must have at least three detected calibration species per
class and achieve, for both classes,

\[
F_h=\exp\{q_{0.975}\,sd(m_h\mid y)\}\le2.
\]

All 16 sensitivity fits must be terminal clean. Relative to primary, no class
mean may shift by more than `log(1.5)`. The wide-prior uncertainty factor must
remain at most 2.25; spread, leave-one-station-out, and leave-one-quarter-out
factors must remain at most 2.5. These wider sensitivity limits diagnose modest
robustness without misrepresenting them as primary F2 estimates.

The versioned target artifact is a bivariate Gaussian summary of the two class
locations. Against the empirical joint draws it must have:

- maximum error 0.10 log units at the marginal 2.5%, 50%, and 97.5% quantiles;
- Mahalanobis-radius Kolmogorov--Smirnov distance at most 0.10 from
  chi-square(2); and
- maximum absolute marginal skewness 0.50.

The artifact schema contains only class order, location mean and covariance,
model/prior metadata, source receipts, seed, diagnostics, and approximation
checks. It contains no candidate or species identifier, detection history, or
membership quantity.

Task 3 selects one conservative sensitivity envelope without viewing a target
outcome. Across the 16 valid sensitivity fits, severity is the larger of (a)
maximum absolute class-mean shift divided by `log(1.5)` and (b) the maximum
uncertainty-factor increase scaled from primary F2 to F2.5. The largest value
wins; ties use profile order. This single calibration-only selection retains
the most consequential observed perturbation without multiplying the target
batch across four largely redundant axes.

Any failed Task 3 gate yields `CALIBRATION_FEASIBILITY_FAIL`; later outcomes
remain unopened.

## Task 4 fits and comparators

If Task 3 passes, the frozen logical schedule contains 234 Stan fits:

- 90 primary calibrated FlexiRich fits;
- 90 conventional occupancy fits; and
- 54 FlexiRich sensitivity fits: the single calibration envelope across the
  54 eligible histories.

The negative controls receive primary FlexiRich and occupancy fits but cannot
advance irrespective of their scores. Every logical fit has a deterministic,
unique seed. Primary plus one frozen rescue is the complete sampler policy.

All methods receive identical candidate pool, target history, target effort,
and realised forecast effort. The comparators are:

1. observed richness with a point mass at zero future discoveries;
2. Chao2 and iChao2 point estimates;
3. iNEXT incidence accumulation/extrapolation;
4. conventional effort-aware multispecies occupancy; and
5. the calibrated finite-pool model's prior-only prediction, which uses the
   class artifact and future effort but no target detections.

Their mathematical and software definitions are reused unchanged from the
[Goal003 baseline contract](../003-prospective-finite-pool-validation/BaselineContract.md):
in particular, `iNEXT` 3.0.2 uses incidence-raw data at Hill order zero,
Chao2/iChao2 retain their finite-pool caps and raw estimates, and occupancy
retains its effort-hazard likelihood, priors, diagnostics, and single rescue.
Goal006 may adapt only the target-window and forecast inputs, not the comparator
definitions after outcomes are visible.

Chao2, iChao2, and iNEXT are reported only for estimands they produce; no PMF
or identity probabilities are invented. For each eligible duration and score,
the probabilistic benchmark is selected once as the lowest pooled mean score
among observed, occupancy, and prior-only predictions on the common 18 folds.
It is not reselected by fold or season.

Count predictions receive unnormalised discrete ranked probability score and
log score. Candidate identity probabilities receive Brier score over candidates
unseen in the target history. Method contrasts use all 18 paired folds. The
9,999-draw season-year cluster bootstrap uses seed `6006` and resamples the six
whole blocks; it never resamples candidates as independent observations.

## Eligible-duration decision gates

Each of 12, 16, and 26 weeks must independently satisfy all applicable rows:

1. all 18 primary FlexiRich fits are terminal clean;
2. at least four folds and at least five candidate outcomes contain a new
   detection, so prospective validation is empirically informative;
3. mean count-RPS skill over the selected benchmark is at least 10%, with a
   95% block-bootstrap lower bound no worse than -5%;
4. absolute mean count bias is at most 0.5 species, at least 14/18 central 90%
   count intervals cover, and all count log scores are finite;
5. mean identity-Brier ratio and its 95% block-bootstrap upper bound are both
   at most 1.05;
6. no season-year block has count RPS more than 25% worse than the selected
   benchmark;
7. at least 16/18 richness 90% intervals have an upper endpoint of at least
   the operational lower reference of 26 species;
8. mean posterior mass at the 50-species ceiling is at most 0.05 and no fold
   exceeds 0.20;
9. the propagated calibration envelope has median absolute richness shift at
   most three species and maximum shift at most eight; and
10. for 12 and 16 weeks, paired posterior means differ from the 26-week anchor
    by at most three species in median and eight species at maximum.

The reference and duration-stability rows are guardrails, not claims that 26
or the 26-week estimate is truth. The 26-week duration has no self-comparison
row. It must still clear every other gate.

## Task 5 release gate

If at least one eligible duration passes, the shortest is provisional. The
same calibration model is then refitted to all 153 occasions solely to create
the frozen external-transfer artifact. It must be terminal clean, retain F2
for both classes, differ from first-year class means by at most `log(1.5)`, and
pass the same 0.10 Gaussian marginal-quantile check.

Only then is the Goal006 result `READY_FOR_HUON_RIDGE`. Otherwise the outcome
is `JUDBURY_CONDITIONAL_ONLY`. A readiness decision freezes the selected
duration, first-year Judbury evidence, full-record calibration artifact,
candidate pool, model, and gates; Huon Ridge remains unopened until the next
goal.

## Compact evidence contract

The compact archive contains metadata, logical-fit status and diagnostics,
richness summaries, forecast count scores, candidate forecast probabilities,
and the complete gate table. Raw CmdStan outputs remain preserved on
`deep-server` as source evidence but are not duplicated into the compact
archive. Every remote run records Git commit, input and manifest hashes, seeds,
software versions, and whether empirical outcomes were permitted for that
stage.

No Task 1 check reads the class-specific calibration result or a forecast
outcome. The exact local verifier is:

```bash
Rscript scripts/check_goal006_task1_contract.R
```

Task 1 is closed only after collaborator confirmation of this numerical
contract. Task 2 may then implement the likelihood and synthetic recovery
without accessing empirical Judbury detections.
