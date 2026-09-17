# First-year baseline criticism

## Model and data

Reuse `stan/goal003_flexirich.stan` unchanged. This is a full-candidate model:
one membership indicator and one persistent log encounter rate per candidate,
with a sum-to-zero shared station effect. Conditional detection probability in
an operational station-week is `1 - exp(-effort * exp(alpha_i + b_j))`.
Likelihood contributions are grouped only by species, station and active-day
count. This grouping is sufficient under the baseline's constant-hazard model;
it does not discard station identity or turn repeats into new species draws.
All-zero candidate histories contribute their membership mixture likelihood.
No observed-only truncation normaliser is used.

Inputs are exactly Goal008 occasions 1–52: 50 candidates, nine stations, 2,341
active station-days and 341 sampled station-weeks. Zero-effort cells are missing,
not observed absences. The reviewed pool supplies labels only. All species use
the same baseline encounter hierarchy; that is an assumption being criticised.

Use two already documented Goal003 prior profiles:

| Component | Primary | Wider-tail sensitivity |
|---|---|---|
| Membership probability | Beta(1, 1) | unchanged |
| Mean log daily encounter rate | Normal(log(0.02), 1.5) | unchanged |
| Among-species log-rate SD | half-Normal(0, 1) | half-Normal(0, 1.5) |
| Shared station SD | half-Normal(0, 0.75) | unchanged |

These are inherited controls, not externally calibrated ecological priors.
The choice of this pre-existing sensitivity follows inspection of Goal008;
it is a development choice, not confirmatory prespecification.
Neither fit is an approved empirical richness estimator. The sensitivity
comparison reveals whether apparently adequate observed-data predictions can
coexist with materially different unseen richness.

## Predictive checks

For each retained joint posterior draw, draw membership once for each species
using its conditional membership probability. Preserve that draw and its rate
across all stations and weeks. Previously detected candidates have membership
one. Generate complete replicated first-year histories under the observed
effort pattern. Replicated observed richness may be less than 21: membership
does not guarantee detection in a replicate. Keep latent membership richness
separate from replicated detected richness.

Report observed values, central 90% predictive intervals and replicated
distributions for total detections, observed richness, mammal/bird components,
station-by-species counts, four consecutive 13-week blocks, and switches between
adjacent sampled weeks. Outages break adjacency; no switch is imputed across a
gap. Temporal summaries test the constant-hazard baseline, not a named seasonal
mechanism. Report posterior predictive upper-tail fractions descriptively,
without using a universal pass/fail cutoff or treating them as calibrated
frequentist p-values. Monte Carlo precision is qualified by posterior dependence.

The already inspected illustrative contrast uses pademelons and bettongs at
`jc_pm12` and `jc_pm23`, restricted to their 30 identical weeks with seven active
days at both stations. Its crossing statistic is the minimum of the pademelon
count difference (pm12 minus pm23) and the bettong count difference (pm23 minus
pm12). The observed value is 18. Larger positive values mean both opposite
directions are strong. Selection was exploratory during Goal008; this is a
targeted criticism check, not independent confirmation. Full species-by-station
summaries accompany it so the example cannot stand in for the whole network.

Add a network-wide common-ranking violation statistic over all station pairs
with matched seven-active-day weeks. For each pair, compute each species'
count difference and take the minimum of the summed positive differences and
the summed negative magnitudes; sum over pairs. Restrict this statistic and
the switch statistic to the fixed set of 21 first-year detected candidates
in both observed and replicated data. This isolates within-member patterns
from the uncertain unseen tail. Retain per-species and species-by-block count
summaries, without treating their many marginal intervals as independent tests.

## Computation and interpretation

Retain the existing four-chain primary sampler (1,000 warmup and 1,000 sampling
iterations; adapt_delta 0.90, maximum depth 12). One predeclared numerical rescue
uses 1,500 + 1,500 iterations, adapt_delta 0.999 and depth 15. Neither changes the
statistical model or data. Each attempt and its diagnostics are retained. Require
the existing zero-divergence/depth-hit, R-hat, ESS and E-BFMI standards for
interpretable posterior summaries. Nonclean fits retain evidence and explicit
failure status; they do not silently produce scientific summaries.

The manifest defines separate sampling and predictive seeds per profile.
Use up to 1,000 evenly spaced joint draws for replicated histories and all
available draws for the mixture-of-Poisson-binomial richness calculation.
Retain conditional dependence through shared parameters when averaging this
distribution; do not calculate it from mean membership probabilities.

A finite-grid Bernoulli-hazard bridge checks identical joint and sequential
posterior weights when species effects and membership are retained, plus a
deliberately incorrect reset-membership control. Include explicit membership-
state enumeration, both period orders, all-zero histories, and detections in
either period. Any detection forces that candidate's membership to one.
This is a mathematical unit check, not a new simulation eligibility screen.

After completion, ask whether station patterns, temporal clustering or tail
sensitivity most directly limit useful prediction. Choose one discriminating
repair and preserve this baseline. Do not add spatial, seasonal, taxonomic and
availability hierarchies together simply because they are plausible.
