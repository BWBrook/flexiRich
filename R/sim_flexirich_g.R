simulate_flexirich_g <- function(
  config = flexirich_sim_config(),
  effort_daily = NULL
) {
  config <- validate_sim_config(config)

  species <- tibble::tibble(
    species_id = sprintf(
      "sp_%03d",
      seq_len(config$candidate_pool_size)
    )
  )
  member_index <- withr::with_seed(config$seed + 101L, {
    if (config$true_richness == 0L) {
      integer()
    } else {
      sample.int(
        config$candidate_pool_size,
        config$true_richness,
        replace = FALSE
      )
    }
  })
  species$member <- seq_len(config$candidate_pool_size) %in% member_index
  species$alpha <- withr::with_seed(
    config$seed + 102L,
    stats::rnorm(
      config$candidate_pool_size,
      mean = config$mean_log_rate,
      sd = config$sd_log_rate
    )
  )

  cameras <- tibble::tibble(
    camera_id = sprintf("cam_%02d", seq_len(config$n_cameras)),
    camera_effect = withr::with_seed(
      config$seed + 201L,
      stats::rnorm(
        config$n_cameras,
        mean = 0,
        sd = config$sd_camera
      )
    )
  )

  rates <- tidyr::crossing(
    species_id = species$species_id,
    camera_id = cameras$camera_id
  ) |>
    dplyr::left_join(species, by = "species_id") |>
    dplyr::left_join(cameras, by = "camera_id") |>
    dplyr::mutate(encounter_rate = exp(alpha + camera_effect))
  if (any(!is.finite(rates$encounter_rate) | rates$encounter_rate <= 0)) {
    stop(
      "Configured effects must generate finite, positive encounter rates.",
      call. = FALSE
    )
  }

  if (is.null(effort_daily)) {
    effort_daily <- simulate_daily_effort(config)
  } else {
    effort_daily <- validate_daily_effort(effort_daily, config)
  }
  effort_weekly <- aggregate_weekly_effort(effort_daily, config)

  detections <- tidyr::crossing(
    species_id = species$species_id,
    effort_weekly
  ) |>
    dplyr::left_join(
      rates |>
        dplyr::select(
          species_id,
          camera_id,
          member,
          encounter_rate
        ),
      by = c("species_id", "camera_id")
    ) |>
    dplyr::mutate(
      sampled = active_days > 0L,
      detect_prob_if_member = -expm1(
        -active_days * encounter_rate
      ),
      detect_prob = as.numeric(member) * detect_prob_if_member
    )

  detections$detected <- withr::with_seed(config$seed + 401L, {
    value <- rep(NA_integer_, nrow(detections))
    sampled_rows <- which(detections$sampled)
    value[sampled_rows] <- stats::rbinom(
      length(sampled_rows),
      size = 1L,
      prob = detections$detect_prob[sampled_rows]
    )
    value
  })

  observed_species <- unique(detections$species_id[
    !is.na(detections$detected) & detections$detected == 1L
  ])
  observed_richness <- length(observed_species)
  truth <- tibble::tibble(
    candidate_pool_size = config$candidate_pool_size,
    true_richness = config$true_richness,
    observed_richness = as.integer(observed_richness),
    unseen_true_members = as.integer(
      config$true_richness - observed_richness
    ),
    nonmembers = as.integer(
      config$candidate_pool_size - config$true_richness
    ),
    total_detections = as.integer(
      sum(detections$detected, na.rm = TRUE)
    )
  )

  result <- list(
    config = config,
    species = species,
    cameras = cameras,
    rates = rates,
    effort_daily = effort_daily,
    effort_weekly = effort_weekly,
    detections = detections,
    truth = truth,
    metadata = list(
      simulator_version = "0.1.0",
      seed = config$seed,
      generated_at = format(Sys.time(), tz = "UTC", usetz = TRUE)
    )
  )
  class(result) <- c("flexirich_sim", "list")
  result
}
