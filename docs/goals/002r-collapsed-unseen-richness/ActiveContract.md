# Goal002R active contract

This document defines the deliberately small active path for the first
Goal002R implementation tranche. The completed Goal002 pilot remains a
historical evidence archive; its freeze, ledger and publication machinery is
not part of this path.

## Scientific promise

Estimate whole-grid detectable-use richness for a finite, known candidate
species pool from complete species-by-camera-by-seven-day detection histories
and exact operational effort. Candidates detected at least once are modelled
with species and camera encounter effects. Candidates never detected are
exchangeable only when their opportunity histories and predictors agree; their
encounter effect is integrated out and their total contribution is represented
by a per-draw binomial tail.

The first implementation is a method prototype and validation surface. It is
not an empirical Judbury or Huon Ridge analysis and makes no claim that total
richness is identified in arbitrary unknown pools.

## Active data contract

Inputs are the existing canonical `flexirich_g_data` object, constructed from:

- a finite candidate pool with unique `species_id` values;
- complete camera-by-seven-day operational effort in `0:7` active days;
- complete binary detection histories at positive effort and missing values at
  zero effort.

The collapsed constructor partitions candidates into the detected set and the
all-zero set. It rejects the collapse if all-zero candidates do not share the
same ordered camera/occasion/effort history.

## Mathematical contract

- Effort enters through the encounter hazard; zero effort has zero detection
  probability.
- The all-zero candidate likelihood is integrated over its species effect by
  checked Gauss--Hermite quadrature.
- Production fitting uses quadrature order 128 by default, rejects arbitrary
  unvalidated production orders, and retains the independent certification
  helper for stress-testing the numerical envelope.
- A candidate's unseen-membership probability is computed for every posterior
  draw, not at a posterior mean.
- The richness PMF is the mean of the per-draw
  `Binomial(U, q_unseen)` PMFs and has support `D:(D + U)`.
- No named encounter-effect estimate is produced for an undetected candidate.
- All PMFs are normalised and all reported richness values lie on integer
  support.

## Reproducibility boundary

The active path uses one explicit loader, one compact fit output directory and
one thin summary. It records the model source hash and seed in memory but does
not require immutable attempt ledgers, per-file inventories or publication
symlinks. Those mechanisms remain available only in the historical Goal002
archive until a later decision requires them.

Numerical certification is validation-only: an independent adaptive integral
is compared with candidate Gauss--Hermite orders, and the first order within
the log-integral tolerance is selected. The production default is the
conservative order 128 from the current certified envelope; it is not a claim
that every future posterior tail is resolved without a new certificate. Every
CmdStan fit also records and enforces a small sampler-health gate (no
divergences or max-treedepth hits, finite E-BFMI/R-hat/ESS diagnostics).

The recovery scripts use truth-known synthetic data to expose bias and
interval behaviour; they are not confirmation studies. The bounded grid
varies effort, encounter rate, true richness, and the resulting unseen-member
fraction.

## Deliberate non-goals

This tranche does not include site-level pooling, external Atlas of Living
Australia data, camera-event reconstruction, false-positive models, unknown
species augmentation, or empirical camera-trap fits. Those are subsequent
scientific decisions, not implementation prerequisites.
