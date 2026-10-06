classdef ReferenceCasesTest < matlab.unittest.TestCase
    %REFERENCECASESTEST Port of Python tests/test_reference_cases.py.
    %   Reads the same raw data, collected from independent sources
    %   (Cohen-Rogers "Gas Turbine Theory", Mattingly "Aircraft Engine
    %   Design" / "Elements of Gas Turbine Propulsion"), from
    %   tests/fixtures/reference_cases.json; both test suites share it.

    properties
        Cases
    end

    methods (TestClassSetup)
        function loadFixture(testCase)
            here = fileparts(mfilename('fullpath'));
            raw = jsondecode(fileread(fullfile(here, 'fixtures', 'reference_cases.json')));
            c = struct();
            for i = 1:numel(raw.cases)
                cs = raw.cases{i};
                c.(cs.id) = cs;
            end
            testCase.Cases = c;
        end
    end

    methods (Test)

        function testInletMilRecovery(testCase)
            ids = {'inlet_supersonic_aaf_1', 'inlet_supersonic_aaf_2'};
            for i = 1:numel(ids)
                id = ids{i};
                cs = testCase.Cases.(id);
                pi_d = mil_inlet_recovery(cs.inputs.M0, cs.inputs.pi_d_max);
                testCase.verifyEqual(pi_d, cs.reference_outputs.pi_d, ...
                    'RelTol', get_tol(cs, 'pi_d')/100, [id ' pi_d']);
            end
        end

        function testCompressorComponent(testCase)
            ids = {'compressor_gttpt2_ex21', 'compressor_gttpt2_ex22', 'compressor_gttpt2_ex23'};
            for i = 1:numel(ids)
                id = ids{i};
                cs = testCase.Cases.(id);
                inp = cs.inputs;
                st_in = struct('T_total', inp.Tt2_K, 'P_total', inp.Pt2_bar*1e5);
                if isfield(inp, 'eta_c'), eta_c = inp.eta_c; else, eta_c = 0.90; end
                if isfield(inp, 'use_polytropic'), use_poly = logical(inp.use_polytropic); else, use_poly = false; end
                if isfield(inp, 'e_c'), e_c = inp.e_c; else, e_c = 0.90; end

                [st_out, ~, ~] = compressor_run(st_in, inp.gamma_c, inp.pi_c, eta_c, use_poly, e_c, 'ideal');

                ref = cs.reference_outputs;
                testCase.verifyEqual(st_out.T_total, ref.Tt3_K, ...
                    'RelTol', get_tol(cs, 'Tt3_K')/100, [id ' Tt3_K']);
                if isfield(ref, 'Pt3_bar')
                    testCase.verifyEqual(st_out.P_total/1e5, ref.Pt3_bar, ...
                        'RelTol', get_tol(cs, 'Pt3_bar')/100, [id ' Pt3_bar']);
                end
                if isfield(ref, 'Pt3_after_burner_loss_bar')
                    pt3_after = (st_out.P_total/1e5) * inp.pi_b;
                    testCase.verifyEqual(pt3_after, ref.Pt3_after_burner_loss_bar, ...
                        'RelTol', get_tol(cs, 'Pt3_after_burner_loss_bar')/100, [id ' Pt3_after_burner_loss_bar']);
                end
            end
        end

        function testCombustorComponent(testCase)
            id = 'combustor_eogtp_real_ex71';
            cs = testCase.Cases.(id);
            inp = cs.inputs;
            st_in = struct('T_total', inp.Tt3_K, 'P_total', inp.Pt3_bar*1e5);
            [~, f] = combustor_run(st_in, inp.Tt4_K, inp.gamma_c, inp.gamma_h, ...
                inp.pi_b, inp.eta_b, inp.FHV_Jkg, 'ideal');
            ref = cs.reference_outputs;
            testCase.verifyEqual(f, ref.f, 'RelTol', get_tol(cs, 'f')/100, [id ' f']);
        end

        function testTurbineComponent(testCase)
            id = 'turbine_gttpt2_ex22';
            cs = testCase.Cases.(id);
            inp = cs.inputs;
            st_in = struct('T_total', inp.Tt4_K, 'P_total', inp.Pt4_bar*1e5);
            if isfield(inp, 'eta_t'), eta_t = inp.eta_t; else, eta_t = 0.90; end
            if isfield(inp, 'use_polytropic'), use_poly = logical(inp.use_polytropic); else, use_poly = false; end
            if isfield(inp, 'e_t'), e_t = inp.e_t; else, e_t = 0.90; end

            [st_out, ~, ~] = turbine_run(st_in, inp.Wc_Jkg, inp.f, inp.gamma_h, ...
                eta_t, inp.eta_m, use_poly, e_t, 'ideal', 0.0);

            ref = cs.reference_outputs;
            testCase.verifyEqual(st_out.T_total, ref.Tt5_K, ...
                'RelTol', get_tol(cs, 'Tt5_K')/100, [id ' Tt5_K']);
            pr = st_in.P_total / st_out.P_total;
            testCase.verifyEqual(pr, ref.pressure_ratio_Pt4_over_Pt5, ...
                'RelTol', get_tol(cs, 'pressure_ratio_Pt4_over_Pt5')/100, [id ' PR']);
        end

        function testNozzleComponent(testCase)
            ids = {'nozzle_choked_gttpt3_ex31', 'nozzle_unchoked_cold_gttpt3_ex32', ...
                   'nozzle_unchoked_hot_gttpt3_ex32'};
            for i = 1:numel(ids)
                id = ids{i};
                cs = testCase.Cases.(id);
                inp = cs.inputs;
                st_in = struct('T_total', inp.Tt_in_K, 'P_total', inp.Pt_in_bar*1e5);

                [st_9, V9, ~, ~, noz_exp] = nozzle_run(st_in, inp.Pa_bar*1e5, 1.0, 1.0, 0.0, ...
                    inp.gamma_h, 0.0, inp.eta_n, 1.0, 'ideal', inp.nozzle_type);

                ref = cs.reference_outputs;
                testCase.verifyEqual(st_9.T_static, ref.T9_K, ...
                    'RelTol', get_tol(cs, 'T9_K')/100, [id ' T9_K']);
                if isfield(ref, 'P9_bar')
                    testCase.verifyEqual(st_9.P_static/1e5, ref.P9_bar, ...
                        'RelTol', get_tol(cs, 'P9_bar')/100, [id ' P9_bar']);
                end
                testCase.verifyEqual(V9, ref.V9_ms, ...
                    'RelTol', get_tol(cs, 'V9_ms')/100, [id ' V9_ms']);
                if ~isfield(cs, 'assert_choked') || cs.assert_choked
                    testCase.verifyEqual(noz_exp.is_choked, logical(ref.choked), [id ' choked']);
                end
            end
        end

        function testFullCycle(testCase)
            id = 'full_cycle_turbojet_gttpt3_ex31';
            cs = testCase.Cases.(id);
            gc = cs.model_config;

            cfg = default_engine_config();
            cfg.M0 = gc.M0; cfg.altitude_m = gc.altitude_m;
            cfg.m_dot = gc.m_dot_fixed;   % use_dynamic_mdot=false is the default (not ported)
            cfg.pi_d_max = gc.pi_d_max;
            cfg.pi_c = gc.pi_c; cfg.eta_c = gc.eta_c; cfg.use_polytropic = logical(gc.use_polytropic);
            cfg.Tt4 = gc.Tt4; cfg.pi_b = gc.pi_b; cfg.eta_b = gc.eta_b;
            cfg.eta_t = gc.eta_t; cfg.eta_m = gc.eta_m;
            cfg.eta_n = gc.eta_n; cfg.nozzle_type = gc.nozzle_type;
            cfg.FHV = gc.FHV;
            cfg.gamma_c = gc.gamma_c; cfg.gamma_h = gc.gamma_h;
            cfg.gas_model = gc.gas_model;

            r = run_design_point(cfg);
            testCase.verifyTrue(r.success, sprintf('[%s] engine did not run: %s', id, r.error_msg));
            if ~r.success
                return
            end

            ref = cs.reference_outputs;
            s = r.stations;
            p = r.performance;

            testCase.verifyEqual(s.t2.T_total, ref.Tt2_K, 'RelTol', get_tol(cs,'Tt2_K')/100, [id ' Tt2_K']);
            testCase.verifyEqual(s.t2.P_total/1e5, ref.Pt2_bar, 'RelTol', get_tol(cs,'Pt2_bar')/100, [id ' Pt2_bar']);
            testCase.verifyEqual(s.t3.T_total, ref.Tt3_K, 'RelTol', get_tol(cs,'Tt3_K')/100, [id ' Tt3_K']);
            testCase.verifyEqual(s.t3.P_total/1e5, ref.Pt3_bar, 'RelTol', get_tol(cs,'Pt3_bar')/100, [id ' Pt3_bar']);
            testCase.verifyEqual(s.t4.T_total, ref.Tt4_K, 'RelTol', get_tol(cs,'Tt4_K')/100, [id ' Tt4_K']);
            testCase.verifyEqual(s.t4.P_total/1e5, ref.Pt4_bar, 'RelTol', get_tol(cs,'Pt4_bar')/100, [id ' Pt4_bar']);
            testCase.verifyEqual(s.t5.T_total, ref.Tt5_K, 'RelTol', get_tol(cs,'Tt5_K')/100, [id ' Tt5_K']);
            testCase.verifyEqual(s.t5.P_total/1e5, ref.Pt5_bar, 'RelTol', get_tol(cs,'Pt5_bar')/100, [id ' Pt5_bar']);
            testCase.verifyEqual(s.s9.T_static, ref.T9_K, 'RelTol', get_tol(cs,'T9_K')/100, [id ' T9_K']);
            testCase.verifyEqual(s.s9.P_static/1e5, ref.P9_bar, 'RelTol', get_tol(cs,'P9_bar')/100, [id ' P9_bar']);
            testCase.verifyEqual(p.F_spec, ref.F_spec_Nskg, 'RelTol', get_tol(cs,'F_spec_Nskg')/100, [id ' F_spec_Nskg']);
        end

    end
end
