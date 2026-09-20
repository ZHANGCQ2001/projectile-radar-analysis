classdef RadarControlMachineApp < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure           matlab.ui.Figure
        NextButton         matlab.ui.control.Button
        PrevButton         matlab.ui.control.Button
        PlayButton         matlab.ui.control.StateButton
        FrameLabel         matlab.ui.control.Label
        SettingsBtn        matlab.ui.control.Button
        ApproxSpeedEdit_2  matlab.ui.control.NumericEditField
        Label_5            matlab.ui.control.Label
        TargetRangeEdit    matlab.ui.control.NumericEditField
        Label_7            matlab.ui.control.Label
        PerpDistanceEdit   matlab.ui.control.NumericEditField
        Label_6            matlab.ui.control.Label
        FrameSlider        matlab.ui.control.Slider
        LogTextArea        matlab.ui.control.TextArea
        StopButton         matlab.ui.control.Button
        ProcessButton      matlab.ui.control.Button
        StartButton        matlab.ui.control.Button
        FPGAButton         matlab.ui.control.Button
        JSONPathEditField  matlab.ui.control.EditField
        Label_4            matlab.ui.control.Label
        CLIPathEditField   matlab.ui.control.EditField
        Label_3            matlab.ui.control.Label
        Label_2            matlab.ui.control.Label
        UnwrapBtn          matlab.ui.control.Button
        ApproxSpeedEdit    matlab.ui.control.NumericEditField
        Label              matlab.ui.control.Label
        ViewDropDown       matlab.ui.control.DropDown
        LoadBtn            matlab.ui.control.Button
        DataPathEdit       matlab.ui.control.EditField
        DataPathBrowseButton  matlab.ui.control.Button
        CLIPathBrowseButton   matlab.ui.control.Button
        JSONPathBrowseButton  matlab.ui.control.Button
        UIAxes_RD_Real     matlab.ui.control.UIAxes
        RawRxDropDown      matlab.ui.control.DropDown
        RawRxLabel         matlab.ui.control.Label
        RawChirpSpinner    matlab.ui.control.Spinner
        RawChirpLabel      matlab.ui.control.Label
        RawWaveformModeDropDown  matlab.ui.control.DropDown
        RawWaveformModeLabel     matlab.ui.control.Label
        UIAxes_RawADCWaveform  matlab.ui.control.UIAxes
        UIAxes_RawADCHeatmap   matlab.ui.control.UIAxes
        FFT1DRxDropDown  matlab.ui.control.DropDown
        FFT1DRxLabel     matlab.ui.control.Label
        FFT1DChirpSpinner  matlab.ui.control.Spinner
        FFT1DChirpLabel    matlab.ui.control.Label
        UIAxes_FFT1DLine     matlab.ui.control.UIAxes
        UIAxes_FFT1DHeatmap  matlab.ui.control.UIAxes
        FitConfirmButton   matlab.ui.control.Button
        FitEndEdit         matlab.ui.control.NumericEditField
        FitEndLabel        matlab.ui.control.Label
        FitStartEdit       matlab.ui.control.NumericEditField
        FitStartLabel      matlab.ui.control.Label
        UIAxes_FitVelocity matlab.ui.control.UIAxes
        UIAxes_FitRange    matlab.ui.control.UIAxes
        UIAxes_TrendVelocity  matlab.ui.control.UIAxes
        UIAxes_PC          matlab.ui.control.UIAxes
        UIAxes_RD          matlab.ui.control.UIAxes
    end

    
    properties (Access = private)
        % 雷达参数与文件指针
        paramsConfig
        numFrames
        numUint16Samples_perFrame
        calib3D
        fp % 二进制文件指针
        
        % 物理与算法坐标轴
        cfar_kernel
        winR
        winD
        offset_dB = 20; % CFAR灵敏度
        rangeAxis
        angleAxis
        delta_v
        
        % 画图句柄
        hImg_RD
        hImg_RawADC
        hRawAdcChirpMarker
        hRawAdcIWaveform
        hRawAdcQWaveform
        hImg_FFT1D
        hFFT1DChirpMarker
        hFFT1DLine
        hColorbar_RawADC
        hColorbar_FFT1D
        hLegend_RawADC

        % 雷达参数配置
        cfg_StartFreqGHz = 77;  % 起始频率 GHz
        cfg_Slope = 60.01;      % 调频斜率 MHz/us
        cfg_Samples = 64;       % 距离维采样点
        cfg_Chirps = 256;       % 速度维Chirp数
        cfg_AdcSampleRate = 10; % ADC采样率 Msps
        cfg_ChirpPeriodUs = 12; % Chirp重复周期 us
        cfg_NumTx = 1;          % 发射通道数
        cfg_NumRx = 8;          % 接收通道数
        cfg_RangeFftSize = 256; % 距离FFT点数
        cfg_AngleFftSize = 256; % 角度FFT点数
        
        % CFAR 动态配置参数
        cfg_Tr = 8;
        cfg_Td = 4;
        cfg_Gr = 3;
        cfg_Gd = 2;
        cfg_MaxSnrRangeMin = 0;
        cfg_MaxSnrRangeMax = 25;
        cfg_MaxSnrVelocityMin = -60;
        cfg_MaxSnrVelocityMax = 60;
        cfg_offset_dB = 20;     % CFAR 阈值

        % 播放状态控制
        isPlaying = false;

        

        % 数据处理子窗口
        processingWindow% 采集保存配置
        cfg_CaptureSizeMB = 800;
        captureOutputDir
        runtimeJsonPath
        jsonTemplatePath
        isDcaRecording = false;
        currentCaptureFilePrefix
        stopCaptureRequested = false;

        hImg_RD_Real     % 物理坐标热力图句柄
        hPhysicalMaxSnrMarker
        vel_axis         % 物理速度轴坐标

        % 滑动窗口配置
        cfg_WinSize = 256;      % 滑动窗口大小(Chirp数，默认处理整帧)
        cfg_WinStep = 256;      % 滑动步进(Chirp数，默认不重叠)
        windows_per_frame = 1;  % 内部计算用：每物理帧包含的滑窗数量

        current_rd_db_shifted;

        % 全局滑窗最大 SNR 统计
        trendWindowIdx
        trendRange
        trendVelocity
        trendSnr
        lastTrendLogWindowIdx = NaN
        lastPhysicalMaxSnrLogWindowIdx = NaN
    end
    
    methods (Access = private)
        
        function appRoot = getAppRoot(app)
            if isdeployed
                appRoot = ctfroot;
            else
                appFile = mfilename('fullpath');
                appRoot = fileparts(appFile);
            end
        end

        function cliPath = getBundledCliPath(app)
            cliPath = fullfile(getAppRoot(app), 'third_party', 'ti_postproc');
            if isfolder(cliPath)
                return;
            end

            matches = dir(fullfile(getAppRoot(app), '**', 'DCA1000EVM_CLI_Control.exe'));
            if ~isempty(matches)
                cliPath = matches(1).folder;
            end
        end

        function jsonPath = getBundledJsonPath(app)
            jsonPath = fullfile(getBundledCliPath(app), 'AM273X_Capture.json');
            if isfile(jsonPath)
                return;
            end

            matches = dir(fullfile(getAppRoot(app), '**', 'AM273X_Capture.json'));
            if ~isempty(matches)
                jsonPath = fullfile(matches(1).folder, matches(1).name);
            end
        end

        function jsonPath = getSelectedJsonTemplatePath(app)
            if ~isempty(app.jsonTemplatePath) && isfile(app.jsonTemplatePath)
                jsonPath = app.jsonTemplatePath;
                return;
            end

            jsonPath = '';
            try
                candidate = app.JSONPathEditField.Value;
                if isfile(candidate)
                    jsonPath = candidate;
                    app.jsonTemplatePath = candidate;
                    return;
                end
            catch
            end

            jsonPath = getBundledJsonPath(app);
            app.jsonTemplatePath = jsonPath;
        end

        function calibPath = getBundledCalibrationPath(app)
            calibPath = fullfile(getAppRoot(app), 'data', 'channelCalibration_MRR.mat');
        end

        function baseDir = getWritableAppDataDir(app)
            baseDir = getenv('LOCALAPPDATA');
            if isempty(baseDir)
                baseDir = fullfile(char(java.lang.System.getProperty('user.home')), 'AppData', 'Local');
            end
            baseDir = fullfile(baseDir, 'RadarControlMachine');
            if ~isfolder(baseDir)
                mkdir(baseDir);
            end
        end

        % function outputDir = getCaptureOutputDir(app)
        %     if isempty(app.captureOutputDir)
        %         if isdeployed
        %             app.captureOutputDir = fullfile(getWritableAppDataDir(app), 'capture_data');
        %         else
        %             app.captureOutputDir = fullfile(getAppRoot(app), 'capture_data');
        %         end
        %     end
        %     outputDir = app.captureOutputDir;
        %     if ~isfolder(outputDir)
        %         mkdir(outputDir);
        %     end
        % end
        function outputDir = getCaptureOutputDir(app)
            % 默认采集数据保存目录
            if isempty(app.captureOutputDir)
                app.captureOutputDir = 'C:\CaptureData';
            end
        
            outputDir = app.captureOutputDir;
        
            % 文件夹不存在时自动创建
            if ~isfolder(outputDir)
                [success, message] = mkdir(outputDir);
        
                if ~success
                    error('无法创建采集数据目录：%s\n原因：%s', ...
                        outputDir, message);
                end
            end
        end

        function jsonPath = getRuntimeJsonPath(app)
            if isempty(app.runtimeJsonPath)
                configDir = '';
                try
                    if isfolder(app.CLIPathEditField.Value)
                        configDir = app.CLIPathEditField.Value;
                    end
                catch
                end

                if isempty(configDir)
                    if isdeployed
                        configDir = getBundledCliPath(app);
                    else
                        configDir = fullfile(getAppRoot(app), 'runtime_config');
                    end
                end

                if ~isfolder(configDir)
                    mkdir(configDir);
                end
                app.runtimeJsonPath = fullfile(configDir, 'AM273X_Capture_runtime.json');
            end
            jsonPath = app.runtimeJsonPath;
        end

        function prefix = makeTimestampedPrefix(app, basePrefix)
            if nargin < 2 || isempty(basePrefix)
                basePrefix = 'capture_';
            end
            basePrefix = regexprep(char(basePrefix), '\d{8}_\d{6}_?$', '');
            if ~endsWith(basePrefix, '_')
                basePrefix = [basePrefix '_'];
            end
            prefix = [basePrefix datestr(now, 'yyyymmdd_HHMMSS')];
        end

        function jsonPath = prepareCaptureJson(app, updateDataPath, refreshFilePrefix)
            if nargin < 2
                updateDataPath = true;
            end
            if nargin < 3
                refreshFilePrefix = false;
            end

            templatePath = getSelectedJsonTemplatePath(app);
            jsonPath = getRuntimeJsonPath(app);
            if ~isfile(templatePath)
                error('找不到模板 JSON: %s', templatePath);
            end

            cfg = jsondecode(fileread(templatePath));
            outputDir = getCaptureOutputDir(app);
            captureCfg = cfg.DCA1000Config.captureConfig;
            captureCfg.fileBasePath = outputDir;
            % captureCfg.captureStopMode = 'bytes';
            captureCfg.captureStopMode = 'infinite';
            captureCfg.bytesToCapture = uint64(round(app.cfg_CaptureSizeMB * 1000000));
            if refreshFilePrefix || isempty(app.currentCaptureFilePrefix)
                if refreshFilePrefix
                    app.currentCaptureFilePrefix = makeTimestampedPrefix(app, captureCfg.filePrefix);
                else
                    app.currentCaptureFilePrefix = captureCfg.filePrefix;
                end
            end
            captureCfg.filePrefix = app.currentCaptureFilePrefix;
            cfg.DCA1000Config.captureConfig = captureCfg;

            jsonText = jsonencode(cfg, 'PrettyPrint', true);
            bytesText = ['"bytesToCapture": ' num2str(captureCfg.bytesToCapture)];
            jsonText = regexprep(jsonText, '"bytesToCapture"\s*:\s*[-+]?\d+(\.\d+)?([eE][-+]?\d+)?', bytesText);

            fid = fopen(jsonPath, 'w');
            if fid < 0
                error('无法写入运行时 JSON: %s', jsonPath);
            end
            cleaner = onCleanup(@() fclose(fid));
            fwrite(fid, jsonText, 'char');

            if updateDataPath
                app.DataPathEdit.Value = fullfile(outputDir, [captureCfg.filePrefix '_Raw_0.bin']);
            end
        end

        function initializeBundledPaths(app)
            cliPath = getBundledCliPath(app);
            if isfolder(cliPath)
                app.CLIPathEditField.Value = cliPath;
            end
            app.jsonTemplatePath = getBundledJsonPath(app);
            if isfile(app.jsonTemplatePath)
                app.JSONPathEditField.Value = app.jsonTemplatePath;
            end
            prepareCaptureJson(app);
        end

        function fileName = getJsonFileName(app, jsonPath)
            [~, name, ext] = fileparts(jsonPath);
            fileName = [name ext];
        end

        function [status, cmdout] = runDcaCli(app, cliPath, exeName, action, jsonArg, runAsync)
            if nargin < 6
                runAsync = false;
            end
            exePath = fullfile(cliPath, exeName);
            if runAsync
                cmd = sprintf('start /B "" /D "%s" "%s" %s "%s"', cliPath, exePath, action, jsonArg);
            else
                cmd = sprintf('cd /d "%s" && "%s" %s "%s"', cliPath, exePath, action, jsonArg);
            end
            [status, cmdout] = system(cmd);
        end

        function stopDcaRecordQuietly(app, cliPath, jsonArg)
            runDcaCli(app, cliPath, ...
                'DCA1000EVM_CLI_Control.exe', ...
                'stop_record', jsonArg, false);
        
            app.isDcaRecording = false;
            pause(0.2);
        end

        function totalBytes = getCurrentCaptureBytes(app)
            totalBytes = 0;
            if isempty(app.currentCaptureFilePrefix)
                return;
            end

            outputDir = getCaptureOutputDir(app);
            files = dir(fullfile(outputDir, [app.currentCaptureFilePrefix '_Raw_*.bin']));
            if isempty(files)
                return;
            end
            totalBytes = sum([files.bytes]);
        end

        function [status, cmdout] = stopDcaRecord(app, cliPath, jsonArg)
            [status, cmdout] = runDcaCli(app, cliPath, ...
                'DCA1000EVM_CLI_Control.exe', ...
                'stop_record', jsonArg, false);
        
            app.isDcaRecording = false;
            pause(0.5);
        end

        function numSamples = getProcessingSamples(app)
            % 距离维实际处理点数为界面/固件 ADC 采样点数的 2 倍。
            numSamples = app.cfg_Samples;
        end

        function [rd_db, frame_idx, sub_idx] = computeWindowRd(app, w_idx)
            rd_db = [];
            frame_idx = [];
            sub_idx = [];
            if isempty(app.fp), return; end
            
            % 1. 核心数学：把滑窗序号还原为物理帧位置和帧内偏移
            frame_idx = floor((w_idx - 1) / app.windows_per_frame) + 1;
            sub_idx = mod(w_idx - 1, app.windows_per_frame);
            chirp_offset = sub_idx * app.cfg_WinStep;
            numRangeSamples = getProcessingSamples(app);
            
            % 2. 计算并跳转到精确的文件偏移位置
            bytes_per_frame = app.numUint16Samples_perFrame * 2;
            bytes_per_chirp = numRangeSamples * app.cfg_NumRx * 4; % 每个复数占4字节
            offset = (frame_idx - 1) * bytes_per_frame + chirp_offset * bytes_per_chirp;
            fseek(app.fp, offset, 'bof');
            
            % 3. 读取当前窗口所需的数据
            num_samples_to_read = numRangeSamples * app.cfg_NumRx * app.cfg_WinSize * 2; % uint16个数
            dataChunk = fread(app.fp, num_samples_to_read, 'uint16', 'l');
            if isempty(dataChunk) || length(dataChunk) < num_samples_to_read, return; end
            
            % 4. 数据重组
            dataChunk = dataChunk - (dataChunk >= 2^15) * 2^16;
            adcOut = dataChunk(1:2:end) + 1i*dataChunk(2:2:end);
            adcOut = reshape(adcOut, numRangeSamples, app.cfg_NumRx, app.cfg_WinSize);
            adcOutFrame = permute(adcOut, [1 3 2]);
            
            for rx = 1:app.cfg_NumRx
                adcOutFrame(:,:,rx) = medfilt1(real(adcOutFrame(:,:,rx)), 3, [], 2) + ...
                                      1i * medfilt1(imag(adcOutFrame(:,:,rx)), 3, [], 2);
            end

            % idx = abs(real(adcOutFrame)) > 1200 | abs(imag(adcOutFrame)) > 1200;
            % adcOutFrame(idx) = 0;
            adcOutFrame = adcOutFrame - mean(adcOutFrame, 2);
            
            % 5. FFT处理
            rangeProfile = fft(adcOutFrame .* hann(numRangeSamples), app.cfg_RangeFftSize, 1);
            % 0601 
            rangeDoppler = fft(rangeProfile .* hann(app.cfg_WinSize)', [], 2);
            % rd_3D = fftshift(fft(rangeDoppler ./ app.calib3D, app.cfg_AngleFftSize, 3), 3);
            rd_3D = sum(abs(rangeDoppler ./ app.calib3D), 3);
            rangeDoppler_NCI = max(abs(rd_3D), [], 3);
            rd_db = 20*log10(rangeDoppler_NCI + 1e-6);
        end

        function [adcOutFrame, frame_idx, sub_idx] = computeWindowRawAdc(app, w_idx)
            adcOutFrame = [];
            frame_idx = [];
            sub_idx = [];
            if isempty(app.fp), return; end

            frame_idx = floor((w_idx - 1) / app.windows_per_frame) + 1;
            sub_idx = mod(w_idx - 1, app.windows_per_frame);
            chirp_offset = sub_idx * app.cfg_WinStep;
            numRangeSamples = getProcessingSamples(app);

            bytes_per_frame = app.numUint16Samples_perFrame * 2;
            bytes_per_chirp = numRangeSamples * app.cfg_NumRx * 4;
            offset = (frame_idx - 1) * bytes_per_frame + chirp_offset * bytes_per_chirp;
            fseek(app.fp, offset, 'bof');

            num_samples_to_read = numRangeSamples * app.cfg_NumRx * app.cfg_WinSize * 2;
            dataChunk = fread(app.fp, num_samples_to_read, 'uint16', 'l');
            if isempty(dataChunk) || length(dataChunk) < num_samples_to_read, return; end

            dataChunk = dataChunk - (dataChunk >= 2^15) * 2^16;
            adcOut = dataChunk(1:2:end) + 1i*dataChunk(2:2:end);
            adcOut = reshape(adcOut, numRangeSamples, app.cfg_NumRx, app.cfg_WinSize);
            adcOutFrame = permute(adcOut, [1 3 2]);
            % idx = abs(real(adcOutFrame)) > 1000 | abs(imag(adcOutFrame)) > 1000;
            % adcOutFrame(idx) = 0;
        end

        function [rangeFftFrame, frame_idx, sub_idx] = computeWindowRangeFft(app, w_idx)
            rangeFftFrame = [];
            [adcOutFrame, frame_idx, sub_idx] = computeWindowRawAdc(app, w_idx);
            if isempty(adcOutFrame)
                return;
            end

            numRangeSamples = size(adcOutFrame, 1);
            rangeWindow = hann(numRangeSamples);
            rangeFftFrame = fft(adcOutFrame .* rangeWindow, app.cfg_RangeFftSize, 1);
        end

        function [maxSnr, targetRange, targetVelocity] = findMaxSnrPoint(app, rd_db)
            if isempty(rd_db)
                maxSnr = NaN;
                targetRange = NaN;
                targetVelocity = NaN;
                return;
            end
            [maxSnr, targetRange, targetVelocity] = findMaxSnrPointInShiftedRd(app, fftshift(rd_db, 2));
        end

        function [maxSnr, targetRange, targetVelocity, rIdx, dIdx, noiseFloor] = findMaxSnrPointInShiftedRd(app, rd_shifted)
            maxSnr = NaN;
            targetRange = NaN;
            targetVelocity = NaN;
            rIdx = NaN;
            dIdx = NaN;
            noiseFloor = [];
            if isempty(rd_shifted), return; end

            noiseFloor = conv2(rd_shifted, app.cfar_kernel, 'same');
            snrMap = rd_shifted - noiseFloor;

            edgeR = max(1, app.cfg_Tr + app.cfg_Gr + 1);
            edgeD = max(1, app.cfg_Td + app.cfg_Gd + 1);
            [numRangeBins, numDopplerBins] = size(snrMap);
            snrMap(1:min(edgeR, numRangeBins), :) = -Inf;
            snrMap(max(1, numRangeBins-edgeR+1):numRangeBins, :) = -Inf;
            snrMap(:, 1:min(edgeD, numDopplerBins)) = -Inf;
            snrMap(:, max(1, numDopplerBins-edgeD+1):numDopplerBins) = -Inf;

            if numel(app.rangeAxis) == numRangeBins
                rangeMin = min(app.cfg_MaxSnrRangeMin, app.cfg_MaxSnrRangeMax);
                rangeMax = max(app.cfg_MaxSnrRangeMin, app.cfg_MaxSnrRangeMax);
                rangeMask = app.rangeAxis(:) >= rangeMin & app.rangeAxis(:) <= rangeMax;
                snrMap(~rangeMask, :) = -Inf;
            end

            if numel(app.vel_axis) == numDopplerBins
                velocityMin = min(app.cfg_MaxSnrVelocityMin, app.cfg_MaxSnrVelocityMax);
                velocityMax = max(app.cfg_MaxSnrVelocityMin, app.cfg_MaxSnrVelocityMax);
                % Gate the aliased velocity axis shown in the physical RD plot.
                velocityMask = app.vel_axis(:).' >= velocityMin & app.vel_axis(:).' <= velocityMax;
                snrMap(:, ~velocityMask) = -Inf;
            end

            [maxSnr, linearIdx] = max(snrMap(:));
            if ~isfinite(maxSnr), return; end

            [rIdx, dIdx] = ind2sub(size(snrMap), linearIdx);
            targetRange = app.rangeAxis(rIdx);
            targetVelocity = app.vel_axis(dIdx);
        end

        function precomputeWindowTrends(app, total_windows)
            app.trendWindowIdx = 1:total_windows;
            app.trendRange = NaN(1, total_windows);
            app.trendVelocity = NaN(1, total_windows);
            app.trendSnr = NaN(1, total_windows);
            app.lastTrendLogWindowIdx = NaN;

            progressDlg = uiprogressdlg(app.UIFigure, ...
                'Title', '正在计算', ...
                'Message', '正在全局计算滑窗 RD 最大 SNR 点...', ...
                'Indeterminate', 'off', ...
                'Cancelable', 'off');
            cleanupObj = onCleanup(@() close(progressDlg));
            updateStep = max(1, floor(total_windows / 100));

            for w = 1:total_windows
                rd_db = computeWindowRd(app, w);
                if ~isempty(rd_db)
                    [app.trendSnr(w), app.trendRange(w), app.trendVelocity(w)] = findMaxSnrPoint(app, rd_db);
                end

                if w == 1 || w == total_windows || mod(w, updateStep) == 0
                    progressDlg.Value = w / total_windows;
                    progressDlg.Message = sprintf('正在计算滑窗 %d / %d', w, total_windows);
                    drawnow limitrate;
                end
            end

            clear cleanupObj;
        end

        function clearTrendCache(app)
            app.trendWindowIdx = [];
            app.trendRange = [];
            app.trendVelocity = [];
            app.trendSnr = [];
            app.lastTrendLogWindowIdx = NaN;
        end

        function logCurrentTrendPoint(app, currentIdx)
            if isempty(app.trendWindowIdx)
                return;
            end
            currentIdx = round(currentIdx);
            if currentIdx < 1 || currentIdx > numel(app.trendWindowIdx)
                return;
            end
            if isequal(app.lastTrendLogWindowIdx, currentIdx)
                return;
            end

            targetRange = app.trendRange(currentIdx);
            targetVelocity = app.trendVelocity(currentIdx);
            targetSnr = app.trendSnr(currentIdx);
            if ~isfinite(targetRange) || ~isfinite(targetVelocity) || ~isfinite(targetSnr)
                app.LogTextArea.Value = [app.LogTextArea.Value; {sprintf('[最大SNR] 窗口 %d: 无有效目标点。', currentIdx)}];
            else
                app.LogTextArea.Value = [app.LogTextArea.Value; {sprintf('[最大SNR] 窗口 %d: 距离 %.3f m，径向速度 %.3f m/s，SNR %.2f dB', currentIdx, targetRange, targetVelocity, targetSnr)}];
            end
            app.lastTrendLogWindowIdx = currentIdx;
            scroll(app.LogTextArea, 'bottom');

        end

        function [signedTargetSpeed, ok] = calculateSingleTargetUnwrappedSpeed(app, radarRange, wrappedRadialVelocity)
            signedTargetSpeed = NaN;
            ok = false;

            v_approx = app.ApproxSpeedEdit.Value;
            perpDistance = abs(app.PerpDistanceEdit.Value);
            v_max = (app.cfg_WinSize / 2) * app.delta_v;

            if isempty(v_max) || ~isfinite(v_max) || v_max <= 0
                return;
            end
            if ~isfinite(radarRange) || ~isfinite(wrappedRadialVelocity) || radarRange <= 0 || perpDistance >= radarRange
                return;
            end

            radialProjection = sqrt(radarRange^2 - perpDistance^2) / radarRange;
            if radialProjection <= eps
                return;
            end

            approxRadialSpeedAbs = abs(v_approx) * radialProjection;
            maxWrap = ceil((approxRadialSpeedAbs + 4 * v_max) / (2 * v_max)) + 3;
            wrapCandidates = -maxWrap:maxWrap;
            radialCandidates = wrappedRadialVelocity + wrapCandidates * (2 * v_max);
            signedTargetSpeedCandidates = radialCandidates / radialProjection;
            [~, bestIdx] = min(abs(signedTargetSpeedCandidates - v_approx));
            targetSpeed = abs(radialCandidates(bestIdx)) / radialProjection;

            if v_approx == 0
                signedTargetSpeed = 0;
            else
                signedTargetSpeed = sign(v_approx) * targetSpeed;
            end
            ok = true;
        end

        function refreshTrendPlot(app, currentIdx)
            cla(app.UIAxes_PC);
            cla(app.UIAxes_TrendVelocity);
            if isempty(app.trendWindowIdx)
                return;
            end
            if nargin < 2 || isempty(currentIdx)
                currentIdx = NaN;
            end

            validRange = isfinite(app.trendRange);
            validVelocity = isfinite(app.trendVelocity);

            plot(app.UIAxes_PC, app.trendWindowIdx(validRange), app.trendRange(validRange), ...
                '-o', 'LineWidth', 1.2, 'MarkerSize', 3, 'Color', [0 0.4470 0.7410]);
            title(app.UIAxes_PC, '最大 SNR 点距离趋势');
            xlabel(app.UIAxes_PC, 'Window Index');
            ylabel(app.UIAxes_PC, 'Range (m)');
            grid(app.UIAxes_PC, 'on');

            if numel(app.trendWindowIdx) > 1
                app.UIAxes_PC.XLim = [1, numel(app.trendWindowIdx)];
                app.UIAxes_TrendVelocity.XLim = [1, numel(app.trendWindowIdx)];
            else
                app.UIAxes_PC.XLim = [0.5, 1.5];
                app.UIAxes_TrendVelocity.XLim = [0.5, 1.5];
            end
            app.UIAxes_PC.XTickMode = 'auto';
            app.UIAxes_PC.YTickMode = 'auto';
            app.UIAxes_PC.XTickLabelMode = 'auto';
            app.UIAxes_PC.YTickLabelMode = 'auto';

            plot(app.UIAxes_TrendVelocity, app.trendWindowIdx(validVelocity), app.trendVelocity(validVelocity), ...
                '-s', 'LineWidth', 1.2, 'MarkerSize', 3, 'Color', [0.8500 0.3250 0.0980]);
            title(app.UIAxes_TrendVelocity, '最大 SNR 点速度趋势');
            xlabel(app.UIAxes_TrendVelocity, 'Window Index');
            ylabel(app.UIAxes_TrendVelocity, 'Aliased Velocity (m/s)');
            app.UIAxes_TrendVelocity.XTickMode = 'auto';
            app.UIAxes_TrendVelocity.YTickMode = 'auto';
            app.UIAxes_TrendVelocity.XTickLabelMode = 'auto';
            app.UIAxes_TrendVelocity.YTickLabelMode = 'auto';
            grid(app.UIAxes_TrendVelocity, 'on');

            if isfinite(currentIdx)
                xline(app.UIAxes_PC, currentIdx, 'k--', 'LineWidth', 1);
                xline(app.UIAxes_TrendVelocity, currentIdx, 'k--', 'LineWidth', 1);
            end
        end

        function resetFitPlot(app)
            cla(app.UIAxes_FitRange);
            cla(app.UIAxes_FitVelocity);

            title(app.UIAxes_FitRange, '拟合距离趋势');
            xlabel(app.UIAxes_FitRange, 'Frame Index');
            ylabel(app.UIAxes_FitRange, 'Range (m)');
            ylim(app.UIAxes_FitRange, [-2 25]);
            grid(app.UIAxes_FitRange, 'on');

            title(app.UIAxes_FitVelocity, '解模糊后速度趋势');
            xlabel(app.UIAxes_FitVelocity, 'Frame Index');
            ylabel(app.UIAxes_FitVelocity, 'Unwrapped Velocity (m/s)');
            grid(app.UIAxes_FitVelocity, 'on');
        end

        function FitConfirmButtonPushed(app, event)
            if isempty(app.trendWindowIdx)
                uialert(app.UIFigure, '请先加载数据并完成最大 SNR 趋势统计。', '拟合失败');
                return;
            end

            startFrame = round(app.FitStartEdit.Value);
            endFrame = round(app.FitEndEdit.Value);
            if startFrame > endFrame
                uialert(app.UIFigure, '拟合起始帧不能大于终点帧。', '拟合失败');
                return;
            end
            if startFrame < 1 || endFrame > app.numFrames
                uialert(app.UIFigure, sprintf('拟合帧范围必须在 1~%d 之间。', app.numFrames), '拟合失败');
                return;
            end
            expectedTotalWindows = app.numFrames * app.windows_per_frame;
            if numel(app.trendWindowIdx) ~= expectedTotalWindows
                uialert(app.UIFigure, sprintf(['当前最大 SNR 趋势缓存与滑窗参数不一致。\n' ...
                    '当前配置每帧应有 %d 个滑窗，总计 %d 个滑窗。\n' ...
                    '请重新点击【加载文件】，让窗口大小/滑动步进重新生效。'], ...
                    app.windows_per_frame, expectedTotalWindows), '拟合失败');
                return;
            end

            trendFrameIdx = floor((app.trendWindowIdx - 1) / app.windows_per_frame) + 1;
            trendSubIdx = mod(app.trendWindowIdx - 1, app.windows_per_frame);
            if app.windows_per_frame > 1
                chirpCenterOffset = trendSubIdx * app.cfg_WinStep + (app.cfg_WinSize - 1) / 2;
                frameCenterOffset = (app.cfg_Chirps - 1) / 2;
                trendFrameAxis = trendFrameIdx + (chirpCenterOffset - frameCenterOffset) / app.cfg_Chirps;
            else
                trendFrameAxis = trendFrameIdx;
            end
            selected = trendFrameIdx >= startFrame & trendFrameIdx <= endFrame & ...
                isfinite(app.trendRange) & isfinite(app.trendVelocity) & isfinite(app.trendSnr);

            fitX = trendFrameAxis(selected);
            fitRange = app.trendRange(selected);
            fitVelocity = app.trendVelocity(selected);
            if numel(fitX) < 2
                uialert(app.UIFigure, '选定帧范围内有效滑窗点不足，至少需要 2 个有效点。', '拟合失败');
                return;
            end
            if numel(unique(fitX)) < 2
                uialert(app.UIFigure, '选定帧范围内横坐标变化不足，无法拟合。请扩大帧范围或减小滑窗步进。', '拟合失败');
                return;
            end

            v_approx = app.ApproxSpeedEdit.Value;
            perpDistance = abs(app.PerpDistanceEdit.Value);
            v_max = (app.cfg_WinSize / 2) * app.delta_v;
            if isempty(v_max) || ~isfinite(v_max) || v_max <= 0
                uialert(app.UIFigure, '请先加载数据，使速度轴参数生效。', '拟合失败');
                return;
            end

            rangeFitDegree = min(2, numel(unique(fitX)) - 1);
            rangeCoeff = polyfit(fitX, fitRange, rangeFitDegree);
            drawX = linspace(min(fitX), max(fitX), 200);
            drawRange = polyval(rangeCoeff, drawX);
            sampleFitRange = polyval(rangeCoeff, fitX);

            [sampleUnwrappedVelocity, validSampleUnwrap] = unwrapVelocityWithRange(fitVelocity, sampleFitRange);
            if nnz(validSampleUnwrap) < 2 || numel(unique(fitX(validSampleUnwrap))) < 2
                uialert(app.UIFigure, '选定范围内可解模糊速度点不足，至少需要 2 个点。', '拟合失败');
                return;
            end

            velocityFitDegree = min(2, numel(unique(fitX(validSampleUnwrap))) - 1);
            velocityCoeff = polyfit(fitX(validSampleUnwrap), sampleUnwrappedVelocity(validSampleUnwrap), velocityFitDegree);
            drawUnwrappedVelocity = polyval(velocityCoeff, drawX);
            validDrawVelocity = isfinite(drawUnwrappedVelocity);

            rangeY = [fitRange(:); drawRange(:)];
            rangeY = rangeY(isfinite(rangeY));
            if isempty(rangeY)
                uialert(app.UIFigure, '选定范围内没有有效距离点。', '拟合失败');
                return;
            end
            rangePad = max(0.5, 0.08 * range(rangeY));
            if range(rangeY) < eps
                rangePad = 0.5;
            end
            velocityY = [sampleUnwrappedVelocity(validSampleUnwrap).'; drawUnwrappedVelocity(:)];
            velocityY = velocityY(isfinite(velocityY));
            velocityPad = max(5, 0.08 * range(velocityY));
            if isempty(velocityY) || range(velocityY) < eps
                velocityPad = 5;
            end

            cla(app.UIAxes_FitRange);
            plot(app.UIAxes_FitRange, fitX, fitRange, 'o', ...
                'MarkerSize', 4, 'LineWidth', 1, 'Color', [0 0.4470 0.7410]);
            hold(app.UIAxes_FitRange, 'on');
            plot(app.UIAxes_FitRange, drawX, drawRange, '-', ...
                'LineWidth', 1.6, 'Color', [0 0.4470 0.7410]);
            hold(app.UIAxes_FitRange, 'off');
            title(app.UIAxes_FitRange, '拟合距离趋势');
            xlabel(app.UIAxes_FitRange, 'Frame Index');
            ylabel(app.UIAxes_FitRange, 'Range (m)');
            if min(fitX) == max(fitX)
                xlim(app.UIAxes_FitRange, [min(fitX)-0.5 max(fitX)+0.5]);
            else
                xlim(app.UIAxes_FitRange, [min(fitX) max(fitX)]);
            end
            ylim(app.UIAxes_FitRange, [min(rangeY)-rangePad max(rangeY)+rangePad]);
            grid(app.UIAxes_FitRange, 'on');

            cla(app.UIAxes_FitVelocity);
            % sampleUnwrappedVelocity = -(sampleUnwrappedVelocity + 60);
            % drawUnwrappedVelocity = -(drawUnwrappedVelocity + 60);
            plot(app.UIAxes_FitVelocity, fitX(validSampleUnwrap), sampleUnwrappedVelocity(validSampleUnwrap), 's', ...
                'MarkerSize', 4, 'LineWidth', 1, 'Color', [0.8500 0.3250 0.0980]);
            hold(app.UIAxes_FitVelocity, 'on');
            plot(app.UIAxes_FitVelocity, drawX(validDrawVelocity), drawUnwrappedVelocity(validDrawVelocity), '-', ...
                'LineWidth', 1.6, 'Color', [0.8500 0.3250 0.0980]);
            hold(app.UIAxes_FitVelocity, 'off');
            title(app.UIAxes_FitVelocity, '解模糊后速度趋势');
            xlabel(app.UIAxes_FitVelocity, 'Frame Index');
            ylabel(app.UIAxes_FitVelocity, 'Unwrapped Velocity (m/s)');
            if min(fitX) == max(fitX)
                xlim(app.UIAxes_FitVelocity, [min(fitX)-0.5 max(fitX)+0.5]);
            else
                xlim(app.UIAxes_FitVelocity, [min(fitX) max(fitX)]);
            end
            ylim(app.UIAxes_FitVelocity, [min(velocityY)-velocityPad max(velocityY)+velocityPad]);
            grid(app.UIAxes_FitVelocity, 'on');

            app.LogTextArea.Value = [app.LogTextArea.Value; ...
                {sprintf('[拟合] 已根据帧 %d~%d 内 %d 个有效滑窗点拟合距离，并根据 %d 个解模糊速度点拟合速度。', startFrame, endFrame, numel(fitX), nnz(validSampleUnwrap))}];
            app.LogTextArea.Value = [app.LogTextArea.Value; ...
                {sprintf('[拟合解模糊] 速度符号按大致速度 %.2f m/s 约束，拟合范围仅限当前选择帧。', v_approx)}];
            scroll(app.LogTextArea, 'bottom');

            function [unwrappedVelocity, validUnwrap] = unwrapVelocityWithRange(wrappedVelocity, fittedRange)
                unwrappedVelocity = NaN(size(wrappedVelocity));
                validUnwrap = isfinite(wrappedVelocity) & isfinite(fittedRange) & abs(fittedRange) > eps;
                for idx = find(validUnwrap)
                    radarRange = abs(fittedRange(idx));
                    if perpDistance >= radarRange
                        validUnwrap(idx) = false;
                        continue;
                    end

                    radialProjection = sqrt(radarRange^2 - perpDistance^2) / radarRange;
                    if radialProjection <= eps
                        validUnwrap(idx) = false;
                        continue;
                    end

                    approxSpeedSign = sign(v_approx);
                    if approxSpeedSign == 0
                        approxSpeedSign = 1;
                    end
                    effectiveApproxSpeed = approxSpeedSign * abs(v_approx);
                    approxRadialSpeedAbs = abs(effectiveApproxSpeed) * radialProjection;
                    maxWrap = ceil((approxRadialSpeedAbs + 4 * v_max) / (2 * v_max)) + 3;
                    wrapCandidates = -maxWrap:maxWrap;
                    radialCandidates = wrappedVelocity(idx) + wrapCandidates * (2 * v_max);
                    signedTargetSpeedCandidates = radialCandidates / radialProjection;
                    [~, bestIdx] = min(abs(signedTargetSpeedCandidates - effectiveApproxSpeed));
                    targetSpeed = abs(signedTargetSpeedCandidates(bestIdx));
                    unwrappedVelocity(idx) = approxSpeedSign * targetSpeed;
                end
            end
        end

        function updateRawAdcView(app, w_idx)
            if isempty(app.fp) || isempty(app.UIAxes_RawADCHeatmap) || isempty(app.UIAxes_RawADCWaveform)
                return;
            end

            [adcOutFrame, frame_idx, sub_idx] = computeWindowRawAdc(app, w_idx);
            if isempty(adcOutFrame)
                cla(app.UIAxes_RawADCHeatmap);
                cla(app.UIAxes_RawADCWaveform);
                return;
            end

            rxIdx = 1;
            if ~isempty(app.RawRxDropDown) && ~isempty(app.RawRxDropDown.Value)
                parsedRx = sscanf(app.RawRxDropDown.Value, 'RX%d');
                if ~isempty(parsedRx)
                    rxIdx = parsedRx(1);
                end
            end
            rxIdx = min(max(round(rxIdx), 1), size(adcOutFrame, 3));

            rawMagnitudeDb = 20 * log10(abs(adcOutFrame(:,:,rxIdx)) + 1e-6);
            sampleAxis = 1:size(adcOutFrame, 1);
            chirpAxis = 1:size(adcOutFrame, 2);

            if isempty(app.hImg_RawADC) || ~isvalid(app.hImg_RawADC)
                app.hImg_RawADC = imagesc(app.UIAxes_RawADCHeatmap, chirpAxis, sampleAxis, rawMagnitudeDb);
            else
                app.hImg_RawADC.XData = chirpAxis;
                app.hImg_RawADC.YData = sampleAxis;
                app.hImg_RawADC.CData = rawMagnitudeDb;
            end
            app.UIAxes_RawADCHeatmap.XLim = [chirpAxis(1), chirpAxis(end)];
            app.UIAxes_RawADCHeatmap.YLim = [sampleAxis(1), sampleAxis(end)];
            app.UIAxes_RawADCHeatmap.YDir = 'normal';
            axis(app.UIAxes_RawADCHeatmap, 'manual');

            chirpIdx = min(size(adcOutFrame, 2), max(1, round(app.RawChirpSpinner.Value)));
            app.RawChirpSpinner.Value = chirpIdx;
            if isempty(app.hRawAdcChirpMarker) || ~isvalid(app.hRawAdcChirpMarker)
                hold(app.UIAxes_RawADCHeatmap, 'on');
                app.hRawAdcChirpMarker = xline(app.UIAxes_RawADCHeatmap, chirpIdx, 'w--', ...
                    'LineWidth', 1.4, 'HitTest', 'off');
                hold(app.UIAxes_RawADCHeatmap, 'off');
            else
                app.hRawAdcChirpMarker.Value = chirpIdx;
                app.hRawAdcChirpMarker.Visible = 'on';
            end

            title(app.UIAxes_RawADCHeatmap, sprintf('原始 ADC 幅值热力图 | Frame %d Window %d RX%d', frame_idx, sub_idx + 1, rxIdx));
            xlabel(app.UIAxes_RawADCHeatmap, 'Chirp Index');
            ylabel(app.UIAxes_RawADCHeatmap, 'ADC Sample Index');
            app.UIAxes_RawADCHeatmap.YDir = 'normal';
            app.UIAxes_RawADCHeatmap.Box = 'on';
            if isempty(app.hColorbar_RawADC) || ~isvalid(app.hColorbar_RawADC)
                app.hColorbar_RawADC = colorbar(app.UIAxes_RawADCHeatmap);
            else
                app.hColorbar_RawADC.Visible = 'on';
            end
            grid(app.UIAxes_RawADCHeatmap, 'off');

            refreshRawAdcWaveform(app, adcOutFrame(:,:,rxIdx), rxIdx, chirpIdx);
        end

        function refreshRawAdcWaveform(app, adcRxFrame, rxIdx, chirpIdx)
            if isempty(adcRxFrame)
                return;
            end

            if nargin < 4 || isempty(chirpIdx)
                chirpIdx = round(size(adcRxFrame, 2) / 2);
            end
            chirpIdx = min(size(adcRxFrame, 2), max(1, round(chirpIdx)));
            sampleAxis = 1:size(adcRxFrame, 1);
            chirpData = adcRxFrame(:, chirpIdx);
            if chirpIdx > 1
                previousChirpData = adcRxFrame(:, chirpIdx - 1);
            elseif size(adcRxFrame, 2) > 1
                previousChirpData = adcRxFrame(:, chirpIdx + 1);
            else
                previousChirpData = chirpData;
            end
            chirpDiffRms = sqrt(mean(abs(chirpData - previousChirpData).^2));
            waveformMode = '去均值I/Q';
            if ~isempty(app.RawWaveformModeDropDown) && ~isempty(app.RawWaveformModeDropDown.Value)
                waveformMode = app.RawWaveformModeDropDown.Value;
            end
            if strcmp(waveformMode, '原始I/Q')
                displayData = chirpData;
            elseif strcmp(waveformMode, '相邻差分I/Q')
                displayData = chirpData - previousChirpData;
            else
                displayData = chirpData - mean(adcRxFrame, 2);
            end

            if isempty(app.hRawAdcIWaveform) || ~isvalid(app.hRawAdcIWaveform) || ...
                    isempty(app.hRawAdcQWaveform) || ~isvalid(app.hRawAdcQWaveform)
                cla(app.UIAxes_RawADCWaveform);
                app.hRawAdcIWaveform = plot(app.UIAxes_RawADCWaveform, sampleAxis, real(displayData), '-', ...
                    'LineWidth', 1.1, 'Color', [0 0.4470 0.7410]);
                hold(app.UIAxes_RawADCWaveform, 'on');
                app.hRawAdcQWaveform = plot(app.UIAxes_RawADCWaveform, sampleAxis, imag(displayData), '-', ...
                    'LineWidth', 1.1, 'Color', [0.8500 0.3250 0.0980]);
                hold(app.UIAxes_RawADCWaveform, 'off');
                app.hLegend_RawADC = legend(app.UIAxes_RawADCWaveform, {'I', 'Q'}, 'Location', 'best');
            else
                app.hRawAdcIWaveform.XData = sampleAxis;
                app.hRawAdcIWaveform.YData = real(displayData);
                app.hRawAdcIWaveform.Visible = 'on';
                app.hRawAdcQWaveform.XData = sampleAxis;
                app.hRawAdcQWaveform.YData = imag(displayData);
                app.hRawAdcQWaveform.Visible = 'on';
            end

            title(app.UIAxes_RawADCWaveform, sprintf('%s | RX%d Chirp %d | Δprev RMS %.1f', waveformMode, rxIdx, chirpIdx, chirpDiffRms));
            xlabel(app.UIAxes_RawADCWaveform, 'ADC Sample Index');
            ylabel(app.UIAxes_RawADCWaveform, 'Amplitude');
            waveformY = [real(displayData(:)); imag(displayData(:))];
            waveformY = waveformY(isfinite(waveformY));
            if ~isempty(waveformY)
                yPad = max(1, 0.08 * range(waveformY));
                if range(waveformY) < eps
                    yPad = max(1, abs(waveformY(1)) * 0.08);
                end
                ylim(app.UIAxes_RawADCWaveform, [min(waveformY) - yPad, max(waveformY) + yPad]);
            end
            grid(app.UIAxes_RawADCWaveform, 'on');
            app.UIAxes_RawADCWaveform.Box = 'on';
            drawnow limitrate;
        end

        function updateFFT1DView(app, w_idx)
            if isempty(app.fp) || isempty(app.UIAxes_FFT1DHeatmap) || isempty(app.UIAxes_FFT1DLine)
                return;
            end

            [rangeFftFrame, frame_idx, sub_idx] = computeWindowRangeFft(app, w_idx);
            if isempty(rangeFftFrame)
                cla(app.UIAxes_FFT1DHeatmap);
                cla(app.UIAxes_FFT1DLine);
                return;
            end

            rxIdx = 1;
            if ~isempty(app.FFT1DRxDropDown) && ~isempty(app.FFT1DRxDropDown.Value)
                parsedRx = sscanf(app.FFT1DRxDropDown.Value, 'RX%d');
                if ~isempty(parsedRx)
                    rxIdx = parsedRx(1);
                end
            end
            rxIdx = min(max(round(rxIdx), 1), size(rangeFftFrame, 3));
            chirpIdx = min(size(rangeFftFrame, 2), max(1, round(app.FFT1DChirpSpinner.Value)));
            app.FFT1DChirpSpinner.Value = chirpIdx;

            fftMagnitudeDb = 20 * log10(abs(rangeFftFrame(:,:,rxIdx)) + 1e-6);
            chirpAxis = 1:size(rangeFftFrame, 2);
            if numel(app.rangeAxis) == size(rangeFftFrame, 1)
                rangePlotAxis = app.rangeAxis;
                rangeAxisLabel = 'Range (m)';
            else
                rangePlotAxis = 1:size(rangeFftFrame, 1);
                rangeAxisLabel = 'Range Bin';
            end

            if isempty(app.hImg_FFT1D) || ~isvalid(app.hImg_FFT1D)
                app.hImg_FFT1D = imagesc(app.UIAxes_FFT1DHeatmap, chirpAxis, rangePlotAxis, fftMagnitudeDb);
            else
                app.hImg_FFT1D.XData = chirpAxis;
                app.hImg_FFT1D.YData = rangePlotAxis;
                app.hImg_FFT1D.CData = fftMagnitudeDb;
            end

            app.UIAxes_FFT1DHeatmap.XLim = [chirpAxis(1), chirpAxis(end)];
            app.UIAxes_FFT1DHeatmap.YLim = [min(rangePlotAxis), max(rangePlotAxis)];
            app.UIAxes_FFT1DHeatmap.YDir = 'normal';
            axis(app.UIAxes_FFT1DHeatmap, 'manual');

            if isempty(app.hFFT1DChirpMarker) || ~isvalid(app.hFFT1DChirpMarker)
                hold(app.UIAxes_FFT1DHeatmap, 'on');
                app.hFFT1DChirpMarker = xline(app.UIAxes_FFT1DHeatmap, chirpIdx, 'w--', ...
                    'LineWidth', 1.4, 'HitTest', 'off');
                hold(app.UIAxes_FFT1DHeatmap, 'off');
            else
                app.hFFT1DChirpMarker.Value = chirpIdx;
                app.hFFT1DChirpMarker.Visible = 'on';
            end

            title(app.UIAxes_FFT1DHeatmap, sprintf('一维 FFT 热力图 | Frame %d Window %d RX%d', frame_idx, sub_idx + 1, rxIdx));
            xlabel(app.UIAxes_FFT1DHeatmap, 'Chirp Index');
            ylabel(app.UIAxes_FFT1DHeatmap, rangeAxisLabel);
            app.UIAxes_FFT1DHeatmap.YDir = 'normal';
            app.UIAxes_FFT1DHeatmap.Box = 'on';
            if isempty(app.hColorbar_FFT1D) || ~isvalid(app.hColorbar_FFT1D)
                app.hColorbar_FFT1D = colorbar(app.UIAxes_FFT1DHeatmap);
            else
                app.hColorbar_FFT1D.Visible = 'on';
            end
            grid(app.UIAxes_FFT1DHeatmap, 'off');

            refreshFFT1DLine(app, rangeFftFrame(:,:,rxIdx), rxIdx, chirpIdx, rangePlotAxis, rangeAxisLabel);
        end

        function refreshFFT1DLine(app, rangeFftRxFrame, rxIdx, chirpIdx, rangePlotAxis, rangeAxisLabel)
            if isempty(rangeFftRxFrame)
                return;
            end

            chirpIdx = min(size(rangeFftRxFrame, 2), max(1, round(chirpIdx)));
            fftLineDb = 20 * log10(abs(rangeFftRxFrame(:, chirpIdx)) + 1e-6);

            [peakVal, peakIdx] = max(fftLineDb);
            peakRange = rangePlotAxis(peakIdx);
            
            if chirpIdx > 1
                prevLineDb = 20 * log10(abs(rangeFftRxFrame(:, chirpIdx-1)) + 1e-6);
                diffRms = sqrt(mean((fftLineDb - prevLineDb).^2));
            else
                diffRms = NaN;
            end

            if isempty(app.hFFT1DLine) || ~isvalid(app.hFFT1DLine)
                cla(app.UIAxes_FFT1DLine);
                app.hFFT1DLine = plot(app.UIAxes_FFT1DLine, rangePlotAxis, fftLineDb, '-', ...
                    'LineWidth', 1.2, 'Color', [0 0.4470 0.7410]);
            else
                app.hFFT1DLine.XData = rangePlotAxis;
                app.hFFT1DLine.YData = fftLineDb;
                app.hFFT1DLine.Visible = 'on';
            end

            % title(app.UIAxes_FFT1DLine, sprintf('选定 Chirp 一维 FFT | RX%d Chirp %d', rxIdx, chirpIdx));
            title(app.UIAxes_FFT1DLine, ...
                sprintf('选定 Chirp 一维 FFT | RX%d Chirp %d | Peak %.2f dB @ %.2f m | Δprev %.3f dB', ...
                rxIdx, chirpIdx, peakVal, peakRange, diffRms));
            xlabel(app.UIAxes_FFT1DLine, rangeAxisLabel);
            ylabel(app.UIAxes_FFT1DLine, 'Magnitude (dB)');
            grid(app.UIAxes_FFT1DLine, 'on');
            app.UIAxes_FFT1DLine.Box = 'on';
            if ~isempty(fftLineDb)
                yPad = max(3, 0.08 * range(fftLineDb));
                if range(fftLineDb) < eps
                    yPad = 3;
                end
                ylim(app.UIAxes_FFT1DLine, [min(fftLineDb) - yPad, max(fftLineDb) + yPad]);
            end
            drawnow limitrate;
        end

        function updateFrame(app, w_idx)
            [rd_db, frame_idx, sub_idx] = computeWindowRd(app, w_idx);
            if isempty(rd_db), return; end
            
            % 刷新界面
            app.hImg_RD.CData = rd_db;
            
            % 物理图：必须在速度维(第2维)做一次 fftshift，使得速度 0 位于图像中心
            app.current_rd_db_shifted = fftshift(rd_db, 2);
            app.hImg_RD_Real.CData = app.current_rd_db_shifted;
            updatePhysicalMaxSnrMarker(app);
            if strcmp(app.ViewDropDown.Value, '最大 SNR 趋势图')
                refreshTrendPlot(app, w_idx);
            end
            app.FrameLabel.Text = sprintf('Phys Frame: %d | Window: %d', frame_idx, sub_idx + 1);
            app.ViewDropDownValueChanged();
        end

        function updatePhysicalMaxSnrMarker(app)
            if isempty(app.current_rd_db_shifted)
                hidePhysicalMaxSnrMarker(app);
                return;
            end

            [maxSnr, targetRange, targetVelocity] = findMaxSnrPointInShiftedRd(app, app.current_rd_db_shifted);
            if ~isfinite(maxSnr) || ~isfinite(targetRange) || ~isfinite(targetVelocity)
                hidePhysicalMaxSnrMarker(app);
                return;
            end

            if isempty(app.hPhysicalMaxSnrMarker) || ~isvalid(app.hPhysicalMaxSnrMarker)
                hold(app.UIAxes_RD_Real, 'on');
                app.hPhysicalMaxSnrMarker = plot(app.UIAxes_RD_Real, targetVelocity, targetRange, 'wo', ...
                    'LineStyle', 'none', ...
                    'MarkerSize', 9, ...
                    'LineWidth', 1.8, ...
                    'HitTest', 'off', ...
                    'PickableParts', 'none');
                hold(app.UIAxes_RD_Real, 'off');
            else
                app.hPhysicalMaxSnrMarker.XData = targetVelocity;
                app.hPhysicalMaxSnrMarker.YData = targetRange;
                app.hPhysicalMaxSnrMarker.Visible = 'on';
            end
        end

        function hidePhysicalMaxSnrMarker(app)
            if ~isempty(app.hPhysicalMaxSnrMarker) && isvalid(app.hPhysicalMaxSnrMarker)
                app.hPhysicalMaxSnrMarker.Visible = 'off';
            end
        end

        function logCurrentPhysicalMaxSnrPoint(app, forceLog)
            if nargin < 2
                forceLog = false;
            end
            if isempty(app.current_rd_db_shifted)
                return;
            end

            currentIdx = round(app.FrameSlider.Value);
            if ~forceLog && isequal(app.lastPhysicalMaxSnrLogWindowIdx, currentIdx)
                return;
            end

            rd_shifted = app.current_rd_db_shifted;
            noiseFloor = conv2(rd_shifted, app.cfar_kernel, 'same');
            snrMap = rd_shifted - noiseFloor;

            edgeR = max(1, app.cfg_Tr + app.cfg_Gr + 1);
            edgeD = max(1, app.cfg_Td + app.cfg_Gd + 1);
            [numRangeBins, numDopplerBins] = size(snrMap);
            snrMap(1:min(edgeR, numRangeBins), :) = -Inf;
            snrMap(max(1, numRangeBins-edgeR+1):numRangeBins, :) = -Inf;
            snrMap(:, 1:min(edgeD, numDopplerBins)) = -Inf;
            snrMap(:, max(1, numDopplerBins-edgeD+1):numDopplerBins) = -Inf;

            if numel(app.rangeAxis) == numRangeBins
                rangeMin = min(app.cfg_MaxSnrRangeMin, app.cfg_MaxSnrRangeMax);
                rangeMax = max(app.cfg_MaxSnrRangeMin, app.cfg_MaxSnrRangeMax);
                rangeMask = app.rangeAxis(:) >= rangeMin & app.rangeAxis(:) <= rangeMax;
                snrMap(~rangeMask, :) = -Inf;
            end

            if numel(app.vel_axis) == numDopplerBins
                velocityMin = min(app.cfg_MaxSnrVelocityMin, app.cfg_MaxSnrVelocityMax);
                velocityMax = max(app.cfg_MaxSnrVelocityMin, app.cfg_MaxSnrVelocityMax);
                % Gate the aliased velocity axis shown in the physical RD plot.
                velocityMask = app.vel_axis(:).' >= velocityMin & app.vel_axis(:).' <= velocityMax;
                snrMap(:, ~velocityMask) = -Inf;
            end

            [maxSnr, linearIdx] = max(snrMap(:));
            app.LogTextArea.Value = [app.LogTextArea.Value; {'------------------------------------'}];
            if ~isfinite(maxSnr)
                app.LogTextArea.Value = [app.LogTextArea.Value; {sprintf('[物理RD自动最大SNR] 窗口 %d: 距离/有模糊速度范围内无有效点。', currentIdx)}];
            else
                [rowIdx, colIdx] = ind2sub(size(snrMap), linearIdx);
                targetRange = app.rangeAxis(rowIdx);
                targetVelocity = app.vel_axis(colIdx);
                targetPower = rd_shifted(rowIdx, colIdx);
                targetNoiseFloor = noiseFloor(rowIdx, colIdx);
                [unwrappedSpeed, ~] = calculateSingleTargetUnwrappedSpeed(app, targetRange, targetVelocity);

                app.LogTextArea.Value = [app.LogTextArea.Value; {sprintf('[物理RD自动最大SNR] 窗口 %d', currentIdx)}];
                app.LogTextArea.Value = [app.LogTextArea.Value; {sprintf('坐标: 距离 %.2f m, 有模糊速度 %.2f m/s, 解模糊速度 %.2f m/s', targetRange, targetVelocity, unwrappedSpeed)}];
                app.LogTextArea.Value = [app.LogTextArea.Value; {sprintf('功率: %.2f dB', targetPower)}];
                app.LogTextArea.Value = [app.LogTextArea.Value; {sprintf('噪底: %.2f dB', targetNoiseFloor)}];
                app.LogTextArea.Value = [app.LogTextArea.Value; {sprintf('信噪比 (SNR): %.2f dB', maxSnr)}];
            end
            app.lastPhysicalMaxSnrLogWindowIdx = currentIdx;
            scroll(app.LogTextArea, 'bottom');
        end
        
        function RD_Real_Click(app, event)
            if isempty(app.current_rd_db_shifted), return; end
            
            % 1. 获取鼠标点击位置的物理坐标 [V, R]
            coords = event.IntersectionPoint;
            v_click = coords(1);
            r_click = coords(2);
            
            % 2. 将物理坐标还原为矩阵索引 [row, col]
            % 找到距离轴和速度轴上最接近点击值的索引
            [~, col_idx] = min(abs(app.vel_axis - v_click));
            [~, row_idx] = min(abs(app.rangeAxis - r_click));
            
            % 3. 提取目标功率 (Signal Power)
            target_pwr = app.current_rd_db_shifted(row_idx, col_idx);
            
            % 4. 计算局部噪底 (Noise Floor)
            % 我们取目标周围一个 11x11 的窗口，排除中间 3x3 的目标保护区
            win_size = 5; % 左右各延申5个单位
            [R_max, D_max] = size(app.current_rd_db_shifted);
            
            r_range = max(1, row_idx-win_size) : min(R_max, row_idx+win_size);
            d_range = max(1, col_idx-win_size) : min(D_max, col_idx+win_size);
            
            local_region = app.current_rd_db_shifted(r_range, d_range);
            
            % 排除中心目标能量（计算均值时排除中间区域）
            % 这里简单处理：取该区域的第 30% 分位数作为噪底，比直接取均值更抗干扰
            noise_floor = quantile(local_region(:), 0.3); 
            
            % 5. 计算 SNR (由于是 dB，直接相减)
            snr = target_pwr - noise_floor;
            
            % 6. 打印到日志区
            app.LogTextArea.Value = [app.LogTextArea.Value; {'------------------------------------'}];
            app.LogTextArea.Value = [app.LogTextArea.Value; {sprintf('选中目标信息：')}];
            [unwrappedSpeed, ~] = calculateSingleTargetUnwrappedSpeed(app, r_click, v_click);
            app.LogTextArea.Value = [app.LogTextArea.Value; {sprintf('坐标: 距离 %.2f m, 速度 %.2f m/s, 解模糊速度 %.2f m/s', r_click, v_click, unwrappedSpeed)}];
            app.LogTextArea.Value = [app.LogTextArea.Value; {sprintf('功率: %.2f dB', target_pwr)}];
            app.LogTextArea.Value = [app.LogTextArea.Value; {sprintf('噪底: %.2f dB', noise_floor)}];
            app.LogTextArea.Value = [app.LogTextArea.Value; {sprintf('信噪比 (SNR): %.2f dB', snr)}];
            
            scroll(app.LogTextArea, 'bottom');
        end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Button pushed function: FPGAButton
        function FPGAButtonPushed(app, event)
            % 获取界面上填写的路径
            cliPath = app.CLIPathEditField.Value; 
            jsonPath = prepareCaptureJson(app, false, false);
            jsonArg = ['.' filesep getJsonFileName(app, jsonPath)];
            
            % 更新日志并强制立刻刷新界面
            app.LogTextArea.Value = [app.LogTextArea.Value; {'------------------------------------'}];
            app.LogTextArea.Value = [app.LogTextArea.Value; {'正在下发 FPGA 配置...'}];
            drawnow; 
            
            % Clear any unfinished DCA1000 record session before reconfiguring FPGA.
            stopDcaRecordQuietly(app, cliPath, jsonArg);
            
            % 执行命令并捕获控制台输出
            [status, cmdout] = runDcaCli(app, cliPath, 'DCA1000EVM_CLI_Control.exe', 'fpga', jsonArg, false);
            
            % 将输出结果回显到界面日志区
            app.LogTextArea.Value = [app.LogTextArea.Value; {cmdout}];
            
            if status ~= 0
                app.LogTextArea.Value = [app.LogTextArea.Value; ...
                    {'[错误] FPGA 初始化失败，请检查网线和DCA1000状态。'}];
                scroll(app.LogTextArea, 'bottom');
                return;
            end
            
            app.LogTextArea.Value = [app.LogTextArea.Value; ...
                {'[成功] FPGA 初始化完成！'}; ...
                {'正在下发 Record 配置...'}];
            drawnow;
            
            % 将采集模式、文件分卷、数据格式等参数配置给DCA1000
            [recordStatus, recordOut] = runDcaCli( ...
                app, cliPath, ...
                'DCA1000EVM_CLI_Control.exe', ...
                'record', jsonArg, false);
            
            app.LogTextArea.Value = [app.LogTextArea.Value; {recordOut}];
            
            if recordStatus == 0
                app.LogTextArea.Value = [app.LogTextArea.Value; ...
                    {'[成功] Record 参数配置完成，可以开始采集。'}];
            else
                app.LogTextArea.Value = [app.LogTextArea.Value; ...
                    {'[错误] Record 参数配置失败。'}];
            end
            
            % 自动滚动到日志最底部
            scroll(app.LogTextArea, 'bottom');
        end

        % Button pushed function: StartButton
        function StartButtonPushed(app, event)
            if app.isDcaRecording
                app.LogTextArea.Value = [app.LogTextArea.Value; {'[WARN] DCA1000 record is already running. Stop it before starting again.'}];
                scroll(app.LogTextArea, 'bottom');
                return;
            end

            cliPath = app.CLIPathEditField.Value; 
            jsonPath = prepareCaptureJson(app, true, true);
            jsonArg = ['.' filesep getJsonFileName(app, jsonPath)];
            targetBytes = round(app.cfg_CaptureSizeMB * 1000000);
            app.stopCaptureRequested = false;
            
            app.LogTextArea.Value = [app.LogTextArea.Value; {'[运行] 开始采集，等待雷达板发射数据...'}];
            app.LogTextArea.Value = [app.LogTextArea.Value; {sprintf('[保存] 本次文件前缀: %s', app.currentCaptureFilePrefix)}];
            app.LogTextArea.Value = [app.LogTextArea.Value; {sprintf('[保存] 首个数据文件: %s', app.DataPathEdit.Value)}];
            app.LogTextArea.Value = [app.LogTextArea.Value; {sprintf('[目标] 自动采集 %.3f MB 后停止。', targetBytes / 1000000)}];
            drawnow;
            
            % 使用 start /B 让命令在后台异步执行，防止 MATLAB App 界面卡死
            [status, cmdout] = runDcaCli(app, cliPath, 'DCA1000EVM_CLI_Control.exe', 'start_record', jsonArg, false);
            app.LogTextArea.Value = [app.LogTextArea.Value; {cmdout}];
            if status ~= 0
                app.isDcaRecording = false;
                app.LogTextArea.Value = [app.LogTextArea.Value; {'[错误] start_record 启动失败。'}];
                scroll(app.LogTextArea, 'bottom');
                return;
            end

            app.isDcaRecording = true;
            app.StartButton.Enable = 'off';
            cleanupStartButton = onCleanup(@() set(app.StartButton, 'Enable', 'on'));
            lastReportTime = tic;
            lastBytes = 0;
            lastGrowthTime = tic;
            stallTimeoutSec = 8;
            stallDetected = false;


            while app.isDcaRecording && ~app.stopCaptureRequested
                capturedBytes = getCurrentCaptureBytes(app);
            
                % 达到目标大小，正常结束
                if capturedBytes >= targetBytes
                    break;
                end
            
                % 文件大小发生增长，重新开始计时
                if capturedBytes > lastBytes
                    lastBytes = capturedBytes;
                    lastGrowthTime = tic;
                end
            
                % 已经收到过数据，但连续8秒没有增长
                if capturedBytes > 0 && toc(lastGrowthTime) >= stallTimeoutSec
                    stallDetected = true;
            
                    app.LogTextArea.Value = [app.LogTextArea.Value; ...
                        {sprintf('[异常] 文件连续 %.1f 秒未增长，当前大小 %.3f MB。', ...
                        stallTimeoutSec, capturedBytes / 1000000)}];
            
                    scroll(app.LogTextArea, 'bottom');
                    break;
                end

                if toc(lastReportTime) >= 1
                    app.LogTextArea.Value = [app.LogTextArea.Value; {sprintf('[采集] %.3f / %.3f MB', capturedBytes / 1000000, targetBytes / 1000000)}];
                    scroll(app.LogTextArea, 'bottom');
                    lastReportTime = tic;
                end
                pause(0.1);
                drawnow;
            end

            if app.isDcaRecording
                if app.stopCaptureRequested
                    app.LogTextArea.Value = [app.LogTextArea.Value; ...
                        {'[中止] 收到手动停止请求，正在 stop_record...'}];
                
                elseif stallDetected
                    app.LogTextArea.Value = [app.LogTextArea.Value; ...
                        {'[异常] 采集数据已停止增长，正在执行 stop_record 并保留已有数据...'}];
                
                else
                    app.LogTextArea.Value = [app.LogTextArea.Value; ...
                        {'[完成] 目标数据量已达到，正在自动 stop_record...'}];
                end
                drawnow;
                [stopStatus, stopOut] = stopDcaRecord(app, cliPath, jsonArg);
                app.LogTextArea.Value = [app.LogTextArea.Value; {stopOut}];
                if stopStatus == 0
                    finalBytes = getCurrentCaptureBytes(app);
                    app.LogTextArea.Value = [app.LogTextArea.Value; {sprintf('[成功] 采集完成，已保存 %.3f MB。', finalBytes / 1000000)}];
                    if ~app.stopCaptureRequested
                        uialert(app.UIFigure, '采集完成，可以再次点击【开始采集】。', '采集完成', 'Icon', 'success');
                    end
                else
                    app.LogTextArea.Value = [app.LogTextArea.Value; {'[错误] stop_record 执行失败，请检查 DCA1000 状态。'}];
                end
            end

            app.stopCaptureRequested = false;
            clear cleanupStartButton;
            scroll(app.LogTextArea, 'bottom');
        end

        % Button pushed function: StopButton
        function StopButtonPushed(app, event)
            if app.isDcaRecording
                app.stopCaptureRequested = true;
                app.LogTextArea.Value = [app.LogTextArea.Value; {'[请求] 将在当前自动采集流程中止并发送 stop_record...'}];
                scroll(app.LogTextArea, 'bottom');
                drawnow;
                return;
            end

            cliPath = app.CLIPathEditField.Value; 
            jsonPath = prepareCaptureJson(app, false, false);
            jsonArg = ['.' filesep getJsonFileName(app, jsonPath)];
            
            app.LogTextArea.Value = [app.LogTextArea.Value; {'正在发送停止指令...'}];
            drawnow;
            
            % 停止采集
            [status, cmdout] = stopDcaRecord(app, cliPath, jsonArg);
            
            app.LogTextArea.Value = [app.LogTextArea.Value; {cmdout}];
            app.LogTextArea.Value = [app.LogTextArea.Value; {'[成功] 采集已停止，.bin 数据已保存至目标文件夹。'}];
            
            scroll(app.LogTextArea, 'bottom');
        end        % Button pushed function: ProcessButton
        function ProcessButtonPushed(app, event)
            try
                appRoot = getAppRoot(app);
                repoRoot = fileparts(appRoot);
                srcDir = fullfile(repoRoot, 'src');
                if isfolder(srcDir)
                    addpath(srcDir);
                end
                addpath(appRoot);

                appConfig = struct();
                appConfig.numSamples = app.cfg_Samples;
                appConfig.numChirpsPerFrame = app.cfg_Chirps;
                appConfig.numRx = app.cfg_NumRx;
                appConfig.numTx = app.cfg_NumTx;
                appConfig.rangeFftSize = app.cfg_RangeFftSize;
                appConfig.adcSampleRateMsps = app.cfg_AdcSampleRate;
                appConfig.slopeMHzPerUs = app.cfg_Slope;
                appConfig.startFreqGHz = app.cfg_StartFreqGHz;
                appConfig.chirpPeriodUs = app.cfg_ChirpPeriodUs;
                appConfig.framePeriodMs = 3.5;

                appConfig.processingWinSize = min(16, app.cfg_Chirps);
                appConfig.processingWinStep = ...
                    appConfig.processingWinSize;
                appConfig.processingDopplerFftSize = ...
                    max(128, appConfig.processingWinSize);

                appConfig.approxSpeed = abs(app.ApproxSpeedEdit.Value);
                if ~isfinite(appConfig.approxSpeed) ...
                        || appConfig.approxSpeed <= 0
                    appConfig.approxSpeed = 400;
                end

                processingCfg = ...
                    radarui.buildProcessingConfig(appConfig);
                dataFile = app.DataPathEdit.Value;

                if ~isempty(app.processingWindow) ...
                        && isvalid(app.processingWindow)
                    app.processingWindow.setInput( ...
                        dataFile, processingCfg);
                else
                    app.processingWindow = ...
                        radarui.ProcessingWindow( ...
                            dataFile, processingCfg);
                end

                app.LogTextArea.Value = [ ...
                    app.LogTextArea.Value; ...
                    {'[数据处理] 已打开弹丸雷达处理窗口。'}];
                scroll(app.LogTextArea, 'bottom');
            catch ME
                app.LogTextArea.Value = [ ...
                    app.LogTextArea.Value; ...
                    {sprintf('[数据处理错误] %s', ME.message)}];
                scroll(app.LogTextArea, 'bottom');
                uialert( ...
                    app.UIFigure, ...
                    getReport(ME, 'extended', 'hyperlinks', 'off'), ...
                    '无法打开数据处理');
            end
        end



        % Button pushed function: LoadBtn
        function LoadBtnButtonPushed(app, event)
            if ~isfile(app.DataPathEdit.Value)
                uialert(app.UIFigure, '文件不存在', '错误'); 
                app.LogTextArea.Value = [app.LogTextArea.Value; {'[错误] 找不到雷达数据文件！'}];
                scroll(app.LogTextArea, 'bottom');
                return;
            end
            app.LogTextArea.Value = [app.LogTextArea.Value; {'------------------------------------'}];
            app.LogTextArea.Value = [app.LogTextArea.Value; {sprintf('开始加载文件: %s', app.DataPathEdit.Value)}];
            drawnow;
            
            % === 1. 利用你输入的动态参数进行推导 ===
            numRangeSamples = getProcessingSamples(app);
            chirpDuration_us = numRangeSamples / app.cfg_AdcSampleRate;
            bandwidth_MHz = app.cfg_Slope * chirpDuration_us;
            centerFreq = app.cfg_StartFreqGHz + 1e-3*(bandwidth_MHz/2);
            lambda = 3e8 / (centerFreq * 1e9);
            
            app.numUint16Samples_perFrame = numRangeSamples * app.cfg_Chirps * app.cfg_NumTx * app.cfg_NumRx * 2; 
            
            app.delta_v = lambda / (2 * app.cfg_WinSize * app.cfg_ChirpPeriodUs * 1e-6);
            
            % 动态生成距离轴
            app.rangeAxis = (0:app.cfg_RangeFftSize-1) * (1e-6*(3e8/2/bandwidth_MHz)) * chirpDuration_us * app.cfg_AdcSampleRate / app.cfg_RangeFftSize;
            
            dx = 0.5 * 3e8/(76.5e9);
            angleSinAxis = linspace(-lambda/(2*dx), lambda/(2*dx)-lambda/(app.cfg_AngleFftSize*dx), app.cfg_AngleFftSize);
            app.angleAxis = asind(angleSinAxis);
            
            % === 2. 加载校准矩阵 ===
            try
                tmpCalib = load(getBundledCalibrationPath(app));
                calibVec = tmpCalib.dataCplxChannels(:).';
                calibVec = calibVec ./ abs(calibVec);
                if numel(calibVec) >= app.cfg_NumRx
                    app.calib3D = reshape(calibVec(1:app.cfg_NumRx), 1, 1, app.cfg_NumRx);
                else
                    app.calib3D = ones(1, 1, app.cfg_NumRx);
                end
            catch
                app.calib3D = ones(1,1,app.cfg_NumRx);
            end
            
            % === 3. 动态配置 CFAR Kernel ===
            Tr = app.cfg_Tr; Td = app.cfg_Td; Gr = app.cfg_Gr; Gd = app.cfg_Gd;
            app.winR = 2*(Tr+Gr)+1; app.winD = 2*(Td+Gd)+1;
            app.cfar_kernel = ones(app.winR, app.winD);
            app.cfar_kernel(Tr+1:Tr+2*Gr+1, Td+1:Td+2*Gd+1) = 0;
            app.cfar_kernel = app.cfar_kernel / sum(app.cfar_kernel(:));
            
            % 更新阈值
            app.offset_dB = app.cfg_offset_dB; 
            
            % === 4. 打开文件获取帧数 ===
            if ~isempty(app.fp), fclose(app.fp); end
            app.fp = fopen(app.DataPathEdit.Value, 'rb');
            fseek(app.fp, 0, 'eof');
            app.numFrames = floor(ftell(app.fp) / (app.numUint16Samples_perFrame * 2));
            
            if app.numFrames < 1
                uialert(app.UIFigure, '文件太小，未能识别到完整帧', '错误'); return;
            end
            app.windows_per_frame = floor((app.cfg_Chirps - app.cfg_WinSize) / app.cfg_WinStep) + 1;
            total_windows = app.numFrames * app.windows_per_frame;
            app.LogTextArea.Value = [app.LogTextArea.Value; {sprintf('[成功] 文件解析完毕，共 %d 个物理帧。', app.numFrames)}];
            app.LogTextArea.Value = [app.LogTextArea.Value; {sprintf('滑窗切片: 每帧可切 %d 窗，总计 %d 窗！', app.windows_per_frame, total_windows)}];
            app.LogTextArea.Value = [app.LogTextArea.Value; {sprintf('系统 Vmax 配置为: ±%.2f m/s', (app.cfg_WinSize/2)*app.delta_v)}];
            scroll(app.LogTextArea, 'bottom');
            
            app.FrameSlider.Limits = [1 total_windows];
            app.FrameSlider.Value = 1;
            app.lastPhysicalMaxSnrLogWindowIdx = NaN;
            app.FitStartEdit.Limits = [1 app.numFrames];
            app.FitEndEdit.Limits = [1 app.numFrames];
            app.FitStartEdit.Value = 1;
            app.FitEndEdit.Value = app.numFrames;
            
            % === 5. 初始化图像 ===
            
            % 计算真实的物理速度轴 (将 0 速度对齐到数组中心)
            % app.vel_axis = (-app.cfg_Chirps/2 : app.cfg_Chirps/2 - 1) * app.delta_v;
            app.vel_axis = (-app.cfg_WinSize/2 : app.cfg_WinSize/2 - 1) * app.delta_v;
            
            % (1) 频点 RD 图 初始化
            dopplerBinAxis = 1:app.cfg_WinSize;
            rangeBinAxis = 1:app.cfg_RangeFftSize;
            app.hImg_RD = imagesc(app.UIAxes_RD, dopplerBinAxis, rangeBinAxis, zeros(app.cfg_RangeFftSize, app.cfg_WinSize));
            app.UIAxes_RD.XLim = [dopplerBinAxis(1), dopplerBinAxis(end)];
            app.UIAxes_RD.YLim = [rangeBinAxis(1), rangeBinAxis(end)];
            app.UIAxes_RD.YDir = 'reverse';
            app.UIAxes_RD.CLim = [max(20, app.cfg_offset_dB) 120]; 
            app.UIAxes_RD.Box = 'on';
            app.UIAxes_RD.XLabel.String = 'Doppler-Bin';
            app.UIAxes_RD.YLabel.String = 'Range-Bin';
            app.UIAxes_RD.XTickMode = 'auto';
            app.UIAxes_RD.YTickMode = 'auto';
            app.UIAxes_RD.XTickLabelMode = 'auto';
            app.UIAxes_RD.YTickLabelMode = 'auto';
            
            % (2) 物理坐标 RD 图 初始化
            app.hImg_RD_Real = imagesc(app.UIAxes_RD_Real, app.vel_axis, app.rangeAxis, zeros(app.cfg_RangeFftSize, app.cfg_WinSize));
            app.hImg_RD_Real.ButtonDownFcn = createCallbackFcn(app, @RD_Real_Click, true); % 鼠标点击事件
            axis(app.UIAxes_RD_Real, 'tight');
            app.UIAxes_RD_Real.YDir = 'normal'; 
            app.UIAxes_RD_Real.CLim = [max(20, app.cfg_offset_dB) 120]; 
            app.UIAxes_RD_Real.Box = 'on';
            app.UIAxes_RD_Real.XLabel.String = 'Velocity (m/s)';
            app.UIAxes_RD_Real.YLabel.String = 'Range (m)';
            app.UIAxes_RD_Real.XTickMode = 'auto';
            app.UIAxes_RD_Real.YTickMode = 'auto';
            app.UIAxes_RD_Real.XTickLabelMode = 'auto';
            app.UIAxes_RD_Real.YTickLabelMode = 'auto';

            % (3) 原始 ADC 数据图 初始化
            rxItems = arrayfun(@(rx) sprintf('RX%d', rx), 1:app.cfg_NumRx, 'UniformOutput', false);
            app.RawRxDropDown.Items = rxItems;
            if isempty(app.RawRxDropDown.Value) || ~ismember(app.RawRxDropDown.Value, rxItems)
                app.RawRxDropDown.Value = rxItems{1};
            end
            app.RawChirpSpinner.Limits = [1 app.cfg_WinSize];
            app.RawChirpSpinner.Value = min(app.cfg_WinSize, max(1, round(app.cfg_WinSize / 2)));
            sampleAxis = 1:numRangeSamples;
            chirpAxis = 1:app.cfg_WinSize;
            app.hImg_RawADC = imagesc(app.UIAxes_RawADCHeatmap, chirpAxis, sampleAxis, zeros(numRangeSamples, app.cfg_WinSize));
            title(app.UIAxes_RawADCHeatmap, '原始 ADC 幅值热力图');
            app.UIAxes_RawADCHeatmap.XLabel.String = 'Chirp Index';
            app.UIAxes_RawADCHeatmap.YLabel.String = 'ADC Sample Index';
            app.UIAxes_RawADCHeatmap.YDir = 'normal';
            app.UIAxes_RawADCHeatmap.Box = 'on';
            app.UIAxes_RawADCHeatmap.XTickMode = 'auto';
            app.UIAxes_RawADCHeatmap.YTickMode = 'auto';
            app.UIAxes_RawADCHeatmap.XTickLabelMode = 'auto';
            app.UIAxes_RawADCHeatmap.YTickLabelMode = 'auto';

            cla(app.UIAxes_RawADCWaveform);
            title(app.UIAxes_RawADCWaveform, '中间 Chirp I/Q 波形');
            app.UIAxes_RawADCWaveform.XLabel.String = 'ADC Sample Index';
            app.UIAxes_RawADCWaveform.YLabel.String = 'Amplitude';
            app.UIAxes_RawADCWaveform.XTickMode = 'auto';
            app.UIAxes_RawADCWaveform.YTickMode = 'auto';
            app.UIAxes_RawADCWaveform.XTickLabelMode = 'auto';
            app.UIAxes_RawADCWaveform.YTickLabelMode = 'auto';
            grid(app.UIAxes_RawADCWaveform, 'on');

            % (4) 一维 FFT 图 初始化
            app.FFT1DRxDropDown.Items = rxItems;
            if isempty(app.FFT1DRxDropDown.Value) || ~ismember(app.FFT1DRxDropDown.Value, rxItems)
                app.FFT1DRxDropDown.Value = rxItems{1};
            end
            app.FFT1DChirpSpinner.Limits = [1 app.cfg_WinSize];
            app.FFT1DChirpSpinner.Value = min(app.cfg_WinSize, max(1, round(app.cfg_WinSize / 2)));
            if numel(app.rangeAxis) == app.cfg_RangeFftSize
                fftRangeAxis = app.rangeAxis;
                fftRangeLabel = 'Range (m)';
            else
                fftRangeAxis = 1:app.cfg_RangeFftSize;
                fftRangeLabel = 'Range Bin';
            end
            app.hImg_FFT1D = imagesc(app.UIAxes_FFT1DHeatmap, chirpAxis, fftRangeAxis, zeros(app.cfg_RangeFftSize, app.cfg_WinSize));
            title(app.UIAxes_FFT1DHeatmap, '一维 FFT 热力图');
            app.UIAxes_FFT1DHeatmap.XLabel.String = 'Chirp Index';
            app.UIAxes_FFT1DHeatmap.YLabel.String = fftRangeLabel;
            app.UIAxes_FFT1DHeatmap.YDir = 'normal';
            app.UIAxes_FFT1DHeatmap.Box = 'on';
            app.UIAxes_FFT1DHeatmap.XTickMode = 'auto';
            app.UIAxes_FFT1DHeatmap.YTickMode = 'auto';
            app.UIAxes_FFT1DHeatmap.XTickLabelMode = 'auto';
            app.UIAxes_FFT1DHeatmap.YTickLabelMode = 'auto';

            cla(app.UIAxes_FFT1DLine);
            title(app.UIAxes_FFT1DLine, '选定 Chirp 一维 FFT');
            app.UIAxes_FFT1DLine.XLabel.String = fftRangeLabel;
            app.UIAxes_FFT1DLine.YLabel.String = 'Magnitude (dB)';
            app.UIAxes_FFT1DLine.XTickMode = 'auto';
            app.UIAxes_FFT1DLine.YTickMode = 'auto';
            app.UIAxes_FFT1DLine.XTickLabelMode = 'auto';
            app.UIAxes_FFT1DLine.YTickLabelMode = 'auto';
            grid(app.UIAxes_FFT1DLine, 'on');
             
            % (5) 最大 SNR 点趋势图 初始化
            cla(app.UIAxes_PC);
            cla(app.UIAxes_TrendVelocity);
            title(app.UIAxes_PC, '最大 SNR 点距离趋势');
            app.UIAxes_PC.XLabel.String = 'Window Index';
            app.UIAxes_PC.YLabel.String = 'Range (m)';
            app.UIAxes_PC.XTickMode = 'auto';
            app.UIAxes_PC.YTickMode = 'auto';
            app.UIAxes_PC.XTickLabelMode = 'auto';
            app.UIAxes_PC.YTickLabelMode = 'auto';
            grid(app.UIAxes_PC, 'on'); colormap(app.UIAxes_PC, 'jet');
            title(app.UIAxes_TrendVelocity, '最大 SNR 点速度趋势');
            app.UIAxes_TrendVelocity.XLabel.String = 'Window Index';
            app.UIAxes_TrendVelocity.YLabel.String = 'Aliased Velocity (m/s)';
            app.UIAxes_TrendVelocity.XTickMode = 'auto';
            app.UIAxes_TrendVelocity.YTickMode = 'auto';
            app.UIAxes_TrendVelocity.XTickLabelMode = 'auto';
            app.UIAxes_TrendVelocity.YTickLabelMode = 'auto';
            grid(app.UIAxes_TrendVelocity, 'on');
            
            app.LogTextArea.Value = [app.LogTextArea.Value; {'正在全局计算每个滑窗的最大 SNR 点...'}];
            scroll(app.LogTextArea, 'bottom');
            drawnow;
            app.precomputeWindowTrends(total_windows);
            app.refreshTrendPlot(1);
            validCount = sum(isfinite(app.trendSnr));
            app.LogTextArea.Value = [app.LogTextArea.Value; {sprintf('[成功] 已完成最大 SNR 趋势统计，有效滑窗 %d / %d。', validCount, total_windows)}];
            scroll(app.LogTextArea, 'bottom');

            app.ViewDropDownValueChanged();

            % 渲染第一帧
            app.updateFrame(1);
        end

        % Button pushed function: DataPathBrowseButton
        function DataPathBrowseButtonPushed(app, event)
            startDir = fileparts(app.DataPathEdit.Value);
            if isempty(startDir) || ~isfolder(startDir)
                startDir = pwd;
            end

            [fileName, fileDir] = uigetfile({'*.bin','Radar raw data (*.bin)'; '*.*','All files (*.*)'}, ...
                '选择雷达原始数据文件', startDir);
            if isequal(fileName, 0)
                return;
            end

            app.DataPathEdit.Value = fullfile(fileDir, fileName);
            app.LogTextArea.Value = [app.LogTextArea.Value; {sprintf('[路径] 数据文件: %s', app.DataPathEdit.Value)}];
            scroll(app.LogTextArea, 'bottom');
        end

        % Button pushed function: CLIPathBrowseButton
        function CLIPathBrowseButtonPushed(app, event)
            startDir = app.CLIPathEditField.Value;
            if isempty(startDir) || ~isfolder(startDir)
                startDir = getBundledCliPath(app);
            end
            if isempty(startDir) || ~isfolder(startDir)
                startDir = pwd;
            end

            selectedDir = uigetdir(startDir, '选择 TI DCA1000 CLI 工具目录');
            if isequal(selectedDir, 0)
                return;
            end

            app.CLIPathEditField.Value = selectedDir;
            app.runtimeJsonPath = [];
            app.LogTextArea.Value = [app.LogTextArea.Value; {sprintf('[路径] CLI目录: %s', selectedDir)}];

            controlExe = fullfile(selectedDir, 'DCA1000EVM_CLI_Control.exe');
            recordExe = fullfile(selectedDir, 'DCA1000EVM_CLI_Record.exe');
            if ~isfile(controlExe) || ~isfile(recordExe)
                app.LogTextArea.Value = [app.LogTextArea.Value; {'[警告] 所选目录中未找到完整的 DCA1000EVM_CLI_Control.exe / DCA1000EVM_CLI_Record.exe。'}];
            end
            scroll(app.LogTextArea, 'bottom');
        end

        % Button pushed function: JSONPathBrowseButton
        function JSONPathBrowseButtonPushed(app, event)
            startDir = fileparts(app.JSONPathEditField.Value);
            if isempty(startDir) || ~isfolder(startDir)
                startDir = getBundledCliPath(app);
            end
            if isempty(startDir) || ~isfolder(startDir)
                startDir = pwd;
            end

            [fileName, fileDir] = uigetfile({'*.json','DCA1000 JSON (*.json)'; '*.*','All files (*.*)'}, ...
                '选择 DCA1000 配置 JSON 文件', startDir);
            if isequal(fileName, 0)
                return;
            end

            app.jsonTemplatePath = fullfile(fileDir, fileName);
            app.JSONPathEditField.Value = app.jsonTemplatePath;
            app.runtimeJsonPath = [];
            app.LogTextArea.Value = [app.LogTextArea.Value; {sprintf('[路径] JSON模板: %s', app.jsonTemplatePath)}];
            scroll(app.LogTextArea, 'bottom');
        end

        % Value changed function: FrameSlider
        function FrameSliderValueChanged(app, event)
            f = round(app.FrameSlider.Value);
            app.updateFrame(f);
            
        end

        % Value changed function: ViewDropDown
        function ViewDropDownValueChanged(app, event)
            mode = app.ViewDropDown.Value;
            
            % 1. 先把所有图和它们的子对象全隐藏，避免其它坐标轴残留
            allAxes = [app.UIAxes_RD, app.UIAxes_RD_Real, app.UIAxes_RawADCHeatmap, app.UIAxes_RawADCWaveform, app.UIAxes_FFT1DHeatmap, app.UIAxes_FFT1DLine, app.UIAxes_PC, app.UIAxes_TrendVelocity, app.UIAxes_FitRange, app.UIAxes_FitVelocity];
            for k = 1:numel(allAxes)
                allAxes(k).Visible = 'off';
                allAxes(k).Toolbar.Visible = 'off';
                axisDescendants = findall(allAxes(k));
                axisDescendants(axisDescendants == allAxes(k)) = [];
                if ~isempty(axisDescendants)
                    set(axisDescendants, 'Visible', 'off');
                end
            end
            if ~isempty(app.hColorbar_RawADC) && isvalid(app.hColorbar_RawADC)
                app.hColorbar_RawADC.Visible = 'off';
            end
            
            if ~isempty(app.hColorbar_FFT1D) && isvalid(app.hColorbar_FFT1D)
                app.hColorbar_FFT1D.Visible = 'off';
            end
            
            if ~isempty(app.hLegend_RawADC) && isvalid(app.hLegend_RawADC)
                app.hLegend_RawADC.Visible = 'off';
            end
            app.FitStartLabel.Visible = 'off';
            app.FitStartEdit.Visible = 'off';
            app.FitEndLabel.Visible = 'off';
            app.FitEndEdit.Visible = 'off';
            app.FitConfirmButton.Visible = 'off';
            app.RawRxLabel.Visible = 'off';
            app.RawRxDropDown.Visible = 'off';
            app.RawChirpLabel.Visible = 'off';
            app.RawChirpSpinner.Visible = 'off';
            app.RawWaveformModeLabel.Visible = 'off';
            app.RawWaveformModeDropDown.Visible = 'off';
            app.FFT1DRxLabel.Visible = 'off';
            app.FFT1DRxDropDown.Visible = 'off';
            app.FFT1DChirpLabel.Visible = 'off';
            app.FFT1DChirpSpinner.Visible = 'off';
            
            % 2. 根据选项，只显示对应的图
            if strcmp(mode, '频点 RD 图')
                targetAxes = app.UIAxes_RD;
            elseif strcmp(mode, '物理坐标 RD 图')
                targetAxes = app.UIAxes_RD_Real;
                updatePhysicalMaxSnrMarker(app);
                forceLog = nargin > 1 && ~isempty(event);
                logCurrentPhysicalMaxSnrPoint(app, forceLog);
            elseif strcmp(mode, '原始 ADC 数据图')
                targetAxes = [app.UIAxes_RawADCHeatmap, app.UIAxes_RawADCWaveform];

                app.RawRxLabel.Visible = 'on';
                app.RawRxDropDown.Visible = 'on';
                app.RawChirpLabel.Visible = 'on';
                app.RawChirpSpinner.Visible = 'on';
                app.RawWaveformModeLabel.Visible = 'on';
                app.RawWaveformModeDropDown.Visible = 'on';
            
                if ~isempty(app.hColorbar_RawADC) && isvalid(app.hColorbar_RawADC)
                    app.hColorbar_RawADC.Visible = 'on';
                end
            
                if ~isempty(app.hLegend_RawADC) && isvalid(app.hLegend_RawADC)
                    app.hLegend_RawADC.Visible = 'on';
                end
            
                if ~isempty(app.fp)
                    updateRawAdcView(app, round(app.FrameSlider.Value));
                end
            elseif strcmp(mode, '一维 FFT 图')
                targetAxes = [app.UIAxes_FFT1DHeatmap, app.UIAxes_FFT1DLine];
                app.FFT1DRxLabel.Visible = 'on';
                app.FFT1DRxDropDown.Visible = 'on';
                app.FFT1DChirpLabel.Visible = 'on';
                app.FFT1DChirpSpinner.Visible = 'on';
                if ~isempty(app.hColorbar_FFT1D) && isvalid(app.hColorbar_FFT1D)
                    app.hColorbar_FFT1D.Visible = 'on';
                end
                if ~isempty(app.fp)
                    updateFFT1DView(app, round(app.FrameSlider.Value));
                end
            elseif strcmp(mode, '拟合趋势图')
                targetAxes = [app.UIAxes_FitRange, app.UIAxes_FitVelocity];
                app.FitStartLabel.Visible = 'on';
                app.FitStartEdit.Visible = 'on';
                app.FitEndLabel.Visible = 'on';
                app.FitEndEdit.Visible = 'on';
                app.FitConfirmButton.Visible = 'on';
                if nargin > 1 && ~isempty(event)
                    resetFitPlot(app);
                end
            else
                if ~isempty(app.trendWindowIdx)
                    currentIdx = round(app.FrameSlider.Value);
                    refreshTrendPlot(app, currentIdx);
                    logCurrentTrendPoint(app, currentIdx);
                end
                targetAxes = [app.UIAxes_PC, app.UIAxes_TrendVelocity];
            end

            for k = 1:numel(targetAxes)
                targetAxes(k).Visible = 'on';
                targetAxes(k).Toolbar.Visible = 'on';
                targetAxes(k).XTickMode = 'auto';
                targetAxes(k).YTickMode = 'auto';
                targetAxes(k).XTickLabelMode = 'auto';
                targetAxes(k).YTickLabelMode = 'auto';
                axisDescendants = findall(targetAxes(k));
                axisDescendants(axisDescendants == targetAxes(k)) = [];
                if ~isempty(axisDescendants)
                    set(axisDescendants, 'Visible', 'on');
                end
            end
        end

        function RawRxDropDownValueChanged(app, event)
            if strcmp(app.ViewDropDown.Value, '原始 ADC 数据图')
                updateRawAdcView(app, round(app.FrameSlider.Value));
            end
        end

        function RawChirpSpinnerValueChanged(app, event)
            app.RawChirpSpinner.Value = round(app.RawChirpSpinner.Value);
            if strcmp(app.ViewDropDown.Value, '原始 ADC 数据图')
                updateRawAdcView(app, round(app.FrameSlider.Value));
            end
        end

        function RawWaveformModeDropDownValueChanged(app, event)
            if strcmp(app.ViewDropDown.Value, '原始 ADC 数据图')
                updateRawAdcView(app, round(app.FrameSlider.Value));
            end
        end

        function FFT1DRxDropDownValueChanged(app, event)
            if strcmp(app.ViewDropDown.Value, '一维 FFT 图')
                updateFFT1DView(app, round(app.FrameSlider.Value));
            end
        end

        function FFT1DChirpSpinnerValueChanged(app, event)
            app.FFT1DChirpSpinner.Value = round(app.FFT1DChirpSpinner.Value);
            if strcmp(app.ViewDropDown.Value, '一维 FFT 图')
                updateFFT1DView(app, round(app.FrameSlider.Value));
            end
        end

        % Button pushed function: UnwrapBtn
        function UnwrapBtnButtonPushed(app, event)
            % 1. 获取输入值
            v_approx = app.ApproxSpeedEdit.Value;
            v_wrapped = app.ApproxSpeedEdit_2.Value;
            perpDistance = abs(app.PerpDistanceEdit.Value);
            radarRange = app.TargetRangeEdit.Value;
            
            % 2. 动态计算当前配置下的最大不模糊速度 Vmax
            v_max = (app.cfg_WinSize / 2) * app.delta_v;

            if isempty(v_max) || ~isfinite(v_max) || v_max <= 0
                uialert(app.UIFigure, '请先加载数据，使速度轴参数生效。', '解模糊失败');
                return;
            end
            if radarRange <= 0 || perpDistance >= radarRange
                uialert(app.UIFigure, '当前目标距离雷达的距离必须大于雷达到轨迹的垂直距离。', '解模糊失败');
                return;
            end
            
            % 3. 几何投影：径向速度 = 目标轨迹速度 * cos(theta)
            alongTrackDistance = sqrt(radarRange^2 - perpDistance^2);
            radialProjection = alongTrackDistance / radarRange;
            approxRadialSpeedAbs = abs(v_approx) * radialProjection;

            % 4. 在所有可能的解模糊径向速度中，选择还原目标速度最接近大致速度的解。
            maxWrap = ceil((approxRadialSpeedAbs + 4 * v_max) / (2 * v_max)) + 3;
            wrapCandidates = -maxWrap:maxWrap;
            radialCandidates = v_wrapped + wrapCandidates * (2 * v_max);
            signedTargetSpeedCandidates = radialCandidates / radialProjection;
            [~, bestIdx] = min(abs(signedTargetSpeedCandidates - v_approx));
            n_wrap = wrapCandidates(bestIdx);
            radial_unwrapped = radialCandidates(bestIdx);
            target_speed = abs(radial_unwrapped) / radialProjection;
            if v_approx == 0
                signed_target_speed = 0;
            else
                signed_target_speed = sign(v_approx) * target_speed;
            end
            
            % 5. 打印结果到运行日志
            app.LogTextArea.Value = [app.LogTextArea.Value; {'------------------------------------'}];
            app.LogTextArea.Value = [app.LogTextArea.Value; {sprintf('【单目标几何解模糊计算】')}];
            app.LogTextArea.Value = [app.LogTextArea.Value; {sprintf('目标大致速度: %.2f m/s', v_approx)}];
            app.LogTextArea.Value = [app.LogTextArea.Value; {sprintf('有模糊径向速度: %.2f m/s', v_wrapped)}];
            app.LogTextArea.Value = [app.LogTextArea.Value; {sprintf('雷达到轨迹垂距: %.3f m', perpDistance)}];
            app.LogTextArea.Value = [app.LogTextArea.Value; {sprintf('当前目标距雷达: %.3f m', radarRange)}];
            app.LogTextArea.Value = [app.LogTextArea.Value; {sprintf('径向投影系数 cos(theta): %.6f', radialProjection)}];
            app.LogTextArea.Value = [app.LogTextArea.Value; {sprintf('由大致速度估计的径向速度幅值: %.2f m/s', approxRadialSpeedAbs)}];
            app.LogTextArea.Value = [app.LogTextArea.Value; {sprintf('当前系统 Vmax: ±%.2f m/s', v_max)}];
            app.LogTextArea.Value = [app.LogTextArea.Value; {sprintf('解模糊径向速度: %.2f m/s (折叠 %d 次)', radial_unwrapped, n_wrap)}];
            app.LogTextArea.Value = [app.LogTextArea.Value; {sprintf('>>> 目标速度大小: %.2f m/s，带符号速度: %.2f m/s <<<', target_speed, signed_target_speed)}];
            app.LogTextArea.Value = [app.LogTextArea.Value; {'------------------------------------'}];
            
            % 6. 自动滚动到底部
            scroll(app.LogTextArea, 'bottom');
        end

        % Button pushed function: SettingsBtn
        function SettingsBtnButtonPushed(app, event)
            % 1. 创建模态弹窗 (WindowStyle='modal' 意味着不关掉它就不能点主界面)
            setFig = uifigure('Name', '参数配置', 'Position', [500, 70, 420, 820], 'WindowStyle', 'modal');
            try
                setFig.Scrollable = 'on';
            catch
            end
            setFig.Position = [500, 40, 420, 910];

            % --- Max SNR selection range ---
            uilabel(setFig, 'Position', [20, 870, 220, 22], 'Text', '最大 SNR 选点范围', 'FontWeight', 'bold');
            uilabel(setFig, 'Position', [20, 835, 150, 22], 'Text', '距离范围 (m):');
            editMaxSnrRangeMin = uieditfield(setFig, 'numeric', 'Position', [190, 835, 55, 22], 'Value', app.cfg_MaxSnrRangeMin);
            uilabel(setFig, 'Position', [252, 835, 15, 22], 'Text', '~');
            editMaxSnrRangeMax = uieditfield(setFig, 'numeric', 'Position', [270, 835, 55, 22], 'Value', app.cfg_MaxSnrRangeMax);
            uilabel(setFig, 'Position', [20, 800, 160, 22], 'Text', '有模糊速度范围 (m/s):');
            editMaxSnrVelocityMin = uieditfield(setFig, 'numeric', 'Position', [190, 800, 55, 22], 'Value', app.cfg_MaxSnrVelocityMin);
            uilabel(setFig, 'Position', [252, 800, 15, 22], 'Text', '~');
            editMaxSnrVelocityMax = uieditfield(setFig, 'numeric', 'Position', [270, 800, 55, 22], 'Value', app.cfg_MaxSnrVelocityMax);
            
            % --- 采集保存区 ---
            uilabel(setFig, 'Position', [20, 770, 150, 22], 'Text', '【采集保存】', 'FontWeight', 'bold');
            uilabel(setFig, 'Position', [20, 735, 150, 22], 'Text', '采集数据量 (MB):');
            editCaptureSize = uieditfield(setFig, 'numeric', 'Position', [190, 735, 120, 22], 'Value', app.cfg_CaptureSizeMB, 'Limits', [1 Inf]);

            % --- 雷达 Chirp 参数区 ---
            uilabel(setFig, 'Position', [20, 695, 220, 22], 'Text', '【雷达 Chirp / 采样参数】', 'FontWeight', 'bold');
            uilabel(setFig, 'Position', [20, 660, 150, 22], 'Text', '起始频率 (GHz):');
            editStartFreq = uieditfield(setFig, 'numeric', 'Position', [190, 660, 120, 22], 'Value', app.cfg_StartFreqGHz, 'Limits', [1 Inf]);
            uilabel(setFig, 'Position', [20, 625, 150, 22], 'Text', '调频斜率 (MHz/us):');
            editSlope = uieditfield(setFig, 'numeric', 'Position', [190, 625, 120, 22], 'Value', app.cfg_Slope, 'Limits', [eps Inf]);
            uilabel(setFig, 'Position', [20, 590, 150, 22], 'Text', 'ADC采样点数(固件):');
            editSamples = uieditfield(setFig, 'numeric', 'Position', [190, 590, 120, 22], 'Value', app.cfg_Samples, 'Limits', [1 Inf]);
            uilabel(setFig, 'Position', [20, 555, 150, 22], 'Text', 'ADC采样率 (Msps):');
            editRate = uieditfield(setFig, 'numeric', 'Position', [190, 555, 120, 22], 'Value', app.cfg_AdcSampleRate, 'Limits', [eps Inf]);
            uilabel(setFig, 'Position', [20, 520, 150, 22], 'Text', 'Chirp周期 (us):');
            editChirpPeriod = uieditfield(setFig, 'numeric', 'Position', [190, 520, 120, 22], 'Value', app.cfg_ChirpPeriodUs, 'Limits', [eps Inf]);
            uilabel(setFig, 'Position', [20, 485, 150, 22], 'Text', '每帧 Chirp 数:');
            editChirps = uieditfield(setFig, 'numeric', 'Position', [190, 485, 120, 22], 'Value', app.cfg_Chirps, 'Limits', [1 Inf]);
            uilabel(setFig, 'Position', [20, 450, 150, 22], 'Text', 'TX数量:');
            editNumTx = uieditfield(setFig, 'numeric', 'Position', [190, 450, 120, 22], 'Value', app.cfg_NumTx, 'Limits', [1 Inf]);
            uilabel(setFig, 'Position', [20, 415, 150, 22], 'Text', 'RX数量:');
            editNumRx = uieditfield(setFig, 'numeric', 'Position', [190, 415, 120, 22], 'Value', app.cfg_NumRx, 'Limits', [1 Inf]);
            
            % --- FFT / 滑窗参数区 ---
            uilabel(setFig, 'Position', [20, 370, 220, 22], 'Text', '【FFT / 滑动窗口参数】', 'FontWeight', 'bold', 'FontColor', [0 0 0.8]);
            uilabel(setFig, 'Position', [20, 335, 150, 22], 'Text', '距离FFT点数:');
            editRangeFft = uieditfield(setFig, 'numeric', 'Position', [190, 335, 120, 22], 'Value', app.cfg_RangeFftSize, 'Limits', [1 Inf]);
            uilabel(setFig, 'Position', [20, 300, 150, 22], 'Text', '角度FFT点数:');
            editAngleFft = uieditfield(setFig, 'numeric', 'Position', [190, 300, 120, 22], 'Value', app.cfg_AngleFftSize, 'Limits', [1 Inf]);
            uilabel(setFig, 'Position', [20, 265, 150, 22], 'Text', '窗口大小 (Chirps):');
            editWinSize = uieditfield(setFig, 'numeric', 'Position', [190, 265, 120, 22], 'Value', app.cfg_WinSize, 'Limits', [1 Inf]);
            uilabel(setFig, 'Position', [20, 230, 150, 22], 'Text', '滑动步进 (Chirps):');
            editWinStep = uieditfield(setFig, 'numeric', 'Position', [190, 230, 120, 22], 'Value', app.cfg_WinStep, 'Limits', [1 Inf]);

            % --- CFAR 参数区 ---
            uilabel(setFig, 'Position', [20, 185, 150, 22], 'Text', '【CFAR 算法参数】', 'FontWeight', 'bold');
            uilabel(setFig, 'Position', [20, 150, 150, 22], 'Text', '距离/速度 参考(Tr,Td):');
            editTr = uieditfield(setFig, 'numeric', 'Position', [190, 150, 55, 22], 'Value', app.cfg_Tr, 'Limits', [0 Inf]);
            editTd = uieditfield(setFig, 'numeric', 'Position', [255, 150, 55, 22], 'Value', app.cfg_Td, 'Limits', [0 Inf]);
            uilabel(setFig, 'Position', [20, 115, 150, 22], 'Text', '保护单元 (Gr,Gd):');
            editGr = uieditfield(setFig, 'numeric', 'Position', [190, 115, 55, 22], 'Value', app.cfg_Gr, 'Limits', [0 Inf]);
            editGd = uieditfield(setFig, 'numeric', 'Position', [255, 115, 55, 22], 'Value', app.cfg_Gd, 'Limits', [0 Inf]);
            uilabel(setFig, 'Position', [20, 80, 150, 22], 'Text', '检测阈值 (Offset dB):');
            editOffset = uieditfield(setFig, 'numeric', 'Position', [190, 80, 120, 22], 'Value', app.cfg_offset_dB);
            
            % --- 保存按钮 ---
            btnSave = uibutton(setFig, 'push', 'Position', [145, 25, 120, 30], 'Text', '保存并应用', 'BackgroundColor', [0.85 0.94 0.85]);
            btnSave.ButtonPushedFcn = @(btn, event) saveParams(app, setFig, editCaptureSize, editStartFreq, editSlope, editSamples, editRate, editChirpPeriod, editChirps, editNumTx, editNumRx, editRangeFft, editAngleFft, editWinSize, editWinStep, editTr, editTd, editGr, editGd, editOffset, editMaxSnrRangeMin, editMaxSnrRangeMax, editMaxSnrVelocityMin, editMaxSnrVelocityMax);
            
            function saveParams(app, fig, eCaptureSize, eStartFreq, eSlope, eSamp, eRate, eChirpPeriod, eChirp, eNumTx, eNumRx, eRangeFft, eAngleFft, eWSize, eWStep, eTr, eTd, eGr, eGd, eOff, eMaxSnrRangeMin, eMaxSnrRangeMax, eMaxSnrVelocityMin, eMaxSnrVelocityMax)
                newCaptureSizeMB = eCaptureSize.Value;
                newStartFreqGHz = eStartFreq.Value;
                newSlope = eSlope.Value;
                newSamples = max(1, round(eSamp.Value));
                newAdcSampleRate = eRate.Value;
                newChirpPeriodUs = eChirpPeriod.Value;
                newChirps = max(1, round(eChirp.Value));
                newNumTx = max(1, round(eNumTx.Value));
                newNumRx = max(1, round(eNumRx.Value));
                newRangeFftSize = max(1, round(eRangeFft.Value));
                newAngleFftSize = max(1, round(eAngleFft.Value));
                newWinSize = max(1, round(eWSize.Value));
                newWinStep = max(1, round(eWStep.Value));
                newTr = max(0, round(eTr.Value));
                newTd = max(0, round(eTd.Value));
                newGr = max(0, round(eGr.Value));
                newGd = max(0, round(eGd.Value));
                newOffset = eOff.Value;
                newMaxSnrRangeMin = eMaxSnrRangeMin.Value;
                newMaxSnrRangeMax = eMaxSnrRangeMax.Value;
                newMaxSnrVelocityMin = eMaxSnrVelocityMin.Value;
                newMaxSnrVelocityMax = eMaxSnrVelocityMax.Value;

                if newWinSize > newChirps
                    uialert(fig, '窗口大小不能大于每帧 Chirp 数。', '参数错误');
                    return;
                end
                if newWinStep > newWinSize
                    uialert(fig, '滑动步进建议不大于窗口大小。', '参数错误');
                    return;
                end
                newProcessingSamples = 2 * newSamples;
                if newRangeFftSize < newProcessingSamples
                    uialert(fig, sprintf('距离FFT点数不能小于实际处理点数 %d。', newProcessingSamples), '参数错误');
                    return;
                end

                if newMaxSnrRangeMin > newMaxSnrRangeMax
                    uialert(fig, '最大 SNR 距离范围下限不能大于上限。', '参数错误');
                    return;
                end
                if newMaxSnrVelocityMin > newMaxSnrVelocityMax
                    uialert(fig, '最大 SNR 速度范围下限不能大于上限。', '参数错误');
                    return;
                end

                app.cfg_CaptureSizeMB = newCaptureSizeMB;
                app.cfg_StartFreqGHz = newStartFreqGHz;
                app.cfg_Slope = newSlope;
                app.cfg_Samples = newSamples;
                app.cfg_AdcSampleRate = newAdcSampleRate;
                app.cfg_ChirpPeriodUs = newChirpPeriodUs;
                app.cfg_Chirps = newChirps;
                app.cfg_NumTx = newNumTx;
                app.cfg_NumRx = newNumRx;
                app.cfg_RangeFftSize = newRangeFftSize;
                app.cfg_AngleFftSize = newAngleFftSize;
                app.cfg_WinSize = newWinSize;
                app.cfg_WinStep = newWinStep;
                app.cfg_Tr = newTr;
                app.cfg_Td = newTd;
                app.cfg_Gr = newGr;
                app.cfg_Gd = newGd;
                app.cfg_offset_dB = newOffset;
                app.cfg_MaxSnrRangeMin = newMaxSnrRangeMin;
                app.cfg_MaxSnrRangeMax = newMaxSnrRangeMax;
                app.cfg_MaxSnrVelocityMin = newMaxSnrVelocityMin;
                app.cfg_MaxSnrVelocityMax = newMaxSnrVelocityMax;

                clearTrendCache(app);
                resetFitPlot(app);
                prepareCaptureJson(app, false);
                delete(fig);
                uialert(app.UIFigure, '参数已保存！请点击【加载文件】重新切分数据并生效。', '设置成功', 'Icon', 'success');
            end
        end

        % Button pushed function: PrevButton
        function PrevButtonPushed(app, event)
            if app.PlayButton.Value == 1, app.PlayButton.Value = 0; end % 停止播放
            
            % 这里的 currentIdx 代表的是滑窗的序号
            currentIdx = round(app.FrameSlider.Value);
            if currentIdx > 1
                newIdx = currentIdx - 1;
                app.FrameSlider.Value = newIdx;
                app.updateFrame(newIdx);
            end
        end

        % Button pushed function: NextButton
        function NextButtonPushed(app, event)
            if app.PlayButton.Value == 1, app.PlayButton.Value = 0; end
            
            currentIdx = round(app.FrameSlider.Value);
            % 使用滑轨的最大值作为判定边界
            if currentIdx < app.FrameSlider.Limits(2)
                newIdx = currentIdx + 1;
                app.FrameSlider.Value = newIdx;
                app.updateFrame(newIdx);
            end
        end

        % Value changed function: PlayButton
        function PlayButtonValueChanged(app, event)
            if app.PlayButton.Value == 1
                app.PlayButton.Text = '⏸ 暂停';
                app.PlayButton.FontColor = [0.8 0 0];
                
                % 播放主循环
                while app.PlayButton.Value == 1 && isvalid(app)
                    currentIdx = round(app.FrameSlider.Value);
                    nextIdx = currentIdx + 1;
                    
                    % 如果超过了滑轨上限，回到第 1 个滑窗
                    if nextIdx > app.FrameSlider.Limits(2)
                        nextIdx = 1; 
                    end
                    
                    app.FrameSlider.Value = nextIdx;
                    app.updateFrame(nextIdx);
                    
                    drawnow; % 处理 UI 事件
                    
                    if app.PlayButton.Value == 0, break; end
                    
                    % 建议加一个极小的 pause，防止 CPU 跑满导致界面卡顿
                    pause(0.01); 
                end
                
                % 退出循环后的重置
                if isvalid(app)
                    app.PlayButton.Text = '▶ 播放';
                    app.PlayButton.FontColor = [0 0 0];
                    app.PlayButton.Value = 0;
                end
            else
                app.PlayButton.Text = '▶ 播放';
                app.PlayButton.FontColor = [0 0 0];
            end
        end

        % Close request function: UIFigure
        function UIFigureCloseRequest(app, event)
            if ~isempty(app.fp)
                fclose(app.fp);
            end
            delete(app);
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 931 634];
            app.UIFigure.Name = 'MATLAB App';
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);

            % Create UIAxes_RD
            app.UIAxes_RD = uiaxes(app.UIFigure);
            title(app.UIAxes_RD, 'Range-Doppler 热力图')
            xlabel(app.UIAxes_RD, 'X')
            ylabel(app.UIAxes_RD, 'Y')
            zlabel(app.UIAxes_RD, 'Z')
            app.UIAxes_RD.Position = [395 96 509 502];

            % Create UIAxes_PC
            app.UIAxes_PC = uiaxes(app.UIFigure);
            title(app.UIAxes_PC, '最大 SNR 点距离趋势')
            xlabel(app.UIAxes_PC, 'X')
            ylabel(app.UIAxes_PC, 'Y')
            zlabel(app.UIAxes_PC, 'Z')
            app.UIAxes_PC.Toolbar.Visible = 'off';
            app.UIAxes_PC.Visible = 'off';
            app.UIAxes_PC.Position = [395 352 509 246];

            % Create UIAxes_TrendVelocity
            app.UIAxes_TrendVelocity = uiaxes(app.UIFigure);
            title(app.UIAxes_TrendVelocity, '最大 SNR 点速度趋势')
            xlabel(app.UIAxes_TrendVelocity, 'X')
            ylabel(app.UIAxes_TrendVelocity, 'Y')
            zlabel(app.UIAxes_TrendVelocity, 'Z')
            app.UIAxes_TrendVelocity.Toolbar.Visible = 'off';
            app.UIAxes_TrendVelocity.Visible = 'off';
            app.UIAxes_TrendVelocity.Position = [395 96 509 246];

            % Create UIAxes_FitRange
            app.UIAxes_FitRange = uiaxes(app.UIFigure);
            title(app.UIAxes_FitRange, '拟合距离趋势')
            xlabel(app.UIAxes_FitRange, 'Frame Index')
            ylabel(app.UIAxes_FitRange, 'Range (m)')
            zlabel(app.UIAxes_FitRange, 'Z')
            app.UIAxes_FitRange.Toolbar.Visible = 'off';
            app.UIAxes_FitRange.Visible = 'off';
            app.UIAxes_FitRange.Position = [395 352 385 246];

            % Create UIAxes_FitVelocity
            app.UIAxes_FitVelocity = uiaxes(app.UIFigure);
            title(app.UIAxes_FitVelocity, '拟合速度趋势')
            xlabel(app.UIAxes_FitVelocity, 'Frame Index')
            ylabel(app.UIAxes_FitVelocity, 'Velocity (m/s)')
            zlabel(app.UIAxes_FitVelocity, 'Z')
            app.UIAxes_FitVelocity.Toolbar.Visible = 'off';
            app.UIAxes_FitVelocity.Visible = 'off';
            app.UIAxes_FitVelocity.Position = [395 96 385 246];

            % Create FitStartLabel
            app.FitStartLabel = uilabel(app.UIFigure);
            app.FitStartLabel.HorizontalAlignment = 'right';
            app.FitStartLabel.Position = [800 448 80 22];
            app.FitStartLabel.Text = '起始帧';
            app.FitStartLabel.Visible = 'off';

            % Create FitStartEdit
            app.FitStartEdit = uieditfield(app.UIFigure, 'numeric');
            app.FitStartEdit.Limits = [1 Inf];
            app.FitStartEdit.RoundFractionalValues = 'on';
            app.FitStartEdit.Position = [800 420 80 22];
            app.FitStartEdit.Value = 1;
            app.FitStartEdit.Visible = 'off';

            % Create FitEndLabel
            app.FitEndLabel = uilabel(app.UIFigure);
            app.FitEndLabel.HorizontalAlignment = 'right';
            app.FitEndLabel.Position = [800 386 80 22];
            app.FitEndLabel.Text = '终点帧';
            app.FitEndLabel.Visible = 'off';

            % Create FitEndEdit
            app.FitEndEdit = uieditfield(app.UIFigure, 'numeric');
            app.FitEndEdit.Limits = [1 Inf];
            app.FitEndEdit.RoundFractionalValues = 'on';
            app.FitEndEdit.Position = [800 358 80 22];
            app.FitEndEdit.Value = 1;
            app.FitEndEdit.Visible = 'off';

            % Create FitConfirmButton
            app.FitConfirmButton = uibutton(app.UIFigure, 'push');
            app.FitConfirmButton.ButtonPushedFcn = createCallbackFcn(app, @FitConfirmButtonPushed, true);
            app.FitConfirmButton.Position = [800 320 80 24];
            app.FitConfirmButton.Text = '确定';
            app.FitConfirmButton.Visible = 'off';

            % Create UIAxes_RD_Real
            app.UIAxes_RD_Real = uiaxes(app.UIFigure);
            title(app.UIAxes_RD_Real, '真实坐标RD图')
            xlabel(app.UIAxes_RD_Real, 'X')
            ylabel(app.UIAxes_RD_Real, 'Y')
            zlabel(app.UIAxes_RD_Real, 'Z')
            app.UIAxes_RD_Real.Toolbar.Visible = 'off';
            app.UIAxes_RD_Real.Visible = 'off';
            app.UIAxes_RD_Real.Position = [395 96 509 502];

            % Create UIAxes_RawADCHeatmap
            app.UIAxes_RawADCHeatmap = uiaxes(app.UIFigure);
            title(app.UIAxes_RawADCHeatmap, '原始 ADC 幅值热力图')
            xlabel(app.UIAxes_RawADCHeatmap, 'Chirp Index')
            ylabel(app.UIAxes_RawADCHeatmap, 'ADC Sample Index')
            zlabel(app.UIAxes_RawADCHeatmap, 'Z')
            app.UIAxes_RawADCHeatmap.Toolbar.Visible = 'off';
            app.UIAxes_RawADCHeatmap.Visible = 'off';
            app.UIAxes_RawADCHeatmap.Position = [395 352 509 246];

            % Create UIAxes_RawADCWaveform
            app.UIAxes_RawADCWaveform = uiaxes(app.UIFigure);
            title(app.UIAxes_RawADCWaveform, '中间 Chirp I/Q 波形')
            xlabel(app.UIAxes_RawADCWaveform, 'ADC Sample Index')
            ylabel(app.UIAxes_RawADCWaveform, 'Amplitude')
            zlabel(app.UIAxes_RawADCWaveform, 'Z')
            app.UIAxes_RawADCWaveform.Toolbar.Visible = 'off';
            app.UIAxes_RawADCWaveform.Visible = 'off';
            app.UIAxes_RawADCWaveform.Position = [395 96 509 246];

            % Create RawRxLabel
            app.RawRxLabel = uilabel(app.UIFigure);
            app.RawRxLabel.HorizontalAlignment = 'right';
            app.RawRxLabel.Position = [800 448 80 22];
            app.RawRxLabel.Text = 'RX通道';
            app.RawRxLabel.Visible = 'off';

            % Create RawRxDropDown
            app.RawRxDropDown = uidropdown(app.UIFigure);
            app.RawRxDropDown.Items = {'RX1'};
            app.RawRxDropDown.ValueChangedFcn = createCallbackFcn(app, @RawRxDropDownValueChanged, true);
            app.RawRxDropDown.Position = [800 420 80 22];
            app.RawRxDropDown.Value = 'RX1';
            app.RawRxDropDown.Visible = 'off';

            % Create RawChirpLabel
            app.RawChirpLabel = uilabel(app.UIFigure);
            app.RawChirpLabel.HorizontalAlignment = 'right';
            app.RawChirpLabel.Position = [800 386 80 22];
            app.RawChirpLabel.Text = 'Chirp';
            app.RawChirpLabel.Visible = 'off';

            % Create RawChirpSpinner
            app.RawChirpSpinner = uispinner(app.UIFigure);
            app.RawChirpSpinner.Limits = [1 Inf];
            app.RawChirpSpinner.RoundFractionalValues = 'on';
            app.RawChirpSpinner.ValueChangedFcn = createCallbackFcn(app, @RawChirpSpinnerValueChanged, true);
            app.RawChirpSpinner.Position = [800 358 80 22];
            app.RawChirpSpinner.Value = 1;
            app.RawChirpSpinner.Visible = 'off';

            % Create RawWaveformModeLabel
            app.RawWaveformModeLabel = uilabel(app.UIFigure);
            app.RawWaveformModeLabel.HorizontalAlignment = 'right';
            app.RawWaveformModeLabel.Position = [800 324 80 22];
            app.RawWaveformModeLabel.Text = '波形模式';
            app.RawWaveformModeLabel.Visible = 'off';

            % Create RawWaveformModeDropDown
            app.RawWaveformModeDropDown = uidropdown(app.UIFigure);
            app.RawWaveformModeDropDown.Items = {'去均值I/Q', '原始I/Q', '相邻差分I/Q'};
            app.RawWaveformModeDropDown.ValueChangedFcn = createCallbackFcn(app, @RawWaveformModeDropDownValueChanged, true);
            app.RawWaveformModeDropDown.Position = [800 292 100 22];
            app.RawWaveformModeDropDown.Value = '去均值I/Q';
            app.RawWaveformModeDropDown.Visible = 'off';

            % Create UIAxes_FFT1DHeatmap
            app.UIAxes_FFT1DHeatmap = uiaxes(app.UIFigure);
            title(app.UIAxes_FFT1DHeatmap, '一维 FFT 热力图')
            xlabel(app.UIAxes_FFT1DHeatmap, 'Chirp Index')
            ylabel(app.UIAxes_FFT1DHeatmap, 'Range Bin')
            zlabel(app.UIAxes_FFT1DHeatmap, 'Z')
            app.UIAxes_FFT1DHeatmap.Toolbar.Visible = 'off';
            app.UIAxes_FFT1DHeatmap.Visible = 'off';
            app.UIAxes_FFT1DHeatmap.Position = [395 352 509 246];

            % Create UIAxes_FFT1DLine
            app.UIAxes_FFT1DLine = uiaxes(app.UIFigure);
            title(app.UIAxes_FFT1DLine, '选定 Chirp 一维 FFT')
            xlabel(app.UIAxes_FFT1DLine, 'Range Bin')
            ylabel(app.UIAxes_FFT1DLine, 'Magnitude (dB)')
            zlabel(app.UIAxes_FFT1DLine, 'Z')
            app.UIAxes_FFT1DLine.Toolbar.Visible = 'off';
            app.UIAxes_FFT1DLine.Visible = 'off';
            app.UIAxes_FFT1DLine.Position = [395 96 509 246];

            % Create FFT1DRxLabel
            app.FFT1DRxLabel = uilabel(app.UIFigure);
            app.FFT1DRxLabel.HorizontalAlignment = 'right';
            app.FFT1DRxLabel.Position = [800 448 80 22];
            app.FFT1DRxLabel.Text = 'RX通道';
            app.FFT1DRxLabel.Visible = 'off';

            % Create FFT1DRxDropDown
            app.FFT1DRxDropDown = uidropdown(app.UIFigure);
            app.FFT1DRxDropDown.Items = {'RX1'};
            app.FFT1DRxDropDown.ValueChangedFcn = createCallbackFcn(app, @FFT1DRxDropDownValueChanged, true);
            app.FFT1DRxDropDown.Position = [800 420 80 22];
            app.FFT1DRxDropDown.Value = 'RX1';
            app.FFT1DRxDropDown.Visible = 'off';

            % Create FFT1DChirpLabel
            app.FFT1DChirpLabel = uilabel(app.UIFigure);
            app.FFT1DChirpLabel.HorizontalAlignment = 'right';
            app.FFT1DChirpLabel.Position = [800 386 80 22];
            app.FFT1DChirpLabel.Text = 'Chirp';
            app.FFT1DChirpLabel.Visible = 'off';

            % Create FFT1DChirpSpinner
            app.FFT1DChirpSpinner = uispinner(app.UIFigure);
            app.FFT1DChirpSpinner.Limits = [1 Inf];
            app.FFT1DChirpSpinner.RoundFractionalValues = 'on';
            app.FFT1DChirpSpinner.ValueChangedFcn = createCallbackFcn(app, @FFT1DChirpSpinnerValueChanged, true);
            app.FFT1DChirpSpinner.Position = [800 358 80 22];
            app.FFT1DChirpSpinner.Value = 1;
            app.FFT1DChirpSpinner.Visible = 'off';

            % Create DataPathEdit
            app.DataPathEdit = uieditfield(app.UIFigure, 'text');
            app.DataPathEdit.Position = [92 576 259 22];
            app.DataPathEdit.Value = 'C:\ti\DATA\AWR2243\am273x__Raw_0.bin';

            % Create DataPathBrowseButton
            app.DataPathBrowseButton = uibutton(app.UIFigure, 'push');
            app.DataPathBrowseButton.ButtonPushedFcn = createCallbackFcn(app, @DataPathBrowseButtonPushed, true);
            app.DataPathBrowseButton.Position = [356 576 21 22];
            app.DataPathBrowseButton.Text = '...';

            % Create LoadBtn
            app.LoadBtn = uibutton(app.UIFigure, 'push');
            app.LoadBtn.ButtonPushedFcn = createCallbackFcn(app, @LoadBtnButtonPushed, true);
            app.LoadBtn.Position = [135 376 74 23];
            app.LoadBtn.Text = '加载文件';

            % Create ViewDropDown
            app.ViewDropDown = uidropdown(app.UIFigure);
            app.ViewDropDown.Items = {'频点 RD 图', '物理坐标 RD 图', '原始 ADC 数据图', '一维 FFT 图', '最大 SNR 趋势图', '拟合趋势图'};
            app.ViewDropDown.ValueChangedFcn = createCallbackFcn(app, @ViewDropDownValueChanged, true);
            app.ViewDropDown.Position = [479 20 110 22];
            app.ViewDropDown.Value = '频点 RD 图';

            % Create Label
            app.Label = uilabel(app.UIFigure);
            app.Label.HorizontalAlignment = 'right';
            app.Label.Position = [24 466 53 22];
            app.Label.Text = '大致速度';

            % Create ApproxSpeedEdit
            app.ApproxSpeedEdit = uieditfield(app.UIFigure, 'numeric');
            app.ApproxSpeedEdit.Position = [92 466 80 22];

            % Create UnwrapBtn
            app.UnwrapBtn = uibutton(app.UIFigure, 'push');
            app.UnwrapBtn.ButtonPushedFcn = createCallbackFcn(app, @UnwrapBtnButtonPushed, true);
            app.UnwrapBtn.Position = [241 376 74 23];
            app.UnwrapBtn.Text = '解模糊';

            % Create Label_2
            app.Label_2 = uilabel(app.UIFigure);
            app.Label_2.HorizontalAlignment = 'right';
            app.Label_2.Position = [24 576 53 22];
            app.Label_2.Text = '文件路径';

            % Create Label_3
            app.Label_3 = uilabel(app.UIFigure);
            app.Label_3.HorizontalAlignment = 'right';
            app.Label_3.Position = [29 538 48 22];
            app.Label_3.Text = 'CLI路径';

            % Create CLIPathEditField
            app.CLIPathEditField = uieditfield(app.UIFigure, 'text');
            app.CLIPathEditField.Position = [92 538 259 22];
            app.CLIPathEditField.Value = 'C:\ti\mmwave_studio_03_00_00_14\mmWaveStudio\PostProc';

            % Create CLIPathBrowseButton
            app.CLIPathBrowseButton = uibutton(app.UIFigure, 'push');
            app.CLIPathBrowseButton.ButtonPushedFcn = createCallbackFcn(app, @CLIPathBrowseButtonPushed, true);
            app.CLIPathBrowseButton.Position = [356 538 21 22];
            app.CLIPathBrowseButton.Text = '...';

            % Create Label_4
            app.Label_4 = uilabel(app.UIFigure);
            app.Label_4.HorizontalAlignment = 'right';
            app.Label_4.Position = [16 500 61 22];
            app.Label_4.Text = 'JSON路径';

            % Create JSONPathEditField
            app.JSONPathEditField = uieditfield(app.UIFigure, 'text');
            app.JSONPathEditField.Position = [92 500 259 22];
            app.JSONPathEditField.Value = 'C:\ti\mmwave_studio_03_00_00_14\mmWaveStudio\PostProc\AM273X_Capture.json';

            % Create JSONPathBrowseButton
            app.JSONPathBrowseButton = uibutton(app.UIFigure, 'push');
            app.JSONPathBrowseButton.ButtonPushedFcn = createCallbackFcn(app, @JSONPathBrowseButtonPushed, true);
            app.JSONPathBrowseButton.Position = [356 500 21 22];
            app.JSONPathBrowseButton.Text = '...';

            % Create FPGAButton
            app.FPGAButton = uibutton(app.UIFigure, 'push');
            app.FPGAButton.ButtonPushedFcn = createCallbackFcn(app, @FPGAButtonPushed, true);
            app.FPGAButton.Position = [29 336 74 23];
            app.FPGAButton.Text = '配置FPGA';

            % Create StartButton
            app.StartButton = uibutton(app.UIFigure, 'push');
            app.StartButton.ButtonPushedFcn = createCallbackFcn(app, @StartButtonPushed, true);
            app.StartButton.Position = [135 336 74 23];
            app.StartButton.Text = '开始采集';

            % Create StopButton
            app.StopButton = uibutton(app.UIFigure, 'push');
            app.StopButton.ButtonPushedFcn = createCallbackFcn(app, @StopButtonPushed, true);
            app.StopButton.Position = [239 336 74 23];
            app.StopButton.Text = '停止采集';


            % Create ProcessButton
            app.ProcessButton = uibutton(app.UIFigure, 'push');
            app.ProcessButton.ButtonPushedFcn = ...
                createCallbackFcn(app, @ProcessButtonPushed, true);
            app.ProcessButton.Position = [319 336 58 23];
            app.ProcessButton.Text = '数据处理';

            % Create LogTextArea
            app.LogTextArea = uitextarea(app.UIFigure);
            app.LogTextArea.Position = [29 1 348 315];

            % Create FrameSlider
            app.FrameSlider = uislider(app.UIFigure);
            app.FrameSlider.MajorTicks = [];
            app.FrameSlider.MajorTickLabels = {''};
            app.FrameSlider.ValueChangedFcn = createCallbackFcn(app, @FrameSliderValueChanged, true);
            app.FrameSlider.MinorTicks = [0 4 8 12 16 20 24 28 32 36 40 44 48 52 56 60 64 68 72 76 80 84 88 92 96 100];
            app.FrameSlider.FontColor = [1 1 1];
            app.FrameSlider.Position = [632 30 150 3];

            % Create Label_5
            app.Label_5 = uilabel(app.UIFigure);
            app.Label_5.HorizontalAlignment = 'right';
            app.Label_5.Position = [176 466 79 22];
            app.Label_5.Text = '有模糊速度';

            app.Label_5.Text = '模糊径向速度';

            % Create ApproxSpeedEdit_2
            app.ApproxSpeedEdit_2 = uieditfield(app.UIFigure, 'numeric');
            app.ApproxSpeedEdit_2.Position = [270 466 80 22];

            % Create Label_6
            app.Label_6 = uilabel(app.UIFigure);
            app.Label_6.HorizontalAlignment = 'right';
            app.Label_6.Position = [24 426 53 22];
            app.Label_6.Text = '垂距(m)';

            % Create PerpDistanceEdit
            app.PerpDistanceEdit = uieditfield(app.UIFigure, 'numeric');
            app.PerpDistanceEdit.Limits = [0 Inf];
            app.PerpDistanceEdit.Position = [92 426 80 22];

            % Create Label_7
            app.Label_7 = uilabel(app.UIFigure);
            app.Label_7.HorizontalAlignment = 'right';
            app.Label_7.Position = [190 426 65 22];
            app.Label_7.Text = '目标距(m)';

            % Create TargetRangeEdit
            app.TargetRangeEdit = uieditfield(app.UIFigure, 'numeric');
            app.TargetRangeEdit.Limits = [eps Inf];
            app.TargetRangeEdit.Position = [270 426 80 22];
            app.TargetRangeEdit.Value = 1;

            % Create SettingsBtn
            app.SettingsBtn = uibutton(app.UIFigure, 'push');
            app.SettingsBtn.ButtonPushedFcn = createCallbackFcn(app, @SettingsBtnButtonPushed, true);
            app.SettingsBtn.Position = [29 376 74 23];
            app.SettingsBtn.Text = '参数配置';

            % Create FrameLabel
            app.FrameLabel = uilabel(app.UIFigure);
            app.FrameLabel.Position = [589 50 276 24];
            app.FrameLabel.Text = 'Frame: 1 / N';

            % Create PlayButton
            app.PlayButton = uibutton(app.UIFigure, 'state');
            app.PlayButton.ValueChangedFcn = createCallbackFcn(app, @PlayButtonValueChanged, true);
            app.PlayButton.Text = '▶ 播放';
            app.PlayButton.Position = [847 19 54 23];

            % Create PrevButton
            app.PrevButton = uibutton(app.UIFigure, 'push');
            app.PrevButton.ButtonPushedFcn = createCallbackFcn(app, @PrevButtonPushed, true);
            app.PrevButton.Position = [604 20 20 23];
            app.PrevButton.Text = '<';

            % Create NextButton
            app.NextButton = uibutton(app.UIFigure, 'push');
            app.NextButton.ButtonPushedFcn = createCallbackFcn(app, @NextButtonPushed, true);
            app.NextButton.Position = [790 20 21 23];
            app.NextButton.Text = '>';

            % Initialize bundled third-party paths before showing the figure
            initializeBundledPaths(app)

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = RadarControlMachineApp

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)


            % Close the optional processing window first.
            try
                if ~isempty(app.processingWindow) ...
                        && isvalid(app.processingWindow)
                    delete(app.processingWindow);
                end
            catch
            end

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end
