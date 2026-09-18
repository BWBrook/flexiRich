# Goal010 execution

Source and design must be committed before the remote run. Record the actual
commit in `run-metadata.txt`. Never overwrite a run directory. Remote source is
an isolated checkout, using the existing synchronized renv library read-only;
do not install packages through that link.

Local verification:

```bash
make test-goal010 goal010-check
Rscript scripts/run_tests.R
bash -n scripts/run_goal010_tmux.sh
shellcheck scripts/run_goal010_tmux.sh
git diff --check
```

Restore required first-year inputs from the committed Goal008 evidence archive
with `tar --keep-old-files`, in a fresh checkout only. The runner checks input
SHA-256 receipts, clean Git, renv synchronization, host and TMUX before fitting.
Only deep-server does Stan compilation/fitting; 4 chains run concurrently and
fits run sequentially. Compilation uses two jobs and BLAS/OpenMP one thread.

- SSH alias: `deep-server-ts`, hostname `deep-server`.
- Checkout: `/data/codex/repos/flexirich-goal010-20260918`.
- Session: `flexirich-g010-spatial-v1`.
- Outputs: `outputs/goal010/spatial-v1/` within that checkout.
- Log and exit marker: `outputs/goal010/spatial-v1.log` and `.exitcode`.

Start once after transfer and verification:

```bash
ssh deep-server-ts 'tmux new-session -d -s flexirich-g010-spatial-v1 -c /data/codex/repos/flexirich-goal010-20260918 "bash scripts/run_goal010_tmux.sh"'
```

Status commands are identical for WSL Ubuntu bash and macOS bash:

```bash
ssh deep-server-ts 'cat /data/codex/repos/flexirich-goal010-20260918/outputs/goal010/spatial-v1/STATUS.txt; tail -n 25 /data/codex/repos/flexirich-goal010-20260918/outputs/goal010/spatial-v1.log'
ssh deep-server-ts 'cat /data/codex/repos/flexirich-goal010-20260918/outputs/goal010/spatial-v1.exitcode'
ssh deep-server-ts 'tmux has-session -t flexirich-g010-spatial-v1'
ssh -t deep-server-ts 'tmux attach -t flexirich-g010-spatial-v1'
```

Exit 0 means all fits computationally clean and postprocessing completed, not
that the model is adequate. Exit 2 retains terminal nonclean fits. Other errors
preserve partial outputs for diagnosis. The exit marker is absent while running;
tmux normally disappears after completion. Check reboot time if both are absent.

Each fit retains model inputs, chain CSVs, attempts/warnings, parameter summaries,
Stan/R bridge errors, joint prediction draws, membership probabilities, latent
richness PMF, complete PPC draws/tables, core correlations and trace/rank plots.
Spatial fits also retain camera/interaction decomposition correlations and
descriptive interaction-SD boundary mass. Controls retain their exact truth.
Global outputs contain the manifest, receipts, seed/runtime/source metadata,
prior draws and mathematical checks. Do not add later detection scoring here.
