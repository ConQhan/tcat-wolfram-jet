function tau_c = compressor_tau_from_polytropic(pi_c, gamma_c, e_c)
%COMPRESSOR_TAU_FROM_POLYTROPIC (efficiency_models.py:71)
tau_c = pi_c ^ ((gamma_c - 1.0) / (gamma_c * e_c));
end
