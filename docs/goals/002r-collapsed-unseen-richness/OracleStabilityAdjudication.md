# Goal 002R Oracle-Stability Adjudication

Status: completed — outcome C / `CLOSE`; no rerun
Version: 2 — independent-review repair
Date: 2026-08-09

## Purpose and scope of inference

The first full decision-scale preflight stopped before producing evidence or an
order decision. At the stopping state, the mandatory one-step endpoint
expansion changed only the reconstructed sigma derivative, by
`1.0477378964424133e-09`, marginally exceeding the frozen absolute `1e-9`
limit. This tranche asks one bounded question:

> At this exact state, is the expansion discrepancy decision-negligible and
> compatible with the current base-R numerical resolution, or does the oracle
> fail to resolve its sigma derivative adequately for candidate assessment?

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
`1.1e-9`. The tolerances, tail budget, Richardson schedule, mixed derivative
rule, derivative sanity limit, decision scales, and `1e-4` reference budget
are inherited from the prospective preflight contract. The extra endpoint,
six-result spans, factors 4/16/32, propagated uncertainty envelopes, evidence
schema, and A/B/C rules were designed after the stop and are prospectively
frozen only for this single adjudication. They are not claimed to have been
prespecified before the observed excess.

## Smallest diagnostic

### Implementation boundary

Implement one standalone base-R script,
`scripts/run_goal002r_oracle_stability_adjudication.R`. It may source, in this
order, only `R/goal002r/config.R`, `R/goal002r/math.R`, and
`R/goal002r/preflight_math.R`. `config.R` is required because the other modules
refer to `.goal002r_stop()`. None of the three files has top-level numerical
execution, but the implementation review must confirm that fact again at its
committed revision.

The runner must implement local, diagnostic-only mode location,
integral-once, and primitive-loop functions using the same analytic kernels,
scores, curvatures, concavity tail formulas, mode-centred scaling, and signed-
log algebra. It must not call `.goal002r_preflight_integral_once()`,
`.goal002r_preflight_primitive()`, `.goal002r_preflight_reference_core()`, or
either public reference function: those helpers discard required integration
metadata, expose only two levels, or apply incompatible endpoint semantics.
The local functions retain each `stats::integrate()` completion message and
absolute-error estimate, endpoints, mode, scale, and tail bound without
altering any sourced file.

Define a local typed condition class,
`goal002r_adjudication_numerical_error`, for only the enumerated frozen
numerical predicates: invalid mode bracket/curvature, non-finite integrand or
primitive, non-OK `integrate()` completion, invalid tail score/bound, or no
tail certification within the inclusive expansion budget. Signal that class
at the local check site. Do not translate ordinary errors by matching message
text or by broadly catching everything raised inside a numerical call; all
untyped errors are implementation failures. Use
`stats::integrate(stop.on.error = FALSE)` locally, retain its message, require
`identical(result$message, "OK")`, and signal the typed condition only after
that explicit completion check.

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
look stable. The search is inclusive: first passage at `e_p = 20` is valid,
and failure means no passage for any integer in `0:20`. Record `e_p` itself,
not the expanded-level index.

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
by itself a failure. Also report the arithmetic-error model

\[
E_{{\rm arith},\sigma}=16\,\epsilon\{P+N+|d_\sigma|\},
\]

where \(\epsilon\) is `.Machine$double.eps`. The factor 16 is a frozen,
conservative model for the small fixed sequence of log-ratio, `expm1()`,
subtraction, and sign operations. It is not presented as a rigorous bound on
platform `exp()` or `expm1()` library error.

If \(r_D,r_P,r_N\) are the relative certified tail bounds, report the
derivative tail envelope

\[
E_{{\rm tail},\sigma}=r_P P+r_N N+r_D|d_\sigma|.
\]

This upper-bounds the effect of independently omitted primitive tails on the
enclosed signed ratio without assuming that cancellation makes relative error
benign.

Let \(A=I_a/D=|d_a|\), and let \(q_D,q_A,q_P,q_N\) be each
primitive's summed `integrate()` absolute-error estimate divided by its
enclosed anchored integral. Propagate the retained integration uncertainty and
the other analytic derivative envelopes as

