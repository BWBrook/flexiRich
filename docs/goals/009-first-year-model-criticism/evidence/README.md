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
preserved draws. See ../PostprocessingRepair.md and the forthcoming Decision.
The original deep-server checkout remains untouched.
