if (!dir.exists("R")) {
  stop(
    "Run this script from the flexiRich repository root.",
    call. = FALSE
  )
}

for (path in sort(list.files(
  "R",
  pattern = "\\.R$",
  full.names = TRUE
))) {
  source(path, local = FALSE)
}

effort_seed <- 62002001L
prior_seed <- c(
  primary = 62002101L,
  sensitivity_membership = 62002201L,
  sensitivity_tail = 62002301L
)
result <- run_goal002_prior_checks(
  output_dir = file.path(
    "outputs",
    "goal002",
    "prior-predictive"
  ),
  effort_seed = effort_seed,
  prior_seed = prior_seed,
  n_draws = goal002_prior_rules()$n_draws,
  verbose = TRUE
)

print(
  result$manifest |>
    dplyr::select(
      profile_key,
      profile_id,
      automatic_outcome,
      failed_rules
    ),
  n = Inf
)

if (result$automatic_rejected) {
  stop(
    paste0(
      "At least one prior profile failed an automatic numerical or ",
      "design-informativeness rule. Complete evidence was published; ",
      "no ecological verdict was inferred."
    ),
    call. = FALSE
  )
}

message(
  "All profiles avoided automatic rejection. ",
  "Ecological plausibility still requires the separate dated PI decision."
)
