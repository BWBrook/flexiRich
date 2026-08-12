# flexiRich repository instructions

Follow the global Codex instructions, with these project-specific additions.

## Scientific compute

- Run unit tests, mathematical bridges, and genuinely small smoke checks locally.
- Run Stan-intensive simulation grids, calibration batches, and empirical model
  batches on `deep-server` in a named `tmux` session.
- Before a remote run, freeze and commit its code, inputs, manifest, seed rules,
  and output contract. Record the Git commit in the run metadata.
- Verify that the remote process has started, is writing the expected log or
  outputs, and is not failing immediately. Then stop and hand monitoring back
  to the user rather than polling indefinitely.
- At every handoff, report the session name, remote working directory, output
  location, and exact status commands for both WSL Ubuntu bash and macOS bash.
- Do not change a running frozen analysis. Diagnose failures from preserved
  evidence and make any repair as a new committed run.
