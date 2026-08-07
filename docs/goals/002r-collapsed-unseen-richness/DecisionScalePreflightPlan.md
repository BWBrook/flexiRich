# Goal 002R Decision-Scale Numerical Preflight Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Determine whether exposure-reduced fixed Gauss--Hermite quadrature
at order 256 or 512 satisfies the approved decision-scale value and gradient
contract without changing the production model.

**Architecture:** A pure numerical module will generate stable log-weight
Gauss--Hermite rules and evaluate candidate and adaptive-reference values and
derivatives. A separate audit module will construct the locked posterior and
domain states, search for maxima, apply the order-selection rule, and write
compact evidence through one thin runner.

**Tech Stack:** R 4.6.1, base R numerical routines, testthat and tidyverse
packages already locked by the project. No new dependency and no Stan
compilation.

## Global Constraints

- Preserve the original order-128 `REJECT` and the stopped first numerical
  revision.
- Do not modify `R/goal002r/math.R`, `R/goal002r/config.R`,
  `stan/flexirich_g_collapsed.stan`, or the paired-comparison runner.
- Evaluate fixed Gauss--Hermite orders 256 and 512 only.
- Protect \(a\in[-8,10]\), \(\sigma_\alpha\in[0,5.5]\), and \(U\le29\).
- Require \(U|\Delta\log m_0|\le5\times10^{-4}\).
- Require maximum scaled gradient discrepancy below \(10^{-2}\) and pooled
  RMS below \(10^{-3}\).
- Select order 256 only with twofold headroom on every decision-scale limit;
  otherwise select order 512 only if it passes the full limits.
- If neither order passes, return `CLOSE`; do not test another order or
  algorithm.
- Keep generated evidence under ignored
  `outputs/goal002r/decision-scale-preflight/`.
- Use one focused review and one repair pass only for a demonstrated defect.
- Do not begin a paired fit, ecological-model extension, or empirical analysis
  in this tranche.

## File Map

- `R/goal002r/preflight_math.R`: locked contract, stable quadrature rule,
  candidate value/derivatives, adaptive reference, and algebraic checks.
- `R/goal002r/preflight_audit.R`: state construction, deterministic audit,
  bounded maxima search, decision, and evidence writing.
- `tests/testthat/test-goal002r-preflight-math.R`: numerical-unit contracts.
- `tests/testthat/test-goal002r-preflight-audit.R`: audit and decision
  contracts.
- `scripts/run_goal002r_decision_scale_preflight.R`: one thin executable.
- `docs/goals/002r-collapsed-unseen-richness/DecisionScalePreflightDesign.md`:
  approved contract and, after execution, concise result.

---

## Task 1: Implement stable fixed-rule values and derivatives

**Files:**

- Create: `R/goal002r/preflight_math.R`
- Create: `tests/testthat/test-goal002r-preflight-math.R`

**Interfaces:**

- Consumes: `.goal002r_stop()` and `.goal002r_scalar()` from
  `R/goal002r/math.R`.
- Produces:
  - `goal002r_preflight_contract() -> named list`
  - `goal002r_preflight_rule(order) -> tibble(node, log_weight)`
  - `goal002r_preflight_rule_checks(rule, order) -> tibble`
  - `goal002r_preflight_gh(a, sigma_alpha, rule) -> named numeric`
  - `goal002r_preflight_algebra_checks() -> tibble`

- [ ] **Step 1: Write failing contract and high-order rule tests**

Create `tests/testthat/test-goal002r-preflight-math.R` with:

