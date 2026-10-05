# Goal013 temporal mechanism comparison.
#
# The C++ helper is deliberately loaded only when probabilities are requested.
# Sourcing all R files therefore does not compile code or create derived output.

.goal013_env <- new.env(parent = emptyenv())
.goal013_root <- function() {
  for (candidate in c(".", "..", "../..", "../../..")) {
    if (file.exists(file.path(candidate, "src", "goal013_mechanisms.cpp"))) return(normalizePath(candidate, mustWork = TRUE))
  }
  stop("Goal013 repository root cannot be located.", call. = FALSE)
}

.goal013_model <- function(model) {
  if (!is.character(model) || length(model) != 1L || is.na(model)) {
    stop("Goal013 model must be one of static, harmonic, array, or station.", call. = FALSE)
  }
  key <- tolower(model)
  aliases <- c(`static` = "static", `harmonic` = "harmonic",
               `array` = "array", `station` = "station")
  out <- unname(aliases[[key]])
  if (is.null(out) || is.na(out)) {
    stop("Goal013 model must be one of static, harmonic, array, or station.", call. = FALSE)
  }
  out
}

.goal013_validate_data <- function(data) {
  if (!is.list(data)) stop("Goal013 data must be a list.", call. = FALSE)
  required <- c("y", "effort", "group", "target", "row_species", "row_class", "phase")
  missing <- setdiff(required, names(data))
  if (length(missing)) stop("Goal013 data is missing: ", paste(missing, collapse = ", "), call. = FALSE)
  y <- data$y
  if (!is.matrix(y) || !is.numeric(y)) stop("Goal013 y must be a numeric matrix.", call. = FALSE)
  D <- nrow(y); T <- ncol(y)
  if (!is.null(data$T) && (length(data$T) != 1L || !is.numeric(data$T) || is.na(data$T) || data$T != T)) {
    stop("Goal013 T must equal ncol(y) when supplied.", call. = FALSE)
  }
  if (!is.matrix(data$effort) || !is.numeric(data$effort) || !identical(dim(data$effort), dim(y))) {
    stop("Goal013 effort must be a numeric matrix with y dimensions.", call. = FALSE)
  }
  if (!is.matrix(data$group) || !identical(dim(data$group), dim(y))) {
    stop("Goal013 group must be an integer matrix with y dimensions.", call. = FALSE)
  }
  group <- data$group
  if (any(!is.finite(group)) || any(group != as.integer(group))) {
    stop("Goal013 group must contain integer values.", call. = FALSE)
  }
  if (!is.numeric(data$target) || any(!is.finite(data$target)) || any(data$target <= 0)) {
    stop("Goal013 target must contain finite positive values.", call. = FALSE)
  }
  G <- length(data$target)
  effort <- data$effort
  if (any(!is.finite(effort)) || any(effort < 0)) stop("Goal013 effort must be finite and non-negative.", call. = FALSE)
  if (any((effort == 0) != (group == 0))) {
    stop("Goal013 requires group 0 exactly when effort is zero.", call. = FALSE)
  }
  if (any(effort > 0 & (group < 1L | group > G))) stop("Goal013 active groups are out of range.", call. = FALSE)
  active_by_group <- tabulate(group[effort > 0], nbins = G)
  if (any(data$target >= active_by_group)) stop("Goal013 targets must be below active-cell counts.", call. = FALSE)
  if (!is.numeric(data$phase) || length(data$phase) != T || any(!is.finite(data$phase))) {
    stop("Goal013 phase must be finite numeric values of length T.", call. = FALSE)
  }
  for (nm in c("row_species", "row_class")) {
    z <- data[[nm]]
    if (!is.numeric(z) || length(z) != D || any(!is.finite(z)) || any(z != as.integer(z))) {
      stop("Goal013 ", nm, " must be an integer vector of length nrow(y).", call. = FALSE)
    }
  }
  row_species <- as.integer(data$row_species)
  row_class <- as.integer(data$row_class)
  if (any(row_species < 1L) || any(row_class < 1L | row_class > 2L)) {
    stop("Goal013 row species/classes are out of range.", call. = FALSE)
  }
  yy <- y[!is.na(y)]
  if (length(yy) && any(!is.finite(yy) | yy < 0 | yy > 1 | yy != as.integer(yy))) {
    stop("Goal013 y must contain only 0, 1, or NA.", call. = FALSE)
  }
  list(y = y, effort = effort, group = matrix(as.integer(group), D, T),
       target = as.numeric(data$target), row_species = row_species,
       row_class = row_class, phase = as.numeric(data$phase),
       D = D, T = T, G = G, S = max(row_species))
}

