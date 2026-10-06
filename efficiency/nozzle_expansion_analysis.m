function noz = nozzle_expansion_analysis(Pt9, P0, gamma_h, m_dot_exit, V9, ...
                                          m_dot_inlet, V0, A_exit, P9, eta_n)
%NOZZLE_EXPANSION_ANALYSIS (efficiency_models.py:101-126)
%   P9: actual static exit pressure. [] (Python None) means full
%   expansion (P9 = P0).
%   Returns: struct(state,is_choked,PR_actual,PR_critical,F_momentum,F_pressure)
if nargin < 6 || isempty(m_dot_inlet), m_dot_inlet = 0.0; end
if nargin < 7 || isempty(V0),          V0 = 0.0;          end
if nargin < 8 || isempty(A_exit),      A_exit = 0.0;       end
if nargin < 9,                          P9 = [];            end
if nargin < 10 || isempty(eta_n),      eta_n = 1.0;         end

crit = nozzle_critical_pr_with_loss(gamma_h, eta_n);
if P0 > 0
    PR = Pt9 / P0;
else
    PR = 1.0;
end
choked = PR >= crit;
if choked
    state = 'perfect';
else
    state = 'unchoked';
end
if choked && PR > crit * 1.05
    state = 'under';
end
F_mom = m_dot_exit * V9 - m_dot_inlet * V0;
if isempty(P9)
    P9_eff = P0;
else
    P9_eff = P9;
end
F_pres = (P9_eff - P0) * A_exit;

noz = struct('state', state, 'is_choked', choked, 'PR_actual', PR, ...
              'PR_critical', crit, 'F_momentum', F_mom, 'F_pressure', F_pres);
end
