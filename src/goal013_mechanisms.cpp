#include <Rcpp.h>
#include <cmath>
#include <limits>

using namespace Rcpp;

// [[Rcpp::plugins(cpp11)]]

// Solve one non-negative hazard scale per physical group.  The target is the
// expected number of positive cells, so an HMM uses the mean of the two state
// probabilities, rather than the probability at the mean multiplier.
// [[Rcpp::export]]
NumericVector goal013_group_scales_cpp(NumericVector effort,
                                       IntegerVector group,
                                       NumericVector multiplier_low,
                                       NumericVector multiplier_high,
                                       NumericVector target,
                                       double tolerance = 1e-14,
                                       int max_iter = 300) {
  const R_xlen_t n = effort.size();
  if (group.size() != n || multiplier_low.size() != n ||
      multiplier_high.size() != n) {
    stop("Goal013 root inputs have incompatible lengths.");
  }
  if (target.size() < 1) stop("Goal013 requires at least one group target.");
  if (!R_FINITE(tolerance) || tolerance <= 0.0 || max_iter < 1) {
    stop("Goal013 root tolerance and iteration limit must be valid.");
  }

  const int G = target.size();
  NumericVector out(G, NA_REAL);
  IntegerVector n_active(G, 0);
  std::vector<std::vector<int> > members(G);

  for (R_xlen_t i = 0; i < n; ++i) {
    const double e = effort[i];
    const int g = group[i];
    if (!R_FINITE(e) || e < 0.0) stop("Goal013 effort must be finite and non-negative.");
    if (e == 0.0) continue;
    if (g < 1 || g > G) stop("Goal013 active cells must have a valid group.");
    if (!R_FINITE(multiplier_low[i]) || !R_FINITE(multiplier_high[i]) ||
        multiplier_low[i] <= 0.0 || multiplier_high[i] <= 0.0) {
      stop("Goal013 multipliers must be finite and positive.");
    }
    ++n_active[g - 1];
    members[g - 1].push_back(i);
  }

  for (int g = 0; g < G; ++g) {
    const double z = target[g];
    if (!R_FINITE(z) || z <= 0.0) {
      stop("Goal013 group targets must be finite and positive.");
    }
    if (n_active[g] == 0) {
      stop("Goal013 has a target for a group with no active cells.");
    }
    if (z >= static_cast<double>(n_active[g])) {
      stop("Goal013 group targets must lie strictly below active-cell counts.");
    }

    auto expected_positive = [&](double scale) {
      double total = 0.0;
      for (std::size_t jj = 0; jj < members[g].size(); ++jj) {
        const R_xlen_t i = members[g][jj];
        const double pl = -std::expm1(-effort[i] * scale * multiplier_low[i]);
        const double ph = -std::expm1(-effort[i] * scale * multiplier_high[i]);
        total += 0.5 * (pl + ph);
      }
      return total;
    };

    double lo = 0.0;
    double hi = 1.0;
    double f_hi = expected_positive(hi);
    int expand = 0;
    while (f_hi < z && expand < 1074) {
      hi *= 2.0;
      f_hi = expected_positive(hi);
      ++expand;
      if (!R_FINITE(hi) || hi > std::numeric_limits<double>::max() / 4.0) break;
    }
    if (!R_FINITE(f_hi) || f_hi < z) {
      stop("Goal013 root bracket could not reach the requested target.");
    }

    for (int iter = 0; iter < max_iter; ++iter) {
      const double mid = 0.5 * (lo + hi);
      const double f_mid = expected_positive(mid);
      if (std::abs(f_mid - z) <= tolerance * std::max(1.0, z) ||
          (hi - lo) <= tolerance * std::max(1.0, mid)) {
        lo = mid;
        hi = mid;
        break;
      }
      if (f_mid < z) lo = mid; else hi = mid;
    }
    out[g] = 0.5 * (lo + hi);
  }
  return out;
}

inline double g013_lse(double a, double b) {
  const double m = std::max(a, b);
  if (!R_FINITE(m)) return m;
  return m + std::log(std::exp(a - m) + std::exp(b - m));
}

