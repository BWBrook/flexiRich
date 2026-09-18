# Goal009 closeout audit

18 September 2026. Independent methodological specialist review plus parent
verification of the preserved and corrected evidence.

**Accepted as completed development model criticism.** Neither prior profile
earns adoption as an adequate empirical richness estimator. This is not evidence
that either posterior richness mean is known to be wrong: actual total richness
remains unknown.

The reviewer independently reproduced the loaded-posterior matrix-class failure,
checked the explicit numeric-matrix repair and regression, inspected corrected
tables, and endorsed the species-by-station comparison with a separately staged
temporal extension. The review specifically rejected interpretation of the
original total-count and third-block deficits after their correction. It also
confirmed that temporal non-exchangeability persists after conditioning on
species-by-station-by-effort counts, without identifying a biological mechanism.

Verification completed:

- All 51 original remote files matched copied SHA-256 receipts; original chain
  CSVs, draws, diagnostics, faulty PPCs, log and exit marker are preserved.
- Original postprocessing replay reproduced all 20 numerical CSVs exactly and
  recorded 104,000 warnings of the same effort-sweep type.
- Goal009 regression suite: 29 expectations passed. Full repository test suite
  passed on the settled repair, with warnings treated as failures.
- Corrected reprocessing used the frozen draws and seeds, required a clean
  committed checkout, and completed with warnings fatal and no warnings.
- Both latent-richness PMFs matched independent plain-matrix recomputation
  within 1e-12. Original sampler diagnostics were unchanged.
- All 1,999 timing permutations preserved stratum detection counts, species
  totals and unsampled cells. Toy checks, overwrite refusal and a separate
  deterministic rerun comparison passed; the script matches its recorded hash.
- Synthesis values agree with source tables. Both evidence archives were
  checked against every archived file after creation.
- Local makedoc check/build passed. Added results and the criticism figure were
  reviewed in rendered PDF and DOCX pages; no build-engine changes were made.

No additional Stan fit, later Judbury detection access, Huon Ridge access,
board message, push or publication occurred in this tranche. The original
remote checkout remains pinned to its fit commit. The completion record is
historical; corrected scientific outputs are local and archived in the repo.
