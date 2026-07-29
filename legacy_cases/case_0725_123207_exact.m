clear;
clc;
close all;

%% =========================================================
%  plot_chirp_range_time.m
%
%  功能：
%  1. 逐 Chirp 原始距离-时间图
%  2. 使用枪击前帧进行背景扣除
%  3. 对每个短时窗口计算完整二维 RD 功率图，并进行功率域背景增强
%  4. 在背景增强后的速度区域内压缩并提取多个候选点
%  5. 联合距离直线连续性与“循环有模糊速度连续性”筛选目标轨迹
%  6. 使用实测速度先验和全局动态规划完成速度解模糊
%% =========================================================

%% 1. 原始数据与雷达参数

cfg.numSamples = 64;               % 每个 Chirp ADC 采样点数
cfg.numChirpsPerFrame = 256;       % 每个物理帧 Chirp 数
cfg.numRx = 8;                     % 接收通道数
cfg.numTx = 1;                     % 单发射
cfg.rangeFftSize = 128;            % 距离 FFT 点数

cfg.adcSampleRate = 10e6;          % Hz
cfg.slope = 60.01e12;              % Hz/s
cfg.startFreq = 77e9;              % Hz

cfg.chirpPeriod = 12e-6;           % s
cfg.framePeriod = 3.5e-3;          % s
cfg.c = 3e8;

%% 2. 距离-Doppler 处理参数

% 对当前这组跨越速度模糊边界的数据，先使用 32/32。
% 后续需要提高时间更新率时，可使用 winSize=32、winStep=16。
cfg.winSize = 16;
cfg.winStep = 16;

% 实际参与相干处理的 Chirp 数仍为 winSize。
% Doppler FFT 零填充到 128 点，用于细化速度轴采样和峰值位置估计。
% 真实速度分辨率仍由 winSize=32 决定，不会因零填充而提高。
cfg.dopplerFftSize = 128;

% 为保留刚出枪口时 20~50 m/s 的径向速度阶段，门限不设为 50。
cfg.highSpeedMin = 20;             % 仅保留 |v_alias| >= 20 m/s

% 当前目标预计只位于近距离区域，缩小距离门限可减少远处杂波。
cfg.candidateRangeMin = 0.25;      % m
cfg.candidateRangeMax = 3.00;      % m

cfg.maxCandidatesPerWindow = 6;    % 每窗口最多保留的候选峰
cfg.candidateThresholdDb = 3.0;    % 相对背景门限，dB
cfg.minCandidateSeparation = 0.25; % 同窗口候选最小距离间隔，m
cfg.rangeSmoothBins = 3;           % 距离轮廓平滑点数

%% 3. 联合轨迹筛选参数

% 最终目标距离斜率的合理范围。
cfg.fitSpeedMin = 250;             % m/s
cfg.fitSpeedMax = 650;             % m/s

% 生成两点直线假设时，至少跨越的时间。
cfg.minHypothesisSpanMs = 0.60;    % ms

% 单个候选相对于假设轨迹的最大距离偏差。
cfg.trackTolerance = 0.50;         % m

% 候选有模糊速度与假设速度折叠值的最大循环差。
% +70 m/s 和 -80 m/s 在循环速度轴上相距约 12 m/s，而不是 150 m/s。
cfg.velocityTolerance = 70;        % m/s

% 轨迹至少覆盖的短时窗口数。
cfg.minTrackWindows = 5;

% 当前数据中目标约从物理帧 134 的窗口 6 开始出现。
cfg.trackStartTimeMs = 1.80;       % ms

% 联合代价权重。
cfg.velocityCostWeight = 0.60;
cfg.strengthCostWeight = 0.12;

% 最终解模糊速度范围。
cfg.unwrapSpeedMin = 200;          % m/s
cfg.unwrapSpeedMax = 700;          % m/s

% =========================================================
% 已知实测速度辅助解模糊
% =========================================================

% 本发弹丸的独立实测速结果。
cfg.muzzleSpeed = 428.62203;       % m/s

% 实测速度先验允许一定偏差，用于覆盖：
% 测速误差、雷达径向投影误差、空气阻力及散射中心变化。
cfg.muzzleSpeedStd = 35.0;         % m/s

% 距离-时间拟合速度的允许偏差。
cfg.distanceFitSpeedStd = 50.0;    % m/s

% 相邻轨迹点解模糊速度的连续性尺度。
cfg.unwrapContinuityStd = 25.0;    % m/s

% 全局解模糊代价权重。
cfg.unwrapMuzzleWeight = 1.00;
cfg.unwrapFitWeight = 0.45;
cfg.unwrapContinuityWeight = 0.80;

% 模糊数搜索范围。
cfg.ambiguityNumberMin = -4;
cfg.ambiguityNumberMax = 8;

% 已知出膛速度在候选关联阶段的软约束。
% 只作为代价项，不直接删除候选点。
cfg.muzzleAliasTolerance = 60.0;   % m/s
cfg.muzzleAliasCostWeight = 0.30;

%% 4. 背景帧与目标帧

% 必须确认这些背景帧中没有本次枪击目标。
cfg.backgroundFrameStart = 126;
cfg.backgroundFrameEnd = 133;

cfg.targetFrameStart = 134;
cfg.targetFrameEnd = 135;

%% 5. 图像显示参数

cfg.displayRangeMin = 0;
cfg.displayRangeMax = 10;

cfg.rawDynamicRangeDb = 35;
cfg.chirpEnhancedClim = [0, 15];
cfg.highSpeedClim = [0, 35];

% 二维 RD 连续变化 GIF 设置
cfg.generateRdGif = true;
cfg.rdGifVisible = false;
cfg.rdGifRangeMin = cfg.displayRangeMin;
cfg.rdGifRangeMax = cfg.displayRangeMax;
cfg.rdGifClim = cfg.highSpeedClim;
cfg.rdGifDelayTime = 0.18;
cfg.rdGifResolution = 140;

%% 6. 保存设置

cfg.saveResults = false;

%% 7. 选择 DCA1000 原始数据文件

[fileName, filePath] = uigetfile( ...
    {'*.bin', 'DCA1000 原始数据文件 (*.bin)'}, ...
    '选择需要分析的 Raw 文件');

if isequal(fileName, 0)
    error('未选择数据文件。');
end

binPath = fullfile(filePath, fileName);

if cfg.numTx ~= 1
    error('当前脚本按照单 Tx 数据格式编写，numTx 必须为 1。');
end

%% 8. 文件与帧信息

cfg.complexSamplesPerFrame = ...
    cfg.numSamples * cfg.numChirpsPerFrame * cfg.numRx;

cfg.bytesPerFrame = cfg.complexSamplesPerFrame * 4;
cfg.uint16PerFrame = cfg.complexSamplesPerFrame * 2;

fileInfo = dir(binPath);

if isempty(fileInfo)
    error('无法读取文件信息：%s', binPath);
end

