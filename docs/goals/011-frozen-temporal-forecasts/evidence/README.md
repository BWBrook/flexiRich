# Frozen Goal011 predictions

`goal011-frozen-predictions.tar.gz` preserves every generated forecast file,
including all six complete RDS objects with joint per-draw probabilities, the
species/count tables, seeded nested paths, input/output receipts, metadata,
completion status, log and exit marker. There are 32 files within the run
directory and two adjacent log/exit files. Archive SHA-256:

```
13f1482a7e926606d20197ca1d5bf127b172d0f5bd6547c583d6a2c8c8bb2ae2
```

Generation used frozen source `033c21ac13bb830d34e31d40698e5f6a0b4dda6d` at
`/data/codex/repos/flexirich-goal011-20260919`, tmux session
`flexirich-g011-forecast-v1`, output `outputs/goal011/forecast-v1/`.
It completed on 19 September 2026 with exit 0. All six profiles are
`predictions_complete_unscored`. The three 4,000-draw and three 6,000-draw
objects retain every draw from their clean parent fits.

On 23 September all 31 receipt-listed file hashes matched after transfer, and
the exact file set matched the receipt plus the receipt file itself. Full
scientific checks and outcome-access clearance are in `../PredictionAudit.md`.
This archive was created before any new later-observation access or scoring.

Restore into a fresh checkout from the repository root:

```bash
tar --keep-old-files -xzf docs/goals/011-frozen-temporal-forecasts/evidence/goal011-frozen-predictions.tar.gz
```

These complete predictive objects suffice for scoring without refitting or
regenerating forecasts. Recreating the parent posterior draws still requires
the separately preserved Goal009/010 run artifacts or new fitting runs.
