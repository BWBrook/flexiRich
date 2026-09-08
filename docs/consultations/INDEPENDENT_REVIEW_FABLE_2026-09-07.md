# flexiRich: an independent critical review after Goal007

**Reviewer:** Claude (Fable 5.1), at the request of Barry Brook
**Date:** 2026-09-07
**Repository state reviewed:** `main` at `ba85b8f` (local clone of github.com/BWBrook/flexiRich)

## 0. Scope and method

I read the complete goal trail (Goal001 through Goal007: goal contracts, task designs, implementation records and decision memos), the README and AGENTS.md, the seven Stan models, the candidate-pool worksheet and frozen configuration tables, the Goal002R external consultation, and representative R source (data adapters, simulators, gate evaluators). I also re-analysed the compact result tables that are present locally under `outputs/` for Goal004 to Goal007, and ran the full R test suite.

Deliberately not read: `docs/consultations/INDEPENDENT_REVIEW_ASTRA_2026-09-07.md`, so that this review is independent of the Astra review. Also not opened: the Judbury detection tables (`outputs/goal003/judbury_inputs.rds`) or anything from Huon Ridge. Everything I say about Judbury is drawn from aggregates already declared in the project documents.

Sol's closing summary of Goal007 (supplied by Barry) was read after my own view had formed; I respond to it in section 4.5 and 5.7.

## 1. Summary verdict

1. **The engineering and research-hygiene standard is exceptional.** Frozen manifests, seeded reproducibility, hash-locked evidence, independent replay audits, a sealed external validation set and a strict no-retuning rule are far above the norm for statistical ecology. Nothing I checked contradicted a recorded result.

2. **The scientific conclusions are weaker than the documents state, because the pass/fail screens have low power to accept a correct model.** Under a perfectly specified, perfectly calibrated estimator, several of the frozen gates fail with probability 30 to 65 percent. The Goal005 Task 4 "replication failure", the Goal006 "calibration feasibility fail" and part of the Goal005 "4 and 8 weeks closed at the information ceiling" are each consistent with a well-behaved model meeting a noisy gate.

3. **The central negative result (short windows cannot estimate finite-pool richness) is real, but it was computable analytically before the first Stan fit.** Under the frozen prior rates, a routine member has a 59 percent chance of going undetected in a 224 camera-day month. Goals 003, 004 and 005 rediscovered this at a cost of roughly 2,800 Stan fits. The Goal004 Task 1 analytical screen was the right instrument, deployed two goals late.

4. **The strategic weakness is that the development dataset has been sealed from the developers.** Judbury is declared the public development dataset, yet after seven goals the model has only ever been fitted to its own simulator. No empirical check exists of the hazard model, stationarity, species-by-station heterogeneity, temporal autocorrelation or seasonal turnover. The leakage discipline appropriate to Huon Ridge has been applied to Judbury, where it blocks exactly the learning the project needs.

5. **The 4-week estimand is partly ill-posed ecologically, not just statistically.** Thirty-three of the 50 primary candidates are birds. Membership of a 153-week reference pool inferred from one month presumes that species present over three years have positive hazard in any given month. For nomadic and seasonal birds that assumption is false, and no amount of rate calibration fixes it.

6. **The most productive next step is not another synthetic screen.** It is to open Judbury for exploratory model-building, run the prospective discovery benchmark that Goal003 Task 5 and Goal006 Task 4 already designed, and redesign evaluation around calibration diagnostics and continuous scores rather than all-or-nothing gates. Huon Ridge should stay sealed for a species-level transfer test.

## 2. What the project has done well

