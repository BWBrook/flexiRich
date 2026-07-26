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

rules <- goal002_prior_rules()
profiles <- goal002_prior_profiles()
effort_seed <- 62002001L
prior_seed <- c(
  primary = 62002101L,
  sensitivity_membership = 62002201L,
  sensitivity_tail = 62002301L
)
output_dir <- file.path("outputs", "goal002", "prior-predictive")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

effort <- goal002_prior_effort(seed = effort_seed)
saveRDS(
  effort,
  file.path(output_dir, "effort.rds"),
  version = 3L
)
utils::write.csv(
  effort$effort_weekly,
  file.path(output_dir, "effort-weekly.csv"),
  row.names = FALSE
)
utils::write.csv(
  data.frame(
    schema_version = effort$schema_version,
    effort_seed = effort$seed,
    effort_hash = effort$effort_hash,
    candidate_pool_size = effort$candidate_pool_size,
    n_cameras = effort$n_cameras,
    n_occasions = effort$n_occasions,
    prefix_occasions = effort$prefix_occasions,
    occasion_days = effort$occasion_days,
    stringsAsFactors = FALSE
  ),
  file.path(output_dir, "effort-provenance.csv"),
  row.names = FALSE
)

all_assessments <- vector("list", length(profiles))
all_manifests <- vector("list", length(profiles))
names(all_assessments) <- names(profiles)
names(all_manifests) <- names(profiles)

for (profile_key in names(profiles)) {
  message("Prior-predictive profile: ", profile_key)
  draws <- simulate_goal002_prior(
    profile = profiles[[profile_key]],
    effort = effort,
    n_draws = rules$n_draws,
    seed = unname(prior_seed[[profile_key]])
  )
  assessment <- assess_goal002_prior(draws)
  report <- goal002_prior_report(draws, assessment)
  profile_stub <- gsub("_", "-", profile_key, fixed = TRUE)

  saveRDS(
    report,
    file.path(output_dir, paste0(profile_stub, "-report.rds")),
    version = 3L
  )
  utils::write.csv(
    report$assessment,
    file.path(output_dir, paste0(profile_stub, "-assessment.csv")),
    row.names = FALSE
  )
  utils::write.csv(
    as.data.frame(report$profile, stringsAsFactors = FALSE),
    file.path(output_dir, paste0(profile_stub, "-profile.csv")),
    row.names = FALSE
  )
  utils::write.csv(
    report$richness_pmf,
    file.path(output_dir, paste0(profile_stub, "-richness-pmf.csv")),
    row.names = FALSE
  )
  utils::write.csv(
    report$quantiles,
    file.path(output_dir, paste0(profile_stub, "-quantiles.csv")),
    row.names = FALSE
  )
  utils::write.csv(
    report$boundary_frequencies,
    file.path(
      output_dir,
      paste0(profile_stub, "-boundary-frequencies.csv")
    ),
    row.names = FALSE
  )
  utils::write.csv(
    report$saturation_frequencies,
    file.path(
      output_dir,
      paste0(profile_stub, "-saturation-frequencies.csv")
    ),
    row.names = FALSE
  )

  all_assessments[[profile_key]] <- dplyr::mutate(
    report$assessment,
    profile_key = profile_key,
    profile_id = report$profile_id,
    .before = 1L
  )
  failed_rules <- report$assessment$rule_id[
    !report$assessment$passed
  ]
  all_manifests[[profile_key]] <- tibble::tibble(
    schema_version = report$schema_version,
    profile_key = profile_key,
    profile_id = report$profile_id,
    profile_hash = report$profile_hash,
    effort_seed = report$effort_seed,
    effort_hash = report$effort_hash,
    simulation_seed = report$simulation_seed,
    n_draws = report$n_draws,
    automatic_outcome = report$automatic_outcome,
    failed_rules = paste(failed_rules, collapse = ";")
  )

  rm(draws, assessment, report)
  invisible(gc(verbose = FALSE))
}

assessment_table <- dplyr::bind_rows(all_assessments)
manifest <- dplyr::bind_rows(all_manifests)
utils::write.csv(
  assessment_table,
  file.path(output_dir, "automatic-assessment.csv"),
  row.names = FALSE
)
utils::write.csv(
  manifest,
  file.path(output_dir, "run-manifest.csv"),
  row.names = FALSE
)
saveRDS(
  list(
    schema_version = .goal002_prior_schema_version,
    rules = rules,
    effort_hash = effort$effort_hash,
    effort_seed = effort_seed,
    prior_seed = prior_seed,
    manifest = manifest,
    assessment = assessment_table
  ),
  file.path(output_dir, "prior-check-index.rds"),
  version = 3L
)

print(
  manifest |>
    dplyr::select(
      profile_key,
      profile_id,
      automatic_outcome,
      failed_rules
    ),
  n = Inf
)

if (any(manifest$automatic_outcome == "rejected_automatically")) {
  stop(
    paste0(
      "At least one prior profile failed an automatic numerical or ",
      "design-informativeness rule. No ecological verdict was inferred."
    ),
    call. = FALSE
  )
}

message(
  "All profiles avoided automatic rejection. ",
  "Ecological plausibility still requires the separate dated PI decision."
)
