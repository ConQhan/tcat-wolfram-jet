function w = mixture_weights(species, phi_eq)
%MIXTURE_WEIGHTS Mixture weights with phi_eq memoisation (real_gas.py:121-132).
persistent air_w cache_keys cache_vals
if isempty(air_w)
    air_w = air_mass_fractions();
    cache_keys = [];
    cache_vals = {};
end
if strcmp(species, 'air')
    w = air_w;
    return
end
key = round(phi_eq, 5);
idx = find(cache_keys == key, 1);
if ~isempty(idx)
    w = cache_vals{idx};
    return
end
w = products_mass_fractions(key);
cache_keys(end+1) = key;      %#ok<AGROW>
cache_vals{end+1} = w;        %#ok<AGROW>
end
