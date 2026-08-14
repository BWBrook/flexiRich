# Goal004 Task 1 decision — core data-responsive, rare fringe prior-driven

Date: 2026-08-14
Decision: **CORE_ONLY**

## Evidence boundary

The deterministic analytical screen completed at Git commit
`3b2b3089d616f54e40efd521f0474c7aebae302d`. It used the frozen Judbury
operational-effort template, reviewed candidate-pool labels and synthetic
design points only. It did not use Judbury detections, Goal003 posterior
outputs, future discovery outcomes, Huon Ridge data or empirical coordinates.

The complete output is retained at:

`outputs/goal004/task1-identifiability-v1`

Read-back checks confirmed 432 unique numerical surfaces, the recorded Git
commit and all three input hashes. `completion-status.txt` was written last and
records `CORE_ONLY`.

Two earlier committed executions stopped before creating an output directory.
The first exposed an ambiguous dplyr data-mask reference to `core_count`; the
second exposed a duplicate reference join at the same post-computation
boundary. Both were mechanical integration defects. Their narrow repairs were
covered by an assembled-table regression test before the successful run; no
scientific threshold or prior was changed.

## Prespecified checkpoint

The decision checkpoint used the lower-median four-week effort window (224
active camera-days), a broad independently calibrated rate target
\(\log r\sim N\{\log(0.002),1\}\), and synthetic expected memberships of 10,
25 and 40.

| Check | Observed | Required | Result |
| --- | ---: | ---: | --- |
| high–low posterior-mean separation | 17.28 species | at least 15 | pass |
| mean CRPS improvement over prior-only | 48.7% | at least 20% | pass |
| minimum cell-specific CRPS improvement | 25.0% | non-negative | pass |
| maximum core shift after adding fringe | 0.72 species | at most 2 | pass |
| maximum total shift after adding fringe | 5.04 species | at most 3 | **fail** |
| minimum fringe-mean reduction from all-zero histories | 13.5% | at least 25% | **fail** |

The core checkpoint passed; the broad-pool checkpoint did not. The frozen
decision is therefore `CORE_ONLY`.

## What the core pass does and does not mean

Four-week camera histories contain real information about expected membership
within the 50-candidate primary pool. The posterior responded across the three
design points and improved CRPS relative to the same diffuse membership prior.
This is enough to justify considering a core-pool model if its encounter-rate
prior can be calibrated independently.

It is not strong identification. At expected memberships 10, 25 and 40, the
posterior means were respectively 19.03, 29.16 and 36.32 species. The
corresponding central 90% intervals were 4.75–42.50, 13.50–46.75 and
22.00–48.50. Posterior correlations between membership and log encounter rate
ranged from -0.64 to -0.72. The two-log-unit profile-likelihood spans were
48.0, 41.0 and 32.25 species.

Thus, the prespecified pass means that the observations improve a deliberately
broad prior, not that a four-week point estimate is unbiased or precise. The
likelihood-ridge figure makes this distinction visible. The homogeneous common
rate is also a favourable case; unmodelled real species heterogeneity would
generally make the unseen-member problem harder.

Effort matters sharply. In the four-week firmware-failure window with only 28
active camera-days, high–low separation fell to 7.16 species and the maximum
profile span reached 49.75 species. A nominal four-week duration is not enough;
effective active camera-days must remain part of the estimand and reporting
contract.

## Why the broader pool failed

The candidate-stratified model successfully insulated the core estimate from
the 56 added candidates: its maximum core shift was only 0.72 species. It did
not make the added rare candidates observable.

Under the prespecified five-species fringe prior and ten-fold lower fringe
encounter rate, all-zero four-week histories reduced expected fringe membership
only from 5.00 to 4.03–4.32 species. Total expected membership consequently
shifted by 4.36–5.04 species. Most of that expanded-pool result came from the
external prior rather than the cameras.

The original exchangeable 106-candidate formulation was much worse: its maximum
four-week shift was 15.89 species. Independent count-scale strata therefore
repair the rescaling of the core, but they cannot create information about
nearly undetectable candidates.

At 26 weeks the same rare-fringe profile behaved differently. The maximum core
shift was 0.08 species, the maximum total shift was 2.54 species, and all-zero
histories reduced the fringe mean by at least 50.6%. Longer observation, not a
cleverer parameterisation, resolves much of the ambiguity.

## Scientific implication

Four-week camera data can support a model for **camera-accessible grid use
within the prespecified 50-candidate primary pool**, subject to independent
encounter-rate calibration and later misspecification tests. They cannot, by
themselves, support a broader gamma-richness claim that includes species known
to be rare or nearly invisible to ground cameras.

Those are two different estimands:

1. camera-accessible richness, for which non-detections can be informative; and
2. expanded ecological gamma richness, for which rare-fringe membership is
   mainly supplied by external natural-history evidence.

The second may still be scientifically useful, but it should be presented as a
joint evidence or expert-elicitation problem, not as richness learned from a
one-month camera survey.

## Decision and next choice

Goal004 pauses before prior elicitation, Stan implementation and empirical
access. The collaborator decision is whether to:

- continue Goal004 with the 50-species camera-accessible pool as the explicit
  four-week estimand, retaining the 106-pool result only as a transparent
  prior-dominated sensitivity; or
- retain expanded gamma richness as the target, in which case the current
  camera-only Goal004 path should stop and the design should add independent
  evidence rather than further tune the likelihood.

No empirical outcome should be opened until that estimand is fixed.