- **Pre-registration in practice.** Each heavy run was frozen and committed before execution, with seeds, gates, denominators and output contracts fixed. Independent audit scripts replay every gate from compact evidence. I found no case where a threshold was moved after a result was seen, and several where a narrow miss was correctly left as a miss.
- **Correct diagnosis of the core problem.** By Goal003 the documents identify the membership-versus-low-rate ridge as weak identification, not a computational defect. That is the right reading and it matches the literature on richness inference for wholly undetected species.
- **Sound Stan implementations.** The marginalised membership likelihood, the sum-to-zero camera basis, the hazard-scale log-likelihood, the Jacobian for the count-scale membership prior, and the Goal006 selection-adjusted calibration likelihood are all correct as written. The numerical bridges are thorough.
- **Real methodological advances.** Goal004's independent core/fringe strata solve declared-pool dependence cleanly. The Goal006 detected-sample selection adjustment is a genuine contribution that many applied papers get wrong.
- **Good comparators.** Observed richness as a saturating null, Chao2/iChao2 with the finite cap, iNEXT, a prior-only baseline and an effort-aware community occupancy model form a fair benchmark suite.
- **Transparent handling of external evidence.** The candidate pool was built from ALA and expert review without a Judbury detection column, and the derived pool rules are frozen and auditable.

## 3. Background numbers the rest of the review relies on

### 3.1 How much can one month of cameras say about a member?

Under the frozen primary prior (routine median 0.002 per camera-day, occasional 0.0005, log-SD 1), the probability that a true member produces an all-zero history is:

| Active camera-days | Routine member undetected | Occasional member undetected |
| ---: | ---: | ---: |
| 28 | 0.92 | 0.98 |
| 125 | 0.72 | 0.91 |
| 224 (median 4-week block) | 0.59 | 0.85 |
| 504 (typical 8 weeks) | 0.38 | 0.72 |
| 700 (typical 12 weeks) | 0.30 | 0.65 |
| 1000 (typical 16 weeks) | 0.22 | 0.56 |
| 1500 (typical 26 weeks) | 0.14 | 0.46 |

An all-zero history is a likelihood ratio of about 0.6 (routine) or 0.85 (occasional) for member versus non-member at 224 camera-days. With 25 true members, roughly 15 are expected to be unseen after a month and about 11 after eight weeks. The posterior for the unseen count is therefore mostly prior at four weeks regardless of how precisely the rates are known. This single table predicts the Goal003, Goal004 and Goal005 duration results.

### 3.2 Probability that a correct model passes the frozen gates

These are computed for an estimator that is exactly unbiased with exactly nominal 90 percent intervals.

| Gate (as frozen) | Pass probability for a correct model |
| --- | ---: |
| Goal005: coverage at least 10/12 in each of three richness cells | 0.70 |
| Goal007 Task 3: coverage 13/16 in each of 3 richness levels and 10/12 in each of 4 rate profiles | 0.51 |
| Goal005: absolute median bias at most 3 in each of three cells of 12, posterior-mean error SD 5 | 0.78 |
| Goal005: fewer than 2 of 36 fits with error at least 12.5, if the true tail rate is 4 percent | 0.55 |
| Goal006: fewer than 2 of 30 factor-three occasional-class errors, estimator error SD 0.45 on top of the 0.41 finite-set floor | 0.37 |

A screen that multiplies several such rows has a pass probability well under one half for the true model. This is the property that makes the run of `STOP` decisions much less informative than the documents present them to be. It is not a criticism of pre-registration; it is a criticism of freezing gates without first checking their power.

## 4. Critical findings

### 4.1 The Goal005 Task 4 "replication failure" is not a failure to replicate

Task 3 and Task 4 fitted the same model at 12 weeks and F3 calibration to two independent sets of 36 synthetic datasets. From the compact tables:

| Run | n | Median abs error | Catastrophic (error at least 12.5) | 90 percent coverage |
| --- | ---: | ---: | ---: | ---: |
| Task 3 F3, 12 weeks | 36 | 2.95 | 0 | 0.97 |
| Task 4 unbiased F3, 12 weeks | 36 | 3.86 | 3 | 0.86 |
| Pooled | 72 | | 3 (4.2 percent) | 0.92 |

The two runs are statistically indistinguishable (Wilcoxon on absolute error p = 0.49; Fisher on catastrophe counts p = 0.24). Pooled coverage is 0.917, essentially nominal. At the pooled catastrophe rate the frozen gate "fewer than 2 of 36" fails 45 percent of the time. The decision memo's interpretation that "12 weeks marks an unstable transition" is over-reading. The estimator at 12 weeks and F3 appears well calibrated, with a heavy tail that the frozen gate was too small to measure.

