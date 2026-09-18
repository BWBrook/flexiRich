# Goal009 decision: the baseline misses spatial and temporal structure

18 September 2026. **Proceed to a bounded species-by-station model comparison;
do not adopt either baseline prior profile as a validated richness estimator.**
The shared-station baseline can reproduce aggregate detection counts while
missing where and when species are photographed. A separate conditional
timing diagnostic shows that static spatial composition does not fully explain
the temporal pattern. Widening the species-rate prior does not repair either
structural failure.

## Correct evidence and the warning investigation

The remote run at source commit `e183888960c6ff5cdc7146e6549bf876f6e3484a`
completed both primary attempts with exit zero. Both fits met the frozen
computational criteria without rescue. Across the two profiles, maximum
R-hat was 1.00416, minimum bulk ESS 436.35, minimum tail ESS 442.18, and
minimum E-BFMI 0.7976; divergences and maximum-depth hits were zero.

However, the warning at shutdown identified a real predictive-simulation
defect. With the posterior namespace loaded, its matrix subclass retained
extra dimensions on row extraction. Effort was then applied along the species
axis instead of the station axis. Exact replay of the original postprocessing
reproduced all 20 numerical CSVs and 104,000 warnings. Tests using only ordinary
matrices had missed this namespace-dependent behaviour.

The repair explicitly rebuilds base numeric matrices. It was independently
reviewed, regression-tested and committed as
`e24e997b7d6d242e04c4afab430da49777279660` before execution. Corrected
postprocessing reused the original posterior draws, predictive seeds and draw
selection, completed with warnings treated as errors, and confirmed both latent
richness PMFs unchanged within 1e-12. No refitting was needed. The 51 original
files were copied with matching remote SHA-256 receipts and archived in full.
See [PostprocessingRepair.md](PostprocessingRepair.md).

**Use `outputs/goal009/ppc-repaired-v2` for predictive conclusions. The original
`first-year-v1/ppc-*` tables and figures are invalid.** Original fit diagnostics,
posterior draws and latent-richness calculations remain usable. The initial
interpretation of original PPC totals and third-block failure is withdrawn.

## What the corrected checks show

Central 90% posterior predictive intervals below describe 1,000 replicated
first-year histories per profile under the observed effort pattern. Counts are
positive species-by-station-by-week cells, not photographs or independent events.

| Statistic | Observed | Primary | Wider tail |
|---|---:|---:|---:|
| Detected richness | 21 | 18–23 | approximately 18–23 |
| Total positive cells | 979 | 927–1,034 | 921–1,034 |
| Network common-ranking violation | 498 | 118–207 | 117–211 |
| Matched pademelon–bettong crossing | 18 | -9–1 | -9–1 |
| Adjacent-week switches | 786 | 985–1,119 | 976–1,113 |
| Third-block positive cells | 51 | 45–66 | 45–65 |
| Fourth-block positive cells | 371 | 305–359 | 303–356 |

The network statistic measures opposing species contrasts across station pairs
with matched fully operational weeks. The targeted crossing requires strong
contrasts in both species' opposite directions. Neither statistic reached its
observed value in any replicate from either profile. This cannot be dismissed
as the sole chosen pademelon–bettong example: the network pattern is also poorly
represented. Nevertheless these are development checks; the targeted example
was selected after inspection, and shared observations make the statistics
dependent. A finite zero exceedance count is not probability zero or a calibrated
p-value.

The baseline imposes a common expected station ordering on all species. The
results support relaxing that restriction; they do not establish habitat
preference, territoriality or any particular ecological cause. The original
claim of overall detection underprediction disappears after repair. Mammal
and bird positive-cell totals also fall inside their corrected intervals.
The low-effort third block is consistent with the corrected baseline.

## Temporal structure persists after conditioning on station use

We added an explicitly exploratory, sampler-free diagnostic after viewing the
initial PPCs. Each of 1,999 permutations shuffled detections across calendar
weeks independently within species × station × exact positive active-day
strata. All stratum detection counts, species totals, effort and unsampled
cells were retained and checked. The seed was 2026091801; the output records
source hashes and the pre-commit working-tree Git HEAD. This was not a
prospectively registered experiment.

