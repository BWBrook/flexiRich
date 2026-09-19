# Independent pre-generation audit

19 September 2026. A separate scientific auditor reviewed the contract, source,
synthetic tests, saved parent inputs and six-model integration smoke. Verdict:
**GO to freeze source and generate predictions.** No remaining pre-generation
blocker. This is not clearance to read later outcomes.

The audit independently verified:

- first-year identity and the 21 known/29 unseen split; reviewed future effort,
  all SHA-256 input receipts, calendar endpoints, model roles and fixed scores;
- baseline and spatial-primary conditional probabilities against separate
  established/direct station-rate calculations (max errors 1.11e-16 and
  2.22e-16), and discovery-count PMFs (1.11e-16 and 8.33e-17);
- tested count mass normalization to 6.66e-16, event complement mass to 2.22e-16,
  exact equality of pooled unseen marginals, and first-bin sums versus final
  cumulative probability to 4.16e-17;
- log-domain tails, joint-draw pairing, conditional Poisson-binomial integration,
  exchangeable hypergeometric subgroup splits, nested count paths, true-zero
  score behaviour and numerical-range rejection;
- all final targeted tests, the six-real-artifact two-draw integration smoke,
  shell syntax and shellcheck.

Review and parent integration caught and resolved draft issues before freezing:
integer membership flags used as column indices; scorer reconstruction from
unpooled unseen draw columns; missing integrated non-detection logs; numeric
versus integer return contracts; and saturated first-bin/numerical overflow
handling. The final scoring function uses only the frozen probability tables
and labels and checks event/count normalization. No later outcomes were read.

Before outcome access, the actual all-draw predictive objects must be verified
against output hashes, checked for normalization, nesting and exchangeability,
archived and committed, and independently cleared. The generation verdict does
not certify those as-yet-unproduced objects or future predictive adequacy.
