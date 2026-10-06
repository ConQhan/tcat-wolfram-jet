function s = cpg_entropy(T, P, cp, T_ref, P_ref)
%CPG_ENTROPY CPG entropy change: ds = cp*ln(T/T_ref) - R*ln(P/P_ref)  [J/(kg*K)]
%   (atmos_utils.py:151). ISA sea level is used when T_ref/P_ref are not given.
if nargin < 5 || isempty(P_ref)
    c = tcat_constants();
    P_ref = c.ISA_P_SL;
end
if nargin < 4 || isempty(T_ref)
    c = tcat_constants();
    T_ref = c.ISA_T_SL;
end
R = tcat_constants().R;
s = cp * log(T / T_ref) - R * log(P / P_ref);
end