There were 950 strata, including 500 with at least two cells and 103 containing
both detections and nondetections. Those mixed strata comprised 3,730 cells;
the full sampled panel had 17,050 species-station-week cells. Degenerate
strata contribute no timing variation. The switch statistic uses the same
fixed 21 detected species and 6,804 eligible adjacent pairs as the PPC.

- Switches: 786 observed, permutation median 923, interval 894–952;
  **0/1,999** permutations had as few switches.
- Fourth-block positives: 371 observed, interval 315–349;
  **0/1,999** permutations had as many positives.
- Third-block positives: 51 observed, interval 44–60; no comparable mismatch.

Conditioning on static species-specific station counts reduces the switch
discrepancy but does not remove it. Thus a spatial-only explanation is
insufficient under this timing-exchangeability comparison. The diagnostic
does not distinguish serial dependence, time-varying availability, seasonality,
abundance changes or time-varying observation effects. Permutation tails are
finite simulation summaries, and the block checks are dependent.

## What this says about richness

| Model output | Primary | Wider tail |
|---|---:|---:|
| Mean latent richness | 24.39 | 25.31 |
| Median latent richness | 24 | 25 |
| Central 90% latent interval | 21–30 | 21–32 |
| Mean additional unseen members | 3.39 | 4.31 |

These are outputs of the criticised baseline, not accepted estimates of actual
local richness. Their intervals concern latent membership, not the posterior
mean membership sum and not replicated detected richness. Both profiles share
the same structural assumptions. Their broadly similar answers are not a
robustness guarantee; their difference is sensitivity to this one inherited
prior change, not a complete uncertainty assessment.

Of 29 unseen candidates, 28 are birds and one is the wombat. Under this model
their identical all-zero histories and common priors make them exchangeable.
Differences between their Monte Carlo membership summaries are not species-
specific ecological evidence. The mean membership probability across unseen
candidates is 0.117 under the primary profile and 0.149 under the wider tail.
Nothing in these checks establishes whether a particular undetected bird or
the wombat belongs to the reference-period pool. Do not convert this into a
taxon exclusion or another class-contrast prior.

## Next comparison

1. Preserve this baseline and test one persistent species-by-station encounter
   term on the same first-year panel, with the same candidate membership model
   and information set. Keep the species effect interpretable as the mean log
   rate across the fixed array, and define the interaction's centring and
   variance prior before fitting. Persist the station interaction into later
   periods; do not redraw it each week. Check limiting-case agreement with the
   baseline, prior predictive behaviour, and posterior geometry.
   The interaction is poorly informed for all-zero candidates and changes their
   nondetection probability through its prior. Its sensitivity and synthetic
   richness recovery must be examined before interpreting a changed richness
   distribution as improved inference.
2. Judge the change against the spatial contrasts and residual timing failures,
   not aggregate counts alone or a narrower richness interval. This is a
   discriminating mechanism comparison, not a proposal that spatial variation
   alone will be adequate. The conditional diagnostic already provides a reason
   to investigate a subsequent temporal component if residual failures persist;
   add it separately so its contribution is interpretable.
3. Freeze actual species-discovery and redetection predictions, with explicit
   planned versus realised effort, before further later Judbury outcomes are
   accessed. Retain baseline forecasts as comparators even when their PPCs fail.
   Forecast success alone cannot validate unseen total richness. Use focused
   simulations after this empirical development to investigate richness recovery,
   not a new broad eligibility screen that postpones observable forecasts.

No new ecological model, later-outcome forecast or Huon Ridge analysis has been
run in this tranche. Candidate eligibility and the reference-period estimand
are unchanged. Huon Ridge still requires Barry's reviewed candidate pool and
deployment/service metadata; independent wombat presence requires its spatial
and temporal provenance. The disclosed earlier later-Judbury row exposure
remains part of the eventual assessment record.

The corrected numerical evidence, conditional timing diagnostic and synthesis
figure are incorporated in the working makedoc manuscript. This closes the
first-year baseline-criticism tranche; model revision, temporal assessment and
external validation remain substantial scientific work.
