# Evidence directory

This directory accompanies
[`CONSULTATION.md`](../CONSULTATION.md). It is a compact evidence subset, not a
complete reproducibility archive.

## Source tables copied without modification

| File | Original path | SHA-256 |
|---|---|---|
| `case-results.csv` | `outputs/goal002r/paired-comparison/case-results.csv` | `df653b2a3a28d1674776138b1fe44b24bb32b2416a05f13470c1ae46e094c780` |
| `decision-criteria.csv` | `outputs/goal002r/paired-comparison/decision-criteria.csv` | `f2528d6f937a143ab66ae753a9c16116707d3d8cdf1cf79ceaf4dbc475852556` |
| `pmf-fidelity.csv` | `outputs/goal002r/paired-comparison/pmf-fidelity.csv` | `a9949009006dc5fba0869b32315811372dab73933e7388d08acc881c2c9e1625` |
| `parameter-fidelity.csv` | `outputs/goal002r/paired-comparison/parameter-fidelity.csv` | `44ac5e4294269a962ca30bac78b20b6c0f9da1d3c48f86037bbb46303edd502e` |
| `quadrature-checks.csv` | `outputs/goal002r/paired-comparison/quadrature-checks.csv` | `0102127ed7c2b3f65447f1a142756d82b9b4efc4ef35e187753c9ab0d9229cf3` |
| `numerical-screen.csv` | `outputs/goal002r/quadrature-revision/numerical-screen.csv` | `cb49234495f11d4bc73744e7ae6cbb929c9bb2cde617b31225ecc36224393fd1` |

The first five files are the complete tabular outputs from the prespecified
Goal 002R paired comparison. `numerical-screen.csv` is the complete 3,000-row
screen of four quadrature candidates across 750 posterior states.

## Derived consultation aids

| File | Purpose |
|---|---|
| `numerical-screen-summary.csv` | Candidate-level pass counts and absolute-error summaries derived from `numerical-screen.csv`. |
| `numerical-screen-states.csv` | The 750 unique integral states. `log_B` and `sigma_alpha` fully specify each integral; mode and scale document the tested adaptive transformation. |
| `runtime-summary.csv` | Primary runtime ratios and clean/rescue status derived from `case-results.csv`. |
| `richness-mean-mcse.csv` | Post-decision comparison of posterior mean-richness differences with combined Monte Carlo standard errors, computed from the saved terminal-fit draws. It did not contribute to the formal decision. |
| `diagnostic-summary.png` | Visual summary of numerical error and the runtime/primary-geometry trade-off. |

For each state in `numerical-screen-states.csv`, the all-zero likelihood is

\[
m_0=E_Z\left[\exp\{-\exp(\log B+\sigma_\alpha Z)\}\right],
\qquad Z\sim N(0,1).
\]

`log_B` is `mu_alpha + log_adjusted_exposure`. Thus the state table and the
reference values in `numerical-screen.csv` are sufficient to test alternative
one-dimensional integration algorithms without the original camera histories
or posterior draws.

The full archive—including CmdStan CSVs, exact code revision, environment
lockfile, simulations and rerun commands—can be supplied if it would help an
adviser reach a firmer conclusion.
