function pi_opt = optimal_pr_max_thrust(tau_lam, tau_r, gamma_c)
%OPTIMAL_PR_MAX_THRUST Optimum pi_c for maximum specific thrust (ideal turbojet,
%   Farokhi Aircraft Propulsion 2nd Ed. Eq 4.73/4.74), efficiency_models.py:146.
%   Diagnostic value only; it does not change the cycle solution
%   (the pi_c input).
if tau_r <= 0
    pi_opt = 1.0;
    return
end
pi_opt = (tau_lam / tau_r^2) ^ (gamma_c / (2.0 * (gamma_c - 1.0)));
end
