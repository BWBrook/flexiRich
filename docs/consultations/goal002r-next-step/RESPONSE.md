# Overall judgement

Barry, my judgement is that the collapsed formulation survives this consultation. I recommend **Path B: one separately versioned, tightly bounded decision-scale experiment**, with three qualifications.

First, the original order-128 `REJECT` decision must remain untouched. It was the correct outcome under the prespecified rules. The next experiment would test a new computational implementation and a newly justified numerical contract, not rescore the first result. Second, I would use the exact exposure reduction and a fixed Gauss–Hermite rule—order 256 initially, with order 512 as the only predeclared fallback—rather than open a broader search over adaptive quadrature, saddlepoint approximations or surrogates. Third, Path D should follow as the next scientific gate before empirical use, but it should not be used retrospectively to rescue or simplify this computational comparison.

The central reason is straightforward: the collapse is an exact marginalisation of the original model under the stated exchangeability conditions; its improvement in the historical stress case is mechanistically consistent with removal of the known membership–detectability ridge; and the numerical errors now appear very small on the scale of the posterior target and richness distribution. The remaining major unknown is not mathematical validity but whether the exposure-reduced implementation produces a worthwhile gain in clean effective samples per second. The formal first experiment found the geometry improvement, one narrow Monte Carlo-sensitive PMF failure, and a runtime comparison badly confounded by avoidable repeated computation.

## Ecological and inferential formulation

### 1. Is the estimand coherent?

Yes, provided it is described operationally. I would define \(g_i=1\) as meaning that candidate \(i\) belongs to the set of species having a non-zero camera-encounter-generating process on the grid during the nominated period. That is a coherent finite-pool estimand. It is bounded, tied to the observation process and considerably better defined than “all species somehow present in the region”.

I would nevertheless avoid letting “use” acquire a stronger biological interpretation than the model supports. A member has a positive hazard at every camera under the present formulation, with differences among cameras represented by a common camera effect. The model does not separately represent local occupancy, realised physical passage during the period, species-specific habitat selection or availability to the camera modality. Thus \(g_i\) is a structural-zero versus positive-hazard distinction, not direct evidence of spatial occupancy or actual grid traversal.

That limitation does not make the estimand incoherent. It simply needs to be part of its name and interpretation. Something close to “finite-pool, grid-level camera-encounter richness” may be even more literal than “detectable-use richness”.

The broader multispecies-occupancy literature reinforces the importance of defining exactly what the inferred richness represents. Simulation work has shown that richness inferred for wholly undetected species can be highly sensitive to the lower tails of occupancy and detection distributions, relevant predictors and priors, even when the overarching model is correctly specified. Your finite named pool removes the unbounded-superpopulation problem, but not the structural-zero versus extremely-low-rate ambiguity.

### 2. Is the collapse itself exact?

Yes. For one all-zero candidate, after integrating its species effect,

\[
L_i=(1-\omega)+\omega m_0,
\qquad
m_0=\int L(\mathbf 0\mid \alpha)\,p(\alpha\mid\mu_\alpha,\sigma_\alpha)\,d\alpha .
\]

For \(U\) conditionally independent, exchangeable all-zero candidates, their joint contribution is

\[
\{(1-\omega)+\omega m_0\}^{U}.
\]

Their conditional membership indicators are therefore independent Bernoulli variables with

\[
q_{\mathrm{unseen}}
=\frac{\omega m_0}{(1-\omega)+\omega m_0},
\]

and hence

\[
S_{\mathrm{grid}}\mid\text{shared parameters}
=D+\operatorname{Binomial}(U,q_{\mathrm{unseen}}).
\]

This is precisely what the two Stan formulations implement: the original retains a latent \(z_{\alpha i}\) and `log_mix` term for every candidate, whereas the collapsed model retains explicit effects only for detected species and adds \(U\) times the integrated zero-history mixture term.

The data adapter also checks the condition needed for the common \(m_0\): all never-detected candidates must have the same positive-effort opportunity history.

