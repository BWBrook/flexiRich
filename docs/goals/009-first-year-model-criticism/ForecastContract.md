# Judbury forecasts and Huon Ridge assessment

Status: implementation-stage design, not a frozen forecast or a claim that
predictions have already been generated. Final model and predictive objects
must be committed before later detection outcomes are accessed.

## Judbury

The first target is a fixed-origin forecast trained on occasions 1–52 and
assessed over occasions 53–153. Report cumulative horizons of 13, 26, 52 and
101 weeks from that origin. These horizons are nested, not four independent
replicates. An operational update sequence may follow as a separate exercise;
its refitting schedule and information sets must be fixed before evaluation.

For each candidate, predict detection and first discovery by each horizon.
First discovery means unseen in all history supplied before the cutoff.
Detection of a previously photographed species is redetection. Retain its known
reference-period membership; short-window absence cannot reverse that fact.
All comparators receive the same history, candidate list and effort information.

Save probabilities for each species and full distributions of additional
discovery counts, including mammal/bird and routine/occasional summaries.
Assess per-species Brier and log scores, count log scores, predictive intervals
and observed-versus-predicted accumulation. Preserve infinite log-score failures
if a model assigns probability zero to an observed outcome. Repeated species
and nested horizons cannot be treated as independent coverage trials. No true
richness is supplied by the complete detected list, so forecast success alone
does not validate recovery of total richness.

Keep two effort interpretations separate: an operational forecast conditional
on planned effort, and a retrospective detection forecast conditional on realised
effort. A realised-effort assessment must be labelled as such and obtain only
effort metadata before predictions, never future species outcomes. Camera outages
must not be removed after inspecting forecast errors. The final freeze must name
the effort source, active-day treatment and horizon endpoints.

The original primary/wider-tail fits may be retained as transparent baseline
forecasts even if their first-year predictive checks fail. The development
decision about a single revised model is made from the first-year evidence.
No model, threshold or species eligibility may be tuned on the later benchmark
and then described as independently validated by that same benchmark.

Record the known historical aggregate disclosures and Goal008's limited raw-row
exposure. These later data remain useful held-out temporal assessment, but not
wholly blind confirmation. Do not drop selectively exposed periods.

## Huon Ridge

Barry's latest deployment account is 14 original cameras, nine later additions,
then three more. These counts and approximate durations are user-provided context,
not yet verified deployment metadata. Before opening detections, obtain the
reviewed candidate pool, station identities/coordinates, deployment/service dates,
and an account of trail placement and changes. Do not infer absence or redefine
eligibility from model failure.

1. Original 14 cameras: one external assessment of the frozen Judbury-developed
   procedure. Specify any allowed Huon Ridge calibration history before access;
   testing a locally recalibrated procedure differs from transferring rates.
2. Later nine and three cameras: conditional prediction into an expanded network.
   Separate densification from area expansion using deployment metadata. These
   cameras share species and environmental history with the original network;
   they are not an independent reserve replicate.
3. Future observation periods: recurring prospective forecasts fixed before the
   periods begin, with predictions preserved before each download. A new download
   is not automatically prospective if its observations already informed anyone's
   model development. Record human and agent information exposure.

Service-date alignment determines comparable temporal windows. Independent wombat
presence at Judbury is useful only with its spatial, temporal and observation
provenance; it would support a targeted known-member comparison, not known rate
or whole-community truth. These questions remain for Barry and do not block
the first-year baseline check.
