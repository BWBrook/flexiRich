# Goal 002R — Collapsed known-pool richness computation

Status: closed — `REJECT`; numerical rescue ended `CLOSE`
Updated: 2026-08-10

## Objective

Goal002R tested whether analytically collapsing the exchangeable all-zero
candidate species in the Goal002 finite-pool model could preserve its posterior
while improving sampling geometry and computational reliability.

The estimand remained whole-grid camera-detectable-use richness over a defined
period for a finite, named regional candidate pool. Seven-day incidence,
camera effort, priors, and the Goal002 observation model were protected. The
collapsed computation was a numerical re-expression, not a new source of
ecological information.

## Evidence and decisions

### Locked paired comparison

The six-case Goal002 versus Goal002R comparison found clean collapsed terminal
fits and passed all 53 shared-parameter checks, but failed the prespecified
retention gates:

- quadrature accuracy passed 141 of 150 checks; the worst discrepancy was
  `2.29e-6` against a `1e-8` limit;
- richness-PMF fidelity passed four of five checks; `standard-short-low` was
  `0.2866` against a `0.25` limit; and
- the median primary-fit runtime ratio was `3.379`, above the limit of `2`.

The collapsed implementation was therefore `REJECT` rather than retained or
revised. Clean sampler diagnostics did not override numerical, PMF, and runtime
failures.

### Bounded numerical revision

A subsequent adaptive-quadrature precheck passed all 3,726 reference states,
but the single authorised full preflight stopped before candidate assessment or
an order decision. At the selected state, endpoint expansion changed the sigma
derivative by `1.0477378964424133e-09`, just above the frozen absolute `1e-9`
limit. No full-preflight evidence table was produced.

The final one-state adjudication then returned outcome C at
`X04_in_memory_schema`: inconclusive, `CLOSE`, and no rerun. Its exact result
and provenance are recorded in
[OracleStabilityAdjudication.md](OracleStabilityAdjudication.md).

## Closure decision

The Goal002R implementation path is retired:

- the collapsed Stan model, custom quadrature/oracle, preflight machinery,
  runners, and dedicated tests have no supported consumer and are removed;
- the temporary Goal002 allowance to write paired fits beneath
  `outputs/goal002r` is removed;
- the locked `REJECT`, stopped preflight, and adjudication outcome C remain
  historical evidence and are not rescored; and
- committed history through `f2a7f4a` preserves the complete executable and
  intermediate design lineage if forensic recovery is ever required.

The external consultation and its evidence packet remain under
`docs/consultations/goal002r-next-step/` as a deliberate scientific record.

## Interpretation

This closure does not show that finite known-pool richness inference is
intrinsically invalid. It shows that this collapsed computational rescue did
not meet its own decision gates and that further bespoke numerical work has
low expected value. More importantly, a reparameterisation cannot repair the
membership–detectability ambiguity already exposed by Goal002.

## Direction retained for Goal003

The next goal will be designed separately. Its intended question is whether a
simple, regularised, finite-pool multispecies detection model can improve
short-window richness inference and future-species-discovery prediction over
transparent baselines.

The retained ingredients are:

- a finite, externally defined regional candidate pool;
- grid-level detectable-use richness before site-level pooling;
- seven-day incidence with exact operational effort;
- synthetic calibration with known truth;
- temporal validation against the long Judbury record; and
- Huon Ridge as private external validation.

No Goal003 model, data adapter, threshold, or empirical analysis is authorised
by this closure record.
