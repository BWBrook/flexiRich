if (!dir.exists("R") || !file.exists("renv.lock")) {
  stop("Run this script from the flexiRich repository root.", call. = FALSE)
}

for (path in sort(list.files("R", pattern = "[.]R$", full.names = TRUE))) {
  source(path, local = FALSE)
}

manifest <- read_goal005_task2_manifests()
rows <- lapply(c("aligned_low", "aligned_mid", "aligned_high"), function(id) {
  manifest$datasets |>
    dplyr::filter(
      scenario_id == .env$id,
      train_occasions == 12L,
      replicate == 1L
    )
})
simulations <- lapply(rows, simulate_goal005_task2_dataset, manifest = manifest)
members <- lapply(simulations, function(x) x$truth$species$member)
rates <- lapply(simulations, function(x) x$truth$species$alpha)
cameras <- lapply(simulations, function(x) x$truth$cameras$camera_effect)
checks <- tibble::tibble(
  check = c(
    "frozen_manifest_shape",
    "nested_membership",
    "paired_candidate_rates",
    "paired_camera_effects",
    "training_data_excludes_truth",
    "oracle_data_exposes_only_fixed_rate_truth"
  ),
  passed = c(
    nrow(manifest$datasets) == 180L && nrow(manifest$fits) == 360L,
    all(members[[1L]] <= members[[2L]]) &&
      all(members[[2L]] <= members[[3L]]),
    identical(rates[[1L]], rates[[2L]]) &&
      identical(rates[[2L]], rates[[3L]]),
    identical(cameras[[1L]], cameras[[2L]]) &&
      identical(cameras[[2L]], cameras[[3L]]),
    all(vapply(simulations, function(x) {
      !any(c("truth", "member", "true_richness", "alpha_fixed") %in%
        names(x$training_data))
    }, logical(1))),
    {
      oracle <- prepare_goal005_candidate_oracle_data(
        simulations[[2L]]$training_data,
        stats::setNames(
          simulations[[2L]]$truth$species$alpha,
          simulations[[2L]]$truth$species$species_id
        )
      )
      "alpha_fixed" %in% names(oracle) &&
        !any(c("truth", "member", "true_richness") %in% names(oracle))
    }
  )
)
if (!all(checks$passed)) {
  print(checks)
  stop("Goal005 Task 2 execution contract failed.", call. = FALSE)
}
cat("Goal005 Task 2 execution contract: PASS\n")
print(checks)