.goal013_theta <- function(model, theta) {
  model <- .goal013_model(model)
  if (is.null(theta)) theta <- numeric()
  if (!is.numeric(theta) || any(!is.finite(theta))) stop("Goal013 theta must be finite numeric values.", call. = FALSE)
  if (model == "static") {
    if (length(theta) != 0L) stop("Static Goal013 has no free theta parameters.", call. = FALSE)
  } else if (length(theta) != 4L) {
    stop("Goal013 dynamic candidates require four theta parameters.", call. = FALSE)
  }
  if (model == "harmonic" && any(theta < -4 | theta > 4)) stop("Harmonic theta must lie in [-4, 4].", call. = FALSE)
  if (model %in% c("array", "station") && (any(theta[c(1, 3)] < 0 | theta[c(1, 3)] > 4) || any(theta[c(2, 4)] < 0 | theta[c(2, 4)] > .98))) {
    stop("Array/station theta must have amplitudes in [0,4] and rho in [0,0.98].", call. = FALSE)
  }
  as.numeric(theta)
}

.goal013_cpp <- function() {
  if (exists("functions", envir = .goal013_env, inherits = FALSE)) return(get("functions", envir = .goal013_env))
  if (!requireNamespace("Rcpp", quietly = TRUE)) stop("Goal013 requires Rcpp to compile its root solver.", call. = FALSE)
  project_root <- .goal013_root()
  cache <- file.path(project_root, "outputs", "goal013", "cpp-cache")
  dir.create(cache, recursive = TRUE, showWarnings = FALSE)
  cpp <- file.path(project_root, "src", "goal013_mechanisms.cpp")
  if (!file.exists(cpp)) stop("Goal013 Rcpp source is missing: ", cpp, call. = FALSE)
  cpp_env <- new.env(parent = globalenv())
  Rcpp::sourceCpp(cpp, env = cpp_env, cacheDir = cache, rebuild = FALSE, showOutput = FALSE)
  funcs <- list(
    root = get("goal013_group_scales_cpp", envir = cpp_env),
    loglik = get("goal013_loglik_cpp", envir = cpp_env),
    forecast = get("goal013_forecast_events_cpp", envir = cpp_env)
  )
  assign("functions", funcs, envir = .goal013_env)
  funcs
}

.goal013_multipliers <- function(d, model, theta) {
  model <- .goal013_model(model); theta <- .goal013_theta(model, theta)
  D <- d$D; T <- d$T
  low <- high <- matrix(1, D, T)
  if (model == "harmonic") {
    sn <- sin(d$phase); cs <- cos(d$phase)
    for (i in seq_len(D)) {
      k <- 2L * d$row_class[i] - 1L
      m <- exp(theta[k] * sn + theta[k + 1L] * cs)
      low[i, ] <- m; high[i, ] <- m
    }
  } else if (model %in% c("array", "station")) {
    for (i in seq_len(D)) {
      k <- 2L * d$row_class[i] - 1L
      low[i, ] <- exp(-theta[k])
      high[i, ] <- exp(theta[k])
    }
  }
  list(low = low, high = high)
}

#' Return normalized cell probabilities for a Goal013 candidate.
goal013_probabilities <- function(data, model, theta = numeric()) {
  d <- .goal013_validate_data(data)
  model <- .goal013_model(model); theta <- .goal013_theta(model, theta)
  mm <- .goal013_multipliers(d, model, theta)
  root <- .goal013_cpp()$root
  effort <- as.vector(d$effort); group <- as.vector(d$group)
  scales <- root(effort, group, as.vector(mm$low), as.vector(mm$high), d$target)
  sc <- rep(NA_real_, length(effort)); active <- effort > 0
  sc[active] <- scales[group[active]]
  hl <- matrix(NA_real_, d$D, d$T); hh <- hl
  hl[active] <- effort[active] * sc[active] * as.vector(mm$low)[active]
  hh[active] <- effort[active] * sc[active] * as.vector(mm$high)[active]
  pl <- matrix(NA_real_, d$D, d$T); ph <- pl
  pl[active] <- -expm1(-hl[active]); ph[active] <- -expm1(-hh[active])
  pm <- .5 * (pl + ph)
  list(model = model, theta = theta, scale = scales, hazard_low = hl, hazard_high = hh,
       p_low = pl, p_high = ph,
       p = pm, multiplier_low = mm$low, multiplier_high = mm$high,
       active = matrix(active, d$D, d$T), target = d$target)
}