The same reading applies to the F3 versus F5 "frontier" at 12 weeks. Across C0 through F5 the continuous results at 12 weeks are flat: median absolute error 2.35 to 2.95 species, coverage 0.92 to 1.00. F5 "failed" only because two fits missed the R-hat threshold. The memo says as much, but the headline "F3 frontier" nonetheless propagated into Goal006's F2 target.

### 4.2 The 4- and 8-week "information ceiling" closure rests on near-empty effort blocks

The Goal005 Task 2 memo states that exact candidate rates cannot rescue 4 or 8 weeks. From the compact tables, every one of the nine catastrophic fits at 4 and 8 weeks, under both oracles, fell in the three effort blocks with 28, 46 or 56 active camera-days and one to three active cameras (the firmware-outage block and its neighbours). Restricting the 4-week I0 oracle to blocks with more than 58 camera-days:

| True richness | n | Median signed error | Median abs error | Covered (of 9) | Median 90 percent width |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 10 | 9 | +2.3 | 2.3 | 8 | 14 |
| 25 | 9 | +5.5 | 5.5 | 9 | 19 |
| 40 | 9 | +1.4 | 3.7 | 8 | 17 |

That is a reasonable one-month estimator: honest intervals, moderate error, some upward bias at intermediate richness. The design's decision to retain the outage block was principled ("duration is not effort"), but the gates then asked a duration-level question with a denominator that includes a survey that barely happened. The two things should have been separated: report by realised effort, and gate on effort bands.

The separation gate (median high-minus-low posterior-mean separation at least 27 of 30) also deserves scrutiny. Removing the low-effort blocks does not rescue it (25.5). But this gate penalises exactly what a calibrated Bayesian estimator does with sparse data: shrink towards the prior. Demanding 90 percent recovery of the true contrast at four weeks is a demand for near-frequentist point accuracy, not for calibration. A calibrated posterior that shrinks and says so is the correct output at four weeks. The gate treats it as failure.

The honest statement is therefore: with adequate realised effort (say at least 160 camera-days and six cameras), four weeks under known rates gives a calibrated but wide posterior; the practical question is whether that width is useful for the decision at hand, which is a question for the end user, not for a synthetic gate.

### 4.3 The information limit was knowable before Goal003

Section 3.1 is a one-line numerical integral. Goal004 Task 1 eventually did the equivalent analysis (likelihood ridge maps, profile spans) and found the answer in an afternoon of compute. Goals 003 and 004 Task 4 together consumed about 1,600 Stan fits and 90 GB of sampler output to establish empirically what the integral shows. This is a planning issue rather than a statistical one: the goal cadence moved from "build the simulator" to "build the estimator" to "screen the estimator at 300 datasets" without a feasibility calculation in between. Every future goal should begin with the analytic or cheap-numerical version of its question.

### 4.4 Goal006 stopped on a gate that a correct model could not reliably pass, aimed at the wrong quantity

The Goal006 Task 2 recovery test fitted the class-location model to 30 synthetic datasets in which all 50 candidates were members and only six were occasional. The stop rule was fewer than two datasets with a factor-three error in either class location, measured against the superpopulation (generating) location.

With six occasional species and log-SD 1, the realised mean of the six latent rates has standard deviation 1/sqrt(6) = 0.41 around the generating location. No detection data can remove that: it is the floor on how well the *generating* location can be recovered from six species. Adding any estimation error at all (posterior SD 0.45 is generous for a class informed by one to four detected species) gives a total error SD near 0.6, a 7 percent per-dataset factor-three rate, and a 63 percent chance of failing the gate. The observed occasional RMSE of 0.62 is the floor, not a defect. Sol's summary correctly identifies the finite-set versus superpopulation distinction; the point I would add is that the gate was set on the target that is both unrecoverable and irrelevant. For richness at the site, only the realised six species matter.

