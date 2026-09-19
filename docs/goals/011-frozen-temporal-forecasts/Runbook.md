# Goal011 forecast generation and handoff

This run generates predictions only. It does not read later observations or
score the models. The actual predictive objects must be verified, archived and
committed, with independent audit clearance, before outcome access.

Local checks:

```bash
make test-goal011 goal011-check
bash -n scripts/run_goal011_tmux.sh
shellcheck scripts/run_goal011_tmux.sh
```

Remote host `deep-server-ts`; isolated checkout
`/data/codex/repos/flexirich-goal011-20260919`. The source is frozen in Git before
launch. Restore Goal008 restricted inputs from the committed evidence archive.
Copy the six hash-listed prediction-draw files and two parent fit-status tables
from the preserved Goal009/010 remote checkouts; never modify those runs. Use
the synchronized shared renv library without installation. Run the input check
in the fresh checkout before launching.

Session: `flexirich-g011-forecast-v1`.
Output directory: `outputs/goal011/forecast-v1/` within that checkout.
Log/exit marker: `outputs/goal011/forecast-v1.log` and `.exitcode`.

```bash
ssh deep-server-ts 'tmux new-session -d -s flexirich-g011-forecast-v1 -c /data/codex/repos/flexirich-goal011-20260919 "bash scripts/run_goal011_tmux.sh"'
```

Status commands, identical in WSL Ubuntu bash and macOS bash:

```bash
ssh deep-server-ts 'cat /data/codex/repos/flexirich-goal011-20260919/outputs/goal011/forecast-v1/STATUS.txt'
ssh deep-server-ts 'tail -n 25 /data/codex/repos/flexirich-goal011-20260919/outputs/goal011/forecast-v1.log'
ssh deep-server-ts 'cat /data/codex/repos/flexirich-goal011-20260919/outputs/goal011/forecast-v1.exitcode'
ssh deep-server-ts 'tmux has-session -t flexirich-g011-forecast-v1'
```

There is no new MCMC in this run. Each profile integrates all retained parent
posterior draws in log space. Outputs retain species event probabilities and
stable log probabilities, conditional count PMFs averaged over MCMC draws and their log PMFs, conditional
per-draw probabilities, and seeded joint nested-horizon count paths. Metadata
record input hashes, parent identities, source commit, environment, model roles,
effort type and the fact that predictions are unscored.

On completion, verify all output file hashes after copying; review finite/normed
PMFs, logical bounds, exact unseen-label symmetry, nesting and endpoint counts;
archive and commit the predictions. The scoring function uses synthetic tests
until the independently reviewed outcome-access gate is satisfied. If execution
fails, preserve the failed run and make any repair a new committed run identity.
