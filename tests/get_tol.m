function tol = get_tol(cs, key)
%GET_TOL Counterpart of _tol() in Python test_reference_cases.py.
%   tolerance_pct is either a scalar (applies to every key) or a struct
%   {"default": .., "KEY": ..}; the fixture's "default" fallback is kept.
t = cs.tolerance_pct;
if isstruct(t)
    if isfield(t, key)
        tol = t.(key);
    else
        tol = t.default;
    end
else
    tol = t;
end
end
