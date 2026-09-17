# Goal009 verification before the run freeze

17 September 2026. Checks on the settled implementation completed before the
source/run commit and before any empirical sampler was started.

| Check | Result |
|---|---|
| `make test-goal009` | PASS: 25 expectations |
| `make goal009-check` | PASS: six input receipts, first-year panel and membership bridge |
| `Rscript scripts/run_tests.R` | PASS, exit 0 on the settled implementation |
| Independent methodological and implementation audit | GO for bounded first-year criticism; see Audit.md |
| `bash -n` and `shellcheck` on run wrapper | PASS |
| Runner R parsing and synthetic chain-rank extraction | PASS |
| `make manuscript-check manuscript` | PASS; affected PDF/DOCX pages visually inspected |
| Goal008 archive recovery evidence | All 47 archived files byte-identical to preserved outputs |
| Local and isolated remote `renv::status()` | synchronized TRUE; R 4.6.1 |

The unchanged `renv.lock` SHA-256 on both machines is:

```
9a0741c3b97e6d529fec2a6bf5f321c81eb0b2730836ef2828b4f99cad163e06
```

The remote runtime has CmdStan 2.38.0. Its isolated source checkout is clean and
its project library reads the existing synchronized remote library without
modifying it. The host had 64 logical CPUs and approximately 81 GiB available
memory at the preparation check. This run uses at most four sampler chains
concurrently, one thread each; compilation is limited to two jobs. It does not
require changes to other jobs, host services or system packages.

These checks establish implementation readiness. They do not establish model
adequacy, identify the unseen richness tail, or validate forecasts. The empirical
run's own source commit, start time, input receipts, diagnostics, completion
status and exit marker are authoritative for its execution.