totalFramesInFile = floor(fileInfo.bytes / cfg.bytesPerFrame);
remainingBytes = mod(fileInfo.bytes, cfg.bytesPerFrame);

fprintf('========================================\n');
fprintf('数据文件：%s\n', binPath);
fprintf('文件大小：%d Bytes，%.3f MiB\n', ...
    fileInfo.bytes, fileInfo.bytes / 1024^2);
fprintf('单帧大小：%d Bytes\n', cfg.bytesPerFrame);
fprintf('完整物理帧数：%d\n', totalFramesInFile);
fprintf('尾部剩余字节：%d\n', remainingBytes);
fprintf('========================================\n');

validateFrameRange( ...
    cfg.backgroundFrameStart, cfg.backgroundFrameEnd, ...
    totalFramesInFile, '背景帧');

validateFrameRange( ...
    cfg.targetFrameStart, cfg.targetFrameEnd, ...
    totalFramesInFile, '目标帧');

%% 9. 距离轴与速度轴

derived.rangeBinSpacing = ...
    cfg.c * cfg.adcSampleRate / ...
    (2 * cfg.slope * cfg.rangeFftSize);

derived.rangeAxis = ...
    (0:cfg.rangeFftSize - 1) * derived.rangeBinSpacing;

adcDuration = cfg.numSamples / cfg.adcSampleRate;
bandwidth = cfg.slope * adcDuration;
centerFreq = cfg.startFreq + bandwidth / 2;
derived.lambda = cfg.c / centerFreq;

% 由实际 Chirp 数决定的真实速度分辨率。
derived.deltaV = ...
    derived.lambda / ...
    (2 * cfg.winSize * cfg.chirpPeriod);

% Doppler FFT 零填充后的速度网格间隔。
derived.deltaVDisplay = ...
    derived.lambda / ...
    (2 * cfg.dopplerFftSize * cfg.chirpPeriod);

% 后续候选速度和绘图均使用零填充后的速度网格。
derived.velocityAxis = ...
    (-cfg.dopplerFftSize / 2 : cfg.dopplerFftSize / 2 - 1) ...
    * derived.deltaVDisplay;

% 最大不模糊速度只由 Chirp 周期决定，与零填充点数无关。
derived.vMax = derived.lambda / (4 * cfg.chirpPeriod);
derived.velocityPeriod = 2 * derived.vMax;

% 实测速度折叠到当前不模糊速度区间后的理论位置。
derived.muzzleAliasedSpeed = mod( ...
    cfg.muzzleSpeed + derived.vMax, ...
    derived.velocityPeriod) ...
    - derived.vMax;

derived.highSpeedMask = ...
    abs(derived.velocityAxis) >= cfg.highSpeedMin;

derived.selectedVelocityAxis = ...
    derived.velocityAxis(derived.highSpeedMask);

derived.windowsPerFrame = ...
    floor((cfg.numChirpsPerFrame - cfg.winSize) / cfg.winStep) + 1;

derived.rangeWindow = reshape( ...
    single(hann(cfg.numSamples)), ...
    cfg.numSamples, 1, 1);

derived.dopplerWindow = reshape( ...
    single(hann(cfg.winSize)).', ...
    1, cfg.winSize, 1);

if ~any(derived.highSpeedMask)
    error('高速速度门限过大，没有任何速度单元被保留。');
end

fprintf('距离单元间隔：%.4f m\n', derived.rangeBinSpacing);
fprintf('真实速度分辨率：%.3f m/s\n', derived.deltaV);
fprintf('零填充速度网格间隔：%.3f m/s\n', ...
    derived.deltaVDisplay);
fprintf('实际 Chirp 数 / Doppler FFT 点数：%d / %d\n', ...
    cfg.winSize, cfg.dopplerFftSize);
fprintf('最大不模糊速度：±%.3f m/s\n', derived.vMax);
fprintf('速度模糊周期：%.3f m/s\n', derived.velocityPeriod);
fprintf('实测速度先验：%.5f m/s\n', cfg.muzzleSpeed);
fprintf('实测速度对应理论有模糊速度：%+.3f m/s\n', ...
    derived.muzzleAliasedSpeed);
fprintf('高速速度门限：|v_alias| >= %.1f m/s\n', cfg.highSpeedMin);
fprintf('每物理帧窗口数：%d\n', derived.windowsPerFrame);
fprintf('保留的有模糊速度单元：\n');
disp(derived.selectedVelocityAxis);

%% 10. 打开数据文件

fid = fopen(binPath, 'rb', 'ieee-le');

if fid < 0
    error('无法打开数据文件：%s', binPath);
end

cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

%% 11. 处理枪击前背景帧

fprintf('\n正在处理背景物理帧 %d～%d……\n', ...
    cfg.backgroundFrameStart, cfg.backgroundFrameEnd);

backgroundData = processFrameRange( ...
    fid, cfg.backgroundFrameStart, cfg.backgroundFrameEnd, ...
    cfg, derived);

%% 12. 处理目标帧

fprintf('\n正在处理目标物理帧 %d～%d……\n', ...
    cfg.targetFrameStart, cfg.targetFrameEnd);

targetData = processFrameRange( ...
    fid, cfg.targetFrameStart, cfg.targetFrameEnd, ...
    cfg, derived);

%% 13. 使用枪击前数据建立背景

% 逐 Chirp 距离图仍按原方式在 dB 域建立一维距离背景。
% 该结果只用于 Figure 2 显示，不进入 Doppler FFT。
rangeBackgroundDb = median( ...
    backgroundData.rangeTimeDb, 2, 'omitnan');

rangeTimeEnhanced = ...
    targetData.rangeTimeDb - rangeBackgroundDb;

% =========================================================
% 完整二维 RD 在线性功率域建立背景
%
% 单个窗口：
%   P_RD(r,v,w) = sum_rx |X_RD(r,v,w,rx)|^2
%
% 背景：
%   P_bg(r,v) = median_w P_RD,bg(r,v,w)
%
% 增强：
%   E(r,v,w) = 10log10(P_target(r,v,w) / P_bg(r,v))
% =========================================================

powerFloor = single(1e-12);

rdBackgroundPower = median( ...
    backgroundData.rdPowerCube, ...
    3, ...
    'omitnan');

rdEnhancedDb = ...
    10 * log10( ...
        (targetData.rdPowerCube + powerFloor) ...
        ./ (rdBackgroundPower + powerFloor));

% 生成二维 RD 连续变化 GIF：展示“完整二维 FFT 背景增强 RD 图”
[~, gifBaseName, ~] = fileparts(fileName);
rdGifOutputPath = fullfile( ...
    filePath, ...
    [gifBaseName, '_2D_RD_evolution.gif']);

if cfg.generateRdGif
    fprintf('\n正在生成二维RD连续变化GIF……\n');
    createRdEvolutionGif( ...
        rdEnhancedDb, ...
        targetData, ...
        derived, ...
        cfg, ...
        rdGifOutputPath);
    fprintf('[完成] 二维RD连续变化GIF：\n%s\n', ...
        rdGifOutputPath);
