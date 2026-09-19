# Goal011 fixed scoring plan

This plan precedes later detection access. Main profiles and sensitivity roles
are fixed in goal011_models.csv. Assessment uses the same 29 discovery and 21
redetection candidates for all profiles, and the same realised effort.

At each cumulative horizon, record each candidate's future detection indicator,
and discovery only if its entire first-year history was zero. No species is
dropped because it was missed or difficult to predict. Unsampled zero-effort
cells are not nondetections, though a wholly unsampled horizon has zero chance
of recording a detection.

For each profile and horizon:

1. Species-level Brier score `(p-y)^2` and negative log predictive probability,
   separately averaged over discovery candidates, redetection candidates and
   all candidates. Retain per-species rows as an audit surface.
2. Negative log predictive probability of the observed additional-discovery
   count. Also report redetection and total future-detected counts, with their
   posterior predictive PMFs averaged over retained draws, median and central 90% intervals.
3. Taxon and encounter-class discovery count distributions, explicitly derived
   under the model's exchangeability assumption. These are descriptive splits,
   not separate ecological calibrations.
4. Observed versus predicted cumulative discovery at 13/26/52/101 weeks. Retain
   joint nested count paths for an honest display; marginal central intervals
   are pointwise, not simultaneous bands.

The focal empirical contrast is the primary spatial minus primary baseline
negative log score for the additional-discovery count at 101 weeks (negative
favours spatial). Shorter horizons and all other scores explain that result;
they do not supply independent replications or a later-selected winning
endpoint. Report every sensitivity profile, including unfavourable cases.

There is one array and one fixed forecast origin. Do not attach independent-
replicate standard errors, calculate nominal coverage from four nested windows,
or claim general superiority from a single realised count. Species share
posterior uncertainty; unseen species share the same marginal probability, so
their scores are not independent evidence for biological discrimination.

Compute logarithmic scores from saved stable log probabilities/PMFs, not by
logging rounded display probabilities or adding an arbitrary epsilon. True
zero mass on an observed event yields an infinite loss and is retained. Do not
clip failure away. Report Monte Carlo limitations separately from observation
error; path simulation is not used to estimate marginal scores, but finite MCMC
posterior integration still contributes Monte Carlo error.

No post-score tuning, class eligibility change or additional model can be
validated by this same forecast benchmark. Any subsequent model development
using its outcomes must declare that information exposure and use distinct
assessment evidence. Good encounter forecasts still do not reveal true total
richness or validate the never-detected candidate tail.
