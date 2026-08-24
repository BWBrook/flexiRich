# Goal006 Task 2 — selection-calibration implementation

Status: complete; frozen recovery returned `TASK2_RECOVERY_FAIL`

Prepared: 2026-08-24

## Scientific implementation

Task 2 implements the detected-sample likelihood fixed in Task 1. For a
detected species, Stan samples its latent log encounter rate and evaluates its
ordinary effort-aware weekly history. The likelihood is divided by the
class-specific probability that a member would have been detected at least
once under the retained cameras and effort. That probability is integrated
over the fixed member log-rate distribution using a 64-node Gauss--Hermite
rule.

All-zero candidate histories and membership parameters are absent from the
calibration model. They are neither treated as known absences nor used to
estimate a calibration-period richness. The fitted parameters are only the
two encounter-class locations, detected-species latent rates, and sum-zero
camera effects.

## Verification boundary

The independent numerical bridge covers five class locations and three
between-species spreads. Direct adaptive integration supplies the reference
selection probability and its analytic gradient. The frozen tolerances remain
`1e-8` for log probability and `1e-5` for the gradient. A separate one-chain
Stan/R bridge recomputes every detected-species history contribution, both
selection adjustments, the total adjusted likelihood, and the sum-zero camera
constraint from posterior draws.

Synthetic recovery uses the exact 30 rows, actual first-52-week effort, seeds,
profiles, and gates frozen in Task 1. All 50 candidates are members; only
simulated detected species enter each fitted sample. The remote run records
one compact fit-status row and two class-recovery rows per dataset, preserves
compressed CmdStan evidence and deterministic simulation objects, and writes
all twelve gate decisions. A replay script reconstructs the decision from the
compact evidence.

No empirical Judbury detections, later target histories, forecast outcomes,
Huon Ridge records, or point locations are read by Task 2.

## Entry points

```bash
Rscript scripts/check_goal006_calibration_model.R
Rscript scripts/run_goal006_task2_smoke.R
Rscript scripts/run_goal006_task2_recovery.R
Rscript scripts/audit_goal006_task2_results.R
```

The 30-fit recovery grid is Stan-intensive and must run on `deep-server` from
a clean, pushed commit. `TASK2_PASS` is required before the empirical
calibration-only input can be materialised for Task 3. A scientifically clean
`TASK2_RECOVERY_FAIL` is a stop, not an invitation to retune the model.

## Outcome

The exact-commit batch completed 30/30 terminal-clean fits and independently
replayed all 12 gate rows. Eleven gates passed. Two clean fits had
factor-three errors in the occasional-class location, failing the frozen
requirement of fewer than two catastrophic cases. Goal006 therefore stops as
`CALIBRATION_FEASIBILITY_FAIL`; full evidence and interpretation are recorded
in [`Decision.md`](Decision.md).
