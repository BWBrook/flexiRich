# Goal 002R Oracle-Stability Adjudication

Status: designed — not authorised for execution
Version: 1
Date: 2026-08-09

## Purpose and scope of inference

The first full decision-scale preflight stopped before producing evidence or an
order decision. At the stopping state, the mandatory one-step endpoint
expansion changed only the reconstructed sigma derivative, by
`1.0477378964424133e-09`, marginally exceeding the frozen absolute `1e-9`
limit. This tranche asks one bounded question:

> At this exact state, is the expansion change a floating-point/cancellation
> resolution effect that is negligible under the already frozen reference-
> uncertainty budget, or does the base-R oracle fail to resolve its sigma
> derivative adequately for candidate assessment?

The numerical target is the value and primitive derivatives of

\[
m_0(a,\sigma)=E_Z[\exp\{-\exp(a+\sigma Z)\}],
\]

especially \(\partial_\sigma\log m_0\). The scientific decision target is the
largest corresponding zero-tail gradient perturbation for \(U=29\) unseen
candidates. The scope of inference is one numerical state and one oracle
implementation. It is not evidence about other protected-domain states, either
Gauss--Hermite candidate, the ecological exchangeability assumptions, the
finite-pool richness estimand, or empirical performance.

This is adjudication rather than candidate rescoring because it evaluates no
Gauss--Hermite rule, candidate order, target-error maximum, posterior state,
or order-selection criterion. It cannot produce `SELECT_256` or `SELECT_512`.
It determines only whether a separately planned oracle-contract amendment and
a new, separately authorised full preflight would be defensible. The original
order-128 `REJECT`, the stopped preflight, and its failed absolute stability
check remain unchanged.

The relevant computational path is: positive primitive integrations -> log
ratios -> signed half-integral subtraction -> oracle sigma derivative ->
candidate-minus-oracle target/gradient metrics -> bounded maximum search ->
order decision. The stop occurred during oracle construction, before the
candidate metric at that optimizer state was returned. Consequently the only
claim this design can test is stability of the primitive-to-oracle part of the
path; no candidate result can be inferred from it.

The load-bearing failure modes are tail truncation, integration-tolerance
sensitivity, loss of precision when two positive half-integrals are
subtracted, finite-difference truncation/roundoff trade-offs, and the fact that
an optimizer selected the state. They are addressed by certified nested
endpoints, both locked tolerances, explicit cancellation diagnostics, and a
frozen denominator-only derivative. Parameter identifiability, prior
sensitivity, detection bias, missingness, pseudoreplication, spatial or
temporal dependence, model misspecification, and Monte Carlo calibration are
not testable here because the tranche has no data likelihood, posterior
sampling, or candidate fit. They remain unresolved rather than implicitly
passed.

## Non-goals

The tranche will not:

- rerun any part of the full preflight or reconstruct its missing in-memory
  results;
- call `goal002r_preflight_reference()`,
  `goal002r_preflight_reference_pair()`, the failing public gate, the audit,
  maxima search, evidence writer, or runner;
- evaluate orders 256 or 512, candidate error, nearby states, posterior draws,
  or a parameter grid;
- tune an integration tolerance, finite-difference step, endpoint, expansion
  count, threshold, or state after seeing a result;
- use Stan, a high-precision package, a new dependency, an asymptotic formula,
  or another integration algorithm; or
- modify production or preflight R code, the Stan model, tests, the original
  evidence, or the stopped-run report.

The optimizer selected this state while searching candidate target error, so
it is not a random validation point. Freezing it exactly, with no nearby-state
search, prevents selection from turning into post hoc tolerance or state
tuning.

## Exact frozen state and constants

The diagnostic has no command-line numerical options. Its source must contain
these literals:

| Quantity | Frozen value |
|---|---:|
| `a` | `10` |
| `sigma_alpha` | `0.01356952703481304` |
| `U` | `29L` |
| integration tolerances | `c(1e-10, 1e-12)` |
| initial endpoint distance | `8` local scales |
| tail threshold | `1e-14` of the enclosed primitive |
| maximum certification expansions | `20L` doublings |
| recorded coverage levels | certified, expanded, further-expanded |
| Richardson starting step | `1e-5` |
| Richardson halvings | exactly `0:8` |
| Richardson convergence threshold | `2.5e-6` |
| value reference-agreement limit | `1e-8` |
| derivative mixed limit | `1e-8 + 1e-10 * max(abs(d))` |
| decision-scaled reference limit | `1e-4` |
| absolute derivative sanity limit | `1e-5` |
| gradient scales | `a = 1.5`, `sigma = 0.85`, `log_sigma = 1.2` |

