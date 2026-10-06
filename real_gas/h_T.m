function h = h_T(T, species, phi_eq)
%H_T Sensible enthalpy h(T) = integral_Tref^T cp dT'  [J/kg]  (real_gas.py:142-150).
if nargin < 2 || isempty(species), species = 'air'; end
if nargin < 3 || isempty(phi_eq),  phi_eq  = 0.35;  end
Tr = 273.15;   % real_gas.py T_REF
S = species_coeffs();
w = mixture_weights(species, phi_eq);
fn = fieldnames(w);
h = 0.0;
for i = 1:numel(fn)
    sp = fn{i};
    coeffs = S.(sp);
    term = 0.0;
    for n = 0:6
        c = coeffs(n+1);
        term = term + c/(n+1) * (T^(n+1) - Tr^(n+1));
    end
    h = h + w.(sp) * term;
end
end
