# What camera grids can tell us about community richness

**Working methods-and-application manuscript, 19 September 2026.** This is an
incomplete research draft. Theoretical diagnostics and early empirical
description and the first spatial-model comparison support development;
held-out forecasting and external validation have not yet been completed. Authorship and journal
selection remain open.

## Abstract

The planned paper asks how survey effort and prior encounter information
jointly determine what can be learned about the camera-accessible species
richness of a wildlife study grid. It will connect a finite-candidate
probability model, controlled simulation experiments and empirical camera
records. Its practical outputs are uncertainty about unseen members and
predictions of additional species under a specified future deployment. A
final abstract will be written after the empirical comparison and external
assessment are complete.

## Introduction

A camera survey records detections rather than a complete species list.
For a species that has not been photographed, two explanations remain:
it does not use the grid, or it uses the grid but has escaped observation.
More operating camera-days can distinguish these explanations only when
they sample places and times at which the species can be encountered.
Estimating the unseen component therefore requires an explicit account of
the species considered, the survey's spatial and temporal scope, and the
encounter information supplied from outside the target observations.

We develop these questions for a reviewed, finite list of camera-accessible
species. The scientific contribution sought is a useful account of when
richness inference is supported, what information makes it useful, and how
uncertainty should be communicated when the unseen tail remains weakly
identified. Comparative literature positioning and novelty assessment remain
to be completed before this introduction is considered a manuscript draft.

## Methods

### Ecological targets and observation units

The historical primary target is reference-period richness,
$S_R=\sum_{i=1}^{C}g_i^R$, where $g_i^R$ indicates membership of the
camera-accessible grid-use pool during a specified reference period.
The reviewed primary candidate list contains $C=50$ species. The Judbury
reference record spans 153 seven-day occasions at nine analysis stations.
This target is distinct from the number using the grid during a particular
short window, and from the number expected to be detected under a future
survey design. Neither abundance nor total vertebrate richness is estimated.

Under correct species identification, a detection during the reference
period establishes reference-period membership. It does not establish
continuous availability at all stations or during all shorter windows.
The full-record detected count is a lower reference for reference-period
richness, not known true richness and not a lower bound for every window's
use richness.

Observations are binary detections by species, station and seven-day
occasion. Effort $E_{jk}$ is the number of confirmed active station-days.
Zero-effort cells are unsampled. The baseline conditional detection model is

$$
P(y_{ijk}=1\mid g_i^R=1)
=1-\exp\{-E_{jk}\exp(\alpha_i+b_j)\}.
$$

This constant-hazard model is a baseline assumption. A common station effect
$b_j$ imposes the same multiplicative station ordering on all species;
seasonal availability and species-specific spatial use require separate
criticism. More flexible mechanisms are not assumed to be identified merely
because their parameters can be added.

### Information retained across surveys

Repeat monitoring and new-reserve transfer are distinct applications.
Earlier observations of the same named species are legitimate information
for repeat monitoring. When a species effect persists between periods,
calibration and target observations must share that effect, or retain its
joint posterior dependence in a sequential analysis. Passing only a class
mean and treating target species as independent new draws changes the model.
The complete-data Gaussian diagnostic isolates this difference before any
additional camera-model fitting.

For all-history repeat monitoring, every earlier detected candidate is
already a known reference-period member. A future discovery is therefore
defined among candidates unseen in all the history supplied before the
forecast cutoff. Encountering a historically known species absent from a
recent window is a redetection, not a first discovery. All repeat-monitoring
comparators must receive the same historical observations and known-member
constraints. An uncalibrated snapshot is a separate information regime;
historical snapshot eligibility rules do not automatically apply to revisits.

We distinguish the generating mean log rate of a species population, the
realised mean log rate of a finite set of species, and each candidate's
probability of being missed by a specified deployment. Uncertainty for one
quantity is not automatically uncertainty for either of the others.

### Fixed-detectability reference calculation

