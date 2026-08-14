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

  real<lower=0> omega_alpha;
  real<lower=0> omega_beta;
  real routine_location;
  real occasional_location;
  real<lower=0> log_rate_sd;
  vector<lower=0, upper=1>[C] routine_weight;
  real<lower=0> sigma_camera_scale;
}

parameters {
  real<lower=0, upper=C> expected_core_members;
  vector[C] alpha;
  real<lower=0> sigma_camera;
  vector[B] z_camera;
}

transformed parameters {
  real<lower=0, upper=1> omega = expected_core_members / C;
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
  target += beta_lpdf(omega | omega_alpha, omega_beta) - log(C);
  sigma_camera ~ normal(0, sigma_camera_scale);
  z_camera ~ std_normal();

  for (i in 1:C) {
    if (routine_weight[i] == 1) {
      alpha[i] ~ normal(routine_location, log_rate_sd);
    } else if (routine_weight[i] == 0) {
      alpha[i] ~ normal(occasional_location, log_rate_sd);
    } else {
      target += log_mix(
        routine_weight[i],
        normal_lpdf(alpha[i] | routine_location, log_rate_sd),
        normal_lpdf(alpha[i] | occasional_location, log_rate_sd)
      );
    }

    if (detected_ever[i] == 1) {
      target += log(omega) + member_ll[i];
    } else {
      target += log_mix(omega, member_ll[i], 0);
    }
  }
}

generated quantities {
  vector[C] q_member;
  real<lower=0, upper=C> expected_richness = 0;

  for (i in 1:C) {
    if (detected_ever[i] == 1) {
      q_member[i] = 1;
    } else {
      q_member[i] = inv_logit(logit(omega) + member_ll[i]);
    }
    expected_richness += q_member[i];
  }
}
