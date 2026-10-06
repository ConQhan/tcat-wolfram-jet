function C = gcam_constants()
%GCAM_CONSTANTS Single source of constants (counterpart of Python constants.py).
%   Only the subset used by the turbojet design-point port is included.
%   Source: GCAM/constants.py

% ---- 1. CPG gas constants ----
C.R      = 287.05;                       % Gas constant of air [J/(kg*K)]
C.GAMMA_C = 1.40;                        % Cold section heat capacity ratio [-]
C.CPC    = C.GAMMA_C * C.R / (C.GAMMA_C - 1.0);   % ~1004.175 [J/(kg*K)]
C.GAMMA_H = 1.33;                        % Hot section heat capacity ratio [-]
C.CPH    = C.GAMMA_H * C.R / (C.GAMMA_H - 1.0);   % ~1243.607 [J/(kg*K)]

% ---- 2. ISA sea level reference values (ICAO Doc 7488-CD) ----
C.ISA_T_SL   = 288.15;                   % [K]
C.ISA_P_SL   = 101325.0;                 % [Pa]
C.ISA_RHO_SL = C.ISA_P_SL / (C.R * C.ISA_T_SL);   % [kg/m^3]
C.ISA_LAPSE  = -0.0065;                  % [K/m] (0-11000m)
C.ISA_T_TROP = 216.65;                   % [K]
C.ISA_H_TROP = 11000.0;                  % [m]
C.G0         = 9.80665;                  % [m/s^2]

% ---- 3. Fuel properties ----
C.FHV_JET_A = 42800000.0;                % Jet-A lower heating value [J/kg]

% ---- 4. Material / design limits ----
C.T_TI_LIMIT     = 950.0;                % Titanium alloy upper limit [K]
C.T_NICKEL_LIMIT = 1200.0;               % Nickel superalloy upper limit [K]
C.T_TIT_WARN     = 1800.0;               % TIT yellow warning threshold [K]
C.T_TIT_LIMIT    = 2200.0;               % TIT red error threshold [K]
C.FAR_WARN       = 0.06;                 % FAR nominal upper value [-]
C.FAR_LIMIT      = 0.10;                 % FAR physical upper limit [-]

% ---- 5. Real gas (real_gas.py) ----
C.FST_C12H23 = 0.0685;   % Stoichiometric fuel/air ratio, C12H23 (Mattingly)

end