\[
\begin{aligned}
E_{{\rm int},\sigma}
  &=4(q_P P+q_N N+q_D|d_\sigma|),\\
E_{{\rm int},a}
  &=4(q_A+q_D)|d_a|,\\
E_{{\rm tail},a}
  &=(r_A+r_D)|d_a|,\\
E_{{\rm arith},a}
  &=16\epsilon|d_a|,\\
B_\sigma
  &=E_{{\rm int},\sigma}+E_{{\rm tail},\sigma}
    +E_{{\rm arith},\sigma},\\
B_a
  &=E_{{\rm int},a}+E_{{\rm tail},a}+E_{{\rm arith},a}.
\end{aligned}
\]

The inherited decision budget applies to the totals \(B_\sigma\) and \(B_a\),
not merely to their individual components.

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

For every denominator log integral used directly as `log_m0`, also define its
absolute log-value uncertainty envelope

\[
b_D=4(q_D+r_D)+32\epsilon\{1+|\log D|\}.
\]

This quantity is carried into both target-value checks and every denominator-
only finite difference below.

### Independent denominator-only derivative

The independent component must never integrate either signed sigma-numerator
half and must never call `.goal002r_preflight_combine_primitives()`. It obtains
only `log_m0` from the denominator primitive at perturbed sigma values and
forms central differences

\[
D_j=\frac{\log m_0(\sigma+h_j)-\log m_0(\sigma-h_j)}{2h_j},
\qquad h_j=10^{-5}/2^j,\quad j=0,\ldots,8,
\]

followed by

\[
R_j=\{4D_{j+1}-D_j\}/3,\qquad j=0,\ldots,7.
\]

If \(b_{+,j}\) and \(b_{-,j}\) are the log-value uncertainty envelopes for
the two denominator evaluations, propagate them without cancellation as

\[
B_{D,j}=\frac{b_{+,j}+b_{-,j}}{2h_j},
\qquad
B_{R,j}=\frac{4B_{D,j+1}+B_{D,j}}{3}.
\]

Compute all nine centred estimates and all eight Richardson estimates for
each tolerance and each of the certified, expanded, and further-expanded
coverage policies. A perturbed evaluation uses its own mode and first
tail-certified endpoint; the two larger policies add exactly one and two
doublings. Select the first `R_j`, starting at `j = 1`, whose difference from
`R_(j-1)` satisfies both

\[
\rho_j=|R_j-R_{j-1}|\le2.5\times10^{-6}
\]

and the post-stop uncertainty-aware rule

\[
\rho_j+B_{R,j}+B_{R,j-1}\le2.5\times10^{-6}.
\]

Compute every row before selecting; do not stop at the first acceptable row.
Each Richardson row has exactly `j`, `h_coarse = h_j`,
`h_fine = h_(j+1)`, `D_coarse = D_j`, `D_fine = D_(j+1)`, `B_D_coarse`,
`B_D_fine`, `R_j`, `B_R_j`, `rho` (`NA` for `j = 0`), and `accepted`.
The reported accepted step is `h_fine`. Overlap across the eight rows retains
all nine centred estimates. Set `accepted = TRUE` only on the first eligible
row and `FALSE` on every other row, including later rows that also meet the
inequalities. Failure to accept one within the frozen eight Richardson rows is
inconclusive; it does not authorise more halvings or another starting step.

This derivative shares the positive denominator integration but is
algebraically independent of the positive-minus-negative half-integral
representation that produced the stop. Agreement can support one-state
adequacy of the current base-R path; it cannot identify cancellation as the
unique cause because both constructions still use `stats::integrate()`.

## Frozen acceptance criteria

Set

\[
S_a=29(1.5)=43.5,
\qquad
S_\sigma=29\max\{0.85,1.2(0.01356952703481304)\}=24.65.
\]

For any collection of estimates, `span` means maximum minus minimum. If each
estimate \(x_k\) has uncertainty envelope \(B_k\), define

\[
\operatorname{span}_B(x)=
\max(x)-\min(x)+B_{\operatorname{argmax}(x)}+
B_{\operatorname{argmin}(x)}.
\]

Ties use the canonical row order below. Outcome A requires every stable
criterion, evaluated in identifier order:

1. `S01_finite_tail`: all applicable modes, curvatures, endpoints, primitives,
   reported errors, tail bounds, reconstructed outputs, and Richardson
   quantities are finite; only schema-defined structural `NA` values are
   exempt. Every primitive certifies at an inclusive `e_p` in `0:20`, and all
   three levels retain relative tail bounds at most `1e-14`.
2. `S02_integrate_ok`: every `stats::integrate()` call reports normal
   completion.
