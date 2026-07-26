.sim_rng_algorithms <- c(
  kind = "Mersenne-Twister",
  normal.kind = "Inversion",
  sample.kind = "Rejection"
)

.with_sim_rng <- function(seed, code) {
  caller_kind <- RNGkind()
  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (had_seed) {
    caller_seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  }

  on.exit({
    suppressWarnings(do.call(RNGkind, as.list(caller_kind)))
    if (had_seed) {
      assign(".Random.seed", caller_seed, envir = .GlobalEnv)
    } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".Random.seed", envir = .GlobalEnv)
    }
  }, add = TRUE)

  suppressWarnings(do.call(RNGkind, as.list(.sim_rng_algorithms)))
  set.seed(seed)
  eval.parent(substitute(code))
}
