# Goal012: post-assessment Judbury timing diagnosis

5 October 2026. Approved continuation of the integrated scientific programme
under Twilight Laboratory. Goal011 and its frozen forecasts remain sealed.
This tranche uses its already-open outcomes for **post-assessment development**.
It is not a new validation dataset or a registered confirmatory test.

The reporting endpoint is a reproducible account of timing and camera effort,
movement-aware conditional controls, one independent check, and a decision
about what the next temporal formulation must explain. Work is small local
data processing and conditional randomisation; no model fitting is required.

## Field context and information boundary

Barry confirmed on 5 October that the relevant monitoring changes were the
camera movements already documented. His independent wombat knowledge is from
a site about 1 km away, not strictly Judbury. Treat that as nearby evidence,
not an independent first-year Judbury presence label. The later Judbury
photograph remains direct evidence within the full reference period.

Use the sealed Goal008 first-year incidence and Goal011 assessment-v3 future
incidence, their calendars, the reviewed 50-candidate pool, and original effort.
No raw observations or Huon Ridge records are needed. Do not revise the pool,
membership definition, first-year predictions, or any Goal011 result.

The copied deployment ledger comes from camtrap-workflow commit
`510bf381d43df8f90b7f5b3d1eb960721d3f45d2`, path
`docs/goals/008-judbury-deployment-evidence/judbury_deployment_ledger.csv`,
SHA-256 `0921eb8845c2bb1ad5760271f283ab2783735b7739e254c67e9243bc906f3ebf`.
Its literal proposed-version fields are preserved; that exact evidence packet
was subsequently accepted and published at `377c0fd4f78513885a3f2b53308e788bfa8d1cb4`
as recorded in the source Goal008 Log. The service ledger is not effort
authority. `jc_op.csv` remains the source of the frozen weekly effort.

## Comparisons fixed before this diagnostic run

Four move pairs map to existing nominal stations: co1 (14 October 2019), co3
(29 November 2021), pm34 (22 June 2021), and pm14 (old placement ending
14 October 2019, new placement starting 26 February 2020). Canonical weekly
incidence cannot assign an observation within a boundary week to a placement.
Hold every week containing either move endpoint fixed, and omit adjacent pairs
involving those weeks. Retain the pm14 gap exactly as recorded by effort; flag
any positive effort in a whole week strictly within its declared gap.

Condition on species × nominal station × exact positive active-day counts.
Shuffle binary weekly detections under four calendar constraints:

1. **Nominal station:** pool clean weeks across movement periods.
2. **Movement periods:** additionally preserve counts within time segments
   delimited by recorded move endpoints. This is the primary static timing
   control; the nominal-station version is a sensitivity baseline.
3. **Movement periods and season:** additionally preserve counts in recurring
   austral seasons, assigned from each week's midpoint (DJF/MAM/JJA/SON).
4. **Movement periods and 13-week blocks:** additionally preserve counts in
   consecutive blocks from the original first occasion; the last is shorter.

These are conditional controls, not fitted ecological models. Movement periods
are calendar strata, not a reconstruction of physical-location event routing.
Seasonal conditioning cannot demonstrate a seasonal mechanism; block
conditioning can absorb several different slowly varying processes.

Use the same eligible adjacent pairs for all controls: both weeks sampled,
neither a boundary week, and both in the same movement period. Count detection/
nondetection switches, consecutive positive pairs, and switches restricted to
pairs within the same 13-week block. The switch statistic is primary;
consecutive positives are related supporting description, not independent
evidence. Report species contributions for the fixed full-period detected set.
The set is invariant under these count-preserving permutations.

Use 1,999 randomisations per control, seeds 2026100501 through 2026100504,
Mersenne-Twister/Inversion/Rejection. Report central 90% reference ranges,
exact conditional means, tail counts and binomial Monte Carlo intervals.
Zero tail counts do not imply zero probabilities. Check all stratum margins
and missingness. Tiny exhaustive-enumeration tests verify the exact pair
expectations independently of the Monte Carlo implementation.
Report exact-mean sensitivity to block phases shifted by four and eight weeks;
do not select a phase or run additional searches from the resulting contrasts.

Report how many strata can vary and how many eligible pairs touch variable
cells. Species tails and the multiple related controls are exploratory; they
do not constitute independent tests or establish a uniquely identified process.
The conditional null randomises species independently, so community totals
also depend on this cross-species exchangeability assumption.

## Acceptance and stopping point

- Reconcile all 68,850 candidate-station-week cells, 50 candidates, nine
  stations and 153 weeks with their source hashes; preserve zero-effort NAs.
- Describe effort, species timing, station use and movement boundaries, with
  an inspectable figure and reusable tables.
- Verify the conditional calculation on finite toy examples and check the
  actual outputs and interpretation independently.
- State what movement, seasonal and coarse temporal conditioning do and do
  not resolve, and recommend the next scientific comparison.

No seasonal, turnover or availability model will be selected solely by which
conditional reference interval contains a statistic. Any resulting model is
developed on Judbury and needs distinct assessment evidence. New Stan batches
remain subject to the repository's committed remote-run contract.