### 3. Is a common \(q_{\mathrm{unseen}}\) defensible?

It is defensible as a deliberately minimal prototype. Knowing the species’ names does not logically destroy exchangeability. What destroys exchangeability is possessing relevant information about those species and then declining to use it.

For an empirical analysis, a common \(q\) will probably be too strong if the pool spans taxa or guilds with markedly different camera availability, body size, activity period, habitat association or geographic opportunity. The remedy need not abandon marginalisation. With candidate-specific predictors, one obtains \(m_{0i}\) and \(q_i\), and unseen richness becomes Poisson-binomial rather than binomial. With a modest number of biologically motivated strata, it becomes a convolution of stratum-specific binomials. Both preserve the computational principle.

I would therefore retain the common-\(q\) model for the current equivalence experiment, while explicitly treating exchangeability as a later empirical-model assumption to be tested rather than a permanent feature of FlexiRich-G.

### 4. What does \(\sigma_\alpha\approx4.7\) mean?

It is a warning, but not yet evidence that the encounter distribution is scientifically wrong. On the log-hazard scale, \(\sigma_\alpha=4.7\) implies an approximately \(e^{4.7}\simeq110\)-fold change in rate per one standard deviation of the species effect. The ratio between the 2.5th and 97.5th percentiles of the implied rate distribution is on the order of

\[
e^{3.92\times4.7},
\]

or roughly \(10^8\). That is extreme, although perhaps not automatically absurd for a candidate pool combining highly detectable residents with extraordinarily rare or poorly camera-sampled taxa.

The distribution of the problematic values matters more than the maximum. Among the 750 supplied audit states, only seven had \(\sigma_\alpha>3\), and only two exceeded 4. Both \(>4\) states came from the two small, low-information cases. None of the three candidate-pool-30 standard cases exceeded 3, and the historical stress case had one state just above 3. The primary prior is half-normal with scale 1.5; under that prior, about 4.6% of draws exceed 3, whereas only about 0.9% of the supplied audit states did. That comparison is not a formal prior-to-posterior analysis, but it argues against describing the current evidence as a pervasive posterior escape into implausibly large heterogeneity.

I would distinguish weak identification from genuine heterogeneity using four diagnostics:

1. Plot the complete prior and posterior for \(\sigma_\alpha\) separately by case, together with its joint posterior against \(\mu_\alpha\), \(\omega\), \(q_{\mathrm{unseen}}\) and expected richness. A long ridge in which increasing \(\sigma_\alpha\) is compensated by \(\omega\) or \(\mu_\alpha\) is the signature of weak identification.
2. Examine which detected species determine the lower tail. Leave-one-species-out or leave-one-rare-species-out refits would reveal whether one or two singleton-like species generate the apparent need for enormous heterogeneity.
3. Compare posterior predictive detection-frequency spectra: numbers of species detected once, twice, at one camera, at one occasion and so forth. Total detections alone will not diagnose the rare-species tail.
4. Run prior-sensitivity and simulation-recovery experiments at fixed true \(\sigma_\alpha\), including lower-tail misspecification, mixtures and guild structure. The key question is whether the model can distinguish large true heterogeneity from low membership using the available observation windows.

I would not strengthen the prior or replace the lognormal distribution during the computational repair. That would destroy the clean equivalence question. A gamma distribution for the positive species rate could eventually be attractive because its Laplace transform is closed form,

\[
m_0=\left(\frac{\beta}{\beta+A}\right)^k,
\]

but it represents a different lower-tail model and should be adopted only if ecological and misspecification evidence favours it—not because it eliminates quadrature.

## Numerical accuracy

### 5. The \(10^{-8}\) gate was substantially too severe

Uniform absolute agreement of \(10^{-8}\) in \(\log m_0\) is a numerical-analysis criterion detached from the actual inferential use of the quantity. The relevant zero-tail contribution is

\[
\ell_U
=U\log\{(1-\omega)+\omega m_0\}.
\]

