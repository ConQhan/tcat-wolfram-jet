function [st_t5, Wt, eta_t_act] = turbine_run(st_in, Wc, f, gamma_h, eta_t, eta_m, ...
                                                use_polytropic, e_t, gas_model, W_offtake)
%TURBINE_RUN _Turbine.run() port (engine_core.py:334-390).
%   alpha_fan/W_fan (turbofan only) are left out; they always contribute
%   zero to the power balance. W_offtake (accessory power offtake) is a
%   simple general term and is included (same unconditional W_offtake
%   wiring as _turbine_ctx_before in topology.py
%   build_full_turbojet_topology).
if nargin < 10 || isempty(W_offtake), W_offtake = 0.0; end
R = gcam_constants().R;
Tt4 = st_in.T_total; Pt4 = st_in.P_total;

Wc_total = Wc + W_offtake;
Wt = Wc_total / (eta_m * (1.0 + f));

if strcmp(gas_model, 'real')
    phi_eq = f / gcam_constants().FST_C12H23;
    h4  = h_T(Tt4, 'products', phi_eq);
    h5  = h4 - Wt;
    Tt5 = T_from_h(h5, 'products', Tt4*0.8, phi_eq);
    if Tt5 <= 0
        error('gcam:turbine:negativeT', 'Turbine T negative: %.1fK', Tt5);
    end
    Pr4 = Pr_T(Tt4, 'products', phi_eq);
    Pr5 = Pr_T(Tt5, 'products', phi_eq);
    if use_polytropic
        pi_t = (Pr5/Pr4) ^ (1.0/e_t);
        Pt5  = Pt4 * pi_t;
        T5i  = T_from_Pr(Pr4*pi_t, 'products', Tt5, phi_eq);
        Wt_isen = h4 - h_T(T5i, 'products', phi_eq);
        if Wt_isen > 0
            eta_t_act = Wt / Wt_isen;
        else
            eta_t_act = eta_t;
        end
    else
        h5_isen = h4 - Wt/eta_t;
        T5i  = T_from_h(h5_isen, 'products', Tt5, phi_eq);
        Pr5i = Pr_T(T5i, 'products', phi_eq);
        Pt5  = Pt4 * (Pr5i/Pr4);
        eta_t_act = eta_t;
    end
    cph = cp_T(Tt5, 'products', phi_eq);
else
    cph = gamma_h*R/(gamma_h-1.0);
    Tt5 = Tt4 - Wt/cph;
    if Tt5 <= 0
        error('gcam:turbine:negativeT', 'Turbine T negative: %.1fK', Tt5);
    end
    tau_t = Tt5/Tt4;
    if use_polytropic
        pi_t = turbine_pi_from_polytropic(tau_t, gamma_h, e_t);
        Pt5  = Pt4 * pi_t;
        exp_isen = (gamma_h-1.0)/gamma_h;
        if pi_t < 1.0
            eta_t_act = (1.0-tau_t) / (1.0 - pi_t^exp_isen);
        else
            eta_t_act = eta_t;
        end
    else
        bracket = 1.0 - (1.0-tau_t)/eta_t;
        if bracket <= 0
            error('gcam:turbine:bracketNonPositive', 'Turbine bracket<=0: %.5f', bracket);
        end
        Pt5 = Pt4 * bracket^(gamma_h/(gamma_h-1.0));
        eta_t_act = eta_t;
    end
end

st_t5 = make_station('t5', Tt5, Pt5, cph, [], [], [], true);
end