end

% 在二维背景增强完成后，才限制速度区域并沿速度维取最大值。
selectedRdEnhanced = ...
    rdEnhancedDb(:, derived.highSpeedMask, :);

[highSpeedEnhanced, maxVelocityIdx] = max( ...
    selectedRdEnhanced, ...
    [], ...
    2);

highSpeedEnhanced = reshape( ...
    highSpeedEnhanced, ...
    cfg.rangeFftSize, ...
    []);

maxVelocityIdx = reshape( ...
    maxVelocityIdx, ...
    cfg.rangeFftSize, ...
    []);

highSpeedVelocityMap = nan( ...
    size(highSpeedEnhanced), ...
    'single');

for windowIdx = 1:size(highSpeedEnhanced, 2)
    highSpeedVelocityMap(:, windowIdx) = single( ...
        derived.selectedVelocityAxis( ...
            maxVelocityIdx(:, windowIdx)));
end

%% 14. 提取每个窗口的多个高速候选点

candidateTable = extractHighSpeedCandidates( ...
    highSpeedEnhanced, ...
    highSpeedVelocityMap, ...
    targetData, ...
    derived.rangeAxis, ...
    cfg);

fprintf('\n========================================\n');
fprintf('通过门限的高速候选点数量：%d\n', height(candidateTable));
fprintf('========================================\n');

if ~isempty(candidateTable)
    disp(candidateTable);
else
    warning('没有候选点通过当前门限。');
end

%% 15. 联合距离与循环速度连续性筛选轨迹

[trackTable, fitInfo] = selectJointTrack( ...
    candidateTable, cfg, derived);

if fitInfo.valid
    trackTable = unwrapTrackVelocity( ...
        trackTable, derived.vMax, fitInfo.speed, cfg);

    validUnwrapped = isfinite(trackTable.UnwrappedVelocity_mps);

    if any(validUnwrapped)

        % 各解模糊速度点相对实测速度的带符号误差。
        velocityError = ...
            trackTable.UnwrappedVelocity_mps(validUnwrapped) ...
            - cfg.muzzleSpeed;

        fitInfo.meanUnwrappedSpeed = mean( ...
            trackTable.UnwrappedVelocity_mps(validUnwrapped));

        fitInfo.unwrapSpeedStd = std( ...
            trackTable.UnwrappedVelocity_mps(validUnwrapped));

        fitInfo.meanMuzzleResidual = mean(abs(velocityError));

        fitInfo.unwrapSpeedRmse = ...
            sqrt(mean(velocityError .^ 2));

        % 所有解模糊速度点中，相对实测速度最小的绝对误差。
        fitInfo.unwrapSpeedMinAbsError = ...
            min(abs(velocityError));

    else

        fitInfo.meanUnwrappedSpeed = NaN;
        fitInfo.unwrapSpeedStd = NaN;
        fitInfo.meanMuzzleResidual = NaN;
        fitInfo.unwrapSpeedRmse = NaN;
        fitInfo.unwrapSpeedMinAbsError = NaN;
    end

    fprintf('\n========================================\n');
    fprintf('高速目标联合轨迹结果\n');
    fprintf('轨迹点数：%d\n', height(trackTable));
    fprintf('距离拟合速度：%.2f m/s\n', fitInfo.speed);
    fprintf('距离拟合截距：%.3f m\n', fitInfo.intercept);
    fprintf('距离拟合 RMSE：%.3f m\n', fitInfo.rmse);
    fprintf('假设速度折叠值：%.2f m/s\n', fitInfo.expectedAliasedSpeed);
    fprintf('平均循环速度残差：%.2f m/s\n', ...
        fitInfo.meanCircularVelocityResidual);
    fprintf('实测速度：%.5f m/s\n', cfg.muzzleSpeed);
    fprintf('全局解模糊平均速度：%.2f m/s\n', ...
        fitInfo.meanUnwrappedSpeed);
    fprintf('全局解模糊速度标准差：%.2f m/s\n', ...
        fitInfo.unwrapSpeedStd);
    fprintf('解模糊速度相对实测速度平均绝对误差：%.2f m/s\n', ...
        fitInfo.meanMuzzleResidual);
    fprintf('解模糊速度相对实测速度 RMSE：%.2f m/s\n', ...
        fitInfo.unwrapSpeedRmse);
    fprintf('解模糊速度相对实测速度最小绝对误差：%.2f m/s\n', ...
        fitInfo.unwrapSpeedMinAbsError);
    fprintf('========================================\n');

    disp(trackTable);
else
    warning([ ...
        '没有找到满足距离连续性与循环速度连续性的有效轨迹。' ...
        '可依次尝试：降低 candidateThresholdDb、' ...
        '增大 trackTolerance、增大 velocityTolerance。']);
end

%% 16. Figure 1：逐 Chirp 原始距离-时间图

finiteRaw = targetData.rangeTimeDb(isfinite(targetData.rangeTimeDb));
rawMaxDb = max(finiteRaw);

ax1 = drawSegmentedMap( ...
    targetData.chirpTimeMs, ...
    derived.rangeAxis, ...
    targetData.rangeTimeDb, ...
    cfg.numChirpsPerFrame, ...
    targetData.numFrames, ...
    '逐 Chirp 原始距离-时间图', ...
    sprintf('逐 Chirp 原始距离-时间图：物理帧 %d～%d', ...
        cfg.targetFrameStart, cfg.targetFrameEnd), ...
    [cfg.displayRangeMin, cfg.displayRangeMax], ...
    [rawMaxDb - cfg.rawDynamicRangeDb, rawMaxDb]);

addFrameLines( ...
    ax1, targetData.numFrames, ...
    cfg.framePeriod, ...
    cfg.numChirpsPerFrame * cfg.chirpPeriod);

%% 17. Figure 2：背景扣除逐 Chirp 距离-时间图

ax2 = drawSegmentedMap( ...
    targetData.chirpTimeMs, ...
    derived.rangeAxis, ...
    rangeTimeEnhanced, ...
    cfg.numChirpsPerFrame, ...
    targetData.numFrames, ...
    '背景扣除逐 Chirp 距离-时间图', ...
    sprintf('背景扣除逐 Chirp 距离-时间图：物理帧 %d～%d', ...
        cfg.targetFrameStart, cfg.targetFrameEnd), ...
    [cfg.displayRangeMin, cfg.displayRangeMax], ...
    cfg.chirpEnhancedClim);

addFrameLines( ...
    ax2, targetData.numFrames, ...
    cfg.framePeriod, ...
    cfg.numChirpsPerFrame * cfg.chirpPeriod);

%% 18. Figure 3：高速距离-时间图

