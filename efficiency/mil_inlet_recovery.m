function pi_d = mil_inlet_recovery(M0, pi_d_max)
%MIL_INLET_RECOVERY MIL-E-5008B supersonic inlet recovery (efficiency_models.py:28).
if nargin < 2 || isempty(pi_d_max), pi_d_max = 1.0; end
if M0 <= 1.0
    eta_r = 1.0;
else
    eta_r = 1.0 - 0.075 * (M0 - 1.0) ^ 1.35;
end
pi_d = pi_d_max * max(0.0, eta_r);
end
