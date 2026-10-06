function geo = size_station(station_id, m_dot, Tt, Pt, M_design, gamma)
%SIZE_STATION Station flow area and diameter by the MFP method.
%   (atmos_utils.py:313)  A = (m_dot*sqrt(R*Tt)) / (Pt*MFP(M,gamma))
%
%   Returns: struct(station_id,M_design,area_m2,diameter_mm,Tt,Pt,m_dot)

if Pt <= 0 || Tt <= 0
    error('tcat:size_station:invalidState', ...
        'Station %s: Pt=%.2f Pa, Tt=%.2f K - positive values required.', ...
        station_id, Pt, Tt);
end
if M_design <= 0
    error('tcat:size_station:invalidMach', ...
        'Station %s: design Mach number must be > 0.', station_id);
end

MFP_val = mfp(M_design, gamma);
if MFP_val <= 0
    error('tcat:size_station:invalidMFP', ...
        'Station %s: MFP evaluated to zero (M=%g, gamma=%g).', ...
        station_id, M_design, gamma);
end

R = tcat_constants().R;
area    = (m_dot * sqrt(R * Tt)) / (Pt * MFP_val);
diam_mm = sqrt(area / pi) * 2.0 * 1000.0;

geo = struct('station_id', station_id, 'M_design', M_design, ...
             'area_m2', area, 'diameter_mm', diam_mm, ...
             'Tt', Tt, 'Pt', Pt, 'm_dot', m_dot);
end