3. `S03_primitive_log_compatible`: every adjacent coverage transition and
   certified-to-further transition satisfies
   `abs(x_j - x_i) <= E_log`.
4. `S04_value_resolution`: each denominator `b_D <= 1e-8`,
   `span_B(log_m0) <= 1e-8`, and
   `29 * span_B(log_m0) <= 5e-4`.
5. `S05_a_resolution`: the raw six-result `derivative_a` span and its
   uncertainty-inflated span are each at most
   `1e-8 + 1e-10 * max(abs(derivative_a))`; additionally,
   `S_a * span_B(derivative_a) <= 1e-4`.
6. `S06_sigma_resolution`: the analogous raw and uncertainty-inflated
   `derivative_sigma` spans satisfy the same mixed rule, and
   `S_sigma * span_B(derivative_sigma) <= 1e-4`.
7. `S07_analytic_uncertainty`: at every tolerance and coverage level,
   `S_a * B_a <= 1e-4` and `S_sigma * B_sigma <= 1e-4`. Retain and report
   every integration, tail, and arithmetic component as well as its total.
8. `S08_richardson_convergence`: each of the six denominator-only sequences
   has exactly one first accepted row under the raw and uncertainty-aware
   convergence rules above.
9. `S09_richardson_uncertainty`: every accepted result satisfies
   `S_sigma * B_R <= 1e-4`.
10. `S10_independent_agreement`: for each signed-half estimate `d`, accepted
    denominator-only estimate `R`, refinement difference `rho`, and their
    envelopes, both `abs(d - R) <= 1e-5` and
    `S_sigma * (abs(d - R) + rho + B_sigma + B_R) <= 1e-4` hold.
11. `S11_richardson_span`: across the six accepted estimates,
    `S_sigma * span_B(R) <= 1e-4`.

The `1e-8 + 1e-10*|d|` form is the existing mixed derivative-agreement rule.
The `1e-5` derivative check and `2.5e-6` Richardson convergence rule are also
pre-existing. The load-bearing `1e-4` decision-scaled limit is one tenth of
the downstream `1e-3` pooled-RMS gradient gate and one hundredth of the
`1e-2` maximum-gradient gate. The post-stop envelopes ensure that retained
`integrate()` error, certified tails, arithmetic resolution, and finite-
difference amplification are carried to that boundary rather than used only
as descriptive diagnostics. The currently reported endpoint change converts
to approximately `2.58e-8` on this scale, but that observation does not waive
any criterion above.

## Decision tree

### Execution-integrity precedence

Execution integrity is outside and precedes the scientific A/B/C tree.
Evaluate these stable checks in order:

1. `X01_output_absent`: if the final or staging output path already exists,
   stop before numerical evaluation with **no attempt and no outcome**.
2. `X02_sources_committed_clean`: require the runner and three permitted
   source files to be tracked at `HEAD`, with no staged or unstaged change to
   those four files. Failure means **no attempt and no outcome**.
3. `X03_provenance_available`: require Git `HEAD`, runtime fields, and all four
   SHA-256 hashes before evaluation. Failure means **no attempt and no
   outcome**.
4. `X04_in_memory_schema`: after a numerically complete run, validate exact
   schemas, row counts, uniqueness, canonical order, finite required fields,
   and exactly one accepted Richardson row per sequence before evaluating A or
   any table-based B/C rule. Failure is C.
5. `X05_evidence_publish`: publish evidence under the staged, decision-last
   protocol below. A computed classification is not a persisted outcome until
   publication completes. If publication fails, report a non-zero console
   error and **no persisted outcome**.

The attempt begins at the first evaluation of a primitive at the frozen state.
A typed `goal002r_adjudication_numerical_error` is `B00_numerical_certification`
and maps to B. Any untyped computation error is
`C00_implementation_failure` and maps to C. This typed distinction is made at
the predicate, never inferred from free-form error text.

### A — one-state discrepancy is decision-negligible

Choose A only after `X01`--`X04` and all `S01`--`S11` pass. A means that the
discrepancy is decision-negligible and compatible with the current base-R
numerical resolution at this one state. It does not establish a unique cause,
rescind the failed `1e-9` check, or validate another state. A permits only a
new, separately reviewed plan to propose an oracle-contract amendment and then
seek authority for one new full run. It does not amend the contract or
authorise that run.

### B — oracle instability supported: `CLOSE`

