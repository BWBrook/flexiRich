# Goal010 preserved evidence

`goal010-compact-results.tar.gz` contains 160 files: all compact run summaries,
inputs, metadata, attempt diagnostics, bridge errors and chain diagnostic plots;
the completion log/exit marker; numerical audit tables; and comparison synthesis
CSVs and figures. SHA-256:

```
add18553b3fa3c10d292fc67fbb4f1ab011f832d1b3761b3a3d2536d5b3a4422
```

`remote-files.sha256` records all 197 original run files. Every file was copied
locally and independently matched to this remote receipt on 19 September 2026.
The full 1.2 GB run is retained (gitignored) locally and on deep-server at
`/data/codex/repos/flexirich-goal010-20260918/outputs/goal010/spatial-v1`.
The compact archive excludes primary/rescue chain CSV directories and the eight
large joint prediction-draw RDS files. It therefore preserves the interpreted
evidence and figure source tables, but is not a substitute for those full files
when regenerating forecasts or draw-based PPCs. Do not claim a compact-archive
restore alone replays all posterior calculations.

Restore into a fresh checkout from the repository root:

```bash
tar -tzf docs/goals/010-persistent-spatial-comparison/evidence/goal010-compact-results.tar.gz
tar --keep-old-files -xzf docs/goals/010-persistent-spatial-comparison/evidence/goal010-compact-results.tar.gz
```

Use the corrected Goal009 archive alongside this one for the preceding baseline
comparison. The frozen Goal010 fit source is bff200a; subsequent synthesis and
interpretation commits do not modify its run. The source, manifest and seed
contract permit a fresh computational replication, while original chain CSVs
and all attempts remain available for exact saved-output inspection.
