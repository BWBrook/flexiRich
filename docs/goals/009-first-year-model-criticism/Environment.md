# Goal009 environment repair

Recorded 2026-09-17 (Australia/Hobart; UTC timestamps below are from package
build metadata).

## Scope and pre-restore state

The existing `renv.lock` records R 4.6.1, `nlme` 3.1-170, and `survival`
3.8-9. With the project activated through `.Rprofile`, the project library
was:

```text
/home/bwbrook/papers/flexiRich/renv/library/linux-ubuntu-noble/R-4.6/x86_64-pc-linux-gnu
```

Before restoration, the project-resolved package versions were:

| Package | Lockfile | Before | Before path |
| --- | --- | --- | --- |
| `nlme` | 3.1-170 | 3.1-171 | `/home/bwbrook/.cache/R/renv/sandbox/linux-ubuntu-noble/R-4.6/x86_64-pc-linux-gnu/9a444a72/nlme` |
| `survival` | 3.8-9 | 3.8-12 | `/home/bwbrook/.cache/R/renv/sandbox/linux-ubuntu-noble/R-4.6/x86_64-pc-linux-gnu/9a444a72/survival` |

The reported `survival` 3.8-11 was not the version observed in this
project-activated session; the resolved version was 3.8-12. A project-
activated `renv::status()` found only these two package drifts. A separate
`Rscript --vanilla` check bypassed project activation and showed system/sandbox
differences; those were not treated as project-library drift and were left
unchanged.

## Restoration

Only the two named packages were restored, using the existing lockfile:

```sh
Rscript -e 'renv::restore(packages = c("nlme", "survival"), prompt = FALSE)'
```

The command built and installed `nlme` 3.1-170 and `survival` 3.8-9 from
source. No snapshot, lockfile edit, raw-data edit, global-library edit, or
Stan/empirical fit was performed.

## Post-restore evidence

The project-activated library now resolves:

| Package | After version | After path |
| --- | --- | --- |
| `nlme` | 3.1-170 | `/home/bwbrook/papers/flexiRich/renv/library/linux-ubuntu-noble/R-4.6/x86_64-pc-linux-gnu/nlme` |
| `survival` | 3.8-9 | `/home/bwbrook/papers/flexiRich/renv/library/linux-ubuntu-noble/R-4.6/x86_64-pc-linux-gnu/survival` |

Both packages report `Built: R 4.6.1; x86_64-pc-linux-gnu`; the runtime R is
4.6.1 and matches `renv.lock`. The final project-activated status check
reported:

```text
No issues found -- the project is in a consistent state.
synchronized= TRUE
```

`git diff --quiet -- renv.lock` also confirmed that the lockfile is unchanged.
