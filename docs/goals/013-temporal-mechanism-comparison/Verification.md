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

The source commit, remote verification and observed startup are recorded below
after dispatch. A successful launch does not constitute recovery or support
for an empirical temporal model.