.goal013_logsumexp <- function(x) {
  m <- max(x)
  if (!is.finite(m)) return(m)
  m + log(sum(exp(x - m)))
}

.goal013_emission <- function(y, p, observed) {
  if (!observed) return(0)
  if (y == 1) log(p) else log1p(-p)
}

#' Compute a candidate log likelihood through `end` (default all columns).
goal013_loglik <- function(data, model, theta = numeric(), end = NULL, start = 1L) {
  d <- .goal013_validate_data(data)
  model <- .goal013_model(model); theta <- .goal013_theta(model, theta)
  if (is.null(end)) end <- d$T
  if (length(end) != 1L || !is.numeric(end) || end != as.integer(end) || end < 0 || end > d$T) stop("Goal013 end must be an integer in [0,T].", call. = FALSE)
  if (length(start) != 1L || !is.numeric(start) || start != as.integer(start) || start < 1L || start > max(1L, end + 1L)) stop("Goal013 start must be a valid scoring index.", call. = FALSE)
  end <- as.integer(end); start <- as.integer(start)
  if (end == 0L || start > end) return(0)
  probs <- goal013_probabilities(d, model, theta)
  code <- match(model, c("static", "harmonic", "array", "station")) - 1L
  if (model == "array" && any(vapply(seq_len(d$S), function(s) length(unique(d$row_class[d$row_species == s])) > 1L, logical(1)))) {
    stop("Goal013 array chains require one class per species.", call. = FALSE)
  }
  .goal013_cpp()$loglik(d$y, d$effort, d$row_species, d$row_class,
                        probs$hazard_low, probs$hazard_high, theta, code, start, end)
}

.goal013_starts <- function(model) {
  if (model == "static") return(list(numeric()))
  if (model == "harmonic") return(list(c(0, 0, 0, 0), c(.5, 0, -.5, 0), c(0, .5, 0, -.5), c(2, 0, 2, 0), c(-2, 0, -2, 0)))
  list(c(0, .5, 0, .5), c(.5, .5, .5, .5), c(2, .5, 2, .5), c(4, .1, 4, .1), c(0, .98, 0, .98))
}

#' Fit one Goal013 candidate with deterministic bounded multistart optimization.
goal013_fit <- function(data, model, train_end = NULL) {
  d <- .goal013_validate_data(data); model <- .goal013_model(model)
  if (is.null(train_end)) train_end <- d$T
  if (length(train_end) != 1L || train_end != as.integer(train_end) || train_end < 1L || train_end > d$T) stop("Goal013 train_end must be an integer in [1,T].", call. = FALSE)
  train_end <- as.integer(train_end)
  starts <- .goal013_starts(model)
  bounds <- if (model == "harmonic") list(lower = rep(-4, 4), upper = rep(4, 4)) else if (model == "static") list(lower = numeric(), upper = numeric()) else list(lower = c(0, 0, 0, 0), upper = c(4, .98, 4, .98))
  diagnostics <- vector("list", length(starts)); fits <- vector("list", length(starts))
  objective <- function(z) {
    ll <- tryCatch(goal013_loglik(d, model, z, train_end), error = function(e) NA_real_)
    if (!is.finite(ll)) return(.Machine$double.xmax / 16)
    -ll
  }
  for (i in seq_along(starts)) {
    st <- starts[[i]]
    if (model == "static") {
      fits[[i]] <- list(par = numeric(), value = -goal013_loglik(d, model, numeric(), train_end), convergence = 0L, counts = c(fn = 0L, gradient = 0L))
    } else {
      fits[[i]] <- tryCatch(
        stats::optim(st, objective, method = "L-BFGS-B", lower = bounds$lower,
                     upper = bounds$upper, control = list(fnscale = 1, maxit = 200)),
        error = function(e) list(par = st, value = .Machine$double.xmax / 16,
                                 convergence = 999L, counts = c(fn = NA_integer_, gradient = NA_integer_),
                                 message = conditionMessage(e)))
    }
    diagnostics[[i]] <- data.frame(start = i, value = fits[[i]]$value, convergence = fits[[i]]$convergence, stringsAsFactors = FALSE)
  }
  vals <- vapply(fits, function(z) z$value, numeric(1)); best <- which.min(vals); fit <- fits[[best]]
  theta <- as.numeric(fit$par)
  flags <- if (model %in% c("array", "station")) c(amplitude_class1_zero = theta[1] <= 1e-8, amplitude_class2_zero = theta[3] <= 1e-8, rho_class1_boundary = min(abs(theta[2] - c(0, .98))) <= 1e-8, rho_class2_boundary = min(abs(theta[4] - c(0, .98))) <= 1e-8) else setNames(logical(), character())
  starts_out <- do.call(rbind, diagnostics)
  list(model = model, theta = theta, loglik_train = -fit$value, convergence = fit$convergence,
       converged = identical(as.integer(fit$convergence), 0L), starts = starts_out,
       start_diagnostics = starts_out, boundary = flags, boundary_flags = flags, train_end = train_end)
}

