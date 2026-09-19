# Goal011: freeze and assess temporal encounter forecasts

Approved continuation, 19 September 2026. Goal010 repaired spatial patterns but
left temporal misspecification and unseen-tail uncertainty. This stage asks
whether that spatial repair improves observable out-of-period prediction. It
uses the already authorised Goal009 forecast contract. No new temporal model,
candidate pool, ecological labels or prior profile is introduced.

The first operation is prediction generation only. Later detection outcomes
remain closed until predictions, scoring code and the final information-access
receipt are frozen and independently audited. Huon Ridge remains protected.
This is a retrospective forecast conditional on reviewed realised camera effort,
not an operational planned-effort forecast or wholly blind confirmation. The
known Goal008 three-row exposure and historical aggregate disclosures remain
part of its interpretation.

## Fixed comparisons and target

Main comparison: shared-station primary (Goal009) versus persistent spatial
primary (Goal010). The wider rate-tail baseline and three remaining spatial
prior combinations are sensitivity analyses. Freeze all six; do not select a
prior profile using later outcomes or combine them into a tuned ensemble.

Train once on occasions 1–52. Forecast occasions 53–153, including the formerly
unused 53–54 gap and occasion 153, at cumulative 13, 26, 52 and 101 week horizons.
The nine stations, reviewed 50-candidate pool and 153-occasion reference-period
membership definition are unchanged. Known members remain known even if they
are not redetected. Report separately:

- first discoveries among the 29 first-year unseen candidates;
- redetection of the 21 first-year detected candidates;
- the number of distinct candidates detected in each future cumulative window.

None is true total community richness. No later model refitting, rolling updates
or selective exclusion of exposed periods is part of this comparison.

## Effort and forecast objects

Use only `config/goal003_task4_effort_template.csv` to derive future effort.
This reviewed table predates the new forecasts and is already an input to
Goals008–010. The derived future metadata have 909 station-weeks and 5,303
active station-days. No observation file is required. Freeze its SHA-256,
calendar, model-input draw hashes, source commit and predictive objects.

Retain joint posterior pairing of membership probabilities, alpha, b and u.
At each draw use cumulative effort and the same persistent effects throughout
all future horizons. Integrate conditional Poisson-binomial distributions over
joint posterior draws; never form a binomial/Poisson-binomial from posterior
mean probabilities, and never convolve separately integrated discovery and
redetection PMFs to get total detection.

All 29 unseen candidates are exactly exchangeable under these six models.
Report their common marginal event probability by pooling across those labels.
Keep heterogeneous latent probabilities inside each draw for the total PMF.
Taxon/class discovery-count marginals follow hypergeometric splitting of the
total discovery distribution, explicitly as an exchangeability consequence.
They do not estimate biological bird/mammal differences. Preserve joint
per-draw cumulative probabilities and seeded coherent nested count paths;
never treat the four horizons as independent replicates.

Save probabilities and stable log probabilities. A probability that rounds to
one is not a genuinely impossible absence: use log-domain arithmetic for
species scores and count tails. Preserve -Inf only for actual zero model mass,
not accidental underflow. Sampling seeds apply only to illustrative joint paths;
the main marginal calculations average exact conditional probabilities and PMFs
over all retained MCMC draws; posterior integration still has Monte Carlo error.

## Before opening outcomes

Require a focused independent audit of formula/code/tests, input identities,
calendar endpoints, absence of future detections, primary/sensitivity roles,
exchangeability, joint-horizon retention and scoring rules. After generation,
verify/archive the actual predictions and commit them before outcome access.
Only then build later outcomes with immediate bounded filtering and score the
already fixed objects. Document the access time and exact observation source.
