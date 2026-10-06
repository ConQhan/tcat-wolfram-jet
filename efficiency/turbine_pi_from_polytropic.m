function pi_t = turbine_pi_from_polytropic(tau_t, gamma_h, e_t)
%TURBINE_PI_FROM_POLYTROPIC (efficiency_models.py:82)
if tau_t <= 0
    pi_t = 0.01;
    return
end
pi_t = tau_t ^ (gamma_h / (e_t * (gamma_h - 1.0)));
end
