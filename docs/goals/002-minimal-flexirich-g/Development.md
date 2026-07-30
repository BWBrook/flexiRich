# Goal 002 Development Benchmarks

## Execution boundary

The six prespecified synthetic development benchmarks were run from source
commit `9aab8540692dc3ffd75f81c1821316361cb2f147`, after the dated
prior-predictive decision had been committed and independently reviewed
`READY`.

The canonical command was invoked exactly once:

```bash
Rscript scripts/run_goal002_pilot.R --phase development
```

It exited successfully with:

```text
Goal 002 development dispatcher: 6 completed, 0 skipped.
```

The tracked development manifest has SHA-256
`1edeca14ff522acec8e0579eee23e2f74876ccee6fdc8949a3b854361cf85a7d`;
its canonical serialized manifest hash is
`b2b497ff077575b16823ccf6491775d7730edfda84e95cc90fee224b9c5a3047`.
All six fits used the provisionally accepted `primary-v1` prior profile. The
Stan source hash recorded by every fit is
`659b335b0e9eaffecb2629d06a768c419d00f3c3a8719fa99f67ea6c4171cb91`.

## Six-row manifest and terminal evidence

The diagnostic columns report the terminal attempt: the primary attempt for
`primary_clean` rows and the single prespecified rescue attempt for
`rescue_clean` rows. The fixed clean-fit gates are zero divergences, zero
maximum-treedepth hits, minimum E-BFMI at least 0.3, maximum R-hat at most
1.01, and minimum bulk and tail ESS at least 400. Every terminal attempt also
passed the continuous Rao--Blackwellised richness diagnostics and the
generated-richness contract.

| Cell | Run ID | True richness | Occasions | Simulation seed | Fit seed | Observed richness | Terminal status | Rescue | Divergences | Treedepth hits | Min E-BFMI | Max R-hat | Min bulk ESS | Min tail ESS | Elapsed (s) | Output | Stan/R bridge |
|---:|---|---:|---:|---:|---:|---:|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 1 | `development-c01-r01-primary` | 8 | 26 | 120020001 | 220020001 | 4 | `rescue_clean` | yes | 0 | 0 | 0.775 | 1.0033 | 1340.5 | 1453.9 | 22.251 | 42.09 MiB | PASS |
| 2 | `development-c02-r01-primary` | 20 | 26 | 120020002 | 220020002 | 13 | `rescue_clean` | yes | 0 | 0 | 0.696 | 1.0027 | 1253.9 | 1370.6 | 22.548 | 39.39 MiB | PASS |
| 3 | `development-c03-r01-primary` | 27 | 26 | 120020003 | 220020003 | 22 | `primary_clean` | no | 0 | 0 | 0.664 | 1.0033 | 1450.1 | 1451.5 | 3.780 | 16.04 MiB | PASS |
| 4 | `development-c04-r01-primary` | 8 | 208 | 120020004 | 220020004 | 7 | `rescue_clean` | yes | 0 | 0 | 0.806 | 1.0074 | 1013.2 | 1296.6 | 89.639 | 53.91 MiB | PASS |
| 5 | `development-c05-r01-primary` | 20 | 208 | 120020005 | 220020005 | 20 | `rescue_clean` | yes | 0 | 0 | 0.649 | 1.0043 | 753.0 | 984.5 | 67.888 | 48.63 MiB | PASS |
| 6 | `development-c06-r01-primary` | 27 | 208 | 120020006 | 220020006 | 27 | `primary_clean` | no | 0 | 0 | 0.640 | 1.0056 | 745.7 | 1247.1 | 10.755 | 22.03 MiB | PASS |

The Stan/R result is one fresh source-level bridge check shared by all six
rows, not six independent cell-specific oracle fits. The command
`Rscript scripts/check_stan_model.R` returned
`Goal 002 Stan bridge: PASS` after the development dispatcher. It rechecked
the finite lower-tail target-density delta, Stan `member_ll`, and Stan
`q_member` against the independent R oracles under the unchanged Stan source.

## Primary attempts and rescue use

The provisional primary sampler was not independently reliable in these six
single-seed cells. Four primary attempts were non-clean and therefore invoked
the one permitted rescue:

