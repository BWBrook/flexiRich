# Goal005 Task 4 — calibration-transfer decision

Date: 2026-08-24
Decision: **UNBIASED_REPLICATION_FAIL**

## Evidence and integrity

The frozen Task 4 stress ran on `deep-server` at Git commit
`63615dadc4bed532fa48d816e6f623704721cfa6`. It generated all 36 scheduled
synthetic datasets and completed all 108 scheduled Stan fits. The preserved
`tmux` pane exited with code zero, both completion records state
`TASK4_COMPLETE`, and no execution-stop record exists.

The canonical remote output remains at:

`/home/bwbrook/papers/flexiRich/outputs/goal005/task4-transfer-stress-v1`

The 25 compact artifacts and run log were copied to the corresponding ignored
local output path and match their remote counterparts byte for byte. All 64
recorded source-file hashes match the frozen checkout. No Judbury detections,
future species discoveries, Huon Ridge data, or unpublished coordinates were
used.

An independent implementation replayed all 51 profile rows and six paired-
shift rows exactly. Every metric, denominator, threshold, pass/fail value, and
the final decision matched. Its completion record states `AUDIT_PASS`. The
load-bearing SHA-256 hashes are:

- profile gates: `2e04b2b62e2854782ebe436eb8fa4a892e216b54ef2670693937b9a2221b1bd5`;
- paired-shift gates: `8b1f1a29a883b096821e1ead64302f4a2c19bc36b56352a55010086b23056bd0`;
- compact calibration pairs: `e6ff4bad7046b317c1c99bc7711705f3ffd340d05468b0b673e3fc5c5cec995e`.

## Frozen result

The fresh unbiased 12-week/F3 profile passed 13 of 17 rows. All 36 fits were
terminal clean, with no divergences or maximum-treedepth hits, so the failure
is scientific rather than computational.

| Failed unbiased criterion | Observed | Required |
| --- | ---: | ---: |
| Median high-minus-low separation | 26.241 species | at least 27 |
| Absolute median signed bias, richness 25 | 4.012 species | at most 3 |
| Fixed-denominator 90% coverage, richness 25 | 8/12 | at least 10/12 |
| Catastrophic-error or non-clean fits | 3/36 | fewer than 2/36 |

The three catastrophic unbiased errors were two richness-10 overestimates and
one richness-25 overestimate, with absolute posterior-mean errors of 12.84,
13.30, and 15.79 species. They occurred in blocks with 125, 557, and 308
active camera-days, respectively. Low realised effort contributes to risk but
does not explain the failure away. Across all unbiased fits, median absolute
error was 3.86 species and the maximum was 15.79, compared with 2.95 and 8.62
at the Task 3 F3 cell.

The biased profiles did not rescue the unchanged profile-level standard:

| Profile | Clean fits | Profile rows passed | Median absolute error | Maximum absolute error |
| --- | ---: | ---: | ---: | ---: |
| Unbiased | 36/36 | 13/17 | 3.86 | 15.79 |
| Median rates multiplied by 0.8 | 35/36 | 11/17 | 4.44 | 16.38 |
| Median rates multiplied by 1.25 | 35/36 | 15/17 | 3.18 | 15.07 |

Both non-clean biased fits narrowly exceeded the frozen R-hat limit and had
no divergent or maximum-treedepth behaviour.

All six direct transfer-shift rows nevertheless passed. Relative to the same
dataset under unbiased calibration, multiplying both class medians by 0.8
shifted posterior mean richness by a median 0.83 species and a maximum 3.36;
multiplying them by 1.25 produced shifts of 0.78 and 1.73. These are well
inside the frozen median and maximum limits of 3.5 and 8 species.

## Interpretation

The prespecified outcome is `UNBIASED_REPLICATION_FAIL`: the selected Task 3
cell did not reproduce the common standard on a fresh simulation and
calibration stream. The result cannot be reclassified as transfer sensitivity
because the unbiased baseline failed first.

The imposed 25% common location bias was not the dominant instability. Its
paired effects were modest. Instead, the combination of F3 calibration
uncertainty and ordinary variation among 12-week detection histories still
produced severe overestimates. Task 3's clean F3 pass was thus a real
conditional success, but not a reproducible operational frontier.

No threshold, calibration factor, duration, or sampler rule is changed after
this result. Task 4 is complete and closes the selected 12-week/F3 cell to an
unqualified `FRONTIER_FOUND` claim.
