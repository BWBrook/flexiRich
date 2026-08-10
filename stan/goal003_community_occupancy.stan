functions {
  real log_detect_from_log_hazard(real log_hazard) {
    if (log_hazard > 20) {
      return 0;
    }
    if (log_hazard < -700) {
      return log_hazard;
    }
    return log1m_exp(-exp(log_hazard));
  }

  real log_nondetect_from_log_hazard(real log_hazard) {
    if (log_hazard > 700) {
      return negative_infinity();
    }
    return -exp(log_hazard);
  }
}

data {
  int<lower=1> C;
  int<lower=1> J;
  int<lower=0> G;
  array[G] int<lower=1, upper=C> species_index;
  array[G] int<lower=1, upper=J> camera_index;
  array[G] int<lower=1, upper=7> active_days;
  array[G] int<lower=0> n_trials;
  array[G] int<lower=0> n_detected;
  array[C, J] int<lower=0, upper=1> site_detected_ever;

  real mu_psi_location;
  real<lower=0> mu_psi_scale;
  real<lower=0> sigma_psi_scale;
  real mu_log_rate_location;
  real<lower=0> mu_log_rate_scale;
  real<lower=0> sigma_log_rate_scale;
}

parameters {
  real mu_psi;
  real<lower=0> sigma_psi;
  vector[C] z_psi;
  real mu_log_rate;
  real<lower=0> sigma_log_rate;
  vector[C] z_log_rate;
}

transformed parameters {
  vector[C] logit_psi = mu_psi + sigma_psi * z_psi;
  vector[C] psi = inv_logit(logit_psi);
  vector[C] log_rate = mu_log_rate + sigma_log_rate * z_log_rate;
  vector[C] rate = exp(log_rate);
  matrix[C, J] member_ll = rep_matrix(0, C, J);

  if (G > 0) {
    for (g in 1:G) {
      int i = species_index[g];
      int j = camera_index[g];
      int y = n_detected[g];
      int n0 = n_trials[g] - y;
      real log_hazard = log(active_days[g]) + log_rate[i];

      if (y > 0) {
        member_ll[i, j] +=
          y * log_detect_from_log_hazard(log_hazard);
      }
      if (n0 > 0) {
        member_ll[i, j] +=
          n0 * log_nondetect_from_log_hazard(log_hazard);
      }
    }
  }
}

model {
  mu_psi ~ normal(mu_psi_location, mu_psi_scale);
  sigma_psi ~ normal(0, sigma_psi_scale);
  z_psi ~ std_normal();
  mu_log_rate ~ normal(mu_log_rate_location, mu_log_rate_scale);
  sigma_log_rate ~ normal(0, sigma_log_rate_scale);
  z_log_rate ~ std_normal();

  for (i in 1:C) {
    for (j in 1:J) {
      if (site_detected_ever[i, j] == 1) {
        target += log(psi[i]) + member_ll[i, j];
      } else {
        target += log_mix(psi[i], member_ll[i, j], 0);
      }
    }
  }
}

generated quantities {
  matrix[C, J] q_site;
  vector[C] q_grid;
  real<lower=0, upper=C> expected_grid_richness = 0;

  for (i in 1:C) {
    real absent_from_grid = 1;
    for (j in 1:J) {
      if (site_detected_ever[i, j] == 1) {
        q_site[i, j] = 1;
      } else {
        q_site[i, j] = inv_logit(logit_psi[i] + member_ll[i, j]);
      }
      absent_from_grid *= 1 - q_site[i, j];
    }
    q_grid[i] = 1 - absent_from_grid;
    expected_grid_richness += q_grid[i];
  }
}
