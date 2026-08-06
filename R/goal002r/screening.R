goal002r_screen_rows <- function(
  draw_count,
  original_rows,
  n_additional = 100L
) {
  draw_count <- as.integer(.goal002r_scalar(
    draw_count, "draw_count", lower = 1
  ))
  n_additional <- as.integer(.goal002r_scalar(
    n_additional, "n_additional", lower = 1
  ))
  if (!is.numeric(original_rows) || anyNA(original_rows) ||
      any(original_rows != trunc(original_rows)) ||
      any(original_rows < 1L | original_rows > draw_count)) {
    .goal002r_stop("original_rows must be valid posterior row indices.")
  }
  available <- setdiff(seq_len(draw_count), as.integer(original_rows))
  if (length(available) < n_additional) {
    .goal002r_stop("Too few posterior rows remain for numerical screening.")
  }
  index <- as.integer(round(seq(
    1,
    length(available),
    length.out = n_additional
  )))
  rows <- available[index]
  if (anyDuplicated(rows)) {
    .goal002r_stop("Deterministic screening row selection produced duplicates.")
  }
  rows
}

goal002r_quadrature_candidates <- function() {
  tibble::tribble(
    ~method, ~order,
    "adaptive", 16L,
    "adaptive", 32L,
    "adaptive", 64L,
    "fixed", 256L
  )
}

goal002r_select_screen_candidate <- function(screen) {
  if (!tibble::is_tibble(screen) ||
      !all(c("method", "order", "passed") %in% names(screen)) ||
      nrow(screen) == 0L || !is.logical(screen$passed) ||
      anyNA(screen$passed)) {
    .goal002r_stop("screen has an invalid candidate-selection contract.")
  }
  candidates <- goal002r_quadrature_candidates()
  candidate_passed <- vapply(seq_len(nrow(candidates)), function(index) {
    rows <- screen$method == candidates$method[index] &
      screen$order == candidates$order[index]
    any(rows) && all(screen$passed[rows])
  }, logical(1))
  selected <- which(candidate_passed)[1L]
  if (is.na(selected)) return(NULL)
  candidates[selected, , drop = FALSE]
}

goal002r_terminal_collapsed_path <- function(
  case_id,
  terminal_status,
  output_root
) {
  if (!is.character(case_id) || length(case_id) != 1L ||
      is.na(case_id) || !nzchar(case_id) ||
      !is.character(output_root) || length(output_root) != 1L ||
      is.na(output_root) || !nzchar(output_root)) {
    .goal002r_stop("Terminal collapsed path inputs are invalid.")
  }
  attempt <- switch(
    terminal_status,
    primary_clean = "primary",
    rescue_clean = "rescue",
    NULL
  )
  if (is.null(attempt)) {
    .goal002r_stop("Numerical screening requires a terminal-clean fit.")
  }
  file.path(output_root, "fits", case_id, "collapsed", attempt)
}

goal002r_read_terminal_collapsed_draws <- function(
  case_id,
  terminal_status,
  output_root
) {
  path <- goal002r_terminal_collapsed_path(
    case_id,
    terminal_status,
    output_root
  )
  files <- sort(Sys.glob(file.path(path, "fit-[1-4].csv")))
  if (length(files) != 4L || any(!file.exists(files))) {
    .goal002r_stop(paste0(
      "Expected four saved collapsed-fit CSVs for ", case_id, "."
    ))
  }
  parsed <- cmdstanr::read_cmdstan_csv(
    files,
    variables = c("mu_alpha", "sigma_alpha", "camera_effect"),
    sampler_diagnostics = NULL
  )
  posterior::as_draws_matrix(parsed$post_warmup_draws)
}

.goal002r_screen_one_value <- function(
  method,
  order,
  zero_history,
  mu_alpha,
  sigma_alpha,
  camera_effect
) {
  rule <- goal002r_gauss_hermite_rule(order)
  if (identical(method, "adaptive")) {
    goal002r_log_m0_adaptive(
      zero_history,
      mu_alpha,
      sigma_alpha,
      camera_effect,
      rule
    )
  } else {
    goal002r_log_m0_fixed(
      zero_history,
      mu_alpha,
      sigma_alpha,
      camera_effect,
      rule
    )
  }
}

