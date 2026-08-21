# Goal005 Task 4 — transfer-stress implementation

Status: implemented, locally verified, and launch-ready

## Frozen surface

The implementation realises the bounded design in `Task4Design.md`:

- 36 fresh synthetic 12-week datasets spanning richness 10, 25, and 40;
- three paired F3 calibration profiles: unbiased, common 0.8-fold bias, and
  common 1.25-fold bias;
- 108 total fits using the existing Goal005 class-calibration model;
- 51 unchanged profile-level decision rows and six paired-shift rows; and
- an independent replay from compact pair evidence.

The transfer profiles share ecological histories and external-calibration
errors exactly. They differ only by the prespecified common class-location
shift. Simulation, calibration, and fit streams use the fresh deterministic
seed rules frozen in `Task4Design.md`.

## Reuse and scope

No new Stan model was added. Task 4 reuses the Task 3 model, adapter, sampler,
posterior-richness calculation, and Task 2 scoring standard. New production
code is limited to the deterministic manifest, a thin simulation guard, the
transfer-specific gates, resumable orchestration, and the independent audit.

The runner records its exact Git commit, generated and copied manifest hashes,
source hashes, runtime versions, RNG contract, row-level completion records,
and the protected-outcome flag. Raw sampler artifacts remain remote; the audit
requires only compact results and manifests.

## Local verification

Focused checks cover:

- exact 36-dataset, 36-calibration, and 108-fit manifests;
- fresh non-overlapping seeds and paired ecological histories;
- exact `-log(1.25)`, zero, and `+log(1.25)` calibration contrasts;
- all 57 production decision rows and all three decision branches;
- detection of an excessive paired maximum richness shift;
- frozen manifest publication and corruption detection;
- independent replay and deliberate gate corruption; and
- protected-outcome isolation.

The complete repository test suite passed without warnings or failures on
2026-08-21. A three-profile Stan smoke at implementation commit `6966be5`
completed with all fits terminal clean, all posterior richness PMFs normalised,
all predictions available, sampler outputs compressed, and truth excluded from
fitted data. The final pushed launch commit receives the same short smoke
before the frozen 108-fit run starts on `deep-server`.