Choose B for `B00_numerical_certification`. With complete tables, choose B at
the first `S` identifier whose **raw measured discrepancy** is resolved beyond
its limit: a primitive-log change outside `E_log`; a raw value or derivative
span outside its inherited limit; `abs(d - R) > 1e-5`;
`S_sigma * (abs(d - R) + rho) > 1e-4`; or
`S_sigma * span(R) > 1e-4`. These are direct failures of the current oracle at
the adjudicated state. Record `CLOSE`; do not rerun the preflight.

### C — inconclusive: `CLOSE`, no rerun

Choose C for `C00_implementation_failure`, `X04_in_memory_schema`, any
Richardson sequence without an uncertainty-aware accepted row, or any failure
caused only by `b_D`, `B_a`, `B_sigma`, `B_R`, or an uncertainty-inflated span
when the corresponding raw discrepancy remains within its limit. Also choose
C for internally contradictory but uncertainty-overlapping evidence. Record
`CLOSE`; do not change steps, tolerances, thresholds, algorithms, or the
state, and do not rerun either this diagnostic or the full preflight.

Within a criterion, inspect rows in the canonical factor order defined below;
the first reason is the lowest criterion identifier and then the first row in
that order. This makes the decision deterministic even when several checks
fail.

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
`outputs/goal002r/oracle-stability-adjudication-v2/`:

- `primitive-stability.csv`: 24 rows (four primitives by two tolerances by
  three coverage levels), including the primitive, integration, tail, and
  transition diagnostics;
- `derivative-stability.csv`: all signed output summaries and all 48
  Richardson rows (two tolerances by three coverage policies by eight
  Richardson levels), for 54 rows total with a `row_type` column and
  acceptance columns; and
- `decision.txt`: version, timestamp, exact frozen constants, outcome A/B/C,
  `CLOSE` where applicable, and the first failed or inconclusive criterion.

The primitive factor order is exactly `denominator`, `numerator_a`,
`sigma_positive`, `sigma_negative`; tolerance order is `1e-10`, then `1e-12`;
coverage order is `certified`, `expanded`, `further_expanded`; and Richardson
order is increasing `j = 0:7`. Sort `primitive-stability.csv` by tolerance,
coverage, then primitive. Its required columns are `primitive`, `rel_tol`,
`coverage`, `e_cert`, `e_level`, `mode`, `local_scale`, `lower_z`, `upper_z`,
`log_integral`, `anchored_integral`, `integrate_abs_error`, `q`,
`relative_tail_bound`, `delta_log_previous`, `E_log_previous`,
`delta_log_certified`, and `E_log_certified`; unavailable transition cells are
`NA` by construction.

Sort `derivative-stability.csv` first by `row_type` in the order
`signed_summary`, `richardson`, then by tolerance, coverage, and increasing
`j`. Its exact union schema is `row_type`, `rel_tol`, `coverage`, `j`,
`h_coarse`, `h_fine`, `log_plus_coarse`, `log_minus_coarse`,
`b_plus_coarse`, `b_minus_coarse`, `log_plus_fine`, `log_minus_fine`,
`b_plus_fine`, `b_minus_fine`, `D_coarse`, `D_fine`, `B_D_coarse`,
`B_D_fine`, `R_j`, `B_R_j`, `rho`, `accepted`, `log_m0`, `b_D`,
`derivative_a`, `B_a`, `derivative_sigma`, `B_sigma`, `P`, `N`,
`kappa_cancel`, `lost_decimal_digits`, `E_int_a`, `E_tail_a`, `E_arith_a`,
`E_int_sigma`, `E_tail_sigma`, `E_arith_sigma`, `accepted_j`,
`accepted_h_fine`, `accepted_R`, `accepted_B_R`, `agreement_abs`, and
`agreement_scaled`.
Fields not applicable to a row type are `NA`. The 48 Richardson rows contain
the frozen per-row schema above; the six summaries contain the accepted result
and analytic-envelope fields. Define `agreement_scaled` exactly as
`S_sigma * (agreement_abs + rho + B_sigma + accepted_B_R)`.

`decision.txt` must additionally record `R.version.string`,
`R.version$platform`, `.Machine$double.eps`, Git `HEAD`, and SHA-256 hashes of
the runner, `config.R`, `math.R`, and `preflight_math.R`. Use the system
`sha256sum` command only for provenance; it is not part of the numerical path.
It also records each `X`, `S`, `B00`, and `C00` identifier in priority order as
`PASS`, `FAIL`, or `NOT_REACHED`, plus the first decisive identifier. There is
no RNG and no seed. When the two CSVs exist, record their validated SHA-256
hashes as well.