ax3 = drawSegmentedMap( ...
    targetData.windowTimeMs, ...
    derived.rangeAxis, ...
    highSpeedEnhanced, ...
    derived.windowsPerFrame, ...
    targetData.numFrames, ...
    '高速目标距离-时间图', ...
    sprintf('高速距离-时间图：物理帧 %d～%d，|v|≥%.0f m/s', ...
        cfg.targetFrameStart, cfg.targetFrameEnd, cfg.highSpeedMin), ...
    [cfg.displayRangeMin, cfg.displayRangeMax], ...
    cfg.highSpeedClim);

addFrameLines( ...
    ax3, targetData.numFrames, ...
    cfg.framePeriod, ...
    cfg.numChirpsPerFrame * cfg.chirpPeriod);

hold(ax3, 'on');

% 标出候选距离搜索范围。
yline(ax3, cfg.candidateRangeMin, 'w:', 'LineWidth', 0.8);
yline(ax3, cfg.candidateRangeMax, 'w:', 'LineWidth', 0.8);

% 所有候选点。
if ~isempty(candidateTable)
    plot( ...
        ax3, ...
        candidateTable.Time_ms, ...
        candidateTable.Range_m, ...
        'wo', ...
        'LineStyle', 'none', ...
        'MarkerSize', 6, ...
        'LineWidth', 1.0);
end

% 最终连续轨迹。
if fitInfo.valid
    plot( ...
        ax3, ...
        trackTable.Time_ms, ...
        trackTable.Range_m, ...
        'r-o', ...
        'MarkerFaceColor', 'y', ...
        'MarkerSize', 7, ...
        'LineWidth', 1.8);

    fitTimeLineMs = linspace( ...
        min(trackTable.Time_ms), ...
        max(trackTable.Time_ms), 300);

    fitRangeLine = ...
        fitInfo.speed * fitTimeLineMs * 1e-3 + fitInfo.intercept;

    plot( ...
        ax3, fitTimeLineMs, fitRangeLine, ...
        'w--', 'LineWidth', 1.5);
end

hold(ax3, 'off');

%% 19. Figure 4：轨迹、折叠速度与解模糊速度

figure( ...
    'Name', '高速目标轨迹分析', ...
    'Color', 'w');

layout = tiledlayout(4, 1);
layout.TileSpacing = 'compact';
layout.Padding = 'compact';

% 19.1 候选点及轨迹
axRange = nexttile;

if ~isempty(candidateTable)
    scatter( ...
        axRange, ...
        candidateTable.Time_ms, ...
        candidateTable.Range_m, ...
        26, ...
        candidateTable.RelativeStrength_dB, ...
        'filled');
    hold(axRange, 'on');
end

if fitInfo.valid
    plot( ...
        axRange, ...
        trackTable.Time_ms, ...
        trackTable.Range_m, ...
        'ro-', ...
        'MarkerFaceColor', 'y', ...
        'MarkerSize', 6, ...
        'LineWidth', 1.5);

    fitTimeLineMs = linspace( ...
        min(trackTable.Time_ms), ...
        max(trackTable.Time_ms), 300);

    plot( ...
        axRange, ...
        fitTimeLineMs, ...
        fitInfo.speed * fitTimeLineMs * 1e-3 + fitInfo.intercept, ...
        'k--', ...
        'LineWidth', 1.4);

    legend( ...
        axRange, ...
        {'所有候选点', '联合连续轨迹'}, ...
        'Location', 'best');
end

hold(axRange, 'off');
grid(axRange, 'on');
xlabel(axRange, 'Time (ms)');
ylabel(axRange, 'Range (m)');
title(axRange, '所有候选点与联合连续轨迹');

% 19.2 有模糊速度
axAlias = nexttile;

if fitInfo.valid
    plot( ...
        axAlias, ...
        trackTable.Time_ms, ...
        trackTable.AliasedVelocity_mps, ...
        'o-', ...
        'LineWidth', 1.4, ...
        'MarkerSize', 6);
end

grid(axAlias, 'on');
xlabel(axAlias, 'Time (ms)');
ylabel(axAlias, 'Aliased velocity (m/s)');
title(axAlias, '连续轨迹有模糊速度');
ylim(axAlias, [-derived.vMax, derived.vMax]);

% 19.3 解模糊速度
axUnwrap = nexttile;

if fitInfo.valid
    plot( ...
        axUnwrap, ...
        trackTable.Time_ms, ...
        trackTable.UnwrappedVelocity_mps, ...
        'o-', ...
        'LineWidth', 1.4, ...
        'MarkerSize', 6);

    hold(axUnwrap, 'on');

    % 黑色虚线表示本发目标的实测速度。
    yline(axUnwrap, cfg.muzzleSpeed, 'k--');

    hold(axUnwrap, 'off');
end

grid(axUnwrap, 'on');
xlabel(axUnwrap, 'Time (ms)');
ylabel(axUnwrap, 'Unwrapped velocity (m/s)');

if fitInfo.valid
    title( ...
        axUnwrap, ...
        { ...
            '连续轨迹解模糊速度', ...
            sprintf( ...
                '相对实测速度 RMSE：%.1f m/s；最小绝对误差：%.1f m/s', ...
                fitInfo.unwrapSpeedRmse, ...
                fitInfo.unwrapSpeedMinAbsError) ...
        });
else
    title(axUnwrap, '连续轨迹解模糊速度');
end

ylim(axUnwrap, [cfg.unwrapSpeedMin, cfg.unwrapSpeedMax]);

% 19.4 最终轨迹相对强度
axStrength = nexttile;

if fitInfo.valid
    plot( ...
        axStrength, ...
        trackTable.Time_ms, ...
        trackTable.RelativeStrength_dB, ...
        'o-', ...
        'LineWidth', 1.4, ...
        'MarkerSize', 6);
end

grid(axStrength, 'on');
xlabel(axStrength, 'Time (ms)');
ylabel(axStrength, 'Relative strength (dB)');
title(axStrength, '连续轨迹相对背景强度');

%% 20. 保存结果

if cfg.saveResults
    [~, baseName, ~] = fileparts(fileName);

    matOutputPath = fullfile( ...
        filePath, [baseName, '_joint_track_analysis.mat']);

    candidateCsvPath = fullfile( ...
        filePath, [baseName, '_all_candidates.csv']);

    trackCsvPath = fullfile( ...
        filePath, [baseName, '_selected_track.csv']);

    save( ...
        matOutputPath, ...
        'cfg', 'derived', ...
        'backgroundData', 'targetData', ...
        'rangeTimeEnhanced', ...
        'rdBackgroundPower', 'rdEnhancedDb', ...
        'rdGifOutputPath', ...
        'highSpeedEnhanced', 'highSpeedVelocityMap', ...
        'candidateTable', 'trackTable', 'fitInfo');

    writetable(candidateTable, candidateCsvPath);

    if fitInfo.valid
        writetable(trackTable, trackCsvPath);
    end

    fprintf('\n结果已保存：\n');
    fprintf('%s\n', matOutputPath);
    fprintf('%s\n', candidateCsvPath);

    if fitInfo.valid
        fprintf('%s\n', trackCsvPath);
    end
end

fprintf('\n全部处理完成。\n');

