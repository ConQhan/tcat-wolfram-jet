function w = air_mass_fractions()
%AIR_MASS_FRACTIONS Dry air mass fractions (real_gas.py:89-97).
S = species_coeffs();
yN2 = 0.7809; yO2 = 0.2095; yAr = 0.0093;
s = yN2 + yO2 + yAr;
yN2 = yN2/s; yO2 = yO2/s; yAr = yAr/s;
Mavg = yN2*S.MW.N2 + yO2*S.MW.O2 + yAr*S.MW.Ar;
w = struct('N2', yN2*S.MW.N2/Mavg, 'O2', yO2*S.MW.O2/Mavg, 'Ar', yAr*S.MW.Ar/Mavg);
end
