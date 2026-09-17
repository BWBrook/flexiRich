# Independent audit — Goal008 diagnostic tranche

12 September 2026. Independent scientific reviewer, separate from the theory
and empirical implementation workers. Parent integrated this memo from the
reviewer's final report and checked the central numerical results directly.

**PASS WITH LIMITATIONS.** The theoretical correction, restricted first-year
description and next-experiment contract are scientifically coherent. No new
estimator, ecological mechanism, short-survey threshold or empirical richness
result has been validated.

## Evidence verified

- The repeated-species Gaussian control is correct for its known-variance,
  flat-location-prior benchmark. Incorrect independence gives exact nominal
  90% coverage 0.7798; correct repeated and fresh-species controls give 0.90.
  The 100,000-replicate results agree within Monte Carlo error.
- Independent integration over shared omega and membership states matched
  the exact finite-pool PMF to 8.6e-14. Theory-v2 passes zero/perfect visibility,
  enumeration and impossible-detection controls. Its SHA-256 source hashes
  match the theory and runner files.
- The repaired UTC+10 filter includes the first instant of 5 June 2019 and
  excludes the first instant of 3 June 2020. Sentinel tests pass; source call
  order filters dates before event construction and analytical aggregation.
- Restricted output contains exactly 50 x 9 x 52 unique detection cells and
  9 x 52 effort cells. Missing detections occur exactly at zero effort.
  Frequency, accumulation, station and block summaries reproduce from these
  tables. There are 979 positive candidate-station-weeks and 17,050 sampled
  candidate-station-weeks (341 sampled station-weeks for each of 50 candidates).
- Twenty-one candidates were detected: 20 routine and one occasional. The
  development block has 2,341 active station-days. These data cannot estimate
  or validate a quantitative routine-occasional class contrast.
- Block effort is 819, 576, 172 and 774 station-days. Seasonal interpretation
  is strongly confounded by effort and spatial coverage.
- From 30 identical fully operating weeks at the illustrated station pair,
  pademelon detections are 29/30 versus 11/30; bettong detections are 0/30
  versus 25/30. This motivates a shared-station baseline predictive check or
  species-by-station stress, not immediate adoption of a complex hierarchy.
- The canonical full test suite completed successfully, including 17 Goal008
  development and 31 theory expectations, without test failures, warnings,
  skips or errors. The renv startup diagnostic remains a separate limitation.

## Limits and repairs

The illustrated species/station pair was selected after descriptive inspection.
Weeks may be temporally dependent; it is not a significance test or an
independent confirmation of an ecological mechanism. The Gaussian example is
not a general posterior-coverage theorem, and fixed detectabilities are oracle
inputs. Ecological rate, availability and station uncertainty remain open.

The cutoff bug was found during source review and repaired before empirical
execution according to the worker. Tests also repaired missing-value handling
and the distinction between a detection flag and the original detection vector.
Final outputs and source hashes, rather than intermediate code, were audited.

Development provenance is recoverable through retrospective SHA-256 receipts
in `outputs/goal008/synthesis-v2/closeout-source-hashes.csv`. They include the
runner and R dependencies, base commit and dirty-state qualification. They
are not a prospective committed-run freeze. A later archive/commit must
preserve and link these exact files and outputs.

The current renv library differs from the lockfile for nlme and survival.
Passing tests do not establish lockfile-exact reproducibility. No environment
repair was made during the diagnostic work.

The worker's orientation displayed a header and four raw records, including
three later records. Final calculations exclude later observations, but later
Judbury cannot be described as wholly unseen. See [Exposure.md](Exposure.md).
The reviewer did not audit the worker's complete tool history; the extent of
exposure beyond output verification rests on its explicit self-report.

## Recommended next move

The next-experiment contract correctly distinguishes known historical
reference membership, first discoveries from all supplied history, recent-
window redetections, and an uncalibrated snapshot. Comparable repeat-monitoring
methods receive the same history. Historical four/eight-week eligibility rules
do not transfer unchanged. Persistent identity is required; spatial/temporal
mechanisms remain competitors.

The strongest next move is a small baseline predictive or simulation comparison
focused on species-specific station structure, retaining constant hazard as
the control. The single detected occasional candidate provides no empirical
basis for another class-contrast regulariser.
