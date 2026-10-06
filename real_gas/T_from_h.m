function T = T_from_h(h, species, T_guess, phi_eq)
%T_FROM_H Solves h(T) = h for T by Newton-Raphson
%   (real_gas.py:176-188). 30 fixed iterations; the early exits on cp<=0
%   and |dT|<1e-6 are kept exactly (the golden values were produced with
%   this behaviour).
if nargin < 2 || isempty(species), species = 'air'; end
if nargin < 3 || isempty(T_guess), T_guess = 500.0; end
if nargin < 4 || isempty(phi_eq),  phi_eq  = 0.35;  end
T = T_guess;
for i = 1:30
    err = h_T(T, species, phi_eq) - h;
    cp  = cp_T(T, species, phi_eq);
    if cp <= 0
        break
    end
    dT = err / cp;
    T = T - dT;
    if abs(dT) < 1e-6
        break
    end
end
end
