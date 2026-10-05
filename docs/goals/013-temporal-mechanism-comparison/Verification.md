# Goal013 verification and launch receipt

## Before the frozen run

The targeted suite passed 43 expectations: 36 mechanism checks and seven count
scoring/selection checks. Independent finite-state enumeration checked both
likelihoods and nonzero-amplitude conditional future event probabilities.
Conditional future likelihoods also agree with full-minus-training likelihood
differences. The independent review includes saturated-hazard and full-design
normalization checks, with maximum group-total discrepancy about `1.18e-11`.

The deterministic input build verifies the inherited compact-input hashes and
the service/placement source hashes. It preserves the original operation and
incidence arrays, masks only the five declared ambiguous movement station-weeks
for this screen, and preserves exactly 3,836 positive-cell totals across the
26 known species. The calibrated harmonic and state truths share their
taxon-specific expected switch targets; bird weakening is reported in Goal.md
and `config/goal013_calibration.csv`.

`outputs/goal013/smoke-v2` completed the full run path for a small two-species,
two-station panel: generation, eight fits, joint forecast scores, species event
probabilities, count distributions, diagnostics, summaries and output hashes.
Every fit converged. It is an integration check and contributes no recovery
evidence. The earlier `smoke-v1` completed fitting but stopped at summary
assembly because recycling a one-row manifest into a ten-row diagnostic table
raised an R row-name warning. Explicit row replication fixed the assembly;
the failed smoke remains preserved. No scientific formula or selection rule
was changed in response to its fitted results.

Shell syntax, shellcheck, R parsing and `git diff --check` passed. The final
input receipts pin code, data, calibrated truths, seeds and the scientific
contract. The final manifest interleaves truths by replicate so initial
execution exercises every generator, with unique frozen seeds per job.

Fable's independent checking script replayed exactly against its supplied log.
The exact script and replay log are preserved in `evidence/`; the scientific
adjudication is in Reconciliation.md. Raw observations and Huon Ridge were not
opened. Performance-only numerical fits used the open design and were not
treated as empirical evidence.

## Remote handoff

Source commit: `df8274015ab5deb9667ce81e2ac545f50f602c73`.
The incremental source bundle was verified on both hosts, SHA-256
`502594723fec8d0e06de20d78095a1697f812c52ca9cbf9ee33ad0f0a2ae0de4`.
The isolated checkout is
`/data/codex/repos/flexirich-goal013-20261005` on `deep-server-ts`.
The same 43 test expectations and complete input-receipt check passed there
before launch. It uses the existing shared R 4.6.1 renv library; no packages
were installed or changed. The library emits its existing out-of-sync warning,
so whole-library agreement with the lockfile is not asserted. The relevant
kernel tests passed in that runtime, and the run saves `session-info.txt`.

Startup was checked at **2026-10-05 02:30:30 UTC** (13:30:30 Hobart):

- Session `flexirich-g013-recovery-v1` was live.
- Overall status was `RUNNING 500 datasets`; no exit marker existed yet.
- Eight job directories were active, covering all five synthetic truths.
- Each had written its first two candidate score rows: 16 completed initial
  fits, all with convergence code 0.
- The log recorded the expected explicit job seeds; no initial execution
  error was present.

Results are written to `outputs/goal013/recovery-v1/` beneath the remote
checkout, with sibling `.log` and `.exitcode` files. Monitoring was handed
back at this point in accordance with AGENTS.md. See Runbook.md for exact
WSL Ubuntu and macOS bash commands. No complete recovery result has yet been
assessed. A successful launch does not establish recovery or support an
empirical temporal model. The code and inputs of the running analysis remain
at the frozen commit; this subsequent edit records its handoff only.
