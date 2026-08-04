testthat::test_that("collapsed data partitions detected and unseen candidates", {
  fixture <- goal002_oracle_fixture(C = 4L)
  collapsed <- prepare_flexirich_g_collapsed_data(fixture$data)

  testthat::expect_identical(
    c(collapsed$detected_ids, collapsed$unseen_ids),
    collapsed$candidate_ids
  )
  testthat::expect_identical(
    collapsed$detected_ids,
    c("sp_01", "sp_02")
  )
  testthat::expect_identical(
    collapsed$unseen_ids,
    c("sp_03", "sp_04")
  )
  testthat::expect_equal(
    collapsed$zero_history$n_trials,
    c(1L, 1L, 1L, 1L, 1L)
  )
  testthat::expect_true(validate_flexirich_g_collapsed_data(collapsed))
})

testthat::test_that("collapsed data is invariant to input row ordering", {
  fixture <- goal002_oracle_fixture(C = 4L)
  shuffled <- fixture$inputs
  shuffled$candidate_pool <- shuffled$candidate_pool[4:1, , drop = FALSE]
  shuffled$effort_weekly <- shuffled$effort_weekly[
    rev(seq_len(nrow(shuffled$effort_weekly))),
    ,
    drop = FALSE
  ]
  shuffled$detections <- shuffled$detections[
    rev(seq_len(nrow(shuffled$detections))),
    ,
    drop = FALSE
  ]

  reference <- prepare_flexirich_g_collapsed_data(fixture$data)
  alternative <- prepare_flexirich_g_collapsed_data(
    prepare_flexirich_g_data(
      shuffled$candidate_pool,
      shuffled$effort_weekly,
      shuffled$detections
    )
  )
  testthat::expect_identical(reference$data_hash, alternative$data_hash)
  testthat::expect_identical(reference$zero_history, alternative$zero_history)
})

testthat::test_that("collapsed data preserves the zero-effort firewall", {
  fixture <- goal002_oracle_fixture(C = 4L)
  bad <- fixture$inputs$detections
  bad$detected[which(is.na(bad$detected))[1L]] <- 0L
  testthat::expect_error(
    prepare_flexirich_g_data(
      fixture$inputs$candidate_pool,
      fixture$inputs$effort_weekly,
      bad
    ),
    "missing at zero effort",
    fixed = TRUE
  )
})

testthat::test_that("the zero-unseen case has an empty tail history", {
  fixture <- goal002_oracle_fixture(C = 4L)
  detections <- fixture$inputs$detections
  positive <- vapply(
    c("sp_03", "sp_04"),
    function(species_id) which(
      detections$species_id == species_id &
        !is.na(detections$detected)
    )[1L],
    integer(1)
  )
  detections$detected[positive] <- 1L
  collapsed <- prepare_flexirich_g_collapsed_data(
    prepare_flexirich_g_data(
      fixture$inputs$candidate_pool,
      fixture$inputs$effort_weekly,
      detections
    )
  )
  testthat::expect_length(collapsed$unseen_ids, 0L)
  testthat::expect_equal(nrow(collapsed$zero_history), 0L)
  testthat::expect_equal(
    goal002r_log_m0(collapsed$zero_history, 0, 1, c(cam_01 = 0, cam_02 = 0)),
    0
  )
})