```r
testthat::test_that("decision-scale preflight contract is frozen", {
  contract <- goal002r_preflight_contract()
  testthat::expect_identical(contract$orders, c(256L, 512L))
  testthat::expect_identical(contract$a_bounds, c(-8, 10))
  testthat::expect_identical(contract$sigma_bounds, c(0, 5.5))
  testthat::expect_identical(contract$grid_size, 61L)
  testthat::expect_identical(contract$max_unseen, 29L)
  testthat::expect_identical(contract$search_starts, 12L)
  testthat::expect_identical(
    contract$reference_tolerances,
    c(1e-10, 1e-12)
  )
  testthat::expect_identical(contract$value_gate, 5e-4)
  testthat::expect_identical(contract$gradient_max_gate, 1e-2)
  testthat::expect_identical(contract$gradient_rms_gate, 1e-3)
  testthat::expect_identical(contract$selection_headroom, 0.5)
})

testthat::test_that("high-order rules retain finite log weights and moments", {
  expected <- c(`0` = 1, `2` = 1, `4` = 3, `6` = 15, `8` = 105, `10` = 945)
  for (order in c(256L, 512L)) {
    rule <- goal002r_preflight_rule(order)
    testthat::expect_identical(nrow(rule), order)
    testthat::expect_true(all(is.finite(rule$node)))
    testthat::expect_true(all(is.finite(rule$log_weight)))
    testthat::expect_lt(max(abs(rule$node + rev(rule$node))), 5e-10)
    testthat::expect_lt(
      max(abs(rule$log_weight - rev(rule$log_weight))),
      5e-10
    )
    weights <- exp(rule$log_weight)
    moments <- vapply(
      as.integer(names(expected)),
      function(power) sum(weights * rule$node^power),
      numeric(1)
    )
    testthat::expect_equal(moments, unname(expected), tolerance = 1e-11)
  }
})
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```sh
Rscript -e 'testthat::test_dir(
  "tests/testthat",
  filter = "goal002r-preflight-math",
  reporter = "summary",
  stop_on_failure = TRUE,
  stop_on_warning = TRUE
)'
```

Expected: failure because `goal002r_preflight_contract()` and
`goal002r_preflight_rule()` do not exist.

- [ ] **Step 3: Implement the frozen contract and stable log-weight rule**

Add the following structure to `R/goal002r/preflight_math.R`:

```r
goal002r_preflight_contract <- function() {
  list(
    orders = c(256L, 512L),
    a_bounds = c(-8, 10),
    sigma_bounds = c(0, 5.5),
    grid_size = 61L,
    max_unseen = 29L,
    search_starts = 12L,
    reference_tolerances = c(1e-10, 1e-12),
    reference_agreement = 1e-8,
    finite_difference_tolerance = 1e-5,
    value_gate = 5e-4,
    gradient_max_gate = 1e-2,
    gradient_rms_gate = 1e-3,
    selection_headroom = 0.5,
    gradient_scales = c(a = 1.5, sigma = 0.85, log_sigma = 1.2),
    posterior_state_file = file.path(
      "docs", "consultations", "goal002r-next-step", "evidence",
      "numerical-screen-states.csv"
    ),
    case_file = file.path(
      "docs", "consultations", "goal002r-next-step", "evidence",
      "case-results.csv"
    ),
    output_component = "decision-scale-preflight"
  )
}

.goal002r_preflight_log_sum_exp <- function(x) {
  anchor <- max(x)
  if (!is.finite(anchor)) return(anchor)
  anchor + log(sum(exp(x - anchor)))
}

.goal002r_preflight_log_hermite <- function(x, degree) {
  previous <- 1
  if (degree == 0L) return(0)
  current <- x
  log_scale <- 0
  if (degree == 1L) return(log(abs(current)))

  for (k in seq_len(degree - 1L)) {
    next_value <- (
      x * current - sqrt(k) * previous
    ) / sqrt(k + 1)
    magnitude <- max(abs(c(previous, current, next_value)))
    if (magnitude > 1e100 || (magnitude > 0 && magnitude < 1e-100)) {
      previous <- previous / magnitude
      current <- current / magnitude
      next_value <- next_value / magnitude
      log_scale <- log_scale + log(magnitude)
    }
    previous <- current
    current <- next_value
  }
  log(abs(current)) + log_scale
}

goal002r_preflight_rule <- function(order) {
  order <- as.integer(.goal002r_scalar(order, "order", lower = 1))
  if (!order %in% goal002r_preflight_contract()$orders) {
    .goal002r_stop("Preflight order must be exactly 256 or 512.")
  }
  jacobi <- matrix(0, nrow = order, ncol = order)
  off_diagonal <- sqrt(seq_len(order - 1L))
  jacobi[cbind(seq_len(order - 1L), seq_len(order - 1L) + 1L)] <-
    off_diagonal
  jacobi[cbind(seq_len(order - 1L) + 1L, seq_len(order - 1L))] <-
    off_diagonal
  node <- sort(eigen(
    jacobi,
    symmetric = TRUE,
    only.values = TRUE
  )$values)
  log_weight <- -log(order) - 2 * vapply(
    node,
    .goal002r_preflight_log_hermite,
    numeric(1),
    degree = order - 1L
  )
  log_weight <- log_weight -
    .goal002r_preflight_log_sum_exp(log_weight)
  tibble::tibble(node = node, log_weight = log_weight)
}
```

Implement `goal002r_preflight_rule_checks()` as one row per symmetry,
normalisation, and moment check with columns
`order`, `check`, `observed`, `threshold`, and `passed`.

- [ ] **Step 4: Add failing candidate and algebraic-identity tests**

Append:

```r
testthat::test_that("fixed rule returns value and primitive derivatives", {
  rule <- goal002r_preflight_rule(256L)
  deterministic <- goal002r_preflight_gh(
    a = log(0.2),
    sigma_alpha = 0,
    rule = rule
  )
  testthat::expect_equal(
    deterministic,
    c(log_m0 = -0.2, derivative_a = -0.2, derivative_sigma = 0),
    tolerance = 1e-14
  )

  shifted <- goal002r_preflight_gh(
    a = 2,
    sigma_alpha = 4,
    rule = rule
  )
  testthat::expect_true(all(is.finite(shifted)))
  testthat::expect_lte(shifted[["log_m0"]], 0)
})

