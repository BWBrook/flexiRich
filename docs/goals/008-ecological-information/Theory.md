# Goal008 theory — estimands, dependence and cheap information checks

Status: completed diagnostic, 12 September 2026. No empirical observations,
Stan fits or remote computation were used.

## Decision

The proposed Goal007 downstream transfer cannot represent the calibration and
target records as conditionally fresh species while simulating persistent
rates for the same named species. That mismatch can materially overstate
information about a generating class mean. A repeat-monitoring model should
link a candidate's measurements through a persistent species effect, with any
seasonal or period-specific variation added explicitly. A generic
class-distribution transfer is a different experiment and should redraw the
target species effects.

This result diagnoses the next model contract; it does not establish that
richness is impossible to estimate, that all aggregate calibration is invalid,
or that Goal007's unrun downstream model would necessarily fail by the amount
in the example.

## Scientific targets and information contract

Let the reviewed candidate set be fixed. Three targets must remain separate.

| Target | Definition | What an observation establishes |
| --- | --- | --- |
| Reference-period pool richness | Number of candidates with a non-zero camera-encounter-generating process on the grid at some time in the stated 153-week reference period | A correctly identified detection during that reference period proves membership for that candidate; a non-detection does not prove absence |
| Target-window use richness | Number of reference-pool candidates available to the camera process during a specified shorter window | A detection proves use in that window; a past detection does not prove availability in every later window |
| Future discovery | Number and identities first detected under a specified future effort schedule among candidates not previously detected | The future camera record directly observes discovery, conditional on identification and effort recording |

The present primary estimand is the first row. It is grid-level,
camera-accessible reference-period richness, not abundance, density, total
reserve richness or automatically the number of species using a particular
month. Target-window use can mediate the observation process without changing
historical reference membership. Discovery is an observable prediction target
and a useful validation surface, but accurate discovery prediction alone does
not identify the never-detected tail of reference richness.

Past species identities are legitimate information for same-grid repeat
monitoring when the prediction target concerns those named candidates. Using
them is not leakage if the outcomes after the forecast cutoff remain held out.
Discarding identities changes the question to transport of a generic species
distribution; it does not remove the biological dependence created by
simulating the same species in both periods.

## Exact Gaussian dependence check

The smallest model that exposes the issue is

\[
\alpha_i\sim N(\mu,\tau^2),\qquad
X_i\mid\alpha_i\sim N(\alpha_i,s_c^2),\qquad
Y_i\mid\alpha_i\sim N(\alpha_i,s_t^2).
\]

For the same species observed in both periods, and using the flat-prior
Gaussian location calculation for this benchmark,

\[
\operatorname{Cov}(X_i,Y_i\mid\mu)=\tau^2.
\]

For genuinely fresh species drawn independently in the two periods, that
covariance is zero. With six species, \(\tau=1\) and
\(s_c=s_t=0.5\), the correct repeated-species information about \(\mu\) is
0.889 per paired species. Treating the two marginal observations as fresh
gives apparent information 1.600, an 80% overstatement. The resulting nominal
90% standard error is 0.323, while its true repeated-species sampling standard
error is 0.433. Exact coverage is 0.7798 rather than 0.90.

A seeded 100,000-replicate check, using base R's Mersenne-Twister, Inversion
normal generator and Rejection sampler, reproduced the formula within Monte
Carlo error at the fixed generating mean \(\mu=0\). The caller's RNG kind and
state are restored. The correctly
correlated repeated-species interval covered 0.8997, the
fresh-species calculation applied to repeated species covered 0.7819, and the
same independence calculation applied to genuinely fresh species covered
0.9011 (individual Monte Carlo standard errors were about 0.001). The fresh
control matters: independence is valid for a new species sample, but not for
two records of the same finite set.

The generating mean \(\mu\) and the realised mean
\(\bar\alpha=n^{-1}\sum_i\alpha_i\) are also distinct. With six species and
\(\tau=1\), the realised mean has sampling standard deviation 0.408 around
the generating mean. Given the paired measurements and known \(\mu\), its
posterior standard deviation in this example is 0.136. A model can therefore
estimate a superpopulation mean reasonably while missing the realised mean of
six named candidates, or estimate those six well without learning a stable
generic class distribution. Neither target substitutes for the nonlinear
miss probabilities needed for richness.

## Exact finite-pool richness check

The second diagnostic strips the model down to fixed candidate-specific
detection probabilities. Let

\[
g_i\mid\omega\sim\operatorname{Bernoulli}(\omega),\qquad
\omega\sim\operatorname{Beta}(a,b),
\]