inline double g013_log_positive(double h) {
  if (h > 0.6931471805599453) return std::log1p(-std::exp(-h));
  return std::log(-std::expm1(-h));
}

inline double g013_emission(double y, double h) {
  if (NumericVector::is_na(y)) return 0.0;
  if (y == 1.0) return g013_log_positive(h);
  return -h;
}

// model_code: 0 static, 1 harmonic, 2 array, 3 station.
// [[Rcpp::export]]
double goal013_loglik_cpp(NumericMatrix y, NumericMatrix effort,
                          IntegerVector row_species, IntegerVector row_class,
                          NumericMatrix p_low, NumericMatrix p_high,
                          NumericVector theta, int model_code,
                          int start, int end) {
  const int D = y.nrow(), T = y.ncol();
  if (effort.nrow() != D || effort.ncol() != T || p_low.nrow() != D ||
      p_low.ncol() != T || p_high.nrow() != D || p_high.ncol() != T ||
      row_species.size() != D || row_class.size() != D) {
    stop("Goal013 likelihood matrices have incompatible dimensions.");
  }
  if (start < 1 || end < 0 || end > T || start > end + 1) {
    stop("Goal013 likelihood interval is invalid.");
  }
  if (end == 0 || start > end) return 0.0;
  double total = 0.0;
  int S = 0;
  for (int i = 0; i < D; ++i) S = std::max(S, row_species[i]);
  if (model_code < 2) {
    for (int i = 0; i < D; ++i) for (int t = start - 1; t < end; ++t) {
      if (effort(i, t) > 0.0 && !NumericVector::is_na(y(i, t))) {
        total += g013_emission(y(i, t), p_low(i, t));
      }
    }
    return total;
  }

  for (int s = 1; s <= S; ++s) {
    std::vector<int> rows;
    for (int i = 0; i < D; ++i) if (row_species[i] == s) rows.push_back(i);
    if (model_code == 3) {
      // Station candidates have one chain per row.
      for (std::size_t ri = 0; ri < rows.size(); ++ri) {
        const int i = rows[ri];
        const int cls = row_class[i];
        const double rho = theta[2 * cls - 1];
        const double q = (1.0 - rho) / 2.0;
        double la0 = std::log(.5), la1 = std::log(.5);
        for (int t = 0; t < end; ++t) {
          if (t > 0) {
            const double na0 = g013_lse(la0 + std::log(1.0 - q), la1 + std::log(q));
            const double na1 = g013_lse(la0 + std::log(q), la1 + std::log(1.0 - q));
            la0 = na0; la1 = na1;
          }
          const double le0 = effort(i, t) > 0.0 ? g013_emission(y(i, t), p_low(i, t)) : 0.0;
          const double le1 = effort(i, t) > 0.0 ? g013_emission(y(i, t), p_high(i, t)) : 0.0;
          const double z0 = la0 + le0, z1 = la1 + le1, norm = g013_lse(z0, z1);
          if (!R_FINITE(norm)) return R_NegInf;
          la0 = z0 - norm; la1 = z1 - norm;
          if (t + 1 >= start) total += norm;
        }
      }
    } else {
      // Array candidate: one chain per species, with one taxon class.
      if (rows.empty()) continue;
      const int cls = row_class[rows[0]];
      const double rho = theta[2 * cls - 1];
      const double q = (1.0 - rho) / 2.0;
      double la0 = std::log(.5), la1 = std::log(.5);
      for (int t = 0; t < end; ++t) {
        if (t > 0) {
          const double na0 = g013_lse(la0 + std::log(1.0 - q), la1 + std::log(q));
          const double na1 = g013_lse(la0 + std::log(q), la1 + std::log(1.0 - q));
          la0 = na0; la1 = na1;
        }
        double le0 = 0.0, le1 = 0.0;
        for (std::size_t ri = 0; ri < rows.size(); ++ri) {
          const int i = rows[ri];
          if (effort(i, t) <= 0.0 || NumericVector::is_na(y(i, t))) continue;
          le0 += g013_emission(y(i, t), p_low(i, t));
          le1 += g013_emission(y(i, t), p_high(i, t));
        }
        const double z0 = la0 + le0, z1 = la1 + le1, norm = g013_lse(z0, z1);
        if (!R_FINITE(norm)) return R_NegInf;
        la0 = z0 - norm; la1 = z1 - norm;
        if (t + 1 >= start) total += norm;
      }
    }
  }
  return total;
}

