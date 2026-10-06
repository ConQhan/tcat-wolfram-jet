function cfg = default_engine_config()
%DEFAULT_ENGINE_CONFIG Turbojet design-point input struct (the subset of
%   the Python EngineConfig covered by this port, engine_core.py:105-191).
%
%   Python fields left out on purpose: engine_type (always turbojet),
%   use_dynamic_mdot/A_inlet_m2 (dynamic mass flow), bleed (BleedConfig),
%   use_afterburner/T_ab/pi_ab/eta_ab (afterburner), turbofan
%   (TurbofanConfig), power_turbine/propeller (turboprop/turboshaft),
%   is_off_design/throttle/off_design_cfg/comp_map/turb_map (off-design
%   solver). "m_dot_fixed" is simplified to "m_dot" (with no dynamic mass
%   flow branch it is the only mass flow source).

c = tcat_constants();

cfg = struct();

% Flight conditions
cfg.M0         = 0.0;
cfg.altitude_m = 0.0;
cfg.m_dot      = 50.0;

% Gas model: 'ideal' (constant Cp/gamma) | 'real' (real_gas.py, temperature dependent Cp)
cfg.gas_model  = 'ideal';

% Component parameters
cfg.pi_c      = 15.0;
cfg.eta_c     = 0.85;
cfg.eta_m     = 1.00;
cfg.Tt4       = 1400.0;
cfg.pi_b      = 0.96;
cfg.eta_b     = 0.98;
cfg.eta_t     = 0.90;
cfg.pi_d_max  = 0.99;
cfg.eta_n     = 0.97;
cfg.nozzle_type = 'cd';   % 'cd' (full expansion) | 'conv' (convergent, may be choked)
cfg.FHV       = c.FHV_JET_A;

cfg.pi_n              = 1.0;    % Turbine exit duct total pressure ratio (GasTurb: Turbine Exit Duct Press Ratio)
cfg.power_offtake_kW  = 0.0;    % Accessory power offtake [kW]

% Polytropic efficiency
cfg.use_polytropic = false;
cfg.e_c = 0.90;
cfg.e_t = 0.90;

% Gas properties
cfg.gamma_c = c.GAMMA_C;
cfg.gamma_h = c.GAMMA_H;

% Design Mach numbers (for station sizing)
cfg.M_des_t2 = 0.45;
cfg.M_des_t3 = 0.35;
cfg.M_des_t4 = 0.30;
cfg.M_des_t5 = 0.40;
cfg.M_des_nz = 0.50;

% Physical envelope check
cfg.max_diameter_limit_mm = 0.0;   % 0 = off

end
