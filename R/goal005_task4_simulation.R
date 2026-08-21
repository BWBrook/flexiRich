#' Simulate one fresh Goal005 Task 4 paired history
simulate_goal005_task4_dataset <- function(dataset_row, manifest) {
  valid <- inherits(dataset_row, "data.frame") &&
    nrow(dataset_row) == 1L &&
    identical(names(dataset_row), .goal005_task2_dataset_fields) &&
    is.list(manifest) &&
    all(c("scenarios", "datasets", "effort") %in% names(manifest))
  if (!valid) {
    .goal005_stop("One canonical Goal005 Task 4 dataset row is required.")
  }
  frozen <- manifest$datasets |>
    dplyr::filter(dataset_id == dataset_row$dataset_id)
  if (nrow(frozen) != 1L || !identical(dataset_row, frozen) ||
      dataset_row$simulation_seed[[1L]] !=
        680000000L + dataset_row$replicate[[1L]]) {
    .goal005_stop("The Goal005 Task 4 dataset row differs from its manifest.")
  }
  simulate_goal005_task2_dataset(dataset_row, manifest)
}
