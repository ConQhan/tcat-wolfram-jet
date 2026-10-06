function [st_t3, Wc, eta_c_act] = compressor_run(st_in, gamma_c, pi_c, eta_c, use_polytropic, e_c, gas_model)
%COMPRESSOR_RUN _Compressor.run() port (engine_core.py:250-290).
R = gcam_constants().R;
Tt2 = st_in.T_total; Pt2 = st_in.P_total;
Pt3 = Pt2 * pi_c;

if strcmp(gas_model, 'real')
    h2  = h_T(Tt2, 'air');
    Pr2 = Pr_T(Tt2, 'air');
    if use_polytropic
        Pr3 = Pr2 * pi_c^(1.0/e_c);
        Tt3 = T_from_Pr(Pr3, 'air', Tt2*pi_c^0.28);
        Wc  = h_T(Tt3, 'air') - h2;
        T3i = T_from_Pr(Pr2*pi_c, 'air', Tt2*pi_c^0.28);
        Wc_isen = h_T(T3i, 'air') - h2;
        if Wc > 0
            eta_c_act = Wc_isen / Wc;
        else
            eta_c_act = eta_c;
        end
    else
        Pr3i = Pr2 * pi_c;
        T3i  = T_from_Pr(Pr3i, 'air', Tt2*pi_c^0.28);
        h3i  = h_T(T3i, 'air');
        Wc_isen = h3i - h2;
        Wc  = Wc_isen / eta_c;
        Tt3 = T_from_h(h2 + Wc, 'air', T3i);
        eta_c_act = eta_c;
    end
    cpc = cp_T(Tt3, 'air');
else
    cpc = gamma_c * R / (gamma_c - 1.0);
    if use_polytropic
        tau_c = compressor_tau_from_polytropic(pi_c, gamma_c, e_c);
        Tt3   = Tt2 * tau_c;
        tau_isen = pi_c ^ ((gamma_c-1.0)/gamma_c);
        if tau_c > 1.0
            eta_c_act = (tau_isen - 1.0) / (tau_c - 1.0);
        else
            eta_c_act = eta_c;
        end
    else
        Tt3 = Tt2 * (1.0 + (pi_c^((gamma_c-1.0)/gamma_c) - 1.0) / eta_c);
        eta_c_act = eta_c;
    end
    Wc = cpc * (Tt3 - Tt2);
end

st_t3 = make_station('t3', Tt3, Pt3, cpc);
end
