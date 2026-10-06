classdef RegressionDefaultConfigTest < matlab.unittest.TestCase
    %REGRESSIONDEFAULTCONFIGTEST Port of Python
    %   test_default_config_regression_unchanged() (test_reference_cases.py:
    %   200-210): the gas_model='ideal' default must stay bit-identical, so
    %   adding new fields cannot silently change the existing behaviour.

    methods (Test)
        function testDefaultUnchanged(testCase)
            cfg1 = default_engine_config();
            cfg2 = default_engine_config();
            cfg2.gas_model = 'ideal';
            cfg2.pi_n = 1.0;
            cfg2.power_offtake_kW = 0.0;

            r1 = run_design_point(cfg1);
            r2 = run_design_point(cfg2);

            testCase.verifyTrue(r1.success, r1.error_msg);
            testCase.verifyTrue(r2.success, r2.error_msg);
            testCase.verifyEqual(r1.performance.F_spec, r2.performance.F_spec);
            testCase.verifyEqual(r1.performance.TSFC,   r2.performance.TSFC);
            testCase.verifyEqual(r1.performance.f_core, r2.performance.f_core);
        end
    end
end
