.goal002_cmdstan_version <- "2.38.0"

.goal002_prior_fields <- c(
  "profile_id",
  "omega_alpha",
  "omega_beta",
  "mu_alpha_location",
  "mu_alpha_scale",
  "sigma_alpha_scale",
  "sigma_camera_scale"
)

.goal002_sampler_fields <- c(
  "profile_id",
  "chains",
  "parallel_chains",
  "iter_warmup",
  "iter_sampling",
  "adapt_delta",
  "max_treedepth",
  "refresh"
)

.goal002_assert_profile_id <- function(x) {
  valid <- is.character(x) && length(x) == 1L && !is.na(x) && nzchar(x)
  if (!valid) {
    stop("profile_id must be one non-empty character value.", call. = FALSE)
  }
  x
}

.goal002_assert_numeric <- function(x, name, positive = FALSE) {
  valid <- is.numeric(x) && !is.complex(x) && length(x) == 1L &&
    !is.na(x) && is.finite(x)
  if (positive) {
    valid <- valid && x > 0
  }
  if (!valid) {
    qualifier <- if (positive) "positive " else ""
    stop(name, " must be one finite ", qualifier, "number.", call. = FALSE)
  }
  as.numeric(x)
}

.goal002_assert_integer <- function(x, name, lower = 1L, upper = Inf) {
  valid <- is.numeric(x) && !is.complex(x) && length(x) == 1L &&
    !is.na(x) && is.finite(x) && x == trunc(x) &&
    x >= -.Machine$integer.max && x <= .Machine$integer.max &&
    x >= lower && x <= upper
  if (!valid) {
    stop(
      name, " must be one finite, representable integer in [",
      lower, ", ", upper, "].",
      call. = FALSE
    )
  }
  as.integer(x)
}

.goal002_canonicalise_profile <- function(profile, fields) {
  if (!is.list(profile)) {
    stop("profile must be a list.", call. = FALSE)
  }

  profile_fields <- names(profile)
  if (is.null(profile_fields) ||
      anyNA(profile_fields) ||
      any(!nzchar(profile_fields))) {
    stop("profile fields must all be named.", call. = FALSE)
  }

  duplicate_fields <- unique(profile_fields[duplicated(profile_fields)])
  if (length(duplicate_fields) > 0L) {
    stop(
      "profile has duplicate fields: ",
      paste(duplicate_fields, collapse = ", "),
      ".",
      call. = FALSE
    )
  }

  missing_fields <- setdiff(fields, profile_fields)
  if (length(missing_fields) > 0L) {
    stop(
      "profile is missing fields: ",
      paste(missing_fields, collapse = ", "),
      ".",
      call. = FALSE
    )
  }

  extra_fields <- setdiff(profile_fields, fields)
  if (length(extra_fields) > 0L) {
    stop(
      "profile has unexpected fields: ",
      paste(extra_fields, collapse = ", "),
      ".",
      call. = FALSE
    )
  }

  stats::setNames(
    lapply(fields, function(field) profile[[field]]),
    fields
  )
}

goal002_prior_profiles <- function() {
  primary <- list(
    profile_id = "primary-v1",
    omega_alpha = 1,
    omega_beta = 1,
    mu_alpha_location = log(1e-3),
    mu_alpha_scale = 2,
    sigma_alpha_scale = 1.5,
    sigma_camera_scale = 0.75
  )

  list(
    primary = primary,
    sensitivity_membership = utils::modifyList(
      primary,
      list(
        profile_id = "sensitivity-membership-v1",
        omega_alpha = 0.5,
        omega_beta = 0.5
      )
    ),
    sensitivity_tail = utils::modifyList(
      primary,
      list(
        profile_id = "sensitivity-tail-v2",
        mu_alpha_scale = 2.5,
        sigma_alpha_scale = 1.75
      )
    )
  )
}

goal002_sampler_profiles <- function() {
  list(
    primary = list(
      profile_id = "primary-sampler-v1",
      chains = 4L,
      parallel_chains = 4L,
      iter_warmup = 1000L,
      iter_sampling = 1000L,
      adapt_delta = 0.90,
      max_treedepth = 12L,
      refresh = 100L
    ),
    rescue = list(
      profile_id = "rescue-sampler-v1",
      chains = 4L,
      parallel_chains = 4L,
      iter_warmup = 1500L,
      iter_sampling = 1500L,
      adapt_delta = 0.99,
      max_treedepth = 15L,
      refresh = 100L
    )
  )
}

goal002_diagnostic_thresholds <- function() {
  list(
    max_divergences = 0L,
    max_treedepth_hits = 0L,
    min_ebfmi = 0.3,
    max_rhat = 1.01,
    min_bulk_ess = 400,
    min_tail_ess = 400
  )
}

