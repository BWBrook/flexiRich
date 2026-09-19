testthat::test_that("Goal011 paths preserve posterior pairing, membership and nested horizons", {
  p <- array(c(.2,.8,0,0, .4,.9,1,1),c(2,2,2))
  f <- list(per_draw=list(log_detection=log(p)),
    metadata=list(candidate_ids=c("a","b"),horizons=c(1L,2L)),
    species_probabilities=data.frame(species_id=c("a","b"),known_member=c(FALSE,TRUE)))
  set.seed(22); old <- .Random.seed
  x <- goal011_draw_paths(f,7400991L)
  testthat::expect_identical(.Random.seed,old)
  testthat::expect_identical(x,goal011_draw_paths(f,7400991L))
  testthat::expect_equal(x$redetection,c(0,0,1,1))
  testthat::expect_equal(x$all_detection,x$totaldiscovery+x$redetection)
  testthat::expect_true(all(x$totaldiscovery[3:4]>=x$totaldiscovery[1:2]))
  # Degenerate zero/one events share their original joint draw, not independent
  # posterior indices for species or horizons.
  f$per_draw$log_detection <- log(array(c(0,1,0,1,0,1,0,1),c(2,2,2)))
  y <- goal011_draw_paths(f,7400992L)
  testthat::expect_equal(y$all_detection,c(0,2,0,2))
})


testthat::test_that("Goal011 core integer membership flags select the right path columns", {
  d <- list(q_member=matrix(c(.5,1,1),1),alpha=matrix(c(-1000,log(1000),-1000),1),
    camera_effect=matrix(0,1),candidate_ids=c("unseen","seen_yes","seen_no"),camera_ids="cam")
  labels <- data.frame(species_id=d$candidate_ids,taxon_class="Mammalia",encounter_class="routine")
  e <- data.frame(camera_id="cam",future_week=1L,active_days=1L)
  f <- goal011_forecast(d,c(0L,1L,1L),e,1L,labels)
  x <- goal011_draw_paths(f,7400993L)
  testthat::expect_equal(x$redetection,1)
  testthat::expect_equal(x$totaldiscovery,0)
  testthat::expect_equal(x$all_detection,1)
})
