# Goal 002R Decision-Scale Numerical Preflight Design

Status: awaiting PI review
Date: 2026-08-07

## Purpose

The original order-128 Goal 002R comparison remains `REJECT`, and the first
bounded numerical revision remains stopped because none of its prespecified
candidates met the original component-level tolerance. Neither result will be
rescored or overwritten.

This design authorises one final, separately versioned numerical preflight. It
asks whether exposure-reduced fixed Gauss--Hermite quadrature at order 256 or
512 is accurate on the scale of the posterior target and richness decision.
The preflight stops before changing the production Stan model or rerunning any
paired fit.

If one rule passes, it may proceed to a new paired experiment under the
prospective downstream contract below. If neither passes, the Goal 002R
computational repair closes. Ecological scrutiny of the common exchangeable
encounter model remains a separate mandatory gate before empirical use.

## Scientific interpretation and invariants

The estimand is **finite-pool, grid-level camera-encounter richness** during a
defined sampling period. Membership means a non-zero camera-encounter-
generating process on the grid, not literal site occupancy, realised passage,
or habitat use.

The collapse remains exact only when never-detected candidates are
exchangeable conditional on the shared parameters and have identical sampling
opportunities. Under that contract,

\[
m_0=E_Z\left[\exp\{-\exp(a+\sigma_\alpha Z)\}\right],
\qquad a=\log B=\mu_\alpha+\log A,
\]

and the all-zero contribution for $U$ candidates is

\[
\ell_U=U\log\{1-\omega+\omega m_0\}.
\]

The preflight may not change the estimand, likelihood, priors, six locked
datasets, seeds, health gates, candidate pools, or original evidence. It may
only evaluate the reduced integral. Judbury and Huon Ridge data remain out of
scope.

## Approaches considered

1. **Exposure-reduced fixed Gauss--Hermite at orders 256 and 512 -- chosen.**
   It is deterministic, smooth under automatic differentiation, simple to
   audit, and removes the avoidable observation-group loop at every node.
2. **Adaptive integration in the production target -- oracle only.** R's
   adaptive integral is retained as an independent reference. Stan's
   `integrate_1d` may later be used as a gradient oracle, but not as the next
   production method because its variable work inside HMC is an unresolved
   cost.
3. **Further adaptive orders, saddlepoint approximations, or a surrogate --
   rejected for this tranche.** They would create an open algorithm search and
   specialised infrastructure before the ecological model has earned it.

No quadrature order other than 256 and 512 will be tested.

## Stable quadrature rule

The current dense-eigenvector rule generator underflows many high-order
weights to zero. The preflight therefore uses a separate log-weight rule:

- standard-normal nodes are the eigenvalues of the probabilists' Hermite
  Jacobi matrix;
- normalised log weights are calculated from
  \(\log w_i=-\log n-2\log|p_{n-1}(x_i)|\), where the orthonormal Hermite
  recurrence is dynamically rescaled; and
- log weights are normalised by log-sum-exp and never exponentiated in the
  integral calculation.

For each order, every node and log weight must be finite; node and log-weight
symmetry must hold within $5\times10^{-10}$; and standard-normal moments of
orders 0, 2, 4, 6, 8 and 10 must agree with $1,1,3,15,105,945$ to relative
error at most $10^{-11}$. Failure closes the preflight as an implementation
failure rather than evidence against the collapse.

## Protected numerical domain

The 750 retained posterior states span

- $a\in[-5.54,3.24]$; and
- $\sigma_\alpha\in[0.0026,4.68]$.

To avoid defining the audit only from realised posterior extrema, a
deterministic prior-predictive calculation was also run with seed `20260807`
and 200,000 draws for each locked case. Across cases, the 0.001 and 0.999
quantiles of $a$ ranged from -7.35 to 9.17. The 0.999 quantile of the primary
half-normal prior for \(\sigma_\alpha\) is 4.94.

The prospectively locked domain is therefore

\[
\boxed{a\in[-8,10],\qquad \sigma_\alpha\in[0,5.5]}.
\]

This is finite because the priors have unbounded support. Any retained draw in
the later paired experiment that falls outside this domain triggers review and
fails the numerical contract; the domain will not be expanded after seeing
the result.

The preflight evaluates both orders on:

1. all 750 supplied posterior states, using each case's actual $U$;
2. a deterministic 61 by 61 grid over the protected domain, using $U=29$;
3. all four boundaries and the exact \(\sigma_\alpha=0\) limit; and
4. bounded multistart numerical searches initialised from the 12 largest grid
   discrepancies for each value and gradient metric.

Grid density is an audit aid, not the claimed certificate; the multistart
search and later all-draw audit protect against missed interior maxima.

## Independent reference

For $T=\exp(a+\sigma_\alpha Z)$, the reference calculation uses anchored
adaptive integration for $m_0$ and the two primitive derivatives

\[
\frac{\partial\log m_0}{\partial a}
=-\frac{E[T e^{-T}]}{m_0},
\qquad
\frac{\partial\log m_0}{\partial\sigma_\alpha}
=-\frac{E[ZT e^{-T}]}{m_0}.
\]

Reference calculations must be finite and must agree between relative
tolerances $10^{-10}$ and $10^{-12}$ to $10^{-8}$ for the value and both
derivatives. Central finite differences at the domain corners, centre, and
the five largest-error states provide an independent derivative sanity check
with absolute agreement at most $10^{-5}$.

