function tl = tau_lambda(cph, Tt4, cpc, T0)
%TAU_LAMBDA (efficiency_models.py:143)
if (cpc * T0) > 0
    tl = cph * Tt4 / (cpc * T0);
else
    tl = 0.0;
end
end