Goal007 then added the finite-set target but combined both into a composite catastrophe rule, which can only increase the failure probability. The gate got harder while the underlying information stayed the same.

### 4.5 Goal007 and Sol's summary

I agree with most of Sol's assessment: the shared shift genuinely helps (RMSE down 16 to 25 percent), F3 over-regularises, and the `no_separation` stress exposes overconfidence when the class contrast prior is wrong. Three additions:

- The `no_separation` truth sits 1.7 prior standard deviations from the F5 contrast centre and 2.5 from the F3 centre. Five-of-ten coverage under a 1.7 to 2.5 SD prior misspecification is the expected behaviour of any regulariser. The gate tested whether regularisation regularises. The scientific question is whether a fourfold ratio is credible, and that is an empirical question about Tasmanian ground-camera encounter rates.
- The data that answer it have been sitting sealed in the repository since Goal003. Twenty-six primary-pool species were detected over 153 weeks at Judbury. Their per-species encounter rates would say directly whether the expert "occasional" label tracks lower rates, and by how much. Two to four of the six occasional species were probably detected. That is thin, but it is real evidence rather than a prior.
- Sol's preferred next step (a continuum diagnostic of F5 with more replicates, propagated to richness) is defensible but low-value relative to opening Judbury. If it is run, use at least 50 replicates per cell, make richness and discovery the outcomes, and include a conflict-robust contrast (a Student-t or a two-component mixture on kappa) as a third arm, since that is the obvious fix for the failure mode observed.

### 4.6 The strategic error: sealing the development dataset

Goal001 fixed that Judbury is the "public development and primary empirical dataset" and Huon Ridge the held-out external validation. That is the right split. But from Goal003 onward, Judbury detections were treated as sealed outcomes behind synthetic gates, and every synthetic gate has stopped. The consequences:

- **The model has never met real data.** All screens except Goal003's misspecification scenarios and Goal004's weak/flipped labels generate data from the model's own family. Even the "misspecified" scenarios are variations the developers imagined. Real Judbury features never simulated include species-by-station heterogeneity (a species using two of nine stations), within-species temporal clustering (a resident camping near one camera), seasonal presence and absence of birds, and rate non-stationarity across three years.
- **The generative model cannot be checked.** Nobody knows whether the lognormal class-rate assumption, the constant-hazard weekly incidence model, or the common camera effect resemble Judbury. The detection-frequency spectrum (species seen in one, two, three station-weeks and so on) is the standard diagnostic and it has never been computed.
- **The stationarity assumption is load-bearing and untested.** Section 4.7 below argues it is probably false for many birds. The Judbury record is the only place to find out.
- **Class calibration was pursued synthetically when it was available empirically.** Goals 005 through 007 built machinery to learn class locations from an outcome-isolated first year. The natural design for Huon Ridge transfer is to estimate species-specific rates from all 153 Judbury weeks and carry them across. That path was never framed because the roadmap put Huon Ridge last and Judbury's own later windows as the intermediate target, which forced the identity-stripping class artifact.

The leakage concern is legitimate for a confirmatory claim about Judbury forecasts. It is not legitimate for model development on the development dataset. The fix is to declare, once, that Judbury is open for exploratory analysis and generative-model building, that any confirmatory claim on Judbury will be reported as in-sample, and that Huon Ridge remains the sole confirmatory test. The current arrangement has the developers flying blind while the one sealed dataset that matters, Huon Ridge, is not yet in play.

### 4.7 The estimand at short windows is partly ill-posed

The estimand is the number of the 50 named candidates with a positive camera-encounter hazard on the grid over the 153-week reference period. The model then infers it from a 4-, 8- or 12-week window under the assumption that membership and rates are constant across the whole period. Consider the pool: 33 birds and 17 mammals in the primary set, including Flame Robin, Scarlet Robin, Common Starling, Swamp Harrier, Brown Falcon, Pink Robin and other species with strong seasonal or nomadic movement in Tasmania. For such species, zero hazard in a given month is the ecological truth, not a detection failure. The 153-week pool and the 4-week pool are different quantities, and the difference is turnover, not detection.