Frozen stop provenance is: order 256, `target_error` search, the exact state
above, certified-to-expanded `derivative_sigma` change
`1.0477378964424133e-09`, and frozen absolute limit `1e-9`. The corresponding
changes in `log_m0` and `derivative_a`, and all four primitive log-integral
changes, were zero at the precision printed by the stopped runner. No evidence
file and no order decision exists.

The old absolute endpoint-change threshold remains `1e-9` and remains failed.
It is reported for provenance but is not silently replaced by, for example,
`1.1e-9`. The adjudication criteria below were inherited from the prospective
reference and derivative contracts and are not fitted to the observed excess.

## Smallest diagnostic

### Implementation boundary

Implement one standalone base-R script,
`scripts/run_goal002r_oracle_stability_adjudication.R`. It may source only
`R/goal002r/math.R` and `R/goal002r/preflight_math.R`. It may use the private
mode-bracketing and mode-centred primitive-integration helpers, because those
are the numerical mechanism being inspected and they do not themselves apply
the failed output gate. It must not source `R/goal002r/preflight_audit.R`.

The script should contain a small local wrapper around the existing primitive
evaluation so that the returned `stats::integrate()` absolute-error estimates,
tail bounds, endpoints, modes, and scales are retained. This wrapper is
diagnostic-only and must not alter any sourced function.

For each of the four existing positive primitives—denominator, numerator for
the \(a\) derivative, and positive- and negative-half magnitudes for the signed
\(\sigma\) numerator—locate the first endpoint distance

\[
8\,2^{e_p}\quad (e_p\in\{0,\ldots,20\})
\]

whose concavity tail bound is at most \(10^{-14}\) of its enclosed integral.
Record that certified result, then evaluate exactly two additional endpoint
distances, \(8\,2^{e_p+1}\) and \(8\,2^{e_p+2}\). These are the expanded and
further-expanded results. Do this independently at relative/absolute
integration tolerances `1e-10` and `1e-12`; do not stop early because results
look stable.

For every primitive and level retain its log integral, enclosed anchored
integral, summed `integrate()` absolute-error estimate, relative error
estimate, relative tail bound, mode, local scale, endpoints, and certification
expansion count. Combine the four primitive logs with the existing signed-log
arithmetic to obtain `log_m0`, `derivative_a`, and `derivative_sigma` at all
six tolerance-by-coverage combinations. This deliberately reproduces the
path whose last-bit stability is in question.

### Tail and conditioning diagnostics

Let \(D\), \(P\), and \(N\) be the enclosed denominator and the positive and
negative sigma-numerator magnitudes, expressed relative to the denominator.
For every tolerance and coverage level report

\[
d_\sigma=-(P-N),\qquad
\kappa_{\rm cancel}=\frac{P+N}{|P-N|},\qquad
L=\log_{10}\kappa_{\rm cancel}.
\]

`L` estimates decimal digits lost in the subtraction; it is diagnostic, not
by itself a failure. Also report the conservative arithmetic floor

\[
E_{\rm fp}=16\,\epsilon\{P+N+|d_\sigma|\},
\]

where \(\epsilon\) is `.Machine$double.eps`. The factor 16 bounds the small,
fixed sequence of log-ratio, `expm1()`, subtraction, and sign operations; it is
frozen before execution.

If \(r_D,r_P,r_N\) are the relative certified tail bounds, report the
derivative tail envelope

\[
E_{\rm tail}=r_P P+r_N N+r_D|d_\sigma|.
\]

This upper-bounds the effect of independently omitted primitive tails on the
enclosed signed ratio without assuming that cancellation makes relative error
benign.

For a transition between two primitive log integrals \(x_i,x_j\), define
\(q_k\) as the summed `integrate()` absolute-error estimate divided by the
enclosed anchored integral and use the prespecified compatibility envelope

