# Independent scientific review — flexiRich after Goal007

**Reviewer:** Codex, independent side conversation (Astra review), 7 September 2026.  
**Snapshot:** local `main`, `560bbc0da4bf5428f091da2031a15f5516e7c79e`.  
**Status:** advisory review, not a new goal, approval, or replacement decision. The historical stops stand. No model, gate, dataset, or analysis output was changed. No empirical Judbury detections or Huon Ridge data were opened.

## 1. Scope and recommendation

**Recommendation: APPROVE WITH CHANGES for continued research; not approval for empirical deployment or a validated-estimator claim.**

There is a worthwhile project here. The current effort-aware, finite-pool model is substantially more defensible than the original illustrative `flexiRich` code. But I would change the next experiment before changing the statistical model again.

My principal concern is that the programme is becoming very good at enforcing its tests without sufficiently testing whether those tests address the ecological decision. Recent work has concentrated on recovering the average encounter rate of a hypothetical population of species. That is related to, but not identical to, estimating how many of the **particular named species** use Judbury. Some of the difficulty is unavoidable sparse information; some is imposed by the chosen information boundary and intermediate requirements.

The most consequential findings are:

1. The planned same-species calibration transfer does not preserve the dependence created by persistent species rates. Removing species identities does not remove that dependence.
2. Six occasional species impose a substantial information limit on a group-average rate. An earlier factor-two precision gate was more demanding than a simple complete-data benchmark could achieve.
3. The latest screen never measured downstream richness. Moreover, six occasional candidates cannot, by themselves, account for earlier richness errors exceeding twelve species.
4. Small simulation cells and many all-or-nothing gates make the apparent duration and calibration boundaries considerably less precise than their labels suggest.
5. The ecological assumptions about persistence, space, season, and transfer remain less tested than the numerical machinery.

This was a bounded methods-and-evidence review, not a repository-wide software or security audit. I examined the Goal003 estimand/model contract; Goal005 oracle, calibration, and replication decisions; Goal006 calibration design and implementation; Goal007 design, Stan model, recovery code, and compact results. I independently recalculated selected results using base R. I did not rerun Stan, the complete test suite, the remote archive reconciliation, or the earlier independent audits.

The `independent-reviewer` skill informed the separation of verified findings, design concerns, and proposed tests below.

## 2. What is sound, and what the results actually establish

### Foundations worth retaining

- A finite, externally reviewed candidate pool avoids the original unbounded invisible-species problem. It does not eliminate the distinction between absence and extremely low encounter rate.
- Operational effort belongs in the likelihood. The current hazard formulation handles unequal uptime coherently; rounding effort-standardised counts would not.
- Marginalising genuine binary membership is valid. The present code does not repeat the original continuous pseudo-presence error: detected species have membership probability one, and all-zero histories are mixtures of absence and missed membership. See [the target Stan model](/home/bwbrook/papers/flexiRich/stan/goal005_class_calibration.stan:80).
- The detected-only calibration likelihood includes the appropriate selection normaliser for its stated conditional sampling model. I found no obvious algebraic defect in that construction. See [the calibration likelihood](/home/bwbrook/papers/flexiRich/stan/goal007_shared_shift_calibration.stan:119).
- Frozen seeds, preserved failures, paired datasets, proper distributional scores, and independent arithmetic replay are valuable. Keeping Huon Ridge available for a genuinely external test is particularly important.

