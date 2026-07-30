# Goal 002 Prior-Predictive Decision

## Frozen evidence

This decision records the evidence available before any Goal 002 development
recovery fit.

- Source commit:
  `3755e844d2f9efcf05bf889e0dfcf6ef5782a1ef`
  (`Revise Goal 002 tail sensitivity prior`).
- Active pointer: `outputs/goal002/prior-predictive`.
- Active immutable output:
  `outputs/goal002/.prior-predictive-version-893ed2149d3608d8f62ce369c48337df46bbbc882e9cf86ba698307b1daf540d`.
- Active evidence ID and `prior-check-index.rds` SHA-256:
  `893ed2149d3608d8f62ce369c48337df46bbbc882e9cf86ba698307b1daf540d`.
- Retained historical v1 output:
  `outputs/goal002/.prior-predictive-version-c5becec0faad4739d51911a4638f6edd03377ff7373b1c40bedf44cd527ba20e`.
- Retained historical `prior-check-index.rds` SHA-256:
  `c5becec0faad4739d51911a4638f6edd03377ff7373b1c40bedf44cd527ba20e`.
- Evidence schema: `1.0.0`.

The retained output is immutable historical evidence for the one permitted
tail-prior revision. Its tail profile is `sensitivity-tail-v1`, with profile
SHA-256
`d09442db630ea83f746c07df5cddaae8fad0e87cb0cfbcb72aac51b83f55c63c`.
The active primary and membership artefacts are byte-identical to their
counterparts in the retained output.

### Current profile provenance

| Profile key | Profile ID | Profile SHA-256 | Omega prior | Mu-alpha location | Mu-alpha scale | Sigma-alpha scale | Sigma-camera scale |
|---|---|---|---|---:|---:|---:|---:|
| `primary` | `primary-v1` | `3487d833d09fbba5efcc6655cb247074ea41bd9a84808b5144d6b1748f872d31` | Beta(1, 1) | -6.90775527898214 | 2 | 1.5 | 0.75 |
| `sensitivity_membership` | `sensitivity-membership-v1` | `59fa870a4cde4649bf4f60f5471ecc0dcaa2045f465659b195726681a5fe37c3` | Beta(0.5, 0.5) | -6.90775527898214 | 2 | 1.5 | 0.75 |
| `sensitivity_tail` | `sensitivity-tail-v2` | `5c3ad4a168fff6322629e3d5f419be5c71ff62ce714c82de5208be9e4c8f4c94` | Beta(1, 1) | -6.90775527898214 | 2.5 | 1.75 | 0.75 |

### Effort and simulation provenance

- Effort seed: `62002001`.
- Effort SHA-256:
  `a34cb694a8bbc27c90e9eae3fcbe6bc1834a122b61d6b456b056d682d910ad73`.
- Design: 30 candidate species, 9 cameras, 208 weekly occasions, a
  26-occasion prefix, and 7 days per occasion.
- Draw count: 10,000 per profile, 30,000 in total.
- Profile simulation seeds:
  `primary=62002101`,
  `sensitivity_membership=62002201`, and
  `sensitivity_tail=62002301`.

### Fixed quantile evidence

The following table transcribes every value for all seven variables and all
nine fixed probabilities in the active immutable output. The values are the
literal CSV values, not recomputed summaries.

