function r = isentropic_T_ratio(M, gamma)
%ISENTROPIC_T_RATIO Tt/T = 1 + (gamma-1)/2 * M^2  (atmos_utils.py:127)
r = 1.0 + (gamma - 1.0) / 2.0 * M * M;
end
