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

  real selection_log_probability(
    real class_location,
    real log_rate_sd,
    real log_total_hazard,
    vector quadrature_node,
    vector quadrature_log_weight
  ) {
    int K = num_elements(quadrature_node);
    vector[K] term;

    for (k in 1:K) {
      real alpha = class_location +
        sqrt(2.0) * log_rate_sd * quadrature_node[k];
      term[k] = quadrature_log_weight[k] +
        log_detect_from_log_hazard(log_total_hazard + alpha);
    }
    return log_sum_exp(term);
  }
}

data {
  int<lower=1> D;
  int<lower=1> J;
  int<lower=0> B;
  int<lower=1> G;
  array[G] int<lower=1, upper=D> species_index;
  array[G] int<lower=1, upper=J> camera_index;
  array[G] int<lower=1, upper=7> active_days;
  array[G] int<lower=0> n_trials;
  array[G] int<lower=0> n_detected;
  array[D] int<lower=1, upper=2> class_index;
  vector<lower=0>[J] total_active_days;
  matrix[J, B] Q;

  vector[2] base_location;
  real<lower=0> common_shift_sd;
  real<lower=0> contrast_sd;
  real<lower=0> log_rate_sd;
  real<lower=0> sigma_camera_scale;

  int<lower=1> K;
  vector[K] quadrature_node;
  vector[K] quadrature_log_weight;
}

parameters {
  real common_shift;
  real contrast_deviation;
  vector[D] alpha;
  real<lower=0> sigma_camera;
  vector[B] z_camera;
}

transformed parameters {
  vector[2] class_location;
  vector[J] camera_effect = sigma_camera * Q * z_camera;
  vector[D] history_log_likelihood = rep_vector(0, D);
  vector[2] log_selection_probability;
  real log_total_hazard = log(dot_product(
    total_active_days,
    exp(camera_effect)
  ));

  class_location[1] = base_location[1] + common_shift;
  class_location[2] = base_location[2] + common_shift + contrast_deviation;

  for (g in 1:G) {
    int i = species_index[g];
    int j = camera_index[g];
    int y = n_detected[g];
    int n0 = n_trials[g] - y;
    real log_hazard = log(active_days[g]) + alpha[i] + camera_effect[j];

    if (y > 0) {
      history_log_likelihood[i] +=
        y * log_detect_from_log_hazard(log_hazard);
    }
    if (n0 > 0) {
      history_log_likelihood[i] +=
        n0 * log_nondetect_from_log_hazard(log_hazard);
    }
  }

  for (h in 1:2) {
    log_selection_probability[h] = selection_log_probability(
      class_location[h],
      log_rate_sd,
      log_total_hazard,
      quadrature_node,
      quadrature_log_weight
    );
  }
}

model {
  common_shift ~ normal(0, common_shift_sd);
  contrast_deviation ~ normal(0, contrast_sd);
  sigma_camera ~ normal(0, sigma_camera_scale);
  z_camera ~ std_normal();

  for (i in 1:D) {
    alpha[i] ~ normal(class_location[class_index[i]], log_rate_sd);
    target += history_log_likelihood[i] -
      log_selection_probability[class_index[i]];
  }
}

generated quantities {
  real selection_adjusted_log_likelihood =
    sum(history_log_likelihood);

  for (i in 1:D) {
    selection_adjusted_log_likelihood -=
      log_selection_probability[class_index[i]];
  }
}
