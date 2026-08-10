# Goal002R oracle-stability adjudication

Status: completed — outcome C / `CLOSE`; no rerun
Version: 2
Executed: 2026-08-09 07:17:37 UTC

## Question

The stopped decision-scale preflight observed a
`1.0477378964424133e-09` endpoint-expansion change in the reconstructed sigma
derivative at:

- `a = 10`;
- `sigma_alpha = 0.01356952703481304`; and
- `U = 29` unseen candidates.

That change marginally exceeded the frozen absolute `1e-9` oracle-stability
limit. The adjudication asked only whether the discrepancy was
decision-negligible and compatible with the current base-R numerical
resolution at this exact state. It did not evaluate either Gauss--Hermite
candidate, another protected-domain state, or any ecological assumption.

## Frozen disposition

The Version 2 contract allowed one execution:

- A would permit planning a separately reviewed oracle-contract amendment;
- B would support oracle instability and `CLOSE`; and
- C would be inconclusive and `CLOSE` without changing controls or rerunning.

The historical order-128 `REJECT` and the failed `1e-9` check were protected
under every outcome.

## Result

The single execution passed:

- `X01_output_absent`;
- `X02_sources_committed_clean`; and
- `X03_provenance_available`.

It failed `X04_in_memory_schema`. Under the frozen tree this is outcome C:
inconclusive, `CLOSE`, with no rerun of this diagnostic or the full preflight.
Decision-only publication passed `X05_evidence_publish`.

The final output contained only `decision.txt`; neither planned CSV evidence
table was published, and no staging directory remained. The result therefore
does not identify which composite X04 requirement failed and supplies no
validated primitive, derivative, uncertainty, convergence, or candidate
evidence. It cannot support outcome A or B, amend the numerical contract,
select a candidate order, or alter the prior `REJECT`.

Resolving X04 would require a newly designed and authorised scientific tranche,
not a rerun of Version 2. Goal002R instead closed and its executable path was
retired.

## Provenance

- execution Git HEAD:
  `26d6fd8b527d1bcc98a33ba18a828dfe96ca007d`
- R: `R version 4.6.1 (2026-06-24)` on `x86_64-pc-linux-gnu`
- runner SHA-256:
  `7bc05949f13af9d2e5a55348b0bbf156fddd99bdd126f0189c34bb1ff888a497`
- `config.R` SHA-256:
  `d8c1ff7884b3711a057f5af51d342f88cf54574394e7fc7093074c4ef8c3e6fd`
- `math.R` SHA-256:
  `7d9d1b1f6c5ebcfbea5b4537d274281974757d868d6fa3fef22339189ae3f131`
- `preflight_math.R` SHA-256:
  `d97f36397a356fd062f7267651e7594d6f0ff39b2cca386acc176bdb45fd7908`
- decision SHA-256:
  `f41cf0c1ec002f8c27b33323da589402e1f22900c099b5d4316e37cd6c1f9846`

The complete implementation and superseded adjudication contract remain
recoverable from Git history at and before closure commit `f2a7f4a`.