\[
E_{\log}=4(q_i+q_j+r_i+r_j)+
32\epsilon\{1+\max(|x_i|,|x_j|)\}.
\]

The factor four acknowledges that QUADPACK's reported error is an estimate,
not a proof; the last term covers the fixed log-scale arithmetic. Check both
adjacent coverage transitions and certified to further-expanded. This is a
diagnostic of whether apparently unchanged primitive logs are compatible with
their reported numerical resolution, not a relaxed derivative cutoff.

### Independent denominator-only derivative

The independent component must never integrate either signed sigma-numerator
half and must never call `.goal002r_preflight_combine_primitives()`. It obtains
only `log_m0` from the denominator primitive at perturbed sigma values and
forms central differences

\[
D_j=\frac{\log m_0(\sigma+h_j)-\log m_0(\sigma-h_j)}{2h_j},
\qquad h_j=10^{-5}/2^j,quad j=0,\ldots,8,
\]

followed by

\[
R_j=\{4D_{j+1}-D_j\}/3,qquad j=0,\ldots,7.
\]

Compute all nine centred estimates and all eight Richardson estimates for
each tolerance and each of the certified, expanded, and further-expanded
coverage policies. A perturbed evaluation uses its own mode and first
tail-certified endpoint; the two larger policies add exactly one and two
doublings. Select the first `R_j`, starting at `j = 1`, whose difference from
`R_(j-1)` is at most `2.5e-6`. Record every estimate, the accepted index and
step, and the accepted successive-estimate difference \(\rho\). Failure to
find one within the frozen eight halvings is inconclusive; it does not
authorise more halvings or another starting step.

This derivative shares the stable, positive denominator integration but is
independent of the positive-minus-negative half-integral representation that
produced the stop. Agreement therefore distinguishes harmless cancellation
resolution in the signed reconstruction from a materially unstable
denominator integral. It is not fully independent of `stats::integrate()`, so
the inference remains explicitly limited to the existing base-R oracle.

## Frozen acceptance criteria

Set

\[
S_a=29(1.5)=43.5,
\qquad
S_\sigma=29\max\{0.85,1.2(0.01356952703481304)\}=24.65.
\]

For any collection of estimates, `span` means maximum minus minimum. Outcome
A requires every item below:

1. All modes, curvatures, endpoints, primitive results, reported errors, tail
   bounds, reconstructed outputs, and Richardson estimates are finite. Each
   primitive certifies its tail within 20 doublings, and all three recorded
   levels retain relative tail bounds at most `1e-14`.
2. Every `integrate()` call reports normal completion. Every primitive log
   transition satisfies `abs(x_j - x_i) <= E_log`.
3. Across all six reconstructed outputs,
   `span(log_m0) <= 1e-8`, and
   `29 * span(log_m0) <= 5e-4`.
4. For each primitive derivative separately, its six-result span is no larger
   than `1e-8 + 1e-10 * max(abs(d))`. In addition,
   `S_a * span(derivative_a) <= 1e-4` and
   `S_sigma * span(derivative_sigma) <= 1e-4`.
5. At every tolerance and coverage level,
   `S_sigma * E_tail <= 1e-4` and
   `S_sigma * E_fp <= 1e-4`.
6. All six denominator-only Richardson sequences converge under the frozen
   rule. For each accepted estimate `R`, signed-half estimate `d`, and its
   accepted refinement difference `rho`, both
   `abs(d - R) <= 1e-5` and
   `S_sigma * (abs(d - R) + rho) <= 1e-4` hold. Finally,
   `S_sigma * span(R) <= 1e-4` across the six accepted estimates.

The `1e-8 + 1e-10*|d|` form is the existing mixed derivative-agreement rule.
The `1e-5` derivative check and `2.5e-6` Richardson convergence rule are also
pre-existing. The load-bearing `1e-4` decision-scaled limit is one tenth of
the downstream `1e-3` pooled-RMS gradient gate and one hundredth of the
`1e-2` maximum-gradient gate. Thus outcome A requires the entire one-state
oracle uncertainty—including finite-difference resolution—to remain
negligible at the downstream decision boundary. The currently reported
endpoint change converts to approximately `2.58e-8` on this scale, but that
observation does not waive any criterion above.

## Decision tree

Apply the branches in this order and record the first applicable reason.

### A — numerical-resolution artefact supported