// Conditional species event probabilities, with actual observations used only
// through origin and all-zero emissions used over the future horizon.
// [[Rcpp::export]]
NumericVector goal013_forecast_events_cpp(NumericMatrix y, NumericMatrix effort,
                                          IntegerVector row_species, IntegerVector row_class,
                                          NumericMatrix hazard, NumericMatrix h_low,
                                          NumericMatrix h_high, NumericVector theta,
                                          int model_code, int origin, int finish) {
  const int D = y.nrow(), T = y.ncol();
  int S = 0; for (int i = 0; i < D; ++i) S = std::max(S, row_species[i]);
  NumericVector out(S);
  if (model_code < 2) {
    for (int s = 1; s <= S; ++s) {
      double logzero = 0.0;
      for (int i = 0; i < D; ++i) if (row_species[i] == s)
        for (int t = origin; t < finish; ++t) if (effort(i, t) > 0.0)
          logzero -= hazard(i, t);
      out[s - 1] = -std::expm1(logzero);
    }
    return out;
  }
  for (int s = 1; s <= S; ++s) {
    std::vector<int> rows;
    for (int i = 0; i < D; ++i) if (row_species[i] == s) rows.push_back(i);
    double species_zero = 1.0;
    for (std::size_t ri = 0; ri < (model_code == 2 ? 1 : rows.size()); ++ri) {
      std::vector<int> chain = model_code == 2 ? rows : std::vector<int>(1, rows[ri]);
      if (chain.empty()) continue;
      const int cls = row_class[chain[0]];
      const double q = (1.0 - theta[2 * cls - 1]) / 2.0;
      double la0 = std::log(.5), la1 = std::log(.5);
      for (int t = 0; t < origin; ++t) {
        if (t > 0) {
          const double na0 = g013_lse(la0 + std::log(1.0 - q), la1 + std::log(q));
          const double na1 = g013_lse(la0 + std::log(q), la1 + std::log(1.0 - q));
          la0 = na0; la1 = na1;
        }
        double le0 = 0.0, le1 = 0.0;
        for (std::size_t k = 0; k < chain.size(); ++k) {
          int i = chain[k];
          if (effort(i, t) <= 0.0 || NumericVector::is_na(y(i, t))) continue;
          le0 += g013_emission(y(i, t), h_low(i, t));
          le1 += g013_emission(y(i, t), h_high(i, t));
        }
        const double z0 = la0 + le0, z1 = la1 + le1, norm = g013_lse(z0, z1);
        if (!R_FINITE(norm)) return NumericVector(S, NA_REAL);
        la0 = z0 - norm; la1 = z1 - norm;
      }
      double logzero = 0.0;
      for (int t = origin; t < finish; ++t) {
        if (t > 0 || origin > 0) {
          const double na0 = g013_lse(la0 + std::log(1.0 - q), la1 + std::log(q));
          const double na1 = g013_lse(la0 + std::log(q), la1 + std::log(1.0 - q));
          la0 = na0; la1 = na1;
        }
        double le0 = 0.0, le1 = 0.0;
        for (std::size_t k = 0; k < chain.size(); ++k) {
          int i = chain[k]; if (effort(i, t) <= 0.0) continue;
          le0 -= h_low(i, t); le1 -= h_high(i, t);
        }
        const double z0 = la0 + le0, z1 = la1 + le1, norm = g013_lse(z0, z1);
        la0 = z0 - norm; la1 = z1 - norm; logzero += norm;
      }
      species_zero *= std::exp(logzero);
    }
    out[s - 1] = -std::expm1(std::log(species_zero));
  }
  return out;
}
