function [st0, st_t2, V0, pi_d_eff] = diffuser_run(M0, T0, P0, gamma_c, pi_d_max, gas_model)
%DIFFUSER_RUN _InletDiffuser.run() port (engine_core.py:221-247).
%   use_mil_spec is always true, the only mode used in this port (see the
%   DiffuserComponent default, component_interface.py:73-74).
R = gcam_constants().R;
if strcmp(gas_model, 'real')
    cp0 = cp_T(T0, 'air');
    gamma0 = cp0 / (cp0 - R);
    V0 = M0 * sqrt(gamma0 * R * T0);
    h0 = h_T(T0, 'air');
    Tt0 = T_from_h(h0 + V0^2/2.0, 'air', T0*(1.0 + 0.2*M0^2));
    Pr0   = Pr_T(T0,  'air');
    Pr_t0 = Pr_T(Tt0, 'air');
    Pt0 = P0 * (Pr_t0 / Pr0);
    cpc = cp_T(T0, 'air');
else
    V0  = M0 * sqrt(gamma_c * R * T0);
    Tt0 = T0 * (1.0 + (gamma_c-1.0)/2.0 * M0^2);
    Pt0 = P0 * (Tt0/T0) ^ (gamma_c/(gamma_c-1.0));
    cpc = gamma_c * R / (gamma_c - 1.0);
end

pi_d_eff = mil_inlet_recovery(M0, pi_d_max);
Tt2 = Tt0;
Pt2 = Pt0 * pi_d_eff;

st0   = make_station('0',  Tt0, Pt0, cpc, T0, P0, M0, false);
st_t2 = make_station('t2', Tt2, Pt2, cpc);
end
