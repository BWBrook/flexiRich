# Goal011 decision: spatial repair does not repair temporal encounter prediction

23 September 2026. **REPAIR the temporal observation model; retain the spatial
structure and the frozen comparison.** The assessment is complete. Neither
primary model is ready for operational richness inference or Huon Ridge
validation. No new fit or prior profile was chosen from these outcomes.

## Ecological conclusion

Representing how different species use different stations improved first-year
spatial fit, but changed predictions of later discoveries very little. The
stronger new finding concerns species already photographed: both primary
models expected too many of them to be photographed again. Later additions
partly offset these missing returns, so an acceptable total count can conceal
opposing errors in its components.

This identifies a failure of temporal encounter prediction. It does not identify
local extinction, colonisation, seasonality, animal persistence, changing camera
performance, or excessive shrinkage as its unique cause. The three species
not redetected were very sparsely recorded in the first year. Their continued
membership of the fixed full-period candidate community is not revoked by
later non-detection.

## Frozen primary comparison

Training used occasions 1–52; assessment used occasions 53–153 and 5,303 active
station-days. The two primary models have the following pointwise central 90%
predictive intervals. The observed counts are identical for all profiles.

| Future weeks | Additional discoveries | Primary discovery interval, both | Known species redetected | Primary redetection interval, both |
|---:|---:|---:|---:|---:|
| 13 | 0 | 0–1 | 12 | 13–17 |
| 26 | 0 | 0–2 | 14 | 15–20 |
| 52 | 3 | 0–4 | 16 | 17–21 |
| 101 | 5 | 0–5 | 18 | 19–21 |

These are four nested observations from one origin, not four independent
coverage trials. The discovery intervals contain all four counts, but that
does not establish calibration. At 101 weeks, primary expected discoveries
were 1.896 (shared station) and 1.935 (spatial); five additions lie at their
upper interval endpoint. The focal negative log scores are 3.188605 and
3.164077, respectively. The spatial-minus-baseline contrast is **−0.02453**,
compared with an approximate MCMC integration MCSE of **0.06488**. There is no
resolved primary advantage on the frozen focal score.

The later window contains 23 species in total: 18 redetections and five new
discoveries. Both primary total-detection intervals are 20–25, although their
expected components are about 20 returning species and two additions.
Component-wise criticism is therefore more informative than the total alone.

Primary mean redetection Brier scores at 101 weeks are 0.11699 and 0.11423;
mean logarithmic losses are 0.36059 and 0.34570. These small descriptive changes
do not erase the count discrepancy or establish transferable superiority.
The spatial model's mean logarithmic score is slightly worse at 13 weeks,
so it is not uniformly better across the retained summaries.

## Species that explain the pattern

All five additions belong to the existing routine class:

| Species | First later photograph | Occasion |
|---|---|---:|
| Tasmanian native-hen, *Tribonyx mortierii* | 1 January 2021 | 83 |
| Brush bronzewing, *Phaps elegans* | 5 January 2021 | 83 |
| Superb fairy-wren, *Malurus cyaneus* | 28 January 2021 | 87 |
| Eurasian blackbird, *Turdus merula* | 15 September 2021 | 120 |
| Bare-nosed wombat, *Vombatus ursinus* | 26 February 2022 | 143 |

The wombat is now directly confirmed within the full reference period. Its
late photograph does not establish when it first used the site or whether it
was independently known to be present before the training cutoff. It is no
longer a never-detected species; an expert-oracle comparison about its earlier
status still requires independent temporal and spatial provenance.

Three first-year species were not redetected:

| Species | First-year positive station-weeks | Weeks | Primary spatial probability of later redetection |
|---|---:|---|---:|
| Eastern barred bandicoot, *Perameles gunnii* | 2 | 7, 8 | 0.952 |
| Spotted-tailed quoll, *Dasyurus maculatus* | 1 | 5 | 0.854 |
| Dog, *Canis familiaris* | 1 | 16 | 0.835 |

These sparse histories support cautious investigation of transient use,
temporal dependence and rate uncertainty, rather than an assertion that three
established populations disappeared. The missed dog accounts for roughly half
of the descriptive primary-model difference in redetection loss. The five new
species all had the same marginal forecast under each profile: the model has
no information to distinguish their identities among the 29 unseen candidates.

## Every sensitivity retained

| Profile | Expected discoveries at 101 weeks | Discovery 90% interval | Discovery negative log score | Redetection 90% interval |
|---|---:|---:|---:|---:|
| Shared primary | 1.896 | 0–5 | 3.1886 | 19–21 |
| Spatial primary | 1.935 | 0–5 | 3.1641 | 19–21 |
| Shared wider rate tail | 2.159 | 0–5 | 2.9477 | 19–21 |
| Spatial wider interaction | 1.915 | 0–5 | 3.1961 | 19–21 |
| Spatial wider rate tail | 2.174 | 0–5 | 2.9419 | 18–21 |
| Spatial both wider | 2.190 | 0–6 | 2.9116 | 18–21 |

Wider rate tails improve the final discovery score and, for the two spatial
profiles, include the final redetection count at the lower interval endpoint.
All six profiles still put the observed redetection counts below their central
intervals at 13, 26 and 52 weeks. These are sensitivity findings, not a licence
to select a new winning prior on the assessed data. Changes in interval endpoints
are not a biological adequacy criterion.

## Provenance and limits

All six predictions, joint draws, fixed scoring rules and audit evidence were
committed before bounded outcome access. The archive is complete and the
original predictions remain unchanged. The successful assessment uses commit
`9fcb4f5` and `outputs/goal011/assessment-v3/`; two preceding integration failures
are preserved. The first did not read outcomes; the second began bounded
access at 2026-09-23 01:38:27 UTC, reproduced the first-year incidence table,
then stopped on an effort-key schema mismatch before scoring. Both repairs
preserved the scientific definitions and predictions.

The final additional count was already derivable from the historically
disclosed full-period total of 26 minus the first-year total of 21. This focal
comparison is a retrospective check of a disclosed aggregate, not a newly
revealed blind endpoint. The known three-row exposure also remains disclosed.
Timing and named outcomes add information, but this is one retrospectively
assessed array conditioned on realised effort. Future detections do not reveal
the true richness of the remaining candidate community. Huon Ridge is unopened.

## Next scientific decision

Keep the spatial extension, avoid further routine/occasional contrast priors,
and investigate the temporal encounter process before another richness claim.
Barry's field context is now material: were animal use, habitat, camera
locations/settings or image-processing rules changing; and was the wombat
known independently during the first year? This information can distinguish
plausible mechanisms and prevent fitting an elaborate ecological story to a
few isolated encounters.

Recommend a bounded follow-up using the now-open Judbury record for explicitly
post-assessment development: describe species-by-station timing and effort,
then compare the simplest field-supported temporal mechanism with the retained
static spatial model using cheap matched controls before any Stan batch.
Do not select a seasonal, persistence or turnover model solely from the four
nested count discrepancies. Any model revised using these outcomes needs
distinct assessment evidence. A reviewed Huon Ridge candidate pool and the
deployment/service metadata remain prerequisites for its eventual use; future
downloads offer the clearest genuinely prospective layer.