%% =========================================================
%  局部函数
%% =========================================================

function createRdEvolutionGif( ...
        rdEnhancedDb, ...
        targetData, ...
        derived, ...
        cfg, ...
        outputPath)

    numWindows = size(rdEnhancedDb, 3);

    if numWindows < 1
        warning('目标帧中没有可用于生成GIF的RD窗口。');
        return;
    end

    if exist(outputPath, 'file')
        delete(outputPath);
    end

    if cfg.rdGifVisible
        figureVisibility = 'on';
    else
        figureVisibility = 'off';
    end

    gifFigure = figure( ...
        'Name', '二维RD连续变化GIF', ...
        'Color', 'w', ...
        'Visible', figureVisibility, ...
        'Position', [100, 100, 980, 760]);

    gifAxes = axes(gifFigure);

    imageHandle = imagesc( ...
        gifAxes, ...
        derived.velocityAxis, ...
        derived.rangeAxis, ...
        double(rdEnhancedDb(:, :, 1)));

    gifAxes.YDir = 'normal';
    gifAxes.Box = 'on';

    xlabel(gifAxes, 'Aliased velocity (m/s)');
    ylabel(gifAxes, 'Range (m)');

    xlim(gifAxes, [ ...
        min(derived.velocityAxis), ...
        max(derived.velocityAxis)]);

    ylim(gifAxes, [ ...
        cfg.rdGifRangeMin, ...
        cfg.rdGifRangeMax]);

    caxis(gifAxes, cfg.rdGifClim);
    colormap(gifAxes, turbo);

    colorBarHandle = colorbar(gifAxes);
    ylabel(colorBarHandle, 'RD background enhancement (dB)');

    temporaryPngPath = [tempname, '.png'];

    cleanupObject = onCleanup( ...
        @() cleanupRdGifResources( ...
        gifFigure, temporaryPngPath)); %#ok<NASGU>

    for globalWindowIdx = 1:numWindows

        currentPhysicalFrame = ...
            targetData.windowPhysicalFrame(globalWindowIdx);

        currentWindowInFrame = ...
            targetData.windowIndexInFrame(globalWindowIdx);

        currentCenterTimeMs = ...
            targetData.windowTimeMs(globalWindowIdx);

        chirpStart = ...
            (currentWindowInFrame - 1) * cfg.winStep + 1;

        chirpEnd = ...
            chirpStart + cfg.winSize - 1;

        set( ...
            imageHandle, ...
            'CData', ...
            double(rdEnhancedDb(:, :, globalWindowIdx)));

        title( ...
            gifAxes, ...
            { ...
                '二维 FFT 背景增强 RD 连续变化', ...
                sprintf( ...
                    ['物理帧 %d | 窗口 %d/%d | ' ...
                     'Chirp %d~%d | 显示 FFT %d 点 | 中心时刻 %.3f ms'], ...
                    currentPhysicalFrame, ...
                    currentWindowInFrame, ...
                    derived.windowsPerFrame, ...
                    chirpStart, ...
                    chirpEnd, ...
                    cfg.dopplerFftSize, ...
                    currentCenterTimeMs) ...
            }, ...
            'FontWeight', 'bold');

        drawnow;

        print( ...
            gifFigure, ...
            temporaryPngPath, ...
            '-dpng', ...
            sprintf('-r%d', cfg.rdGifResolution));

        rgbFrame = imread(temporaryPngPath);

        [indexedFrame, colorMap] = ...
            rgb2ind(rgbFrame, 256, 'nodither');

        if globalWindowIdx == 1
            imwrite( ...
                indexedFrame, ...
                colorMap, ...
                outputPath, ...
                'gif', ...
                'LoopCount', Inf, ...
                'DelayTime', cfg.rdGifDelayTime);
        else
            imwrite( ...
                indexedFrame, ...
                colorMap, ...
                outputPath, ...
                'gif', ...
                'WriteMode', 'append', ...
                'DelayTime', cfg.rdGifDelayTime);
        end

        fprintf( ...
            '  GIF帧 %d / %d：物理帧%d，窗口%d\n', ...
            globalWindowIdx, ...
            numWindows, ...
            currentPhysicalFrame, ...
            currentWindowInFrame);
    end
end

function cleanupRdGifResources(gifFigure, temporaryPngPath)

    if exist(temporaryPngPath, 'file')
        delete(temporaryPngPath);
    end

    if isgraphics(gifFigure)
        close(gifFigure);
    end
end

function validateFrameRange(frameStart, frameEnd, totalFrames, rangeName)
    if frameStart < 1 || frameEnd < frameStart || frameEnd > totalFrames
        error('%s范围无效：%d～%d，文件总帧数为 %d。', ...
            rangeName, frameStart, frameEnd, totalFrames);
    end
end

