% compare_reference_case.m
% Compares the MATLAB port with the Cohen-Rogers "Gas Turbine Theory"
% Example 3.1 reference case (simple turbojet, choked convergent nozzle).
% Reference data: tests/fixtures/reference_cases.json,
% id="full_cycle_turbojet_gttpt3_ex31".
%
% Usage: run this file in MATLAB (the tool folder is added to the path).

here = fileparts(mfilename('fullpath'));
root = fileparts(here);
addpath(genpath(root));

raw = jsondecode(fileread(fullfile(root, 'tests', 'fixtures', 'reference_cases.json')));
cs = [];
for i = 1:numel(raw.cases)
    if strcmp(raw.cases{i}.id, 'full_cycle_turbojet_gttpt3_ex31')
        cs = raw.cases{i};
    end
end
ref = cs.reference_outputs;
gc  = cs.gcam_config;

cfg = default_engine_config();
cfg.M0 = gc.M0; cfg.altitude_m = gc.altitude_m;
cfg.m_dot = gc.m_dot_fixed;
cfg.pi_d_max = gc.pi_d_max;
cfg.pi_c = gc.pi_c; cfg.eta_c = gc.eta_c; cfg.use_polytropic = logical(gc.use_polytropic);
cfg.Tt4 = gc.Tt4; cfg.pi_b = gc.pi_b; cfg.eta_b = gc.eta_b;
cfg.eta_t = gc.eta_t; cfg.eta_m = gc.eta_m;
cfg.eta_n = gc.eta_n; cfg.nozzle_type = gc.nozzle_type;
cfg.FHV = gc.FHV;
cfg.gamma_c = gc.gamma_c; cfg.gamma_h = gc.gamma_h;
cfg.gas_model = gc.gas_model;

r = run_design_point(cfg);
if ~r.success
    error('Engine did not run: %s', r.error_msg);
end
s = r.stations; p = r.performance;

mat = struct();
mat.Tt2_K = s.t2.T_total; mat.Pt2_bar = s.t2.P_total/1e5;
mat.Tt3_K = s.t3.T_total; mat.Pt3_bar = s.t3.P_total/1e5;
mat.Tt4_K = s.t4.T_total; mat.Pt4_bar = s.t4.P_total/1e5;
mat.Tt5_K = s.t5.T_total; mat.Pt5_bar = s.t5.P_total/1e5;
mat.T9_K  = s.s9.T_static; mat.P9_bar = s.s9.P_static/1e5;
mat.F_spec_Nskg = p.F_spec;

rows   = {'Tt2_K','Pt2_bar','Tt3_K','Pt3_bar','Tt4_K','Pt4_bar','Tt5_K','Pt5_bar','T9_K','P9_bar','F_spec_Nskg'};
labels = {'Tt2 [K]';'Pt2 [bar]';'Tt3 [K]';'Pt3 [bar]';'Tt4 [K]';'Pt4 [bar]';'Tt5 [K]';'Pt5 [bar]'; ...
          'T9 [K]';'P9 [bar]';'F_spec [N.s/kg]'};

n = numel(rows);
Reference_Book = nan(n,1); MATLAB_Port = nan(n,1);
for i = 1:n
    Reference_Book(i) = ref.(rows{i});
    MATLAB_Port(i)    = mat.(rows{i});
end
Diff_pct = abs(MATLAB_Port./Reference_Book - 1) * 100;

T = table(labels, Reference_Book, MATLAB_Port, Diff_pct, ...
    'VariableNames', {'Quantity','Reference_Book','MATLAB_Port','Diff_pct'});

fprintf('\nCASE: M0=%.2f  altitude=%.0fm  pi_c=%.1f  Tt4=%.0fK  (Cohen-Rogers Example 3.1)\n\n', ...
    cfg.M0, cfg.altitude_m, cfg.pi_c, cfg.Tt4);
disp(T)
fprintf(['NOTE: the Tt5/Pt5/T9/P9/F_spec difference (~0.5-4%%) comes from the book\n' ...
    'neglecting the (1+f) factor in the turbine work balance; GCAM/MATLAB is\n' ...
    'more accurate here, this is not a port error (see reference_cases.json).\n']);