testthat::test_that("exposure reduction preserves the row-wise calculation", {
  checks <- goal002r_preflight_algebra_checks()
  testthat::expect_identical(nrow(checks), 4L)
  testthat::expect_true(all(checks$passed))
  testthat::expect_lte(max(checks$absolute_error), 1e-12)
})
```

- [ ] **Step 5: Implement candidate derivatives and algebra checks**

Use normalised log terms to avoid exponentiating high-order weights:

```r
goal002r_preflight_gh <- function(a, sigma_alpha, rule) {
  a <- .goal002r_scalar(a, "a")
  sigma_alpha <- .goal002r_scalar(
    sigma_alpha,
    "sigma_alpha",
    lower = 0
  )
  if (sigma_alpha == 0) {
    value <- -exp(a)
    return(c(
      log_m0 = value,
      derivative_a = value,
      derivative_sigma = 0
    ))
  }

  log_t <- a + sigma_alpha * rule$node
  t_value <- exp(log_t)
  log_terms <- rule$log_weight - t_value
  log_m0 <- .goal002r_preflight_log_sum_exp(log_terms)
  normalised <- exp(log_terms - log_m0)
  weighted_t <- normalised * t_value
  c(
    log_m0 = log_m0,
    derivative_a = -sum(weighted_t),
    derivative_sigma = -sum(rule$node * weighted_t)
  )
}
```

For `goal002r_preflight_algebra_checks()`, use the fixed fixture:

```r
zero_history <- tibble::tribble(
  ~camera_id, ~active_days, ~n_trials,
  "cam_01", 1L, 4L,
  "cam_01", 5L, 2L,
  "cam_02", 2L, 3L
)
camera_effect <- c(cam_01 = -0.2, cam_02 = 0.2)
mu_alpha <- log(0.001)
sigma_values <- c(0, 0.4, 1.1, 2)
```

Compare row-wise and exposure-reduced log-sum-exp values with the same order-
256 log rule. Return the four errors and `passed = absolute_error <= 1e-12`.

- [ ] **Step 6: Verify Task 1 and commit**

Run:

```sh
Rscript -e 'testthat::test_dir(
  "tests/testthat",
  filter = "goal002r-preflight-math",
  reporter = "summary",
  stop_on_failure = TRUE,
  stop_on_warning = TRUE
)'
git diff --check
git add R/goal002r/preflight_math.R \
  tests/testthat/test-goal002r-preflight-math.R
