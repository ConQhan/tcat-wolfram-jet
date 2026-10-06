classdef PhysicalSanityTest < matlab.unittest.TestCase
    %PHYSICALSANITYTEST Independent checks of physical and thermodynamic
    %   relations that must ALWAYS hold, instead of specific numbers. They
    %   catch "right number, physically wrong" errors that single reference
    %   cases miss. No new calculation code: every check is re-derived from
    %   the public API (run_design_point, h_T/cp_T).

    properties (Constant)
        TOL = 1e-6
    end

    methods (Static, Access = private)
        function cfgs = sampleConfigs()
            %SAMPLECONFIGS Base configs for the 2x2x3 = 12 combinations of
            %   gas_model x use_polytropic x pi_c, shared by the compressor,
            %   turbine, nozzle and entropy tests.
            base = default_engine_config();
            cfgs = {};
            gasModels = {'ideal','real'};
            polyOpts  = [false, true];
            piCs      = [6.0, 15.0, 28.0];
            for gi = 1:numel(gasModels)
                for pj = 1:numel(polyOpts)
                    for ci = 1:numel(piCs)
                        c = base;
                        c.gas_model = gasModels{gi};
                        c.use_polytropic = polyOpts(pj);
                        c.pi_c = piCs(ci);
                        cfgs{end+1} = c; %#ok<AGROW>
                    end
                end
            end
        end

        function ds = realGasEntropyChange(T1, P1, T2, P2, species, phi_eq)
            %REALGASENTROPYCHANGE Rigorous entropy change for the real gas
            %   (temperature dependent cp): ds = [phi(T2)-phi(T1)] - R*ln(P2/P1),
            %   phi(T) = integral(cp(T')/T' dT') (real_gas/phi_T.m, FAIR
            %   nomenclature). Unlike the single local cp approximation of the
            %   `entropy` field (cpg_entropy.m), this integrates cp(T)/T.
            if nargin < 6, phi_eq = 0.35; end
            R = gcam_constants().R;
            ds = (phi_T(T2, species, phi_eq) - phi_T(T1, species, phi_eq)) - R*log(P2/P1);
        end
    end

    methods (Test)

        function testCompressorHeatsGas(testCase)
            cfgs = PhysicalSanityTest.sampleConfigs();
            for i = 1:numel(cfgs)
                r = run_design_point(cfgs{i});
                testCase.assumeTrue(r.success);
                testCase.verifyGreaterThan(r.stations.t3.T_total, r.stations.t2.T_total, ...
                    sprintf('case %d: compressor exit must be hotter than the inlet', i));
            end
        end

        function testTurbineExtractsEnergy(testCase)
            cfgs = PhysicalSanityTest.sampleConfigs();
            for i = 1:numel(cfgs)
                r = run_design_point(cfgs{i});
                testCase.assumeTrue(r.success);
                testCase.verifyLessThan(r.stations.t5.T_total, r.stations.t4.T_total, ...
                    sprintf('case %d: turbine exit must be colder than the inlet', i));
            end
        end

        function testNozzleStaticNotAboveInletTotal(testCase)
            cfgs = PhysicalSanityTest.sampleConfigs();
            for i = 1:numel(cfgs)
                r = run_design_point(cfgs{i});
                testCase.assumeTrue(r.success);
                testCase.verifyLessThanOrEqual(r.stations.s9.T_static, ...
                    r.stations.t5.T_total + PhysicalSanityTest.TOL, ...
                    sprintf('case %d: nozzle exit static T must not exceed the turbine exit total T', i));
            end
        end

        function testSecondLawCompressor(testCase)
            % Entropy can never decrease in the compressor (second law).
            % In 'ideal' mode the cpg_entropy field is exact (one constant cp).
            % In 'real' mode cp(T) varies and the `entropy` field (single local
            % cp in make_station, meant for the T-s diagram only) is not exact,
            % so the phi_T based change (realGasEntropyChange) is used (see the
            % FINDING note below).
            cfgs = PhysicalSanityTest.sampleConfigs();
            for i = 1:numel(cfgs)
                cfg = cfgs{i};
                r = run_design_point(cfg);
                testCase.assumeTrue(r.success);
                s = r.stations;
                if strcmp(cfg.gas_model, 'real')
                    ds = PhysicalSanityTest.realGasEntropyChange( ...
                        s.t2.T_total, s.t2.P_total, s.t3.T_total, s.t3.P_total, 'air');
                else
                    ds = s.t3.entropy - s.t2.entropy;
                end
                testCase.verifyGreaterThanOrEqual(ds, -1e-3, ...
                    sprintf('case %d: compressor cannot reduce entropy (second law)', i));
            end
        end

        function testSecondLawTurbine(testCase)
            % FINDING: the first version of this test used the `entropy`
            % field directly and reported a "violation" in every
            % gas_model='real' case (e.g. ds = -20.5 J/(kg*K)). Root cause: the
            % `entropy` field (cpg_entropy.m) uses one cp at each station's own
            % temperature (e.g. cp(Tt4=1400K)=1267.2 vs cp(Tt5=1223K)=1240.3).
            % It is a quick T-s diagram approximation, not an exact entropy
            % calculation (same in Python engine_core.py, not a port error).
            % Computed exactly with phi_T, the same case gives +20.3 J/(kg*K):
            % the cycle itself obeys the second law. The test now uses phi_T.
            cfgs = PhysicalSanityTest.sampleConfigs();
            for i = 1:numel(cfgs)
                cfg = cfgs{i};
                r = run_design_point(cfg);
                testCase.assumeTrue(r.success);
                s = r.stations; p = r.performance;
                if strcmp(cfg.gas_model, 'real')
                    phi_eq = p.f_core / gcam_constants().FST_C12H23;
                    ds = PhysicalSanityTest.realGasEntropyChange( ...
                        s.t4.T_total, s.t4.P_total, s.t5.T_total, s.t5.P_total, 'products', phi_eq);
                else
                    ds = s.t5.entropy - s.t4.entropy;
                end
                testCase.verifyGreaterThanOrEqual(ds, -1e-3, ...
                    sprintf('case %d: turbine cannot reduce entropy (second law)', i));
            end
        end

        function testSecondLawNozzle(testCase)
            % The same FINDING as in testSecondLawTurbine applies to the
            % nozzle (same root cause, same fix).
            cfgs = PhysicalSanityTest.sampleConfigs();
            for i = 1:numel(cfgs)
                cfg = cfgs{i};
                r = run_design_point(cfg);
                testCase.assumeTrue(r.success);
                s = r.stations; p = r.performance;
                if strcmp(cfg.gas_model, 'real')
                    phi_eq = p.f_core / gcam_constants().FST_C12H23;
                    ds = PhysicalSanityTest.realGasEntropyChange( ...
                        s.t5.T_total, s.t5.P_total, s.s9.T_static, s.s9.P_static, 'products', phi_eq);
                else
                    ds = s.s9.entropy - s.t5.entropy;
                end
                testCase.verifyGreaterThanOrEqual(ds, -1e-3, ...
                    sprintf('case %d: nozzle cannot reduce entropy (second law)', i));
            end
        end

        function testCompressorTurbinePowerBalance(testCase)
            % Recomputes Wc/Wt from public results only (station
            % temperatures and the same public h_T/cp_T formulas) and checks
            % the power balance Wt*eta_m*(1+f) = Wc + W_offtake. Not a deep
            % thermodynamic proof: a wiring check that catches regressions
            % such as W_offtake being dropped.
            cfgs = PhysicalSanityTest.sampleConfigs();
            R = gcam_constants().R;
            for i = 1:numel(cfgs)
                cfg = cfgs{i};
                cfg.power_offtake_kW = 50.0;  % non-zero so the offtake term is covered
                r = run_design_point(cfg);
                testCase.assumeTrue(r.success);
                s = r.stations; p = r.performance;
                if strcmp(cfg.gas_model, 'real')
                    Wc_chk = h_T(s.t3.T_total, 'air') - h_T(s.t2.T_total, 'air');
                    phi_eq = p.f_core / gcam_constants().FST_C12H23;
                    Wt_chk = h_T(s.t4.T_total, 'products', phi_eq) - h_T(s.t5.T_total, 'products', phi_eq);
                else
                    cpc = cfg.gamma_c*R/(cfg.gamma_c-1.0);
                    cph = cfg.gamma_h*R/(cfg.gamma_h-1.0);
                    Wc_chk = cpc*(s.t3.T_total - s.t2.T_total);
                    Wt_chk = cph*(s.t4.T_total - s.t5.T_total);
                end
                W_offtake = (cfg.power_offtake_kW*1000.0) / cfg.m_dot;
                lhs = Wt_chk * cfg.eta_m * (1.0 + p.f_core);
                rhs = Wc_chk + W_offtake;
                testCase.verifyEqual(lhs, rhs, 'RelTol', 1e-6, ...
                    sprintf('case %d: turbine-compressor power balance does not hold', i));
            end
        end

        function testThrustIncreasesWithTt4(testCase)
            % Known behaviour (Cohen-Rogers / Mattingly parametric plots):
            % at constant pi_c, specific thrust increases with Tt4.
            baseCfgs = {default_engine_config()};
            c2 = default_engine_config(); c2.gas_model = 'real'; c2.use_polytropic = true;
            baseCfgs{end+1} = c2;
            Tt4Range = 1000:100:1900;
            for bi = 1:numel(baseCfgs)
                Fspecs = zeros(size(Tt4Range));
                for k = 1:numel(Tt4Range)
                    c = baseCfgs{bi};
                    c.Tt4 = Tt4Range(k);
                    r = run_design_point(c);
                    testCase.assumeTrue(r.success);
                    Fspecs(k) = r.performance.F_spec;
                end
                testCase.verifyTrue(all(diff(Fspecs) > 0), ...
                    sprintf('base config %d: F_spec does not increase monotonically with Tt4', bi));
            end
        end

        function testChokedConvergentNozzleReachesMach1(testCase)
            cfg = default_engine_config();
            cfg.nozzle_type = 'conv';
            cfg.pi_c = 20.0;   % large PR margin keeps the nozzle choked
            r = run_design_point(cfg);
            testCase.verifyTrue(r.success, r.error_msg);
            testCase.verifyTrue(r.performance.is_choked, 'convergent nozzle must be choked (high PR)');
            testCase.verifyEqual(r.performance.M_exit, 1.0, 'AbsTol', 1e-6);
        end

        function testFullyExpandedCdNozzleMatchesAmbient(testCase)
            cfg = default_engine_config();
            cfg.nozzle_type = 'cd';
            r = run_design_point(cfg);
            testCase.verifyTrue(r.success, r.error_msg);
            testCase.verifyEqual(r.stations.s9.P_static, r.stations.s0.P_static, 'RelTol', 1e-6, ...
                'cd nozzle (full expansion): P9 must equal the ambient pressure');
        end

    end
end
