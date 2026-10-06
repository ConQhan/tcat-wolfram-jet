function cp = cp_T(T, species, phi_eq)
%CP_T Cp(T) [J/(kg*K)] -- mass-weighted sum over the mixture species (real_gas.py:135-139).
if nargin < 2 || isempty(species), species = 'air'; end
if nargin < 3 || isempty(phi_eq),  phi_eq  = 0.35;  end
S = species_coeffs();
w = mixture_weights(species, phi_eq);
fn = fieldnames(w);
cp = 0.0;
for i = 1:numel(fn)
    sp = fn{i};
    coeffs = S.(sp);          % low to high: coeffs(n+1) is the T^n coefficient
    term = 0.0;
    for n = 0:6
        term = term + coeffs(n+1) * T^n;
    end
    cp = cp + w.(sp) * term;
end
end
