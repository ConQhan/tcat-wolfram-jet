function pr = Pr_T(T, species, phi_eq)
%PR_T Isentropic reference pressure Pr(T) = exp(phi(T)/R)  (real_gas.py:171-173).
if nargin < 2 || isempty(species), species = 'air'; end
if nargin < 3 || isempty(phi_eq),  phi_eq  = 0.35;  end
R = tcat_constants().R;
pr = exp(phi_T(T, species, phi_eq) / R);
end