## Decision-scale gates

### Algebraic identity

The exposure-reduced and row-wise zero-history likelihoods must agree within
$10^{-12}$ on the existing deterministic fixtures.

### Target-value gate

For every audited state and searched maximum,

\[
U\left|\Delta\log m_0\right|\le5\times10^{-4}.
\]

This bounds the worst target perturbation directly and allocates about 0.015
species of conservative mean-richness error when $U\le29$.

### Gradient gate

Let \(\Delta_a\) and \(\Delta_\sigma\) be candidate-minus-reference
derivative errors. The full zero-tail multiplier is bounded conservatively by
$Uq_{\mathrm{unseen}}\le29$. The scaled components are

\[
1.5(29)|\Delta_a|,
\quad 0.85(29)|\Delta_\sigma|,
\quad 1.2(29)|\sigma_\alpha\Delta_\sigma|.
\]

The scales 1.5, 0.85 and 1.2 round outward the largest observed case-level
posterior SDs for $a$, constrained $\sigma_\alpha$, and
$\log\sigma_\alpha$, respectively. The $a$ component also bounds the
\(\mu_\alpha\) direction; camera-effect derivatives are exposure shares of
that component and are therefore no larger.

The maximum scaled component must be below $10^{-2}$, and the pooled RMS
scaled discrepancy must be below $10^{-3}$. The high-
\(\sigma_\alpha\) boundary and paths across it must contain no non-finite
values or discontinuous spikes.

### Order selection

Both orders are audited once. Order 256 is selected only if it passes every
gate and has at least twofold headroom on all three decision-scale limits:

- target error at most $2.5\times10^{-4}$;
- maximum scaled gradient error at most $5\times10^{-3}$; and
- RMS scaled gradient error at most $5\times10^{-4}$.

Otherwise, order 512 is selected if it passes the full gates. If neither
condition holds, the decision is `CLOSE`. No further order or algorithm is
tested.

## Preflight implementation boundary and evidence

The preflight adds only a pure R numerical module, focused tests, and one thin
runner. It does not alter `goal002r_log_m0()`, the production Stan file, fit
configuration, or paired-comparison runner.

Generated evidence is written under ignored
`outputs/goal002r/decision-scale-preflight/`:

- `rule-integrity.csv`;
- `posterior-state-audit.csv`;
- `domain-audit.csv`;
- `numerical-maxima.csv`; and
- `decision.txt`.

One concise result section will then be appended to this document. No ledger,
manifest system, report renderer, or figure is required.

## Downstream paired-experiment contract

This section is frozen prospectively but is not implemented unless the
preflight selects an order.

### Numerical posterior correction

At every retained collapsed draw, calculate the exact-reference correction

\[
\Delta_s=U\left[\log\{1-\omega_s+\omega_s m_{0,\mathrm{ref},s}\}
-\log\{1-\omega_s+\omega_s m_{0,\mathrm{GH},s}\}\right].
\]

The importance-reweighted and unweighted richness PMFs must differ by no more
than 0.005 total variation and 0.025 species in posterior mean. Every retained
draw must lie inside the protected domain.

### Monte Carlo-aware equivalence

Each path first receives the existing four-chain, 1,000-warmup,
1,000-sampling geometry probe. It then receives one terminal confirmation fit
with four chains, 1,500 warmup iterations, 6,000 retained iterations per
chain, `adapt_delta = 0.99`, and `max_treedepth = 15`. Confirmation seeds are
the locked primary seeds plus 1,000,000. There is no further rescue.

Rao--Blackwellised per-draw richness PMFs are divided into 30 contiguous
batches per chain. A chain-respecting bootstrap with 2,000 replicates and a
fixed seed estimates one-sided 95% upper confidence bounds for total-
variation distance and one-Wasserstein distance. Each clean pair must satisfy

- upper confidence bound for TV at most 0.05; and
- upper confidence bound for $W_1$ at most 0.25 species.

Within-method bootstrap comparisons are reported as the Monte Carlo noise
floor but are not a separate gate. Existing shared-parameter fidelity checks
remain unchanged.

### Geometry and computational value

The collapsed terminal confirmation must be clean in all six cases, its
primary-clean count must be at least the original count, and the historical
stress case must be clean. For cases with two clean terminal fits:

- median collapsed/original total cost-to-confirmation ratio must be at most
  2.0;
- median collapsed/original ESS-per-second ratio across \(\omega\),
  \(\mu_\alpha\), \(\sigma_\alpha\), \(\sigma_{\mathrm{camera}}\),
  \(q_{\mathrm{unseen}}\), expected richness, and per-draw PMF probabilities
  at $D$, the posterior median, and $C$, must be at least 0.75; and
- no collapsed confirmation fit may exceed 900 seconds on the locked
  workstation.

Log-density/gradient evaluations per second and raw runtime are reported but
are not additional gates. Total cost includes both the geometry probe and the
confirmation fit.

## Stopping rule

Perform one focused review and repair only a demonstrated implementation
defect. Stop after the preflight decision and return it for PI assessment.

- `SELECT_256` or `SELECT_512` authorises planning the separately versioned
  paired experiment above; it does not retain the scientific model.
- `CLOSE` ends Goal 002R computational repair.
- A rule-generation or oracle failure is reported as an implementation
  blocker and may receive one repair pass; it is not converted into a model
  result.

No empirical analysis, broader calibration, new integrator search, or
ecological model extension begins in this tranche.