None of this makes the model biologically established. Richness sensitivity to the assumed occurrence/detection distributions is already a documented problem in community modelling; a finite pool reduces one aspect of it rather than making it disappear. [Guillera-Arroita, Kéry & Lahoz-Monfort (2019)](https://pmc.ncbi.nlm.nih.gov/articles/PMC6362448/).

### Latest verified result

From the preserved Goal007 CSVs, all 180 fits were terminal-clean. For the 50 core datasets:

| Model | Occasional generating-mean RMSE | Occasional realised-set RMSE | Generating-mean 90% coverage |
| --- | ---: | ---: | ---: |
| Independent | 0.5581 | 0.5705 | 50/50 |
| Shared F5 | 0.4374 | 0.4645 | 50/50 |
| Shared F3 | 0.4176 | 0.4777 | 49/50 |

F5 failed the maximum core-profile occasional bias gate, 0.5338 versus 0.5000, and the no-separation coverage gate, 5/10 versus at least 7/10. F3 failed those two gates and the stress catastrophe gate. These values agree with [the recorded decision](/home/bwbrook/papers/flexiRich/docs/goals/007-rare-encounter-regularisation/Decision.md:43).

The defensible conclusion is narrow: **these two priors improve average calibration error but show concerning shrinkage under an incorrect class contrast. They did not meet this screen's deployment standard.** It is not yet established that either worsens richness, that a more flexible prior would improve richness, or that real occasional species require a different biological classification. Task 3 was not run; the simulated profiles stipulated the biology being tested.

## 3. Findings, ranked by consequence

### F1 — MAJOR: the planned calibration transfer mixes two different prediction problems

**Evidence.** [Goal007 Task 3](/home/bwbrook/papers/flexiRich/docs/goals/007-rare-encounter-regularisation/Task1Design.md:150) explicitly preserves each candidate's latent rate across calibration and target periods, but discards its identity and rate estimate. The [artifact boundary](/home/bwbrook/papers/flexiRich/docs/goals/007-rare-encounter-regularisation/Task1Design.md:176) retains only the two class means and covariance. The existing [target hierarchy](/home/bwbrook/papers/flexiRich/stan/goal005_class_calibration.stan:74) then samples target species effects from the class distribution and updates the class means again.

This is not just a conservative loss of information. It changes the assumed dependence.

For calibration data \(C\), later data \(T\), and a persistent species effect \(\alpha_i\), a coherent likelihood contains

\[
\int p(C_i\mid\alpha_i)p(T_i\mid\alpha_i)
       p(\alpha_i\mid m)\,d\alpha_i.
\]

Passing only \(p(m\mid C)\) and treating the later effect as a new independent draw instead uses the structure

\[
\left[\int p(C_i\mid\alpha_i)p(\alpha_i\mid m)d\alpha_i\right]
\left[\int p(T_i\mid\alpha'_i)p(\alpha'_i\mid m)d\alpha'_i\right].
\]

Those expressions are generally different. Calendar separation prevents overlap of observations, but does not turn the same species into independent draws from the species distribution.

**A simple counterexample.** Suppose both periods reveal the same six latent rates perfectly, between-species variance is one, and the prior variance of the class mean is \(1.5^2\). The correct posterior SD is

\[
(6+1/1.5^2)^{-1/2}=0.3939.
\]

Counting those six persistent rates as six new independent draws in the second period gives

\[
(12+1/1.5^2)^{-1/2}=0.2835.
\]

That extra precision is not new information about the class distribution. This is an analytical counterexample, **not a measured inflation factor for the unfinished Goal007 downstream model**. It does not invalidate Task 2 or Goal005's externally generated calibration experiments.

**Minimal correction.** Explicitly separate the intended uses:

| Use | Legitimate information | Dependence to preserve |
| --- | --- | --- |
| Revisit Judbury | Earlier identities, histories, and uncertain species rates | Same species and potentially persistent camera effects |
| Survey a new reserve | External ecological information and source-site calibration | Shared species traits/rate tendencies plus uncertain site differences |
| Transfer only a generic class distribution | Class-level calibration without identities | An explicit assumption about exchangeability and source–target dependence |

For the first use, retain the relevant joint posterior or fit the two periods jointly with persistent species effects. Past observations are not future-outcome leakage. They establish past detection, not automatically current membership if membership can change. A deliberately modular or no-feedback analysis is possible, but its changed inferential target and uncertainty need stating; a reduced artifact does not itself establish independence.

**Suggested test.** Add the six-species complete-data example as a mathematical check of the proposed transfer design. Then compare persistent-rate and genuinely independent-rate synthetic experiments. Do this before another large transfer batch.

### F2 — MAJOR: a group-average precision target is constrained by the number of species, not just camera-days

**Evidence.** The independent calibration fixes species log-rate SD at one and uses prior SD 1.5; [Goal006 required factor-two precision](/home/bwbrook/papers/flexiRich/docs/goals/006-judbury-calibration-validation/Task1Design.md:165) for each class. Only six candidates belong to the occasional class. The [simulator](/home/bwbrook/papers/flexiRich/R/goal006_simulation.R:54) draws one latent rate per species, not a new independent species rate each week.

Even if all six occasional rates were observed without error, the elementary Gaussian complete-data calculation above gives a nominal 95% uncertainty factor

\[
F=\exp(1.959964\times0.3939)=2.164.
\]

For three species it is 2.875; for one, 5.108. Under that complete-data benchmark, at least eight independent species draws are needed to get below two with the stated prior. This calculation diagnoses the information demand; it is not a universal bound for every selected-sample likelihood or alternative prior.

Longer monitoring can estimate each species' rate more accurately. It cannot indefinitely improve the estimate of a hypothetical species-population mean once those individual rates are known. Stronger borrowing can add information, but it adds assumptions as well.

The Goal007 CSVs make the practical limitation visible: in the ten `expanded` datasets, only zero to three occasional species were detected, despite all six being true members and a year of calibration effort. The later proposed richness-10 experiments have only **one** true occasional member.

**Qualification.** Goal006 actually stopped at the earlier recovery screen, not at this precision gate. Goal007 subsequently removed the F2 requirement. I am not proposing its removal again or attributing the recorded Goal006 stop to an unexecuted gate. The lesson is that oracle feasibility checks should precede expensive requirements about nuisance parameters.

**Minimal correction and test.** Evaluate precision for the quantities needed by the ecological decision: candidate-specific missed-detection probabilities and their combined richness consequences. Keep class-mean uncertainty as a diagnostic. For every future precision gate, calculate an appropriate complete-data benchmark first.

### F3 — MAJOR: the screen conflates estimation targets and has not established the cause of large richness errors

**Evidence.** [The recovery code](/home/bwbrook/papers/flexiRich/R/goal007_recovery.R:164) compares the same posterior class-mean estimate both with the generating mean and with the realised mean of the finite species set. [The catastrophe rule](/home/bwbrook/papers/flexiRich/R/goal007_recovery.R:243) fails a dataset if either error exceeds a factor of three.

Both comparisons can be useful. They are not interchangeable accuracy tests. If

\[
\alpha_i\sim N(m,1),\qquad n_O=6,
\]

the realised occasional mean differs from \(m\) with SD \(1/\sqrt6=0.4082\), even before observation error. An estimator of the realised mean should have its own posterior derived from the latent species effects; it is not automatically the posterior median of \(m\).

Both shared models' two core catastrophes occurred in `expanded-r01` and `expanded-r03`. For F5, errors against the generating means were 0.7060 and 0.6429, while errors against the realised means were 1.2421 and 1.4371. The generating means were inside both 90% intervals. These are real large deviations against the finite-set target, but not failed estimation of that target by a model actually reporting its posterior.

There is a second, more ecological problem. The [earlier downstream replication](/home/bwbrook/papers/flexiRich/docs/goals/005-duration-calibration-frontier/Task4Decision.md:46) had richness errors of 12.84, 13.30, and 15.79 species. There are only six occasional candidates. Holding routine-species inference fixed, even completely changing occasional membership can change richness by at most six.

Therefore substantial routine-species error, or feedback affecting routine species, must also be involved. The [shared membership fraction and camera effects](/home/bwbrook/papers/flexiRich/stan/goal005_class_calibration.stan:50) provide possible routes for such feedback. Which route matters has not been demonstrated by recovering occasional class means alone.

**Minimal correction.** Report \(S_R\), \(S_O\), and \(S=S_R+S_O\), alongside the posterior missed-detection probabilities of unseen candidates. Separate generating-mean recovery from finite-set prediction. Retain calibration failures as warnings rather than assuming each is a demonstrated richness catastrophe.

**Suggested test.** On a small, newly declared diagnostic experiment, compare four controlled cases: both rate classes uncertain, occasional rates known, routine rates known, and both known. Preserve the same datasets and membership model. This directly tests whether repairing occasional rates can solve the actual large-error mechanism. A follow-up comparison of common versus class-specific membership assumptions is warranted only if the decomposition points there.

### F4 — MAJOR: the gate system is more decisive than the simulation precision supports

**Evidence.** [Goal007's core criteria](/home/bwbrook/papers/flexiRich/docs/goals/007-rare-encounter-regularisation/Task1Design.md:81) use ten replicates per profile, require coverage of at least eight in each class–profile cell, and combine numerous requirements with an all-pass rule. Goal005 closed the eight-week individual-rate oracle when its separation was 26.808 against 27, while the twelve-week class oracle passed at 27.034. See [the duration decision](/home/bwbrook/papers/flexiRich/docs/goals/005-duration-calibration-frontier/Task2Decision.md:54).

At true coverage 0.90, ten independent replicates give a Monte Carlo standard error of 0.0949. A genuinely 90%-covering method has a 7.02% probability of covering fewer than eight times. If ten such cell decisions were independent, the probability of at least one failure would be 51.7%. The actual cells share data, so **51.7% is an illustration, not the false-stop probability of this experiment**.

This does not excuse the no-separation result. Coverage of 5/10 is concerning: its exact 95% binomial interval is approximately 0.187–0.813, and the probability of five or fewer successes under coverage 0.90 is 0.00163. The two shared candidates failed on the same five stress datasets, so they are not independent replications of that finding.

The proper distinction is between retaining a prespecified operational stop and treating it as a sharp scientific boundary. Likewise, the individual-rate oracle remains a particular Bayesian estimator with uncertain camera effects and a specified membership prior. Its gate failure is not an impossibility theorem for every estimator or survey at that calendar duration.

**Minimal correction.** In the next design, use a small set of primary ecological endpoints; label the others diagnostic or safety checks. Attach Monte Carlo uncertainty to error, coverage, and paired method differences. Separate numerical non-completion from large scientific error even if both count against operational reliability. This follows standard simulation-study guidance on estimands and Monte Carlo uncertainty. [Morris, White & Crowther (2019)](https://pmc.ncbi.nlm.nih.gov/articles/PMC6492164/).

**Suggested test.** Use approximately 100 independent ecological replicates for one or two decisive contrasts if three-percentage-point coverage precision is adequate, rather than ten replicates across many gates. Choose that precision prospectively. Report risk against active camera-days and spatial coverage as well as weeks; retain outages rather than filtering difficult blocks away.

Keep every historical pass/fail unchanged. It is scientifically legitimate to learn from an earlier screen and design a new one. More seeds alone do not make a repeatedly revised question independent confirmation.

### F5 — MAJOR: ecological transport assumptions remain largely untested

**Evidence.** The [latest simulator](/home/bwbrook/papers/flexiRich/R/goal006_simulation.R:68) generates centred camera effects and conditionally independent observations with hazard \(\exp(\alpha_i+b_j)\). The shared calibration [uses the same additive structure](/home/bwbrook/papers/flexiRich/stan/goal007_shared_shift_calibration.stan:85). Thus a camera that raises the rate for one species raises it by the same factor for every species, and the latest screen changes class locations but retains the specified log-rate distribution and temporal process.

Real cameras can favour one taxon while disfavoring another; species can use only part of the reserve; ground use and activity can vary by season; and repeated detections can remain correlated after event grouping. Constant total exposure is not equivalent to spatially representative or seasonally representative exposure. The shared species–camera structure is a useful baseline, but cannot establish robustness to these processes by simulating itself more extensively.

There is an important estimand qualification. [Goal006 explicitly targets the 153-week pool](/home/bwbrook/papers/flexiRich/docs/goals/006-judbury-calibration-validation/Goal.md:42). For that target, the 26 detected species are a legitimate operational lower reference, not a mistaken demand that every short window contain 26 species. However, inferring that long-period pool from a short constant-hazard window requires assumptions about seasonal availability and persistence. A species active only outside that window is not rescued merely by a more accurate annual class mean. If the estimand changes to window-specific use, the long-record count is no longer a lower bound for it.

**Minimal correction and tests.** Keep the existing model as a baseline. Before adding model layers, use one species-by-camera interaction stress and one seasonal/intermittent-use stress, chosen for ecological relevance. Test whether their resulting bias would alter the monitoring decision. In a separately approved development phase, inspect an explicitly designated early Judbury block for the corresponding patterns while leaving later forecasts and Huon Ridge protected. No such opening was performed here.

## 4. Improved or alternative approaches worth considering

These are ranked options, not a proposal to implement all of them.

### First choice: an identity-preserving repeat-monitoring model

For the question “what does a new short Judbury survey tell us, given what we already learned there?”, use earlier species histories. Start with persistent species effects and an explicit definition of membership. Add seasonal or period deviations only when the diagnostic evidence warrants them. Fit jointly, or carry forward a sufficient joint posterior over the relevant shared latent quantities.

This tests the actual value of long-running cameras as calibration infrastructure. It also supplies a clear contrast with a genuinely uncalibrated snapshot survey. Any gain must be labelled partly a gain from extra historical information; it is not automatically an estimator superiority claim. Give competing calibrated methods access to the same authorised history.

For Huon Ridge, allow an uncertain reserve-level change and, if supported, species-specific transfer deviations. Same species does not imply identical encounter rates at a new reserve. One Judbury reserve cannot identify the distribution of between-reserve transfer effects; Huon provides an external case, not universal replication across landscapes.

### Second choice: a transparent detectability-to-membership benchmark

The most directly useful calibration quantity is a candidate's chance of being missed over a specified survey, not necessarily the class median log rate.

Let \(d_i\) indicate whether candidate \(i\) was detected at least once, and let \(p_i\) be its probability of at least one detection if it is a member, for the specified effort and camera arrangement. With known \(p_i\), exchangeable membership probability \(\omega\), and \(D=\sum_i d_i\),

\[
L(\omega)\propto\omega^D\prod_{i:d_i=0}(1-\omega p_i).
\]

For an unseen candidate,

\[
P(g_i=1\mid d_i=0,\omega,p_i)
=\frac{\omega(1-p_i)}{1-\omega p_i}.
\]

A one-dimensional integration over \(\omega\) gives a small, inspectable benchmark; the conditional richness distribution follows from the unseen membership probabilities. This is not a novel richness theory. It is a useful way to expose where uncertainty enters and to test the more complex implementation. Known \(p_i\) is an oracle assumption, not an empirical fact. Extending it to uncertain calibration must preserve shared uncertainty and same-species dependence, not plug in independent point estimates.

Under the current hazard model,

\[
1-p_i=\exp\{-B\exp(\alpha_i)\},\qquad
B=\sum_{jk}E_{jk}\exp(b_j).
\]

With uncertain rates, the relevant quantity is an expectation of this nonlinear function. It is not determined by a class mean alone. This suggests evaluating calibration on missed-detection probabilities at realistic efforts as an intermediate diagnostic that is much closer to richness.

### Third choice: offer survey-relevant inference when total richness remains weak

Maintain observed richness and the posterior for total camera-encounter richness, but make the predicted number and identities of additional species under a specified future deployment a primary operational product. That is directly observable and can support a decision about extending a survey.

An optional, explicitly different estimand is expected detected richness under a standard design \(E^*\):

\[
R(E^*)=\sum_i g_i\{1-\exp[-H_i(E^*)]\}.
\]

This discounts species that are effectively invisible to that design without claiming they are absent. It must be called standardised expected detected richness, not silently substituted for total richness. Predictions of near-term discovery likewise do not prove accuracy for an invisible tail.

### Possible later extension: robust borrowing, with modest expectations

A heavy-tailed contrast prior or a predeclared mixture of stronger and weaker borrowing could reduce shrinkage when the two classes conflict. It deserves consideration **after** F1–F3 are addressed, not as the automatic next fix.

There are only two classes and one between-class contrast. The 44 routine species inform the routine mean; they do not independently tell us the occasional–routine contrast. Sparse occasional data may be unable to identify conflict, so an “adaptive” procedure can still be strongly prior-driven. A more elaborate prior does not create the missing biological information. Nor should it be selected to turn the existing `no_separation` simulations green.

## 5. Suggested bounded next tranche

I would ask the main thread to agree on **one small diagnostic tranche**, before commissioning another broad regularisation screen:

1. **Clarify the use case and retained information.** Prefer same-grid repeat monitoring as the first application; distinguish it explicitly from new-reserve transfer and an uncalibrated snapshot. Retain the 153-week estimand unless there is a substantive decision to change it.
2. **Check the dependence and information benchmarks.** Use the complete-data Gaussian calculation and a fixed-detectability membership benchmark. These are cheap and should precede Stan grids.
3. **Trace the actual richness failure.** On a compact new paired experiment, decompose routine/occasional error and use the rate-oracle comparisons in F3. Compare a coherent identity-preserving model with the existing aggregate approach as a labelled diagnostic, not as a way to reverse Goal007.
4. **Make the next decision from ecological outputs.** Does the revised information use reduce consequential richness error and improve or maintain discovery calibration? If not, locate the remaining failure before proposing another hierarchy. Use Monte Carlo precision appropriate to that decision.

The deliverable should be an error decomposition, a dependence check, and a recommendation—not a new framework of ledgers or an exhaustive grid. If real-data model criticism is the next bottleneck, explicitly designate an early development block and preserve later outcomes and Huon Ridge for confirmation. Iterative model building is compatible with rigorous validation when development and final assessment are distinguished. [Gelman et al., *Bayesian Workflow*](https://arxiv.org/abs/2011.01808).

## 6. Evidence quality and limitations of this review

**Verified directly:** current commit and initially clean worktree; the relevant likelihood and recovery code; consistency of the Goal007 failed-gate values, clean-fit count, core RMSEs, and shared-model catastrophe decomposition with the retained CSVs; the complete-data and binomial calculations below. Static inspection supports the stated selection-likelihood construction, but is not a proof covering every implementation path.

**Verified from documents, not reproduced here:** earlier Goal005/006 batch outcomes, remote source-hash reconciliation, the full numerical bridge and gradient screens, and the existing independent audits. Their recorded evidence is substantially stronger than a narrative claim that a model ran, but I did not re-execute those analyses.

**Not established:** how frequently a prospective same-species transfer defect would affect practical richness; which class or shared parameter causes the earlier large richness errors; empirical seasonal/spatial adequacy; external transportability; or the performance of any alternative proposed here. No inference about actual Judbury detections was made from the synthetic results.

**Reproducibility limitation:** compact run evidence lives in ignored local output directories, and raw CmdStan evidence remains on `deep-server`. A fresh clone alone will not reproduce this review's numerical checks without the corresponding evidence package. The existing tracked decisions identify the runs; an eventual paper needs an archived, versioned evidence release. This review did not create another archive.

### Lightweight verification commands

The inspection used `git status --short`, `git rev-parse HEAD`, targeted `rg` searches, and numbered file reads. The following base-R checks reproduce the decision-relevant calculations without invoking project startup, Stan, or empirical inputs:

```bash
cd /home/bwbrook/papers/flexiRich
Rscript --vanilla -e '
r <- read.csv("outputs/goal007/task2-screen-v1/results/recovery.csv")
s <- read.csv("outputs/goal007/task2-screen-v1/results/fit-status.csv")
g <- read.csv("outputs/goal007/task2-screen-v1/results/decision-gates.csv")
print(g[!g$passed, c("model_id", "gate_id", "value", "threshold")])
print(c(clean = sum(s$terminal_clean), fits = nrow(s)))
for (m in unique(r$model_id)) {
  v <- subset(r, model_id == m & screen_role == "core" &
                 encounter_class == "occasional")
  print(data.frame(model = m,
    generator_RMSE = sqrt(mean(v$generator_error^2)),
    finite_RMSE = sqrt(mean(v$finite_error^2)),
    covered = sum(v$generator_covered_90)))
}
print(subset(r, model_id != "independent" & screen_role == "core" &
               (abs(generator_error) > log(3) | abs(finite_error) > log(3)),
             select = c(model_id, dataset_id, generator_error,
                        finite_error, generator_covered_90)))
n <- c(1, 3, 6, 8, 44)
sd <- 1 / sqrt(n + 1 / 1.5^2)
print(data.frame(n = n, sd = sd, factor95 = exp(qnorm(.975) * sd)))
print(c(correct_sd = 1 / sqrt(6 + 1 / 1.5^2),
        repeated_species_as_new_sd = 1 / sqrt(12 + 1 / 1.5^2)))
print(c(coverage_MCSE = sqrt(.9 * .1 / 10),
        reject_eight_of_ten = pbinom(7, 10, .9),
        any_of_ten_independent_cells = 1 - (1 - pbinom(7, 10, .9))^10,
        at_most_five_covered = pbinom(5, 10, .9)))
print(binom.test(5, 10)$conf.int)
'
```

## 7. Risk register deltas

| Risk | Likelihood / impact | Proportionate mitigation |
| --- | --- | --- |
| Persistent species treated as new independent latent draws during transfer | Structural concern in the proposed design; potentially high inferential impact | Fix the source–target dependence contract and verify the complete-data case |
| More effort spent repairing a nuisance parameter than the ecological failure | High / substantial research cost | Decompose richness error before further prior development |
| Gate noise mistaken for a precise duration or information boundary | High near current margins / moderate to high claim risk | Monte Carlo uncertainty and fewer primary decisions |
| Biological misspecification dominates any calibration improvement | Plausible, not measured here / high | Small targeted spatial and seasonal stresses, then protected empirical criticism |
| External transfer success overstated from one source and one target reserve | High if generalised / high for a broad methods claim | State domain limits; later seek independent sites or datasets |

## 8. Questions requiring the collaborator's judgment

1. **Which application leads the paper:** estimating richness from a previously unstudied short survey, or improving short revisits using earlier monitoring of the same named species? Both are worthwhile, but they require different information contracts and different claims.
2. **What ecological decision should define useful precision:** distinguishing changes of a few species, placing a defensible bound on total richness, or deciding whether another month of sampling is worthwhile? The current many-gate standard partly substitutes for this choice.
3. **After a bounded synthetic dependence/failure diagnostic, should an early Judbury block become explicit development data?** That would let real ecology inform model criticism while later Judbury forecasts and Huon Ridge remain protected. It needs a deliberate main-thread decision, not an incidental file inspection.

## Bottom line

I would continue the research, but I would not make the next move simply “invent a more robust rare-species prior”. First ensure the model uses the historical information coherently, and establish which component actually produces the large richness errors. Keep the numerical foundations and the honest historical failures. Change the next question from **“can this class mean pass every calibration gate?”** to **“what information is needed to make the ecological inference useful, and are we using that information correctly?”**
