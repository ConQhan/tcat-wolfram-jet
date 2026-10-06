function T = T_from_Pr(Pr, species, T_guess, phi_eq)
%T_FROM_PR Solves Pr(T) = Pr for T by Newton-Raphson
%   (real_gas.py:191-207). d(phi)/dT = cp(T)/T => d(ln Pr)/dT = cp(T)/(R*T).
if nargin < 2 || isempty(species), species = 'air'; end
if nargin < 3 || isempty(T_guess), T_guess = 500.0; end
if nargin < 4 || isempty(phi_eq),  phi_eq  = 0.35;  end
R = gcam_constants().R;
target_phi = R * log(Pr);
T = T_guess;
for i = 1:30
    err   = phi_T(T, species, phi_eq) - target_phi;
    deriv = cp_T(T, species, phi_eq) / T;
    if deriv <= 0
        break
    end
    dT = err / deriv;
    T = T - dT;
    if abs(dT) < 1e-6
        break
    end
end
end