| Profile | Variable | q0 | q0.001 | q0.01 | q0.05 | q0.5 | q0.95 | q0.99 | q0.999 | q1 |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| primary | eta | -29.3118686318806 | -16.1085034135726 | -13.1678656064161 | -11.1132637275526 | -6.8712679984818 | -2.65878901417082 | -0.580028786569507 | 2.50575347312535 | 11.9603899158111 |
| primary | rate | 1.86216088037425e-13 | 1.00963839108415e-07 | 1.91103494542264e-06 | 1.49132015450559e-05 | 0.00103716111178064 | 0.070032979359791 | 0.559882249246815 | 12.2527876364393 | 156434.068993584 |
| primary | p1 | 1.86216088037408e-13 | 1.00963834011567e-07 | 1.91103311939652e-06 | 1.49130903438185e-05 | 0.00103662344609277 | 0.0676369293382541 | 0.428723671892704 | 0.999995228203104 | 1 |
| primary | p7 | 1.30351261626113e-12 | 7.06746624013393e-07 | 1.33771551430206e-05 | 0.000104386962117276 | 0.00723383671872432 | 0.387515017675897 | 0.980142544385381 | 1 | 1 |
| primary | richness | 0 | 0 | 0 | 1 | 15 | 29 | 30 | 30 | 30 |
| primary | observed_26 | 0 | 0 | 0 | 0 | 8 | 26 | 29 | 30 | 30 |
| primary | observed_208 | 0 | 0 | 0 | 1 | 13 | 28 | 30 | 30 | 30 |
| sensitivity_membership | eta | -25.4584842611774 | -16.3910082742882 | -13.2942137001687 | -11.1116704136617 | -6.93749121001228 | -2.69812646893805 | -0.615801174511119 | 2.59321631417505 | 12.3593035050537 |
| sensitivity_membership | rate | 8.78053074161484e-12 | 7.61159292308312e-08 | 1.68421041543581e-06 | 1.49369818959881e-05 | 0.000970701831940463 | 0.0673315423787675 | 0.540207921072777 | 13.3727133575168 | 233118.807273632 |
| sensitivity_membership | p1 | 8.78053074157629e-12 | 7.61159263340139e-08 | 1.68420899715425e-06 | 1.49368703398295e-05 | 0.000970230853322792 | 0.0651148041120744 | 0.417372900671812 | 0.999998442943449 | 1 |
| sensitivity_membership | p7 | 6.1463715189415e-11 | 5.32811362671794e-07 | 1.17894034124881e-05 | 0.000104553407183438 | 0.00677187960254674 | 0.37582268770085 | 0.977210501642255 | 1 | 1 |
| sensitivity_membership | richness | 0 | 0 | 0 | 0 | 15 | 30 | 30 | 30 | 30 |
| sensitivity_membership | observed_26 | 0 | 0 | 0 | 0 | 8 | 28 | 30 | 30 | 30 |
| sensitivity_membership | observed_208 | 0 | 0 | 0 | 0 | 13 | 30 | 30 | 30 | 30 |
| sensitivity_tail | eta | -35.2223923132765 | -17.7949717137512 | -14.4601688667447 | -11.9812957731712 | -6.89493384214408 | -1.80911608777475 | 0.574118725185936 | 4.04782496905367 | 16.0500505238354 |
| sensitivity_tail | rate | 5.04788414664688e-16 | 1.86957106996193e-08 | 5.24841845321927e-07 | 6.26021659780294e-06 | 0.00101290398387263 | 0.163798856645368 | 1.77556507643825 | 57.2727515177143 | 9342183.14041222 |
| sensitivity_tail | p1 | 5.04788414664688e-16 | 1.86957105248545e-08 | 5.2484170759247e-07 | 6.2601970026879e-06 | 0.00101239116979078 | 0.151087242131661 | 0.830612294550155 | 1 | 1 |
| sensitivity_tail | p7 | 3.53351890265281e-15 | 1.3086996633386e-07 | 3.67388616851717e-06 | 4.38205560360053e-05 | 0.00706525081555764 | 0.682282290530567 | 0.999995998957217 | 1 | 1 |
| sensitivity_tail | richness | 0 | 0 | 0 | 1 | 15 | 29 | 30 | 30 | 30 |
| sensitivity_tail | observed_26 | 0 | 0 | 0 | 0 | 8 | 26 | 29 | 30 | 30 |
| sensitivity_tail | observed_208 | 0 | 0 | 0 | 1 | 12 | 28 | 30 | 30 | 30 |

The lossless source tables and their SHA-256 values are:

| Profile | Immutable table | SHA-256 |
|---|---|---|
| `primary-v1` | `primary-quantiles.csv` | `6cdc8cf6c55e72cf28a7defe90c87ca9db729d8fda3b5e25a0ccb385e37e5872` |
| `sensitivity-membership-v1` | `sensitivity-membership-quantiles.csv` | `93aa6cebe426c13a45e8f0bb69ea48e9c9b0e7a8eeb512460f8787949304cb3f` |
| `sensitivity-tail-v2` | `sensitivity-tail-quantiles.csv` | `affbcf5fa28f33707092652e117a8c4ef0e460475d27f494ac818e14ed15faa1` |

