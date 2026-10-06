classdef TcatDesignApp < matlab.apps.AppBase
    %TCATDESIGNAPP User interface for the turbojet design point and the
    %   parametric sweep. Hand-written with standard uifigure/uigridlayout
    %   components (plain MATLAB code, not the binary .mlapp format).
    %
    %   Usage: run launch.m, or after addpath(genpath(<tool folder>)) type
    %       TcatDesignApp
    %
    %   The app only calls the calculation files (cycle/run_design_point.m,
    %   sweep/param_sweep.m, config/default_engine_config.m); it does not
    %   change them.
    %
    %   Layout: the RUN button sits in a fixed bar at the top of the tab, so
    %   it never scrolls out of view. Input fields are packed in two columns,
    %   with label + field pairs side by side in each group.

    % -- Component handles ---------------------------------------------
    properties (Access = private)
        UIFigure            matlab.ui.Figure
        TabGroup            matlab.ui.container.TabGroup
        DesignTab           matlab.ui.container.Tab
        SweepTab            matlab.ui.container.Tab

        % Design point tab
        FieldEdits                      % containers.Map: fieldname -> uieditfield
        GasModelDropDown     matlab.ui.control.DropDown
        NozzleTypeDropDown   matlab.ui.control.DropDown
        PolytropicCheckBox   matlab.ui.control.CheckBox
        RunButton            matlab.ui.control.Button
        StatusLabel          matlab.ui.control.Label
        StationsTable        matlab.ui.control.Table
        PerfTable            matlab.ui.control.Table
        WarningsArea         matlab.ui.control.TextArea
        DiamAxes             matlab.ui.control.UIAxes

        % Parametric sweep tab
        ParamADropDown       matlab.ui.control.DropDown
        ParamARangeField     matlab.ui.control.EditField
        ParamBDropDown       matlab.ui.control.DropDown
        ParamBRangeField     matlab.ui.control.EditField
        SweepOutputDropDown  matlab.ui.control.DropDown
        PlotTypeSwitch                  % uiswitch('slider'): carpet / surface
        SweepButton          matlab.ui.control.Button
        FullScreenButton     matlab.ui.control.Button
        SweepStatusLabel     matlab.ui.control.Label
        SweepAxes            matlab.ui.control.UIAxes
        SweepDataTable       matlab.ui.control.Table
        ViewButtonRow                   % container of the standard view buttons
    end

    properties (Access = private)
        LastCfg        = []      % cfg of the last design point run (the sweep starts from it)
        LastGrid       = []      % last param_sweep result
        LastViewMode   = 'iso'   % last standard view in the surface plot ('iso'/'top'/'front'/'side')
        CarpetViewMode = 'iso'   % last axis-pair view in the carpet plot (independent of LastViewMode)
    end

    % -- Input field definitions (grouped) ------------------------------
    properties (Constant, Access = private)
        NumericFieldSpecs = {
            'M0',                   'Flight Mach number M0 [-]',            'Flight conditions and mass flow';
            'altitude_m',           'Altitude [m]',                         'Flight conditions and mass flow';
            'm_dot',                'Mass flow [kg/s]',                     'Flight conditions and mass flow';
            'pi_d_max',             'Inlet pressure recovery pi_d,max',     'Inlet';
            'pi_c',                 'Compressor pressure ratio pi_c',       'Compressor';
            'eta_c',                'Compressor isentropic eff. eta_c',     'Compressor';
            'e_c',                  'Compressor polytropic eff. e_c',       'Compressor';
            'Tt4',                  'Turbine inlet temperature Tt4 [K]',    'Combustor';
            'pi_b',                 'Combustor pressure ratio pi_b',        'Combustor';
            'eta_b',                'Combustion efficiency eta_b',          'Combustor';
            'FHV',                  'Fuel heating value FHV [J/kg]',        'Combustor';
            'eta_t',                'Turbine isentropic eff. eta_t',        'Turbine';
            'eta_m',                'Mechanical efficiency eta_m',          'Turbine';
            'e_t',                  'Turbine polytropic eff. e_t',          'Turbine';
            'eta_n',                'Nozzle efficiency eta_n',              'Nozzle';
            'pi_n',                 'Turbine exit duct pressure ratio pi_n','Nozzle';
            'power_offtake_kW',     'Accessory power offtake [kW]',         'Other / limits';
            'max_diameter_limit_mm','Max. diameter limit [mm] (0 = off)',   'Other / limits';
            'M_des_t2',             'Design Mach - t2',                     'Design Mach / gas';
            'M_des_t3',             'Design Mach - t3',                     'Design Mach / gas';
            'M_des_t4',             'Design Mach - t4',                     'Design Mach / gas';
            'M_des_t5',             'Design Mach - t5',                     'Design Mach / gas';
            'M_des_nz',             'Design Mach - nozzle',                 'Design Mach / gas';
            'gamma_c',              'gamma (cold section)',                 'Design Mach / gas';
            'gamma_h',              'gamma (hot section)',                  'Design Mach / gas';
        }
        % Groups in the left / right column (chosen by hand for similar heights)
        LeftColumnGroups  = {'Model options','Compressor','Combustor','Turbine'}
        RightColumnGroups = {'Flight conditions and mass flow','Inlet','Nozzle','Other / limits','Design Mach / gas'}

        SweepableFields = {'M0','altitude_m','pi_c','eta_c','Tt4','pi_b','eta_b', ...
                            'eta_t','eta_m','eta_n','pi_d_max','m_dot'}
        % 'f_ab' and 'm_bleed' are not offered: without afterburner and bleed
        % they are always exactly 0, and a flat plot would look like a bug.
        % 'is_choked' is a 0/1 flag; it is kept but is only meaningful in the
        % data table.
        SweepOutputFields = {'F_spec','TSFC','eta_th','eta_p','eta_o','V0','V9', ...
                              'f_core','thrust_N','area_throat','area_exit','M_exit', ...
                              'tau_lam','pi_c_opt','pi_d_eff','F_momentum','F_pressure', ...
                              'is_choked','Tt4_mix','eta_c_isen','eta_t_isen'}
    end

    % -- Building the components ----------------------------------------
    methods (Access = private)

        function createComponents(app)
            cfg = default_engine_config();
            app.FieldEdits = containers.Map('KeyType','char','ValueType','any');

            app.UIFigure = uifigure('Visible','off');
            app.UIFigure.Position = [60 40 1500 940];
            app.UIFigure.Name = 'TCAT - Turbojet Cycle Analysis Tool';

            app.TabGroup = uitabgroup(app.UIFigure);
            app.TabGroup.Position = [0 0 1500 940];

            app.DesignTab = uitab(app.TabGroup, 'Title', 'Design point');
            app.SweepTab  = uitab(app.TabGroup, 'Title', 'Parametric sweep');

            app.buildDesignTab(cfg);
            app.buildSweepTab();

            app.UIFigure.Visible = 'on';
        end

        function buildDesignTab(app, cfg)
            outer = uigridlayout(app.DesignTab, [2 1]);
            outer.RowHeight = {46, '1x'};
            outer.RowSpacing = 6;
            outer.Padding = [8 8 8 8];

            % ---- Fixed top bar: status + RUN, always visible (outside the
            % scrolling input area) ----
            topBar = uigridlayout(outer, [1 2]);
            topBar.Layout.Row = 1; topBar.Layout.Column = 1;
            topBar.ColumnWidth = {'1x', 200};
            topBar.Padding = [0 0 0 0];
            topBar.ColumnSpacing = 10;

            app.StatusLabel = uilabel(topBar);
            app.StatusLabel.Text = 'Ready - edit the inputs and press RUN.';
            app.StatusLabel.FontWeight = 'bold';
            app.StatusLabel.FontSize = 13;
            app.StatusLabel.Layout.Row = 1; app.StatusLabel.Layout.Column = 1;

            app.RunButton = uibutton(topBar, 'push');
            app.RunButton.Text = '▶  RUN';
            app.RunButton.FontWeight = 'bold';
            app.RunButton.FontSize = 15;
            app.RunButton.BackgroundColor = [0.16 0.45 0.28];
            app.RunButton.FontColor = [1 1 1];
            app.RunButton.Layout.Row = 1; app.RunButton.Layout.Column = 2;
            app.RunButton.ButtonPushedFcn = @(~,~) app.onRunButtonPushed();

            % ---- Body: inputs (left, 2 columns) | results (right) ----
            body = uigridlayout(outer, [1 2]);
            body.Layout.Row = 2; body.Layout.Column = 1;
            body.ColumnWidth = {860, '1x'};
            body.ColumnSpacing = 8;
            body.Padding = [0 0 0 0];

            leftPanel = uipanel(body);
            leftPanel.Scrollable = 'on';
            leftPanel.Layout.Row = 1; leftPanel.Layout.Column = 1;

            specs  = app.NumericFieldSpecs;
            colL   = app.LeftColumnGroups;
            colR   = app.RightColumnGroups;
            nRows  = max(numel(colL), numel(colR));

            leftGrid = uigridlayout(leftPanel, [nRows, 2]);
            leftGrid.ColumnWidth = {'1x','1x'};
            leftGrid.RowHeight = repmat({'fit'}, 1, nRows);
            leftGrid.RowSpacing = 6;
            leftGrid.ColumnSpacing = 6;

            app.placeGroupColumn(leftGrid, 1, colL, specs, cfg);
            app.placeGroupColumn(leftGrid, 2, colR, specs, cfg);

            % ---- Right: results ----
            rightGrid = uigridlayout(body, [5 1]);
            rightGrid.Layout.Row = 1; rightGrid.Layout.Column = 2;
            rightGrid.RowHeight = {175, 'fit', 300, 100, '1x'};
            rightGrid.RowSpacing = 4;
            rightGrid.Padding = [4 4 4 4];

            app.StationsTable = uitable(rightGrid);
            app.StationsTable.ColumnName = {'Station','Tt [K]','Pt [Pa]','T_static [K]','P_static [Pa]'};
            app.StationsTable.Layout.Row = 1; app.StationsTable.Layout.Column = 1;

            % Static values: stations 0 and 9 are solved by the cycle; for
            % t2-t5 the 0-D cycle only tracks total conditions (see
            % populateResults).
            staticNote = uilabel(rightGrid);
            staticNote.Text = '* t2-t5: static values derived from the design Mach number. 0 and 9: values solved by the cycle.';
            staticNote.FontSize = 9;
            staticNote.FontColor = [0.45 0.45 0.45];
            staticNote.WordWrap = 'on';
            staticNote.Layout.Row = 2; staticNote.Layout.Column = 1;

            app.PerfTable = uitable(rightGrid);
            app.PerfTable.ColumnName = {'Quantity','Value'};
            app.PerfTable.Layout.Row = 3; app.PerfTable.Layout.Column = 1;

            app.WarningsArea = uitextarea(rightGrid);
            app.WarningsArea.Editable = 'off';
            app.WarningsArea.Layout.Row = 4; app.WarningsArea.Layout.Column = 1;

            app.DiamAxes = uiaxes(rightGrid);
            app.DiamAxes.Layout.Row = 5; app.DiamAxes.Layout.Column = 1;
            title(app.DiamAxes, 'Station diameters [mm]');
        end

        function placeGroupColumn(app, leftGrid, colIdx, groupNames, specs, cfg)
            for gi = 1:numel(groupNames)
                gname = groupNames{gi};
                if strcmp(gname, 'Model options')
                    app.buildModelOptionsPanel(leftGrid, gi, colIdx, cfg);
                else
                    mask = strcmp(specs(:,3), gname);
                    fieldDefs = specs(mask, 1:2);
                    app.buildFieldGroup(leftGrid, gi, colIdx, gname, fieldDefs, cfg);
                end
            end
        end

        function buildModelOptionsPanel(app, parentGrid, rowIdx, colIdx, cfg)
            panel = uipanel(parentGrid);
            panel.Title = 'Model options';
            panel.Layout.Row = rowIdx; panel.Layout.Column = colIdx;

            g = uigridlayout(panel, [3 2]);
            g.ColumnWidth = {'1.3x','0.7x'};
            g.RowHeight = {26, 26, 26};
            g.RowSpacing = 4;

            l1 = uilabel(g); l1.Text = 'Gas model'; l1.Layout.Row = 1; l1.Layout.Column = 1;
            app.GasModelDropDown = uidropdown(g);
            app.GasModelDropDown.Items = {'ideal','real'};
            app.GasModelDropDown.Value = cfg.gas_model;
            app.GasModelDropDown.Layout.Row = 1; app.GasModelDropDown.Layout.Column = 2;

            l2 = uilabel(g); l2.Text = 'Nozzle type'; l2.Layout.Row = 2; l2.Layout.Column = 1;
            app.NozzleTypeDropDown = uidropdown(g);
            app.NozzleTypeDropDown.Items = {'cd','conv'};
            app.NozzleTypeDropDown.Value = cfg.nozzle_type;
            app.NozzleTypeDropDown.Layout.Row = 2; app.NozzleTypeDropDown.Layout.Column = 2;

            l3 = uilabel(g); l3.Text = 'Polytropic efficiency'; l3.Layout.Row = 3; l3.Layout.Column = 1;
            app.PolytropicCheckBox = uicheckbox(g);
            app.PolytropicCheckBox.Text = '';
            app.PolytropicCheckBox.Value = cfg.use_polytropic;
            app.PolytropicCheckBox.Layout.Row = 3; app.PolytropicCheckBox.Layout.Column = 2;
        end

        function buildFieldGroup(app, parentGrid, rowIdx, colIdx, groupTitle, fieldDefs, cfg)
            % Each group packs label + field pairs two per row, so a group
            % of n fields takes about n/2 rows.
            panel = uipanel(parentGrid);
            panel.Title = groupTitle;
            panel.Layout.Row = rowIdx; panel.Layout.Column = colIdx;

            n = size(fieldDefs, 1);
            nInnerRows = ceil(n/2);
            g = uigridlayout(panel, [nInnerRows, 4]);
            g.ColumnWidth = {'1.3x','0.7x','1.3x','0.7x'};
            g.RowHeight = repmat({26}, 1, nInnerRows);
            g.RowSpacing = 4;
            g.ColumnSpacing = 4;

            for i = 1:n
                fn  = fieldDefs{i,1};
                lbl = fieldDefs{i,2};
                r = ceil(i/2);
                if mod(i,2) == 1
                    labCol = 1; fieldCol = 2;
                else
                    labCol = 3; fieldCol = 4;
                end

                l = uilabel(g);
                l.Text = lbl;
                l.FontSize = 11;
                l.Layout.Row = r; l.Layout.Column = labCol;

                e = uieditfield(g, 'numeric');
                e.Layout.Row = r; e.Layout.Column = fieldCol;
                e.Value = cfg.(fn);
                app.FieldEdits(fn) = e;
            end
        end

        function buildSweepTab(app)
            % Outer rows are 'fit' so MATLAB sizes them to their content
            % (fixed pixel heights clipped the controls).
            grid = uigridlayout(app.SweepTab, [5 1]);
            grid.RowHeight = {'fit', 'fit', 'fit', 'fit', '1x'};
            grid.RowSpacing = 6;
            grid.Padding = [8 8 8 8];

            % ---- Top control row: parameter A/B + ranges + plot switch + RUN ----
            ctrl = uigridlayout(grid, [2 6]);
            ctrl.Layout.Row = 1; ctrl.Layout.Column = 1;
            ctrl.ColumnWidth = {'1x','1x','1x','1x','fit','fit'};
            ctrl.ColumnSpacing = 14;
            ctrl.RowHeight = {'fit','fit'};
            ctrl.RowSpacing = 4;

            la = uilabel(ctrl); la.Text = 'Parameter A'; la.Layout.Row = 1; la.Layout.Column = 1;
            app.ParamADropDown = uidropdown(ctrl);
            app.ParamADropDown.Items = app.SweepableFields;
            app.ParamADropDown.Value = 'pi_c';
            app.ParamADropDown.Layout.Row = 2; app.ParamADropDown.Layout.Column = 1;

            lar = uilabel(ctrl); lar.Text = 'A range (e.g. 4:1:12)'; lar.Layout.Row = 1; lar.Layout.Column = 2;
            app.ParamARangeField = uieditfield(ctrl, 'text');
            app.ParamARangeField.Value = '4:1:12';
            app.ParamARangeField.Layout.Row = 2; app.ParamARangeField.Layout.Column = 2;

            lb = uilabel(ctrl); lb.Text = 'Parameter B'; lb.Layout.Row = 1; lb.Layout.Column = 3;
            app.ParamBDropDown = uidropdown(ctrl);
            app.ParamBDropDown.Items = app.SweepableFields;
            app.ParamBDropDown.Value = 'Tt4';
            app.ParamBDropDown.Layout.Row = 2; app.ParamBDropDown.Layout.Column = 3;

            lbr = uilabel(ctrl); lbr.Text = 'B range (e.g. 1100:100:1400)'; lbr.Layout.Row = 1; lbr.Layout.Column = 4;
            app.ParamBRangeField = uieditfield(ctrl, 'text');
            app.ParamBRangeField.Value = '1100:100:1400';
            app.ParamBRangeField.Layout.Row = 2; app.ParamBRangeField.Layout.Column = 4;

            lsw = uilabel(ctrl);
            lsw.Text = 'Plot';
            lsw.HorizontalAlignment = 'center';
            lsw.Layout.Row = 1; lsw.Layout.Column = 5;
            app.PlotTypeSwitch = uiswitch(ctrl, 'slider');
            app.PlotTypeSwitch.Items = {'Carpet plot','Surface plot'};
            app.PlotTypeSwitch.Value = 'Surface plot';
            app.PlotTypeSwitch.Layout.Row = 2; app.PlotTypeSwitch.Layout.Column = 5;
            app.PlotTypeSwitch.ValueChangedFcn = @(~,~) app.plotSweepResult();

            app.SweepButton = uibutton(ctrl, 'push');
            app.SweepButton.Text = '▶  RUN SWEEP';
            app.SweepButton.FontWeight = 'bold';
            app.SweepButton.FontSize = 13;
            app.SweepButton.BackgroundColor = [0.16 0.45 0.28];
            app.SweepButton.FontColor = [1 1 1];
            app.SweepButton.Layout.Row = [1 2]; app.SweepButton.Layout.Column = 6;
            app.SweepButton.ButtonPushedFcn = @(~,~) app.onSweepButtonPushed();

            % ---- Second row: output to plot + status + full screen ----
            outputRow = uigridlayout(grid, [1 4]);
            outputRow.Layout.Row = 2; outputRow.Layout.Column = 1;
            outputRow.ColumnWidth = {'fit','fit','1x','fit'};
            outputRow.ColumnSpacing = 10;

            lo = uilabel(outputRow); lo.Text = 'Output to plot (surface / table):'; lo.Layout.Row = 1; lo.Layout.Column = 1;
            app.SweepOutputDropDown = uidropdown(outputRow);
            app.SweepOutputDropDown.Items = app.SweepOutputFields;
            app.SweepOutputDropDown.Value = 'F_spec';
            app.SweepOutputDropDown.Layout.Row = 1; app.SweepOutputDropDown.Layout.Column = 2;
            app.SweepOutputDropDown.ValueChangedFcn = @(~,~) app.plotSweepResult();

            app.SweepStatusLabel = uilabel(outputRow);
            app.SweepStatusLabel.Text = 'Ready - the inputs of the Design point tab are the base case.';
            app.SweepStatusLabel.Layout.Row = 1; app.SweepStatusLabel.Layout.Column = 3;

            app.FullScreenButton = uibutton(outputRow, 'push');
            app.FullScreenButton.Text = '⛶  Full screen';
            app.FullScreenButton.Layout.Row = 1; app.FullScreenButton.Layout.Column = 4;
            app.FullScreenButton.ButtonPushedFcn = @(~,~) app.onFullScreenButtonPushed();

            % ---- Third row: note on the plot modes ----
            noteLbl = uilabel(grid);
            noteLbl.Layout.Row = 3; noteLbl.Layout.Column = 1;
            noteLbl.Text = ['Note: the standard view buttons (Isometric/Top/Front/Side) work in both modes. ' ...
                'In the surface plot they rotate the camera. In the carpet plot they change the AXIS PAIR: ' ...
                'Isometric = classic thrust-TSFC carpet plot; Top = parameter A x B grid; ' ...
                'Front = "Output to plot" vs A (one curve per B value); Side = "Output to plot" vs B ' ...
                '(one curve per A value). Binary (0/1) fields such as is_choked are only meaningful ' ...
                'in the table; they look flat in continuous plots.'];
            noteLbl.FontSize = 10;
            noteLbl.FontColor = [0.45 0.45 0.45];
            noteLbl.WordWrap = 'on';

            % ---- Fourth row: CAD-style standard view buttons ----
            app.ViewButtonRow = uigridlayout(grid, [1 4]);
            app.ViewButtonRow.Layout.Row = 4; app.ViewButtonRow.Layout.Column = 1;
            app.ViewButtonRow.ColumnWidth = {'1x','1x','1x','1x'};
            app.ViewButtonRow.ColumnSpacing = 6;
            app.ViewButtonRow.Padding = [0 0 0 0];

            viewDefs = { ...
                'iso',   '⬒  Isometric'; ...
                'top',   '⬇  Top (X-Y)'; ...
                'front', '▭  Front (X-Z)'; ...
                'side',  '▮  Side (Y-Z)'};
            for vi = 1:size(viewDefs,1)
                vb = uibutton(app.ViewButtonRow, 'push');
                vb.Text = viewDefs{vi,2};
                vb.Layout.Row = 1; vb.Layout.Column = vi;
                vname = viewDefs{vi,1};
                vb.ButtonPushedFcn = @(~,~) app.onStandardViewButtonPushed(vname);
            end

            % ---- Fifth row: plot (left) | raw data table (right) ----
            plotRow = uigridlayout(grid, [1 2]);
            plotRow.Layout.Row = 5; plotRow.Layout.Column = 1;
            plotRow.ColumnWidth = {'2x', '1x'};
            plotRow.ColumnSpacing = 8;
            plotRow.Padding = [0 0 0 0];

            app.SweepAxes = uiaxes(plotRow);
            app.SweepAxes.Layout.Row = 1; app.SweepAxes.Layout.Column = 1;

            tablePanel = uipanel(plotRow);
            tablePanel.Title = 'Grid data (selected output, every point)';
            tablePanel.Layout.Row = 1; tablePanel.Layout.Column = 2;
            tableGrid = uigridlayout(tablePanel, [1 1]);
            tableGrid.Padding = [2 2 2 2];
            app.SweepDataTable = uitable(tableGrid);
            app.SweepDataTable.Layout.Row = 1; app.SweepDataTable.Layout.Column = 1;
        end
    end

    % -- Callbacks and logic --------------------------------------------
    methods (Access = private)

        function cfg = readConfigFromForm(app)
            cfg = default_engine_config();
            keys = app.FieldEdits.keys;
            for i = 1:numel(keys)
                fn = keys{i};
                cfg.(fn) = app.FieldEdits(fn).Value;
            end
            cfg.gas_model      = app.GasModelDropDown.Value;
            cfg.nozzle_type    = app.NozzleTypeDropDown.Value;
            cfg.use_polytropic = app.PolytropicCheckBox.Value;
        end

        function onRunButtonPushed(app)
            app.StatusLabel.Text = 'Running...';
            app.StatusLabel.FontColor = [0.2 0.2 0.2];
            drawnow;
            cfg = app.readConfigFromForm();
            r = run_design_point(cfg);
            app.LastCfg = cfg;
            app.populateResults(r);
        end

        function populateResults(app, r)
            if ~r.success
                app.StatusLabel.Text = ['ERROR: ' r.error_msg];
                app.StatusLabel.FontColor = [0.75 0.1 0.1];
                app.StationsTable.Data = {};
                app.PerfTable.Data = {};
                app.WarningsArea.Value = {''};
                cla(app.DiamAxes);
                return
            end
            app.StatusLabel.Text = 'Done.';
            app.StatusLabel.FontColor = [0.10 0.55 0.20];

            s = r.stations;
            ids    = {'s0','t2','t3','t4','t5','s9'};
            labels = {'0 (ambient)','t2 (inlet exit)','t3 (compressor exit)', ...
                      't4 (combustor exit)','t5 (turbine exit)','9 (nozzle exit)'};
            % The 0-D cycle does not solve static T/P at t2/t3/t4/t5 (same in
            % Python engine_core.py: only total conditions are tracked). For
            % display only, they are derived from the design Mach numbers of
            % r.geometries(1:4) (t2/t3/t4/t5; the 5th entry re-sizes t5 for
            % the nozzle with M_des_nz and is not used) with the validated
            % isentropic_T_ratio/isentropic_P_ratio. The cycle is unchanged.
            cfgUsed = app.LastCfg;
            geoMach = [NaN, r.geometries(1).M_design, r.geometries(2).M_design, ...
                       r.geometries(3).M_design, r.geometries(4).M_design, NaN];
            geoGamma = [NaN, cfgUsed.gamma_c, cfgUsed.gamma_c, cfgUsed.gamma_h, cfgUsed.gamma_h, NaN];
            data = cell(numel(ids), 5);
            for i = 1:numel(ids)
                st = s.(ids{i});
                data{i,1} = labels{i};
                data{i,2} = st.T_total;
                data{i,3} = st.P_total;
                if ~isempty(st.T_static)
                    data{i,4} = st.T_static;
                    data{i,5} = st.P_static;
                else
                    Tr = isentropic_T_ratio(geoMach(i), geoGamma(i));
                    Pr = isentropic_P_ratio(geoMach(i), geoGamma(i));
                    data{i,4} = st.T_total / Tr;
                    data{i,5} = st.P_total / Pr;
                end
            end
            app.StationsTable.Data = data;

            p = r.performance;
            % eta_p (propulsive) and eta_o (overall) are exactly zero at
            % M0 = 0 by definition (thrust power F*V0 = 0). This is not a bug,
            % but the app opens with M0 = 0, so the reason is shown.
            if cfgUsed.M0 == 0
                etaPCell = sprintf('%.4f  (M0=0: zero by definition when static)', p.eta_p);
                etaOCell = sprintf('%.4f  (M0=0: zero by definition when static)', p.eta_o);
            else
                etaPCell = p.eta_p;
                etaOCell = p.eta_o;
            end
            perfRows = { ...
                'Specific thrust F_spec [N·s/kg]',     p.F_spec; ...
                'TSFC [mg/(N·s)]',                     p.TSFC*1e6; ...
                'Thermal efficiency eta_th',           p.eta_th; ...
                'Propulsive efficiency eta_p',         etaPCell; ...
                'Overall efficiency eta_o',            etaOCell; ...
                'Thrust [N] (for the given mass flow)', p.thrust_N; ...
                'Exit velocity V9 [m/s]',              p.V9; ...
                'Fuel/air ratio f',                    p.f_core; ...
                'Inlet recovery pi_d,eff',             p.pi_d_eff; ...
                'tau_lambda (diagnostic)',             p.tau_lam; ...
                'Optimum pi_c (diagnostic)',           p.pi_c_opt; ...
                'Nozzle state',                        p.nozzle_state; ...
                'Nozzle choked',                       mat2str(p.is_choked); ...
            };
            app.PerfTable.Data = perfRows;

            if isempty(r.warnings)
                app.WarningsArea.Value = {'(no warnings)'};
            else
                app.WarningsArea.Value = r.warnings(:);
            end

            diam = [r.geometries.diameter_mm];
            stids = {r.geometries.station_id};
            % The same station_id (e.g. "t5") can appear twice: the nozzle
            % inlet re-uses the turbine exit station with M_des_nz (original
            % Python behaviour). categorical() needs unique labels.
            dispLabels = stids;
            seen = containers.Map('KeyType', 'char', 'ValueType', 'double');
            for i = 1:numel(dispLabels)
                key = dispLabels{i};
                if isKey(seen, key)
                    seen(key) = seen(key) + 1;
                    dispLabels{i} = sprintf('%s(%d)', key, seen(key));
                else
                    seen(key) = 1;
                end
            end
            cla(app.DiamAxes);
            bar(app.DiamAxes, categorical(dispLabels, dispLabels), diam);
            ylabel(app.DiamAxes, 'Diameter [mm]');
            title(app.DiamAxes, 'Station diameters');
        end

        function onSweepButtonPushed(app)
            if isempty(app.LastCfg)
                cfg = app.readConfigFromForm();
            else
                cfg = app.LastCfg;
            end

            fieldA = app.ParamADropDown.Value;
            fieldB = app.ParamBDropDown.Value;
            if strcmp(fieldA, fieldB)
                app.SweepStatusLabel.Text = 'Parameters A and B must be different fields.';
                app.SweepStatusLabel.FontColor = [0.75 0.1 0.1];
                return
            end

            valsA = str2num(app.ParamARangeField.Value); %#ok<ST2NM>
            valsB = str2num(app.ParamBRangeField.Value); %#ok<ST2NM>
            if isempty(valsA) || isempty(valsB)
                app.SweepStatusLabel.Text = 'Enter a valid MATLAB vector expression (e.g. 4:1:12).';
                app.SweepStatusLabel.FontColor = [0.75 0.1 0.1];
                return
            end

            app.SweepStatusLabel.Text = 'Running...';
            app.SweepStatusLabel.FontColor = [0.2 0.2 0.2];
            drawnow;

            grd = param_sweep(cfg, fieldA, valsA, fieldB, valsB);
            app.LastGrid = grd;
            app.plotSweepResult();

            nfail = nnz(~grd.success);
            if nfail > 0
                app.SweepStatusLabel.Text = sprintf('Done (%d/%d cells failed).', ...
                    nfail, numel(grd.success));
                app.SweepStatusLabel.FontColor = [0.75 0.5 0.0];
            else
                app.SweepStatusLabel.Text = 'Done, every cell succeeded.';
                app.SweepStatusLabel.FontColor = [0.10 0.55 0.20];
            end
        end

        function plotSweepResult(app)
            % The standard view buttons work in both modes: they rotate the
            % camera in the surface plot and change the axis pair in the
            % carpet plot (see onStandardViewButtonPushed).
            if isempty(app.LastGrid)
                return
            end
            app.drawSweepPlot(app.SweepAxes);
            app.populateSweepTable();
        end

        function [Z, lbl] = scaleOutputField(~, grd, outField)
            % TSFC in SI units (kg/(N.s), ~1e-5) is hard to read; it is shown
            % in mg/(N.s) (*1e6) like the Python GUI. Other fields unchanged.
            Z = grd.(outField);
            if strcmp(outField, 'TSFC')
                Z = Z * 1e6;
                lbl = 'TSFC [mg/(N·s)]';
            else
                lbl = outField;
            end
        end

        function drawSweepPlot(app, ax)
            % Shared by the embedded SweepAxes and the "Full screen" figure;
            % both accept a standard MATLAB axes handle.
            if strcmp(app.PlotTypeSwitch.Value, 'Carpet plot')
                % Classic carpet plot (thrust-TSFC, one curve per parameter B
                % value, parameter A labels on the points), as in GasTurb and
                % the literature. Not a contour / heat map.
                app.drawCarpetPlot(ax);
                return
            end

            grd = app.LastGrid;
            outField = app.SweepOutputDropDown.Value;
            [Z, lbl] = app.scaleOutputField(grd, outField);
            Z(~grd.success) = NaN;
            [A, B] = meshgrid(grd.values_a, grd.values_b);

            % cla(ax) only clears the children, not axis-level settings such
            % as the legend, grid and box that the carpet plot turns on.
            % Reset them so they do not leak into the surface plot.
            cla(ax);
            legend(ax, 'off');
            grid(ax, 'off');
            box(ax, 'off');
            surf(ax, A, B, Z);
            xlabel(ax, grd.field_a, 'Interpreter', 'none');
            ylabel(ax, grd.field_b, 'Interpreter', 'none');
            zlabel(ax, lbl, 'Interpreter', 'none');
            colorbar(ax);
            % Re-apply the last standard view without animation, so changing
            % the output does not reset the view. Also updates the title.
            app.applyView(ax, app.LastViewMode);
        end

        function [az, el] = viewAngleFor(~, viewName)
            % Camera angles of the CAD-style standard views (MATLAB az/el
            % convention; 'top' equals view(2)).
            switch viewName
                case 'top';   az = 0;     el = 90;
                case 'front'; az = 0;     el = 0;
                case 'side';  az = -90;   el = 0;
                otherwise;    az = -37.5; el = 30;   % 'iso' (MATLAB 3-D default)
            end
        end

        function updateTitleForView(app, ax, viewName)
            % The title names the two quantities actually visible in the
            % current view (in front/side views one axis is edge-on).
            if isempty(app.LastGrid)
                return
            end
            grd = app.LastGrid;
            [~, lbl] = app.scaleOutputField(grd, app.SweepOutputDropDown.Value);
            switch viewName
                case 'top'
                    desc = sprintf('%s x %s', grd.field_a, grd.field_b);
                case 'front'
                    desc = sprintf('%s x %s', grd.field_a, lbl);
                case 'side'
                    desc = sprintf('%s x %s', grd.field_b, lbl);
                otherwise
                    desc = sprintf('%s x %s, colour=%s', grd.field_a, grd.field_b, lbl);
            end
            title(ax, sprintf('%s  (%s)', lbl, desc), 'Interpreter', 'none');
        end

        function applyView(app, ax, viewName)
            % Applies the view immediately (no animation); used to restore
            % the last view after a redraw.
            [az, el] = app.viewAngleFor(viewName);
            view(ax, az, el);
            app.updateTitleForView(ax, viewName);
        end

        function animateToView(app, ax, viewName)
            % Called when a standard view button is pressed: interpolates
            % the camera from the current angles to the target in ~20 steps
            % for a smooth CAD-style rotation.
            [az1, el1] = app.viewAngleFor(viewName);
            [az0, el0] = view(ax);
            nSteps = 20;
            for k = 1:nSteps
                t = k / nSteps;
                view(ax, az0 + (az1-az0)*t, el0 + (el1-el0)*t);
                drawnow;
                pause(0.015);
            end
            app.LastViewMode = viewName;
            app.updateTitleForView(ax, viewName);
        end

        function onStandardViewButtonPushed(app, viewName)
            if isempty(app.LastGrid)
                return
            end
            if strcmp(app.PlotTypeSwitch.Value, 'Surface plot')
                app.animateToView(app.SweepAxes, viewName);
                return
            end
            % In the carpet plot the button changes the AXIS PAIR, not the
            % camera: different data is drawn, so it is simply redrawn.
            app.CarpetViewMode = viewName;
            app.drawSweepPlot(app.SweepAxes);
            app.populateSweepTable();
        end

        function drawCarpetPlot(app, ax)
            % Dispatcher: in the carpet plot the four standard view buttons
            % change the axis pair. Common clean-up is done here once.
            cla(ax); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
            view(ax, 2);
            colorbar(ax, 'off');
            switch app.CarpetViewMode
                case 'top'
                    app.drawCarpetGrid(ax);
                case 'front'
                    app.drawCarpetVsA(ax);
                case 'side'
                    app.drawCarpetVsB(ax);
                otherwise
                    app.drawCarpetClassic(ax);
            end
            hold(ax, 'off');
        end

        function drawCarpetClassic(app, ax)
            % Port of Python param_table_tab.py:_plot_param_chart(): X = thrust
            % [N], Y = TSFC [mg/(N.s)], one curve per parameter B value, each
            % parameter A value a labelled point, a star at the lowest TSFC.
            % This is the default ("Isometric") view.
            grd = app.LastGrid;
            na = numel(grd.values_a); nb = numel(grd.values_b);
            cmap = lines(max(nb, 1));

            bestX = []; bestY = []; bestA = []; bestB = [];
            anyLine = false;
            for ib = 1:nb
                xs = []; ys = []; as_ = [];
                for ia = 1:na
                    if grd.success(ib, ia)
                        xs(end+1)  = grd.thrust_N(ib, ia); %#ok<AGROW>
                        ys(end+1)  = grd.TSFC(ib, ia) * 1e6; %#ok<AGROW>
                        as_(end+1) = grd.values_a(ia); %#ok<AGROW>
                    end
                end
                if isempty(xs)
                    continue
                end
                anyLine = true;
                plot(ax, xs, ys, '-o', 'Color', cmap(ib,:), 'LineWidth', 1.8, ...
                    'MarkerSize', 5, 'MarkerFaceColor', cmap(ib,:), ...
                    'DisplayName', sprintf('%s=%.4g', grd.field_b, grd.values_b(ib)));
                for k = 1:numel(xs)
                    text(ax, xs(k), ys(k), sprintf('  %s=%.4g', grd.field_a, as_(k)), ...
                        'FontSize', 7, 'Color', [0.40 0.40 0.40], 'VerticalAlignment', 'bottom');
                end
                [ymin, idx] = min(ys);
                if isempty(bestY) || ymin < bestY
                    bestY = ymin; bestX = xs(idx); bestA = as_(idx); bestB = grd.values_b(ib);
                end
            end

            if ~isempty(bestY)
                plot(ax, bestX, bestY, 'p', 'MarkerSize', 16, ...
                    'MarkerFaceColor', [0.95 0.75 0.10], 'MarkerEdgeColor', [0.2 0.2 0.2], ...
                    'DisplayName', 'Lowest TSFC (automatic optimum)');
                optStr = sprintf('Optimum: %s=%.4g  %s=%.4g   ->   F=%.1f N   TSFC=%.2f mg/(N·s)', ...
                    grd.field_a, bestA, grd.field_b, bestB, bestX, bestY);
            else
                optStr = 'No valid result in this range.';
            end

            xlabel(ax, 'Thrust F [N]');
            ylabel(ax, 'TSFC [mg/(N·s)]');
            title(ax, {'Parametric sweep - thrust vs TSFC (carpet plot)', optStr}, 'Interpreter', 'none');
            if anyLine
                legend(ax, 'Location', 'best', 'FontSize', 8);
            end
        end

        function drawCarpetGrid(app, ax)
            % "Top": the swept parameter grid itself (A x B), with every
            % point marked as succeeded or failed.
            grd = app.LastGrid;
            [A, B] = meshgrid(grd.values_a, grd.values_b);
            okMask = grd.success;
            plot(ax, A(okMask), B(okMask), 'o', 'MarkerSize', 6, ...
                'MarkerFaceColor', [0.20 0.55 0.85], 'MarkerEdgeColor', [0.10 0.30 0.55], ...
                'DisplayName', 'Succeeded');
            if any(~okMask(:))
                plot(ax, A(~okMask), B(~okMask), 'x', 'MarkerSize', 8, 'LineWidth', 1.5, ...
                    'Color', [0.80 0.15 0.15], 'DisplayName', 'Failed');
            end
            xlabel(ax, grd.field_a, 'Interpreter', 'none');
            ylabel(ax, grd.field_b, 'Interpreter', 'none');
            title(ax, sprintf('Parameter grid  (%s x %s)', grd.field_a, grd.field_b), 'Interpreter', 'none');
            legend(ax, 'Location', 'best', 'FontSize', 8);
        end

        function drawCarpetVsA(app, ax)
            % "Front": the selected output against parameter A, one curve per
            % parameter B value.
            grd = app.LastGrid;
            outField = app.SweepOutputDropDown.Value;
            [Z, lbl] = app.scaleOutputField(grd, outField);
            Z(~grd.success) = NaN;
            nb = numel(grd.values_b);
            cmap = lines(max(nb, 1));
            for ib = 1:nb
                plot(ax, grd.values_a, Z(ib,:), '-o', 'Color', cmap(ib,:), 'LineWidth', 1.8, ...
                    'MarkerSize', 5, 'MarkerFaceColor', cmap(ib,:), ...
                    'DisplayName', sprintf('%s=%.4g', grd.field_b, grd.values_b(ib)));
            end
            xlabel(ax, grd.field_a, 'Interpreter', 'none');
            ylabel(ax, lbl, 'Interpreter', 'none');
            title(ax, sprintf('%s vs %s  (one curve per %s)', lbl, grd.field_a, grd.field_b), 'Interpreter', 'none');
            legend(ax, 'Location', 'best', 'FontSize', 8);
        end

        function drawCarpetVsB(app, ax)
            % "Side": the selected output against parameter B, one curve per
            % parameter A value.
            grd = app.LastGrid;
            outField = app.SweepOutputDropDown.Value;
            [Z, lbl] = app.scaleOutputField(grd, outField);
            Z(~grd.success) = NaN;
            na = numel(grd.values_a);
            cmap = lines(max(na, 1));
            for ia = 1:na
                plot(ax, grd.values_b, Z(:,ia), '-o', 'Color', cmap(ia,:), 'LineWidth', 1.8, ...
                    'MarkerSize', 5, 'MarkerFaceColor', cmap(ia,:), ...
                    'DisplayName', sprintf('%s=%.4g', grd.field_a, grd.values_a(ia)));
            end
            xlabel(ax, grd.field_b, 'Interpreter', 'none');
            ylabel(ax, lbl, 'Interpreter', 'none');
            title(ax, sprintf('%s vs %s  (one curve per %s)', lbl, grd.field_b, grd.field_a), 'Interpreter', 'none');
            legend(ax, 'Location', 'best', 'FontSize', 8);
        end

        function populateSweepTable(app)
            % Shows the full grid of the selected output as numbers, so every
            % point can be read without guessing from the colour scale.
            if isempty(app.LastGrid)
                app.SweepDataTable.Data = {};
                app.SweepDataTable.ColumnName = {};
                app.SweepDataTable.RowName = {};
                return
            end
            grd = app.LastGrid;
            outField = app.SweepOutputDropDown.Value;
            [Z, ~] = app.scaleOutputField(grd, outField);

            na = numel(grd.values_a); nb = numel(grd.values_b);
            colNames = arrayfun(@(v) sprintf('%s=%.4g', grd.field_a, v), grd.values_a, 'UniformOutput', false);
            rowNames = arrayfun(@(v) sprintf('%s=%.4g', grd.field_b, v), grd.values_b, 'UniformOutput', false);

            dataCell = cell(nb, na);
            for ib = 1:nb
                for ia = 1:na
                    if grd.success(ib, ia)
                        dataCell{ib, ia} = sprintf('%.4g', Z(ib, ia));
                    else
                        dataCell{ib, ia} = '-';
                    end
                end
            end
            app.SweepDataTable.ColumnName = colNames;
            app.SweepDataTable.RowName = rowNames;
            app.SweepDataTable.Data = dataCell;
        end

        function onFullScreenButtonPushed(app)
            if isempty(app.LastGrid)
                app.SweepStatusLabel.Text = 'Run a sweep first.';
                app.SweepStatusLabel.FontColor = [0.75 0.1 0.1];
                return
            end
            scr = get(0, 'ScreenSize');
            w = round(scr(3) * 0.78); h = round(scr(4) * 0.80);
            x = round((scr(3) - w) / 2); y = round((scr(4) - h) / 2);
            fig2 = figure('Name', 'TCAT parametric sweep - full screen', ...
                'NumberTitle', 'off', 'Color', 'w', 'Position', [x y w h]);
            ax2 = axes(fig2);
            app.drawSweepPlot(ax2);
        end
    end

    % -- App life cycle -------------------------------------------------
    methods (Access = public)
        function app = TcatDesignApp
            createComponents(app)
            registerApp(app, app.UIFigure)
            if nargout == 0
                clear app
            end
        end

        function delete(app)
            delete(app.UIFigure)
        end
    end
end
