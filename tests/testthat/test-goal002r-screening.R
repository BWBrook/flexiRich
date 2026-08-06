testthat::test_that("screen rows are deterministic and exclude original checks", {
  original <- as.integer(round(seq(1, 4000, length.out = 25L)))

  first <- goal002r_screen_rows(4000L, original, n_additional = 100L)
  second <- goal002r_screen_rows(4000L, original, n_additional = 100L)

  testthat::expect_identical(first, second)
  testthat::expect_length(first, 100L)
  testthat::expect_false(any(first %in% original))
  testthat::expect_identical(anyDuplicated(first), 0L)
  testthat::expect_true(all(first >= 1L & first <= 4000L))
})

testthat::test_that("screen candidates and selection precedence are locked", {
  candidates <- goal002r_quadrature_candidates()
  testthat::expect_identical(
    candidates,
    tibble::tribble(
      ~method, ~order,
      "adaptive", 16L,
      "adaptive", 32L,
      "adaptive", 64L,
      "fixed", 256L
    )
  )

  screen <- tidyr::crossing(
    method = candidates$method,
    order = candidates$order,
    check = seq_len(3L)
  ) |>
    dplyr::filter(
      (method == "adaptive" & order %in% c(16L, 32L, 64L)) |
        (method == "fixed" & order == 256L)
    ) |>
    dplyr::mutate(passed = !(method == "adaptive" & order == 16L))

  selected <- goal002r_select_screen_candidate(screen)

  testthat::expect_identical(selected$method, "adaptive")
  testthat::expect_identical(selected$order, 32L)
})

testthat::test_that("fixed 256 is the only screening fallback", {
  candidates <- goal002r_quadrature_candidates()
  screen <- tidyr::crossing(
    candidate = seq_len(nrow(candidates)),
    check = seq_len(2L)
  ) |>
    dplyr::left_join(
      dplyr::mutate(candidates, candidate = dplyr::row_number()),
      by = "candidate"
    ) |>
    dplyr::mutate(passed = method == "fixed")

  selected <- goal002r_select_screen_candidate(screen)

  testthat::expect_identical(selected$method, "fixed")
  testthat::expect_identical(selected$order, 256L)
  testthat::expect_null(goal002r_select_screen_candidate(
    dplyr::mutate(screen, passed = FALSE)
  ))
})

testthat::test_that("terminal collapsed paths follow the clean attempt", {
  root <- tempfile("goal002r-screen-root-")

  testthat::expect_identical(
    goal002r_terminal_collapsed_path("small-easy", "primary_clean", root),
    file.path(root, "fits", "small-easy", "collapsed", "primary")
  )
  testthat::expect_identical(
    goal002r_terminal_collapsed_path("small-easy", "rescue_clean", root),
    file.path(root, "fits", "small-easy", "collapsed", "rescue")
  )
  testthat::expect_error(
    goal002r_terminal_collapsed_path(
      "small-easy", "final_nonclean", root
    ),
    "terminal-clean",
    fixed = TRUE
  )
})
