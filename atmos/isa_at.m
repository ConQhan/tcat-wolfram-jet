function pt = isa_at(altitude_m)
%ISA_AT ICAO Standard Atmosphere (ISA), 0-86km (Python: atmos_utils.py:75).
%   pt = isa_at(altitude_m) -> struct(altitude_m,T,P,rho,a)
%
%   NOTE (faithful port): the Python loop only checks the base of the
%   first 6 layers (0..51000 m, range(len(LAYERS)-1)) and never the base
%   of the 7th layer (71000 m). For h >= 71000 m Python, and therefore
%   this port, uses the 51000 m layer parameters. This is the behaviour of
%   the original code; it lies far outside the micro-jet flight envelope
%   (<< 71 km) and was ported unchanged on purpose.

layers = [ ...
      0.0, 288.15, 101325.0,  -0.0065; ...
  11000.0, 216.65,  22632.1,   0.0;    ...
  20000.0, 216.65,   5474.89,  0.001;  ...
  32000.0, 228.65,    868.019, 0.0028; ...
  47000.0, 270.65,    110.906, 0.0;    ...
  51000.0, 270.65,     66.939,-0.0028; ...
  71000.0, 214.65,      3.956,-0.002 ];

c  = gcam_constants();
R  = c.R;
G0 = c.G0;

h = max(0.0, altitude_m);

layer_idx = 1;                 % Python layer_idx=0 (1-based equivalent)
for i = 1:6                    % Python: range(len(_ISA_LAYERS)-1) = range(6)
    if h >= layers(i,1)
        layer_idx = i;
    else
        break
    end
end

h_b = layers(layer_idx,1);
T_b = layers(layer_idx,2);
P_b = layers(layer_idx,3);
L   = layers(layer_idx,4);
dh  = h - h_b;

if abs(L) < 1e-12
    T = T_b;
    P = P_b * exp(-G0*dh/(R*T_b));
else
    T = T_b + L*dh;
    P = P_b * (T/T_b)^(-G0/(L*R));
end

rho = P/(R*T);
a   = sqrt(1.4*R*T);

pt = struct('altitude_m', h, 'T', T, 'P', P, 'rho', rho, 'a', a);
end
