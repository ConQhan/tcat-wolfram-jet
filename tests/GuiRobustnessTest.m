classdef GuiRobustnessTest < matlab.unittest.TestCase
    %GUIROBUSTNESSTEST Regression tests: GcamDesignApp must not crash on
    %   bad or extreme inputs, must show an error and recover. The app is
    %   created, controls are found with findall and their callbacks are
    %   called directly (works in matlab -batch). If a callback throws an
    %   uncaught error, the test framework reports the test as failed.
    %   Note: these tests open the app window.

    properties
        App
        Fig
    end

    methods (TestMethodSetup)
        function createApp(testCase)
            testCase.App = GcamDesignApp;
            figs = findall(groot, 'Type', 'figure');
            testCase.Fig = figs(1);
        end
    end

    methods (TestMethodTeardown)
        function deleteApp(testCase)
            delete(testCase.App);
        end
    end

    methods (Access = private)
        function btn = findButton(~, fig, txt)
            buttons = findall(fig, 'Type', 'uibutton');
            btn = [];
            for k = 1:numel(buttons)
                if strcmp(strtrim(erase(buttons(k).Text, '▶')), txt)
                    btn = buttons(k);
                    return
                end
            end
        end

        function ef = findNumericFieldNear(~, fig, val)
            edits = findall(fig, '-class', 'matlab.ui.control.NumericEditField');
            ef = [];
            for k = 1:numel(edits)
                if abs(edits(k).Value - val) < 1e-9
                    ef = edits(k);
                    return
                end
            end
        end

        function tbl = findPerfTable(~, fig)
            % The performance table is identified by its column count: it
            % always has exactly 2 columns, even before the first run
            % (StationsTable has 5, SweepDataTable is empty or has one
            % column per parameter A value). Matching on Data or on the
            % column titles was not reliable.
            tables = findall(fig, 'Type', 'uitable');
            tbl = [];
            for k = 1:numel(tables)
                if numel(tables(k).ColumnName) == 2
                    tbl = tables(k);
                    return
                end
            end
        end

        function found = anyLabelContains(~, fig, needle)
            lbls = findall(fig, '-class', 'matlab.ui.control.Label');
            found = false;
            for k = 1:numel(lbls)
                if contains(lbls(k).Text, needle)
                    found = true;
                    return
                end
            end
        end
    end

    methods (Test)

        function testZeroMassFlowDoesNotCrash(testCase)
            fig = testCase.Fig;
            hesBtn = testCase.findButton(fig, 'RUN');
            mdotField = testCase.findNumericFieldNear(fig, 50.0);  % default m_dot
            testCase.assertNotEmpty(mdotField);
            mdotField.Value = 0.0;
            cb = hesBtn.ButtonPushedFcn;
            cb(hesBtn, []);   % an uncaught error fails the test
        end

        function testNegativeMassFlowDoesNotCrash(testCase)
            fig = testCase.Fig;
            hesBtn = testCase.findButton(fig, 'RUN');
            mdotField = testCase.findNumericFieldNear(fig, 50.0);
            testCase.assertNotEmpty(mdotField);
            mdotField.Value = -10.0;
            cb = hesBtn.ButtonPushedFcn;
            cb(hesBtn, []);
        end

        function testExtremeValuesDoNotCrash(testCase)
            fig = testCase.Fig;
            hesBtn = testCase.findButton(fig, 'RUN');
            tt4Field = testCase.findNumericFieldNear(fig, 1400.0);
            picField = testCase.findNumericFieldNear(fig, 15.0);
            testCase.assertNotEmpty(tt4Field);
            testCase.assertNotEmpty(picField);
            tt4Field.Value = 1e6;
            picField.Value = 1000.0;
            cb = hesBtn.ButtonPushedFcn;
            cb(hesBtn, []);
        end

        function testRecoveryAfterBadInput(testCase)
            fig = testCase.Fig;
            hesBtn = testCase.findButton(fig, 'RUN');
            cb = hesBtn.ButtonPushedFcn;
            tt4Field = testCase.findNumericFieldNear(fig, 1400.0);
            testCase.assertNotEmpty(tt4Field);

            tt4Field.Value = 50.0;   % Tt4 < Tt3: impossible case
            cb(hesBtn, []);
            tt4Field.Value = 1400.0;  % back to a valid value
            cb(hesBtn, []);

            perfTbl = testCase.findPerfTable(fig);
            testCase.assertNotEmpty(perfTbl);
            fRow = perfTbl.Data(strcmp(perfTbl.Data(:,1), 'Specific thrust F_spec [N·s/kg]'), 2);
            testCase.assertNotEmpty(fRow);
            testCase.verifyEqual(fRow{1}, 858.2575123287082, 'RelTol', 1e-6, ...
                'after a bad input the app must return to normal results (no stale state)');
        end

        function testInvalidSweepRangeTextShowsMessage(testCase)
            fig = testCase.Fig;
            swBtn = testCase.findButton(fig, 'RUN SWEEP');
            testCase.assertNotEmpty(swBtn);

            allObjs = findall(fig);
            rangeField = [];
            for k = 1:numel(allObjs)
                o = allObjs(k);
                if isprop(o,'Value') && ischar(o.Value) && strcmp(o.Value, '4:1:12')
                    rangeField = o;
                end
            end
            testCase.assertNotEmpty(rangeField);
            rangeField.Value = 'invalid expression';
            cbSweep = swBtn.ButtonPushedFcn;
            cbSweep(swBtn, []);

            testCase.verifyTrue(testCase.anyLabelContains(fig, 'vector expression'), ...
                'expected error message for an invalid range text not shown');
        end

        function testSameFieldForBothParamsRejected(testCase)
            fig = testCase.Fig;
            swBtn = testCase.findButton(fig, 'RUN SWEEP');
            testCase.assertNotEmpty(swBtn);

            allObjs = findall(fig);
            ddA = []; ddB = [];
            for k = 1:numel(allObjs)
                o = allObjs(k);
                if isa(o, 'matlab.ui.control.DropDown')
                    if strcmp(o.Value, 'pi_c'), ddA = o; end
                    if strcmp(o.Value, 'Tt4'),  ddB = o; end
                end
            end
            testCase.assertNotEmpty(ddA);
            testCase.assertNotEmpty(ddB);
            ddB.Value = ddA.Value;   % make parameter B equal to A
            cbSweep = swBtn.ButtonPushedFcn;
            cbSweep(swBtn, []);

            testCase.verifyTrue(testCase.anyLabelContains(fig, 'must be different'), ...
                'expected message for parameter A = B not shown');
        end

        function testAllGasModelNozzleTypePolytropicCombinations(testCase)
            % All 2x2x2 = 8 combinations of gas_model x nozzle_type x
            % use_polytropic are run through the GUI and compared with a
            % direct run_design_point call.
            fig = testCase.Fig;
            hesBtn = testCase.findButton(fig, 'RUN');
            cb = hesBtn.ButtonPushedFcn;
            perfTbl = testCase.findPerfTable(fig);

            allObjs = findall(fig);
            gasDD = []; nozDD = []; polyCB = [];
            for k = 1:numel(allObjs)
                o = allObjs(k);
                if isa(o,'matlab.ui.control.DropDown') && isequal(sort(o.Items), sort({'ideal','real'}))
                    gasDD = o;
                elseif isa(o,'matlab.ui.control.DropDown') && isequal(sort(o.Items), sort({'cd','conv'}))
                    nozDD = o;
                elseif isa(o,'matlab.ui.control.CheckBox')
                    polyCB = o;
                end
            end
            testCase.assertNotEmpty(gasDD);
            testCase.assertNotEmpty(nozDD);
            testCase.assertNotEmpty(polyCB);

            gasOpts = {'ideal','real'}; nozOpts = {'cd','conv'}; polyOpts = [false, true];
            for gi = 1:2
                for ni = 1:2
                    for pj = 1:2
                        gasDD.Value = gasOpts{gi};
                        nozDD.Value = nozOpts{ni};
                        polyCB.Value = polyOpts(pj);
                        cb(hesBtn, []);

                        fRow = perfTbl.Data(strcmp(perfTbl.Data(:,1), 'Specific thrust F_spec [N·s/kg]'), 2);
                        testCase.assertNotEmpty(fRow, sprintf('gas=%s noz=%s poly=%d: result table empty', ...
                            gasOpts{gi}, nozOpts{ni}, polyOpts(pj)));
                        guiF = fRow{1};

                        cfgChk = default_engine_config();
                        cfgChk.gas_model = gasOpts{gi};
                        cfgChk.nozzle_type = nozOpts{ni};
                        cfgChk.use_polytropic = polyOpts(pj);
                        rChk = run_design_point(cfgChk);
                        testCase.assertTrue(rChk.success);

                        testCase.verifyEqual(guiF, rChk.performance.F_spec, 'RelTol', 1e-9, ...
                            sprintf('gas=%s noz=%s poly=%d: GUI result differs from the direct call', ...
                            gasOpts{gi}, nozOpts{ni}, polyOpts(pj)));
                    end
                end
            end
        end

    end
end
