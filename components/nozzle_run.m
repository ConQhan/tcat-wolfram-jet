function [st_9, V9, A_th, A_exit, noz_exp] = nozzle_run(st_in, P_amb, m_dot_total, ...
                                    m_dot_inlet, V0, gamma_h, f, eta_n, pi_n, gas_model, nozzle_type)
%NOZZLE_RUN _CDNozzle.run() port (engine_core.py:464-549).
if nargin < 7 || isempty(f), f = 0.0; end
R = tcat_constants().R;
Tt5 = st_in.T_total; Pt5 = st_in.P_total;
Pt9 = Pt5 * pi_n;
if Pt9 < P_amb
    error('tcat:nozzle:infeasible', ...
        'Nozzle: Pt9=%.0fPa < P_amb=%.0fPa. The engine cannot produce thrust with these inputs.', Pt9, P_amb);
end

if strcmp(gas_model, 'real')
    phi_eq = f / tcat_constants().FST_C12H23;
    cp5 = cp_T(Tt5, 'products', phi_eq);
    gamma_use = cp5 / (cp5 - R);
else
    phi_eq = 0.35;
    gamma_use = gamma_h;
end

crit_PR = nozzle_critical_pr_with_loss(gamma_use, eta_n);
PR = Pt9 / P_amb;
choked_conv = strcmp(nozzle_type, 'conv') && (PR >= crit_PR);
gamma_a9 = gamma_h;

if choked_conv
    % Choked convergent nozzle: M9 = 1 and P9 > P_amb (the pressure thrust
    % term is added in nozzle_expansion_analysis).
    T9 = Tt5 * 2.0 / (gamma_use + 1.0);
    P9 = Pt9 / crit_PR;
    if strcmp(gas_model, 'real')
        cph = cp_T(T9, 'products', phi_eq);
    else
        cph = gamma_h*R/(gamma_h-1.0);
    end
    if T9 <= 0
        error('tcat:nozzle:negativeT9', 'Nozzle T9 negative: %.1fK', T9);
    end
    V9 = sqrt(gamma_use * R * T9);
    gamma_a9 = gamma_use;
else
    % Full expansion (C-D nozzle or unchoked convergent nozzle): P9 = P_amb.
    P9 = P_amb;
    if strcmp(gas_model, 'real')
        h5  = h_T(Tt5, 'products', phi_eq);
        Pr5 = Pr_T(Tt5, 'products', phi_eq);
        Pr9_ideal = Pr5 * (P_amb/Pt9);
        T9_ideal  = T_from_Pr(Pr9_ideal, 'products', Tt5*0.7, phi_eq);
        h9_ideal  = h_T(T9_ideal, 'products', phi_eq);
        h9 = h5 - eta_n*(h5 - h9_ideal);
        T9 = T_from_h(h9, 'products', T9_ideal, phi_eq);
        if T9 <= 0
            error('tcat:nozzle:negativeT9', 'Nozzle T9 negative: %.1fK', T9);
        end
        V9  = sqrt(2.0 * (h5 - h9));
        cph = cp_T(T9, 'products', phi_eq);
    else
        cph = gamma_h*R/(gamma_h-1.0);
        pr_term = (P_amb/Pt9) ^ ((gamma_h-1.0)/gamma_h);
        T9 = Tt5 - eta_n*Tt5*(1.0 - pr_term);
        if T9 <= 0
            error('tcat:nozzle:negativeT9', 'Nozzle T9 negative: %.1fK', T9);
        end
        V9 = sqrt(2.0 * cph * (Tt5 - T9));
    end
end

a9   = sqrt(gamma_a9 * R * T9);
M9   = V9 / a9;
rho9 = P9 / (R * T9);
if (rho9*V9) > 0
    A_exit = m_dot_total / (rho9*V9);
else
    A_exit = [];
end

T_th   = Tt5 * 2.0 / (gamma_h + 1.0);
P_th   = Pt9 * (2.0/(gamma_h+1.0)) ^ (gamma_h/(gamma_h-1.0));
rho_th = P_th / (R*T_th);
a_th   = sqrt(gamma_h * R * T_th);
if (rho_th*a_th) > 0
    A_th = m_dot_total / (rho_th*a_th);
else
    A_th = [];
end

if isempty(A_exit)
    A_exit_for_noz = 0.0;
else
    A_exit_for_noz = A_exit;
end
noz_exp = nozzle_expansion_analysis(Pt9, P_amb, gamma_use, m_dot_total, V9, ...
                                      m_dot_inlet, V0, A_exit_for_noz, P9, eta_n);

st_9 = make_station('9', Tt5, Pt9, cph, T9, P9, M9, true);
end
