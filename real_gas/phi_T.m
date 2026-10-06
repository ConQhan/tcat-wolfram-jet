function ph = phi_T(T, species, phi_eq)
%PHI_T Reduced entropy function phi(T) = integral_Tref^T cp/T' dT'
%   [J/(kg*K)]  (real_gas.py:153-168). NOTE: "phi" of the FAIR nomenclature;
%   not to be confused with the equivalence ratio phi_eq (same warning as
%   in the source).
if nargin < 2 || isempty(species), species = 'air'; end
if nargin < 3 || isempty(phi_eq),  phi_eq  = 0.35;  end
Tr = 273.15;
S = species_coeffs();
w = mixture_weights(species, phi_eq);
fn = fieldnames(w);
ph = 0.0;
for i = 1:numel(fn)
    sp = fn{i};
    coeffs = S.(sp);                       % coeffs(1)=a0 ... coeffs(7)=a6
    sp_total = coeffs(1) * log(T/Tr);
    for n = 1:6
        c = coeffs(n+1);
        sp_total = sp_total + c/n * (T^n - Tr^n);
    end
    ph = ph + w.(sp) * sp_total;
end
end