#' Simulate observations from a fitted mechanism while retaining y's mask.
goal013_simulate <- function(data, model, theta = numeric(), seed = NULL, states = FALSE) {
  d <- .goal013_validate_data(data); model <- .goal013_model(model); theta <- .goal013_theta(model, theta)
  if (!is.null(seed)) { if (length(seed) != 1L || !is.finite(seed)) stop("Goal013 seed must be finite scalar.", call. = FALSE); set.seed(as.integer(seed)) }
  probs <- goal013_probabilities(d, model, theta)
  out <- d$y; out[,] <- NA_real_; keep <- d$effort > 0 & !is.na(d$y)
  state <- NULL
  if (model %in% c("static", "harmonic")) {
    z <- matrix(NA_real_, nrow = d$D, ncol = d$T)
    z[keep] <- stats::rbinom(sum(keep), 1L, probs$p[keep])
    out[keep] <- z[keep]
  } else {
    state <- matrix(NA_integer_, d$D, d$T)
    for (s in seq_len(d$S)) {
      rows <- which(d$row_species == s)
      chains <- if (model == "array") list(rows) else as.list(rows)
      for (chain in chains) {
        if (!length(chain)) next
        cls <- d$row_class[chain[[1L]]]; rho <- theta[2L * cls]; q <- (1 - rho) / 2
        st <- rbinom(1L, 1L, .5) + 1L
        for (tt in seq_len(d$T)) {
          if (tt > 1L && rbinom(1L, 1L, q)) st <- 3L - st
          state[chain, tt] <- st
          for (rr in chain) if (keep[rr, tt]) {
            pp <- if (st == 1L) probs$p_low[rr, tt] else probs$p_high[rr, tt]
            out[rr, tt] <- rbinom(1L, 1L, pp)
          }
        }
      }
    }
  }
  ans <- list(y = out)
  if (isTRUE(states)) ans$states <- state
  ans
}

#' Conditional probability of at least one future positive per species.
goal013_forecast_events <- function(data, model, theta = numeric(), origin, horizon) {
  d <- .goal013_validate_data(data); model <- .goal013_model(model); theta <- .goal013_theta(model, theta)
  if (length(origin) != 1L || origin != as.integer(origin) || origin < 0L || origin > d$T) stop("Goal013 origin must be an integer in [0,T].", call. = FALSE)
  if (length(horizon) != 1L || horizon != as.integer(horizon) || horizon < 1L || origin + horizon > d$T) stop("Goal013 horizon must fit after origin.", call. = FALSE)
  origin <- as.integer(origin); horizon <- as.integer(horizon); finish <- origin + horizon
  probs <- goal013_probabilities(d, model, theta)
  if (model == "array" && any(vapply(seq_len(d$S), function(s) length(unique(d$row_class[d$row_species == s])) > 1L, logical(1)))) {
    stop("Goal013 array chains require one class per species.", call. = FALSE)
  }
  code <- match(model, c("static", "harmonic", "array", "station")) - 1L
  .goal013_cpp()$forecast(d$y, d$effort, d$row_species, d$row_class,
                          probs$hazard_low, probs$hazard_low, probs$hazard_high, theta,
                          code, origin, finish)
}
