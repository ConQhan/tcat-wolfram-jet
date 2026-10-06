function grid = param_sweep(base_cfg, field_a, values_a, field_b, values_b)
%PARAM_SWEEP Parametric sweep: the core of Python
%   gui_app/tabs/param_table_tab.py _run_param_table() (lines 142-184)
%   without the GUI. Unlike the Python GUI (thrust + TSFC only), it returns
%   every PerformanceMetrics field on the (ib, ia) grid.
%
%   Inputs:
%     base_cfg : base struct from default_engine_config()
%     field_a  : char/string, first EngineConfig field to sweep (columns)
%     values_a : numeric vector of values for field_a
%     field_b  : char/string, second EngineConfig field to sweep (rows)
%     values_b : numeric vector of values for field_b
%
%   Returns grid (struct): grid.values_a, grid.values_b,
%   grid.success(ib,ia) (logical) and grid.<field>(ib,ia) for every
%   PerformanceMetrics field (failed cells are NaN).

numeric_fields = {'F_spec','TSFC','eta_th','eta_p','eta_o','V0','V9','f_core','f_ab', ...
    'thrust_N','area_throat','area_exit','M_exit','tau_lam','pi_c_opt','pi_d_eff', ...
    'F_momentum','F_pressure','is_choked','m_bleed','Tt4_mix','eta_c_isen','eta_t_isen'};

na = numel(values_a);
nb = numel(values_b);

grid = struct();
grid.field_a  = field_a;  grid.field_b  = field_b;
grid.values_a = values_a(:)';
grid.values_b = values_b(:)';
grid.success  = false(nb, na);
for k = 1:numel(numeric_fields)
    grid.(numeric_fields{k}) = NaN(nb, na);
end

for ib = 1:nb
    for ia = 1:na
        cfg2 = base_cfg;
        cfg2.(field_a) = values_a(ia);
        cfg2.(field_b) = values_b(ib);
        try
            r = run_design_point(cfg2);
        catch
            r = struct('success', false);
        end
        if isfield(r, 'success') && r.success && ~isempty(r.performance)
            grid.success(ib, ia) = true;
            p = r.performance;
            for k = 1:numel(numeric_fields)
                fn = numeric_fields{k};
                if isfield(p, fn) && ~isempty(p.(fn))
                    grid.(fn)(ib, ia) = double(p.(fn));
                end
            end
        end
    end
end
end
