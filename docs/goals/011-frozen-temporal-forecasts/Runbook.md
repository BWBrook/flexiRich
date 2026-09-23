# Goal011 forecast generation and handoff

Status, 23 September 2026: generation, independent audit and bounded Judbury
assessment are complete. See Decision.md, PredictionAudit.md and Verification.md.
The remote generation run below remains unchanged and unscored; local scores
live separately in `outputs/goal011/assessment-v3/`, and the final figure/tables
in `outputs/goal011/synthesis-v2/`. Huon Ridge remains unopened.

The generation command reads no later detections. Its actual predictive objects
were verified, archived and committed, with independent audit clearance, before
the later bounded assessment. Do not relaunch the completed remote command into
its existing output directory.

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

## Completed local assessment and reproduction

The original remote job ended with exit 0; its tmux session need not still
exist. The status/log/exit commands above work identically from WSL and macOS.
The full prediction, audit and assessment archives are under `evidence/`, with
their SHA-256 values and restore instructions. Restore into a fresh checkout
without overwriting existing outputs. No protected Huon Ridge data are needed.

With restored forecasts and assessment tables, regenerate the figure and all
comparison tables into a new directory:

```bash
Rscript scripts/summarise_goal011_assessment.R outputs/goal011/assessment-v3 outputs/goal011/forecast-v1 outputs/goal011/synthesis-replay
```

The manuscript figure points to the preserved final `synthesis-v2` artifact.
Its data and scores are unchanged from v1; only vertical scaling and labels
were improved, and a named-species first-year context table was added.

Raw extraction can be replayed, after the committed audit and hashes pass, with
the unchanged external source files available and a clean checkout:

```bash
Rscript scripts/check_goal011_outcome_protocol.R
Rscript scripts/score_goal011.R outputs/goal011/assessment-replay
```

This records another access receipt and never overwrites the preserved v2
failure or successful v3 assessment. The original first-access time remains
2026-09-23 01:38:27 UTC. This is bounded deterministic data processing and
scoring, not a new MCMC batch; it ran locally. Any future empirical fitting
still belongs on deep-server under a new committed run contract and tmux session.
