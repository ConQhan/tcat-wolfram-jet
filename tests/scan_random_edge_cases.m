% scan_random_edge_cases.m - random + edge case robustness scan.
%   Like the Python scan_ideal_vs_real_gas.py, this is a repeatable
%   diagnostic report, not a pass/fail test, and it is not part of
%   run_all_tests.m (hundreds of cases would slow the standard suite).
%
%   Purpose: look for crashes or silent NaN/Inf results on random inputs.
%   It checks robustness, not specific numbers.
%
%   Usage: matlab -batch "run('<tool folder>/tests/scan_random_edge_cases.m')"

here = fileparts(mfilename('fullpath'));
root = fileparts(here);
addpath(genpath(root));

rng(42);   % fixed seed so the report is reproducible

N_RANDOM = 300;
base = default_engine_config();

bounds = struct( ...
    'M0',               [0.0,   2.2], ...
    'altitude_m',       [0.0,   18000.0], ...
    'm_dot',            [1.0,   200.0], ...
    'pi_c',             [2.0,   35.0], ...
    'eta_c',            [0.75,  0.92], ...
    'Tt4',              [900.0, 2000.0], ...
    'pi_b',             [0.90,  0.98], ...
    'eta_b',            [0.92,  0.995], ...
    'eta_t',            [0.82,  0.94], ...
    'eta_m',            [0.95,  1.00], ...
    'pi_d_max',         [0.90,  1.00], ...
    'eta_n',            [0.92,  0.99], ...
    'pi_n',             [0.95,  1.00], ...
    'power_offtake_kW', [0.0,   500.0], ...
    'M_des_t2',         [0.2,   0.6], ...
    'M_des_t3',         [0.2,   0.6], ...
    'M_des_t4',         [0.2,   0.6], ...
    'M_des_t5',         [0.2,   0.6], ...
    'M_des_nz',         [0.2,   0.6] ...
);
fn = fieldnames(bounds);

configs = cell(1, N_RANDOM);
for i = 1:N_RANDOM
    c = base;
    for k = 1:numel(fn)
        f = fn{k};
        lo = bounds.(f)(1); hi = bounds.(f)(2);
        c.(f) = lo + (hi-lo)*rand();
    end
    if rand() < 0.5, c.gas_model = 'real'; else, c.gas_model = 'ideal'; end
    if rand() < 0.5, c.nozzle_type = 'conv'; else, c.nozzle_type = 'cd'; end
    c.use_polytropic = rand() < 0.5;
    if c.use_polytropic
        c.e_c = 0.85 + 0.07*rand();
        c.e_t = 0.85 + 0.07*rand();
    end
    configs{i} = c;
end

% ---- Hand-picked edge cases ----
edge = {};
mk = @() base;

c = mk(); c.M0 = 0.0;           edge{end+1} = c; %#ok<AGROW>
c = mk(); c.M0 = 2.2;           edge{end+1} = c; %#ok<AGROW>
c = mk(); c.altitude_m = 0.0;   edge{end+1} = c; %#ok<AGROW>
c = mk(); c.altitude_m = 18000.0; edge{end+1} = c; %#ok<AGROW>
c = mk(); c.pi_c = 2.0;         edge{end+1} = c; %#ok<AGROW>
c = mk(); c.pi_c = 35.0;        edge{end+1} = c; %#ok<AGROW>
c = mk(); c.Tt4 = 900.0;        edge{end+1} = c; %#ok<AGROW>  % small margin to Tt3
c = mk(); c.Tt4 = 2000.0;       edge{end+1} = c; %#ok<AGROW>  % close to the TIT warning threshold
c = mk(); c.m_dot = 0.5;        edge{end+1} = c; %#ok<AGROW>  % very low mass flow

gasOpts  = {'ideal','real'};
noOpts   = {'cd','conv'};
polyOpts = [false, true];
for gi = 1:2
    for ni = 1:2
        for pj = 1:2
            c = mk();
            c.gas_model      = gasOpts{gi};
            c.nozzle_type    = noOpts{ni};
            c.use_polytropic = polyOpts(pj);
            edge{end+1} = c; %#ok<AGROW>
        end
    end
end

allConfigs = [configs, edge];
nTotal = numel(allConfigs);
fprintf('Total cases: %d (%d random + %d edge cases)\n', nTotal, N_RANDOM, numel(edge));

