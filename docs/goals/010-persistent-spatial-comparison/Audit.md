# Goal010 pre-run audit

18 September 2026. Separate methodological specialist reviewed the design and
implementation; parent reviewed the code and integrated the findings. This is
an internal independent review, not Fable's external review or validation of
future results.

Resolved before fitting:

- Preserve row centring only; do not impose candidate-wide column centring.
  Proper priors regularise the b/u decomposition but do not identify it through
  the likelihood. The design records this limitation and diagnostic outputs.
- Explicitly interpret alpha as a fixed-array log mean. New-station transfer
  is not implied. Distinguish tau's marginal station SD from sigma_camera's
  contrast-coefficient SD.
- Keep the wider interaction-prior stress case, acknowledging the infinite
  arithmetic rate moment and using bounded detection summaries instead.
- Correct the runner's missing data argument for monitored variables. Check mode
  now exercises all eight adapter/monitor contracts before compilation.
- Correct a draft PPC thinning defect: u must use exactly the same posterior
  draw indices as alpha, b and membership probabilities. A draw-varying fixture
  compares automatic thinning with manual joint subsetting.
- Strip posterior::draws_matrix explicitly during vector extraction, verified
  against ordinary matrices with the posterior namespace loaded.
- Add direct saved-fit Stan/R likelihood and membership checks before PPCs,
  including station-log-rate and row-centering identities. Fake-fit tests must
  detect corrupted transformed quantities; actual bridge results come from the
  remote fits and are not claimed in advance.
- Restore and hash-check the gitignored first-year tables in the isolated remote
  checkout; never depend on untracked contents of an older checkout.

Scientific interpretation must retain two limits: improving the spatial fit of
observed species does not validate inference on 29 all-zero candidates, and a
static grouped likelihood remains calendar-exchangeable. The timing failure
therefore remains a distinct question even if spatial checks improve.

Verification status and the actual frozen source identifier are recorded in
`Verification.md` and remote `run-metadata.txt`, respectively.
