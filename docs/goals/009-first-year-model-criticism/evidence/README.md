# Preserved Goal009 evidence

`first-year-v1-original.tar.gz` contains the complete frozen remote run,
including all eight sampler chain CSVs, saved prediction draws, original
predictive summaries and figures, run log and exit marker. The predictive
summaries contain the documented effort-indexing defect; preserve them as
execution evidence, not scientific results.

Archive SHA-256:
`624eafe0aa53ffcd379c56428e9a2c83a9217de828f233ff91a9ade68cd7f5e4`.

All 51 copied files matched SHA-256 receipts computed on deep-server.
Recovery from the repository root, without replacing existing files:

```bash
tar --keep-old-files -xzf docs/goals/009-first-year-model-criticism/evidence/first-year-v1-original.tar.gz
sha256sum -c docs/goals/009-first-year-model-criticism/evidence/first-year-v1-sha256.txt
```

The separate original postprocessing replay reproduced all 20 numerical CSV
outputs exactly and captured 104,000 effort-sweep warnings. Its comparison
and log are retained here. `replay-original-postprocessing.R` deliberately
loads functions from the original frozen Git commit and reproduces that
old defect into a new directory, without sampling or raw-data access.
It is diagnostic evidence, not the corrected scientific workflow.

Use `scripts/reprocess_goal009_ppc.R` for corrected predictive checks from
preserved draws. See ../PostprocessingRepair.md and ../Decision.md.
The original deep-server checkout remains untouched.

## Corrected scientific evidence

`corrected-criticism-v2.tar.gz` preserves the corrected predictive tables and
draw statistics, the separate conditional timing permutations, and the synthesis
tables and figure. SHA-256:
`e092eab1478e0d0e1022bc968d4966966610fdb0ee3bbaec23b624a8353d66df`.

Restore, without replacing existing files:

```bash
tar --keep-old-files -xzf docs/goals/009-first-year-model-criticism/evidence/corrected-criticism-v2.tar.gz
```

Both archives were checked member by member against local preserved files.
The corrected output records repair commit `e24e997` and the original fit commit
`e183888`. The exploratory timing diagnostic records its pre-commit Git HEAD
and exact source hashes; it must not be relabelled prospectively frozen.

To regenerate rather than restore (choose fresh destinations when existing
outputs are present):

```bash
Rscript scripts/reprocess_goal009_ppc.R
Rscript scripts/check_goal009_conditional_timing.R
Rscript scripts/summarise_goal009_results.R
make manuscript-check manuscript
```

The first command requires a clean committed checkout. The synthesis script
reads the documented default output directories and may regenerate its derived
figure and tables. It does not fit a model or open additional empirical data.
