classdef ProcessingWindow < handle
%PROCESSINGWINDOW Data-processing window launched by RadarControlMachineApp.
%
%   radarui.ProcessingWindow(dataFile, baseCfg)
%
%   The window runs the existing pradar candidate/track/unwrap pipeline while
%   keeping acquisition and legacy RD display code isolated from processing.

    properties
        UIFigure
        MainGrid
        ControlPanel
        ControlGrid
        TabGroup

        DataFileEdit
        BrowseButton
        FileInfoLabel

        BackgroundStartEdit
        BackgroundEndEdit
        TargetStartEdit
        TargetEndEdit

        WinSizeEdit
        WinStepEdit
        DopplerFftEdit
        FramePeriodEdit

        RangeMinEdit
        RangeMaxEdit
        DisplayRangeMinEdit
        DisplayRangeMaxEdit
        CandidateThresholdEdit
        MaxCandidatesEdit

        FitSpeedMinEdit
        FitSpeedMaxEdit
        ReferenceSpeedEdit
        TrackToleranceEdit
        TrackStartTimeEdit
        TrackEndTimeEdit
        MinTrackWindowsEdit
        HighSpeedMinEdit

        ProjectionDropDown
        VelocityHardGateCheckBox
        VelocityToleranceEdit
        MeanRemovalCheckBox
        KeepIntermediateCheckBox

        RunButton
        CancelButton
        ExportButton
        ProgressGauge
        StatusLabel

        SummaryTextArea
        EnhancedRdAxes
        TrackAxes
        VelocityAxes
    end

    properties (Access = private)
        BaseConfig
        Controller
        Result
        ProgressDialog
        TotalFrames = 0
    end

    methods
        function obj = ProcessingWindow(dataFile, baseCfg)
            if nargin < 1
                dataFile = "";
            end
            if nargin < 2 || isempty(baseCfg)
                baseCfg = pradar.defaultConfig();
            end

            obj.BaseConfig = baseCfg;
            obj.Controller = radarui.ProcessingController();

            obj.createComponents();
            obj.applyConfigToControls(baseCfg);

            if strlength(string(dataFile)) > 0
                obj.DataFileEdit.Value = char(string(dataFile));
            end

            obj.refreshFileInfo();
            obj.UIFigure.Visible = 'on';
        end

        function setInput(obj, dataFile, baseCfg)
            if nargin >= 3 && ~isempty(baseCfg)
                obj.BaseConfig = baseCfg;
                obj.applyConfigToControls(baseCfg);
            end

            if nargin >= 2 && strlength(string(dataFile)) > 0
                obj.DataFileEdit.Value = char(string(dataFile));
            end

            obj.refreshFileInfo();
            obj.show();
        end

        function show(obj)
            if ~isempty(obj.UIFigure) && isvalid(obj.UIFigure)
                obj.UIFigure.Visible = 'on';
                figure(obj.UIFigure);
            end
        end

        function delete(obj)
            try
                if ~isempty(obj.Controller) && obj.Controller.IsRunning
                    obj.Controller.requestCancel();
                end
            catch
            end

            try
                if ~isempty(obj.ProgressDialog) ...
                        && isvalid(obj.ProgressDialog)
                    close(obj.ProgressDialog);
                end
            catch
            end

            if ~isempty(obj.UIFigure) && isvalid(obj.UIFigure)
                obj.UIFigure.CloseRequestFcn = [];
                delete(obj.UIFigure);
            end
        end
    end

    methods (Access = private)
        function createComponents(obj)
            obj.UIFigure = uifigure('Visible', 'off');
            obj.UIFigure.Name = '弹丸雷达数据处理';
            obj.UIFigure.Position = [120 80 1240 760];
            obj.UIFigure.CloseRequestFcn = @(~, ~) delete(obj);

            obj.MainGrid = uigridlayout(obj.UIFigure, [1 2]);
            obj.MainGrid.ColumnWidth = {360, '1x'};
            obj.MainGrid.RowHeight = {'1x'};
            obj.MainGrid.Padding = [8 8 8 8];
            obj.MainGrid.ColumnSpacing = 8;

            obj.ControlPanel = uipanel(obj.MainGrid);
            obj.ControlPanel.Title = '处理参数';
            obj.ControlPanel.Layout.Row = 1;
            obj.ControlPanel.Layout.Column = 1;

            obj.ControlGrid = uigridlayout(obj.ControlPanel, [20 4]);
            obj.ControlGrid.ColumnWidth = {92, 72, 92, '1x'};
            obj.ControlGrid.RowHeight = { ...
                26, 34, 24, 26, 26, 26, 26, 26, 26, 26, ...
                26, 26, 26, 26, 26, 26, 32, 30, 34, '1x'};
            obj.ControlGrid.Padding = [8 8 8 8];
            obj.ControlGrid.RowSpacing = 5;
            obj.ControlGrid.ColumnSpacing = 5;

            fileLabel = uilabel(obj.ControlGrid);
            fileLabel.Text = 'BIN 文件';
            fileLabel.Layout.Row = 1;
            fileLabel.Layout.Column = 1;

            obj.DataFileEdit = uieditfield(obj.ControlGrid, 'text');
            obj.DataFileEdit.Layout.Row = 1;
            obj.DataFileEdit.Layout.Column = [2 3];
            obj.DataFileEdit.ValueChangedFcn = @(~, ~) obj.refreshFileInfo();

            obj.BrowseButton = uibutton(obj.ControlGrid, 'push');
            obj.BrowseButton.Text = '浏览';
            obj.BrowseButton.Layout.Row = 1;
            obj.BrowseButton.Layout.Column = 4;
            obj.BrowseButton.ButtonPushedFcn = @(~, ~) obj.browseFile();

            obj.FileInfoLabel = uilabel(obj.ControlGrid);
            obj.FileInfoLabel.Text = '尚未选择有效 BIN 文件';
            obj.FileInfoLabel.WordWrap = 'on';
            obj.FileInfoLabel.Layout.Row = 2;
            obj.FileInfoLabel.Layout.Column = [1 4];

            addLabel(obj, 3, 1, '背景起始帧');
            obj.BackgroundStartEdit = addNumeric(obj, 3, 2, 1);
            addLabel(obj, 3, 3, '背景终止帧');
            obj.BackgroundEndEdit = addNumeric(obj, 3, 4, 1);

            addLabel(obj, 4, 1, '目标起始帧');
            obj.TargetStartEdit = addNumeric(obj, 4, 2, 1);
            addLabel(obj, 4, 3, '目标终止帧');
            obj.TargetEndEdit = addNumeric(obj, 4, 4, 1);

            addLabel(obj, 5, 1, '短时窗 Chirp');
            obj.WinSizeEdit = addNumeric(obj, 5, 2, 16);
            addLabel(obj, 5, 3, '滑动步进');
            obj.WinStepEdit = addNumeric(obj, 5, 4, 16);

            addLabel(obj, 6, 1, 'Doppler FFT');
            obj.DopplerFftEdit = addNumeric(obj, 6, 2, 128);
            addLabel(obj, 6, 3, '帧周期 ms');
            obj.FramePeriodEdit = addNumeric(obj, 6, 4, 3.5);

            addLabel(obj, 7, 1, '候选距离下限');
            obj.RangeMinEdit = addNumeric(obj, 7, 2, 0.25);
            addLabel(obj, 7, 3, '候选距离上限');
            obj.RangeMaxEdit = addNumeric(obj, 7, 4, 3.0);

            addLabel(obj, 8, 1, '显示距离下限');
            obj.DisplayRangeMinEdit = addNumeric(obj, 8, 2, 0);
            addLabel(obj, 8, 3, '显示距离上限');
            obj.DisplayRangeMaxEdit = addNumeric(obj, 8, 4, 6.0);

            addLabel(obj, 9, 1, '候选门限 dB');
            obj.CandidateThresholdEdit = addNumeric(obj, 9, 2, 3.0);
            addLabel(obj, 9, 3, '每窗候选数');
            obj.MaxCandidatesEdit = addNumeric(obj, 9, 4, 6);

            addLabel(obj, 10, 1, '拟合速度下限');
            obj.FitSpeedMinEdit = addNumeric(obj, 10, 2, 200);
            addLabel(obj, 10, 3, '拟合速度上限');
            obj.FitSpeedMaxEdit = addNumeric(obj, 10, 4, 1700);

            addLabel(obj, 11, 1, '参考速度 m/s');
            obj.ReferenceSpeedEdit = addNumeric(obj, 11, 2, 400);
            addLabel(obj, 11, 3, '轨迹容差 m');
            obj.TrackToleranceEdit = addNumeric(obj, 11, 4, 0.55);

            addLabel(obj, 12, 1, '轨迹起始 ms');
            obj.TrackStartTimeEdit = addNumeric(obj, 12, 2, 0);
            addLabel(obj, 12, 3, '轨迹终止 ms');
            obj.TrackEndTimeEdit = addNumeric(obj, 12, 4, Inf);

            addLabel(obj, 13, 1, '最少轨迹点');
            obj.MinTrackWindowsEdit = addNumeric(obj, 13, 2, 5);
            addLabel(obj, 13, 3, '最小|模糊速度|');
            obj.HighSpeedMinEdit = addNumeric(obj, 13, 4, 0);

            obj.VelocityHardGateCheckBox = uicheckbox(obj.ControlGrid);
            obj.VelocityHardGateCheckBox.Text = '启用速度硬门限';
            obj.VelocityHardGateCheckBox.Layout.Row = 14;
            obj.VelocityHardGateCheckBox.Layout.Column = [1 2];

            addLabel(obj, 14, 3, '速度容差 m/s');
            obj.VelocityToleranceEdit = addNumeric(obj, 14, 4, 70);

            addLabel(obj, 15, 1, 'RD 投影');
            obj.ProjectionDropDown = uidropdown(obj.ControlGrid);
            obj.ProjectionDropDown.Items = {'range', 'velocity'};
            obj.ProjectionDropDown.Value = 'range';
            obj.ProjectionDropDown.Layout.Row = 15;
            obj.ProjectionDropDown.Layout.Column = 2;

            obj.MeanRemovalCheckBox = uicheckbox(obj.ControlGrid);
            obj.MeanRemovalCheckBox.Text = '慢时间去均值';
            obj.MeanRemovalCheckBox.Layout.Row = 15;
            obj.MeanRemovalCheckBox.Layout.Column = 3;

            obj.KeepIntermediateCheckBox = uicheckbox(obj.ControlGrid);
            obj.KeepIntermediateCheckBox.Text = '保留完整 RD Cube';
            obj.KeepIntermediateCheckBox.Layout.Row = 15;
            obj.KeepIntermediateCheckBox.Layout.Column = 4;

            buttonGrid = uigridlayout(obj.ControlGrid, [1 3]);
            buttonGrid.Layout.Row = 16;
            buttonGrid.Layout.Column = [1 4];
            buttonGrid.ColumnWidth = {'1x', '1x', '1x'};
            buttonGrid.Padding = [0 0 0 0];
            buttonGrid.ColumnSpacing = 6;

            obj.RunButton = uibutton(buttonGrid, 'push');
            obj.RunButton.Text = '开始处理';
            obj.RunButton.ButtonPushedFcn = @(~, ~) obj.runProcessing();

            obj.CancelButton = uibutton(buttonGrid, 'push');
            obj.CancelButton.Text = '取消';
            obj.CancelButton.Enable = 'off';
            obj.CancelButton.ButtonPushedFcn = @(~, ~) obj.cancelProcessing();

            obj.ExportButton = uibutton(buttonGrid, 'push');
            obj.ExportButton.Text = '导出结果';
            obj.ExportButton.Enable = 'off';
            obj.ExportButton.ButtonPushedFcn = @(~, ~) obj.exportResults();

            obj.ProgressGauge = uigauge(obj.ControlGrid, 'linear');
            obj.ProgressGauge.Limits = [0 100];
            obj.ProgressGauge.Value = 0;
            obj.ProgressGauge.Layout.Row = 17;
            obj.ProgressGauge.Layout.Column = [1 4];

            obj.StatusLabel = uilabel(obj.ControlGrid);
            obj.StatusLabel.Text = '就绪';
            obj.StatusLabel.WordWrap = 'on';
            obj.StatusLabel.Layout.Row = 18;
            obj.StatusLabel.Layout.Column = [1 4];

            noteLabel = uilabel(obj.ControlGrid);
            noteLabel.Text = [ ...
                '候选距离只限制算法搜索；显示距离只控制图像范围。' ...
                '参考速度用于速度约束与解模糊。'];
            noteLabel.WordWrap = 'on';
            noteLabel.Layout.Row = [19 20];
            noteLabel.Layout.Column = [1 4];

            obj.TabGroup = uitabgroup(obj.MainGrid);
            obj.TabGroup.Layout.Row = 1;
            obj.TabGroup.Layout.Column = 2;

            summaryTab = uitab(obj.TabGroup, 'Title', '结果摘要');
            summaryGrid = uigridlayout(summaryTab, [1 1]);
            summaryGrid.Padding = [8 8 8 8];
            obj.SummaryTextArea = uitextarea(summaryGrid);
            obj.SummaryTextArea.Editable = 'off';
            obj.SummaryTextArea.Value = {'尚未执行处理。'};

            rdTab = uitab(obj.TabGroup, 'Title', '候选目标RD');
            rdGrid = uigridlayout(rdTab, [1 1]);
            rdGrid.Padding = [8 8 8 8];
            obj.EnhancedRdAxes = uiaxes(rdGrid);
            title(obj.EnhancedRdAxes, '候选目标点增强图');
            xlabel(obj.EnhancedRdAxes, 'Time (ms)');
            ylabel(obj.EnhancedRdAxes, 'Range (m)');
            grid(obj.EnhancedRdAxes, 'on');

            trackTab = uitab(obj.TabGroup, 'Title', '候选与轨迹');
            trackGrid = uigridlayout(trackTab, [1 1]);
            trackGrid.Padding = [8 8 8 8];
            obj.TrackAxes = uiaxes(trackGrid);
            title(obj.TrackAxes, '距离-时间候选点与最终轨迹');
            xlabel(obj.TrackAxes, 'Time (ms)');
            ylabel(obj.TrackAxes, 'Range (m)');
            grid(obj.TrackAxes, 'on');

            velocityTab = uitab(obj.TabGroup, 'Title', '速度');
            velocityGrid = uigridlayout(velocityTab, [1 1]);
            velocityGrid.Padding = [8 8 8 8];
            obj.VelocityAxes = uiaxes(velocityGrid);
            title(obj.VelocityAxes, '有模糊/解模糊速度');
            xlabel(obj.VelocityAxes, 'Time (ms)');
            ylabel(obj.VelocityAxes, 'Velocity (m/s)');
            grid(obj.VelocityAxes, 'on');
        end

        function applyConfigToControls(obj, cfg)
            if isfield(cfg, 'winSize')
                obj.WinSizeEdit.Value = cfg.winSize;
            end
            if isfield(cfg, 'winStep')
                obj.WinStepEdit.Value = cfg.winStep;
            end
            if isfield(cfg, 'dopplerFftSize')
                obj.DopplerFftEdit.Value = cfg.dopplerFftSize;
            end
            if isfield(cfg, 'framePeriod')
                obj.FramePeriodEdit.Value = cfg.framePeriod * 1e3;
            end

            if isfield(cfg, 'candidateRangeMin')
                obj.RangeMinEdit.Value = cfg.candidateRangeMin;
            end
            if isfield(cfg, 'candidateRangeMax')
                obj.RangeMaxEdit.Value = cfg.candidateRangeMax;
            end
            if isfield(cfg, 'displayRangeMin')
                obj.DisplayRangeMinEdit.Value = cfg.displayRangeMin;
            end
            if isfield(cfg, 'displayRangeMax')
                obj.DisplayRangeMaxEdit.Value = cfg.displayRangeMax;
            end
            if isfield(cfg, 'candidateThresholdDb')
                obj.CandidateThresholdEdit.Value = ...
                    cfg.candidateThresholdDb;
            end
            if isfield(cfg, 'maxCandidatesPerWindow')
                obj.MaxCandidatesEdit.Value = ...
                    cfg.maxCandidatesPerWindow;
            end

            if isfield(cfg, 'fitSpeedMin')
                obj.FitSpeedMinEdit.Value = cfg.fitSpeedMin;
            end
            if isfield(cfg, 'fitSpeedMax')
                obj.FitSpeedMaxEdit.Value = cfg.fitSpeedMax;
            end
            if isfield(cfg, 'measuredSpeed') ...
                    && isfinite(cfg.measuredSpeed)
                obj.ReferenceSpeedEdit.Value = abs(cfg.measuredSpeed);
            end
            if isfield(cfg, 'trackTolerance')
                obj.TrackToleranceEdit.Value = cfg.trackTolerance;
            end
            if isfield(cfg, 'minTrackWindows')
                obj.MinTrackWindowsEdit.Value = cfg.minTrackWindows;
            end
            if isfield(cfg, 'trackStartTimeMs')
                obj.TrackStartTimeEdit.Value = cfg.trackStartTimeMs;
            end
            if isfield(cfg, 'trackEndTimeMs')
                obj.TrackEndTimeEdit.Value = cfg.trackEndTimeMs;
            end
            if isfield(cfg, 'highSpeedMin')
                obj.HighSpeedMinEdit.Value = cfg.highSpeedMin;
            end
            if isfield(cfg, 'useVelocityHardGate')
                obj.VelocityHardGateCheckBox.Value = ...
                    logical(cfg.useVelocityHardGate);
            end
            if isfield(cfg, 'velocityTolerance')
                obj.VelocityToleranceEdit.Value = cfg.velocityTolerance;
            end

            if isfield(cfg, 'rdProjectionMode')
                value = char(string(cfg.rdProjectionMode));
                if ismember(value, obj.ProjectionDropDown.Items)
                    obj.ProjectionDropDown.Value = value;
                end
            end
            if isfield(cfg, 'slowTimeMeanRemoval')
                obj.MeanRemovalCheckBox.Value = ...
                    logical(cfg.slowTimeMeanRemoval);
            end
            if isfield(cfg, 'keepIntermediateData')
                obj.KeepIntermediateCheckBox.Value = ...
                    logical(cfg.keepIntermediateData);
            end
        end

        function browseFile(obj)
            startDir = pwd;
            currentPath = string(obj.DataFileEdit.Value);
            if strlength(currentPath) > 0
                candidateDir = fileparts(currentPath);
                if isfolder(candidateDir)
                    startDir = candidateDir;
                end
            end

            [fileName, filePath] = uigetfile( ...
                {'*.bin', 'DCA1000 BIN (*.bin)'; '*.*', '所有文件'}, ...
                '选择雷达 BIN 文件', startDir);

            if isequal(fileName, 0)
                return;
            end

            obj.DataFileEdit.Value = fullfile(filePath, fileName);
            obj.refreshFileInfo();
        end

        function refreshFileInfo(obj)
            dataFile = string(obj.DataFileEdit.Value);

            if strlength(dataFile) == 0 || ~isfile(dataFile)
                obj.TotalFrames = 0;
                obj.FileInfoLabel.Text = '尚未选择有效 BIN 文件';
                return;
            end

            try
                cfg = obj.collectConfig(false);
                derived = pradar.deriveParameters(cfg);
                info = dir(dataFile);
                obj.TotalFrames = floor(info.bytes / derived.bytesPerFrame);
                trailingBytes = mod(info.bytes, derived.bytesPerFrame);

                obj.FileInfoLabel.Text = sprintf( ...
                    '完整物理帧: %d；尾部字节: %d；单帧 %.3f MiB', ...
                    obj.TotalFrames, ...
                    trailingBytes, ...
                    derived.bytesPerFrame / 1024^2);

                if obj.TotalFrames >= 1
                    bgStart = 1;
                    bgEnd = min(obj.TotalFrames, 10);
                    targetStart = min(obj.TotalFrames, bgEnd + 1);
                    targetEnd = min(obj.TotalFrames, targetStart + 9);

                    obj.BackgroundStartEdit.Value = bgStart;
                    obj.BackgroundEndEdit.Value = bgEnd;
                    obj.TargetStartEdit.Value = targetStart;
                    obj.TargetEndEdit.Value = targetEnd;
                end
            catch ME
                obj.TotalFrames = 0;
                obj.FileInfoLabel.Text = ...
                    sprintf('文件参数解析失败: %s', ME.message);
            end
        end

        function cfg = collectConfig(obj, includeFrameRanges)
            if nargin < 2
                includeFrameRanges = true;
            end

            cfg = obj.BaseConfig;

            cfg.winSize = round(obj.WinSizeEdit.Value);
            cfg.winStep = round(obj.WinStepEdit.Value);
            cfg.dopplerFftSize = round(obj.DopplerFftEdit.Value);
            cfg.framePeriod = obj.FramePeriodEdit.Value * 1e-3;

            cfg.candidateRangeMin = obj.RangeMinEdit.Value;
            cfg.candidateRangeMax = obj.RangeMaxEdit.Value;
            cfg.displayRangeMin = obj.DisplayRangeMinEdit.Value;
            cfg.displayRangeMax = obj.DisplayRangeMaxEdit.Value;
            cfg.candidateThresholdDb = ...
                obj.CandidateThresholdEdit.Value;
            cfg.maxCandidatesPerWindow = ...
                round(obj.MaxCandidatesEdit.Value);

            cfg.fitSpeedMin = obj.FitSpeedMinEdit.Value;
            cfg.fitSpeedMax = obj.FitSpeedMaxEdit.Value;
            cfg.measuredSpeed = abs(obj.ReferenceSpeedEdit.Value);
            cfg.trackTolerance = obj.TrackToleranceEdit.Value;
            cfg.trackStartTimeMs = obj.TrackStartTimeEdit.Value;
            cfg.trackEndTimeMs = obj.TrackEndTimeEdit.Value;
            cfg.minTrackWindows = ...
                round(obj.MinTrackWindowsEdit.Value);

            cfg.highSpeedMin = max(0, obj.HighSpeedMinEdit.Value);
            cfg.useFullAliasedVelocityAxis = cfg.highSpeedMin <= 0;
            cfg.useVelocityHardGate = ...
                logical(obj.VelocityHardGateCheckBox.Value);
            cfg.velocityTolerance = obj.VelocityToleranceEdit.Value;

            cfg.rdProjectionMode = ...
                string(obj.ProjectionDropDown.Value);
            cfg.slowTimeMeanRemoval = ...
                logical(obj.MeanRemovalCheckBox.Value);
            cfg.keepIntermediateData = ...
                logical(obj.KeepIntermediateCheckBox.Value);

            cfg.generateRdGif = false;
            cfg.generateRawRdGif = false;
            cfg.generateMeanRemovedRdGif = false;
            cfg.generateEnhancedRdGif = false;
            cfg.plotVisible = false;
            cfg.saveResults = false;
            cfg.saveFigures = false;

            if includeFrameRanges
                cfg.backgroundFrameStart = ...
                    round(obj.BackgroundStartEdit.Value);
                cfg.backgroundFrameEnd = ...
                    round(obj.BackgroundEndEdit.Value);
                cfg.targetFrameStart = ...
                    round(obj.TargetStartEdit.Value);
                cfg.targetFrameEnd = ...
                    round(obj.TargetEndEdit.Value);
            end

            if cfg.framePeriod <= 0 || ~isfinite(cfg.framePeriod)
                error('radarui:InvalidFramePeriod', ...
                    '帧周期必须为正数。');
            end
            if cfg.winSize < 2 || cfg.winStep < 1
                error('radarui:InvalidWindow', ...
                    '短时窗至少为 2 Chirp，滑动步进至少为 1 Chirp。');
            end
            if cfg.maxCandidatesPerWindow < 1
                error('radarui:InvalidCandidateCount', ...
                    '每窗候选数至少为 1。');
            end
            if cfg.candidateRangeMin < 0
                error('radarui:InvalidRangeGate', ...
                    '候选距离下限不能为负数。');
            end
            if cfg.displayRangeMin < 0 ...
                    || cfg.displayRangeMax <= cfg.displayRangeMin
                error('radarui:InvalidDisplayRange', ...
                    '显示距离范围必须满足 0 <= 下限 < 上限。');
            end
            if cfg.trackEndTimeMs < cfg.trackStartTimeMs
                error('radarui:InvalidTrackTimeGate', ...
                    '轨迹终止时间不能小于起始时间。');
            end
            if ~isfinite(cfg.velocityTolerance) ...
                    || cfg.velocityTolerance <= 0
                error('radarui:InvalidVelocityTolerance', ...
                    '速度容差必须为正数。');
            end
            if ~isfinite(cfg.highSpeedMin) || cfg.highSpeedMin < 0
                error('radarui:InvalidHighSpeedMin', ...
                    '最小模糊速度不能为负数。');
            end
            if ~isfinite(cfg.measuredSpeed) || cfg.measuredSpeed <= 0
                error('radarui:InvalidReferenceSpeed', ...
                    '参考速度必须为正数。');
            end
            if ~isfinite(cfg.trackTolerance) || cfg.trackTolerance <= 0
                error('radarui:InvalidTrackTolerance', ...
                    '轨迹容差必须为正数。');
            end
            if cfg.minTrackWindows < 2
                error('radarui:InvalidTrackLength', ...
                    '最少轨迹点至少为 2。');
            end

            cfg = pradar.validateConfig(cfg);
        end

        function runProcessing(obj)
            dataFile = string(obj.DataFileEdit.Value);

            if strlength(dataFile) == 0 || ~isfile(dataFile)
                uialert(obj.UIFigure, ...
                    '请先选择有效的 BIN 文件。', ...
                    '无法开始处理');
                return;
            end

            try
                cfg = obj.collectConfig(true);
                derived = pradar.deriveParameters(cfg);
            catch ME
                uialert(obj.UIFigure, ME.message, '参数错误');
                return;
            end

            info = dir(dataFile);
            totalFrames = floor(info.bytes / derived.bytesPerFrame);
            if totalFrames < 1
                uialert(obj.UIFigure, ...
                    '文件中没有完整物理帧。', ...
                    '无法开始处理');
                return;
            end

            if cfg.backgroundFrameEnd > totalFrames ...
                    || cfg.targetFrameEnd > totalFrames
                uialert(obj.UIFigure, ...
                    sprintf('帧范围超出文件范围 1~%d。', totalFrames), ...
                    '参数错误');
                return;
            end

            estimatedBytes = obj.estimatePeakBytes(cfg, derived);
            if estimatedBytes > 1.5 * 1024^3
                answer = uiconfirm( ...
                    obj.UIFigure, ...
                    sprintf([ ...
                        '当前范围预计峰值数组内存约 %.2f GiB。\n' ...
                        '建议缩小背景/目标帧范围后分段处理。\n\n' ...
                        '仍要继续吗？'], estimatedBytes / 1024^3), ...
                    '内存提示', ...
                    'Options', {'继续', '取消'}, ...
                    'DefaultOption', 2, ...
                    'CancelOption', 2);

                if strcmp(answer, '取消')
                    return;
                end
            end

            obj.Controller = radarui.ProcessingController();
            obj.Result = [];
            obj.RunButton.Enable = 'off';
            obj.CancelButton.Enable = 'on';
            obj.ExportButton.Enable = 'off';
            obj.ProgressGauge.Value = 0;
            obj.StatusLabel.Text = '正在处理...';

            obj.ProgressDialog = uiprogressdlg( ...
                obj.UIFigure, ...
                'Title', '雷达数据处理', ...
                'Message', '准备处理...', ...
                'Indeterminate', 'off', ...
                'Cancelable', 'on', ...
                'Value', 0);

            cleanupObject = onCleanup(@() obj.finishUiRun()); %#ok<NASGU>

            try
                result = obj.Controller.run( ...
                    dataFile, ...
                    cfg, ...
                    @(stage, completed, total) ...
                        obj.updateProgress( ...
                            stage, completed, total));

                obj.Result = result;
                obj.renderResult();
                obj.ExportButton.Enable = 'on';
                obj.StatusLabel.Text = sprintf( ...
                    '处理完成：候选点 %d，轨迹点 %d。', ...
                    height(result.candidateTable), ...
                    height(result.trackTable));
            catch ME
                if strcmp(ME.identifier, 'pradar:Cancelled')
                    obj.StatusLabel.Text = '处理已取消。';
                else
                    obj.StatusLabel.Text = ...
                        sprintf('处理失败: %s', ME.message);
                    uialert(obj.UIFigure, ...
                        getReport(ME, 'extended', ...
                            'hyperlinks', 'off'), ...
                        '处理失败');
                end
            end
        end

        function cancelProcessing(obj)
            if ~isempty(obj.Controller) && obj.Controller.IsRunning
                obj.Controller.requestCancel();
                obj.StatusLabel.Text = '正在取消...';
            end
        end

        function updateProgress(obj, stage, completed, total)
            total = max(1, double(total));
            fraction = min(1, max(0, double(completed) / total));

            switch char(string(stage))
                case 'background'
                    overall = 0.20 * fraction;
                    message = sprintf( ...
                        '背景建模：%d / %d 帧', ...
                        completed, total);
                case 'target'
                    overall = 0.20 + 0.55 * fraction;
                    message = sprintf( ...
                        '目标数据：%d / %d 帧', ...
                        completed, total);
                otherwise
                    overall = 0.75 + 0.25 * fraction;
                    message = sprintf( ...
                        '候选/轨迹分析：%d / %d', ...
                        completed, total);
            end

            obj.ProgressGauge.Value = 100 * overall;
            obj.StatusLabel.Text = message;

            if ~isempty(obj.ProgressDialog) ...
                    && isvalid(obj.ProgressDialog)
                obj.ProgressDialog.Value = overall;
                obj.ProgressDialog.Message = message;

                if obj.ProgressDialog.CancelRequested
                    obj.Controller.requestCancel();
                end
            end

            drawnow limitrate;
        end

        function finishUiRun(obj)
            obj.RunButton.Enable = 'on';
            obj.CancelButton.Enable = 'off';

            if ~isempty(obj.ProgressDialog) ...
                    && isvalid(obj.ProgressDialog)
                close(obj.ProgressDialog);
            end
            obj.ProgressDialog = [];

            if ~isempty(obj.Result)
                obj.ProgressGauge.Value = 100;
            end
        end

        function bytes = estimatePeakBytes(~, cfg, derived)
            backgroundFrames = ...
                cfg.backgroundFrameEnd - cfg.backgroundFrameStart + 1;
            targetFrames = ...
                cfg.targetFrameEnd - cfg.targetFrameStart + 1;

            backgroundWindows = ...
                backgroundFrames * derived.windowsPerFrame;
            targetWindows = ...
                targetFrames * derived.windowsPerFrame;

            rdElementBytes = 4;
            rangeElementBytes = 4;

            backgroundRdBytes = ...
                cfg.rangeFftSize * cfg.dopplerFftSize ...
                * backgroundWindows * rdElementBytes;

            % target cube plus enhanced target cube coexist during analysis
            targetRdBytes = ...
                2 * cfg.rangeFftSize * cfg.dopplerFftSize ...
                * targetWindows * rdElementBytes;

            rangeBytes = ...
                cfg.rangeFftSize * cfg.numChirpsPerFrame ...
                * (backgroundFrames + 2 * targetFrames) ...
                * rangeElementBytes;

            bytes = backgroundRdBytes + targetRdBytes + rangeBytes;
        end

        function renderResult(obj)
            result = obj.Result;
            obj.renderSummary(result);
            obj.renderCandidateRd(result);
            obj.renderTrack(result);
            obj.renderVelocity(result);
        end

        function renderSummary(obj, result)
            lines = {};
            lines{end + 1} = sprintf( ...
                '数据文件: %s', char(result.dataFile));
            lines{end + 1} = sprintf( ...
                '完整物理帧: %d', result.totalFrames);
            lines{end + 1} = sprintf( ...
                '背景帧: %d ~ %d', ...
                result.cfg.backgroundFrameStart, ...
                result.cfg.backgroundFrameEnd);
            lines{end + 1} = sprintf( ...
                '目标帧: %d ~ %d', ...
                result.cfg.targetFrameStart, ...
                result.cfg.targetFrameEnd);
            lines{end + 1} = sprintf( ...
                '短时窗/步进: %d / %d Chirp', ...
                result.cfg.winSize, result.cfg.winStep);
            lines{end + 1} = sprintf( ...
                '速度轴 Vmax: +/- %.3f m/s', ...
                result.derived.vMax);
            lines{end + 1} = sprintf( ...
                '候选点数量: %d', ...
                height(result.candidateTable));
            lines{end + 1} = sprintf( ...
                '最终轨迹点数量: %d', ...
                height(result.trackTable));
            lines{end + 1} = ' ';

            if result.fitInfo.valid
                lines{end + 1} = sprintf( ...
                    '距离-时间拟合速度: %.3f m/s', ...
                    result.fitInfo.speed);
                lines{end + 1} = sprintf( ...
                    '距离拟合 RMSE: %.4f m', ...
                    result.fitInfo.rmse);
                lines{end + 1} = sprintf( ...
                    '理论有模糊速度: %.3f m/s', ...
                    result.fitInfo.expectedAliasedSpeed);

                if isfinite(result.velocityMetrics.meanSpeed)
                    lines{end + 1} = sprintf( ...
                        '平均解模糊速度: %.3f m/s', ...
                        result.velocityMetrics.meanSpeed);
                    lines{end + 1} = sprintf( ...
                        '参考速度: %.3f m/s', ...
                        result.cfg.measuredSpeed);
                    lines{end + 1} = sprintf( ...
                        '相对参考速度 RMSE: %.3f m/s', ...
                        result.velocityMetrics.rmse);
                    lines{end + 1} = sprintf( ...
                        '相对参考速度 MAE: %.3f m/s', ...
                        result.velocityMetrics.mae);
                end
            else
                lines{end + 1} = ...
                    '未找到满足当前参数约束的连续目标轨迹。';
                lines{end + 1} = ...
                    '可检查背景/目标帧范围、距离门、候选门限和速度范围。';
            end

            obj.SummaryTextArea.Value = lines;
        end

        function renderCandidateRd(obj, result)
            cla(obj.EnhancedRdAxes);
            hold(obj.EnhancedRdAxes, 'on');

            if isempty(result.rdEnhancedRangeTimeDb)
                text( ...
                    obj.EnhancedRdAxes, ...
                    0.5, 0.5, ...
                    '当前投影模式没有时间-距离增强图，请将 RD 投影切换为 range。', ...
                    'Units', 'normalized', ...
                    'HorizontalAlignment', 'center', ...
                    'VerticalAlignment', 'middle', ...
                    'FontSize', 12);

                title(obj.EnhancedRdAxes, '候选目标点增强图');
                xlabel(obj.EnhancedRdAxes, 'Time (ms)');
                ylabel(obj.EnhancedRdAxes, 'Range (m)');
                grid(obj.EnhancedRdAxes, 'on');
                hold(obj.EnhancedRdAxes, 'off');
                return;
            end

            timeAxis = [];
            if isfield(result, 'targetData') ...
                    && isfield(result.targetData, 'windowTimeMs')
                timeAxis = result.targetData.windowTimeMs;
            end

            numWindows = size(result.rdEnhancedRangeTimeDb, 2);
            if isempty(timeAxis) || numel(timeAxis) ~= numWindows
                timeAxis = 1:numWindows;
                xLabelText = 'Window Index';
            else
                timeAxis = double(timeAxis(:).');
                xLabelText = 'Time (ms)';
            end

            imagesc( ...
                obj.EnhancedRdAxes, ...
                timeAxis, ...
                result.derived.rangeAxis, ...
                result.rdEnhancedRangeTimeDb);

            obj.EnhancedRdAxes.YDir = 'normal';
            xlabel(obj.EnhancedRdAxes, xLabelText);
            ylabel(obj.EnhancedRdAxes, 'Range (m)');
            title(obj.EnhancedRdAxes, '候选目标点增强图');
            colorbar(obj.EnhancedRdAxes);
            grid(obj.EnhancedRdAxes, 'on');

            displayMin = max( ...
                min(result.derived.rangeAxis), ...
                result.cfg.displayRangeMin);
            displayMax = min( ...
                max(result.derived.rangeAxis), ...
                result.cfg.displayRangeMax);

            if isfinite(displayMin) && isfinite(displayMax) ...
                    && displayMax > displayMin
                ylim(obj.EnhancedRdAxes, [displayMin displayMax]);
            end

            if isfield(result.cfg, 'rdEnhancedRangeTimeClim') ...
                    && numel(result.cfg.rdEnhancedRangeTimeClim) == 2
                clim(obj.EnhancedRdAxes, ...
                    result.cfg.rdEnhancedRangeTimeClim);
            end

            yline( ...
                obj.EnhancedRdAxes, ...
                result.cfg.candidateRangeMin, ...
                'w:', ...
                '候选下限', ...
                'LineWidth', 1.2, ...
                'LabelHorizontalAlignment', 'left', ...
                'HandleVisibility', 'off');

            yline( ...
                obj.EnhancedRdAxes, ...
                result.cfg.candidateRangeMax, ...
                'w:', ...
                '候选上限', ...
                'LineWidth', 1.2, ...
                'LabelHorizontalAlignment', 'left', ...
                'HandleVisibility', 'off');

            candidates = result.candidateTable;
            if ~isempty(candidates)
                scatter( ...
                    obj.EnhancedRdAxes, ...
                    candidates.Time_ms, ...
                    candidates.Range_m, ...
                    54, ...
                    'o', ...
                    'MarkerEdgeColor', 'w', ...
                    'LineWidth', 1.4, ...
                    'DisplayName', '候选点');
            end

            track = result.trackTable;
            if ~isempty(track)
                plot( ...
                    obj.EnhancedRdAxes, ...
                    track.Time_ms, ...
                    track.Range_m, ...
                    'r-', ...
                    'LineWidth', 1.4, ...
                    'HandleVisibility', 'off');

                scatter( ...
                    obj.EnhancedRdAxes, ...
                    track.Time_ms, ...
                    track.Range_m, ...
                    64, ...
                    'o', ...
                    'MarkerFaceColor', 'y', ...
                    'MarkerEdgeColor', 'r', ...
                    'LineWidth', 1.5, ...
                    'DisplayName', '最终轨迹');

                if ismember( ...
                        'FittedRange_m', ...
                        track.Properties.VariableNames)
                    plot( ...
                        obj.EnhancedRdAxes, ...
                        track.Time_ms, ...
                        track.FittedRange_m, ...
                        'r--', ...
                        'LineWidth', 1.4, ...
                        'DisplayName', '拟合轨迹');
                end
            end

            if ~isempty(candidates) || ~isempty(track)
                legend(obj.EnhancedRdAxes, 'Location', 'best');
            end

            hold(obj.EnhancedRdAxes, 'off');
        end

        function renderTrack(obj, result)
            cla(obj.TrackAxes);
            hold(obj.TrackAxes, 'on');

            candidates = result.candidateTable;
            track = result.trackTable;

            if ~isempty(candidates)
                scatter( ...
                    obj.TrackAxes, ...
                    candidates.Time_ms, ...
                    candidates.Range_m, ...
                    28, ...
                    candidates.RelativeStrength_dB, ...
                    'filled', ...
                    'DisplayName', '候选点');
                colorbar(obj.TrackAxes);
            end

            if ~isempty(track)
                plot( ...
                    obj.TrackAxes, ...
                    track.Time_ms, ...
                    track.Range_m, ...
                    'ko-', ...
                    'LineWidth', 1.3, ...
                    'MarkerSize', 5, ...
                    'DisplayName', '最终轨迹');

                if ismember( ...
                        'FittedRange_m', ...
                        track.Properties.VariableNames)
                    plot( ...
                        obj.TrackAxes, ...
                        track.Time_ms, ...
                        track.FittedRange_m, ...
                        'k--', ...
                        'LineWidth', 1.5, ...
                        'DisplayName', '距离拟合');
                end
            end

            hold(obj.TrackAxes, 'off');
            xlabel(obj.TrackAxes, 'Time (ms)');
            ylabel(obj.TrackAxes, 'Range (m)');
            title(obj.TrackAxes, '距离-时间候选点与最终轨迹');
            grid(obj.TrackAxes, 'on');

            if ~isempty(candidates) || ~isempty(track)
                legend(obj.TrackAxes, 'Location', 'best');
            end
        end

        function renderVelocity(obj, result)
            cla(obj.VelocityAxes);
            track = result.trackTable;

            if isempty(track)
                title(obj.VelocityAxes, '未找到有效轨迹');
                grid(obj.VelocityAxes, 'on');
                return;
            end

            hold(obj.VelocityAxes, 'on');

            plot( ...
                obj.VelocityAxes, ...
                track.Time_ms, ...
                track.AliasedVelocity_mps, ...
                'o-', ...
                'LineWidth', 1.1, ...
                'DisplayName', '有模糊速度');

            if ismember( ...
                    'UnwrappedVelocity_mps', ...
                    track.Properties.VariableNames)
                plot( ...
                    obj.VelocityAxes, ...
                    track.Time_ms, ...
                    track.UnwrappedVelocity_mps, ...
                    's-', ...
                    'LineWidth', 1.5, ...
                    'DisplayName', '解模糊速度');
            end

            yline( ...
                obj.VelocityAxes, ...
                result.cfg.measuredSpeed, ...
                '--', ...
                '参考速度', ...
                'DisplayName', '参考速度');

            hold(obj.VelocityAxes, 'off');
            xlabel(obj.VelocityAxes, 'Time (ms)');
            ylabel(obj.VelocityAxes, 'Velocity (m/s)');
            title(obj.VelocityAxes, '有模糊/解模糊速度');
            grid(obj.VelocityAxes, 'on');
            legend(obj.VelocityAxes, 'Location', 'best');
        end

        function exportResults(obj)
            if isempty(obj.Result)
                uialert(obj.UIFigure, ...
                    '当前没有可导出的处理结果。', ...
                    '导出结果');
                return;
            end

            outputDir = uigetdir(pwd, '选择结果保存目录');
            if isequal(outputDir, 0)
                return;
            end

            [~, baseName, ~] = fileparts(char(obj.Result.dataFile));
            prefix = fullfile(outputDir, baseName);

            result = obj.Result; %#ok<NASGU>
            save([prefix '_processing_result.mat'], ...
                'result', '-v7.3');

            if ~isempty(obj.Result.candidateTable)
                writetable( ...
                    obj.Result.candidateTable, ...
                    [prefix '_candidates.csv']);
            end

            if ~isempty(obj.Result.trackTable)
                writetable( ...
                    obj.Result.trackTable, ...
                    [prefix '_track.csv']);
            end

            summaryPath = [prefix '_summary.txt'];
            fid = fopen(summaryPath, 'w', 'n', 'UTF-8');
            if fid >= 0
                cleanupObject = onCleanup(@() fclose(fid)); %#ok<NASGU>
                summaryLines = string(obj.SummaryTextArea.Value);
                for idx = 1:numel(summaryLines)
                    fprintf(fid, '%s\n', char(summaryLines(idx)));
                end
            end

            obj.StatusLabel.Text = ...
                sprintf('结果已导出到: %s', outputDir);
        end
    end
end

function addLabel(obj, row, column, textValue)
    label = uilabel(obj.ControlGrid);
    label.Text = textValue;
    label.HorizontalAlignment = 'right';
    label.Layout.Row = row;
    label.Layout.Column = column;
end

function field = addNumeric(obj, row, column, value)
    field = uieditfield(obj.ControlGrid, 'numeric');
    field.Layout.Row = row;
    field.Layout.Column = column;
    field.Value = value;
end