git commit -m "feat: add stable Goal002R preflight quadrature"
```

Expected: focused tests pass; no production Goal 002R file changes.

---

## Task 2: Implement the independent value-and-gradient oracle

**Amended after load-bearing review:** commit `f21a9ee` followed the original
brief, but the fixed `[-12,12]` range is not a valid reference on the protected
domain and the forward quotient at `sigma_alpha == 0` is invalid. Task 3
remains blocked until this amended task is implemented and reviewed.

**Files:**

- Modify: `R/goal002r/preflight_math.R`
- Modify: `tests/testthat/test-goal002r-preflight-math.R`

**Interfaces:**

- Consumes: the contract and candidate functions from Task 1.
- Produces:
  - `goal002r_preflight_reference(a, sigma_alpha, rel_tol) -> named numeric`
  - `goal002r_preflight_reference_pair(a, sigma_alpha) -> named numeric`
  - `goal002r_preflight_derivative_checks(states) -> tibble`

- [ ] **Step 1: Freeze the repaired oracle contract and write failing
  regressions**

Extend `goal002r_preflight_contract()` with exactly:

```r
mode_initial_bound = 1
mode_max_expansions = 64L
tail_initial_scales = 8
tail_max_expansions = 20L
tail_relative_bound = 1e-14
tail_stability = 1e-9
```

Add regressions for the exact states `(10, 5.5 / 60)`, `(10, 0.55)`, and
`(10, 0)`. The first must equal

```r
c(
  log_m0 = -1351.413795,
  derivative_a = -460.412146,
  derivative_sigma = 19422.772652
)
```

within `5e-6`. The second must return finite values at both locked tolerances.
Both non-zero states must have all three strict/loose agreements at most
`1e-8`, maximum certified relative tail bound at most `1e-14`, and maximum
post-expansion output change at most `1e-9`. The zero state must equal
`c(-exp(10), -exp(10), 0)` in the same output order, report the exact sigma
derivative, and satisfy the evenness check in Step 4.

- [ ] **Step 2: Run the focused test and verify RED**

Run the Task 1 focused command. Expected: the reviewed fixed-range oracle fails
at the new regression and stability requirements.

- [ ] **Step 3: Implement deterministic mode location and certified tails**

For `t = exp(a + sigma_alpha * z)`, retain the continuous kernels already used
by the oracle. Their analytic scores are:

```r
score_denominator <- -z - sigma_alpha * t
score_numerator_a <- -z + sigma_alpha - sigma_alpha * t
score_sigma_magnitude <- score_numerator_a + 1 / z
```

The corresponding curvatures are `-1 - sigma_alpha^2 * t` for the first two
and that quantity minus `1 / z^2` for each sigma magnitude. They are strictly
negative, so every whole-line kernel has one mode and each open-half-line
sigma kernel has one mode.

Bracket each score root without `optimize()`. For a whole-line kernel start at
`[-1, 1]`; double only an endpoint whose score does not yet have the required
positive-left/negative-right sign. For the positive sigma kernel use
`[sqrt(.Machine$double.eps), 1]` and double the right endpoint; for the negative
kernel use `[-1, -sqrt(.Machine$double.eps)]` and double the magnitude of the
left endpoint. Use overflow-safe score evaluation. Stop after 64 expansions
per movable endpoint and error if the signs do not bracket a root. Locate the
root with `stats::uniroot(tol = 1e-12, maxiter = 100L)` and set
`local_scale = 1 / sqrt(-curvature(mode))`.

For each primitive integral, transform to
`y = (z - mode) / local_scale`, subtract the modal log kernel, and split the
finite transformed interval at `y = 0`. Call `stats::integrate()` separately
on the two pieces with the requested locked relative tolerance, matching
absolute tolerance, `subdivisions = 1000L`, and `stop.on.error = TRUE`. This
mode-centred scaling is mandatory for the positive and negative sigma
magnitudes: each half has its own mode and scale, so a mode close to `z = 0`
cannot be hidden at an endpoint of a broad interval.

Start every unbounded endpoint eight local scales from the mode. For a log
kernel `K`, use strict concavity to certify omitted mass:

```r
left_bound <- exp(K(L)) / score(L)       # score(L) > 0
right_bound <- exp(K(R)) / (-score(R))   # score(R) < 0
```

Evaluate these bounds in log space. Double the mode-to-endpoint distance until
the sum of applicable bounds is at most `1e-14` of the enclosed integral, with
at most 20 expansions per unbounded endpoint. After first passage, double
every unbounded endpoint once more, repeat the integral, and require the
absolute change in each of `log_m0`, `derivative_a`, and `derivative_sigma` to
be at most `1e-9`. Any non-finite score, curvature, bound, or integral, or any
failure to meet the finite expansion limits, is an oracle error.

Combine the separately integrated positive and negative sigma magnitudes with
signed log arithmetic. Use `expm1()` when their log magnitudes are close; do
not exponentiate both large ratios and subtract them naively. Return:

```r
c(
  log_m0 = log(denominator),
  derivative_a = -numerator_a / denominator,
  derivative_sigma = -numerator_sigma / denominator
)
```

Handle `sigma_alpha == 0` with the exact candidate expression. In
`goal002r_preflight_reference_pair()`, run the oracle at `1e-10` and `1e-12`,
retain the strict result, and append the three absolute agreements, maximum
certified relative tail bound, maximum post-expansion output change, and the
maximum number of tail expansions used. The implementation must remain
independent of the Gauss--Hermite nodes, weights, and candidate sums.

- [ ] **Step 4: Replace the invalid sigma-boundary quotient**

For positive `sigma_alpha`, retain central differences with `h_a = 1e-5` and
`h_sigma = max(1e-5, sigma_alpha * 1e-5)`. At `sigma_alpha == 0`, do not use a
forward quotient. The boundary row instead passes only if the analytic sigma
derivative is exactly zero and a private signed-sigma evaluation satisfies

```r
abs(log_m0(a, 1e-5) - log_m0(a, -1e-5)) <= 1e-12
```

The signed evaluation is diagnostic only; the public protected domain remains
non-negative. Test at least:

```r
tibble::tribble(
  ~a, ~sigma_alpha,
  -8, 5.5,
   0, 2.75,
  10, 5.5,
  10, 0
)
```

Return one `a` row and one `sigma_alpha` row per state. Label the boundary
sigma row `exact_evenness`, rather than `finite_difference`, while retaining a
common `observed`, `threshold`, and `passed` schema. Positive-sigma derivative
differences must agree within `1e-5`.

- [ ] **Step 5: Add expansion and exhaustive grid prechecks**

Exercise the private integrator at `(10, 5.5 / 60)` with an intentionally
narrow two-local-scale initial interval. Require at least one expansion, the
`1e-14` certified tail bound, and agreement with the default eight-scale result
within `1e-9` for all three outputs. This is a regression of the frozen
expansion rule, not permission to tune it during the preflight.

Then evaluate `goal002r_preflight_reference_pair()` at every state from:

```r
tidyr::crossing(
  a = seq(-8, 10, length.out = 61L),
  sigma_alpha = seq(0, 5.5, length.out = 61L)
)
```

Require exactly 3,721 completed states, finite returned values, maximum
strict/loose agreement at most `1e-8`, maximum certified relative tail bound at
most `1e-14`, and maximum post-expansion change at most `1e-9`. This finite
oracle precheck must pass and be recorded in the Task 2 report before any Task
3 code is started.

- [ ] **Step 6: Verify Task 2 and commit**

Run:

```sh
Rscript -e 'testthat::test_dir(
  "tests/testthat",
  filter = "goal002r-preflight-math",
  reporter = "summary",
  stop_on_failure = TRUE,
  stop_on_warning = TRUE
)'
git diff --check
git add R/goal002r/preflight_math.R \
  tests/testthat/test-goal002r-preflight-math.R
