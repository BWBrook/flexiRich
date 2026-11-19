# flexiRich repository instructions

Follow the machine-wide agent instructions, with these project-specific additions.

## Scientific compute

- Run unit tests, mathematical bridges, and genuinely small smoke checks locally.
- Run Stan-intensive simulation grids, calibration batches, and empirical model
  batches in a named `tmux` session on `deep` from `wsl` or on `nectar` from a Mac.
  Follow the current routing guidance in the Nectar control-plane repo.
- Before a remote run, freeze and commit its code, inputs, manifest, seed rules,
  and output contract. Record the Git commit in the run metadata.
- Verify that the remote process has started, is writing the expected log or
  outputs, and is not failing immediately. For a launch-only task, report the
  verified start and status command. When the task includes monitoring or
  results, follow the run through completion and verify its outputs.
- At every handoff, report the session name, remote working directory, output
  location, and exact status commands for both WSL Ubuntu bash and macOS bash.
- Do not change a running frozen analysis. Diagnose failures from preserved
  evidence and make any repair as a new committed run.
