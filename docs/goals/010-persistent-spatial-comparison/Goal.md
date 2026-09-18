# Goal010: persistent species-by-station comparison

Approved development work, 18 September 2026. Barry authorised autonomous
progress until a substantive blocker or a decision requiring his/Fable's input.
This carries forward the integrated methods-and-application paper and the
first-year development boundary. Routine stage transitions require no approval.
No external correspondence, publication, or Git push is implied.

## Question and reporting horizon

Does a persistent species-specific station effect repair the shared-station
model's failure to represent opposite spatial patterns, and how much does this
change inference about the unseen candidates? Compare against the corrected
Goal009 baseline. Interpret the mechanism, remaining failures, and sensitivity;
then prepare the next justified development or forecasting stage. Computational
completion is not ecological adequacy or richness validation.

Goal009 found 498 global ordering violations against baseline predictive 90%
intervals of about 117–211, and a selected species crossing of 18 against -9–1.
These checks concern the 21 detected species. Separately, conditional timing
permutations found 786 switches against 894–952 and fourth-block count 371
against 315–349. A static spatial model cannot remove calendar dependence
conditional on species-station totals; this comparison must not be sold as a
complete temporal model.

## Scope

Use only the frozen 50-candidate, nine-station, first-52-occasion Judbury tables.
No raw detections are needed. Later Judbury detections and all Huon observations
remain protected. The earlier three-row Judbury display remains disclosed in
Goal008/009; eventual later testing is not wholly blind. No candidate edits,
new routine/occasional contrast, expert presence constraint, or taxon-specific
prior is introduced here. Twenty-eight of 29 all-zero candidates are birds.

One added mechanism, four empirical prior combinations, two paired synthetic
mechanisms fitted with baseline and spatial models: eight fits, sequentially,
four chains at a time. Synthetic examples check implementation and mechanism;
they cannot estimate coverage, average error, or richness calibration.

## Decision principles

1. Establish input identities, mathematical invariants, correct joint posterior
   extraction, Stan/R agreement, and acceptable HMC diagnostics before reading
   ecological comparisons.
2. Evaluate spatial discrepancy repair jointly with total detections, species
   counts, station patterns and block/switch summaries. Report failures rather
   than selecting only favourable checks. Existing diagnostics are development
   checks, not prespecified confirmatory p-values.
3. Separate detected-species fit from unseen-tail inference. A narrower richness
   distribution or better spatial PPC does not establish more accurate richness.
4. Inspect sensitivity to both rate-tail and interaction priors. Report the
   common camera/interaction decomposition as prior-regularised, not uniquely
   likelihood-identified.
5. Preserve all attempts. Any execution repair is separately committed and run
   under a new output identity; never alter a running frozen analysis.

The current autonomous instruction permits bounded monitoring and interpretation
while doing useful work, rather than requiring another approval after startup.
Long-running work remains safely in deep-server tmux. Do not poll indefinitely;
if a practical handoff is necessary, record exact status commands and remaining
work. Consult for a consequential estimand/ecological assumption change, protected
access beyond the agreed forecast contract, or a real resource/access blocker.