| Cell | Primary result | Divergences | Treedepth hits | Min E-BFMI | Max R-hat | Min bulk ESS | Min tail ESS | Recorded reasons |
|---:|---|---:|---:|---:|---:|---:|---:|---|
| 1 | non-clean | 15 | 0 | 0.845 | 1.0067 | 672.6 | 549.4 | `divergences` |
| 2 | non-clean | 4 | 0 | 0.731 | 1.0048 | 789.6 | 703.6 | `divergences` |
| 3 | clean | 0 | 0 | 0.664 | 1.0033 | 1450.1 | 1451.5 | none |
| 4 | non-clean | 40 | 0 | 0.764 | 1.0141 | 199.9 | 96.9 | `rhat`, `bulk_ess`, `tail_ess`, `divergences` |
| 5 | non-clean | 0 | 0 | 0.593 | 1.0052 | 416.9 | 358.0 | `tail_ess` |
| 6 | clean | 0 | 0 | 0.640 | 1.0056 | 745.7 | 1247.1 | none |

All four invoked rescue attempts were clean. Across them, divergences and
maximum-treedepth hits were zero, minimum E-BFMI was 0.649, maximum R-hat was
1.0074, minimum bulk ESS was 753.0, and minimum tail ESS was 984.5. Thus all
six rows ended clean and addressable; there was no terminal failure.

The observed rescue fraction, 4/6, is a material efficiency limitation. It is
not an estimate of the future rescue probability: each cell has only one
development seed, so seed variation and cell-specific geometry cannot be
separated.

## Runtime and storage

The six terminal records contain 216.861 seconds of aggregate attempt time,
with a mean of 36.1435 seconds per manifest row. The first attempt began at
2026-07-30T03:05:39Z and the last attempt ended at
2026-07-30T03:09:54.755Z, a 255.755-second attempt span. The complete dispatcher
used 263.6 seconds of observed wall time, including startup, simulation,
serialization and validation overhead.

A linear 16-fold projection from six to 96 rows is:

- 3,469.776 seconds, or 57.8296 minutes, from recorded attempt time; and
- 4,217.6 seconds, or 70.2933 minutes (1.1716 hours), from complete dispatcher
  wall time.

This is a warm-cache, serial projection under the observed 4/6 rescue fraction.
It does not include later reporting or audit work, and it will change if
frozen-run rescue use differs.

The six run directories contain 232,880,154 file bytes in total
(222.0918 MiB). Peak per-row output was 56,533,319 bytes (53.9144 MiB) in
cell 4. A simple 16-fold storage projection is 3.4702 GiB, before filesystem
overhead and any downstream report artefacts.

## Sampler adjudication

No sampler profile was changed.

The high provisional-primary failure rate is real, but the prespecified
two-stage sampler contract was successful: every invoked rescue passed all
fixed diagnostic gates, and all six rows were terminal-clean. The six
benchmarks do not isolate which rescue-profile component produced that result,
because warmup length, sampling length, `adapt_delta`, maximum treedepth and
fit seed changed jointly. Promoting the observed rescue settings wholesale
would leave no empirically tested, more-conservative rescue profile; inventing
an intermediate or stronger replacement would be an untested tuning decision.
The bounded evidence therefore supports retaining the tested two-stage
contract and disclosing its efficiency cost, rather than making a speculative
sampler change.

The final profiles are:

| Role | Profile ID | Chains | Parallel chains | Warmup | Sampling | `adapt_delta` | Max treedepth | Refresh |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| Primary | `primary-sampler-v1` | 4 | 4 | 1000 | 1000 | 0.90 | 12 | 100 |
| Rescue | `rescue-sampler-v1` | 4 | 4 | 1500 | 1500 | 0.99 | 15 | 100 |

Frozen execution must retain every primary failure, invoke at most this one
rescue, and suppress posterior interpretation for any terminal non-clean row.
The six development runs support this bounded operational decision only; they
do not establish universal HMC robustness.

## Evidence validation and interpretation boundary

A read-only validation pass:

- re-read the canonical six-row manifest and its hash;
- confirmed exactly six unique status rows, all `completed`;
- called `goal002_terminal_action()` for every row and obtained `skip` only
  after full terminal-record and artefact validation;
- reopened and validated every `fit.rds`, `summary.rds`, primary attempt and
  applicable rescue attempt;
- reconstructed every synthetic dataset from its manifest simulation seed and
  matched the data hash;
- matched primary and rescue seeds, including the fixed rescue offset;
- matched every terminal record to its fit, summary, attempt diagnostics,
  model hash, posterior PMF and status row; and
- directly rechecked all continuous diagnostic gates and generated-richness
  contracts.

The development results apply only to the correctly specified synthetic pilot.
They are not empirical camera-trap validation, out-of-sample validation, or
evidence for anonymous unseen-species richness.

`outputs/goal002/frozen` was absent throughout this tranche. No frozen command
was run, and no frozen output was created or viewed.