Because

\[
\frac{\partial \ell_U}{\partial\log m_0}=Uq_{\mathrm{unseen}}\le U,
\]

an error \(\delta\) in \(\log m_0\) causes at most \(U\delta\) error in this part of the log target. Accuracy should therefore be controlled through the induced target error, its derivatives and posterior functionals.

I independently recomputed the fixed-rule integrals and their first derivatives from the supplied 750 states. I also evaluated a \(181\times181\) deterministic grid over the stated rectangle and checked the apparent maxima using adaptive quadrature. The dense grid is an audit rather than a mathematical certificate, but the results are informative:

| Fixed rule and audit domain | Maximum \(|\Delta\log m_0|\) | Maximum error in \(\partial\log m_0/\partial\log B\) | Maximum error in \(\partial\log m_0/\partial\sigma_\alpha\) |
|---|---:|---:|---:|
| Order 256, 750 supplied states | \(1.80\times10^{-6}\) | \(3.20\times10^{-5}\) | \(2.07\times10^{-5}\) |
| Order 256, dense bounding rectangle | \(1.58\times10^{-5}\) | \(1.03\times10^{-4}\) | \(4.47\times10^{-5}\) |
| Order 512, same rectangle | \(1.60\times10^{-7}\) | \(1.47\times10^{-6}\) | \(5.61\times10^{-7}\) |

The first row reproduces the supplied fixed-256 result; the latter two extend the check between the sampled states.

The inferential implication is much smaller than even those already small numbers suggest. Taking the dense order-256 maximum and the worst possible \(U=29\),

\[
\epsilon=U\delta
\le29(1.58\times10^{-5})
=4.58\times10^{-4}.
\]

If two unnormalised posterior densities differ uniformly by no more than \(\epsilon\) on the log scale, the total-variation distance between their normalised posteriors is bounded by \(\tanh(\epsilon)\). Here that is approximately \(4.58\times10^{-4}\).

Allowing both posterior reweighting and the direct change in \(q\), the corresponding conservative bound on posterior mean richness is approximately

\[
29\tanh(\epsilon)+29\delta/4
\simeq0.0134\ \text{species}.
\]

A coupling bound for the complete richness PMF is approximately

\[
\tanh(\epsilon)+29\delta/4
\simeq5.7\times10^{-4}.
\]

Those values are far below the original margins of 0.25 species and 0.05 TV. The argument is conditional on having a genuine error bound over the relevant posterior region; a grid alone does not establish that. But it demonstrates why the old \(10^{-8}\) pass/fail rule was mis-scaled.

On the actual 750 states, pairing each state with its own value of \(U\), the maximum fixed-256 zero-tail target error was only \(7.2\times10^{-6}\).

### 6. Could the order-128 error explain the PMF discrepancy?

Almost certainly not. The paired fit used order 128, not 256, so this distinction matters. I therefore also evaluated order 128 on the 125 stored states for `standard-short-low`, the sole PMF failure. Its maximum \(\log m_0\) error was \(1.46\times10^{-6}\), giving a maximum zero-tail target discrepancy of \(4.23\times10^{-5}\) for \(U=29\). If that were a uniform bound over the relevant posterior mass, it would limit the induced mean-richness difference to roughly \(0.0012\) species.

That is about two orders of magnitude below the observed 0.2866-species difference. Combined with the 1.69-MCSE diagnostic and the passing TV, medians, interval endpoints and all 53 shared-parameter comparisons, the isolated mean failure is much more plausibly finite-chain variation than quadrature bias. The correct retrospective conclusion is not “pass”, but “the experiment did not have enough Monte Carlo precision to distinguish equivalence from a small difference at that margin”.

### 7. Do function errors justify another test despite possible gradient errors?

Yes, but the pointwise function bounds are not sufficient by themselves. The additional derivative audit is essential.

Let

\[
a=\log B,\qquad
T=\exp(a+\sigma_\alpha Z).
\]

Then the two fundamental derivatives can be computed independently as

