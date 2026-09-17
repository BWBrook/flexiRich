# Goal009 launch record

The first-year criticism run was started on deep-server on 17 September 2026
from frozen source commit `e183888960c6ff5cdc7146e6549bf876f6e3484a`.
Goal008 was preserved beforehand in commit `6a54caa`, including its final
evidence archive. The isolated remote checkout was verified clean and all
six frozen input receipts and the mathematical bridge passed there before
launch. No push or board publication was made.

- Session: `flexirich-g009-firstyear-v1`.
- Checkout: `/data/codex/repos/flexirich-goal009-20260917`.
- Output: `outputs/goal009/first-year-v1/` within that checkout.
- Start recorded in run metadata: `2026-09-17 03:05:59 UTC`.
- Startup verification: compilation succeeded; the primary fit started at
  `2026-09-17 13:06:38` in the server's local time. The tmux session was alive,
  its R process had four sampler child processes, and STATUS.txt read
  `RUNNING: primary`. The expected log and metadata were present.

This is a launch snapshot, not a claim that the job is still running or has
completed when this note is read. Monitoring was handed back at verified
startup under the repository protocol. See [Runbook.md](Runbook.md) for exact
WSL/macOS bash commands, output interpretation and exit-marker meanings.
The running checkout remains pinned to the analysis commit; this documentation
closeout does not alter its code or inputs.

The next scientific decision follows review of both profiles' sampler and
predictive diagnostics. No new later Judbury or Huon Ridge outcomes were
opened. No predictive adequacy or richness-validation result is claimed yet.