This has two implications. First, part of the four-week "failure" is definitional and cannot be fixed by calibration. Second, the estimand should be stated with a time scope that matches the window, or the model needs an availability layer. Both versions are useful; conflating them is not. The prior mass on "member with low rate" is also doing double duty as "member not present this month", which is why the rate prior is so load-bearing.

### 4.8 Model-structure gaps worth naming

- **No species-by-station heterogeneity.** The FlexiRich models use a common camera effect plus a species effect. The occupancy comparator has species-specific site use. If a member uses only two stations, the FlexiRich model overstates its grid detection probability, concludes too confidently that all-zero candidates are non-members, and produces overconfident low richness. This is the most plausible real-data misspecification and it was never simulated.
- **Fixed class spread.** Log-SD 1 is fixed throughout and never learned or stress-tested beyond 1.25. A heavier lower tail (a few near-undetectable members) is the classic way richness estimators fail.
- **A binary class structure.** Six species is too few to define a class. Sol's point 3 is right. The obvious alternative is species-specific external information, which the Judbury record supplies for 26 species.
- **The uniform richness prior is not weak at four weeks.** With 11 detected and 39 all-zero candidates whose likelihood ratios are near 0.6 to 0.85, the posterior on the membership fraction is pulled toward the middle and the unseen count is largely prior. The "lower-bound-conditioned prior" comparator illustrates the same mechanism in the opposite direction (means of 47 to 49 at Judbury). Reporting should make the prior's share of the posterior explicit, as the Goal004 memo already recommends.
- **Chao2 as a comparator.** Chao2 estimates the asymptotic richness of the sampled community, not membership of a named pool. It is fine as a transparent reference but should not be scored against the finite-pool truth as if it targeted the same quantity.

### 4.9 Process weight

The repository holds about 570 KB of design and decision Markdown, 45,000 lines of R, 57 test files, and about 3,100 completed Stan fits across seven goals, with no empirical result yet. The documentation is excellent as an audit trail and very hard to hold in one head as a scientific programme. The risk in an agent-driven workflow is that the PI approves designs whose statistical properties (section 3.2) nobody has checked, because the design is long and looks rigorous. Two concrete guards: every gate table should carry a "pass probability under a correct model" column before it is frozen; and decision memos should be limited to two pages with a stable one-paragraph "what we now believe and why" at the top.

### 4.10 Smaller technical notes

- **Goal002R.** The external consultation judged the collapsed formulation sound and recommended a bounded decision-scale experiment. The project closed the path on a 1e-9 absolute derivative tolerance. That was a misapplied gate, though moot now: with fixed class-rate priors (Goal004 onward) the ridge that motivated 002R is gone, and the Goal006 selection integral already computes the collapsed all-zero probability for each class. The Goal004 Stan model still samples a latent rate for every undetected candidate; the exchangeable-within-class Binomial collapse would be a cheap simplification.
- **Occupancy comparator failures.** Twelve of 180 occupancy fits in Goal004 failed on R-hat or ESS after rescue. That is a property of the comparator's learned hyperparameters on sparse data and should be reported as such, not as a gate the candidate fails.
- **Environment.** `renv::status()` reports the project as out of sync. The test suite ran regardless (result in section 6).
- **Effort template.** The 153-week template has a near-gridwide outage from about occasion 25 to 38 (7 to 16 active camera-days per week). Any duration recommendation must be phrased in realised camera-days and active stations, as the documents already insist.

## 5. Where the science can productively go

In priority order.

### 5.1 Open Judbury for exploratory analysis and generative-model building

Declare Judbury the development dataset in practice. Then, with the existing adapters:

1. Compute per-species encounter rates for the 26 detected species over 153 weeks, with uncertainty, and compare them with the routine/occasional labels. This directly tests the fourfold contrast that Goal007 was forced to assume.
2. Produce the detection-frequency spectrum (species by number of positive station-weeks) and compare it with posterior predictive spectra from the FlexiRich and occupancy models.
3. Test stationarity: species accumulation by season and year, per-species presence by season, and whether the 4-, 26- and 52-week detected sets are nested subsets or show turnover.
4. Quantify species-by-station heterogeneity: for each detected species, how many of the nine stations ever record it, versus the model's implied distribution.
5. Rebuild the simulator so that its default scenarios are Judbury-shaped in these respects, then rerun the cheapest existing screen to see which conclusions survive.