Let $d_i$ indicate whether candidate $i$ is detected and let $p_i$ be its
known probability of at least one detection if it is a member. Conditional
on a common membership probability $\omega$, candidate membership states
are independent. The observation likelihood, omitting factors constant in
$\omega$, is

$$
L(\omega)\propto\omega^D\prod_{i:d_i=0}(1-\omega p_i),
\qquad D=\sum_i d_i.
$$

For an unseen candidate,

$$
P(g_i=1\mid d_i=0,\omega,p_i)
=\frac{\omega(1-p_i)}{1-\omega p_i}.
$$

The richness distribution integrates the conditional Poisson-binomial
distribution over the posterior for $\omega$. Averaging candidate
probabilities first and then treating memberships as independent would
discard their dependence through $\omega$. This calculation is an oracle
reference, not an assumption that empirical detectabilities are known.

Under the baseline encounter model, survey miss probability is
$\exp\{-\sum_{jk}E_{jk}\exp(\alpha_i+b_j)\}$. Its expectation under
uncertain rates depends on their distribution, not only their mean log rate.

### Empirical development and retained assessment data

The first 52 Judbury occasions, 5 June 2019 to 2 June 2020 inclusive, are
declared development data before new empirical inspection. Observations are
filtered to that interval using the established fixed UTC+10 convention
before event construction and analytical aggregation. The frozen candidate
list, source receipts, event protocol and physical-position-to-station
mapping are retained. Later Judbury detections and Huon Ridge are not used
in this development tranche's calculations. During schema inspection, a worker
inadvertently displayed three later observation records. They were excluded
from all analyses, but later temporal assessment must disclose this exposure
alongside historical aggregate disclosures; it cannot be described as wholly
blind. Huon Ridge has not been accessed. The repository records the incident
and the independently checked analytical boundary.

Development diagnostics describe operational effort, accumulation of
observed species, species detection frequencies, station use and four
consecutive 13-week blocks. Incidence fractions have explicit sampled-cell
denominators. These summaries neither estimate the encounter distribution
of unseen species nor establish seasonal effects from a single year.
After inspecting the descriptive station summaries, we selected one
illustrative station pair and compared species on their shared calendar
occasions with seven active days at both stations. This exploratory matching
controls calendar and exposure differences, but not temporal dependence.

### First-year model criticism

We fitted the full-candidate baseline to the 52-week development panel,
retaining one membership state and one persistent log encounter rate per
species, and sum-to-zero shared station effects. Species log rates followed
a normal hierarchy. Both prior profiles used $\omega\sim\mathrm{Beta}(1,1)$,
$\mu_\alpha\sim\mathrm{Normal}(\log(0.02),1.5^2)$ and a half-normal prior
with scale 0.75 for the station-contrast standard deviation. The half-normal
scale for the among-species standard deviation was 1 in the primary profile
and 1.5 in the wider-tail sensitivity. These inherited priors were not
externally calibrated. Taxon and routine/occasional labels were used for
descriptive summaries, not separate encounter-rate distributions.

Each fit used four chains with 1,000 warmup and 1,000 retained iterations
per chain. Predictive checks used 1,000 evenly spaced joint draws and the
observed effort pattern. Membership was drawn once per species in each
replicate and retained across all its stations and weeks; previously detected
species had membership one. We distinguished replicated detected richness
from latent membership richness, whose distribution averaged conditional
Poisson-binomial distributions over all 4,000 posterior draws. Predictive
tail fractions and central 90% intervals were descriptive model checks,
not independent hypothesis tests or calibrated coverage estimates.

Checks included species and taxon counts, four 13-week blocks, adjacent-week
switches, and station contrasts. The targeted crossing statistic was the
minimum of the pademelon and bettong count differences in their opposite
observed directions. A network-wide statistic summed, over all station pairs
with matched fully operational weeks, the smaller of the positive and
negative species count-difference totals. The fixed set of 21 detected
species defined both the observed and replicated ranking and switch
statistics. Outages broke temporal adjacency.

