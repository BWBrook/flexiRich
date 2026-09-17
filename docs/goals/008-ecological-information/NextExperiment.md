# Next experiment — coherent repeat monitoring

Status: recommendation developed during Goal008, not a frozen production run.

## Question and ecological meaning

Can retained information about the same named species improve reference-pool
richness and future discovery predictions without the artificial precision
created by treating repeated species as fresh population draws?

Retain the 153-week reference-period target for continuity. A candidate detected
anywhere in the supplied past history is a known member of that reference
pool, under correct identification. A short-window zero for that candidate
is information about encounter/availability, not evidence that it was never
a reference member. No dynamic availability model is adopted by that statement.

For an all-history revisit benchmark, the information set at cutoff t is all
permitted observed history up to t. New-species predictions concern candidates
unseen in that entire information set. Recent-window novelty/redetection is
a distinct secondary prediction and must be labelled accordingly. Every
comparator gets the same historical evidence and known-member constraints.
An uncalibrated short snapshot receives different information and is reported
as a separate application. The old four/eight-week rejection rules cannot be
transferred automatically to the richer information set.

## Smallest coherent model and controls

Start with the existing effort-aware finite-pool observation model applied
jointly to calibration and target histories, preserving species identities.
The joint likelihood has one species effect (or one explicitly specified
persistent component) per candidate, not one independent species draw per
period. Known detections constrain reference membership to one. All-zero
candidates remain uncertain and all 50 reviewed candidates remain in scope.

Using the full candidate panel is an untruncated sampling model. It must not
also subtract a detected-species selection normaliser. The old normaliser
remains appropriate to the separately specified detected-only calibration
experiment; its correctness did not make the aggregate transfer interface
adequate for repeated species.

Before a Stan batch, use small mathematical examples to compare a joint
likelihood with a sequential update retaining the full relevant joint
posterior. They must agree for the same prior, data and model. Compare the
old aggregate interface only as a deliberately lossy, dependence-misspecified
diagnostic. A fresh-species control has genuinely independent species effects
and is explicitly a different generative problem.

The constant-hazard/shared-station structure is the baseline. Species-specific
station effects, period effects, intermittent availability and heavy encounter
tails are competing explanations for departures, not layers to add together
by default. The early-development evidence should choose the first informative
stress and model comparison. A small class cannot identify an unrestricted
rate distribution or cross-reserve transport variance by itself.

## Outcomes and uncertainty

Report total richness and its routine/occasional components, missed-member
probabilities and future-discovery count/identity predictions. A useful model
may return a wide richness posterior; class-mean precision alone is not an
eligibility requirement. Report prior sensitivity and changes in information
explicitly. Correct computation, calibrated prediction and biological recovery
are separate results.

Use paired ecological streams with adequately replicated decisive contrasts.
For example, 100 independent datasets give a binomial Monte Carlo standard
error of about 0.03 at coverage 0.90; more are needed for precise tail-risk
claims. Pairing and shared streams across richness/duration cells must be
retained in uncertainty calculations. This is a precision illustration, not
an approved final simulation budget or an all-pass selection rule.

Describe performance against realised effort and active stations, retaining
outages. Any proposed effort threshold needs new validation rather than a
post hoc exclusion of the historical failing blocks.

## Evidence boundaries and execution

Only first-year observations entered Goal008 analyses. Three later records
were inadvertently displayed during worker schema inspection; see Exposure.md.
The later record is retained for assessment with that disclosure, not claimed
as wholly unseen. Freeze
the implemented comparison, seeds and evaluation rules before later Judbury
assessment. Outcomes after each forecast cutoff remain unavailable to that
fit; learning modelling decisions from the whole later benchmark would make
it development evidence. Huon Ridge remains a separate external case until
the method and transport assumptions are fixed.

New empirical or Stan-intensive batches require a committed source/input/run
contract on deep-server in a named tmux session. Verify startup and expected
output, then hand monitoring to Barry with the prescribed status commands.
The next tranche should produce one discriminating ecological comparison,
not another broad search over contrast priors.