validate_goal002_profile <- function(profile, type) {
  valid_type <- is.character(type) && length(type) == 1L &&
    !is.na(type) && type %in% c("prior", "sampler")
  if (!valid_type) {
    stop("type must be exactly one of 'prior' or 'sampler'.", call. = FALSE)
  }

  if (identical(type, "prior")) {
    profile <- .goal002_canonicalise_profile(
      profile,
      .goal002_prior_fields
    )
    profile$profile_id <- .goal002_assert_profile_id(profile$profile_id)
    profile$omega_alpha <- .goal002_assert_numeric(
      profile$omega_alpha,
      "omega_alpha",
      positive = TRUE
    )
    profile$omega_beta <- .goal002_assert_numeric(
      profile$omega_beta,
      "omega_beta",
      positive = TRUE
    )
    profile$mu_alpha_location <- .goal002_assert_numeric(
      profile$mu_alpha_location,
      "mu_alpha_location"
    )
    profile$mu_alpha_scale <- .goal002_assert_numeric(
      profile$mu_alpha_scale,
      "mu_alpha_scale",
      positive = TRUE
    )
    profile$sigma_alpha_scale <- .goal002_assert_numeric(
      profile$sigma_alpha_scale,
      "sigma_alpha_scale",
      positive = TRUE
    )
    profile$sigma_camera_scale <- .goal002_assert_numeric(
      profile$sigma_camera_scale,
      "sigma_camera_scale",
      positive = TRUE
    )
    return(profile)
  }

  profile <- .goal002_canonicalise_profile(
    profile,
    .goal002_sampler_fields
  )
  profile$profile_id <- .goal002_assert_profile_id(profile$profile_id)
  profile$chains <- .goal002_assert_integer(
    profile$chains,
    "chains",
    lower = 4L,
    upper = 4L
  )
  profile$parallel_chains <- .goal002_assert_integer(
    profile$parallel_chains,
    "parallel_chains",
    lower = 1L,
    upper = min(4L, profile$chains)
  )
  profile$iter_warmup <- .goal002_assert_integer(
    profile$iter_warmup,
    "iter_warmup"
  )
  profile$iter_sampling <- .goal002_assert_integer(
    profile$iter_sampling,
    "iter_sampling"
  )
  profile$adapt_delta <- .goal002_assert_numeric(
    profile$adapt_delta,
    "adapt_delta"
  )
  if (profile$adapt_delta <= 0 || profile$adapt_delta >= 1) {
    stop("adapt_delta must be strictly between 0 and 1.", call. = FALSE)
  }
  profile$max_treedepth <- .goal002_assert_integer(
    profile$max_treedepth,
    "max_treedepth"
  )
  profile$refresh <- .goal002_assert_integer(
    profile$refresh,
    "refresh",
    lower = 0L
  )
  profile
}

.goal002_cmdstan_status <- function(
  available,
  required_version,
  installed_version = NA_character_,
  path = NA_character_
) {
  list(
    available = available,
    required_version = required_version,
    installed_version = installed_version,
    path = path,
    matches = isTRUE(
      available &&
        identical(installed_version, required_version)
    )
  )
}

check_goal002_cmdstan <- function(
  required_version = .goal002_cmdstan_version,
  error = TRUE
) {
  valid_version <- is.character(required_version) &&
    length(required_version) == 1L &&
    !is.na(required_version) &&
    nzchar(required_version)
  if (!valid_version) {
    stop(
      "required_version must be one non-empty character value.",
      call. = FALSE
    )
  }
  if (!is.logical(error) || length(error) != 1L || is.na(error)) {
    stop("error must be TRUE or FALSE.", call. = FALSE)
  }

  fail <- function(message, status) {
    if (error) {
      stop(message, call. = FALSE)
    }
    status
  }

  if (!requireNamespace("cmdstanr", quietly = TRUE)) {
    status <- .goal002_cmdstan_status(FALSE, required_version)
    return(fail(
      paste0(
        "The cmdstanr package is unavailable; restore the project renv ",
        "before checking CmdStan."
      ),
      status
    ))
  }

  path <- tryCatch(
    cmdstanr::cmdstan_path(),
    error = function(e) NA_character_
  )
  if (!is.character(path) || length(path) != 1L ||
      is.na(path) || !nzchar(path) || !dir.exists(path)) {
    status <- .goal002_cmdstan_status(
      FALSE,
      required_version,
      path = if (is.character(path) && length(path) == 1L) {
        path
      } else {
        NA_character_
      }
    )
    return(fail(
      paste0(
        "No valid CmdStan path is available. Install CmdStan ",
        required_version,
        " explicitly with: Rscript scripts/setup_cmdstan.R --install"
      ),
      status
    ))
  }

  installed_version <- tryCatch(
    as.character(cmdstanr::cmdstan_version()),
    error = function(e) NA_character_
  )
  version_available <- is.character(installed_version) &&
    length(installed_version) == 1L &&
    !is.na(installed_version) &&
    nzchar(installed_version)
  status <- .goal002_cmdstan_status(
    version_available,
    required_version,
    installed_version = if (version_available) {
      installed_version
    } else {
      NA_character_
    },
    path = path
  )

  if (!version_available) {
    return(fail(
      paste0(
        "The installed CmdStan version could not be determined at ",
        path,
        "."
      ),
      status
    ))
  }
  if (!status$matches) {
    return(fail(
      paste0(
        "CmdStan ", required_version, " is required; installed version is ",
        installed_version, ". Install explicitly with: ",
        "Rscript scripts/setup_cmdstan.R --install"
      ),
      status
    ))
  }

  status
}