An exploratory follow-up separated temporal pattern from static station
composition. We independently permuted observations across weeks within
each species-by-station-by-exact-active-days stratum 1,999 times, preserving
all stratum counts and unsampled cells. This conditions on spatial use and
effort while testing calendar exchangeability. It cannot distinguish
seasonality, animal persistence or time-varying observation effects.

### Persistent species-by-station comparison (Goal010)

To test whether the shared station ordering was too restrictive, we added a
persistent species-by-station interaction to the first-year model. For
candidate $i$, station $j$ and occasion $k$, the log hazard was

$$
\log h_{ijk}=\log E_{jk}+\alpha_i+b_j+u_{ij}.
$$

The row-centred $u_i$ terms sum to zero across the nine stations and were
parameterised so their marginal station standard deviation is $\tau$; the
inherited camera-effect parameter $\sigma_{camera}$ remains a contrast
coefficient standard deviation. Candidate identities, membership, effort,
station effects and species-specific station effects persisted through the
52-week window. This fixed-array extension tests spatial-pattern flexibility;
it does not specify seasonal availability or a transferable random field.
Proper priors regularise the shared/species-specific station decomposition;
the likelihood does not identify those components uniquely.

Four empirical fits crossed $\tau\sim\mathrm{HalfNormal}(0,0.5)$ or
$\mathrm{HalfNormal}(0,1)$ with the inherited among-species rate scale
$\sigma_\alpha\sim\mathrm{HalfNormal}(0,1)$ or
$\mathrm{HalfNormal}(0,1.5)$. We also fitted the baseline and spatial models to
two fixed synthetic mechanisms: no species-specific station interaction, and
opposing $+1.5/-1.5$ log-rate offsets for two species at two stations. These
paired controls checked implementation and mechanism response; they were not
coverage or average-accuracy experiments.

### Frozen temporal encounter forecasts

We compared the primary shared-station and spatial models using fixed-origin
forecasts for occasions 53–153, after fitting only occasions 1–52. The other
four prior profiles were retained as sensitivity analyses. Predictions,
scoring rules and complete predictive objects were frozen and independently
checked before accessing the later outcomes. Known historical exposure to
three later records and aggregate summaries precludes describing this as
wholly blind validation. In particular, the historical full-period total of
26 detected species, combined with the first-year total of 21, already revealed
the final count of five additions. The focal count comparison is consequently
a retrospective predictive check of a disclosed aggregate. All models used
the same reviewed realised effort:
5,303 active station-days over the following 101 weeks. These are retrospective
forecasts conditional on that effort, rather than operational forecasts of an
unknown future deployment.

For posterior draw $d$, candidate $i$ and future horizon $h$, the probability
of at least one future detection was

$$
p_{id}(h)=q_{id}\left[1-\exp\left\{-\sum_j
E_j(h)\exp(\alpha_{id}+b_{jd}+u_{ijd})\right\}\right],
$$

where $q_{id}$ is the membership probability conditional on the first year,
$E_j(h)$ is cumulative future effort, and $u_{ijd}=0$ in the shared-station
model. Membership probabilities were one for the 21 previously detected
candidates. We preserved joint posterior draws and the same species and
station effects through nested horizons of 13, 26, 52 and 101 weeks. Conditional
Poisson-binomial count probabilities were averaged over all retained draws;
count distributions were not constructed from marginal mean probabilities.
Named marginal predictions were pooled across the 29 exchangeable unseen
candidates, while their heterogeneous probabilities within each posterior
draw were retained for the count mixture.

We scored first discoveries among those 29 candidates separately from
redetection of the 21 known members. The focal contrast was spatial minus
shared-station negative log predictive probability of the additional-discovery
count at 101 weeks. Species-level Brier and logarithmic scores, all shorter
horizons, total future-detected counts and every prior sensitivity were also
retained. Taxon and encounter-class discovery distributions were obtained by
hypergeometric splitting under exchangeability; they contain no independently
estimated taxon-specific detection information. Scores used saved log
probabilities without truncating small probabilities. Central 90% predictive
intervals were pointwise summaries, and the nested horizons were not treated
as independent replications. Successful prediction of further discoveries
would still not establish the true richness of the candidate pool.

