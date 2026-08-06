# Goal 002R Numerical Revision Design

Status: approved design; implementation pending
Date: 2026-08-06

## Purpose

The first prespecified Goal 002R paired comparison rejected the order-128
collapsed computation. The collapsed model improved sampling geometry, but it
failed 9 of 150 independent quadrature checks, missed one of five richness-PMF
fidelity checks, and had a median primary-runtime ratio of 3.38 relative to the
original computation.

That `REJECT` decision remains part of the scientific record. This revision
tests one new numerical candidate rather than changing the first decision.

## Protected scientific contract

The revision may not change:

- the finite known-pool, whole-grid detectable-use estimand;
- the species x camera x seven-day incidence and exact-effort data;
- the membership, encounter-rate or camera-effect model;
- the prior used within a paired case;
- the six comparison datasets, simulation seeds or fit seeds;
- the primary and single-rescue sampler settings;
- the strict sampler-health thresholds;
- the posterior-fidelity or runtime thresholds; or
- the first order-128 `REJECT` result and its evidence files.

Only the numerical evaluation of the all-zero candidate likelihood may change.

## Algebraic reduction

For an exchangeable never-detected candidate, define the total
camera-adjusted exposure

\[
A=\sum_j E_j\exp(c_j),
\]

where \(E_j\) is the sum of active camera-days times the number of trials at
camera \(j\), and \(c_j\) is its camera effect. If
\(\alpha=\mu_\alpha+\sigma_\alpha Z\) with \(Z\sim N(0,1)\), then

\[
m_0=E_Z\left[\exp\{-A\exp(\mu_\alpha+\sigma_\alpha Z)\}\right].
\]

This is exactly the current all-zero likelihood. It removes the repeated loop
over zero-history rows from every quadrature node without changing the model.
The reduced and current row-wise calculations must agree to absolute log-scale
error at most \(10^{-12}\) on existing numerical fixtures.

## Revised numerical candidate

The production candidate is mode-adaptive Gauss-Hermite quadrature. Write
\(B=A\exp(\mu_\alpha)\). For \(\sigma_\alpha>0\), the log-integrand mode and
local scale are

\[
z_*=-\frac{W_0(B\sigma_\alpha^2)}{\sigma_\alpha},\qquad
s=\{1+W_0(B\sigma_\alpha^2)\}^{-1/2},
\]

where \(W_0\) is the principal Lambert-W function. CmdStan 2.38.0 exposes
`lambert_w0` with reverse-mode derivatives.

For standard-normal Gauss-Hermite nodes \(u_q\) and normalised weights \(w_q\),
set \(z_q=z_*+s u_q\) and evaluate

\[
\log m_0 \approx \log s+
\operatorname{logsumexp}_q\left[
\log w_q-\frac{z_q^2}{2}-B\exp(\sigma_\alpha z_q)
+\frac{u_q^2}{2}
\right].
\]

When \(\sigma_\alpha=0\), use the exact expression
\(-A\exp(\mu_\alpha)\).

This centring targets the region containing the integrand's mass. The exposure
reduction also makes its cost proportional to the number of nodes rather than
the number of nodes times the number of zero-history groups.

## Bounded numerical screening

Before changing the Stan model, compare only these candidates:

- fixed Gauss-Hermite order 256 after exposure reduction;
- adaptive Gauss-Hermite orders 16, 32 and 64.

Use the independent adaptive `integrate()` calculation as the oracle. Evaluate
each candidate on:

1. the original 150 posterior checks; and
2. 100 additional deterministic, evenly spaced posterior rows per case after
   excluding the original 25 rows.

Thus each candidate faces 750 checks across the six cases. A candidate passes
only if every absolute log-integral error is at most \(10^{-8}\). Select the
lowest passing adaptive order. Fixed order 256 is a conservative comparator
and fallback, not grounds for testing still more orders.

If no candidate passes, stop with `REJECT`; do not begin a wider algorithm
search in this tranche.

## Revised paired experiment

If screening identifies a candidate:

1. implement the same reduced adaptive calculation in R and Stan;
2. retain the candidate order selected by the numerical screen;
3. rerun the original and revised collapsed computations on the same six
   prespecified cases under a new `paired-comparison-v2` output root; and
4. apply the original posterior-fidelity, sampler-health, geometry, quadrature
   and median-runtime criteria unchanged.

The new posterior quadrature audit again checks 25 evenly spaced draws from
every clean revised collapsed fit against the independent oracle. All checks
must meet \(10^{-8}\).

The revised experiment produces a fresh `RETAIN`, `REVISE` or `REJECT`
decision. It does not overwrite the first decision.

## Evidence and stopping rule

Keep the evidence compact:

- one numerical-screen table;
- the same six paired-comparison CSVs and text decision used by version 1; and
- fit files under the ignored revised output root.

Perform one focused review of the algebra, numerical screen, data identity,
health gates and recorded decision. Repair only a demonstrated implementation
defect. Do not tune orders, cases, seeds, priors, samplers or thresholds after
the revised results are visible.

Stop after the revised decision and return it for PI assessment. Broader
synthetic calibration, comparator benchmarking and Judbury analysis remain out
of scope.
