# Goal005 Task 3 — class-calibration implementation

Status: **approved and launch-ready; heavy run not started**

## Frozen surface

The implementation realises the proposed Task 3 surface without accessing
Judbury detections, future discoveries, Huon Ridge data, or unpublished
locations:

- 108 fresh synthetic datasets: three richness scenarios, twelve paired
  streams, and 12-, 16-, and 26-week nested deployments;
- seven calibration levels from exact class locations (`C0`) through a nominal
  factor-five 95% interval (`F5`); and
- 756 fits, scored against the unchanged 17-row Goal005 standard in each of 21
  duration-by-precision cells.

The finite-calibration model adds only two latent encounter-class locations to
the established Goal004 model. External estimates have prespecified Gaussian
uncertainty while the biological between-species log-rate SD remains one. The
class labels, candidate pool, effort template, prior, seed rules, generated
manifests, and source hashes are frozen by the run contract.

## Verification completed

The implementation commit `3f57191` passed:

- the full repository test suite;
- the deterministic 108-dataset, 84-calibration, and 756-fit manifest check;
- the Stan/R likelihood bridge, with discrepancy at most `2.66e-15` across
  the load-bearing quantities;
- the analytic zero-uncertainty prior limit;
- truth-isolation and protected-outcome source checks; and
- an exact-commit two-level smoke using `C0` and `F1.25` on one fresh 12-week
  dataset. Both fits were terminal clean, produced normalised richness PMFs,
  compressed their sampler outputs, and excluded synthetic truth from fitted
  data.

An independent audit path is also frozen. It reconstructs all 357 gate rows
from compact pair evidence, independently applies the precision-prefix rule,
and reconciles the three duration-frontier decisions. A deliberate gate-value
corruption is detected by its focused test.

## Approved launch boundary

The collaborator approved the prespecified precision grid and Task 4 transfer
stress on 2026-08-20. The final clean pushed commit receives one short
exact-commit smoke before the 756-fit batch is launched on `deep-server` in a
named `tmux` session.