None of this is a confirmatory claim, so none of it needs a gate. Report it as exploratory, exactly as one would with any development dataset.

### 5.2 Run the prospective discovery benchmark that has already been designed

Goal003 Task 5 and Goal006 Task 4 designed a rolling-origin benchmark: given data to a cutoff, predict the number and identities of species first detected in the next four occasions, scored by RPS and Brier with season-year block bootstrap. The outcomes are observable; no latent truth is needed. This is the empirical core of a paper and it was blocked only because synthetic gates stopped upstream. Run it now with every comparator (observed richness, Chao2/iChao2, iNEXT, occupancy, prior-only, Goal004 FlexiRich, and a species-rate-informed FlexiRich variant from 5.1) at 4, 8, 12, 16 and 26 weeks. Report it as in-sample development evidence on Judbury. If nothing beats the zero-new-species null at four weeks, that is a publishable finding about snapshot surveys.

### 5.3 Replace all-or-nothing gates with calibration diagnostics and powered tests

- Use simulation-based calibration (rank histograms or PIT values of the true richness under the posterior) as the primary correctness check for each model. It answers "is the posterior calibrated" without arbitrary thresholds and detects both computational and model-family problems.
- Report continuous metrics with uncertainty (median absolute error with bootstrap intervals, coverage with binomial intervals, RPS skill with paired intervals) rather than binary rows.
- Before freezing any remaining gate, compute its pass probability under a correct model by simulation and require it to exceed, say, 0.9. Section 3.2 shows how far the current gates are from that.
- Prefer fewer scenarios with more replicates (50 or more per cell) over many cells with 10 to 12. Tail-event gates (catastrophes) need hundreds of replicates or should be replaced by a continuous tail statistic.

### 5.4 Re-express the estimand and the output

- Distinguish window-scoped richness (species with positive hazard during the survey) from reference-period richness (species with positive hazard over the reference period). Report which one a given analysis targets. Longer windows converge; short windows do not, and the gap is ecology.
- Make per-species posterior use probabilities, shown alongside their priors, the primary output. Richness is a derived summary. For most all-zero candidates the posterior is close to the prior at short windows, and users should see that.
- Report richness as a prior-conditional envelope (posterior under the frozen rate prior plus the two one-factor rate sensitivities) rather than a single interval. The Goal004 memo already recommends this; it should become the default.
- State any duration recommendation in realised camera-days and active stations, never in calendar weeks alone.

### 5.5 Design the Huon Ridge test as species-level transfer

The Goal005 oracle results show that when rates are known (I0) the model is well behaved at 12 weeks and beyond, and reasonable at 4 weeks with adequate effort. Species-specific rates estimated from 153 Judbury weeks are the closest real analogue of I0 for a new Tasmanian site. The confirmatory design is therefore:

1. Estimate species-specific encounter rates (with uncertainty and a transfer inflation) from all of Judbury.
2. Freeze the model, the prior, the durations (12, 16, 26 weeks; 4 and 8 as negative controls) and the scoring rules.
3. Apply to Huon Ridge windows, score against Huon Ridge's own long-duration detected pool (one-sided, as the documents already propose) and against prospective discoveries.
4. Report Huon Ridge as the only confirmatory result.

This needs Huon Ridge to have a long enough record for the long-pool reference; that is a question for Barry (section 7).

### 5.6 Model extensions, in order of expected value

1. Species-by-station heterogeneity, at least as a diagnostic comparison with the occupancy comparator on Judbury, and as a simulator scenario.
2. A heavy-tailed or two-component class-rate distribution, to stress the lower tail honestly.
3. A seasonal availability layer for birds, or a restriction of the primary pool to resident species, with migrants as a declared secondary stratum.
4. Candidate-specific external priors (from Judbury or literature), replacing the binary class structure where possible.
5. Only then, robust borrowing across classes (Student-t contrast), if a class structure is still needed.

