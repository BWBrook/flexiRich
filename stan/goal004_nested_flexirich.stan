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
    if (log_hazard > 709.782712893384) {
      return negative_infinity();
    }
    return -exp(log_hazard);
  }
}

data {
  int<lower=1> C;
  int<lower=1> C_core;
  int<lower=1> C_fringe;
  array[C_core] int<lower=1, upper=C> core_index;
  array[C_fringe] int<lower=1, upper=C> fringe_index;
  int<lower=1> J;
  int<lower=0> B;
  int<lower=0> G;
  array[G] int<lower=1, upper=C> species_index;
  array[G] int<lower=1, upper=J> camera_index;
  array[G] int<lower=1, upper=7> active_days;
  array[G] int<lower=0> n_trials;
  array[G] int<lower=0> n_detected;
  array[C] int<lower=0, upper=1> detected_ever;
  matrix[J, B] Q;

  real<lower=0> core_omega_alpha;
  real<lower=0> core_omega_beta;
  real<lower=0> fringe_expected_count_scale;
  vector[C] alpha_location;
  real<lower=0> log_rate_sd;
  real<lower=0> sigma_camera_scale;
}

transformed data {
  if (C_core + C_fringe != C) {
    reject("Core and fringe sizes must sum to C.");
  }
}

parameters {
  real<lower=0, upper=C_core> expected_core_members;
  real<lower=0, upper=C_fringe> expected_fringe_members;
  vector[C] alpha;
  real<lower=0> sigma_camera;
  vector[B] z_camera;
}

transformed parameters {
  real<lower=0, upper=1> omega_core =
    expected_core_members / C_core;
  real<lower=0, upper=1> omega_fringe =
    expected_fringe_members / C_fringe;
  vector[J] camera_effect = sigma_camera * Q * z_camera;
  vector[C] member_ll = rep_vector(0, C);

  if (G > 0) {
    for (g in 1:G) {
      int i = species_index[g];
      int j = camera_index[g];
      int y = n_detected[g];
      int n0 = n_trials[g] - y;
      real log_hazard =
        log(active_days[g]) + alpha[i] + camera_effect[j];

      if (y > 0) {
        member_ll[i] += y * log_detect_from_log_hazard(log_hazard);
      }
      if (n0 > 0) {
        member_ll[i] += n0 * log_nondetect_from_log_hazard(log_hazard);
      }
    }
  }
}

model {
  target += beta_lpdf(
    omega_core | core_omega_alpha, core_omega_beta
  ) - log(C_core);
  target += exponential_lpdf(
    expected_fringe_members | inv(fringe_expected_count_scale)
  ) - log1m_exp(-C_fringe / fringe_expected_count_scale);

  alpha ~ normal(alpha_location, log_rate_sd);
  sigma_camera ~ normal(0, sigma_camera_scale);
  z_camera ~ std_normal();

  for (h in 1:C_core) {
    int i = core_index[h];
    if (detected_ever[i] == 1) {
      target += log(omega_core) + member_ll[i];
    } else {
      target += log_mix(omega_core, member_ll[i], 0);
    }
  }
  for (h in 1:C_fringe) {
    int i = fringe_index[h];
    if (detected_ever[i] == 1) {
      target += log(omega_fringe) + member_ll[i];
    } else {
      target += log_mix(omega_fringe, member_ll[i], 0);
    }
  }
}

generated quantities {
  vector[C_core] q_core;
  vector[C_fringe] q_fringe;
  real<lower=0, upper=C_core> expected_core_richness = 0;
  real<lower=0, upper=C_fringe> expected_fringe_richness = 0;
  real<lower=0, upper=C> expected_total_richness;

  for (h in 1:C_core) {
    int i = core_index[h];
    if (detected_ever[i] == 1) {
      q_core[h] = 1;
    } else {
      q_core[h] = inv_logit(logit(omega_core) + member_ll[i]);
    }
    expected_core_richness += q_core[h];
  }
  for (h in 1:C_fringe) {
    int i = fringe_index[h];
    if (detected_ever[i] == 1) {
      q_fringe[h] = 1;
    } else {
      q_fringe[h] = inv_logit(logit(omega_fringe) + member_ll[i]);
    }
    expected_fringe_richness += q_fringe[h];
  }
  expected_total_richness =
    expected_core_richness + expected_fringe_richness;
}
