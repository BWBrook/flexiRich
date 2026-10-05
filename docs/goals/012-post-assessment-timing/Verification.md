# Goal012 verification

Completed 5 October 2026. Accepted as bounded post-assessment model criticism.

## Data and execution

- Eleven input hashes matched the frozen Goal011 inputs/assessment receipts
  and copied deployment-ledger hash. The full 50 × 9 × 153 grid contains
  68,850 incidence cells, with NA exactly where effort is zero.
- All 1,377 station-week effort values match the original template, totaling
  7,644 active station-days. All 200 candidate-horizon outcomes match the
  completed Goal011 assessment. Recorded species counts remain 21 in the
  first year, 23 in the later window and 26 overall.
- Four movement pairs produce five fixed transition station-weeks: co1/19,
  pm14/19, pm14/39, pm34/107 and co3/130. All 19 whole gap weeks at pm14 have
  zero effort. Every main control uses the same 27,846 eligible pairs.
- The completed run is `outputs/goal012/timing-v2/`, exit 0. It used one CPU
  for 2 minutes 57 seconds with maximum RSS 310,188 KiB and no swap. It read
  neither raw observations nor Huon Ridge records and performed no new fits.
- The exploratory run used local Goal012 additions to base HEAD `9f17d48`.
  Three code/specification hashes identify the executed source exactly;
  it is not represented as an analysis already committed at that base HEAD.

## Mathematical and numerical checks

`make test-goal012` passed 96 expectations. Tests exercise exact-effort and
context strata, singleton/fixed boundaries, zero-effort cells, margin
conservation over repeated shuffles and exhaustive one/two-stratum allocations
for pair expectations. All four empirical controls additionally check every
stratum count and the full NA pattern on each of 1,999 randomisations.

For a pair in the same stratum with n cells and k detections, the exact
switch probability is `2 k (n-k) / [n (n-1)]` and the consecutive-positive
probability is `k (k-1) / [n (n-1)]`. For two distinct, independently shuffled
strata with marginal probabilities p and q, these are `p+q-2pq` and `pq`.
Summing these probabilities gives the exact conditional means; Monte Carlo
provides the reference ranges and finite tail counts.

A separate scientific reviewer independently reconstructed the calculations
from long tables. All observed counts, exact expectations, stratum and mixed-cell
counts, masks and phase-0/4/8 results agreed. Replay of the saved RDS draws
reproduced every simulation mean within 4.1e-12, all type-1 quantiles and all
tail counts. Across the 12 aggregate summaries, simulated means differed from
exact means by at most 2.024 estimated Monte Carlo standard errors.

## Independent review and artifact checks

The reviewer accepted `timing-v2` with no remaining blocker. The review verified
all 11 input, three code and 24 output receipts, PDF structure, both raster
overview figures and selected station pages spanning all moved cameras. The
parent inspected the overview images and the summary figure. The README and
decision distinguish conditional model criticism from a new forecast test,
mechanistic identification and richness validation.

The review caught a mismatch in the optional shifted-block summary before
acceptance: its within-block statistic initially kept the original phase's
mask. Run v1 was interrupted and preserved, including its executed script,
partial tables and log. V2 recalculates both the observed statistic and exact
expectation for each phase's own mask. Primary comparisons and all inputs
were unchanged. No v1 numerical result is used in the decision.

The complete evidence is archived with restore instructions under
[evidence/README.md](evidence/README.md). The original Goal011 forecast,
assessment and manuscripts remain unchanged. The proposed next temporal
formulation has not been implemented or fitted.
