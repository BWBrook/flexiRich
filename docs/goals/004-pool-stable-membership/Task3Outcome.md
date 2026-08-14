# Goal004 Task 3 — minimal fixed-class model outcome

Date: 2026-08-14
Verdict: **TASK3_PASS**

## Decision

The approved core-only fixed-class model is implemented correctly enough to
advance to Task 4 design. This verdict establishes agreement between the Stan
and R likelihoods, agreement with the frozen no-data prior forecast, clean
sampling in one small truth-isolated fit, and valid exact finite-pool outputs.

It does **not** establish calibration, superiority to the prior-only forecast,
or stability to adding the 56 fringe candidates. Those remain the scientific
tests for Task 4 and Task 5.

## Frozen implementation

The principal implementation was committed as
`26794f65fd006b2d75165eb6d277dc759c2f3d2f`. It contains:

- a direct expected-core-membership parameter on the 0–50 scale;
- the proper transformed Beta density, including the (1/C) Jacobian;
- direct candidate encounter rates under fixed routine or occasional priors;
- the prespecified overlapping class-blur sensitivity without a latent class;
- the existing effort-aware grouped likelihood and exact sum-zero camera layer;
- analytically marginalised candidate membership; and
- exact posterior richness and future-discovery PMFs.

The count-scale parameter remains algebraically equivalent to the membership
fraction for a fixed pool. It improves interpretation and permits independent
future strata, but does not itself supply new information.

## Verification evidence

### Static and unit contract

The focused Goal004 tests and the complete repository test suite passed. They
verify the 44 routine / six occasional core mapping, all six frozen profiles,
class- and profile-sensitive hashes, zero-effort handling, the absence of
learned encounter hyperparameters and membership RNGs, and normalised exact
PMFs. The project environment remained synchronized under `renv`.

### Stan/R bridge

The bridge used the eight-candidate synthetic fixture and the blurred-class
profile for 20 retained draws. Maximum absolute discrepancies were:

| Quantity | Maximum error | Gate |
| --- | ---: | ---: |
| member log likelihood | (1.78\times10^{-15}) | (10^{-8}) |
| conditional membership probability | (1.11\times10^{-16}) | (10^{-8}) |
| expected richness | (8.88\times10^{-16}) | (10^{-7}) |
| sum of camera effects | 0 | (10^{-10}) |
| (R_c-C\omega_c) | 0 | (10^{-12}) |

### Zero-effort prior concordance

The first committed runner completed a clean fit but its evidence writer
expected a CmdStan summary column not provided by the installed version. That
attempt is retained at `outputs/goal004/task3-prior-concordance-v1`; it was an
implementation-contract failure, not a failed numerical gate. The MCSE was
then calculated explicitly with `posterior`, committed as
`9a898ae6b37b6c0850bd179ccc234ca7c9528855`, and rerun into a new output
directory.

The corrected 50-candidate run used no likelihood rows and the frozen
lower-median four-week effort prospectively:

| Check | Result | Gate |
| --- | ---: | ---: |
| sampler status | `primary_clean` | clean |
| divergences / treedepth hits | 0 / 0 | 0 / 0 |
| maximum R-hat | 1.0079 | 1.01 |
| minimum bulk / tail ESS | 3662 / 2046 | 400 / 400 |
| richness mean error | 0.158 | four MCSE = 0.645 |
| richness PMF total variation | 0.0164 | 0.05 |
| four-week discovery PMF total variation | 0.0146 | 0.05 |

The complete evidence is under
`outputs/goal004/task3-prior-concordance-v2`. It records the Task 2 reference
commit and confirms that no empirical outcomes were used.

### Synthetic smoke

The single 12-candidate, three-camera, 26-week smoke fit finished
`primary_clean` at the corrected implementation commit:

| Diagnostic | Result |
| --- | ---: |
| divergences / treedepth hits | 0 / 0 |
| maximum R-hat | 1.0048 |
| minimum E-BFMI | 0.910 |
| minimum bulk / tail ESS | 2599 / 1709 |

The posterior-richness, prior-richness, and future-discovery PMFs all summed to
one; richness support matched the 12-candidate pool; every detected candidate
had posterior membership one; and synthetic truth was absent from the fitted
object. Evidence is under `outputs/goal004/task3-smoke-v1` with simulation seed
40053 and fit seed 40054.

## Scientific interpretation

Task 3 proves that the proposed fixed-class core model is a coherent and
reproducible candidate. It has not yet shown that short samples materially
improve on the external prior. The apparently strong no-data result is a
concordance test, not evidence of inferential performance.

Task 4 should therefore remain a bounded development screen that:

1. compares posterior forecasts with the matching prior-only forecasts;
2. crosses four- and 26-week windows with informative, weak, and partly wrong
   encounter classes;
3. adds the fringe through an independent membership stratum;
4. checks whether shared camera effects perturb the core posterior; and
5. stops before held-out or empirical work if calibration, information gain,
   or nested-pool stability is inadequate.

No Judbury detection outcome, Huon Ridge datum, or held-out Goal004 seed was
used in Task 3.
