# Goal005 Task 4 — bounded calibration-transfer stress

Status: frozen for implementation
Prepared: 2026-08-21

## Decision question

Does the selected 12-week/F3 class-calibration frontier remain acceptable when
an otherwise valid external calibration is transferred with a modest common
location bias?

Task 4 is a single-cell guardrail, not a second frontier search. The selected
cell and all scientific thresholds were fixed before Task 3 outcomes. No
duration, precision, bias magnitude, or decision rule will be retuned against
this stress.

## Selected cell

Task 3 selected the smallest passing duration and its coarsest passing finite
precision:

- deployment: 12 seven-day occasions;
- external 95% multiplicative factor: F3;
- calibration SD: `log(3) / qnorm(0.975) = 0.560526773621262`;
- common transfer-bias magnitude: `log(1.25) = 0.223143551314210`.

The selected precision is conservative because the 12-week/F5 failure was
sampler-driven. Task 4 nevertheless follows the frozen prefix decision rather
than reopening Task 3.

## Calibration profiles

For replicate \(r\) and encounter class \(h\), independent calibration first
generates

\[
\widehat m_{hr}^{(0)} = m_h^{\mathrm{true}} + \tau z_{hr},
\qquad z_{hr}\sim N(0,1).
\]

The same two standardised errors are then used in all three paired profiles:

| Profile | External class-location estimate | Median-rate interpretation |
| --- | --- | --- |
| `unbiased` | \(\widehat m_{hr}^{(0)}\) | no common transfer bias |
| `down_0.8` | \(\widehat m_{hr}^{(0)}-\log(1.25)\) | both medians multiplied by 0.8 |
| `up_1.25` | \(\widehat m_{hr}^{(0)}+\log(1.25)\) | both medians multiplied by 1.25 |

All profiles retain the same F3 uncertainty and biological between-species SD
of one. The target model receives only the profile-specific external class
locations and their declared uncertainty. It never receives the true class
locations, candidate rates, membership, or richness.

## Fresh paired evidence

Task 4 uses three richness scenarios, twelve effort-only start blocks, and one
12-week prefix: 36 fresh synthetic datasets. Each dataset is fitted under all
three calibration profiles, giving 108 fits.

Within a replicate, membership, candidate rates, camera effects, effort,
detection uniforms, and the two independent calibration errors are common
across profiles. Thus each biased-unbiased contrast isolates the imposed
transfer shift. The data are fresh relative to Tasks 2 and 3.

The frozen seeds are:

- ecological/detection stream: `680000000 + replicate`;
- external-calibration stream: `690000000 + replicate`;
- fit stream: `780000000 + 1000000 * profile_code +
  10000 * scenario_order + 1200 + replicate`.

`profile_code` is 1 for `unbiased`, 2 for `down_0.8`, and 3 for `up_1.25`;
`scenario_order` is 1--3 for richness 10, 25, and 40. All streams use R's
`Mersenne-Twister`, `Inversion`, and `Rejection` RNG kinds.

## Frozen gates

Each profile independently faces the unchanged 17-row Goal005 standard at 12
weeks. This yields 51 profile-level rows. A profile passes only if all 17 rows
pass; no threshold is relaxed for the stress.

Each biased profile also faces three paired rows relative to `unbiased`:

1. at least 35 of 36 dataset pairs have terminal-clean fits, available
   predictions, and finite posterior means;
2. median absolute paired posterior-mean richness shift is at most 3.5
   species; and
3. maximum absolute paired shift is at most 8 species.

This yields six paired rows and 57 decision rows in total. The completeness
row prevents missing or non-clean fits from making the shift distribution look
artificially stable.

## Decision rule

Provided the evidence-integrity contract passes:

- `TRANSFER_ROBUST` — all 51 profile rows and all six paired rows pass;
- `UNBIASED_REPLICATION_FAIL` — the fresh unbiased profile fails at least one
  of its 17 rows, so the selected Task 3 cell is not stable on new streams;
- `TRANSFER_SENSITIVE` — the unbiased profile passes, but at least one biased
  profile or paired-shift row fails.

Execution or evidence-integrity failure is reported separately and cannot be
converted into either scientific outcome.

At Task 5, `TRANSFER_ROBUST` supports the Goal005 decision `FRONTIER_FOUND`.
`TRANSFER_SENSITIVE` yields `CONDITIONAL_FRONTIER_ONLY`: the 12-week/F3 result
remains valid under unbiased calibration but is not sufficiently portable
under the prespecified transfer error. `UNBIASED_REPLICATION_FAIL` also blocks
`FRONTIER_FOUND`, but is reported separately because it questions replication
of the selected baseline rather than transfer robustness.

## Implementation and evidence boundary

Implementation should reuse the Task 3 model, adapter, simulation, scoring,
sampler, and publication machinery. New code is limited to:

- the 36-dataset/108-fit manifest and paired calibration generator;
- the three-profile executor;
- the 51 profile gates, six paired-shift rows, and final decision;
- an independent compact-evidence replay; and
- focused tests for common random numbers, exact bias shifts, truth isolation,
  manifest completeness, pairing, and decision logic.

One reduced local smoke should fit the three profiles for one dataset before
the frozen heavy run. The 108-fit batch runs on `deep-server` only from a clean
pushed commit. Raw sampler artifacts remain remote; compact evidence is copied
and independently replayed locally. Judbury detections and Huon Ridge remain
protected throughout.