### 5.7 Publication strategy

Two papers are available now.

- **A methods and design paper:** "How long must a camera survey run to estimate camera-detectable richness of a named pool?" The analytic bound (section 3.1), the oracle frontier (Goal005 Task 2 reanalysed by effort), the calibration-precision flatness at 12 weeks and beyond, the selection-adjusted calibration likelihood, and the honest conclusion that snapshot surveys estimate a lower bound. This is publishable as a negative and boundary result and it is nearly written.
- **An empirical paper:** the Judbury prospective benchmark (5.2) plus the Huon Ridge transfer (5.5), with the reframed estimand (5.4).

Framing the seven `STOP` decisions as a sequence of failures undersells them. Framed as a mapped frontier with an analytic explanation, they are a result.

## 6. Verification performed

- All quantitative claims in section 4 were recomputed from the compact CSV tables under `outputs/goal005`, `outputs/goal006` and `outputs/goal007`. The R snippets are in the appendix.
- The full R test suite was run from the repository root with `Rscript scripts/run_tests.R`. Outcome: see the addendum at the end of this file.
- No Stan model was refitted and no Judbury detection outcome was read.

## 7. Questions for Barry

1. Was sealing Judbury from Goal003 onward a deliberate PI decision, or did it emerge from the agent's leakage rules? The answer changes how much of section 4.6 is a process recommendation versus a scientific one.
2. What is the intended use case: a new-site one-month snapshot survey, repeat monitoring at a known site, or both? The recommended designs differ.
3. How long is the Huon Ridge record, and does it have its own multi-year detected pool to serve as a one-sided reference?
4. Is the 50-species primary pool meant to include seasonal and nomadic birds as reference-period members? If so, the estimand needs an availability layer; if not, the pool should be split.
5. How much more heavy compute is acceptable? Everything in 5.1 and 5.2 runs on the existing deep-server pattern within a day or two of wall time; the value is in what is fitted, not in how much.

## Appendix: reproducible calculations

Miss probabilities (section 3.1):

```r
m0 <- function(days, med, sd = 1) {
  integrate(function(z) exp(-days * med * exp(sd * z)) * dnorm(z), -8, 8)$value
}
sapply(c(28, 125, 224, 504, 700, 1000, 1500), m0, med = 0.002)
sapply(c(28, 125, 224, 504, 700, 1000, 1500), m0, med = 0.0005)
```

Gate pass probabilities for a correct model (section 3.2):

```r
pbinom(9, 12, 0.9, lower.tail = FALSE)^3                # Goal005 coverage rows
pbinom(12, 16, 0.9, lower.tail = FALSE)^3 *
  pbinom(9, 12, 0.9, lower.tail = FALSE)^4              # Goal007 Task 3 coverage rows
mean(replicate(2e4, abs(median(rnorm(12, 0, 5))) <= 3))^3   # bias rows, error SD 5
pbinom(1, 36, 0.042)                                    # catastrophe row at pooled rate
tot <- sqrt(0.408^2 + 0.45^2); pbinom(1, 30, 2 * pnorm(-log(3) / tot))  # Goal006
```

Goal005 Task 2 catastrophes by effort block and Task 3 versus Task 4 F3 comparison (section 4.1, 4.2): join `richness-scores.csv` to `dataset-status.csv` on `dataset_id`, filter `run_role != "prior_only"`, and tabulate `absolute_error >= 12.5` against `training_active_camera_days` and `active_camera_count`; then `wilcox.test` on `absolute_error` and `fisher.test` on the catastrophe counts for `information_level == "F3"`, `train_occasions == 12` (Task 3) versus `information_level == "unbiased"` (Task 4).

## Addendum: test-suite result

`Rscript scripts/run_tests.R` completed from the repository root at `ba85b8f` with exit code 0. All 57 test files ran with no failure, warning, skip or error reported. `renv` reported the project as out of sync at startup but every test still loaded and passed; the lockfile should be reconciled before the next frozen run.
