# Goal008 — retain species information; test station structure next

12 September 2026. **GO for the focused model-criticism direction; REPAIR the
proposed aggregate transfer before downstream fitting.** The diagnostic
tranche is complete. The full theory, revised estimator and integrated paper
remain in development; no method has earned empirical deployment by this work.

The first-year Judbury record changes the emphasis of the next experiment.
Only one of six occasional candidates was detected: a domestic dog in one
station-week. Meanwhile the routine category contains species with one to
215 positive station-weeks, and common mammals show opposite station-use
patterns. The most informative next test concerns persistent species
information and species-specific station structure, rather than a new prior
on an unmeasured routine-occasional class contrast.

## What is now established

**Dependence.** Repeated observations of the same species do not supply new
independent draws from a species population. A checked Gaussian example gives
78.0% coverage for a nominal 90% interval when that dependence is discarded,
versus 90% under the correct model. This quantifies a possible mechanism, not
the unrun Goal007 camera model's error. The exact fixed-detectability finite-
pool calculation also agrees with independent enumeration and integration.
See [Theory.md](Theory.md).

**Estimand.** Retain reference-period richness and distinguish it from
short-window use. Earlier detections fix reference membership to one under
correct identification. In an all-history revisit, future discoveries concern
species unseen in all supplied past history; historically known species
absent from a recent window are redetections. All comparators must receive
the same past information. No new dynamic availability model has been adopted.

**Empirical development.** The declared first 52 occasions contain 2,341 active
station-days, 341 sampled station-weeks, 127 unsampled station-weeks and 21
detected candidates (20 routine, one occasional). Twenty-nine candidates
remain unobserved. Incidence fractions are descriptive, selection-limited
observations, not estimates of the unseen class distribution.

Four successive 13-week blocks have 819, 576, 172 and 774 station-days.
The third block's outage prevents a simple seasonal interpretation. A
post-inspection example matching 30 identical weeks with complete operation
at both stations shows a stronger spatial contrast:

| Species | jc_pm12 | jc_pm23 |
| --- | ---: | ---: |
| Tasmanian pademelon | 29/30 weeks | 11/30 weeks |
| Tasmanian bettong | 0/30 weeks | 25/30 weeks |

The example controls calendar and effort differences; it does not make weeks
independent or establish a mechanism. It supports prioritising a shared-station
baseline predictive check and a species-specific station stress before a
seasonal hierarchy. The full matched table retains all 50 candidates.

**Historical evidence.** A reproducible retrospective join confirmed that all
nine catastrophic four/eight-week oracle fits belonged to 28-, 46- or 56-day
effort blocks with one to three active cameras. This does not rescind any old
gate or establish a new operational effort threshold.

## Verification and qualification

The independent [audit](Audit.md) returns PASS WITH LIMITATIONS. The complete
unit suite passed, including 48 new Goal008 expectations. Independent
recalculation verified all restricted detection/effort summaries, the matched
station example and the central mathematical identities. Source SHA-256
receipts match the executed final code; development dependency receipts were
collected retrospectively and are explicitly labelled as such. This is a
locally checked development run from uncommitted additions, not a frozen
remote production batch. No existing model, gate, candidate classification or
historical result was changed.

R is 4.6.1. `renv::status()` reports nlme 3.1-171 versus locked 3.1-170 and
survival 3.8-11 versus locked 3.8-9. These packages are not used by the new
diagnostic calculations; the environment was retained and its session recorded.
Do not call this a lockfile-exact replay.

There was an inspection incident: a worker displayed four raw records while
looking at the source schema, three from later Judbury dates. They did not
enter the analyses. [Exposure.md](Exposure.md) records the exact command,
extent as reported by the worker, and independent verification limits.
Later Judbury is retained for assessment with that disclosure, not labelled
wholly unseen. Huon Ridge has not been accessed.

## Deliverables and reproduction

Final numerical/figure evidence is under:

- `outputs/goal008/theory-v2/` — exact controls and seeded Gaussian check;
- `outputs/goal008/development-v1/` — restricted canonical histories and summaries;
- `outputs/goal008/legacy-v1/` — retrospective frozen-score decomposition;
- `outputs/goal008/synthesis-v2/` — matched-station example, overview figures,
  complete source receipts and session information.

Theory-v1 is superseded by the completed controls/provenance version. Synthesis-
v1 is superseded solely by corrected plot margins and a more descriptive title;
the matched counts are unchanged. These preliminary outputs are retained.

From the repository root, with the pinned external source checkout and the
existing Goal005 compact results available, generate outputs in a checkout
where the corresponding output destinations do not yet exist:

```sh
Rscript scripts/run_goal008_theory.R
Rscript scripts/run_goal008_development.R
Rscript scripts/summarise_goal008_legacy_evidence.R
Rscript scripts/synthesise_goal008.R
make test-goal008
Rscript scripts/run_tests.R
make manuscript-check
make manuscript
```

Runners refuse to overwrite their output directories. Theory accepts
`GOAL008_THEORY_OUTPUT` and the development runner accepts a relative output
directory as its first argument for a separately named replay. Synthesis
expects the canonical first-year outputs. No command opens Huon Ridge;
only the development runner reads raw Judbury and it applies the declared
timestamp filter before analytical use. Source receipt checks require the
same content, not the same current HEAD of the source checkout.

The working integrated manuscript is `manuscript/text/main.md`, with generated
PDF and editable DOCX under `outputs/manuscript/`. It builds through
`$HOME/work/makedoc` and includes inspected diagnostic figures. The final
10-page PDF and the editable DOCX (11 pages in LibreOffice) were rendered and
visually checked; manuscript lint, reference audit and build checks passed. It is an
incomplete scientific draft, with a Methods/Results core and explicit
outstanding analyses, not a circulation- or submission-ready paper. Authorship,
full literature positioning, journal choice and final empirical/external
evaluation remain to be completed. Nothing has been committed, pushed or
published in this tranche.

## Next scientific tranche

[NextExperiment.md](NextExperiment.md) specifies a coherent repeated-species
baseline and comparable discovery targets. Use the observed station contrast
to select one small predictive/interaction comparison while retaining the
constant-hazard control. Establish joint-versus-full-sequential equivalence
before Stan fits, then assess total/routine/occasional richness and discovery
under the same information. Do not substitute another class-mean precision
gate for these ecological endpoints. Any substantial run belongs on
deep-server in committed form and a named tmux session.
