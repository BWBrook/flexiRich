# Goal007 decision — no regularisation candidate

Status: **complete — `NO_REGULARISATION_CANDIDATE`**

Adjudicated: 2026-08-25

## Decision

Neither frozen shared-shift candidate is eligible to proceed. Goal007 stops at
Task 2, Task 3 is not run, and no method is released for prospective Judbury
validation. Judbury detection outcomes and all Huon Ridge information remain
sealed.

This is an inferential stop, not a computational failure. The shared hierarchy
reduced occasional-class RMSE and core catastrophic errors, but it introduced
too much systematic bias when the true class contrast departed from its prior
centre and provided inadequate uncertainty when the two classes had no true
separation.

## Frozen execution and audit

The screen ran on `deep-server` from clean pushed Git commit
`6afcd2820c9fec0c07e0fe206f9813671c4c6c34` in the named `tmux` session
`flexirich-g007-task2`.

- 60 new synthetic datasets crossed six frozen truth profiles and 10
  replicates;
- the unchanged independent baseline, `shared_F5`, and `shared_F3` produced
  180 paired fits and 360 class-recovery rows;
- all 180 fits were terminal-clean: the baseline required one rescue and both
  shared candidates were 60/60 primary-clean;
- all 120 shared-candidate Gaussian artifacts passed their approximation
  checks;
- the run exited zero and recorded `empirical_outcomes_used=false`; and
- an independently implemented compact-evidence replay matched all 52 gate
  rows, both eligibility decisions, the catastrophic cases, and the weak-first
  selection result.

The deterministic bridges also passed: maximum prior-transform error was
`8.88e-16`, implied-covariance error was zero, likelihood-value error was
`9.82e-10`, and likelihood-gradient error was `1.22e-08`.

## Prespecified gate result

| Candidate | Gates passed | Failed requirements | Eligible |
| --- | ---: | --- | --- |
| `shared_F5` | 24/26 | core occasional generator bias; no-separation stress coverage | no |
| `shared_F3` | 23/26 | core occasional generator bias; no-separation stress coverage; no-separation stress catastrophic errors | no |

The exact failed values were:

| Candidate | Gate | Value | Frozen requirement |
| --- | --- | ---: | ---: |
| `shared_F5` | maximum absolute core-profile occasional bias | 0.534 | at most 0.500 |
| `shared_F5` | no-separation occasional 90% coverage | 5/10 | at least 7/10 |
| `shared_F3` | maximum absolute core-profile occasional bias | 0.654 | at most 0.500 |
| `shared_F3` | no-separation occasional 90% coverage | 5/10 | at least 7/10 |
| `shared_F3` | no-separation composite catastrophes | 4/10 | at most 2/10 |

No threshold is relaxed after seeing these results. In particular, F5's core
bias miss is numerically narrow but scientifically interpretable: its median
occasional-location bias in the `compressed` profile was `-0.534` log units,
or a factor of 1.71. F3 was more strongly pulled toward the prior contrast; its
largest bias was `+0.654` log units in `expanded`, or a factor of 1.92.

## What the redesign did improve

The hypothesis was not wholly unsuccessful. Relative to the independent
baseline, both shared candidates improved central occasional-class recovery
without degrading routine-class recovery:

| Model | Occasional generator RMSE | Occasional finite-set RMSE | Core occasional coverage | Core catastrophes |
| --- | ---: | ---: | ---: | ---: |
| independent | 0.558 | 0.571 | 50/50 | 3/50 |
| `shared_F5` | 0.437 | 0.465 | 50/50 | 2/50 |
| `shared_F3` | 0.418 | 0.478 | 49/50 | 2/50 |

The frozen worst-target occasional RMSE ratios were 0.814 for F5 and 0.837 for
F3, comfortably better than the required 0.90. Routine generator and
finite-set RMSE ratios were also below one for both candidates. Thus, borrowing
the common shift reduced variance and one core catastrophic case.

The trade-off was systematic shrinkage under contrast misspecification. F5
had opposing median occasional biases of `-0.534` in `compressed` and `+0.498`
in `expanded`; F3 increased these to `-0.562` and `+0.654`. In the
`no_separation` stress profile, the independent baseline covered the
occasional generating location in 8/10 replicates, compared with only 5/10 for
each shared model. Stronger F3 regularisation also raised stress catastrophes
from one under the baseline to four.

The two shared-model core catastrophes both occurred in `expanded` replicates.
They were driven by errors against the realised mean of the six fixed
occasional candidates rather than non-clean computation or failure to cover
the superpopulation generating location. For F5, the finite-set errors were
1.24 and 1.44 log units, corresponding to factors of about 3.46 and 4.21. This
distinction supports retaining both recovery targets in future work.

## Scientific interpretation

The shared-shift premise was partly correct: the 44 routine candidates can
stabilise a common grid-level encounter-rate shift for the six occasional
candidates. However, the same coupling makes inference brittle when the
routine--occasional contrast is wrong. A normal F3 or F5 contrast prior cannot
simultaneously deliver the desired variance reduction, profile-level bias
control, and severe-misspecification coverage in this design.

The result does not show that all hierarchical borrowing is unhelpful. It
shows that these two fixed Gaussian contrast regularisers are not robust enough
to justify empirical deployment. A future, separately prespecified hypothesis
might consider robust or conflict-adaptive borrowing, external quantitative
calibration of the class contrast, or replacement of the binary encounter
classes with defensible species information. It should use fresh simulations
and must not redefine the present gates or reuse these streams for candidate
selection.

## Protected-data boundary and handoff

Because Task 2 returned `TASK2_STOP`:

1. the fresh end-to-end Task 3 richness and discovery screen is not run;
2. no empirical Judbury calibration or prospective outcome is opened;
3. Huon Ridge remains untouched external validation; and
4. the next scientific direction requires a new goal and a new freeze rather
   than another Goal007 tuning pass.

Compact evidence is retained under `outputs/goal007/task2-screen-v1/` and the
independent audit under `outputs/goal007/task2-audit-v1/`. Raw compressed
CmdStan evidence remains on `deep-server`.
