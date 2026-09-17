# Goal009 pre-launch audit

17 September 2026. Parent integration of an independent methodological design
review and focused implementation audit, followed by direct local checks.

**GO for first-year model criticism.** The unchanged Goal003 full-candidate
likelihood is a coherent baseline for this purpose. Grouping observations by
species, station and active days is sufficient under its constant-hazard
assumption. The full panel contains all-zero candidates and needs no detected-
only truncation correction. This does not overturn historical scientific stops
or qualify the model as an empirical richness estimator.

The primary prior is inherited; choosing the existing wider-tail profile after
Goal008 inspection is a development sensitivity. Both must be interpreted
together, including whether latent richness changes while observed-data
predictions remain similar.

## Independently checked

- Reconstruction from restricted first-year CSVs gives detected richness 21,
  979 positive cells, 16 detected mammals and five detected birds.
- All 450 observed species-by-station counts match the preserved Goal008
  summaries. The targeted crossing statistic is the minimum of the two
  opposite differences, 18, over 30 fully operational matched weeks.
- The network-wide common-ranking violation statistic is 498. The temporal
  statistic is 786 switches among 6,804 eligible adjacent cell pairs for the
  fixed set of 21 detected species.
- Predictive simulation retains draw-matched species rates, camera effects and
  membership probabilities. It draws membership once per species and preserves
  it across all stations and weeks; known species have membership one.
- Cell ordering and species/station/block output order agree with canonical
  tables. The reader uses only restricted Goal008 tables and tracked config;
  all six data/config inputs have frozen SHA-256 receipts.
- The runner requires deep-server, tmux, a clean source commit and synchronized
  renv; it preserves failed attempts and suppresses PPCs for nonclean fits.
- The finite-grid bridge compares explicit state enumeration with sequential
  updating in both period orders, including a candidate with all-zero history
  and candidates first detected in either period. Maximum errors are 3.47e-18
  for likelihoods and 1.11e-16 for per-case normalized masses and final
  membership probabilities. Membership after a detection is exactly one. The
  deliberately incorrect reset control differs by 7.84e-3.

## Repairs before launch

Review caught a new bridge bug that allowed a nonmember to produce a detection,
followed by an incorrect reverse-order evidence update. Both were repaired and
checked against independent membership enumeration before any empirical fit.
Each observed-history case now normalizes its own parameter grid. Tests check
forward/reverse membership agreement, known-member constraints, shared membership
across replicate cells, and RNG restoration/invariance to the caller's RNG kind.
PPC uses Mersenne-Twister/Inversion/Rejection with explicit seeds.

A wrapper-only draw-array dimension issue was caught with synthetic posterior
arrays and repaired before launch. The manuscript's added taxonomic paragraph
built through makedoc; affected PDF and DOCX-rendered pages were inspected.
The shell wrapper passed bash syntax and shellcheck. Goal008's evidence archive
was compared byte-for-byte with all 47 archived files, with no differences.

One full-suite invocation overlapped the final source/test repairs, so its two
Goal009 failures are not accepted as a check of a stable revision. The affected
tests passed on settled source; a new full-suite invocation is required before
the run commit. Final verification is recorded in `Verification.md`.

## Scientific limits

Shared station effects cannot represent species-specific spatial rankings;
conditional independence omits temporal clustering. Both are targets of the
criticism. Positive station-week cells are not image-event counts. No in-sample
PPC identifies whether an unseen candidate is absent or almost undetectable.
Intervals across many species and blocks are descriptive, not independent
hypothesis tests. The selected station example is exploratory. No later Judbury
or Huon Ridge outcomes were read in this audit or implementation.
