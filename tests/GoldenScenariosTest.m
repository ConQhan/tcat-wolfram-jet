classdef GoldenScenariosTest < matlab.unittest.TestCase
    %GOLDENSCENARIOSTEST The two scenarios of Python
    %   tests/test_design_point_golden.py covered by this port ("default",
    %   "poly_real"); "afterburner"/"turbofan"/"bleed" are not ported. The
    %   values are hard-coded in the Python test, so they were copied by hand
    %   and checked side by side (test_design_point_golden.py: 27-40
    %   "default", 93-107 "poly_real").

    properties (Constant)
        TOL = 1e-6
    end

    methods (Test)

        function testDefaultScenario(testCase)
            cfg = default_engine_config();
            r = run_design_point(cfg);
            testCase.verifyTrue(r.success, r.error_msg);
            tol = GoldenScenariosTest.TOL;

            p = r.performance;
            testCase.verifyEqual(p.F_spec, 858.2575123287082, 'RelTol', tol);
            testCase.verifyEqual(p.TSFC,   2.6941635289110186e-05, 'RelTol', tol);
            testCase.verifyEqual(p.eta_th, 0.36374087510358594, 'RelTol', tol);
            testCase.verifyEqual(p.eta_p,  0.0, 'AbsTol', tol);
            testCase.verifyEqual(p.m_bleed, 0.0, 'AbsTol', tol);
            testCase.verifyEqual(p.Tt4_mix, 1400.0, 'RelTol', tol);

            s = r.stations;
            testCase.verifyEqual(s.t2.T_total, 288.15, 'RelTol', tol);
            testCase.verifyEqual(s.t2.P_total, 100311.75, 'RelTol', tol);
            testCase.verifyEqual(s.t3.T_total, 684.0458116198604, 'RelTol', tol);
            testCase.verifyEqual(s.t3.P_total, 1504676.25, 'RelTol', tol);
            testCase.verifyEqual(s.t4.T_total, 1400.0, 'RelTol', tol);
            testCase.verifyEqual(s.t4.P_total, 1444489.2, 'RelTol', tol);
            testCase.verifyEqual(s.t5.T_total, 1063.9658142686735, 'RelTol', tol);
            testCase.verifyEqual(s.t5.P_total, 413783.78616464254, 'RelTol', tol);
            testCase.verifyEqual(s.s9.T_total, 1063.9658142686735, 'RelTol', tol);
            testCase.verifyEqual(s.s9.P_total, 413783.78616464254, 'RelTol', tol);

            expected_diam = [621.4169038049965, 220.63841361835048, 291.6627840208954, ...
                              454.6960818742558, 417.13619518315215];
            actual_diam = [r.geometries.diameter_mm];
            testCase.verifyEqual(numel(actual_diam), numel(expected_diam), 'number of geometries changed');
            testCase.verifyEqual(actual_diam, expected_diam, 'RelTol', tol);
        end

        function testPolyRealScenario(testCase)
            cfg = default_engine_config();
            cfg.use_polytropic = true;
            cfg.gas_model = 'real';
            r = run_design_point(cfg);
            testCase.verifyTrue(r.success, r.error_msg);
            tol = GoldenScenariosTest.TOL;

            p = r.performance;
            testCase.verifyEqual(p.F_spec, 881.4564367754219, 'RelTol', tol);
            testCase.verifyEqual(p.TSFC,   2.4653871812506233e-05, 'RelTol', tol);
            testCase.verifyEqual(p.eta_th, 0.4087946952064416, 'RelTol', tol);
            testCase.verifyEqual(p.eta_p,  0.0, 'AbsTol', tol);
            testCase.verifyEqual(p.m_bleed, 0.0, 'AbsTol', tol);
            testCase.verifyEqual(p.Tt4_mix, 1400.0, 'RelTol', tol);

            s = r.stations;
            testCase.verifyEqual(s.t2.T_total, 288.15, 'RelTol', tol);
            testCase.verifyEqual(s.t2.P_total, 100311.75, 'RelTol', tol);
            testCase.verifyEqual(s.t3.T_total, 669.3414628086823, 'RelTol', tol);
            testCase.verifyEqual(s.t3.P_total, 1504676.25, 'RelTol', tol);
            testCase.verifyEqual(s.t4.T_total, 1400.0, 'RelTol', tol);
            testCase.verifyEqual(s.t4.P_total, 1444489.2, 'RelTol', tol);
            testCase.verifyEqual(s.t5.T_total, 1088.862553786618, 'RelTol', tol);
            testCase.verifyEqual(s.t5.P_total, 435141.406069771, 'RelTol', tol);
            testCase.verifyEqual(s.s9.T_total, 1088.862553786618, 'RelTol', tol);
            testCase.verifyEqual(s.s9.P_total, 435141.406069771, 'RelTol', tol);

            expected_diam = [621.4169038049965, 219.44301491723627, 291.6627840208954, ...
                              445.66501781185406, 408.8511365437259];
            actual_diam = [r.geometries.diameter_mm];
            testCase.verifyEqual(numel(actual_diam), numel(expected_diam), 'number of geometries changed');
            testCase.verifyEqual(actual_diam, expected_diam, 'RelTol', tol);
        end

    end
end
