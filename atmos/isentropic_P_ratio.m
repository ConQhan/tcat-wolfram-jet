function r = isentropic_P_ratio(M, gamma)
%ISENTROPIC_P_RATIO Pt/P = (1+(gamma-1)/2*M^2)^(gamma/(gamma-1))  (atmos_utils.py:135)
r = isentropic_T_ratio(M, gamma) ^ (gamma / (gamma - 1.0));
end
