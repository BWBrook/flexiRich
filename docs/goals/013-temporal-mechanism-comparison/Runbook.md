# Goal013 runbook

Run from the repository root with its existing renv library. No new packages
or Stan toolchain are required; Rcpp builds the small numerical kernel.

```bash
make test-goal013 goal013-check
bash -n scripts/run_goal013_tmux.sh
shellcheck scripts/run_goal013_tmux.sh
```

The committed `config/goal013_design.rds`, `goal013_calibration.rds`, run manifest
and input receipts are sufficient to run recovery without the original compact
data archives. The builders are also retained for reproduction: first restore
Goal008/011/012 archived compact outputs, verify their receipts, then run
`scripts/build_goal013_design.R` and `scripts/calibrate_goal013_design.R` into
new paths. Both refuse to replace their primary frozen RDS inputs. Changing
calibration requires a new committed run and new receipts.

A single two-species, two-station local smoke job checks integration; it is not used as
recovery evidence. The production run comprises 500 independently seeded
datasets, four fitted candidates and two forecast origins, with at most eight
workers and single-threaded numerical libraries.

- Host: `deep-server-ts`.
- Session: `flexirich-g013-recovery-v1`.
- Working directory: `/data/codex/repos/flexirich-goal013-20261005`.
- Results: `outputs/goal013/recovery-v1/` beneath that directory.
- Log and exit marker: `outputs/goal013/recovery-v1.log` and `.exitcode`.

The isolated checkout must contain the exact frozen commit. Use a Git bundle
for local unpublished commits and the existing remote shared renv library;
do not update another running checkout or restore/install packages implicitly.
Check hashes and tests before launching. The launcher refuses existing run
artifacts and requires deep-server plus tmux.

```bash
ssh deep-server-ts 'tmux new-session -d -s flexirich-g013-recovery-v1 -c /data/codex/repos/flexirich-goal013-20261005 "bash scripts/run_goal013_tmux.sh"'
```

Status commands are identical from **WSL Ubuntu bash and macOS bash**:

```bash
ssh deep-server-ts 'cat /data/codex/repos/flexirich-goal013-20261005/outputs/goal013/recovery-v1/STATUS.txt'
ssh deep-server-ts 'tail -n 25 /data/codex/repos/flexirich-goal013-20261005/outputs/goal013/recovery-v1.log'
ssh deep-server-ts 'test ! -f /data/codex/repos/flexirich-goal013-20261005/outputs/goal013/recovery-v1.exitcode || cat /data/codex/repos/flexirich-goal013-20261005/outputs/goal013/recovery-v1.exitcode'
ssh deep-server-ts 'tmux has-session -t flexirich-g013-recovery-v1'
```

During execution, a job subdirectory's `scores.csv` records each completed
candidate, and `STATUS.txt` distinguishes running, complete and failed jobs.
The session normally disappears when the launcher exits; its absence alone
does not establish success. Read the exit marker and result status.

After completion, copy the complete output without overwriting local results,
verify `output-sha256.csv`, inspect numerical failures and boundary fits, then
adjudicate recovery, proper scores, count calibration and diagnostic support
against Goal.md. A complete run is not a supported biological interpretation.
Any repair preserves the original artifacts and uses a new committed identity.

## Completed assessment

The run finished with exit 0; all 500 datasets are complete, with two retained
numerical flags among 4,000 fits. The completed scientific assessment is in
[Decision.md](Decision.md). The session has ended; the status commands above
remain the exact commands for both WSL Ubuntu and macOS bash.

The complete production artifacts are now also local at
`outputs/goal013/recovery-v1/`. Run the bounded postprocessor from the repository
root to verify their hashes and reconstruct the assessment into a **new** path:

```bash
Rscript scripts/assess_goal013_results.R outputs/goal013/recovery-v1 outputs/goal013/assessment-replay
```

It refuses an existing destination, runs no fits, and reads no new field data.
It verifies event outcomes/cohorts against saved simulated panels, reconstructs
the count scores and model selections, reports complete parameter bounds, and
generates the diagnostic figure. The 9 October assessment is preserved under
`evidence/assessment-v1/` with a manifest. Numeric tables can be compared
directly; rendered PDF bytes may differ because of embedded creation metadata.
