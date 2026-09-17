# What camera grids can tell us about community richness

**Working methods-and-application manuscript, 12 September 2026.** This is an
incomplete research draft. Theoretical diagnostics and early empirical
description support development; a revised estimator, prospective comparison
and external validation have not yet been completed. Authorship and journal
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

Definitive richness-model comparisons and the external application remain
outstanding.

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
