function result = run_design_point(cfg)
%RUN_DESIGN_POINT JetEngineCycle._run_design_point() port (engine_core.py:
%   597-798), turbojet only. The dynamic mass flow (use_dynamic_mdot),
%   bleed and afterburner branches are removed; there is no turbofan.
%   power_offtake_kW and max_diameter_limit_mm are included.
%
%   Station names: Python's "0" and "9" are not valid MATLAB field names,
%   so they are stored as s0/s9 (t2/t3/t4/t5 unchanged).
%
%   Returns: struct(stations, performance, geometries, isa, nozzle_exp,
%   warnings, success, error_msg)

c = tcat_constants();
R = c.R;

result = struct();
result.stations    = struct();
result.performance = [];
result.geometries  = [];
result.isa         = [];
result.nozzle_exp  = [];
result.warnings    = {};
result.success     = true;
result.error_msg   = '';

try
    % --- Ambient (no dynamic mass flow: m_dot is always fixed) ---
    atm = isa_at(cfg.altitude_m);
    T0 = atm.T; P0 = atm.P;
    m_dot = cfg.m_dot;
    result.isa = atm;

    warnings = {};
    if cfg.altitude_m > 0
        warnings{end+1} = sprintf('ISA@%.0fm T0=%.1fK P0=%.2fkPa mdot=%.3fkg/s', ...
            cfg.altitude_m, T0, P0/1000, m_dot);
    end
    geos = [];

    % 1. Diffuser
    [st0, st_t2, V0, pi_d_eff] = diffuser_run(cfg.M0, T0, P0, cfg.gamma_c, cfg.pi_d_max, cfg.gas_model);
    result.stations.s0 = st0;
    result.stations.t2 = st_t2;
    g = size_station('t2', m_dot, st_t2.T_total, st_t2.P_total, cfg.M_des_t2, cfg.gamma_c);
    geos = [geos, g]; warnings = local_check_diam(g, cfg.max_diameter_limit_mm, warnings);
    if cfg.M0 > 1.0
        warnings{end+1} = sprintf('MIL-E-5008B: pid,max=%.3f->pid,eff=%.4f (M0=%.2f)', ...
            cfg.pi_d_max, pi_d_eff, cfg.M0);
    end

    % 2. Compressor
    [st_t3, Wc, eta_c_act] = compressor_run(st_t2, cfg.gamma_c, cfg.pi_c, cfg.eta_c, ...
        cfg.use_polytropic, cfg.e_c, cfg.gas_model);
    result.stations.t3 = st_t3;
    g = size_station('t3', m_dot, st_t3.T_total, st_t3.P_total, cfg.M_des_t3, cfg.gamma_c);
    geos = [geos, g]; warnings = local_check_diam(g, cfg.max_diameter_limit_mm, warnings);
    Tt3 = st_t3.T_total;
    if cfg.use_polytropic
        warnings{end+1} = sprintf('Polytropic compressor: ec=%.3f->eta_c,isen=%.4f Tt3=%.1fK', ...
            cfg.e_c, eta_c_act, Tt3);
    end
    if Tt3 > c.T_TI_LIMIT
        warnings{end+1} = sprintf('Compressor Tt3=%.0fK>%.0fK (Ti limit). Nickel alloy required.', Tt3, c.T_TI_LIMIT);
    elseif Tt3 > 0.85*c.T_TI_LIMIT
        warnings{end+1} = sprintf('Compressor Tt3=%.0fK close to the Ti limit.', Tt3);
    end

    % 3. Combustor
    [st_t4, f_core] = combustor_run(st_t3, cfg.Tt4, cfg.gamma_c, cfg.gamma_h, ...
        cfg.pi_b, cfg.eta_b, cfg.FHV, cfg.gas_model);
    result.stations.t4 = st_t4;
    % (no bleed, so st_t4.T_total is already cfg.Tt4; the Python "unmixed"
    % copy is not needed)
    g = size_station('t4', m_dot, cfg.Tt4, st_t4.P_total, cfg.M_des_t4, cfg.gamma_h);
    geos = [geos, g]; warnings = local_check_diam(g, cfg.max_diameter_limit_mm, warnings);
    if cfg.Tt4 > c.T_TIT_LIMIT
        warnings{end+1} = sprintf('TIT=%.0fK>%.0fK', cfg.Tt4, c.T_TIT_LIMIT);
    elseif cfg.Tt4 > c.T_TIT_WARN
        warnings{end+1} = sprintf('TIT=%.0fK high', cfg.Tt4);
    end
    if f_core > c.FAR_LIMIT
        warnings{end+1} = sprintf('FAR=%.4f>%.2f', f_core, c.FAR_LIMIT);
    elseif f_core > c.FAR_WARN
        warnings{end+1} = sprintf('FAR=%.4f>%.2f', f_core, c.FAR_WARN);
    end

    m_bleed = 0.0;         % no bleed in this port
    Tt4_mix = cfg.Tt4;     % no bleed mixing

    % 4. Turbine (W_offtake included; no fan/bleed, their power terms are zero)
    if m_dot > 0
        W_offtake = (cfg.power_offtake_kW*1000.0) / m_dot;
    else
        W_offtake = 0.0;
    end
    [st_t5, ~, eta_t_act] = turbine_run(st_t4, Wc, f_core, cfg.gamma_h, cfg.eta_t, cfg.eta_m, ...
        cfg.use_polytropic, cfg.e_t, cfg.gas_model, W_offtake);
    result.stations.t5 = st_t5;
    m_hot = m_dot*(1.0+f_core) - m_bleed;
    g = size_station('t5', m_hot, st_t5.T_total, st_t5.P_total, cfg.M_des_t5, cfg.gamma_h);
    geos = [geos, g]; warnings = local_check_diam(g, cfg.max_diameter_limit_mm, warnings);
    if cfg.use_polytropic
        warnings{end+1} = sprintf('Polytropic turbine: et=%.3f->eta_t,isen=%.4f Tt5=%.1fK', ...
            cfg.e_t, eta_t_act, st_t5.T_total);
    end

    % 5. Afterburner: not included (always off)
    nozzle_inlet = st_t5;
    f_ab = 0.0;

    % 6. Nozzle
    f_total = f_core + f_ab;
    m_dot_total = m_dot*(1.0+f_total) - m_bleed;
    [st_9, V9, A_th, A_ex, noz_exp] = nozzle_run(nozzle_inlet, P0, m_dot_total, m_dot, V0, ...
        cfg.gamma_h, f_total, cfg.eta_n, cfg.pi_n, cfg.gas_model, cfg.nozzle_type);
    result.stations.s9 = st_9;
    result.nozzle_exp  = noz_exp;
    g = size_station(nozzle_inlet.station_id, m_dot_total, nozzle_inlet.T_total, ...
        nozzle_inlet.P_total, cfg.M_des_nz, cfg.gamma_h);
    geos = [geos, g]; warnings = local_check_diam(g, cfg.max_diameter_limit_mm, warnings);
    if noz_exp.is_choked
        choke_txt = 'CHOKED';
    else
        choke_txt = 'UNCHOKED';
    end
    warnings{end+1} = sprintf('Nozzle: %s PR=%.2f crit=%.2f %s', ...
        choke_txt, noz_exp.PR_actual, noz_exp.PR_critical, noz_exp.state);

    % 7. Performance
    cpc = cfg.gamma_c*R/(cfg.gamma_c-1.0);
    if m_dot > 0
        F_pressure_spec = noz_exp.F_pressure / m_dot;
    else
        F_pressure_spec = 0.0;
    end
    F_spec = (1.0+f_total)*V9 - V0 + F_pressure_spec;
    if F_spec > 0
        TSFC = f_total / F_spec;
    else
        TSFC = Inf;
    end
    if F_spec <= 0
        warnings{end+1} = sprintf('Specific thrust <= 0 (F_spec=%.1f N.s/kg): no net thrust, TSFC undefined (Inf).', F_spec);
    elseif F_spec < 150.0
        warnings{end+1} = sprintf(['Specific thrust very low (F_spec=%.1f N.s/kg): nozzle pressure ratio ' ...
            '(Pt9/P0=%.3f) far below the critical value (~%.2f).'], F_spec, noz_exp.PR_actual, noz_exp.PR_critical);
    end

    KE_out = (1.0+f_total)*V9^2/2.0;
    KE_in  = V0^2/2.0;
    fuel_e = f_total*cfg.FHV;
    if fuel_e > 0
        eta_th = (KE_out-KE_in)/fuel_e;
    else
        eta_th = 0.0;
    end
    if (KE_out-KE_in) > 0 && V0 > 0
        eta_p = (F_spec*V0)/(KE_out-KE_in);
    else
        eta_p = 0.0;
    end

    % The tau_lambda diagnostic always uses the ideal cph (engine_core.py:661,
    % independent of gas_model; information only).
    cph_diag = cfg.gamma_h*R/(cfg.gamma_h-1.0);
    tau_lam  = tau_lambda(cph_diag, cfg.Tt4, cpc, T0);
    tau_r    = 1.0 + (cfg.gamma_c-1.0)/2.0*cfg.M0^2;
    pi_c_opt = optimal_pr_max_thrust(tau_lam, tau_r, cfg.gamma_c);

    thrust_N = m_dot * F_spec;

    perf = struct();
    perf.F_spec = F_spec; perf.TSFC = TSFC;
    perf.eta_th = eta_th; perf.eta_p = eta_p; perf.eta_o = eta_th*eta_p;
    perf.V0 = V0; perf.V9 = V9; perf.f_core = f_core; perf.f_ab = f_ab;
    perf.thrust_N = thrust_N;
    perf.area_throat = A_th; perf.area_exit = A_ex; perf.M_exit = st_9.mach;
    perf.tau_lam = tau_lam; perf.pi_c_opt = pi_c_opt; perf.pi_d_eff = pi_d_eff;
    perf.F_momentum = noz_exp.F_momentum; perf.F_pressure = noz_exp.F_pressure;
    perf.nozzle_state = noz_exp.state; perf.is_choked = noz_exp.is_choked;
    perf.m_bleed = m_bleed; perf.Tt4_mix = Tt4_mix;
    perf.eta_c_isen = eta_c_act; perf.eta_t_isen = eta_t_act;

    result.performance = perf;
    result.geometries  = geos;
    result.warnings    = warnings;

catch err
    result.success   = false;
    result.error_msg  = err.message;
end
end


function warnings = local_check_diam(geo, lim, warnings)
%LOCAL_CHECK_DIAM Physical envelope diameter check (engine_core.py:576-585).
if lim > 0 && geo.diameter_mm > lim
    warnings{end+1} = sprintf(['PHYSICAL ENVELOPE EXCEEDED! Station %s: D=%.1fmm > ' ...
        'limit %.0fmm (A=%.1fcm2 Tt=%.0fK)'], ...
        geo.station_id, geo.diameter_mm, lim, geo.area_m2*10000, geo.Tt);
end
end