Each table is relative to the active immutable output directory identified
above.

### Boundary and floating-point saturation evidence

| Profile | richness=0 | richness=30 | observed_26=0 | observed_26=richness | observed_208=0 | observed_208=richness |
|---|---:|---:|---:|---:|---:|---:|
| `primary-v1` | 0.0311 | 0.0317 | 0.0791 | 0.3247 | 0.0424 | 0.6304 |
| `sensitivity-membership-v1` | 0.0993 | 0.1014 | 0.1476 | 0.3691 | 0.1095 | 0.6505 |
| `sensitivity-tail-v2` | 0.0305 | 0.034 | 0.0999 | 0.3258 | 0.0471 | 0.5817 |

| Profile | p1=0 | p1=1 | p7=0 | p7=1 | detect_26=0 | detect_26=1 | detect_208=0 | detect_208=1 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `primary-v1` | 0 | 0.000415185185185185 | 0 | 0.00180111111111111 | 0 | 0.117116666666667 | 0 | 0.366586666666667 |
| `sensitivity-membership-v1` | 0 | 0.000471111111111111 | 0 | 0.00186666666666667 | 0 | 0.115726666666667 | 0 | 0.359113333333333 |
| `sensitivity-tail-v2` | 0 | 0.00139074074074074 | 0 | 0.0048562962962963 | 0 | 0.164386666666667 | 0 | 0.38701 |

For the tail revision specifically:

| Evidence | Retained `sensitivity-tail-v1` | Active `sensitivity-tail-v2` |
|---|---:|---:|
| Rate q0.99 | 16.3667424605308 | 1.77556507643825 |
| Rate q0.999 | 2575.07859271713 | 57.2727515177143 |
| Exact p1 floating-one frequency | 0.00683037037037037 | 0.00139074074074074 |
| Exact p7 floating-one frequency | 0.0171185185185185 | 0.0048562962962963 |
| 26-week detection floating-one frequency | 0.21716 | 0.164386666666667 |
| 208-week detection floating-one frequency | 0.409626666666667 | 0.38701 |
| Observed richness zero at 26 weeks | 0.1128 | 0.0999 |
| Observed richness equals latent richness at 26 weeks | 0.2993 | 0.3258 |
| Observed richness zero at 208 weeks | 0.0577 | 0.0471 |
| Observed richness equals latent richness at 208 weeks | 0.4988 | 0.5817 |

## Numerical decision

The seven automatic rules and their thresholds were unchanged between the
retained and active evidence. Every active profile passed every rule; no
threshold was changed during adjudication.

| Profile | Rule | Statistic | Comparison | Threshold | Result |
|---|---|---:|:---:|---:|---|
| `primary-v1` | `finite_draws` | 0 | <= | 0 | PASS |
| `primary-v1` | `nested_richness_bounds` | 0 | <= | 0 | PASS |
| `primary-v1` | `richness_pmf` | 0 | <= | 1e-12 | PASS |
| `primary-v1` | `max_observed_mass_26` | 0.0791 | < | 0.95 | PASS |
| `primary-v1` | `max_observed_mass_208` | 0.0429 | < | 0.95 | PASS |
| `primary-v1` | `min_partial_probability_26` | 0.663468960194068 | >= | 0.05 | PASS |
| `primary-v1` | `min_partial_probability_208` | 0.378211489690153 | >= | 0.05 | PASS |
| `sensitivity-membership-v1` | `finite_draws` | 0 | <= | 0 | PASS |
| `sensitivity-membership-v1` | `nested_richness_bounds` | 0 | <= | 0 | PASS |
| `sensitivity-membership-v1` | `richness_pmf` | 0 | <= | 1e-12 | PASS |
| `sensitivity-membership-v1` | `max_observed_mass_26` | 0.1476 | < | 0.95 | PASS |
| `sensitivity-membership-v1` | `max_observed_mass_208` | 0.1095 | < | 0.95 | PASS |
| `sensitivity-membership-v1` | `min_partial_probability_26` | 0.674421714132905 | >= | 0.05 | PASS |
| `sensitivity-membership-v1` | `min_partial_probability_208` | 0.388420911886616 | >= | 0.05 | PASS |
| `sensitivity-tail-v2` | `finite_draws` | 0 | <= | 0 | PASS |
| `sensitivity-tail-v2` | `nested_richness_bounds` | 0 | <= | 0 | PASS |
| `sensitivity-tail-v2` | `richness_pmf` | 0 | <= | 1e-12 | PASS |
| `sensitivity-tail-v2` | `max_observed_mass_26` | 0.0999 | < | 0.95 | PASS |
| `sensitivity-tail-v2` | `max_observed_mass_208` | 0.0471 | < | 0.95 | PASS |
| `sensitivity-tail-v2` | `min_partial_probability_26` | 0.642778146427781 | >= | 0.05 | PASS |
| `sensitivity-tail-v2` | `min_partial_probability_208` | 0.424795399247954 | >= | 0.05 | PASS |

