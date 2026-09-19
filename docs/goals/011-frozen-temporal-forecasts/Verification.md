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