\[
\frac{\partial\log m_0}{\partial a}
=
-\frac{E[T e^{-T}]}{m_0},
\]

and

\[
\frac{\partial\log m_0}{\partial\sigma_\alpha}
=
-\frac{E[ZT e^{-T}]}{m_0}.
\]

All other quadrature-sensitive gradients follow by the chain rule. In particular,

\[
\frac{\partial\ell_U}{\partial\theta}
=
Uq_{\mathrm{unseen}}
\frac{\partial\log m_0}{\partial\theta}.
\]

At the worst points in my dense order-256 audit, multiplying the raw derivative discrepancies by \(U=29\) gives about \(0.0030\) for the \(\log B\) direction and \(0.0013\) for the \(\sigma_\alpha\) direction. Those are not automatically negligible on an HMC scale, but neither are they prima facie alarming. On the actual 750 states, conservative corresponding maxima were approximately \(1.8\times10^{-4}\) and \(1.2\times10^{-4}\).

The correct next test is therefore a full-target gradient comparison in Stan’s unconstrained parameterisation, scaled by posterior parameter variation or the adapted HMC metric. I would require the quadrature-gradient discrepancy, multiplied by one posterior standard deviation of the corresponding parameter, to be comfortably below \(10^{-2}\), with a much smaller RMS discrepancy and no isolated spikes or discontinuities along paths between posterior states.

### 8. Why did the mode-adaptive rule disappoint?

I see no indication of an algebraic error in the Lambert-\(W\) mode and curvature derivation. The problem is the shape of the integrand.

For large \(\sigma_\alpha\),

\[
\exp\{-\exp(a+\sigma_\alpha z)\}
\]

approaches a softened step function: approximately one to the left of \(z=-a/\sigma_\alpha\) and zero to its right. Multiplication by the standard-normal density produces a broad, truncated-normal-like left side and a sharp right cutoff. It is not well represented by a symmetric local Gaussian centred at its mode. Mode and curvature adaptation can therefore concentrate nodes around the local peak while undersampling the broad side containing appreciable mass. Increasing the adaptive order helps, as your results show, but it does not fundamentally remove the mismatch.

Lambert-\(W\)-based approximations to the lognormal Laplace transform are well motivated and have useful asymptotic properties, but those results are asymptotic rather than guarantees of uniform accuracy over your full \((\log B,\sigma_\alpha)\) rectangle.

### 9. Which integrator should be used?

My ranking is:

**First: exposure-reduced fixed Gauss–Hermite.** It is deterministic, smooth under automatic differentiation, cheap to test and easy to maintain. The nodes and weights do not change during HMC. Order 256 appears decision-scale adequate over the present region. Order 512 buys roughly two orders of magnitude in function accuracy and one to two orders in derivative accuracy in the difficult corner. I would predeclare 512 as the sole fallback if 256 fails the expanded-domain or gradient gate. I would not continue testing 384, 768, 1024 and so forth after seeing outcomes.

**Second: Stan’s `integrate_1d`, as an oracle and possible fallback.** Stan’s one-dimensional integrator uses adaptive double-exponential quadrature and propagates gradients using the Leibniz rule and automatic differentiation. It is consequently a principled reference implementation, although its variable internal work may be substantially more expensive inside every HMC gradient evaluation.

**Not yet: saddlepoint/Laplace approximations or a surrogate.** A saddlepoint-style approximation would require a correction or a separate validated region because its accuracy will vary with both \(a\) and \(\sigma_\alpha\). A two-dimensional Chebyshev or spline surrogate is technically feasible, but introduces interpolation, derivative, boundary and extrapolation certification. That is too much specialised infrastructure for a model whose ecological assumptions are not yet validated.

## The prospective numerical gate I would use

I would authorise one new versioned experiment with the following contract.

### Algebraic identity

The exposure-reduced and row-wise zero-history calculations must continue to agree within \(10^{-12}\) on deterministic fixtures.

### Protected domain

