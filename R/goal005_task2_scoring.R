#' Score the no-data richness prior for one Goal005 Task 2 dataset
score_goal005_task2_prior <- function(dataset_row, truth) {
  if (!inherits(dataset_row, "data.frame") || nrow(dataset_row) != 1L ||
      !identical(names(dataset_row), .goal005_task2_dataset_fields)) {
    .goal005_stop("One frozen Goal005 Task 2 dataset row is required.")
  }
  .goal003_task4_validate_truth(truth)
  pmf <- goal004_beta_binomial_pmf(
    candidate_count = dataset_row$candidate_pool_size[[1L]],
    alpha = 1,
    beta = 1
  )
  score <- score_goal003_task4_prediction(
    dataset_id = dataset_row$dataset_id[[1L]],
    fit_id = NA_character_,
    method = "goal005_prior",
    run_role = "prior_only",
    terminal_clean = TRUE,
    truth = truth,
    richness_pmf = pmf
  )$richness
  dplyr::mutate(
    score,
    information_level = "P0",
    prior_profile = "uniform_membership",
    pool_profile = "core_50",
    candidate_pool_size = dataset_row$candidate_pool_size[[1L]],
    .after = run_role
  )
}

#' Score one Goal005 Task 2 information-ceiling fit
score_goal005_task2_fit <- function(
  fit_row,
  truth,
  terminal_clean,
  richness_pmf = NULL
) {
  if (!inherits(fit_row, "data.frame") || nrow(fit_row) != 1L ||
      !identical(names(fit_row), .goal005_task2_fit_fields)) {
    .goal005_stop("One frozen Goal005 Task 2 fit row is required.")
  }
  score <- score_goal003_task4_prediction(
    dataset_id = fit_row$dataset_id[[1L]],
    fit_id = fit_row$fit_id[[1L]],
    method = fit_row$method[[1L]],
    run_role = fit_row$run_role[[1L]],
    terminal_clean = terminal_clean,
    truth = truth,
    richness_pmf = richness_pmf
  )$richness
  dplyr::mutate(
    score,
    information_level = fit_row$information_level[[1L]],
    prior_profile = fit_row$prior_profile[[1L]],
    pool_profile = fit_row$pool_profile[[1L]],
    candidate_pool_size = fit_row$candidate_pool_size[[1L]],
    .after = run_role
  )
}