goal002r_screen_quadrature <- function(
  v1_output_root = file.path(
    goal002r_project_root(),
    goal002r_contract()$output_root,
    "paired-comparison"
  ),
  output_file = NULL
) {
  case_file <- file.path(v1_output_root, "case-results.csv")
  check_file <- file.path(v1_output_root, "quadrature-checks.csv")
  if (!file.exists(case_file) || !file.exists(check_file)) {
    .goal002r_stop("Version-1 paired-comparison evidence is incomplete.")
  }
  if (!is.null(output_file) && file.exists(output_file)) {
    .goal002r_stop("The numerical-screen output already exists.")
  }
  case_results <- utils::read.csv(case_file, check.names = FALSE)
  original_checks <- utils::read.csv(check_file, check.names = FALSE)
  specifications <- goal002r_paired_cases()
  if (!setequal(case_results$case_id, specifications$case_id)) {
    .goal002r_stop("Version-1 evidence does not contain the six locked cases.")
  }
  candidates <- goal002r_quadrature_candidates()
  results <- lapply(seq_len(nrow(specifications)), function(case_index) {
    case_id <- specifications$case_id[case_index]
    prepared <- goal002r_prepare_paired_case(
      specifications[case_index, , drop = FALSE]
    )
    case_row <- case_results[case_results$case_id == case_id, , drop = FALSE]
    draws <- goal002r_read_terminal_collapsed_draws(
      case_id,
      case_row$collapsed_terminal_status,
      v1_output_root
    )
    original_rows <- original_checks$posterior_row[
      original_checks$case_id == case_id
    ]
    if (length(original_rows) != 25L || anyDuplicated(original_rows)) {
      .goal002r_stop("Each version-1 case must contribute 25 original checks.")
    }
    additional_rows <- goal002r_screen_rows(
      nrow(draws),
      original_rows,
      n_additional = 100L
    )
    rows <- c(as.integer(original_rows), additional_rows)
    sources <- c(rep("original", 25L), rep("additional", 100L))
    camera_names <- sprintf(
      "camera_effect[%d]",
      seq_along(prepared$collapsed_data$camera_ids)
    )
    required <- c("mu_alpha", "sigma_alpha", camera_names)
    if (!all(required %in% colnames(draws))) {
      .goal002r_stop("Saved collapsed draws lack numerical-screen variables.")
    }
    dplyr::bind_rows(lapply(seq_along(rows), function(check_index) {
      row <- rows[check_index]
      camera_effect <- stats::setNames(
        as.numeric(draws[row, camera_names]),
        prepared$collapsed_data$camera_ids
      )
      reference <- goal002r_reference_log_m0(
        prepared$collapsed_data$zero_history,
        draws[row, "mu_alpha"],
        draws[row, "sigma_alpha"],
        camera_effect
      )$log_m0
      dplyr::bind_rows(lapply(seq_len(nrow(candidates)), function(index) {
        value <- .goal002r_screen_one_value(
          candidates$method[index],
          candidates$order[index],
          prepared$collapsed_data$zero_history,
          draws[row, "mu_alpha"],
          draws[row, "sigma_alpha"],
          camera_effect
        )
        error <- abs(value - reference)
        tibble::tibble(
          case_id = case_id,
          check_source = sources[check_index],
          posterior_row = as.integer(row),
          method = candidates$method[index],
          order = candidates$order[index],
          log_m0 = value,
          log_m0_reference = reference,
          absolute_error = error,
          passed = is.finite(error) && error <= 1e-8
        )
      }))
    }))
  })
  screen <- dplyr::bind_rows(results)
  selected <- goal002r_select_screen_candidate(screen)
  if (!is.null(output_file)) {
    dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)
    utils::write.csv(screen, output_file, row.names = FALSE)
  }
  list(screen = screen, selected = selected)
}