nSuccess = 0; nFail = 0;
failIds = containers.Map('KeyType','char','ValueType','double');
unexpectedErrors = {};
nanInfFlags = {};
outOfRangeCount = 0;

for i = 1:nTotal
    cfg = allConfigs{i};
    try
        r = run_design_point(cfg);
    catch err
        idKey = err.identifier;
        if isempty(idKey), idKey = '(no identifier)'; end
        if isKey(failIds, idKey)
            failIds(idKey) = failIds(idKey) + 1;
        else
            failIds(idKey) = 1;
        end
        if isempty(err.identifier) || ~startsWith(err.identifier, 'tcat:')
            unexpectedErrors{end+1} = sprintf('case %d: [%s] %s', i, idKey, err.message); %#ok<AGROW>
        end
        nFail = nFail + 1;
        continue
    end

    if ~r.success
        % run_design_point.m catches every error and returns
        % success=false without the identifier, so the first word of the
        % message (e.g. "Nozzle:", "Turbine", "Combustor") is used to group
        % the failures.
        msg = r.error_msg;
        colonIdx = strfind(msg, ':');
        if ~isempty(colonIdx)
            reasonKey = strtrim(msg(1:colonIdx(1)-1));
        else
            reasonKey = strtrim(msg(1:min(30,numel(msg))));
        end
        idKey = sprintf('(failed, no MATLAB error thrown) -- "%s..."', reasonKey);
        if isKey(failIds, idKey)
            failIds(idKey) = failIds(idKey) + 1;
        else
            failIds(idKey) = 1;
        end
        nFail = nFail + 1;
        continue
    end

    nSuccess = nSuccess + 1;

    % NaN/Inf scan: TSFC = Inf when F_spec <= 0 is documented behaviour
    % (run_design_point.m); anything else is unexpected.
    p = r.performance;
    pf = fieldnames(p);
    for k = 1:numel(pf)
        fld = pf{k};
        val = p.(fld);
        if ~isnumeric(val) || isempty(val), continue; end
        if strcmp(fld, 'TSFC') && isinf(val) && p.F_spec <= 0
            continue  % documented case
        end
        if any(isnan(val(:))) || any(isinf(val(:)))
            nanInfFlags{end+1} = sprintf('case %d: performance.%s = %g', i, fld, val); %#ok<AGROW>
        end
    end

    % Real gas polynomial used outside its range (200-2400 K, see
    % real_gas/species_coeffs.m): not an error, a known limitation.
    if strcmp(cfg.gas_model, 'real')
        temps = [r.stations.s0.T_total, r.stations.t2.T_total, r.stations.t3.T_total, ...
                 r.stations.t4.T_total, r.stations.t5.T_total, r.stations.s9.T_static];
        if any(temps < 200) || any(temps > 2400)
            outOfRangeCount = outOfRangeCount + 1;
        end
    end
end

fprintf('\n=== SUMMARY ===\n');
fprintf('Succeeded: %d/%d  (%.1f%%)\n', nSuccess, nTotal, 100*nSuccess/nTotal);
fprintf('Failed   : %d/%d  (%.1f%%)\n', nFail, nTotal, 100*nFail/nTotal);

fprintf('\n--- Failure reasons ---\n');
ks = keys(failIds);
for i = 1:numel(ks)
    fprintf('  %-60s : %d\n', ks{i}, failIds(ks{i}));
end

fprintf('\n--- Unexpected errors (no tcat: identifier): %d ---\n', numel(unexpectedErrors));
for i = 1:numel(unexpectedErrors)
    fprintf('  %s\n', unexpectedErrors{i});
end

fprintf('\n--- Unexpected NaN/Inf in successful cases: %d ---\n', numel(nanInfFlags));
for i = 1:numel(nanInfFlags)
    fprintf('  %s\n', nanInfFlags{i});
end

nRealCases = sum(cellfun(@(c) strcmp(c.gas_model,'real'), allConfigs));
fprintf('\n--- Real gas polynomial outside 200-2400 K: %d/%d real gas cases ---\n', ...
    outOfRangeCount, nRealCases);

if isempty(unexpectedErrors) && isempty(nanInfFlags)
    fprintf('\nSCAN CLEAN: no unexpected errors or silent NaN/Inf.\n');
else
    fprintf('\nSCAN FOUND ISSUES: see the lists above.\n');
end