function output = processFrameRange( ...
        fid, frameStart, frameEnd, cfg, derived)

    numFrames = frameEnd - frameStart + 1;
    totalChirps = numFrames * cfg.numChirpsPerFrame;
    totalWindows = numFrames * derived.windowsPerFrame;

    output.rangeTimeDb = nan( ...
        cfg.rangeFftSize, totalChirps, 'single');

    output.chirpTimeMs = nan(1, totalChirps);

    % 完整二维 RD 线性功率：
    % 距离 × 零填充 Doppler 单元 × 窗口
    output.rdPowerCube = nan( ...
        cfg.rangeFftSize, ...
        cfg.dopplerFftSize, ...
        totalWindows, ...
        'single');

    output.windowTimeMs = nan(1, totalWindows);
    output.windowPhysicalFrame = nan(1, totalWindows);
    output.windowIndexInFrame = nan(1, totalWindows);
    output.numFrames = numFrames;

    chirpColumn = 1;
    windowColumn = 1;

    for frameIdx = frameStart:frameEnd
        fprintf('  正在处理物理帧 %d / %d\n', frameIdx, frameEnd);

        byteOffset = (frameIdx - 1) * cfg.bytesPerFrame;

        if fseek(fid, byteOffset, 'bof') ~= 0
            error('无法跳转到物理帧 %d。', frameIdx);
        end

        rawData = fread( ...
            fid, cfg.uint16PerFrame, 'uint16=>double');

        if numel(rawData) < cfg.uint16PerFrame
            error('物理帧 %d 数据不完整。', frameIdx);
        end

        negativeMask = rawData >= 2^15;
        rawData(negativeMask) = rawData(negativeMask) - 2^16;

        adcComplex = complex( ...
            rawData(1:2:end), ...
            rawData(2:2:end));

        % 原始排列：Sample × RX × Chirp
        adcComplex = reshape( ...
            adcComplex, ...
            cfg.numSamples, cfg.numRx, cfg.numChirpsPerFrame);

        % 转换为：Sample × Chirp × RX
        adcFrame = single(permute(adcComplex, [1, 3, 2]));

        % ---------- 逐 Chirp 距离 FFT ----------
        rangeFftAll = fft( ...
            adcFrame .* derived.rangeWindow, ...
            cfg.rangeFftSize, 1);

        rangeAmplitude = sum(abs(rangeFftAll), 3);

        rangeAmplitudeDb = ...
            20 * log10(rangeAmplitude + single(1e-6));

        chirpColumnEnd = ...
            chirpColumn + cfg.numChirpsPerFrame - 1;

        chirpColumns = chirpColumn:chirpColumnEnd;

        output.rangeTimeDb(:, chirpColumns) = rangeAmplitudeDb;

        relativeFrameIdx = frameIdx - frameStart;

        output.chirpTimeMs(chirpColumns) = ...
            (relativeFrameIdx * cfg.framePeriod ...
            + (0:cfg.numChirpsPerFrame - 1) * cfg.chirpPeriod) * 1e3;

        chirpColumn = chirpColumnEnd + 1;

        % ---------- 每个短时窗口计算 RD ----------
        for localWindowIdx = 1:derived.windowsPerFrame
            chirpStart = ...
                (localWindowIdx - 1) * cfg.winStep + 1;

            chirpEnd = chirpStart + cfg.winSize - 1;
            chirpIndices = chirpStart:chirpEnd;

            adcWindow = adcFrame(:, chirpIndices, :);

            % 慢时间复数去均值，抑制严格静态分量。
            adcWindow = adcWindow - mean(adcWindow, 2);

            rangeFftWindow = fft( ...
                adcWindow .* derived.rangeWindow, ...
                cfg.rangeFftSize, 1);

            rangeDoppler = fftshift( ...
                fft( ...
                    rangeFftWindow .* derived.dopplerWindow, ...
                    cfg.dopplerFftSize, ...
                    2), ...
                2);

            % 对接收通道做功率非相干累加，并保留线性功率。
            % 不在这里提前压缩速度维，也不在这里转成 dB。
            rdPower = sum(abs(rangeDoppler).^2, 3);

            output.rdPowerCube(:, :, windowColumn) = ...
                single(rdPower);

            windowCenterChirp = ...
                (chirpStart - 1) + (cfg.winSize - 1) / 2;

            output.windowTimeMs(windowColumn) = ...
                (relativeFrameIdx * cfg.framePeriod ...
                + windowCenterChirp * cfg.chirpPeriod) * 1e3;

            output.windowPhysicalFrame(windowColumn) = frameIdx;
            output.windowIndexInFrame(windowColumn) = localWindowIdx;

            windowColumn = windowColumn + 1;
        end
    end
end

function candidateTable = extractHighSpeedCandidates( ...
        highSpeedEnhanced, ...
        highSpeedVelocityMap, ...
        targetData, ...
        rangeAxis, ...
        cfg)

    globalWindow = [];
    physicalFrame = [];
    windowInFrame = [];
    timeMs = [];
    rangeM = [];
    aliasedVelocity = [];
    relativeStrength = [];
    rangeBin = [];

    rangeGate = ...
        rangeAxis(:) >= cfg.candidateRangeMin ...
        & rangeAxis(:) <= cfg.candidateRangeMax;

    validBins = find(rangeGate);

    if numel(validBins) < 3
        error('候选距离范围过窄，无法进行局部峰检测。');
    end

    firstValidBin = validBins(1);
    lastValidBin = validBins(end);
    innerBins = (firstValidBin + 1):(lastValidBin - 1);

    numWindows = size(highSpeedEnhanced, 2);

    for windowIdx = 1:numWindows
        profile = double(highSpeedEnhanced(:, windowIdx));

        profileSmooth = movmean( ...
            profile, cfg.rangeSmoothBins, 'omitnan');

        profileSmooth(~rangeGate) = -Inf;

        isLocalPeak = false(numel(profileSmooth), 1);

        % 不允许搜索范围的两个边界被判为局部峰。
        isLocalPeak(innerBins) = ...
            profileSmooth(innerBins) ...
            >= profileSmooth(innerBins - 1) ...
            & profileSmooth(innerBins) ...
            > profileSmooth(innerBins + 1);

        peakIndices = find( ...
            isLocalPeak ...
            & profileSmooth >= cfg.candidateThresholdDb);

        if isempty(peakIndices)
            continue;
        end

        [~, sortOrder] = sort( ...
            profileSmooth(peakIndices), 'descend');

        peakIndices = peakIndices(sortOrder);
        selectedIndices = [];

        for idx = 1:numel(peakIndices)
            currentBin = peakIndices(idx);
            currentRange = rangeAxis(currentBin);

            if isempty(selectedIndices)
                isSeparated = true;
            else
                selectedRanges = rangeAxis(selectedIndices);
                isSeparated = all( ...
                    abs(selectedRanges - currentRange) ...
                    >= cfg.minCandidateSeparation);
            end

            if isSeparated
                selectedIndices(end + 1) = currentBin; %#ok<AGROW>

                if numel(selectedIndices) >= cfg.maxCandidatesPerWindow
                    break;
                end
            end
        end

        for idx = 1:numel(selectedIndices)
            currentBin = selectedIndices(idx);

            currentVelocity = ...
                highSpeedVelocityMap(currentBin, windowIdx);

            if ~isfinite(currentVelocity)
                continue;
            end

            globalWindow(end + 1, 1) = windowIdx; %#ok<AGROW>
            physicalFrame(end + 1, 1) = ...
                targetData.windowPhysicalFrame(windowIdx); %#ok<AGROW>
            windowInFrame(end + 1, 1) = ...
                targetData.windowIndexInFrame(windowIdx); %#ok<AGROW>
            timeMs(end + 1, 1) = ...
                targetData.windowTimeMs(windowIdx); %#ok<AGROW>
            rangeM(end + 1, 1) = ...
                rangeAxis(currentBin); %#ok<AGROW>
            aliasedVelocity(end + 1, 1) = ...
                currentVelocity; %#ok<AGROW>
            relativeStrength(end + 1, 1) = ...
                profileSmooth(currentBin); %#ok<AGROW>
            rangeBin(end + 1, 1) = currentBin; %#ok<AGROW>
        end
    end

    candidateTable = table( ...
        globalWindow, physicalFrame, windowInFrame, ...
        timeMs, rangeM, aliasedVelocity, ...
        relativeStrength, rangeBin, ...
        'VariableNames', { ...
            'GlobalWindow', ...
            'PhysicalFrame', ...
            'WindowInFrame', ...
            'Time_ms', ...
            'Range_m', ...
            'AliasedVelocity_mps', ...
            'RelativeStrength_dB', ...
            'RangeBin'});
end