and let \(q_i\) be the known probability that candidate \(i\) is detected in
the observed survey if it is a member. A detected candidate has \(g_i=1\).
For the \(U\) undetected candidates, define
\(w_i=1-q_i\), let \(D\) be the number detected, and let \(e_k(w)\) be the
degree-\(k\) elementary symmetric polynomial. Integrating the shared
\(\omega\) gives the exact posterior richness mass

\[
P(R=D+k\mid d,q)\ \propto\
e_k(w)\,B(a+D+k,b+U-k),\quad k=0,\ldots,U.
\]

This expression retains the membership dependence induced by uncertainty in
the shared \(\omega\). It is not the product of Bernoulli probabilities formed
by plugging in a posterior mean for \(\omega\). Conditional on a particular
richness, the posterior for \(\omega\) is
\(\operatorname{Beta}(a+R,b+C-R)\), so posterior moments of \(\omega\) follow
from the same finite mixture.

The implementation was checked against an independently enumerated membership
state space. For the eight-candidate example in the output, all richness
probabilities agreed to machine precision. Boundary controls also agree: when
all candidates are undetected with \(q_i=0\), the data contain no visibility
information and the Beta-binomial prior is recovered (uniform over richness
0 through \(C\) for a Beta(1,1) prior); an undetected candidate with \(q_i=1\)
has zero posterior membership probability; and a detection paired with
\(q_i=0\) is rejected as impossible. This is a useful exact test oracle
for later prediction code. It is deliberately not a claim that real
candidate-specific detectabilities are known: uncertain encounter rates,
availability and station effects can remain confounded with membership, and
their uncertainty must be propagated rather than replaced by fixed \(q_i\).

## Why a mean log rate is not enough

For effort \(E\) and log encounter rate \(\alpha\), the probability of no
detection under the simple Poisson encounter process is

\[
p_0(E,\alpha)=\exp\{-E\exp(\alpha)\}.
\]

The output compares a point mass at \(\log(0.02)\) with an equal mixture at
\(\log(0.02)-1.5\) and \(\log(0.02)+1.5\). Both distributions have exactly
the same mean log rate. At effort 50 their mean missed-detection probabilities
are 0.368 and 0.406; at effort 100 they are 0.135 and 0.320. At lower effort
the ordering reverses. The nonlinear transform therefore depends on spread
and shape as well as location, and no single class mean determines richness
or discovery risk.

Total effort is likewise insufficient when availability varies through time.
With rate 0.02 and 60 camera-days, a year-round species has missed probability
0.301 whether effort is split 30/30 across two seasons or concentrated in one.
For a species available only in season A, those same schedules give missed
probabilities 0.549, 0.301 and 1.000 for balanced, A-concentrated and
B-concentrated effort. A historical reference-period member can consequently
be structurally unavailable in a short target window even with positive total
effort.

## Consequences for the next model experiment

The next coherent repeat-monitoring sketch should retain candidate identity
and start with persistent species encounter propensity plus the recorded
camera-effort observation process. Constant hazard remains the baseline.
Period or seasonal availability/rate variation is a competing mechanism to add
only if the early empirical diagnostics show temporal concentration or lack of
repeatability that the baseline cannot represent. Those diagnostics cannot
identify the distribution of species never detected, but they can reject
representations that already fail for observed species.

A later small simulation should compare a persistent-species model with a
generic fresh-draw transfer under both matching and mismatching data-generating
processes. The generic transfer represents a separate application to newly
drawn species. An intentionally identity-discarding comparator may receive the
same historical records to quantify the defect diagnosed here, provided its
information loss is explicit. Comparator inputs and effort must otherwise be
matched. Primary checks should concern reference richness and future discovery,
while separately reporting recovery of the generating distribution and the
realised finite set. Seasonal allocation and alternative encounter-distribution
shapes should be varied one at a time because the cheap counterexamples show
that each can change missed-detection risk without changing a mean log rate or
total effort.

No new regulariser is justified by these checks alone. Their decisive result
is the repair of the information contract: match repeated-species data with a
repeated-species likelihood, define whether window availability belongs in the
estimand or observation process, and propagate the full finite-pool posterior
to richness and discovery.

## Reproducibility

Run `Rscript scripts/run_goal008_theory.R` from the repository root. Outputs
are written once to `outputs/goal008/theory-v2/`; an existing directory causes
the script to stop. The directory contains source tables, three PDF figures,
run provenance and a completion record. Provenance records the base Git commit,
whether the worktree was clean, and hashes of the uncommitted theory source and
runner; this diagnostic is not represented as a commit-frozen production run.
The only stochastic calculation uses the declared seed 812008; exact formulae
and the independent finite-state enumeration provide the acceptance checks.
No empirical outcomes or Stan code are read.
