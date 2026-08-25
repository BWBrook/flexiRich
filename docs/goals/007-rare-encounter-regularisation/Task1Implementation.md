# Goal007 Task 1 — executable-contract implementation

Status: complete and frozen
Implemented: 2026-08-25

## Outcome

The proposed Goal007 design is now represented by one deterministic executable
authority, `R/goal007_contract.R`. It creates the model candidates, synthetic
rate profiles, paired Task 2 schedules, both possible Task 3 branches, effort
windows, seed rules, decision gates, output schemas, and stable content hashes.
No Goal007 model has been fitted.

The implementation reuses the content-frozen 50-candidate pool, operational-
effort schedule, and outcome-free Goal006 fold table. External verification
checks the existing source receipts but does not parse the empirical Judbury
observation file. The contract reports `empirical_outcomes_used=false`.

## Frozen-shape checks

Focused tests establish that:

- F5 and F3 transform exactly to their intended Gaussian contrast SDs;
- all six rate profiles reproduce their declared common shifts and contrast
  deviations;
- Task 2 contains 60 fresh paired datasets and 180 uniquely seeded fits;
- Task 3 contains 48 ecological datasets with nested richness scenarios and
  four balanced post-gap effort windows;
- each possible selected-candidate branch contains exactly 96 calibration and
  288 target fits with unique bounded seeds;
- the 54 decision rows encode the proposed Task 2 and Task 3 surface; and
- aggregate calibration artifacts cannot contain candidate identities,
  histories, membership quantities, or individual rates.

The standalone verifier is:

```bash
Rscript scripts/check_goal007_task1_contract.R
```

It passed against the current external source receipts. The complete local R
test suite also passed after adding the Goal007 checks.

## Boundary

This implementation froze the scientific thresholds at commit `fa6e8ae` before
the shared-shift candidate was fitted. The next bounded tranche was the
shared-shift Stan/R model, its deterministic bridges, truth-isolating adapter,
and reduced local smoke. The 180-fit screen remains a later `deep-server` run
from a new clean pushed commit.
