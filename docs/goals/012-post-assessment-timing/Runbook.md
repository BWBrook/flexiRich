# Goal012 local timing diagnostics

This is small, single-process processing of retained Judbury weekly tables.
It requires the project's existing renv environment, no new fit and no remote
compute. From the repository root:

```bash
make test-goal012
Rscript scripts/diagnose_goal012_timing.R outputs/goal012/timing-replay
Rscript scripts/plot_goal012_summary.R outputs/goal012/timing-replay outputs/goal012/synthesis-replay
```

The destination must not exist. Inputs are hash-checked against the committed
Goal011 manifest and assessment output receipt. The copied deployment ledger
has its original bytes and a fixed SHA-256 check. The runner reconciles the
full effort grid and all 200 Goal011 candidate-horizon outcomes before doing
any conditional calculations.

In a fresh checkout, restore the existing source tables first. These commands
refuse to overwrite files, so use them only when those outputs are absent:

```bash
tar --keep-old-files -xzf docs/goals/008-ecological-information/evidence/goal008-final-outputs.tar.gz
tar --keep-old-files -xzf docs/goals/011-frozen-temporal-forecasts/evidence/goal011-assessment-results.tar.gz
```

Completed Goal012 results use `outputs/goal012/timing-v2/`. The initial v1 was
interrupted during the controls when independent review identified that an
optional shifted-block summary retained the original within-block pair mask.
Its partial outputs, executed script and log remain preserved. The repair
calculates each phase's own observed count and expectation on the corresponding
mask; it changes no source data, primary statistic, main control or seed.

The output contract is descriptive species/station/season tables, effort and
movement tables, four conditional summaries and their simulation draws,
stratum support, exact block-phase means, figures, input/code/output hashes,
session information and a completion marker. `species-timing.png` is the
array-level overview. `station-timing.pdf` has one page per nominal station;
zero effort and sampled nondetection have different colours. Every date
derived from incidence has weekly precision.

The compact four-control figure is
`outputs/goal012/synthesis-v1/conditional-timing.png`. Completed outputs,
simulation draws and the interrupted attempt are preserved under
[evidence](evidence/README.md), with an archive hash and restore command.

## Previous remote job

The Goal011 forecast job was rechecked on 5 October 2026: completion marker
present and exit code 0. Its preserved remote outputs still describe the
generation stage as unscored; local Goal011 assessment-v3 contains the scores.

- Session: `flexirich-g011-forecast-v1` (completed; no session need remain).
- Working directory: `/data/codex/repos/flexirich-goal011-20260919`.
- Output: `outputs/goal011/forecast-v1/` within that directory.

The following commands work identically in WSL Ubuntu bash and macOS bash:

```bash
ssh deep-server-ts 'cd /data/codex/repos/flexirich-goal011-20260919 && cat outputs/goal011/forecast-v1/STATUS.txt outputs/goal011/forecast-v1.exitcode'
ssh deep-server-ts 'tail -n 25 /data/codex/repos/flexirich-goal011-20260919/outputs/goal011/forecast-v1.log'
```

Do not relaunch that command into the completed directory. New empirical
fitting would require a separate committed run, metadata and tmux session.