function [trackTable, fitInfo] = selectJointTrack( ...
        candidateTable, cfg, derived)

    trackTable = table();

    fitInfo.valid = false;
    fitInfo.speed = NaN;
    fitInfo.intercept = NaN;
    fitInfo.rmse = NaN;
    fitInfo.expectedAliasedSpeed = NaN;
    fitInfo.meanCircularVelocityResidual = NaN;

    if isempty(candidateTable)
        return;
    end

    validMask = candidateTable.Time_ms >= cfg.trackStartTimeMs;
    candidates = candidateTable(validMask, :);

    if height(candidates) < 2
        return;
    end

    numCandidates = height(candidates);

    bestSelection = [];
    bestMetric = -Inf;

    for firstIdx = 1:numCandidates - 1
        for secondIdx = firstIdx + 1:numCandidates
            if candidates.GlobalWindow(firstIdx) ...
                    == candidates.GlobalWindow(secondIdx)
                continue;
            end

            time1 = candidates.Time_ms(firstIdx) * 1e-3;
            time2 = candidates.Time_ms(secondIdx) * 1e-3;
            deltaTime = time2 - time1;

            if deltaTime <= 0 ...
                    || deltaTime * 1e3 < cfg.minHypothesisSpanMs
                continue;
            end

            range1 = candidates.Range_m(firstIdx);
            range2 = candidates.Range_m(secondIdx);

            speed = (range2 - range1) / deltaTime;

            if speed < cfg.fitSpeedMin || speed > cfg.fitSpeedMax
                continue;
            end

            intercept = range1 - speed * time1;

            [selectedRows, distanceResiduals, ...
                velocityResiduals, metric] = ...
                selectCandidatesForHypothesis( ...
                    candidates, speed, intercept, cfg, derived);

            if numel(selectedRows) < cfg.minTrackWindows
                continue;
            end

            if metric > bestMetric
                bestMetric = metric;
                bestSelection = selectedRows;
            end
        end
    end

    if numel(bestSelection) < cfg.minTrackWindows
        return;
    end

    selectedRows = bestSelection;

    % 使用已选择点重新拟合，并迭代更新关联结果。
    for iteration = 1:5
        selectedTime = ...
            candidates.Time_ms(selectedRows) * 1e-3;

        selectedRange = ...
            candidates.Range_m(selectedRows);

        p = polyfit(selectedTime, selectedRange, 1);
        speed = p(1);
        intercept = p(2);

        if speed < cfg.fitSpeedMin || speed > cfg.fitSpeedMax
            return;
        end

        [newSelection, ~, ~, ~] = ...
            selectCandidatesForHypothesis( ...
                candidates, speed, intercept, cfg, derived);

        if numel(newSelection) < cfg.minTrackWindows
            return;
        end

        if isequal(sort(newSelection), sort(selectedRows))
            selectedRows = newSelection;
            break;
        end

        selectedRows = newSelection;
    end

    trackTable = candidates(selectedRows, :);
    trackTable = sortrows(trackTable, 'Time_ms');

    p = polyfit( ...
        trackTable.Time_ms * 1e-3, ...
        trackTable.Range_m, 1);

    fittedRange = polyval(p, trackTable.Time_ms * 1e-3);
    residual = trackTable.Range_m - fittedRange;

    expectedAlias = wrapVelocity(p(1), derived.vMax);

    circularResidual = circularVelocityDifference( ...
        trackTable.AliasedVelocity_mps, ...
        expectedAlias, ...
        derived.velocityPeriod);

    trackTable.FittedRange_m = fittedRange;
    trackTable.FitResidual_m = residual;
    trackTable.ExpectedAliasedVelocity_mps = ...
        repmat(expectedAlias, height(trackTable), 1);
    trackTable.CircularVelocityResidual_mps = ...
        circularResidual;

    fitInfo.valid = true;
    fitInfo.speed = p(1);
    fitInfo.intercept = p(2);
    fitInfo.rmse = sqrt(mean(residual.^2));
    fitInfo.expectedAliasedSpeed = expectedAlias;
    fitInfo.meanCircularVelocityResidual = ...
        mean(circularResidual);
end

function [selectedRows, distanceResiduals, ...
        velocityResiduals, metric] = ...
        selectCandidatesForHypothesis( ...
        candidates, speed, intercept, cfg, derived)

    selectedRows = [];
    distanceResiduals = [];
    velocityResiduals = [];

    expectedAlias = wrapVelocity(speed, derived.vMax);

    % 实测速度对应的有模糊速度，仅作为软先验。
    muzzleExpectedAlias = wrapVelocity( ...
        cfg.muzzleSpeed, derived.vMax);

    uniqueWindows = unique(candidates.GlobalWindow, 'stable');

    totalStrength = 0;

    for idx = 1:numel(uniqueWindows)
        currentWindow = uniqueWindows(idx);

        rows = find( ...
            candidates.GlobalWindow == currentWindow);

        predictedRange = ...
            speed * candidates.Time_ms(rows) * 1e-3 ...
            + intercept;

        distanceResidual = abs( ...
            candidates.Range_m(rows) - predictedRange);

        velocityResidual = circularVelocityDifference( ...
            candidates.AliasedVelocity_mps(rows), ...
            expectedAlias, ...
            derived.velocityPeriod);

        muzzleVelocityResidual = circularVelocityDifference( ...
            candidates.AliasedVelocity_mps(rows), ...
            muzzleExpectedAlias, ...
            derived.velocityPeriod);

        validMask = ...
            distanceResidual <= cfg.trackTolerance ...
            & velocityResidual <= cfg.velocityTolerance;

        if ~any(validMask)
            continue;
        end

        validRows = rows(validMask);
        dRes = distanceResidual(validMask);
        vRes = velocityResidual(validMask);
        muzzleVRes = muzzleVelocityResidual(validMask);
        strength = candidates.RelativeStrength_dB(validRows);

        normalizedCost = ...
            (dRes / cfg.trackTolerance).^2 ...
            + cfg.velocityCostWeight ...
            * (vRes / cfg.velocityTolerance).^2 ...
            + cfg.muzzleAliasCostWeight ...
            * (muzzleVRes / cfg.muzzleAliasTolerance).^2 ...
            - cfg.strengthCostWeight ...
            * max(strength, 0) ...
            / max(cfg.candidateThresholdDb, 1);

        [~, bestLocalIdx] = min(normalizedCost);

        selectedRows(end + 1, 1) = ...
            validRows(bestLocalIdx); %#ok<AGROW>

        distanceResiduals(end + 1, 1) = ...
            dRes(bestLocalIdx); %#ok<AGROW>

        velocityResiduals(end + 1, 1) = ...
            vRes(bestLocalIdx); %#ok<AGROW>

        totalStrength = totalStrength ...
            + max(strength(bestLocalIdx), 0);
    end

    if isempty(selectedRows)
        metric = -Inf;
        return;
    end

    metric = ...
        numel(selectedRows) * 100 ...
        + 0.40 * totalStrength ...
        - 30 * mean(distanceResiduals) ...
        - 0.50 * mean(velocityResiduals);
end

function wrappedVelocity = wrapVelocity(velocity, vMax)
    period = 2 * vMax;
    wrappedVelocity = mod(velocity + vMax, period) - vMax;
end

function difference = circularVelocityDifference( ...
        velocity1, velocity2, period)

    directDifference = abs(velocity1 - velocity2);
    difference = min(directDifference, period - directDifference);
