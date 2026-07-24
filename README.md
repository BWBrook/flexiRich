# flexiRich

Research implementation and validation of an effort-aware estimator of
camera-detectable species richness from a finite candidate pool.

## Goal 001

```sh
Rscript bootstrap_env.R
Rscript scripts/run_tests.R
```

The illustrated acceptance scenario is a deterministic explanatory simulation,
not estimator validation or an empirical fit. Render it from the repository
root with:

```sh
quarto render analysis/goal001_simulator.qmd --output-dir ../outputs/goal001
```

Generated artefacts are written under `outputs/` and are not committed.
Huon Ridge data and locations are outside this repository.
