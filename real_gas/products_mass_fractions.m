function w = products_mass_fractions(phi_eq)
%PRODUCTS_MASS_FRACTIONS C12H23 + air combustion products, atom balance
%   (AEGCombustion.pdf Eq 9.1/9.20), real_gas.py:100-118.
S = species_coeffs();
phi_eq = max(0.0, min(phi_eq, 0.999));
x = 12.0; y = 23.0;
a = x + y/4.0;
n_CO2 = x*phi_eq;
n_H2O = (y/2.0)*phi_eq;
n_O2  = a*(1.0-phi_eq);
n_N2  = a*(79.0/21.0);
ntot  = n_CO2 + n_H2O + n_O2 + n_N2;
yCO2 = n_CO2/ntot; yH2O = n_H2O/ntot; yO2 = n_O2/ntot; yN2 = n_N2/ntot;
Mavg = yCO2*S.MW.CO2 + yH2O*S.MW.H2O + yO2*S.MW.O2 + yN2*S.MW.N2;
w = struct('CO2', yCO2*S.MW.CO2/Mavg, 'H2O', yH2O*S.MW.H2O/Mavg, ...
            'O2', yO2*S.MW.O2/Mavg, 'N2', yN2*S.MW.N2/Mavg);
end
