function [st_t4, f] = combustor_run(st_in, Tt4, gamma_c, gamma_h, pi_b, eta_b, FHV, gas_model)
%COMBUSTOR_RUN _Combustor.run() port (engine_core.py:293-331).
R = tcat_constants().R;
Tt3 = st_in.T_total; Pt3 = st_in.P_total;
Pt4 = Pt3 * pi_b;

if strcmp(gas_model, 'real')
    h3 = h_T(Tt3, 'air');
    % phi_eq depends on f itself (phi_eq = f/FST), so it is solved by
    % fixed-point iteration (same approach as real_gas.py:303-318).
    phi_eq = 0.35;
    f_new = NaN;
    for i = 1:10
        h4  = h_T(Tt4, 'products', phi_eq);
        num = h4 - h3;
        den = FHV*eta_b - h4;
        if den <= 0
            error('tcat:combustor:denNonPositive', ...
                'Combustor: FHV*eta_b < cph*Tt4. Tt4=%.0fK.', Tt4);
        end
        if num < 0
            error('tcat:combustor:numNegative', ...
                'Tt4(%.0fK) < Tt3(%.1fK).', Tt4, Tt3);
        end
        f_new = num/den;
        phi_new = f_new / tcat_constants().FST_C12H23;
        if abs(phi_new - phi_eq) < 1e-6
            phi_eq = phi_new;
            break
        end
        phi_eq = phi_new;
    end
    f = f_new;
    cph = cp_T(Tt4, 'products', phi_eq);
    st_t4 = make_station('t4', Tt4, Pt4, cph, [], [], [], true);
    return
end

cpc = gamma_c*R/(gamma_c-1.0);
cph = gamma_h*R/(gamma_h-1.0);
num = cph*Tt4 - cpc*Tt3;
den = FHV*eta_b - cph*Tt4;
if den <= 0
    error('tcat:combustor:denNonPositive', ...
        'Combustor: FHV*eta_b < cph*Tt4. Tt4=%.0fK.', Tt4);
end
if num < 0
    error('tcat:combustor:numNegative', ...
        'Tt4(%.0fK) < Tt3(%.1fK).', Tt4, Tt3);
end
f = num/den;
st_t4 = make_station('t4', Tt4, Pt4, cph, [], [], [], true);
end