git commit -m "fix: repair Goal002R preflight reference oracle"
```

Expected: all math tests, the exact regressions, the forced-expansion check,
and the 3,721-state oracle precheck pass. If any bounded oracle criterion
fails, stop with an error. Do not try another range, tolerance, or algorithm;
after the one authorised repair pass is exhausted, record `CLOSE`.

---

## Task 3: Implement deterministic audits, maxima search, and selection

**Precondition:** do not start this task until the amended Task 2 regressions,
forced-expansion check, all-3,721-state oracle precheck, and task-scoped review
have passed.

**Files:**

- Create: `R/goal002r/preflight_audit.R`
- Create: `tests/testthat/test-goal002r-preflight-audit.R`

**Interfaces:**

- Consumes: all Task 1--2 functions and the two committed consultation CSVs.
- Produces:
  - `goal002r_preflight_posterior_states(...) -> tibble`
  - `goal002r_preflight_domain_grid() -> tibble`
  - `goal002r_preflight_audit(states, source) -> tibble`
  - `goal002r_preflight_search_maxima(domain_audit) -> tibble`
  - `goal002r_preflight_criteria(...) -> tibble`
  - `goal002r_preflight_select(criteria) -> character`
  - `goal002r_preflight_run() -> named list`

- [ ] **Step 1: Write failing state and grid tests**

Create `tests/testthat/test-goal002r-preflight-audit.R`:

```r
testthat::test_that("preflight states reproduce the locked evidence", {
  states <- goal002r_preflight_posterior_states()
  testthat::expect_identical(nrow(states), 750L)
  testthat::expect_setequal(
    unique(states$case_id),
    goal002r_paired_cases()$case_id
  )
  testthat::expect_true(all(states$U >= 0L & states$U <= 29L))
  testthat::expect_equal(
    range(states$a),
    c(-5.5408861, 3.2412154),
    tolerance = 1e-6
  )
  testthat::expect_equal(
    range(states$sigma_alpha),
    c(0.002599196, 4.675935063),
    tolerance = 1e-6
  )
})