Use the fixed sibling staging directory
`outputs/goal002r/.oracle-stability-adjudication-v2.staging`; both it and the
final directory must be absent at `X01`. For a complete-table outcome, write
both CSVs to temporary filenames in staging, read them back, validate their
schemas, 24/54 row counts, keys, factor order, and content hashes, then rename
them to their final basenames. For an early typed B or untyped C, do not create
CSV placeholders. Write `decision.txt.tmp` only after classification and any
available CSV validation, rename it to `decision.txt` last, and finally rename
the staging directory to the final directory on the same filesystem. The
final directory therefore appears only as a complete atomic publication.

If decision writing or final publication fails, emit a non-zero console error,
leave the staging path to block reuse, and record no persisted A/B/C outcome.
Never fabricate missing rows or report a computed classification as persisted.
No manifest, plot, rendered report, or session dump is needed.

## Implementation tasks and stopping point

1. **Implement the isolated runner.** Create only
   `scripts/run_goal002r_oracle_stability_adjudication.R`; use base R and the
   three permitted sourced files. Implement local typed conditions and local
   diagnostic-only mode/integral/primitive logic with inclusive `e_p = 0:20`,
   `e_p + 1`, and `e_p + 2`. Propagate retained `integrate()` errors through
   both analytic derivatives and every Richardson row, and implement the exact
   schemas, ordering, provenance, and staged decision-last publisher. Do not
   edit an existing R or test file.
2. **Verify without consuming the attempt.** Parse the script; inspect its
   call graph and literal constants; run `git diff --check`; verify all four
   tracked source identities are clean. Do not source or execute the runner.
   Commit the implementation separately from this design.
3. **Perform one focused review.** Confirm the exact state, counts, formulas,
   uncertainty propagation, stable criterion identifiers, decision precedence,
   atomic writer, and SHA-256 provenance. Confirm the runner contains no call
   to `goal002r_preflight_reference()`,
   `goal002r_preflight_reference_pair()`,
   `.goal002r_preflight_reference_core()`,
   `goal002r_preflight_gh()`, `goal002r_preflight_rule()`, any
   audit/maxima/writer function, the public runner, or `source_goal002r()`.
   Confirm every expected numerical failure is typed at its predicate and
   every other failure remains C. Repair ordinary static defects before
   execution.
4. **Execute once and reconcile.** Run the single command above. Verify exact
   row counts when CSVs are complete, recompute the decisive scale conversions
   and propagated envelopes from the CSVs with a small read-only base-R check,
   and confirm that `decision.txt` follows the frozen tree and matches the
   recorded runtime/source identities. Do not repeat the scientific run.
5. **Record and stop.** Append a concise result to this document and commit
   only the adjudication result/provenance intended for version control.
   Outcome A stops at authority to plan a contract amendment. Outcomes B and C
   record `CLOSE`. No path begins candidate testing, contract editing, a full
   preflight rerun, Stan work, or ecological analysis.

This is the complete adjudication tranche. Any request to broaden the state
set, change numerical controls, or resolve an inconclusive result is a new
scientific decision and is not authorised here.

## Adjudication result

Executed: 2026-08-09 07:17:37 UTC

Git HEAD: `26d6fd8b527d1bcc98a33ba18a828dfe96ca007d`

The single authorised Version 2 execution passed `X01_output_absent`,
`X02_sources_committed_clean`, and `X03_provenance_available`, but failed
`X04_in_memory_schema`. Under the frozen decision tree, this is outcome C:
inconclusive, `CLOSE`, with no rerun of either this diagnostic or the full
preflight. Decision-only publication passed `X05_evidence_publish`.

The final output directory contains only `decision.txt`; neither CSV evidence
table was published, and no staging directory remains. Consequently, the run
does not identify which composite X04 requirement failed and supplies no
validated numerical evidence for `S01`--`S11`. It cannot establish that the
endpoint discrepancy is decision-negligible, support oracle instability,
amend the numerical contract, select a candidate order, or alter the existing
order-128 `REJECT` and stopped-preflight findings.

Any attempt to resolve the X04 failure would require a newly designed and
authorised scientific tranche, not a rerun of Version 2.

Decision SHA-256:
`f41cf0c1ec002f8c27b33323da589402e1f22900c099b5d4316e37cd6c1f9846`
