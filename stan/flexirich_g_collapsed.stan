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

  real detection_probability_from_log_hazard(real log_hazard) {
    if (log_hazard > 20) {
      return 1;
    }
    return -expm1(-exp(log_hazard));
  }

  real log_m0_from_nodes(
    real mu_alpha,
    real sigma_alpha,
    vector camera_effect,
    int G0,
    array[] int zero_camera_index,
    array[] int zero_active_days,
    array[] int zero_n_trials,
    vector gh_nodes,
    vector gh_log_weights
  ) {
    int Nq = num_elements(gh_nodes);
    vector[Nq] log_values;
    for (q in 1:Nq) {
      real alpha = mu_alpha + sigma_alpha * gh_nodes[q];
      real value = 0;
      if (G0 > 0) {
        for (g in 1:G0) {
          real log_hazard =
            log(zero_active_days[g]) +
            alpha + camera_effect[zero_camera_index[g]];
          value += zero_n_trials[g] *
            log_nondetect_from_log_hazard(log_hazard);
        }
      }
      log_values[q] = gh_log_weights[q] + value;
    }
    return log_sum_exp(log_values);
  }
}

data {
  int<lower=1> D;
  int<lower=0> U;
  int<lower=2> J;
  int<lower=0> B;
  int<lower=0> G;
  int<lower=0> G0;
  int<lower=1> Nq;
  array[G] int<lower=1, upper=D> species_index;
  array[G] int<lower=1, upper=J> camera_index;
  array[G] int<lower=1, upper=7> active_days;
  array[G] int<lower=1> n_trials;
  array[G] int<lower=0> n_detected;
  array[G0] int<lower=1, upper=J> zero_camera_index;
  array[G0] int<lower=1, upper=7> zero_active_days;
  array[G0] int<lower=1> zero_n_trials;
  matrix[J, B] Q;
  vector[Nq] gh_nodes;
  vector[Nq] gh_log_weights;

  real<lower=0> omega_alpha;
  real<lower=0> omega_beta;
  real mu_alpha_location;
  real<lower=0> mu_alpha_scale;
  real<lower=0> sigma_alpha_scale;
  real<lower=0> sigma_camera_scale;
}

parameters {
  real<lower=0, upper=1> omega;
  real mu_alpha;
  real<lower=0> sigma_alpha;
  vector[D] z_alpha;
  real<lower=0> sigma_camera;
  vector[B] z_camera;
}

transformed parameters {
  vector[D] alpha;
  vector[J] camera_effect;
  vector[D] member_ll;
  real log_m0;

  alpha = mu_alpha + sigma_alpha * z_alpha;
  camera_effect = sigma_camera * Q * z_camera;
  member_ll = rep_vector(0, D);

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

  log_m0 = log_m0_from_nodes(
    mu_alpha,
    sigma_alpha,
    camera_effect,
    G0,
    zero_camera_index,
    zero_active_days,
    zero_n_trials,
    gh_nodes,
    gh_log_weights
  );
}

model {
  omega ~ beta(omega_alpha, omega_beta);
  mu_alpha ~ normal(mu_alpha_location, mu_alpha_scale);
  sigma_alpha ~ normal(0, sigma_alpha_scale);
  z_alpha ~ std_normal();
  sigma_camera ~ normal(0, sigma_camera_scale);
  z_camera ~ std_normal();

  if (D > 0) {
    for (i in 1:D) {
      target += log(omega) + member_ll[i];
    }
  }
  if (U > 0) {
    target += U * log_mix(omega, log_m0, 0);
  }
}

generated quantities {
  real q_unseen;
  int<lower=0> S_grid;
  real<lower=0> expected_richness;
  array[G] int<lower=0> y_rep;

  q_unseen = inv_logit(logit(omega) + log_m0);
  S_grid = D + binomial_rng(U, q_unseen);
  expected_richness = D + U * q_unseen;

  if (G > 0) {
    for (g in 1:G) {
      int i = species_index[g];
      int j = camera_index[g];
      real log_hazard =
        log(active_days[g]) + alpha[i] + camera_effect[j];
      real p = detection_probability_from_log_hazard(log_hazard);
      y_rep[g] = binomial_rng(n_trials[g], p);
    }
  }
}
