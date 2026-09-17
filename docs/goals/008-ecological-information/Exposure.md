# Judbury inspection incident — 12 September 2026

During initial schema orientation, the delegated development worker ran:

```sh
head -n 5 /home/bwbrook/git/camtrap-workflow/data/jc_obs.csv
```

This displayed a header and four observation records. According to the
worker's account of its existing tool history, three records were outside
the declared first-year development interval, with dates ranging from
2 February 2021 to 19 March 2022. The columns included station, datetime,
species, count and image metadata. Their values are not repeated here.
The parent did not reread these records. This was an instruction-following
error: schema inspection should have inspected only the header or used
synthetic data. The parent disclosed the incident to Barry during execution.
The initial progress message called these five source rows; precisely, they
were one header and four records, three of them later observations.

The worker reports that this was the only command displaying later records
and that they did not inform date selection, species selection, code, models
or interpretation. That is the worker's self-report; it is not independently
verified by a complete audit of its tool history. The development interval,
candidate list and intended descriptive diagnostics were already declared.

Independent inspection of the final adapter, date-boundary controls and
restricted output tables confirms that the calculations use only occasions
1–52 ending 2 June 2020. No later observations entered the tables or figures.
The cutoff-construction bug found during source review was repaired before
any empirical runner execution, according to the worker; the final parser
preflight and boundary tests passed. The output contains 50 x 9 x 52 cells,
with missing detections exactly where effort is zero.

## Consequence

The statement that later observations were excluded from this tranche's
analysis is supported. A statement that all later Judbury observations were
wholly unseen during this session is false and must not be made. Later
temporal assessment must disclose this limited row exposure alongside the
already known historical aggregate results. Do not selectively discard
affected folds or inspect further later outcomes in response to the incident.
Any stronger claim of a blind temporal confirmation requires explicit review
of the disclosure history. Huon Ridge has not been accessed and remains
the intended untouched external case.