end

function trackTable = unwrapTrackVelocity( ...
        trackTable, vMax, referenceSpeed, cfg)

    % =========================================================
    % 基于实测速度的全局速度解模糊
    %
    % 对每一个有模糊速度 va，构造：
    %   v(i,k) = va(i) + k * 2Vmax
    %
    % 使用动态规划一次性寻找整条轨迹的最优模糊数序列。
    % 代价同时考虑：
    %   1. 接近实测速度；
    %   2. 接近距离-时间拟合速度；
    %   3. 相邻时刻速度连续。
    %
    % 与旧版逐点贪心方法相比，第一个点选错后不会直接锁死
    % 后面全部点的模糊分支。
    % =========================================================

    ambiguityPeriod = 2 * vMax;

    ambiguityCandidates = ...
        cfg.ambiguityNumberMin:cfg.ambiguityNumberMax;

    aliasedVelocity = ...
        double(trackTable.AliasedVelocity_mps(:));

    numPoints = numel(aliasedVelocity);
    numAmbiguities = numel(ambiguityCandidates);

    possibleVelocity = ...
        aliasedVelocity ...
        + ambiguityPeriod * ambiguityCandidates;

    validMask = ...
        possibleVelocity >= cfg.unwrapSpeedMin ...
        & possibleVelocity <= cfg.unwrapSpeedMax;

    % 每个点的局部代价。
    muzzleCost = cfg.unwrapMuzzleWeight ...
        * ((possibleVelocity - cfg.muzzleSpeed) ...
        / cfg.muzzleSpeedStd).^2;

    fitCost = cfg.unwrapFitWeight ...
        * ((possibleVelocity - referenceSpeed) ...
        / cfg.distanceFitSpeedStd).^2;

    localCost = muzzleCost + fitCost;
    localCost(~validMask) = Inf;

    accumulatedCost = inf(numPoints, numAmbiguities);
    previousState = zeros(numPoints, numAmbiguities);

    accumulatedCost(1, :) = localCost(1, :);

    for pointIdx = 2:numPoints
        for stateIdx = 1:numAmbiguities

            if ~isfinite(localCost(pointIdx, stateIdx))
                continue;
            end

            transitionCost = ...
                cfg.unwrapContinuityWeight ...
                * ((possibleVelocity(pointIdx, stateIdx) ...
                - possibleVelocity(pointIdx - 1, :)) ...
                / cfg.unwrapContinuityStd).^2;

            totalPreviousCost = ...
                accumulatedCost(pointIdx - 1, :) ...
                + transitionCost;

            [minimumPreviousCost, bestPreviousState] = ...
                min(totalPreviousCost);

            accumulatedCost(pointIdx, stateIdx) = ...
                localCost(pointIdx, stateIdx) ...
                + minimumPreviousCost;

            previousState(pointIdx, stateIdx) = ...
                bestPreviousState;
        end
    end

    [bestFinalCost, bestState] = ...
        min(accumulatedCost(end, :));

    if ~isfinite(bestFinalCost)
        warning('没有找到满足当前速度范围的有效解模糊路径。');

        trackTable.AmbiguityNumber = ...
            nan(numPoints, 1);

        trackTable.UnwrappedVelocity_mps = ...
            nan(numPoints, 1);

        trackTable.MuzzleSpeedPrior_mps = ...
            repmat(cfg.muzzleSpeed, numPoints, 1);

        return;
    end

    bestStateSequence = zeros(numPoints, 1);
    bestStateSequence(end) = bestState;

    for pointIdx = numPoints:-1:2
        bestStateSequence(pointIdx - 1) = ...
            previousState( ...
                pointIdx, ...
                bestStateSequence(pointIdx));
    end

    linearIndex = sub2ind( ...
        size(possibleVelocity), ...
        (1:numPoints).', ...
        bestStateSequence);

    unwrappedVelocity = ...
        possibleVelocity(linearIndex);

    ambiguityNumber = ...
        ambiguityCandidates(bestStateSequence).';

    trackTable.AmbiguityNumber = ...
        ambiguityNumber;

    trackTable.UnwrappedVelocity_mps = ...
        unwrappedVelocity;

    trackTable.MuzzleSpeedPrior_mps = ...
        repmat(cfg.muzzleSpeed, numPoints, 1);

    trackTable.MuzzleSpeedResidual_mps = ...
        unwrappedVelocity - cfg.muzzleSpeed;

    trackTable.DistanceFitSpeedResidual_mps = ...
        unwrappedVelocity - referenceSpeed;

    trackTable.GlobalUnwrapPathCost = ...
        repmat(bestFinalCost, numPoints, 1);
end

function ax = drawSegmentedMap( ...
        timeAxisMs, ...
        rangeAxis, ...
        mapData, ...
        columnsPerFrame, ...
        numFrames, ...
        figureName, ...
        titleText, ...
        rangeLimits, ...
        colorLimits)

    fig = figure('Name', figureName, 'Color', 'w');
    ax = axes(fig);

    hold(ax, 'on');

    totalColumns = size(mapData, 2);

    for localFrameIdx = 1:numFrames
        firstColumn = ...
            (localFrameIdx - 1) * columnsPerFrame + 1;

        lastColumn = min( ...
            localFrameIdx * columnsPerFrame, totalColumns);

        if firstColumn > totalColumns
            break;
        end

        columns = firstColumn:lastColumn;

        imagesc( ...
            ax, ...
            timeAxisMs(columns), ...
            rangeAxis, ...
            mapData(:, columns));
    end

    hold(ax, 'off');

    ax.YDir = 'normal';
    ax.Box = 'on';

    xlabel(ax, 'Time (ms)');
    ylabel(ax, 'Range (m)');
    title(ax, titleText);

    ylim(ax, rangeLimits);

    finiteTime = timeAxisMs(isfinite(timeAxisMs));

    if ~isempty(finiteTime)
        timeMargin = 0.1;
        xlim(ax, [ ...
            min(finiteTime) - timeMargin, ...
            max(finiteTime) + timeMargin]);
    end

    if ~isempty(colorLimits)
        caxis(ax, colorLimits);
    end

    colormap(ax, turbo);
    colorbar(ax);
end

function addFrameLines( ...
        ax, numFrames, framePeriod, activeDuration)

    hold(ax, 'on');

    for localFrameIdx = 1:numFrames
        frameStartMs = ...
            (localFrameIdx - 1) * framePeriod * 1e3;

        activeEndMs = ...
            frameStartMs + activeDuration * 1e3;

        xline( ...
            ax, activeEndMs, ...
            'w--', 'LineWidth', 0.8);

        if localFrameIdx < numFrames
            nextFrameStartMs = ...
                localFrameIdx * framePeriod * 1e3;

            xline( ...
                ax, nextFrameStartMs, ...
                'w:', 'LineWidth', 0.8);
        end
    end

    hold(ax, 'off');
end
