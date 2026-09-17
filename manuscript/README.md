# Integrated manuscript

This is a working scientific outline with a developing Methods/Results core,
not a circulation-ready or submission-ready manuscript. Authorship, journal,
full literature positioning, definitive model comparisons and external
validation remain to be completed. It is one methods-and-application paper.

Sources remain in this repository. Build with the local makedoc engine:

```sh
make manuscript-check
make manuscript
```

The default engine is `$HOME/work/makedoc`; use `MAKEDOC=/path/to/makedoc`
to override it. Outputs are `outputs/manuscript/flexirich-working.pdf`,
`flexirich-working.docx`, and the makedoc build manifest. The engine inspected
for initial onboarding was commit `b613e715a86f81623953403f84353314405057db`.
No build-engine source or settings are modified by this integration.

Generated figures must already exist before building. They are produced by
the Goal008 theory and restricted early-Judbury development runners; see
`docs/goals/008-ecological-information/Decision.md` for reproduction commands
and data-use limits. Building the manuscript never opens empirical data.

The CSL file is an unchanged copy of the locally bundled Pandoc default style
(`/usr/share/pandoc/data/default.csl`); its embedded attribution and licence
are retained. This is draft typography, not a venue decision. The bibliography
is intentionally small during this diagnostic tranche; a passing citation-key
check is not a literature-completeness check.
