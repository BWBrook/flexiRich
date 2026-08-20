# Goal005 Task 2 — frozen information-ceiling implementation

Status: complete and independently audited
Frozen: 2026-08-20

## Scientific contract

Task 2 implements the approved ceiling comparison without empirical outcomes:

- `C0` fits the aligned Goal004 class-distribution oracle;
- `I0` fixes each synthetic candidate's true latent log encounter rate while
  estimating membership and target-camera effects; and
- both paths use the same 50-candidate membership prior, nested synthetic
  histories, effort blocks, duration-independent gates, and no-data richness
  comparator.

The exact candidate rates enter only the declared `I0` oracle adapter. They do
not enter the canonical training data, `C0`, the membership state, or any
empirical reader. Judbury contributes only the tracked operational-effort
template and reviewed candidate labels. Huon Ridge is not accessed.

## Frozen rows and seeds

- 3 richness scenarios × 12 paired streams × 5 durations = 180 datasets;
- 2 information ceilings per dataset = 360 fits;
- simulation seed: `650000000 + replicate`;
- fit seed: `750000000 + 1000000 * information_code +
  10000 * scenario_order + 100 * train_occasions + replicate`.

Every paired stream is generated through 26 training weeks plus four retained
future weeks before being sliced. Membership, candidate rates, camera effects,
and overlapping detection uniforms are therefore shared exactly across
richness and duration comparisons.

## Implementation surface

The Task 2-specific code is limited to:

- one fixed-rate Stan model and its tested R adapter;
- frozen scenario, dataset, and fit manifests;
- a paired synthetic generator;
- richness-only prior and fit scoring;
- the seven-part duration/oracle gate and pruning table; and
- thin non-overwriting artifact and run adapters that reuse Goal003/Goal004
  publication, diagnostic, and sampler machinery.

No discovery, occupancy, fringe-pool, baseline, empirical, or package-API
branch is repeated.

## Evidence contract

The heavy output root is
`outputs/goal005/task2-information-ceiling-v1`. It records source and manifest
hashes, run metadata, one artifact per dataset and fit, compact diagnostics,
richness PMFs and scores, all 170 gate rows, a ten-row information-level by
duration summary, and the five-row Task 3 pruning table. Terminal non-clean
fits remain in fixed denominators.

The heavy screen reports `TASK2_COMPLETE` when all scheduled evidence is
present. This is an execution status, not a scientific pass. The pruning table
classifies each duration as `CLASS_CALIBRATION_ELIGIBLE`,
`CANDIDATE_CALIBRATION_REQUIRED`, or `CLOSED_ORACLE_FAIL`.

## Verification and launch boundary

Before the heavy run:

1. the complete R test suite and deterministic Task 2 execution check must
   pass;
2. both Stan paths must produce a terminal-clean committed smoke fit;
3. the worktree must be clean and pushed; and
4. the heavy screen must start from that exact commit on `deep-server` in a
   named `tmux` session.

The heavy run is resumable only from matching metadata and manifest hashes.
Interrupted staging is preserved for diagnosis rather than overwritten.

## Outcome

The frozen screen completed on `deep-server` at commit
`b453df19d3764bb7a4efecbb5aecb9deb41e195a`. All 180 datasets and 360 fits
completed, all fits were terminal clean, and an independent gate replay
matched every one of the 170 decision rows. Four and eight weeks were
classified `CLOSED_ORACLE_FAIL`; 12, 16, and 26 weeks were classified
`CLASS_CALIBRATION_ELIGIBLE`. See `Task2Decision.md` for the evidence and
scientific interpretation.