Choose A only if all six acceptance items pass. The failed `1e-9` absolute
check remains historical fact; A means that the excess is supported as a
last-bit/cancellation-resolution effect and is negligible under the
prospectively frozen mixed and decision-scaled budgets. A permits only a new,
separately reviewed plan to amend the oracle stability contract and then seek
authority for one new full run. It does not itself amend the contract or
authorise that run.

### B — oracle instability supported: `CLOSE`

Choose B if a mode, tail, or integration computation cannot produce finite
certified, expanded, and further-expanded primitives within the frozen
budgets. Also choose B when all six Richardson sequences converge and a
measured primitive-compatibility, mixed derivative, tolerance/coverage-span,
or independent derivative-agreement criterion fails after its stated
uncertainty allowance. These are direct, quantified failures of the current
oracle at the adjudicated state. Record `CLOSE`; do not rerun the preflight.

### C — inconclusive: `CLOSE`, no rerun

Choose C if any denominator-only Richardson sequence does not converge within
eight halvings; if only `E_tail`, `E_fp`, or another reported uncertainty
envelope exceeds `1e-4` without a resolved disagreement; if the two derivative
constructions give internally contradictory but uncertainty-overlapping
evidence; or if an implementation/evidence failure prevents the frozen
diagnostic from completing. Record `CLOSE`; do not change steps, tolerances,
thresholds, algorithms, or the state, and do not rerun either this diagnostic
or the full preflight.

## One-shot execution and evidence

The single scientific execution begins only after the script is committed,
parses successfully, its constants have been checked against this document,
and a focused read-only review confirms that it cannot reach the public gate,
candidate functions, audit, or full runner. Parsing and static review do not
consume the attempt; any evaluation at the frozen state does.

Run exactly once:

```sh
Rscript scripts/run_goal002r_oracle_stability_adjudication.R
```

Write only the following ignored files under
`outputs/goal002r/oracle-stability-adjudication-v1/`:

- `primitive-stability.csv`: 24 rows (four primitives by two tolerances by
  three coverage levels), including the primitive, integration, tail, and
  transition diagnostics;
- `derivative-stability.csv`: all signed output summaries and all 48
  Richardson rows (two tolerances by three coverage policies by eight
  Richardson levels), for 54 rows total with a `row_type` column and
  acceptance columns; and
- `decision.txt`: version, timestamp, exact frozen constants, outcome A/B/C,
  `CLOSE` where applicable, and the first failed or inconclusive criterion.

The script must refuse to start if that directory exists. It must catch a
classified numerical certification error and still attempt to write
`decision.txt` as B. An unexpected implementation, schema, or I/O error maps
to C. Neither path fabricates missing CSV rows. No manifest, plot, rendered
report, or session dump is needed.

## Implementation tasks and stopping point

1. **Implement the isolated runner.** Create only
   `scripts/run_goal002r_oracle_stability_adjudication.R`; use base R and the
   two permitted sourced files. Freeze every constant in this document,
   retain `integrate()` errors, implement the three endpoint levels and the
   denominator-only Richardson calculation, and add collision-safe compact
   evidence writing. Do not edit an existing R or test file.
2. **Verify without consuming the attempt.** Parse the script; inspect its
   call graph and literal constants; run `git diff --check`. Do not source or
   execute it. Commit the implementation separately from this design.
3. **Perform one focused review.** Confirm the exact state, counts, formulas,
   decision precedence, absence of candidate/audit/full-run calls, and that
   every failure maps deterministically to A, B, or C. Repair ordinary static
   defects before execution.
4. **Execute once and reconcile.** Run the single command above. Verify exact
   row counts when CSVs are complete, recompute the decisive scale conversions
   from the CSVs with a small read-only base-R check, and confirm that
   `decision.txt` follows the frozen tree. Do not repeat the scientific run.
5. **Record and stop.** Append a concise result to this document and commit
   only the adjudication result/provenance intended for version control.
   Outcome A stops at authority to plan a contract amendment. Outcomes B and C
   record `CLOSE`. No path begins candidate testing, contract editing, a full
   preflight rerun, Stan work, or ecological analysis.

This is the complete adjudication tranche. Any request to broaden the state
set, change numerical controls, or resolve an inconclusive result is a new
scientific decision and is not authorised here.
