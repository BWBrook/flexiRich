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

## Completed-run assessment, 9 October 2026

The launch receipt above describes its historical state. The remote run
finished on 5 October at 22:04:07 Australia/Hobart with exit code 0. All 500
jobs completed; 3,998 of 4,000 fits returned code 0 and two retained code 52.
The session `flexirich-g013-recovery-v1` has ended. Its working directory and
output locations remain as recorded above and in Runbook.md.

All 4,513 output hashes passed remotely at the completion check, then passed
again after the complete artifact tree was copied to the corresponding local
`outputs/goal013/recovery-v1/` path. The assessment also verified every frozen
input receipt. The production manifest SHA-256 is
`80416264b13eedd30863b595bf6654d1a509653b6137d4338e2f719356e183a8`.

`scripts/assess_goal013_results.R` checked all 260,000 saved species event rows
against the simulated panels and training cohorts, reconstructed 30,000 count
scores, reproduced 1,000 model selections, and verified identical diagnostic
pair support. It recomputed bounds from saved parameter vectors, including
upper amplitudes omitted by the frozen boundary field. No fits were rerun.

Compact tables, a visually checked PNG/PDF figure, and their SHA-256 manifest
are preserved in `evidence/assessment-v1/`. The full local generated assessment
is at `outputs/goal013/assessment-v1/`. The independent results audit is
`evidence/results-independent-review.md`; the scientific assessment and
proposed next comparison are in Decision.md and Fable-review-brief.md. The
brief remains unsent. Completion of this assessment does not approve a new
field model or change the original frozen data, fits or selection rules.
