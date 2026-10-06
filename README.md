# GCAM MATLAB - Turbojet Design Point Tool

MATLAB port of the turbojet design-point part of GCAM, our Python gas turbine
cycle analysis code. Calculates the cycle station by station, the performance
(specific thrust, TSFC, efficiencies) and the station flow areas.

## Start

Run `launch.m` in MATLAB (no toolboxes needed). The app has two tabs:

1. **Design point** - inputs, station table, performance table, warnings, station diameters
2. **Parametric sweep** - sweep any two inputs; surface plot, carpet plot (thrust vs TSFC) and data table

## Use from scripts

```matlab
cfg = default_engine_config();      % all inputs, see config/default_engine_config.m
cfg.pi_c = 8; cfg.Tt4 = 1200;
r = run_design_point(cfg);          % r.performance, r.stations, r.geometries, r.warnings

grid = param_sweep(cfg, 'pi_c', 4:1:12, 'Tt4', [1100 1200 1300]);
```

Gas model: `'ideal'` (constant cp) or `'real'` (temperature dependent cp, NASA polynomials).

## Folders

- `cycle/` cycle solver (`run_design_point.m`)
- `components/` inlet, compressor, combustor, turbine, nozzle
- `atmos/`, `real_gas/`, `efficiency/` atmosphere, gas properties, loss models
- `config/` default inputs
- `sweep/` parametric sweep
- `gui/` user interface
- `examples/` comparison with Cohen-Rogers Example 3.1
- `tests/` regression and reference tests: `run('tests/run_all_tests.m')`

## Validation

The tests compare against textbook cases (Cohen-Rogers, *Gas Turbine Theory*;
Mattingly, *Aircraft Engine Design* and *Elements of Gas Turbine Propulsion*),
golden values from the Python code, and physical checks (second law, power balance).

## License

Developed by Fatihhan Toprak for the Wolfram Jet team.

Licensed under [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/): free to use, share and modify for non-commercial purposes, with credit to the author; modified versions must be shared under the same license. Commercial use is not permitted. See `LICENSE`.