testthat::test_that("protected grid includes every boundary", {
  grid <- goal002r_preflight_domain_grid()
  testthat::expect_identical(nrow(grid), 61L * 61L)
  testthat::expect_identical(range(grid$a), c(-8, 10))
  testthat::expect_identical(range(grid$sigma_alpha), c(0, 5.5))
  testthat::expect_true(all(grid$U == 29L))
})
```

- [ ] **Step 2: Run focused audit tests and verify RED**

Run:

```sh
Rscript -e 'testthat::test_dir(
  "tests/testthat",
  filter = "goal002r-preflight-audit",
  reporter = "summary",
  stop_on_failure = TRUE,
  stop_on_warning = TRUE
)'
```

Expected: missing state/grid function failures.

- [ ] **Step 3: Implement state construction**

In `goal002r_preflight_posterior_states()`:

1. read `numerical-screen-states.csv` and `case-results.csv`;
2. require exactly 750 unique `case_id`/`posterior_row` pairs;
3. join `candidate_pool_size` and `observed_richness`;
4. set `U = candidate_pool_size - observed_richness`; and
5. rename `log_B` to `a`, retaining only
   `case_id`, `check_source`, `posterior_row`, `a`, `sigma_alpha`, and `U`.

Construct the grid with:

```r
tidyr::crossing(
  a = seq(-8, 10, length.out = 61L),
  sigma_alpha = seq(0, 5.5, length.out = 61L)
) |>
  dplyr::mutate(U = 29L)
```

- [ ] **Step 4: Write failing audit and decision tests**

Append:

```r
testthat::test_that("audit reports both orders and scaled discrepancies", {
  states <- tibble::tribble(
    ~a, ~sigma_alpha, ~U,
    -8, 0, 29L,
     0, 2.75, 29L,
    10, 5.5, 29L
  )
  audit <- goal002r_preflight_audit(states, source = "test")
  testthat::expect_identical(nrow(audit), 6L)
  testthat::expect_setequal(unique(audit$order), c(256L, 512L))
  testthat::expect_true(all(c(
    "target_error", "scaled_a_error", "scaled_sigma_error",
    "scaled_log_sigma_error", "reference_agreement",
    "tail_relative_bound", "expansion_change"
  ) %in% names(audit)))
  numeric <- audit[vapply(audit, is.numeric, logical(1))]
  testthat::expect_true(all(is.finite(unlist(numeric))))
})

testthat::test_that("selection precedence is 256 headroom then 512 then close", {
  passing <- tibble::tibble(
    order = c(256L, 512L),
    full_pass = c(TRUE, TRUE),
    headroom_pass = c(TRUE, TRUE)
  )
  testthat::expect_identical(
    goal002r_preflight_select(passing),
    "SELECT_256"
  )
  passing$headroom_pass[1] <- FALSE
  testthat::expect_identical(
    goal002r_preflight_select(passing),
    "SELECT_512"
  )
  passing$full_pass[2] <- FALSE
  testthat::expect_identical(
    goal002r_preflight_select(passing),
    "CLOSE"
  )
})
```

- [ ] **Step 5: Implement audit metrics**

For each state, calculate the strict reference once and evaluate both rules.
Return candidate/reference values and derivatives plus:

```r
target_error <- U * abs(candidate_log_m0 - reference_log_m0)
scaled_a_error <- 1.5 * U *
  abs(candidate_derivative_a - reference_derivative_a)
scaled_sigma_error <- 0.85 * U *
  abs(candidate_derivative_sigma - reference_derivative_sigma)
scaled_log_sigma_error <- 1.2 * U * sigma_alpha *
  abs(candidate_derivative_sigma - reference_derivative_sigma)
