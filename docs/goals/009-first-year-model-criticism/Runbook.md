# Goal009 execution and monitoring

**18 September closeout:** the original run completed, but its PPC tables and
figures contain an effort-indexing defect. Use the corrected local
`outputs/goal009/ppc-repaired-v2` outputs and [Decision.md](Decision.md).
The original remote checkout and sampler outputs remain preserved.

Verified closeout: exit marker `0`, both fits clean, and tmux session
`flexirich-g009-firstyear-v1` no longer present. Its working directory remains
`/data/codex/repos/flexirich-goal009-20260917`; original outputs remain under
`outputs/goal009/first-year-v1/` there. Corrected outputs were generated locally
from copied draws; the remote completion marker does not certify the old PPCs.

The run uses the unchanged Goal003 full-candidate Stan model, the two rows of
`config/goal009_fits.csv`, and hash-verified first-year tables listed in
`config/goal009_inputs.csv`. Frozen source identity is recorded in each run's
`run-metadata.txt`. The runner refuses a dirty checkout and refuses empirical
fitting outside deep-server/tmux. Outputs cannot be overwritten.

Local checks:

```bash
make test-goal009 goal009-check
Rscript scripts/run_tests.R
```

First-year tables can be recovered in a fresh checkout from the committed
Goal008 evidence archive; see its README. They are the only detection inputs
needed. The current Goal009 R library uses the unchanged lockfile; the remote
isolated source clone reads the already synchronized library through a symlink
to `/home/bwbrook/papers/flexiRich/renv/library`. It must not install or alter
packages through that shared link. Runtime R and CmdStan versions are recorded.

## Remote execution

- Host: `deep-server-ts` (`deep-server`).
- Isolated checkout: `/data/codex/repos/flexirich-goal009-20260917`.
- Session: `flexirich-g009-firstyear-v1`.
- Output directory: `outputs/goal009/first-year-v1/` inside that checkout.
- Log: `outputs/goal009/first-year-v1.log`.
- Exit marker: `outputs/goal009/first-year-v1.exitcode`.

After transfer, source/input verification and a clean checkout, start once:

```bash
ssh deep-server-ts 'tmux new-session -d -s flexirich-g009-firstyear-v1 -c /data/codex/repos/flexirich-goal009-20260917 "bash scripts/run_goal009_tmux.sh"'
```

The following commands are identical in WSL Ubuntu bash and macOS bash, using
the configured `deep-server-ts` SSH alias:

```bash
ssh deep-server-ts 'tail -n 35 /data/codex/repos/flexirich-goal009-20260917/outputs/goal009/first-year-v1.log'
ssh deep-server-ts 'cat /data/codex/repos/flexirich-goal009-20260917/outputs/goal009/first-year-v1/STATUS.txt'
ssh deep-server-ts 'cat /data/codex/repos/flexirich-goal009-20260917/outputs/goal009/first-year-v1.exitcode'
ssh deep-server-ts 'tmux has-session -t flexirich-g009-firstyear-v1'
ssh -t deep-server-ts 'tmux attach -t flexirich-g009-firstyear-v1'
```

Detach an attached session with Ctrl-b then d. Before completion, the exit
marker is absent; after completion the tmux session normally disappears. Exit
zero means both fits are computationally clean and summaries were written, not
that the ecological model is adequate. Exit two means retained nonclean fits;
other nonzero values indicate execution errors. Inspect logs and attempt
diagnostics in all cases. A vanished session without an exit marker warrants
checking host reboot time, not assuming success.

## Output contract and next decision

Each fit retains primary/rescue chain CSVs, attempt diagnostics, parameter
summaries, canonical model data, joint prediction draws, latent richness PMF,
membership probabilities, replicated statistic draws, marginal predictive
summaries and diagnostic figures. Nonclean fits do not receive PPC summaries.
No later-outcome scoring or automatic model selection occurs in this run.

Review the two fits together, checking ecological failures and prior sensitivity.
Preserve negative results. Only then choose the next model comparison and freeze
the actual temporal predictions under `ForecastContract.md` before opening
later detections. Any repair to a running analysis is a new committed run.
