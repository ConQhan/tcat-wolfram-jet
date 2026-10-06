function S = species_coeffs()
%SPECIES_COEFFS NASA-Glenn species Cp(T) polynomial coefficients (real_gas.py:45-86).
%   Molar Cp data (200-2400 K, 100 K steps) is converted to specific Cp for
%   each species and fitted with a degree-6 polynomial. NumPy's polyfit()
%   scales the Vandermonde matrix by its column 2-norms before solving and
%   scales back (otherwise the >20 orders of magnitude of T^6 cause
%   round-off errors). MATLAB's plain polyfit() does not do this, so the
%   same algorithm is applied here by hand.
%
%   Returned fields (S.N2, S.O2, S.Ar, S.CO2, S.H2O) are 7x1 coefficient
%   vectors from LOW to HIGH order (index n+1 -> T^n coefficient), the same
%   order Python stores with coeffs[::-1].
persistent cached
if ~isempty(cached)
    S = cached;
    return
end

T_grid = (200:100:2400)';   % 23 points, real_gas.py:46

AR_molar  = repmat(20.786, 23, 1);
N2_molar  = [29.107;29.125;29.249;29.582;30.109;30.754;31.434;32.090; ...
             32.696;33.242;33.724;34.147;34.518;34.842;35.127; ...
             35.377;35.599;35.795;35.970;36.127;36.267;36.395;36.510];
O2_molar  = [29.126;29.388;30.115;31.092;32.090;32.990;33.745;34.361; ...
             34.883;35.333;35.695;36.006;36.288;36.553;36.808; ...
             37.057;37.302;37.545;37.784;38.020;38.254;38.484;38.710];
CO2_molar = [32.361;37.220;41.325;44.624;47.323;49.561;51.432;52.999; ...
             54.309;55.420;56.347;57.130;57.798;58.374;58.873; ...
             59.310;59.693;60.033;60.335;60.604;60.846;61.065;61.263];
H2O_molar = [33.349;33.596;34.265;35.225;36.324;37.499;38.728;39.998; ...
             41.291;42.574;43.843;45.065;46.226;47.318;48.340; ...
             49.292;50.176;50.996;51.756;52.458;53.108;53.709;54.264];

MW = struct('N2', 0.0280134, 'O2', 0.0319988, 'Ar', 0.039948, ...
             'CO2', 0.0440095, 'H2O', 0.0180153);   % kg/mol

S = struct();
S.N2  = fit_one(T_grid, N2_molar,  MW.N2);
S.O2  = fit_one(T_grid, O2_molar,  MW.O2);
S.Ar  = fit_one(T_grid, AR_molar,  MW.Ar);
S.CO2 = fit_one(T_grid, CO2_molar, MW.CO2);
S.H2O = fit_one(T_grid, H2O_molar, MW.H2O);
S.MW  = MW;

cached = S;
end


function coeffs_low_to_high = fit_one(T, molar_cp, mw)
deg = 6;
cp_specific = molar_cp / mw;                  % [J/(kg*K)]
V = T .^ (deg:-1:0);                          % Vandermonde, T^6..T^0 (same order as numpy.vander)
scale = sqrt(sum(V.^2, 1));                   % NumPy polyfit column 2-norm scaling
Vs = V ./ scale;
c = Vs \ cp_specific;                         % least squares solution (scaled basis)
c = c ./ scale(:);                            % undo the scaling (still high to low, T^6..T^0)
coeffs_low_to_high = flipud(c);               % equivalent of Python coeffs[::-1]
end