### Evaluation principles

Future model comparisons will retain equivalent information across
comparators, separate ecological error from computational non-completion,
and report continuous performance with simulation uncertainty. The choice
of simulation replication will follow the precision needed for the
decision, consistent with the guidance of @morris2019simulation.
Predictive assessment of additional species is empirically observable;
good discovery prediction alone does not establish recovery of a nearly
undetectable richness tail.

## Results

### Historical development evidence

The completed Goal007 calibration screen comprised 60 synthetic datasets
and 180 fits. Both shared-shift candidates reduced occasional-class error
but failed their frozen selection standard; downstream richness and discovery
confirmation was not run. These historical decisions stand. They do not
establish that either candidate produced inaccurate empirical richness.

Earlier known-rate experiments showed that calendar duration alone is an
inadequate descriptor of survey information. All nine catastrophic oracle
fits at four or eight weeks occurred in blocks with 28, 46 or 56 active
camera-days and one to three active cameras. Other performance deficiencies
remained. This retrospective decomposition describes the existing experiment;
it does not establish a new effort threshold or validate short surveys.

### Current diagnostic evidence

In a known-variance Gaussian control with six persistent species, between-
species standard deviation one and measurement standard deviation 0.5 in
each of two periods, treating repeat measurements as new species draws
overstated information about the generating mean by 80%. Under a flat
location prior, the resulting nominal 90% interval had exact repeated-
sampling coverage 0.7798. Correctly retaining dependence gave coverage 0.90;
the independent-species analysis also gave 0.90 when the species draws were
actually independent. This is a controlled mechanism check, not a measured
coverage loss in the unfinished camera model (Fig. [1](#fig-dependence)).

The exact fixed-detectability richness distribution agreed with independent
small-pool membership enumeration and numerical integration. Matched-mean
log-rate examples produced different survey miss probabilities, and a
seasonal-availability counterexample showed that identical total effort
can yield different detection probabilities depending on its allocation.
These results identify quantities that the next camera-model comparison
must preserve; they do not validate its ecological assumptions.

### First-year empirical development

The 52-week development block contained 2,341 active station-days, 341
sampled station-weeks and 127 unsampled station-weeks. Twenty-one of the
50 candidates were detected; 29 remained unobserved. Twenty detected
candidates were labelled routine. The sole detected occasional candidate
was the domestic dog, represented by one positive station-week. This
selection-limited evidence cannot establish a general quantitative
routine-occasional encounter-rate contrast.

Detection differed markedly between taxa: 16 of 17 mammal candidates and
five of 33 bird candidates were photographed. The 29 undetected candidates
comprised 28 birds and the common wombat. This pattern makes the ecological
scope of the candidate pool and taxonomic differences in ground-camera
encounter central to interpretation. It does not establish the membership
of undetected candidates or show that a binary taxonomic grouping would
adequately describe their encounter rates.

Effort in the four consecutive 13-week blocks was 819, 576, 172 and 774
station-days (Fig. [2](#fig-effort)). The low effort in the third block
makes simple temporal comparisons unsuitable as evidence of seasonal
availability. Species labelled routine ranged from one to 215 positive
station-weeks, so the label did not imply consistently frequent observation.

The matched station pair had 30 identical calendar weeks with complete
operation at both stations. Tasmanian pademelons were detected in 29/30
weeks at station jc_pm12 and 11/30 at jc_pm23; Tasmanian bettongs were
detected in 0/30 and 25/30, respectively (Fig. [3](#fig-stations)). These
opposite observed station contrasts motivate testing species-specific
station structure against the shared-station baseline. They do not identify
the ecological mechanism or constitute an independent confirmatory test.
The full early station histories are retained in Fig. [4](#fig-history).

### Baseline predictive failures

Both prior profiles met the frozen sampling criteria without numerical
rescue: there were no divergences or maximum-depth hits, maximum R-hat was
1.0042, and minimum bulk and tail effective sample sizes across both fits
were 436 and 442. A draw-class indexing defect in the initial predictive
postprocessing was identified from warnings, corrected and regression-tested.
The following results use corrected simulations from the unchanged saved
posterior draws; the original defective outputs remain archived.

The baseline reproduced overall detection totals but failed spatial and
temporal checks (Fig. [5](#fig-criticism)). There were 979 observed positive
station-week cells, compared with a primary predictive median of 979 and a
central 90% interval of 927–1,034. The network-wide station-ranking violation
was 498, compared with predictive intervals of 118–207 and 117–211 under
the primary and wider-tail priors. The selected pademelon–bettong crossing
statistic was 18, compared with an interval of -9 to 1 under either prior.
None of the 1,000 replicates per profile reached either observed spatial
statistic. These finite simulation counts do not imply zero tail probability.

Observed histories contained 786 switches between adjacent sampled weeks,
compared with predictive intervals of 985–1,119 and 976–1,113. The conditional
timing permutations, which preserved species-specific station counts and
effort, gave a median of 923 switches and an interval of 894–952. None of
1,999 permutations had as few switches as observed. The fourth 13-week block
also retained excess detections under this conditional comparison: 371
observed against an interval of 315–349. Thus static station composition
does not fully explain the temporal pattern. The low-effort third block
was consistent with both the corrected predictive and conditional timing
distributions.

Widening the among-species prior left these predictive failures largely
unchanged. Mean latent richness shifted from 24.4 to 25.3, with central 90%
intervals of 21–30 and 21–32. These are illustrative outputs of the criticised
baseline, not validated estimates of local richness. The 29 all-zero
candidates remain exchangeable under this hierarchy: it has no species-specific
ecological information with which to distinguish the wombat from an undetected
bird. Adequate overall detection counts therefore do not establish adequate
inference for unseen members. Definitive richness-model comparisons and the
external application remain outstanding.

### Persistent species-by-station comparison

All eight frozen fits were terminal-clean. Three empirical fits required the
prespecified rescue attempt for effective sample size or R-hat; no attempt had
divergences or maximum-depth hits. The primary spatial model brought the
observed global common-ranking violation of 498 inside its central 90%
predictive interval (413–616), compared with 118–207 under the corrected
shared-station baseline. The selected pademelon–bettong crossing of 18 was
similarly inside the spatial interval (9–22), whereas the baseline interval
was −9–1 (Fig. [6](#fig-goal010)).

The spatial extension did not repair the temporal discrepancies. Observed
adjacent-week switches were 786, compared with 860–984 under the primary
spatial model; the observed fourth-block count of 371 was compared with
309–357. These remaining failures are consistent with the design warning that
static species-specific station effects cannot represent calendar dependence.
They do not establish seasonality or a causal mechanism.

The primary latent richness mean was 24.57 with a central 90% interval of
21–30, close to the baseline mean of 24.39 with the same interval. Widening
the interaction prior changed the mean little (24.58); widening the inherited
rate tail gave means of 25.51 and 25.53, each with an interval of 21–32.
These shifts are outputs of a development comparison, not evidence that
unchanged interval endpoints validate richness inference. The all-zero
candidates remain exchangeable, future forecasts were not run, and later
observations remain protected.

## Discussion

The proposed interpretation will distinguish limited observation of named
species from limited information about a wider encounter-rate distribution.
It will evaluate whether preserving species information and representing
the ecological structure visible in development data improve useful
richness and discovery inference. Any operational recommendation must name
its candidate pool, reference period, effort, spatial coverage and calibration
assumptions. A shortest universal calendar duration is not presently supported.

The principal unresolved evidence comprises ecological model adequacy,
the performance of a coherent repeated-species model, and transfer beyond
Judbury. A single additional reserve can provide an external case study;
it cannot identify general between-reserve variability by itself.

## Data and code availability

Code, manuscript sources and analysis contracts are maintained together in
the flexiRich repository. Generated analysis and document outputs are kept
under `outputs/`. Release locations, data permissions and archival identifiers
will be specified before public dissemination.

## References
