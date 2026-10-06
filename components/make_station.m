function st = make_station(station_id, T_total, P_total, cp, T_static, P_static, mach, hot)
%MAKE_STATION _GasPathComponent._make_station() port (engine_core.py:208-218).
%   T_static/P_static/mach stay [] (Python None) when not given.
if nargin < 5, T_static = []; end
if nargin < 6, P_static = []; end
if nargin < 7, mach = []; end
if nargin < 8 || isempty(hot), hot = false; end

if isempty(T_static)
    T_for_entropy = T_total;
else
    T_for_entropy = T_static;
end
if isempty(P_static)
    P_for_entropy = P_total;
else
    P_for_entropy = P_static;
end

st = struct('station_id', station_id, ...
             'T_static', T_static, 'T_total', T_total, ...
             'P_static', P_static, 'P_total', P_total, ...
             'entropy', cpg_entropy(T_for_entropy, P_for_entropy, cp), ...
             'mach', mach, 'hot', hot);
end
