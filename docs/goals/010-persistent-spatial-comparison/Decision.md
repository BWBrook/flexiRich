# Goal010 decision: retain spatial structure and move to observable forecasts

19 September 2026. Completed development comparison, using first-year Judbury
only. The frozen run used commit `bff200a2b4e36d87a96c5b034e4e8f3491cd174c` and
finished with exit 0. Later Judbury outcomes and Huon Ridge remain unopened in
this stage. Independent interpretation review is recorded separately.

## Ecological conclusion

Different species use the camera stations differently. Allowing those persistent
differences repairs both conspicuous spatial failures of the shared-station
model. This is a successful, biologically interpretable development step.
It does not establish habitat preference or its cause, and the diagnostics were
chosen after inspecting first-year data, not tested on a new empirical sample.

The spatial model still scatters detections too freely across time. It reduces
the excess of switches between detection and non-detection by roughly half,
but the remaining discrepancy and late-year excess are substantial. Static
station structure was part of the temporal failure, not its full explanation.
The existing conditional permutation analysis had already established calendar
nonexchangeability independently of fitted static station patterns.

Richness is almost unchanged. Repairing an evident observation-model failure
has not supplied much additional information about the 29 unseen candidates.
Their membership remains an inference under the common encounter hierarchy,
not a validated estimate of the local bird or mammal community.

## Main comparison

Central 90% predictive intervals below; latent richness is a different quantity.

| Statistic | Observed | Shared-station primary | Spatial primary |
|---|---:|---:|---:|
| Total positive station-weeks | 979 | 927–1,034 | 930–1,031 |
| Global station-order violation | 498 | 118–207 | 413–616 |
| Selected opposite species crossing | 18 | -9–1 | 9–22 |
| Adjacent-week switches | 786 | 985–1,119 | 860–984 |
| Fourth-block positives | 371 | 305–359 | 309–357 |

The four spatial prior combinations give the same interpretation. Their global
station intervals span about 409–619; crossing intervals are 8–22. Switch
intervals remain about 854–984, and fourth-block intervals about 306–357.
Only 2–4 of 1,000 replicates per spatial profile reach the fourth-block total.
Finite Monte Carlo tail fractions are descriptive checks, not calibrated tests;
zero observed replicates must not be interpreted as zero probability.

Primary interaction SD tau has median 0.895 and 90% interval 0.758–1.056 log-rate
units; widening its prior moves the median to 0.923 (0.775–1.097). Thus the
spatial discrepancy repair is not critically dependent on the narrower tau
prior within this comparison. This does not test different interaction families.

| Profile | Mean latent richness | Median | Central 90% interval |
|---|---:|---:|---:|
| Shared primary | 24.39 | 24 | 21–30 |
| Shared wider rate tail | 25.31 | 25 | 21–32 |
| Spatial primary | 24.57 | 24 | 21–30 |
| Spatial wider interaction | 24.58 | 24 | 21–31 |
| Spatial wider rate tail | 25.51 | 25 | 21–32 |
| Spatial both wider | 25.53 | 25 | 21–32 |

These remain model-dependent development outputs, not calibrated richness
estimates. Spatial primary implies 3.57 expected unseen members; widening the
rate tail raises this to about 4.51. Mean membership among the 29 all-zero
candidates is 0.123 under primary and about 0.155–0.156 under wider rate tails.
They are exactly exchangeable in this model. Small candidate-specific Monte
Carlo differences in the saved tables must not be interpreted as ecological
information about the wombat versus individual birds.

## Controls and computation

All four fixed synthetic controls completed cleanly. In the crossing mechanism,
observed global violation 61 falls outside the baseline interval 6–28 and inside
the spatial interval 38–78. Spatial switches 103–149 contain the observed 126;
the baseline interval is 137–182. In the zero-interaction mechanism, both
models accommodate the observed spatial statistic 17. These are useful matched
examples, not replication-based coverage or richness-recovery evidence.

The primary empirical spatial fit passed without rescue. Wider interaction
needed rescue for R-hat 1.01077; wider rate tail for R-hat 1.01053 and bulk ESS
321; both wider for bulk ESS 367. The prespecified longer, more cautious rescue
fits passed all unchanged criteria. There were no divergences, depth hits or
captured warnings in any of the 11 attempts. Across final empirical fits,
maximum R-hat is 1.00857, minimum bulk ESS 474, minimum tail ESS 1,095, and
minimum E-BFMI 0.808. Trace/rank inspection supplements these numerical checks.

Every fit's direct Stan/R bridge passed: largest likelihood error 2.28e-13,
membership error 1.12e-16, and expected-richness error 7.11e-15. Station log rates
matched their component sums exactly in selected saved draws. The shared
camera/mean-observed-interaction correlations range from about -0.74 to -0.51,
as expected from their prior-regularised decomposition; do not give separate
causal interpretations to b and u. Scientific interpretation rests on station
log rates and predictions, not a uniquely likelihood-identified decomposition.

## Next action

Retain the spatial model as the revised observational candidate and preserve
the shared-station model as a transparent comparator. Freeze their fixed-origin
forecasts for occasions 53–153 at nested 13/26/52/101-week horizons before reading
those outcomes. Carry all existing prior profiles through as sensitivity cases;
do not choose a favourable profile from later forecast performance.

Use the already reviewed full effort template to make **retrospective forecasts
conditional on realised effort**. These are neither operational planned-effort
forecasts nor wholly blind confirmation (see the prior exposure disclosure).
Predict first discoveries among the 29 historically unseen species separately
from redetection of the 21 known members. Preserve the joint posterior and
persistent same-station effects. Score observable species events and discovery
counts; future detections still do not reveal true total richness.

A further temporal component is scientifically motivated, but one year's
clustering does not identify repeatable seasonal dynamics. Do not add another
flexible model before learning whether the current spatial repair improves the
held-out observable task. Freeze scores, effort, models and predictive objects,
obtain independent forecast-contract review, then assess the existing models
without tuning on that benchmark. Any later model development using those
outcomes must be labelled accordingly and tested on different evidence.