reference_agreement <- max(
  value_agreement,
  derivative_a_agreement,
  derivative_sigma_agreement
)
tail_relative_bound <- maximum_tail_relative_bound
expansion_change <- maximum_expansion_change
```

Keep one row per order and state. Any non-finite result stops with a concise
state identifier. A tail bound above `1e-14` or expansion change above `1e-9`
is also an oracle failure, not a candidate discrepancy.

- [ ] **Step 6: Implement bounded maxima search**

For each order and each of
`target_error`, `scaled_a_error`, `scaled_sigma_error`, and
`scaled_log_sigma_error`:

1. select the 12 largest grid rows as starts;
2. call `stats::optim(method = "L-BFGS-B")` on the negative metric with
   `lower = c(-8, 0)` and `upper = c(10, 5.5)`;
3. reevaluate the returned point using the strict reference; and
4. retain the largest finite result across starts.

Return exactly eight rows with
`order`, `metric`, `a`, `sigma_alpha`, `observed`, and `convergence`.
Non-zero optimiser convergence is retained visibly; all 12 failures for one
order/metric constitute an implementation blocker.

- [ ] **Step 7: Implement the decision summary**

For each order, combine posterior, grid, and searched maxima. Define:

```r
maximum_target <- max(target_error)
maximum_gradient <- max(
  scaled_a_error,
  scaled_sigma_error,
  scaled_log_sigma_error
)
rms_gradient <- sqrt(mean(c(
  scaled_a_error,
  scaled_sigma_error,
  scaled_log_sigma_error
)^2))
full_pass <- maximum_target <= 5e-4 &&
  maximum_gradient < 1e-2 &&
  rms_gradient < 1e-3 &&
  maximum_reference_agreement <= 1e-8 &&
  maximum_tail_relative_bound <= 1e-14 &&
  maximum_expansion_change <= 1e-9
headroom_pass <- full_pass &&
  maximum_target <= 2.5e-4 &&
  maximum_gradient <= 5e-3 &&
  rms_gradient <= 5e-4
```

`goal002r_preflight_select()` returns `SELECT_256` when order 256 has
`headroom_pass`, otherwise `SELECT_512` when order 512 has `full_pass`,
otherwise `CLOSE`.

For the derivative sanity check, combine the four domain corners, the domain
centre, and the five unique states with the largest per-state maximum across
all value and gradient discrepancies. Run
`goal002r_preflight_derivative_checks()` on those ten states, yielding exactly
20 rows. Use central differences only when `sigma_alpha > 0`. Each
`sigma_alpha == 0` row instead checks the exact zero analytic derivative and
the `1e-12` evenness identity; it must not contain a forward quotient.

`goal002r_preflight_run()` assembles:

```r
list(
  rule_integrity = dplyr::bind_rows(
    rule_checks,
    goal002r_preflight_algebra_checks(),
    derivative_checks
  ),
  posterior_audit = posterior_audit,
  domain_audit = domain_audit,
  maxima = maxima,
  criteria = criteria,
  decision = decision
)
```

- [ ] **Step 8: Verify Task 3 and commit**

Run:

```sh
Rscript -e 'testthat::test_dir(
  "tests/testthat",
  filter = "goal002r-preflight",
  reporter = "summary",
  stop_on_failure = TRUE,
  stop_on_warning = TRUE
)'
git diff --check
git add R/goal002r/preflight_audit.R \
  tests/testthat/test-goal002r-preflight-audit.R
git commit -m "feat: add Goal002R preflight decision audit"
```

Expected: focused math and audit tests pass; no fit is run.

---

## Task 4: Run once, reconcile evidence, and report the decision

**Files:**

- Create: `scripts/run_goal002r_decision_scale_preflight.R`
- Modify: `R/goal002r/preflight_audit.R`
- Modify: `tests/testthat/test-goal002r-preflight-audit.R`
- Modify:
  `docs/goals/002r-collapsed-unseen-richness/DecisionScalePreflightDesign.md`

**Interfaces:**

- Consumes: `goal002r_preflight_run()` from Task 3.
- Produces:
  - `goal002r_preflight_write(result, output_dir) -> named character vector`
  - the five evidence files specified by the approved design
  - one appended result section in the design document

- [ ] **Step 1: Write failing evidence-writer tests**

Append:

```r
testthat::test_that("preflight writer emits only the five approved files", {
  fixture <- goal002r_preflight_result_fixture(decision = "SELECT_256")
  output_dir <- tempfile("goal002r-preflight-")
  paths <- goal002r_preflight_write(fixture, output_dir)
  testthat::expect_setequal(
    basename(paths),
    c(
      "rule-integrity.csv",
      "posterior-state-audit.csv",
      "domain-audit.csv",
      "numerical-maxima.csv",
      "decision.txt"
    )
  )
  testthat::expect_true(all(file.exists(paths)))
  decision_text <- paste(readLines(paths[["decision"]]), collapse = "\n")
  testthat::expect_match(decision_text, "SELECT_256")
})
```

Implement `goal002r_preflight_result_fixture()` inside the test file as a
minimal named list with the exact `goal002r_preflight_run()` schema. It is test
data, not production API.

- [ ] **Step 2: Run the focused audit tests and verify RED**

Run the Task 3 focused command. Expected: writer does not exist.

- [ ] **Step 3: Implement the compact writer**

`goal002r_preflight_write()` must:

1. reject an output directory containing any of the five approved filenames;
2. create the directory;
3. write the four approved CSVs without row names;
4. write `decision.txt` with the decision and one line per criterion; and
5. return a named path vector.

Do not add a manifest, hash table, ledger, plot, or report renderer.

- [ ] **Step 4: Create the thin runner**

Create:

```r
if (!dir.exists("R") || !dir.exists("stan")) {
  stop("Run this script from the flexiRich repository root.", call. = FALSE)
}

