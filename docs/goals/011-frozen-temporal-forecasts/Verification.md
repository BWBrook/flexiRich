# Goal011 pre-generation verification

19 September 2026. All inputs and calculations here precede later outcome access.

- SHA-256 receipts match all six complete saved prediction-draw objects, both
  parent terminal-status tables, restricted first-year data and reviewed future
  effort/calendar/model manifests.
- Future metadata have nine stations, 101 occasions, 909 station-weeks and
  5,303 active days; every row matches the reviewed full effort template.
- Horizon endpoints are occasion 65 (2020-09-01), 78 (2020-12-01), 104
  (2021-06-01), and 153 (2022-05-10). Training has 21 detected and 29 unseen
  members of the fixed 50-candidate pool.
- Targeted tests pass with warnings treated as errors: 26 forecast, nine path,
  and 20 scoring expectations. These include small-pool enumeration, posterior
  mixture dependence, exchangeable subgroup splitting, stable tiny event tails,
  hazard-range rejection, membership flags, coherent paths and corrupted-input
  rejection. Scoring uses synthetic outcomes only.
- A two-retained-draw smoke from every real saved fit passed the complete core,
  paths and scoring interfaces. It generated no files and made no scientific
  forecast claims. The actual run uses every retained draw.
- Input-check mode, R parsing, shell syntax/shellcheck and whitespace checks
  pass. No new Stan compilation, fitting or later detection access occurred.

Resolved during review: strip posterior matrix subclasses; subset integer known-
member flags logically; preserve joint draw identity; pool unseen marginals only
after conditional prediction; compute first-discovery bins through interval
hazards rather than subtracting saturated CDFs; score saved stable event/count
logs directly; reject malformed probability mass and floating-point hazard
range loss instead of inventing impossible events.

Independent generation review and the actual launch receipt follow below.
The outcome-access decision remains separate and requires verified frozen
predictive objects, not merely passing software checks.

Independent auditor verdict: GO to freeze and generate. Separate probability
and count-mixture checks agree to approximately 2.22e-16 or better. See Audit.md.

## Remote launch receipt

Source and contracts frozen at
`033c21ac13bb830d34e31d40698e5f6a0b4dda6d`. A fresh detached checkout at
`/data/codex/repos/flexirich-goal011-20260919` received that commit by Git bundle,
the committed restricted Goal008 inputs, and unchanged hash-listed parent fit
artifacts copied from the preserved Goal009/010 runs. Its working tree was clean.
All six input checks and two-draw integration smokes passed remotely; renv
reported a consistent project before the full calculation began.

The run started at **2026-09-19 05:24:34 UTC**, in tmux session
`flexirich-g011-forecast-v1`. Startup was verified through the live R process,
log, run metadata, and `RUNNING: baseline_primary` status. Output is
`outputs/goal011/forecast-v1/`, with adjacent `.log` and `.exitcode` files. The
recorded run commit matches the freeze above. Monitoring is handed back after
successful startup, as required by the repository compute policy; completion
and full-output verification are not claimed here. Exact WSL/macOS commands
are in Runbook.md.

Later Judbury detections and Huon Ridge remain unopened. Independent clearance
of the actual archived, committed predictive objects is still required before
outcome access.

## Completion and transfer

23 September 2026: verified remote `COMPLETE` and exit 0 at the unchanged
generation commit. All six profiles report `predictions_complete_unscored`:
4,000 draws for the primary baseline, primary spatial and wider-tail baseline;
6,000 for each of the three wider-prior spatial profiles. The log has no
warnings or errors. The remote working tree is clean.

The entire run was copied locally. All 31 receipt-listed hashes match and the
32-file run directory has no missing or additional files. The complete
prediction archive, including all six RDS objects and the log/exit files, is
preserved under `evidence/` with its SHA-256 and restore instructions. These
are generation and transfer checks; the independent all-draw audit is recorded
in PredictionAudit.md before any outcome access.

## Outcome adapter checks before access

The new adapter restricts observation and operation rows to occasions 1–153
before event construction and identity mapping. It retains the established
15-minute gap rule and assigns each event to its start time in fixed UTC+10.
Events are constructed once over this bounded period, then future outcomes
are selected from occasions 53–153; the observation process is not reset at
the forecast boundary. Non-candidate taxa remain excluded under the original
reviewed pool and are reported in an explicit diagnostic table.

All 88 Goal011 test expectations passed with warnings treated as errors,
including the new raw-adapter and pure-outcome tests. A synthetic integration
using the pinned external protocol code passed events crossing occasions
52/53 and 65/66 and an event exactly at the start of occasion 153. The latter
test protects a final-breakpoint indexing error found and repaired during
self-review before real outcome access. No real observations entered these
checks.

The assessment runner will require the committed prediction archive and audit
clearance, verify consumed input receipts, preserve the frozen scoring function
byte-for-byte, and write a dated access receipt before reading observations.
It will require exact agreement with all 23,400 first-year incidence cells,
the full and future effort tables, the forecast calendar and the known-member
flags; a separate event aggregation must agree with every weekly-table outcome.
Failure stops assessment. These empirical bridge checks remain unrun until
the documented outcome-access gate is satisfied.

The historical aggregate exposure is specifically relevant to the focal
endpoint: `R/goal003_judbury.R` already records 26 detected species for the full
153 occasions. Together with the first-year total of 21 this implies five
later additions. This was recoverable from existing code before the current
outcome extraction. The frozen final-count comparison is therefore a
retrospective predictive check of an already disclosed aggregate, not a newly
unseen confirmatory endpoint. The endpoint, models and scoring rules remain
unchanged; timing and named outcomes will be reported with the same broader
historical-exposure caveat. Huon Ridge remains protected.
