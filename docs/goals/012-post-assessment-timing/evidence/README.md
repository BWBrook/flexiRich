# Goal012 retained evidence

`goal012-timing-evidence.tar.gz` contains 41 files (797,214 compressed bytes):
the interrupted v1 diagnostics and original executed script, the successful
v2 outputs and run log, and the summary figure with its source receipts.
Every archived file was compared byte-for-byte with the local original.

SHA-256:

```text
e37a387db8ea3fb73fc0f15894c420f5d46b5ef687d83a1530a3d6a9512038e7
```

Restore from the repository root into a checkout without these output paths:

```bash
tar --keep-old-files -xzf docs/goals/012-post-assessment-timing/evidence/goal012-timing-evidence.tar.gz
```

Use `outputs/goal012/timing-v2/` for accepted numerical evidence and
`outputs/goal012/synthesis-v1/conditional-timing.png` for the compact comparison.
Run v1 is explicitly interrupted and excluded from the decision.

V2 retains all 7,996 conditional randomisations in
`conditional-replicates.rds`, exact means, finite-tail counts and Monte Carlo
intervals, all species summaries, movement/effort/calendar tables, stratum
information, block-phase checks and figures. Its output receipt covers all
generated files except the receipt itself; input and code receipts identify
the sources. The parent and independent reviewer verified these receipts.

The 68,850-cell source panel is reconstructed from existing Goal008/011
archives and the committed configuration, rather than duplicated here. Exact
reproduction is described in [the runbook](../Runbook.md). The source base
was `9f17d48` with local Goal012 additions recorded by code hashes; no claim is
made that the new analysis was already committed at that earlier HEAD.

This evidence is explicitly post-assessment Judbury model criticism. It does
not replace the sealed Goal011 predictions or establish external validation.
