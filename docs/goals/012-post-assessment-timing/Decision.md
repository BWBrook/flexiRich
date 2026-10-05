# Goal012 decision: temporal clustering survives movement and seasonal controls

5 October 2026. **REPAIR the encounter process.** Accounting for the known
camera movements reduces the timing discrepancy only modestly. Conditioning
on recurring seasons or successive 13-week detection totals reduces it further,
but detections still occur in more sustained runs than the conditional controls
produce. Neither camera placement alone nor these coarse temporal margins
are sufficient descriptions of weekly encounter timing.

This is post-assessment development using the already-open full Judbury record.
It strengthens the reason to develop a temporal component; it does not select
a seasonal, occupancy-turnover or persistence model, establish local extinction,
or validate the remaining unseen richness.

## Field information and camera movements

Barry recalled no material monitoring changes beyond the documented camera
movements. His independent wombat knowledge concerns a site about 1 km away,
not strictly Judbury. That is regional context, not a site-specific first-year
presence label. The existing Judbury photograph at occasion 143 remains direct
full-reference-period evidence; its late timing does not date arrival.

The nine analytical station IDs pool 13 physical camera placements. Four move
pairs affect co1, co3, pm14 and pm34. The five station-weeks containing move
endpoints were held fixed and excluded from adjacent comparisons. The 19 whole
weeks in pm14's declared deployment gap all have zero effort in the original
operation-derived table. No effort or detection values were changed and no
within-week observations were reassigned to physical locations.

## Main comparison

There were **2,937 detection/nondetection switches among 27,846 eligible
adjacent species-station-week pairs**. Every control used those same pairs,
within movement periods and with both weeks sampled. Each randomisation
preserved species, nominal station, exact active-day count and all unsampled
cells, with the additional margins below.

| Additional margins preserved | Exact expected switches | Central 90% shuffle range | Observed minus expectation |
|---|---:|---:|---:|
| None: nominal-station sensitivity | 3,898.9 | 3,836–3,961 | −961.9 |
| Movement period: primary static control | 3,811.0 | 3,751–3,870 | −874.0 |
| Movement period and recurring austral season | 3,611.2 | 3,552–3,669 | −674.2 |
| Movement period and successive 13-week block | 3,249.9 | 3,198–3,301 | −312.9 |

Fewer switches mean greater temporal clustering. None of 1,999 randomisations
per control produced as few switches as observed. The plus-one tail estimate
is 0.0005; the two-sided 95% binomial Monte Carlo interval for a zero count is
0–0.00184. These are finite simulation summaries under conditional
exchangeability, not probabilities of a biological explanation.

The fourth control also fails when comparisons are restricted to adjacent
pairs inside the same 13-week block: 2,726 switches versus exact expectation
2,987.9 and range 2,937–3,038. Thus its discrepancy is not created solely by
cross-block comparisons. Shifting the block phase by four or eight weeks
leaves the all-pair exact expectation at 3,228.3 or 3,211.4, still above 2,937.
Corresponding within-phase deficits remain 248–262 switches; no phase was
selected. Alternate phases have exact means only, not simulated tail intervals.

There were also 2,283 consecutive positive pairs, versus 2,121.6 expected
(range 2,096–2,149) under movement-plus-block conditioning. This is related
supporting description, not an independent replication of the switch result.

Preserving movement margins lowers the expected switch count by about 88.
That is attenuation after conditioning on placement-period totals, not a
causal fraction attributable to moving cameras. Placement changes coincide
with calendar time and were not randomized.

## What the species histories can support

The full panel has 7,644 active station-days and 3,845 positive
species-station-week cells. Twenty-six candidates were recorded; the remaining
24 have no detections. Pademelon, brushtail possum, red-necked wallaby and
bettong contribute 62.2% of positive cells. Residual clustering also appears
in other frequently recorded taxa, with the forest raven contributing the
largest absolute switch deficit under the block control. This is not solely
a pattern created by the three species missing from the later period.

Conversely, ten recorded species have only one to three positive cells.
The eastern barred bandicoot, spotted-tailed quoll and dog had respectively
two, one and one first-year positive cells and no later detections. The five
later additions each have one or two positive cells. These histories cannot
distinguish transient use, very low encounter rates, changes in availability,
or continued presence without detection. The quoll's reviewed common-name
label is Bindjulang; scientific identities and labels remain unchanged.

The block control retains 790 mixed strata and 9,087 cells capable of changing
under randomisation; 9,263 eligible pairs touch such cells. Conditioning does
not remove all diagnostic information, but species-level support varies greatly.
All 26 species' summaries are supplied without significance-based selection.
Because the controls condition on full-period species-by-station totals, they
do not assess the model's predicted numbers of additions or missed returns.
They diagnose the allocation of detections through time conditional on those
totals. Goal011 remains the evidence for the forecast discrepancy.

## Next scientific comparison

Keep the fixed full-period community definition and spatial heterogeneity.
First represent the known camera-placement changes explicitly as observation
structure. Then test a single parsimonious source of correlated temporal
encounter variation against a movement-aware static baseline, using matched
synthetic controls before another Stan batch. Temporary changes in encounter
availability are a suitable starting hypothesis; their latent state must not
be interpreted automatically as absence from the candidate community.

The next proposed comparator is an array-wide species-week encounter-availability
state with first-order persistence, multiplying the retained movement-aware
species-by-station encounter rates. Starting with an array-wide state limits
the identifiability burden. Do not add seasonality simultaneously. Matched
synthetic controls must include the static boundary, placement changes alone,
shared temporal variation and station-specific variation that could falsify
this simpler representation.

That is a proposed scientific formulation, not a mechanism established here.
The current controls do not distinguish array-wide from station-specific
variation. Common taxa supply most timing information; borrowing their dynamics
for rare or unseen candidates requires explicit sensitivity and recovery checks,
including discovery and redetection predictions. Do not retrofit a winning prior
to Goal011 or label an improved Judbury fit external validation.

Seasonal conditioning pools about three annual cycles; block origins are
arbitrary; weekly active-day totals omit within-week timing; and independent
species permutations do not preserve shared environmental fluctuations.
Those limitations prevent a unique mechanistic conclusion. Huon Ridge remains
unopened. Distinct assessment evidence is needed for any revised model.

See [the runbook](Runbook.md) for reproduction and the previous remote-job
status commands, and [verification](Verification.md) for checks and retained
evidence. Main outputs are `outputs/goal012/timing-v2/`.