source(file.path("scripts", "source_goal002r.R"))
source_goal002r(".")

result <- goal002r_preflight_run()
output_dir <- goal002r_output_path(
  goal002r_preflight_contract()$output_component
)
paths <- goal002r_preflight_write(result, output_dir)
print(result$criteria)
cat("Decision:", result$decision, "\n")
cat("Evidence:", output_dir, "\n")
```

- [ ] **Step 5: Verify all code before the scientific run**

Run:

```sh
Rscript -e 'testthat::test_dir(
  "tests/testthat",
  filter = "goal002r-preflight",
  reporter = "summary",
  stop_on_failure = TRUE,
  stop_on_warning = TRUE
)'
Rscript scripts/run_tests.R
git diff --check
```

Expected: all tests pass and only the preflight files are changed.

- [ ] **Step 6: Execute the preflight once**

Run:

```sh
Rscript scripts/run_goal002r_decision_scale_preflight.R
```

Expected output structure:

- 1,500 posterior-audit rows: 750 states times two orders;
- 7,442 domain-audit rows: 3,721 states times two orders;
- eight maximum-search rows;
- finite reference agreements no greater than \(10^{-8}\); and
- exactly one of `SELECT_256`, `SELECT_512`, or `CLOSE`.

If an implementation defect stops the run, repair it once, remove only
`outputs/goal002r/decision-scale-preflight/`, rerun the affected focused tests
and full suite, then execute once more. Do not change the domain, orders, or
thresholds.

- [ ] **Step 7: Perform one focused reconciliation**

Check:

```sh
wc -l outputs/goal002r/decision-scale-preflight/*.csv
Rscript -e '
  root <- "outputs/goal002r/decision-scale-preflight"
  p <- read.csv(file.path(root, "posterior-state-audit.csv"))
  d <- read.csv(file.path(root, "domain-audit.csv"))
  m <- read.csv(file.path(root, "numerical-maxima.csv"))
  stopifnot(
    nrow(p) == 1500L,
    nrow(d) == 7442L,
    nrow(m) == 8L,
    setequal(unique(p$order), c(256L, 512L)),
    setequal(unique(d$order), c(256L, 512L)),
    all(is.finite(unlist(p[vapply(p, is.numeric, logical(1))]))),
    all(is.finite(unlist(d[vapply(d, is.numeric, logical(1))])))
  )
'
```

Read `decision.txt` and verify it agrees with recomputed criteria. Confirm
`git diff --name-only` contains no production math, Stan, fit, or paired-runner
file.

- [ ] **Step 8: Record the result and commit**

Append a concise `## Preflight result` section to
`DecisionScalePreflightDesign.md` containing:

- the selected decision;
- order-level maximum target error, maximum scaled gradient error, RMS
  gradient error, and maximum reference disagreement;
- rule/algebra/derivative-diagnostic status; and
- the authorised next step or closure statement.

Set the document status to `completed — SELECT_256`,
`completed — SELECT_512`, or `completed — CLOSE`.

Run:

```sh
Rscript scripts/run_tests.R
git diff --check
git status --short
git add R/goal002r/preflight_audit.R \
  scripts/run_goal002r_decision_scale_preflight.R \
  tests/testthat/test-goal002r-preflight-audit.R \
  docs/goals/002r-collapsed-unseen-richness/DecisionScalePreflightDesign.md
git commit -m "test: complete Goal002R decision-scale preflight"
```

Stop and report the decision. Do not implement the selected rule in Stan in
the same tranche.

## Acceptance and Stopping Point

The implementation tranche is complete when:

- focused and full tests pass;
- the rule, oracle, posterior-state, domain, maxima, and decision evidence are
  internally reconciled;
- the approved design records exactly one terminal preflight decision; and
- no production or paired-fit code has changed.

Return the evidence-backed decision, material numerical limitation, and
highest-value next step for PI assessment. A selected order authorises a new
paired-experiment implementation plan; it does not retain the ecological
model.
