# Independent prelaunch review of Goal013

5 October 2026. This review covers the conditional temporal-mechanism design,
numerical kernel, scoring rules, diagnostic summaries and recovery runner before
the frozen simulation launch. It used only the already-open compact weekly
tables and derived Goal012/013 artifacts. It did not read raw observations or
Huon Ridge data, conduct an inferential empirical-model comparison, or generate
recovery evidence. The performance-only fits described below are excluded
from scientific interpretation.

## Verdict

The four-candidate numerical comparison is suitable for a frozen synthetic
recovery screen after its final input-receipt check and one disposable synthetic
integration smoke run. The static, harmonic, array-state and station-state
likelihoods now receive the same oracle marginal information. Array and station
states differ only in whether the low/high state is shared across cameras or
evolves independently by station. The screen can therefore test conditional
finite-panel discrimination without pretending to validate richness, occupancy,
camera malfunction or a biological mechanism.

The early proposal to apply a `Beta(0.5,0.5)` adjustment independently to all
338 species-placement cells was rejected before any simulation. On the real
design that version would have changed 3,836 observed positive cells to about
3,964.6 expected positives and changed each one-record species to about 7.36
expected records. The implemented placement-share adjustment instead has a
total pseudocount of 0.5 per species and preserves every species total exactly;
the 338 targets sum to 3,836.

The harmonic and state truths now use one common taxon-specific adjacent-switch
target. For birds, the attainable common target retains 54.1% of the observed
deficit; for mammals it retains the full deficit. The bird limit is imposed by
the fixed `pi=0.5`, `rho=0.8`, amplitude-at-most-four state template: its minimum
expected switch count is 482.498, whereas the harmonic can reach 369.902.
Consequently, failure can reject advancement of these conditional templates,
but cannot establish that array-wide persistence in general is unrecoverable.
This weakening is explicit and prevents recovery rates from being compared
across unequal temporal signal strengths. The five ambiguous movement
station-weeks are removed consistently
from margins, likelihoods, diagnostics and event endpoints, while latent states
continue to propagate across those weeks and other effort gaps.

## Direct verification

- I inspected `R/goal013_mechanisms.R`, `src/goal013_mechanisms.cpp`, the
  calibrator, runner, scoring and diagnostic functions, the targeted tests, and
  the stated interpretation in `Goal.md`.
- `tests/testthat/test-goal013-mechanisms.R` passed 36 expectations and
  `tests/testthat/test-goal013-scoring.R` passed seven expectations in a fresh
  targeted run. These include unequal-effort normalization, finite enumeration
  of array and station likelihoods, the zero-amplitude static identity, row
  permutation, missing-week propagation, deterministic simulation, optimizer
  starts, count-PMF enumeration and selection-rule behavior.
- On the 26-species design, all four candidates reproduced every one of the 338
  target margins. The largest absolute discrepancy in my check was
  `1.18e-11` expected positive cells.
- An additional independent four-week enumeration gave an array future-event
  probability of `0.7202498` and a station future-event probability of
  `0.8018630`; both matched the C++ forward calculation to displayed precision.
  Direct conditional future likelihoods agreed with full-minus-training
  likelihood differences within `2.3e-16`.
- A deliberately saturated toy case remained finite with hazards as large as
  about `9.1e5`, confirming that the likelihood and no-event calculations use
  hazards rather than rounded probabilities in their vulnerable tails.
- The C++ group indexing reduced a full-design probability evaluation from
  about one second to about 0.03 seconds after compilation. Performance-only
  fits to the open design took approximately 24 seconds for the harmonic,
  56 seconds for the array state and 75 seconds for the station state on the
  laptop; all converged from the retained starts with objective spreads below
  `1.5e-6`. These fits were diagnostics only. Their parameter estimates are not
  recovery or empirical evidence and must not enter interpretation.
- The primary event horizons are 13, 26, 52 and 101 weeks, matching Goal011;
  the secondary origin scores the remaining 49 weeks. The remote hostname guard
  was verified separately against the live authorized host.
- The combined `make test-goal013 goal013-check` preflight passed, including the
  frozen 500-job manifest, input hashes and numerical-kernel load.

## Scientific limits and stopping rule

This is an intentionally favourable oracle ceiling. Full-period placement
margins and truth calibration are known to every candidate, including candidates
fitted at week 52. The results cannot be described as reproducing the Goal011
information set or as an independently validated field forecast. The 24
never-recorded candidates are excluded; no membership or richness claim follows.

The stationary state probability is fixed at one half, temporal parameters are
shared by taxon, and event predictions plug in fitted parameters without
propagating parameter uncertainty. One harmonic phase and one shared-service
stress realization do not span plausible non-stationarity. Sparse species may
remain unresolved even if the panel-level mechanism is recoverable. Coverage,
boundary estimates, start agreement and numerical failures therefore remain
decision evidence rather than routine diagnostics.

The predeclared core gates are appropriately stringent: at least 80/100
own-truth selections for provisional recovery, at most 4/100 array selections
under each harmonic and station truth, and no more than 2% numerical failures.
Array/station confusion or materially excessive cross-station synchrony blocks
advancement. The shared-service stress uses the same predeclared array
false-selection limit of 4/100. Selections of the other misspecified dynamic
candidates under this stress are descriptive.

A passing screen would justify nuisance-rate estimation and a harder combined
misspecification stage. It would not justify proceeding directly to empirical
hierarchical Stan, revising Goal011, or claiming an array-wide availability
mechanism. A failing or unresolved screen is a scientific stop, not a reason to
retune amplitudes, phases or the two-nat resolution rule on the generated
outcomes.
