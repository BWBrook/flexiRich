# Goal009 predictive simulation repair

18 September 2026. Both frozen fits completed with clean sampler diagnostics,
but the original predictive tables are invalid and must not be interpreted.
The original run, its warnings, saved draws and all outputs remain preserved.

## Defect and scope

The original log reported at least 50 warnings without individual messages.
Replaying its postprocessing from all eight saved chain CSVs reproduced all
20 numerical CSV outputs exactly and captured 104,000 warnings, 52,000 per
profile: `STATS does not recycle exactly across MARGIN` from the effort
`sweep()` inside `goal009_ppc()`.

The saved matrices retain `posterior::draws_matrix`. With the posterior
namespace loaded, its extraction method keeps a row as a matrix. The outer
sum of a 1-by-50 species row and 1-by-9 station row therefore has dimensions
1-by-50-by-1-by-9. Applying effort along its second margin recycles nine
station efforts across the 50 species instead of applying them by station.
Zero-effort masking later in the simulation does not repair this allocation.
`as.matrix()` does not remove the subclass. Without the posterior namespace
loaded, the same deserialized objects can use base extraction and appear
correct; this explains why tests with ordinary matrices missed the defect.

The Stan likelihood, sampling, saved draws and latent-richness PMFs are
separate from the faulty simulation. The PMF helper explicitly converts its
probability vector to numeric. The repair will also recompute that PMF from
plain matrices and require agreement with each preserved PMF within 1e-12.

## Repair and replacement contract

Rebuild the three predictive input matrices explicitly as base numeric
matrices at the `goal009_ppc()` boundary. The new regression loads posterior
and compares its matrix subclass with plain matrices using unequal effort,
an outage, distinct species rates and opposite station effects. All 29
Goal009 expectations pass, with warnings treated as failures.

`scripts/reprocess_goal009_ppc.R` reads only the preserved draws and restricted
first-year data. It checks 11 frozen input receipts, retains the original two
predictive seeds and 1,000-draw selection, treats every warning as an error,
and writes a new `outputs/goal009/ppc-repaired-v2` directory. It requires a
clean committed source checkout and refuses to overwrite existing outputs.
No new posterior sampling or ecological assumption is introduced. This local
postprocessing operation does not alter the frozen deep-server checkout.

Only the corrected predictive tables may support the Decision.
The original `COMPLETE` marker describes successful execution, not correctness
of its predictive postprocessing. The initial interpretation of the original
PPCs is withdrawn pending replacement. No later Judbury or Huon Ridge outcomes
are accessed by this repair.

## Verified outcome

The repair was frozen in commit
`e24e997b7d6d242e04c4afab430da49777279660`. The full local test suite passed
with warnings treated as failures. An independent methodological specialist
reproduced the dimension defect, checked the repair and regression, and approved
the preserved-draw reprocessing contract. Both corrected profiles completed
with warnings treated as errors and both latent PMFs matched within 1e-12.
No additional sampler was run.

The scientific interpretation changed materially: aggregate positive-cell
counts and the third temporal block are reproduced adequately after repair.
The spatial and temporal structure failures remain. See Decision.md for the
corrected numbers; do not carry forward the original total-count deficit.
