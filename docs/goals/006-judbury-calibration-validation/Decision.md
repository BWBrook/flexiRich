# Goal006 decision — calibration feasibility failure

Decision: **`CALIBRATION_FEASIBILITY_FAIL`**

Adjudicated: 2026-08-24

## Result

Goal006 stops at Task 2. The selection-adjusted encounter-class calibration is
mathematically and computationally valid, but it did not meet the complete
prespecified synthetic-recovery standard. The empirical first-year Judbury
calibration, later target histories, forecast outcomes, and Huon Ridge data
remain unopened.

The frozen 30-dataset run used Git commit
`8be48bb7d1b37ff30315b49d07d50e05a3579229` on `deep-server`. It completed all
30 fits with process exit code zero. Twenty-nine fits were primary clean and
one was rescue clean. The independent compact-evidence replay matched all 12
recorded gate rows and confirmed `TASK2_RECOVERY_FAIL`.

## Gate evidence

Eleven of the twelve Task 2 gates passed:

| Requirement | Result | Gate |
| --- | ---: | ---: |
| Maximum likelihood-value bridge error | 9.82e-10 | <= 1e-8 |
| Maximum likelihood-gradient bridge error | 1.22e-8 | <= 1e-5 |
| Terminal-clean fits | 30/30 | >= 29/30 |
| Minimum clean fits per profile | 10/10 | >= 9/10 |
| Maximum absolute median routine bias | 0.073 log units | <= 0.35 |
| Maximum absolute median occasional bias | 0.155 log units | <= 0.50 |
| Routine RMSE | 0.187 log units | <= 0.60 |
| Occasional RMSE | 0.620 log units | <= 0.80 |
| Routine 90% coverage | 29/30 | >= 25/30 |
| Occasional 90% coverage | 28/30 | >= 25/30 |
| Minimum class-by-profile coverage | 9/10 | >= 8/10 |
| Catastrophic cases | **2/30** | **< 2/30** |

The failed guard was not an execution artefact. Both affected fits were
terminal clean, but the posterior-median occasional-class location differed
from truth by more than `log(3)`:

| Dataset | Profile | Detected occasional species | Error, log units | Multiplicative error | 90% covered |
| --- | --- | ---: | ---: | ---: | --- |
| `g006t2-lower-r03` | lower | 1/6 | +1.318 | 3.74 | yes |
| `g006t2-compressed-r07` | compressed | 4/6 | -1.443 | 4.24 | no |

The first case illustrates the anticipated small-class information limit, but
the second shows that the fragility is not confined to a single-detection
sample. Aggregate bias and coverage can therefore look satisfactory while an
occasional-class calibration still occasionally shifts by a biologically
consequential factor.

## Interpretation

Selection adjustment itself is not rejected. The bridge, convergence,
aggregate bias, RMSE, and coverage results show that the implementation is
mostly well behaved. What fails is the reliability standard required before
letting a two-location aggregate artifact control unseen-species inference in
later Judbury windows. With only six occasional candidates, the fitted
occasional-class location remains too vulnerable to realised species effects
and sparse detection.

The failure is deliberately decisive. Task 1 required fewer than two
catastrophic datasets and explicitly prohibited retuning after a scientifically
clean recovery failure. Treating the boundary value of two as “close enough”,
weakening the factor-three definition, changing the seeds, or inspecting
empirical calibration before redesign would invalidate the protected test.

## Consequence for the project

- Task 3 is not run; no empirical class-location artifact is produced.
- Tasks 4 and 5 are retired under this Goal006 candidate.
- The candidate is **not ready for external Huon Ridge validation**.
- Judbury later-window outcomes and Huon Ridge remain available for a future,
  newly prespecified model rather than being consumed to repair this one.

A future goal may retain the proven effort-hazard and selection-adjustment
machinery while reconsidering how rare encounter behaviour is regularised.
Plausible scientific directions include externally informed taxon-specific
rate information, a less brittle trait hierarchy, or explicitly acknowledging
that the occasional class supports only weak bounds. Such work must begin as a
new design with new synthetic gates; it cannot revise Goal006 retrospectively.

## Evidence record

- Frozen result gate table SHA-256:
  `bfc2347a1061fe2b108f2016565da778424515ef082fcc7e431d73b20647ffaf`.
- Recovery table SHA-256:
  `cec5bb93b75cb82b2e5a23abd0b07394192be7a0f7ad3c5d329c5d5e1e9de95b`.
- Independent audit status SHA-256:
  `8dce2bae7e16cde4095b71449f857378bc7c89e5dbaa21768392b349d4860716`.
- Remote evidence root:
  `/home/bwbrook/papers/flexiRich/outputs/goal006/task2-recovery-v1`.
- Audit root:
  `/home/bwbrook/papers/flexiRich/outputs/goal006/task2-audit-v1`.

Raw compressed CmdStan evidence remains on `deep-server`; the compact result
and audit archives were also copied locally under the ignored `outputs/`
tree.
