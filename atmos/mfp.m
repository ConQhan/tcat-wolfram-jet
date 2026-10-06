function v = mfp(M, gamma)
%MFP Mass Flow Parameter  (atmos_utils.py:165)
%   MFP = sqrt(gamma) * M * (1+(gamma-1)/2*M^2)^(-(gamma+1)/(2*(gamma-1)))
if M <= 0.0
    v = 0.0;
    return
end
expo = -(gamma + 1.0) / (2.0 * (gamma - 1.0));
v = sqrt(gamma) * M * isentropic_T_ratio(M, gamma) ^ expo;
end