Define the domain before fitting using the current posterior envelope, an expanded buffer and prior-predictive tail limits. Do not define it merely as the exact minimum and maximum among the 750 rows. Search for maxima numerically over this domain rather than relying only on a regular grid, then audit every posterior draw from the eventual fits.

### Target-value gate

Require

\[
\sup U\left|\Delta\log m_0\right|
\le5\times10^{-4}.
\]

For \(U\le29\), this allocates at most about 0.015 species of worst-case mean-richness error—roughly 6% of the original 0.25-species equivalence margin—and less than \(10^{-3}\) PMF TV. This is stringent, inferentially interpretable and several orders less arbitrary than \(10^{-8}\) on the component integral.

### Gradient gate

Compare exact-reference and fixed-rule gradients for \(a\), \(\sigma_\alpha\), \(\mu_\alpha\), camera effects and the unconstrained scale parameter. Require the componentwise discrepancy over a one-posterior-SD displacement to be below \(10^{-2}\), with an RMS target substantially smaller, and inspect directional finite differences along paths through the difficult high-\(\sigma_\alpha\) region.

### Posterior-correction gate

At every retained draw, calculate

\[
\Delta_s
=
U\left[
\log\{1-\omega_s+\omega_s m_{0,\mathrm{ref},s}\}
-
\log\{1-\omega_s+\omega_s m_{0,\mathrm{GH},s}\}
\right].
\]

Use these as exact-reference importance corrections. The reweighted and unweighted richness PMFs should differ by no more than 0.005 TV and 0.025 species in posterior mean—10% of the eventual equivalence budgets. With errors of the scale presently observed, the weights should be virtually constant.

### Order selection

Run a stand-alone log-density-and-gradient benchmark for reduced orders 256 and 512 before any paired fits. Select 256 if it passes every numerical gate with a satisfactory margin; select 512 only if 256 fails or sits too close to the expanded-domain boundary. Then freeze the choice.

This remains a bounded numerical repair. It is not Path C in disguise.

## Computational comparison

### 10. Raw primary runtime is not the right principal metric

It should still be reported, but the more meaningful metric is

\[
\text{ESS per second}
\]

for \(\omega\), \(\mu_\alpha\), \(\sigma_\alpha\), \(\sigma_{\mathrm{camera}}\), \(q_{\mathrm{unseen}}\), expected richness and selected PMF probabilities; together with the number of log-density/gradient evaluations per second and the total wall-clock cost of obtaining one terminal-clean fit under the fixed primary/rescue policy.

A fast primary fit that fails and requires rescue is not cheaper in the operational sense. Conversely, ESS per second alone is insufficient because it can hide large fixed costs and failures. I would therefore retain a wall-clock ceiling, but apply it to cost-to-clean alongside ESS per second.

### 11. Is the 3.379 runtime ratio provisional?

Strongly yes. The present implementation has complexity approximately

\[
O(N_qG_0)
\]

for the integrated zero history, where \(G_0\) is the number of grouped zero-history rows. Exposure reduction changes this to approximately

\[
O(G_0+N_q).
\]

Thus even doubling the quadrature order from 128 to 256 can reduce the dominant zero-tail arithmetic dramatically. The old ratio measures a particular inefficient implementation, not the intrinsic price of marginalisation.

The revised runtime result could still be disappointing because automatic differentiation through hundreds of exponentials has a cost. But that must be measured; it cannot be inferred from the order-128 row-wise benchmark.

### 12. Does one additional clean stress case justify another attempt?

In isolation, a change from five of six to six of six terminal-clean fits would be weak evidence. In this case, however, the historical failure was the exact pathology the collapse was designed to remove, and it became clean on the collapsed primary fit. That provides a mechanistic link between intervention and result. The collapsed model also preserved all 53 shared-parameter comparisons.

Combined with the obvious removable runtime inefficiency and the very small decision-scale numerical errors, this justifies one further attempt. It does not justify a sequence of new integrators if that attempt fails.

