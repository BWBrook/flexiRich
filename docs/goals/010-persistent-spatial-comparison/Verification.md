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