The numerical decision is therefore `PASS` for all 21 profile-rule rows. Each
profile's automatic outcome is `not_rejected_automatically`, with no failed
rule. This numerical result is necessary but does not supply the ecological
judgement.

## Ecological judgement

- PI: Barry W. Brook.
- Current adjudication date: `2026-07-30 UTC`.
- Permitted verdict vocabulary:
  `accept_provisionally`, `revise_before_freeze`, or `reject`.

| Current profile | PI verdict | Verdict date | Frozen-summary rationale |
|---|---|---|---|
| `primary-v1` | `accept_provisionally` | 2026-07-28 UTC | All seven automatic rules passed. The frozen richness distribution spans 0 to 30 with median 15, while partial-observation probability remains 0.663468960194068 at 26 weeks and 0.378211489690153 at 208 weeks. |
| `sensitivity-membership-v1` | `accept_provisionally` | 2026-07-28 UTC | All seven automatic rules passed. The alternative membership prior increases richness-boundary mass (0.0993 at 0 and 0.1014 at 30) but remains non-degenerate, with median richness 15 and partial-observation probabilities 0.674421714132905 and 0.388420911886616. |
| `sensitivity-tail-v2` | `accept_provisionally` | 2026-07-30 UTC | All seven automatic rules passed. Relative to retained v1, the frozen 99.9% rate quantile fell from 2575.07859271713 to 57.2727515177143 and exact seven-day saturation fell from 0.0171185185185185 to 0.0048562962962963, while partial-observation probabilities remain 0.642778146427781 and 0.424795399247954. |

The `2026-07-30 UTC` verdict on `sensitivity-tail-v2` completes adjudication
of the current three-profile set. No verdict is inferred from an automatic
pass; each verdict above records the PI's explicit choice.

### Revision history and fit-order gate

| UTC date | Evidence or change | Explicit PI decision and consequence |
|---|---|---|
| 2026-07-28 | Retained evidence `c5becec0faad4739d51911a4638f6edd03377ff7373b1c40bedf44cd527ba20e` | `primary-v1` and `sensitivity-membership-v1` were `accept_provisionally`; `sensitivity-tail-v1` was `revise_before_freeze`. The tail verdict required the one permitted revision cycle and blocked development fitting. |
| 2026-07-28 | Tail revision committed as source commit `3755e844d2f9efcf05bf889e0dfcf6ef5782a1ef` | `sensitivity-tail-v1` was retained as historical evidence; `sensitivity-tail-v2` replaced it as the current tail profile. No development recovery output had been produced. |
| 2026-07-30 | Active evidence `893ed2149d3608d8f62ce369c48337df46bbbc882e9cf86ba698307b1daf540d` | `sensitivity-tail-v2` was `accept_provisionally`, completing the current three-profile decision. At the time of this record, `outputs/goal002/development` and `Development.md` did not exist. |

Thus every explicit PI verdict, including the required revision and
replacement verdict, precedes every Goal 002 development recovery fit.

## Interpretation boundary

Provisional acceptance applies only to the correctly specified synthetic
pilot represented by the frozen prior-predictive evidence above. It is not
empirical camera-trap validation.

In particular, the decision does not establish field-data fit, validate
species discovery or unseen-richness behaviour, demonstrate temporal or
spatial out-of-sample performance, approve sampler settings from development
fits, or authorise any frozen recovery result. Those claims require their
separate prespecified development, audit, empirical-validation, and freeze
gates.
