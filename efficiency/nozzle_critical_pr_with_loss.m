function crit = nozzle_critical_pr_with_loss(gamma, eta_n)
%NOZZLE_CRITICAL_PR_WITH_LOSS Critical pressure ratio Pt/Pc including losses
%   (Cohen-Rogers Eq 3.14), efficiency_models.py:37.
if nargin < 2 || isempty(eta_n), eta_n = 1.0; end
if eta_n >= 1.0
    crit = ((gamma + 1.0) / 2.0) ^ (gamma / (gamma - 1.0));
    return
end
bracket = 1.0 - (1.0 / eta_n) * (gamma - 1.0) / (gamma + 1.0);
if bracket <= 0
    crit = Inf;
    return
end
crit = bracket ^ (-gamma / (gamma - 1.0));
end
