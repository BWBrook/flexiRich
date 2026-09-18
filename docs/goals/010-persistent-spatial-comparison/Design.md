# Goal010 model and comparison design

Frozen before fitting. The unchanged full-candidate membership mixture is
combined with log encounter hazard

`log h_ijt = log E_jt + alpha_i + b_j + u_ij`.

A detected species has membership one. An all-zero candidate retains the
absent/member mixture. Species identities, effort, unsampled cells, membership,
and all station effects persist throughout the observation window.

## Spatial parameterisation and estimand

Let Q be the existing J by J−1 orthonormal contrast basis. The shared camera
effect is `b = sigma_camera Q z_camera`, as in Goal009. Independently for each
species, `u_i = tau sqrt(J/(J−1)) Q z_i`, with standard-normal z_i. Each row sums
to zero and each station has marginal conditional SD tau. For J=1 set u=0.
Alpha is the equally weighted mean log encounter rate across this fixed array;
it is not an arithmetic average rate. The inherited sigma_camera is a contrast
coefficient SD; its marginal station SD is sigma_camera sqrt((J−1)/J), so it
is not on exactly the same scale as tau. Do not average exp(alpha) over this prior.

There is no hard column centring across candidates: adding an unobserved
candidate must not deterministically constrain the other rows. However,
exchangeable hierarchical borrowing remains. Detected species chiefly inform
tau, which is transferred to unseen species; the all-zero mixtures also feed
back through possible membership. Their realised individual station patterns
are not ecological evidence. All-zero species remain exchangeable here.

The likelihood identifies station log rates, not a unique b/u decomposition:
adding a sum-zero vector v to b and subtracting it from every u row leaves the
likelihood unchanged. Proper Gaussian priors regularise that decomposition.
Inspect b-versus-mean-observed-u posterior correlations, chain traces, and all
station-log-rate diagnostics. Do not claim that sum-zero constraints alone solve
identifiability.

This is a fixed-array parameterisation. It does not define an unchanged random
field as J changes. Same-station temporal predictions can reuse these effects;
new-camera or cross-reserve transfer requires a separate generative specification.

## Priors and controls

The original `primary` and `tail_wide` Goal003 rate/membership/camera priors remain
unchanged. Cross each with tau ~ HalfNormal(0,0.5) (primary) or HalfNormal(0,1)
(stress). The wider interaction scale permits substantial station contrasts.
The marginal arithmetic rate mean is infinite at the wider tau scale; inherited
rate-tail priors can already have this property. This is a proper prior with
bounded detection probabilities, not a reason to report unstable rate means.
Inspect quantiles and bounded detection/miss probabilities instead.

Use 2,000 prior draws per profile under the actual first-year effort, including
tau=0 reference profiles (six profiles total). A common random stream couples
membership and base effects across profiles. Outputs are bounded detection
probabilities, prior latent/detected richness, unseen members and proportions
nearly invisible/certain to be detected. These are prior consequences, not
posterior accuracy claims.

Two synthetic fixtures have eight candidates, four stations, 26 weeks and six
true members, with common alpha/b/membership/effort and common Bernoulli uniforms.
One has u=0; the other gives species 1 and 2 opposing log-rate offsets ±1.5 at
the first two stations. Other interaction entries are zero. This deliberately
fixed mechanism is not a random sample from the fitted Gaussian interaction
population. Fit both the baseline and primary spatial model to each. Retain
truth and prediction outputs, but do not estimate coverage from two examples.

## Frozen execution and evidence

`config/goal010_fits.csv` fixes all eight cases, sampler and predictive seeds,
and 1,000 joint predictive draws. `config/goal010_inputs.csv` hashes the manifest
and restricted input tables. Synthetic seed 7300401; prior seed 7300301.

The primary sampler inherits four chains, 1,000 warmup and 1,000 retained draws,
with adapt_delta raised to 0.95 and depth 12. The unchanged rescue policy has
1,500+1,500 iterations, adapt_delta 0.999, depth 15 and seed+1. Use inherited
Goal003 diagnostic thresholds. Monitor hyperparameters, alpha, b, u and station
log rates, not only richness. No PPCs for terminal nonclean fits.

Postprocessing warnings are fatal. Explicit base arrays avoid posterior matrix
subclass indexing; every joint component uses the same retained draw indices.
For clean fits compare 20 evenly spaced saved draws against the reference R
member likelihood/membership calculation, including nonzero interactions and
station-log-rate/centring identities. Fail rather than interpret discrepancies.
Compare with the corrected Goal009 PPCs (`ppc-repaired-v2`), never the superseded
original PPCs; original posterior fitting remains valid and is not repeated.
