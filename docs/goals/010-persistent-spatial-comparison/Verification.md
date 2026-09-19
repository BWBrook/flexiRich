# Goal010 verification receipt

18 September 2026, before remote fitting.

- Goal010 unit tests and runner check passed; mathematical maximum absolute
  error 1.14e-13. Input hashes and all eight adapter/monitor contracts match.
- Direct-fit bridge regression suite passed (16 expectations), including
  corrupted member likelihood, station rates, extracted membership and missing
  fields. This checks the checker; actual Stan/R agreement remains a remote
  output requirement.
- Prior-predictive smoke (100 draws per six profiles) completed without warnings.
  This is a runtime check; the frozen report uses 2,000 draws per profile.
- Shell syntax, shellcheck and whitespace checks passed.
- Independent methodological review: GO after the full local suite passes.
  Resolved findings and scientific limitations are in Audit.md.

The full-suite completion receipt and remote launch identifier will be appended
before/after those events respectively. No local Stan compilation or fitting.

Full `Rscript scripts/run_tests.R` completed successfully with warnings treated
as errors. It covered the repaired Goal009 PPC and Goal010 theory, extraction
and joint-thinning tests; the bridge file was added during that suite and was
therefore verified separately by its focused suite above. No skipped result is
being presented as an actual fitted-model check.

## Remote launch

Frozen fit source: `bff200a2b4e36d87a96c5b034e4e8f3491cd174c`.
An isolated clone was created at
`/data/codex/repos/flexirich-goal010-20260918`, fetched from a local Git bundle,
and detached at that commit. No Git push occurred. Goal008 archive SHA-256
matched `4b81065297f3eee6da6aa13a3d5f20d9c2fe854fdd9fa34b594ec10080068468`;
`tar --keep-old-files` restored its evidence, and the remote Goal010 check verified
the restricted first-year input hashes. Git was clean; renv reported synchronized;
CmdStan is 2.38.0.

Named session `flexirich-g010-spatial-v1` started successfully, with the expected
log and `RUNNING: prior checks and compilation` status under
`outputs/goal010/spatial-v1`. The existing unrelated session was untouched.
This is a launch receipt, not a completion or ecological success claim. Use
Runbook.md for exact WSL/macOS status commands.

Startup verification progressed beyond compilation: `control_zero_baseline`
completed `primary_clean`, including its direct Stan/R bridge and PPC outputs;
`control_zero_spatial` then began. Both Stan programs therefore compiled, and
the first end-to-end fit completed successfully. The run remains in progress.

A subsequent bounded startup check confirmed all four controls completed
`primary_clean`; `spatial_primary` began at 12:46:16 server time. Thus nonzero
interaction Stan/R bridges and the full spatial PPC path have also executed
successfully. Empirical fits were still pending at this receipt.

The separate synthesis script passed parsing, clear missing-run failure, and
an eight-directory synthetic schema smoke including legitimately unavailable
control statistics (all NA). Expected CSVs and PNG/PDF figures were generated
without script warnings. This smoke is not a scientific result; real-output
synthesis remains pending. The postprocessor does not alter the frozen fit run.

## Completed run, 19 September 2026

Exit marker is 0; all eight fits are terminal-clean (five primary, three rescue).
All 197 remote files were copied and matched byte-for-byte by SHA-256. The
original run is unchanged. Both the actual-result synthesis and the supplemental
summary audit completed without warnings. The comparison figure was visually
inspected; the both-wide mean-rate trace/rank plot was also inspected alongside
all saved numerical diagnostics. The manuscript includes the spatial comparison
and was rebuilt through the local makedoc toolchain.

The three rescues followed the frozen ESS/R-hat policy; all 11 attempts had zero
divergences, zero depth hits and no captured warnings. See audit-v1/rows.csv for
all attempts and InterpretationAudit.md for the independent scientific review.
Detailed results and the approved next step are in Decision.md. No later
Judbury detection or Huon Ridge file was opened during this interpretation.