## Posterior fidelity and Monte Carlo error

### 13. Equivalence criteria should incorporate MC uncertainty

Yes. A hard rule such as

\[
|\hat\mu_1-\hat\mu_2|\le0.25
\]

will falsely reject equivalent targets with non-negligible probability whenever the Monte Carlo standard error is appreciable. The criterion should instead require a one-sided confidence bound for the absolute difference to lie within the equivalence margin. Under such a rule, the existing `standard-short-low` result would be **inconclusive**, not equivalent and not materially different. Its estimated difference is slightly outside the margin, but its uncertainty is too large to establish either proposition.

For the integer PMF, I would use the Rao–Blackwellised per-draw conditional PMFs and estimate uncertainty using multivariate batch means or a chain-respecting block bootstrap. For every resample, calculate

\[
\mathrm{TV}(p_1,p_2)
=\frac12\sum_s|p_1(s)-p_2(s)|
\]

and the one-Wasserstein distance

\[
W_1(p_1,p_2)
=\sum_s|F_1(s)-F_2(s)|.
\]

TV measures shape disagreement, while \(W_1\) is expressed directly in species units and bounds the difference in posterior means. I would require the 95% upper confidence bounds, rather than only the point estimates, to remain below the prespecified margins. Within-method split-chain or batch comparisons should also be reported to show the Monte Carlo “noise floor” for TV and \(W_1\).

The experiment must be run long enough to have a reasonable chance of proving equivalence. Using the current combined MCSE of about 0.17 in the difficult case, it could not do so at a 0.25-species margin even if the true difference were zero. Merely rerunning the same chain lengths would recreate that ambiguity.

### 14. Which path should be chosen?

My decision is

\[
\boxed{\text{B now, followed by D before empirical application.}}
\]

Path C is unwarranted unless the reduced fixed rules fail despite the ecological model surviving its own validation. Path A becomes appropriate if the bounded fixed-rule attempt fails either the decision-scale numerical gate or the clean-sample efficiency gate.

The single missing result most likely to change this recommendation is **the clean ESS-per-second and cost-to-terminal-clean performance of the exposure-reduced fixed rule after it has passed a full-target value-and-gradient reference audit**. Numerical adequacy already looks likely. Computational value remains genuinely uncertain.

### 15. When should the collapse be abandoned?

I would close the computational repair if any one of the following occurs in the new, frozen experiment:

- The reduced order-256 rule and its sole order-512 fallback cannot satisfy the target, gradient and posterior-correction gates over the protected region.
- The reduced implementation still exceeds the agreed cost-to-clean ceiling without compensating ESS-per-second or reliability gains.
- The stress-case improvement disappears under adequately long fitting.
- Achieving acceptability would require a surrogate, bespoke saddlepoint correction or continuing sequence of quadrature orders.

I would also stop investing in this particular collapse if the subsequent ecological analysis shows that the common exchangeable positive-rate hierarchy is not a defensible approximation. Candidate-specific or stratum-specific marginalisation may still be worthwhile, but that would be a new model goal rather than further repair of Goal 002R.

# Bottom line

The formal `REJECT` was methodologically proper, but it rejected an implementation against an excessively fine component-level tolerance and a confounded runtime threshold. It did not show that the marginalisation was scientifically or statistically unsound.

The collapse is exact under its stated exchangeability contract. Fixed order 256 appears accurate enough at the scale of posterior inference, including first derivatives, while order 512 offers a comfortable numerical reserve. The narrow PMF failure is not plausibly explained by the observed quadrature errors and should be handled prospectively through Monte Carlo-aware equivalence testing. The old runtime ratio should be regarded as obsolete once the exposure reduction is implemented.

I would therefore authorise one final, prospectively specified Goal 002R revision using the reduced fixed rule, decision-scale value and gradient gates, exact-reference posterior corrections, MC-aware PMF equivalence and clean ESS-per-second benchmarking. If that bounded experiment fails, close the repair without proceeding to a specialised integration-development programme.
