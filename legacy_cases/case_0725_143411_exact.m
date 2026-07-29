clear;
clc;
close all;

%% =========================================================
%  plot_ultra_high_speed_target.m
%
%  适用目标：
%      真实径向速度约 800~1200 m/s，或更一般的 700~1300 m/s。
%
%  处理原则：
%  1. 不使用 |v_alias| 门限判断目标是否高速；
%     高速目标多次折叠后可能落在零多普勒附近。
%  2. 不在短时窗口内做慢时间去均值；
%     否则可能削弱折叠到零多普勒附近的真实高速目标。
%  3. 使用枪击前背景帧建立完整二维 RD 背景。
%  4. 对目标帧的完整 RD 图进行二维背景扣除。
%  5. 先利用距离-时间斜率搜索 700~1300 m/s 的连续轨迹。
%  6. 使用实测速度先验、距离拟合速度和全局动态规划完成速度解模糊。
%
%  输出：
%  Figure 1：逐 Chirp 原始距离-时间图
%  Figure 2：逐 Chirp 背景增强距离-时间图
%  GIF：各滑窗完整二维 RD 图的连续变化过程
%  Figure 3：完整速度轴 RD 背景增强距离-时间图及轨迹
%  Figure 4：候选点、距离拟合、有模糊速度、解模糊速度、强度
%% =========================================================

%% 1. 原始数据与雷达参数

cfg.numSamples = 64;               % 每个 Chirp ADC 采样点数
cfg.numChirpsPerFrame = 256;       % 每个物理帧 Chirp 数
cfg.numRx = 8;                     % 接收通道数
cfg.numTx = 1;                     % 单发射
cfg.rangeFftSize = 256;            % 距离 FFT 点数

cfg.adcSampleRate = 10e6;          % Hz
cfg.slope = 60.01e12;              % Hz/s
cfg.startFreq = 77e9;              % Hz

cfg.chirpPeriod = 12e-6;           % s
cfg.framePeriod = 3.5e-3;          % s
cfg.c = 3e8;

%% 2. 短时 RD 参数

% 16 Chirp 窗口持续 0.192 ms。
% 对 800~1200 m/s 目标，窗口内移动约 0.154~0.230 m，
% 可减轻 32 Chirp 窗口下的距离走动。
cfg.winSize = 16;

% 统一使用 128 点 Doppler FFT。
% 实际相干处理长度仍为 16 Chirp，128 点仅对慢时间频谱零填充。
% 同一个 128 点 RD 结果同时用于背景增强、候选提取、轨迹处理和 GIF。
cfg.dopplerFftSize = 128;

% 16 Chirp 步进，对应 0.192 ms 更新间隔，窗口之间不重叠。
cfg.winStep = 16;

% 关键：不删除任何有模糊速度区域。
% 高速目标多次折叠后可能出现在 -Vmax~+Vmax 的任意位置。
cfg.useFullAliasedVelocityAxis = true;

%% 3. 候选点提取参数

% 需要根据实际射程调整。
cfg.candidateRangeMin = 1.00;      % m
cfg.candidateRangeMax = 5.50;      % m

cfg.candidateThresholdDb = 7.0;    % 相对二维 RD 背景门限，dB
cfg.maxCandidatesPerWindow = 4;    % 每窗口最多保留候选数
cfg.minCandidateSeparation = 0.22; % 同一窗口候选最小距离间隔，m
cfg.rangeSmoothBins = 3;           % 距离轮廓平滑点数

%% 4. 真实速度搜索与轨迹筛选参数

% 初始搜索范围适当放宽；最终速度仍由距离轨迹拟合结果判定。
cfg.fitSpeedMin = 700;             % m/s
cfg.fitSpeedMax = 1700;            % m/s

% 两个候选点建立速度假设时，至少跨越该时间。
cfg.minHypothesisSpanMs = 0.40;    % ms

% 候选距离与假设轨迹的最大允许偏差。
% 当前真实距离分辨率约 0.39 m，因此不宜设置得过小。
cfg.trackTolerance = 0.85;         % m

% 速度残差只作为软约束，不做严格删除。
% 16 点 Doppler FFT 分辨率较粗，且高速距离走动会使谱峰不稳定。
cfg.velocityCostWeight = 0.25;

% 候选强度在关联代价中的权重。
cfg.strengthCostWeight = 0.10;

% 轨迹评分中各因素的权重。
cfg.trackCountWeight = 100;
cfg.trackStrengthWeight = 0.30;
cfg.trackDistancePenalty = 35;
cfg.trackVelocityPenalty = 0.20;

% 至少覆盖的窗口数。
cfg.minTrackWindows = 6;

% 相对于目标分析起始帧的时间。按截图，目标约在第 87 帧窗口 6 出现。
cfg.trackStartTimeMs = 1.65;       % ms
cfg.trackEndTimeMs = 4.90;         % ms

% 解模糊速度范围。
cfg.unwrapSpeedMin = 650;          % m/s
cfg.unwrapSpeedMax = 1350;         % m/s

% =========================================================
% 本发目标的实测速度先验
% =========================================================

cfg.measuredSpeed = 1207.82892;    % m/s

% 实测速度不是严格无误差的径向真值，因此作为软约束使用。
cfg.measuredSpeedStd = 60.0;       % m/s
cfg.distanceFitSpeedStd = 120.0;   % m/s
cfg.unwrapContinuityStd = 50.0;    % m/s

% 全局动态规划解模糊代价权重。
cfg.unwrapMeasuredWeight = 1.00;
cfg.unwrapFitWeight = 0.35;
cfg.unwrapContinuityWeight = 0.80;

% 模糊数搜索范围。
cfg.ambiguityNumberMin = -2;
cfg.ambiguityNumberMax = 12;

% 在轨迹候选关联阶段加入实测速度折叠值软约束。
cfg.measuredAliasTolerance = 60.0; % m/s
cfg.measuredAliasCostWeight = 0.30;

%% 5. 背景帧与目标帧

% 必须确认背景帧没有本次枪击、上一发残留或明显运动目标。
% 当前截图目标位于第 87~88 帧，因此默认使用 79~86 帧作为背景。
cfg.backgroundFrameStart = 79;
cfg.backgroundFrameEnd = 86;

cfg.targetFrameStart = 87;
cfg.targetFrameEnd = 88;

%% 6. 图像显示参数

cfg.displayRangeMin = 0;
cfg.displayRangeMax = 10;

cfg.rawDynamicRangeDb = 35;
cfg.chirpEnhancedClim = [0, 18];
cfg.rdEnhancedRangeTimeClim = [0, 35];

%% 7. 二维 RD 连续变化 GIF 参数

% 方案 A：只显示每个滑窗的完整二维 RD 背景增强图，
% 不叠加候选点，也不叠加最终目标轨迹。
cfg.generateRdGif = true;

% 每帧停留时间。0.12 s 对当前约 62 帧的 GIF 较合适。
cfg.rdGifDelayTime = 0.12;

% GIF 中固定使用同一颜色范围，避免每帧自动缩放造成闪烁。
cfg.rdGifClim = [0, 35];

% GIF 显示的距离范围。
cfg.rdGifRangeMin = 0;
cfg.rdGifRangeMax = 10;

% 输出 PNG 中间帧的分辨率。
cfg.rdGifResolution = 120;

% false：生成时不弹出额外绘图窗口；true：可观察生成过程。
cfg.rdGifVisible = false;

%% 8. 可选的 FMCW 距离-速度耦合补偿

% 上扫频 FMCW 的距离-速度耦合符号取决于你的混频及速度符号定义。
% 在未通过已知目标标定前，默认关闭，只输出耦合偏移量级。
cfg.applyRangeVelocityCouplingCorrection = false;

% 开启补偿后使用：
% R_corrected = R_measured + sign * fc/slope * v
% sign 需要通过已知速度、已知距离实验确定为 +1 或 -1。
cfg.rangeVelocityCouplingSign = 1;

%% 9. 保存结果

cfg.saveResults = false;

%% 10. 选择 DCA1000 原始数据文件

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

%% 11. 文件与物理帧信息

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
fprintf('单物理帧大小：%d Bytes\n', cfg.bytesPerFrame);
fprintf('完整物理帧数：%d\n', totalFramesInFile);
fprintf('尾部剩余字节：%d\n', remainingBytes);
fprintf('========================================\n');

validateFrameRange( ...
    cfg.backgroundFrameStart, cfg.backgroundFrameEnd, ...
    totalFramesInFile, '背景帧');

validateFrameRange( ...
    cfg.targetFrameStart, cfg.targetFrameEnd, ...
    totalFramesInFile, '目标帧');

%% 12. 派生距离轴、速度轴与窗函数

derived.rangeBinSpacing = ...
    cfg.c * cfg.adcSampleRate / ...
    (2 * cfg.slope * cfg.rangeFftSize);

derived.rangeAxis = ...
    (0:cfg.rangeFftSize - 1) * derived.rangeBinSpacing;

adcDuration = cfg.numSamples / cfg.adcSampleRate;
bandwidth = cfg.slope * adcDuration;
derived.centerFreq = cfg.startFreq + bandwidth / 2;
derived.lambda = cfg.c / derived.centerFreq;

% 由实际 16 个 Chirp 决定的真实速度分辨率。
derived.deltaV = ...
    derived.lambda / ...
    (2 * cfg.winSize * cfg.chirpPeriod);

% 128 点零填充后的速度网格间隔。
% 该间隔只表示频谱采样更密，真实速度分辨率仍由 16 Chirp 决定。
derived.deltaVGrid = ...
    derived.lambda / ...
    (2 * cfg.dopplerFftSize * cfg.chirpPeriod);

% 背景增强、候选提取、轨迹处理和 GIF 统一使用该速度轴。
derived.velocityAxis = ...
    (-cfg.dopplerFftSize / 2 : cfg.dopplerFftSize / 2 - 1) ...
    * derived.deltaVGrid;

derived.vMax = cfg.winSize / 2 * derived.deltaV;
derived.velocityPeriod = 2 * derived.vMax;

derived.measuredAliasedSpeed = ...
    wrapVelocity(cfg.measuredSpeed, derived.vMax);

derived.windowsPerFrame = ...
    floor((cfg.numChirpsPerFrame - cfg.winSize) / cfg.winStep) + 1;

derived.rangeWindow = reshape( ...
    single(hann(cfg.numSamples)), ...
    cfg.numSamples, 1, 1);

derived.dopplerWindow = reshape( ...
    single(hann(cfg.winSize)).', ...
    1, cfg.winSize, 1);

fprintf('距离 FFT 显示单元间隔：%.4f m\n', ...
    derived.rangeBinSpacing);
fprintf('理论距离分辨率：%.4f m\n', cfg.c / (2 * bandwidth));
fprintf('真实 Doppler 速度分辨率：%.3f m/s\n', ...
    derived.deltaV);
fprintf('128 点零填充速度网格间隔：%.3f m/s\n', ...
    derived.deltaVGrid);
fprintf('实际 Chirp 数 / 统一 Doppler FFT 点数：%d / %d\n', ...
    cfg.winSize, cfg.dopplerFftSize);
fprintf('最大不模糊速度：±%.3f m/s\n', derived.vMax);
fprintf('速度模糊周期：%.3f m/s\n', derived.velocityPeriod);
fprintf('实测速度：%.5f m/s\n', cfg.measuredSpeed);
fprintf('实测速度对应有模糊速度：%+.3f m/s\n', ...
    derived.measuredAliasedSpeed);
fprintf('每物理帧短时窗口数：%d\n', derived.windowsPerFrame);
fprintf('短时窗口持续时间：%.3f ms\n', ...
    cfg.winSize * cfg.chirpPeriod * 1e3);
fprintf('短时窗口输出间隔：%.3f ms\n', ...
    cfg.winStep * cfg.chirpPeriod * 1e3);

fprintf('\n真实速度折叠示例：\n');
exampleTrueVelocity = [800, 900, 1000, 1100, 1200];
exampleAliasVelocity = wrapVelocity( ...
    exampleTrueVelocity, derived.vMax);

for idx = 1:numel(exampleTrueVelocity)
    fprintf('  %4.0f m/s -> 有模糊速度 %+7.2f m/s\n', ...
        exampleTrueVelocity(idx), exampleAliasVelocity(idx));
end

%% 13. 打开数据文件

fid = fopen(binPath, 'rb', 'ieee-le');

if fid < 0
    error('无法打开数据文件：%s', binPath);
end

cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

%% 14. 处理背景帧：保留完整二维 RD 功率

fprintf('\n正在处理背景物理帧 %d～%d……\n', ...
    cfg.backgroundFrameStart, cfg.backgroundFrameEnd);

backgroundData = processFrameRange( ...
    fid, cfg.backgroundFrameStart, cfg.backgroundFrameEnd, ...
    cfg, derived);

%% 15. 处理目标帧：保留完整二维 RD 功率

fprintf('\n正在处理目标物理帧 %d～%d……\n', ...
    cfg.targetFrameStart, cfg.targetFrameEnd);

targetData = processFrameRange( ...
    fid, cfg.targetFrameStart, cfg.targetFrameEnd, ...
    cfg, derived);

%% 16. 建立背景并进行增强

% 逐 Chirp 距离像背景：距离 × 1。
backgroundRangePower = median( ...
    backgroundData.rangePowerTime, 2, 'omitnan');

% 统一的 128 点二维 RD 背景：距离 × 速度单元。
backgroundRdPower = median( ...
    backgroundData.rdPowerCube, 3, 'omitnan');

% 逐 Chirp 背景增强，单位 dB。
rangeTimeEnhancedDb = ...
    10 * log10( ...
        (targetData.rangePowerTime + single(1e-12)) ...
        ./ (backgroundRangePower + single(1e-12)));

% 统一的 128 点二维 RD 背景增强，单位 dB。
% 该数据同时用于 GIF、候选提取、轨迹处理和速度解模糊。
rdEnhancedDb = ...
    10 * log10( ...
        (targetData.rdPowerCube + single(1e-12)) ...
        ./ (backgroundRdPower + single(1e-12)));

%% 17. 生成完整二维 RD 连续变化 GIF

[~, baseNameForGif, ~] = fileparts(fileName);

rdGifOutputPath = fullfile( ...
    filePath, ...
    [baseNameForGif, '_2D_RD_evolution.gif']);

if cfg.generateRdGif
    fprintf('\n正在生成二维 RD 连续变化 GIF……\n');

    createRdEvolutionGif( ...
        rdEnhancedDb, ...
        targetData, ...
        derived, ...
        cfg, ...
        rdGifOutputPath);

    fprintf('[完成] 二维 RD 连续变化 GIF：\n%s\n', ...
        rdGifOutputPath);
end

%% 18. 将每个完整 RD 图压缩为一条距离轮廓

% 对每个距离单元，在完整有模糊速度轴上取“背景增强最大值”。
% 这里不是用 |v_alias| 判断目标高速，而只是将二维 RD 图压缩成距离轮廓。
[rdEnhancedRangeTimeDb, maxVelocityIndex] = ...
    max(rdEnhancedDb, [], 2);

rdEnhancedRangeTimeDb = squeeze(rdEnhancedRangeTimeDb);
maxVelocityIndex = squeeze(maxVelocityIndex);

if isvector(rdEnhancedRangeTimeDb)
    rdEnhancedRangeTimeDb = rdEnhancedRangeTimeDb(:);
end

if isvector(maxVelocityIndex)
    maxVelocityIndex = maxVelocityIndex(:);
end

numTargetWindows = size(rdEnhancedRangeTimeDb, 2);

aliasVelocityAtRangeMaximum = nan( ...
    size(rdEnhancedRangeTimeDb), 'single');

for windowIdx = 1:numTargetWindows
    aliasVelocityAtRangeMaximum(:, windowIdx) = single( ...
        derived.velocityAxis(maxVelocityIndex(:, windowIdx)));
end

%% 19. 提取每个短时窗口的多个候选点

candidateTable = extractCandidates( ...
    rdEnhancedRangeTimeDb, ...
    aliasVelocityAtRangeMaximum, ...
    targetData, ...
    derived.rangeAxis, ...
    cfg);

fprintf('\n========================================\n');
fprintf('候选点数量：%d\n', height(candidateTable));
fprintf('========================================\n');

if ~isempty(candidateTable)
    disp(candidateTable);
else
    warning('当前门限下没有提取到候选点。');
end

%% 20. 根据 700~1700 m/s 距离斜率筛选连续轨迹

[trackTable, fitInfo] = selectUltraHighSpeedTrack( ...
    candidateTable, cfg, derived);

if fitInfo.valid
    trackTable = unwrapTrackVelocity( ...
        trackTable, derived.vMax, fitInfo.speed, cfg);

    validUnwrapped = ...
        isfinite(trackTable.UnwrappedVelocity_mps);

    if any(validUnwrapped)

        velocityError = ...
            trackTable.UnwrappedVelocity_mps(validUnwrapped) ...
            - cfg.measuredSpeed;

        fitInfo.meanUnwrappedSpeed = ...
            mean(trackTable.UnwrappedVelocity_mps(validUnwrapped));

        fitInfo.unwrapSpeedStd = ...
            std(trackTable.UnwrappedVelocity_mps(validUnwrapped));

        fitInfo.unwrapSpeedMae = ...
            mean(abs(velocityError));

        fitInfo.unwrapSpeedRmse = ...
            sqrt(mean(velocityError.^2));

    else

        fitInfo.meanUnwrappedSpeed = NaN;
        fitInfo.unwrapSpeedStd = NaN;
        fitInfo.unwrapSpeedMae = NaN;
        fitInfo.unwrapSpeedRmse = NaN;
    end

    % 可选的距离-速度耦合补偿。
    couplingOffset = ...
        derived.centerFreq / cfg.slope ...
        .* trackTable.UnwrappedVelocity_mps;

    trackTable.RangeVelocityCouplingMagnitude_m = ...
        abs(couplingOffset);

    if cfg.applyRangeVelocityCouplingCorrection
        trackTable.CorrectedRange_m = ...
            trackTable.Range_m ...
            + cfg.rangeVelocityCouplingSign .* couplingOffset;
    else
        trackTable.CorrectedRange_m = trackTable.Range_m;
    end

    fprintf('\n========================================\n');
    fprintf('超高速目标轨迹结果\n');
    fprintf('轨迹点数：%d\n', height(trackTable));
    fprintf('距离-时间拟合速度：%.2f m/s\n', fitInfo.speed);
    fprintf('距离拟合截距：%.3f m\n', fitInfo.intercept);
    fprintf('距离拟合 RMSE：%.3f m\n', fitInfo.rmse);
    fprintf('拟合速度对应有模糊速度：%+.2f m/s\n', ...
        fitInfo.expectedAliasedSpeed);
    fprintf('平均循环速度残差：%.2f m/s\n', ...
        fitInfo.meanCircularVelocityResidual);
    fprintf('实测速度：%.5f m/s\n', cfg.measuredSpeed);
    fprintf('解模糊平均速度：%.2f m/s\n', ...
        fitInfo.meanUnwrappedSpeed);
    fprintf('解模糊速度标准差：%.2f m/s\n', ...
        fitInfo.unwrapSpeedStd);
    fprintf('解模糊速度相对实测速度 MAE：%.2f m/s\n', ...
        fitInfo.unwrapSpeedMae);
    fprintf('解模糊速度相对实测速度 RMSE：%.2f m/s\n', ...
        fitInfo.unwrapSpeedRmse);
    fprintf('估计距离-速度耦合偏移量级：%.2f～%.2f m\n', ...
        min(trackTable.RangeVelocityCouplingMagnitude_m), ...
        max(trackTable.RangeVelocityCouplingMagnitude_m));
    fprintf('========================================\n');

    disp(trackTable);
else
    warning([ ...
        '未找到满足 700~1300 m/s 距离斜率约束的有效轨迹。' ...
        '请检查目标帧范围、背景帧、候选距离范围和检测门限。']);
end

%% 21. Figure 1：逐 Chirp 原始距离-时间图

targetRangePowerDb = ...
    10 * log10(targetData.rangePowerTime + single(1e-12));

finiteRaw = targetRangePowerDb(isfinite(targetRangePowerDb));
rawMaxDb = max(finiteRaw);

ax1 = drawSegmentedMap( ...
    targetData.chirpTimeMs, ...
    derived.rangeAxis, ...
    targetRangePowerDb, ...
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

%% 22. Figure 2：逐 Chirp 背景增强距离-时间图

ax2 = drawSegmentedMap( ...
    targetData.chirpTimeMs, ...
    derived.rangeAxis, ...
    rangeTimeEnhancedDb, ...
    cfg.numChirpsPerFrame, ...
    targetData.numFrames, ...
    '逐 Chirp 背景增强距离-时间图', ...
    sprintf('逐 Chirp 背景增强距离-时间图：物理帧 %d～%d', ...
        cfg.targetFrameStart, cfg.targetFrameEnd), ...
    [cfg.displayRangeMin, cfg.displayRangeMax], ...
    cfg.chirpEnhancedClim);

addFrameLines( ...
    ax2, targetData.numFrames, ...
    cfg.framePeriod, ...
    cfg.numChirpsPerFrame * cfg.chirpPeriod);

%% 23. Figure 3：完整速度轴 RD 背景增强距离-时间图

ax3 = drawSegmentedMap( ...
    targetData.windowTimeMs, ...
    derived.rangeAxis, ...
    rdEnhancedRangeTimeDb, ...
    derived.windowsPerFrame, ...
    targetData.numFrames, ...
    '完整速度轴 RD 背景增强距离-时间图', ...
    sprintf([ ...
        '完整速度轴 RD 背景增强距离-时间图：' ...
        '物理帧 %d～%d，真实速度搜索 %.0f～%.0f m/s'], ...
        cfg.targetFrameStart, cfg.targetFrameEnd, ...
        cfg.fitSpeedMin, cfg.fitSpeedMax), ...
    [cfg.displayRangeMin, cfg.displayRangeMax], ...
    cfg.rdEnhancedRangeTimeClim);

addFrameLines( ...
    ax3, targetData.numFrames, ...
    cfg.framePeriod, ...
    cfg.numChirpsPerFrame * cfg.chirpPeriod);

hold(ax3, 'on');

yline(ax3, cfg.candidateRangeMin, ...
    'w:', '候选距离下限', 'LineWidth', 0.8);
yline(ax3, cfg.candidateRangeMax, ...
    'w:', '候选距离上限', 'LineWidth', 0.8);

if ~isempty(candidateTable)
    plot( ...
        ax3, ...
        candidateTable.Time_ms, ...
        candidateTable.Range_m, ...
        'wo', ...
        'LineStyle', 'none', ...
        'MarkerSize', 5, ...
        'LineWidth', 0.9);
end

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
        fitInfo.speed * fitTimeLineMs * 1e-3 ...
        + fitInfo.intercept;

    plot( ...
        ax3, fitTimeLineMs, fitRangeLine, ...
        'w--', 'LineWidth', 1.5);
end

hold(ax3, 'off');

%% 24. Figure 4：轨迹综合分析

figure( ...
    'Name', '超高速目标轨迹综合分析', ...
    'Color', 'w');

layout = tiledlayout(4, 1);
layout.TileSpacing = 'compact';
layout.Padding = 'compact';

% 22.1 所有候选点与轨迹
axRange = nexttile;

if ~isempty(candidateTable)
    scatter( ...
        axRange, ...
        candidateTable.Time_ms, ...
        candidateTable.Range_m, ...
        24, ...
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
        fitInfo.speed * fitTimeLineMs * 1e-3 ...
        + fitInfo.intercept, ...
        'k--', ...
        'LineWidth', 1.4);

    legend( ...
        axRange, ...
        {'所有候选点', '连续轨迹'}, ...
        'Location', 'best');
end

hold(axRange, 'off');
grid(axRange, 'on');
xlabel(axRange, 'Time (ms)');
ylabel(axRange, 'Range (m)');
title(axRange, '所有候选点与超高速连续轨迹');

% 22.2 有模糊速度
axAlias = nexttile;

if fitInfo.valid
    plot( ...
        axAlias, ...
        trackTable.Time_ms, ...
        trackTable.AliasedVelocity_mps, ...
        'o-', ...
        'LineWidth', 1.4, ...
        'MarkerSize', 5);

end

grid(axAlias, 'on');
xlabel(axAlias, 'Time (ms)');
ylabel(axAlias, 'Aliased velocity (m/s)');
title(axAlias, '轨迹有模糊速度');
ylim(axAlias, [-derived.vMax, derived.vMax]);

% 22.3 解模糊速度
axUnwrap = nexttile;

if fitInfo.valid
    plot( ...
        axUnwrap, ...
        trackTable.Time_ms, ...
        trackTable.UnwrappedVelocity_mps, ...
        'o-', ...
        'LineWidth', 1.4, ...
        'MarkerSize', 5);

    hold(axUnwrap, 'on');

    % 黑色虚线表示本发目标的实测速度参考值。
    yline( ...
        axUnwrap, ...
        cfg.measuredSpeed, ...
        'k--');

    text( ...
        axUnwrap, ...
        0.98, ...
        0.90, ...
        sprintf( ...
        '相对实测速度 RMSE: %.1f m/s', ...
        fitInfo.unwrapSpeedRmse), ...
        'Units', 'normalized', ...
        'HorizontalAlignment', 'right', ...
        'VerticalAlignment', 'top', ...
        'FontSize', 10, ...
        'BackgroundColor', 'w', ...
        'Margin', 3);

    hold(axUnwrap, 'off');
end

grid(axUnwrap, 'on');
xlabel(axUnwrap, 'Time (ms)');
ylabel(axUnwrap, 'Unwrapped velocity (m/s)');
title(axUnwrap, '轨迹解模糊速度');
ylim(axUnwrap, [cfg.unwrapSpeedMin, cfg.unwrapSpeedMax]);

% 22.4 轨迹相对背景强度
axStrength = nexttile;

if fitInfo.valid
    plot( ...
        axStrength, ...
        trackTable.Time_ms, ...
        trackTable.RelativeStrength_dB, ...
        'o-', ...
        'LineWidth', 1.4, ...
        'MarkerSize', 5);
end

grid(axStrength, 'on');
xlabel(axStrength, 'Time (ms)');
ylabel(axStrength, 'RD enhancement (dB)');
title(axStrength, '轨迹相对二维 RD 背景增强量');

%% 25. 保存结果

if cfg.saveResults
    [~, baseName, ~] = fileparts(fileName);

    matOutputPath = fullfile( ...
        filePath, ...
        [baseName, '_ultra_high_speed_analysis.mat']);

    candidateCsvPath = fullfile( ...
        filePath, ...
        [baseName, '_ultra_high_speed_candidates.csv']);

    trackCsvPath = fullfile( ...
        filePath, ...
        [baseName, '_ultra_high_speed_track.csv']);

    save( ...
        matOutputPath, ...
        'cfg', 'derived', ...
        'backgroundRangePower', ...
        'backgroundRdPower', ...
        'rangeTimeEnhancedDb', ...
        'rdEnhancedDb', ...
        'rdEnhancedRangeTimeDb', ...
        'aliasVelocityAtRangeMaximum', ...
        'candidateTable', ...
        'trackTable', ...
        'fitInfo');

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
        rdEnhancedDb, targetData, derived, cfg, outputPath)

    numWindows = size(rdEnhancedDb, 3);

    if numWindows < 1
        warning('目标帧中没有可用于生成 GIF 的短时 RD 窗口。');
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
        'Name', '二维 RD 连续变化 GIF', ...
        'Color', 'w', ...
        'Visible', figureVisibility, ...
        'Position', [100, 100, 960, 760]);

    gifAxes = axes(gifFigure);

    firstRdFrame = double(rdEnhancedDb(:, :, 1));

    imageHandle = imagesc( ...
        gifAxes, ...
        derived.velocityAxis, ...
        derived.rangeAxis, ...
        firstRdFrame);

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

    set(gifFigure, 'PaperPositionMode', 'auto');

    temporaryPngPath = [tempname, '.png'];

    cleanupObject = onCleanup(@() cleanupRdGifResources( ...
        gifFigure, temporaryPngPath)); %#ok<NASGU>

    for globalWindowIdx = 1:numWindows
        currentPhysicalFrame = ...
            targetData.windowPhysicalFrame(globalWindowIdx);

        currentWindowInFrame = ...
            targetData.windowIndexInFrame(globalWindowIdx);

        currentCenterTimeMs = ...
            targetData.windowTimeMs(globalWindowIdx);

        chirpStart = ...
            (currentWindowInFrame - 1) ...
            * cfg.winStep + 1;

        chirpEnd = chirpStart + cfg.winSize - 1;

        set( ...
            imageHandle, ...
            'CData', ...
            double(rdEnhancedDb(:, :, globalWindowIdx)));

        title( ...
            gifAxes, ...
            { ...
                '二维 FFT 背景增强 RD 连续变化', ...
                sprintf( ...
                    ['物理帧 %d | 窗口 %d/%d | Chirp %d～%d | ' ...
                     '显示 FFT %d 点 | 中心时刻 %.3f ms'], ...
                    currentPhysicalFrame, ...
                    currentWindowInFrame, ...
                    derived.windowsPerFrame, ...
                    chirpStart, ...
                    chirpEnd, ...
                    cfg.dopplerFftSize, ...
                    currentCenterTimeMs) ...
            }, ...
            'FontWeight', 'bold', ...
            'Interpreter', 'none');

        drawnow;

        print( ...
            gifFigure, ...
            temporaryPngPath, ...
            '-dpng', ...
            sprintf('-r%d', cfg.rdGifResolution));

        rgbFrame = imread(temporaryPngPath);

        [indexedFrame, colorMap] = rgb2ind( ...
            rgbFrame, 256, 'nodither');

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
            '  GIF 帧 %d / %d：物理帧 %d，窗口 %d\\n', ...
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

function validateFrameRange( ...
        frameStart, frameEnd, totalFrames, rangeName)

    if frameStart < 1 ...
            || frameEnd < frameStart ...
            || frameEnd > totalFrames

        error('%s范围无效：%d～%d，文件总帧数为 %d。', ...
            rangeName, frameStart, frameEnd, totalFrames);
    end
end

function output = processFrameRange( ...
        fid, frameStart, frameEnd, cfg, derived)

    numFrames = frameEnd - frameStart + 1;
    totalChirps = numFrames * cfg.numChirpsPerFrame;
    totalWindows = numFrames * derived.windowsPerFrame;

    output.rangePowerTime = nan( ...
        cfg.rangeFftSize, totalChirps, 'single');

    output.chirpTimeMs = nan(1, totalChirps);

    % 统一的 128 点 RD：
    % 同时用于背景增强、候选提取、轨迹处理和 GIF。
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
        fprintf('  正在处理物理帧 %d / %d\n', ...
            frameIdx, frameEnd);

        byteOffset = ...
            (frameIdx - 1) * cfg.bytesPerFrame;

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
            cfg.numSamples, ...
            cfg.numRx, ...
            cfg.numChirpsPerFrame);

        % 转换为：Sample × Chirp × RX
        adcFrame = single(permute(adcComplex, [1, 3, 2]));

        % ---------- 逐 Chirp 距离 FFT ----------
        rangeFftAll = fft( ...
            adcFrame .* derived.rangeWindow, ...
            cfg.rangeFftSize, 1);

        rangePower = sum(abs(rangeFftAll).^2, 3);

        chirpColumnEnd = ...
            chirpColumn + cfg.numChirpsPerFrame - 1;

        chirpColumns = chirpColumn:chirpColumnEnd;

        output.rangePowerTime(:, chirpColumns) = ...
            single(rangePower);

        relativeFrameIdx = frameIdx - frameStart;

        output.chirpTimeMs(chirpColumns) = ...
            (relativeFrameIdx * cfg.framePeriod ...
            + (0:cfg.numChirpsPerFrame - 1) ...
            * cfg.chirpPeriod) * 1e3;

        chirpColumn = chirpColumnEnd + 1;

        % ---------- 完整速度轴短时 RD ----------
        for localWindowIdx = 1:derived.windowsPerFrame
            chirpStart = ...
                (localWindowIdx - 1) * cfg.winStep + 1;

            chirpEnd = chirpStart + cfg.winSize - 1;
            chirpIndices = chirpStart:chirpEnd;

            adcWindow = adcFrame(:, chirpIndices, :);

            % 关键：这里不做 adcWindow - mean(adcWindow, 2)。
            % 静态及系统背景由枪击前二维 RD 背景扣除处理。

            rangeFftWindow = fft( ...
                adcWindow .* derived.rangeWindow, ...
                cfg.rangeFftSize, 1);

            windowedRangeData = ...
                rangeFftWindow .* derived.dopplerWindow;

            % 统一计算 128 点 Doppler FFT。
            % 实际相干长度仍为 16 Chirp，零填充只细化速度网格。
            rangeDoppler = fftshift( ...
                fft( ...
                    windowedRangeData, ...
                    cfg.dopplerFftSize, 2), ...
                2);

            rdPower = sum(abs(rangeDoppler).^2, 3);

            output.rdPowerCube(:, :, windowColumn) = ...
                single(rdPower);

            windowCenterChirp = ...
                (chirpStart - 1) ...
                + (cfg.winSize - 1) / 2;

            output.windowTimeMs(windowColumn) = ...
                (relativeFrameIdx * cfg.framePeriod ...
                + windowCenterChirp * cfg.chirpPeriod) * 1e3;

            output.windowPhysicalFrame(windowColumn) = frameIdx;
            output.windowIndexInFrame(windowColumn) = localWindowIdx;

            windowColumn = windowColumn + 1;
        end
    end
end

function candidateTable = extractCandidates( ...
        rangeTimeMapDb, ...
        aliasVelocityMap, ...
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

    numWindows = size(rangeTimeMapDb, 2);

    for windowIdx = 1:numWindows
        profile = double(rangeTimeMapDb(:, windowIdx));

        profileSmooth = movmean( ...
            profile, cfg.rangeSmoothBins, 'omitnan');

        profileSmooth(~rangeGate) = -Inf;

        isLocalPeak = false(numel(profileSmooth), 1);

        % 不允许候选搜索上下边界被当成局部峰。
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

        for peakIdx = 1:numel(peakIndices)
            currentBin = peakIndices(peakIdx);
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

                if numel(selectedIndices) ...
                        >= cfg.maxCandidatesPerWindow
                    break;
                end
            end
        end

        for selectedIdx = 1:numel(selectedIndices)
            currentBin = selectedIndices(selectedIdx);

            currentVelocity = ...
                aliasVelocityMap(currentBin, windowIdx);

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

            rangeBin(end + 1, 1) = ...
                currentBin; %#ok<AGROW>
        end
    end

    candidateTable = table( ...
        globalWindow, ...
        physicalFrame, ...
        windowInFrame, ...
        timeMs, ...
        rangeM, ...
        aliasedVelocity, ...
        relativeStrength, ...
        rangeBin, ...
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

function [trackTable, fitInfo] = selectUltraHighSpeedTrack( ...
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

    timeGate = ...
        candidateTable.Time_ms >= cfg.trackStartTimeMs ...
        & candidateTable.Time_ms <= cfg.trackEndTimeMs;

    candidates = candidateTable(timeGate, :);

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

            if speed < cfg.fitSpeedMin ...
                    || speed > cfg.fitSpeedMax
                continue;
            end

            intercept = range1 - speed * time1;

            [selectedRows, metric] = ...
                associateCandidatesToHypothesis( ...
                    candidates, speed, intercept, ...
                    cfg, derived);

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

    % 迭代执行：重新拟合距离直线，再重新关联候选点。
    for iteration = 1:6
        selectedTime = ...
            candidates.Time_ms(selectedRows) * 1e-3;

        selectedRange = ...
            candidates.Range_m(selectedRows);

        p = polyfit(selectedTime, selectedRange, 1);

        speed = p(1);
        intercept = p(2);

        if speed < cfg.fitSpeedMin ...
                || speed > cfg.fitSpeedMax
            % 当前迭代结果越界时，保留上一轮有效关联，
            % 不直接把整条候选轨迹判为无效。
            break;
        end

        [newSelection, ~] = ...
            associateCandidatesToHypothesis( ...
                candidates, speed, intercept, ...
                cfg, derived);

        if numel(newSelection) < cfg.minTrackWindows
            % 新一轮关联变差时，继续使用上一轮有效结果。
            break;
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

    fittedRange = polyval( ...
        p, trackTable.Time_ms * 1e-3);

    distanceResidual = ...
        trackTable.Range_m - fittedRange;

    expectedAlias = wrapVelocity(p(1), derived.vMax);

    circularVelocityResidual = ...
        circularVelocityDifference( ...
            trackTable.AliasedVelocity_mps, ...
            expectedAlias, ...
            derived.velocityPeriod);

    trackTable.FittedRange_m = fittedRange;
    trackTable.FitResidual_m = distanceResidual;

    trackTable.ExpectedAliasedVelocity_mps = ...
        repmat(expectedAlias, height(trackTable), 1);

    trackTable.CircularVelocityResidual_mps = ...
        circularVelocityResidual;

    fitInfo.valid = true;
    fitInfo.speed = p(1);
    fitInfo.intercept = p(2);
    fitInfo.rmse = sqrt(mean(distanceResidual.^2));
    fitInfo.expectedAliasedSpeed = expectedAlias;
    fitInfo.meanCircularVelocityResidual = ...
        mean(circularVelocityResidual);
end

function [selectedRows, metric] = ...
        associateCandidatesToHypothesis( ...
        candidates, speed, intercept, cfg, derived)

    selectedRows = [];

    distanceResidualList = [];
    velocityResidualList = [];
    totalStrength = 0;

    expectedAlias = wrapVelocity(speed, derived.vMax);
    measuredAlias = derived.measuredAliasedSpeed;

    uniqueWindows = unique( ...
        candidates.GlobalWindow, 'stable');

    for windowIdx = 1:numel(uniqueWindows)
        currentWindow = uniqueWindows(windowIdx);

        rows = find( ...
            candidates.GlobalWindow == currentWindow);

        predictedRange = ...
            speed * candidates.Time_ms(rows) * 1e-3 ...
            + intercept;

        distanceResidual = abs( ...
            candidates.Range_m(rows) - predictedRange);

        % 有模糊速度仅作为软约束。
        velocityResidual = circularVelocityDifference( ...
            candidates.AliasedVelocity_mps(rows), ...
            expectedAlias, ...
            derived.velocityPeriod);

        measuredVelocityResidual = circularVelocityDifference( ...
            candidates.AliasedVelocity_mps(rows), ...
            measuredAlias, ...
            derived.velocityPeriod);

        validMask = ...
            distanceResidual <= cfg.trackTolerance;

        if ~any(validMask)
            continue;
        end

        validRows = rows(validMask);
        dRes = distanceResidual(validMask);
        vRes = velocityResidual(validMask);
        measuredVRes = measuredVelocityResidual(validMask);
        strength = ...
            candidates.RelativeStrength_dB(validRows);

        normalizedCost = ...
            (dRes / cfg.trackTolerance).^2 ...
            + cfg.velocityCostWeight ...
            * (vRes / derived.vMax).^2 ...
            + cfg.measuredAliasCostWeight ...
            * (measuredVRes ...
            / cfg.measuredAliasTolerance).^2 ...
            - cfg.strengthCostWeight ...
            * max(strength, 0) ...
            / max(cfg.candidateThresholdDb, 1);

        [~, bestLocalIdx] = min(normalizedCost);

        selectedRows(end + 1, 1) = ...
            validRows(bestLocalIdx); %#ok<AGROW>

        distanceResidualList(end + 1, 1) = ...
            dRes(bestLocalIdx); %#ok<AGROW>

        velocityResidualList(end + 1, 1) = ...
            vRes(bestLocalIdx); %#ok<AGROW>

        totalStrength = totalStrength ...
            + max(strength(bestLocalIdx), 0);
    end

    if isempty(selectedRows)
        metric = -Inf;
        return;
    end

    metric = ...
        cfg.trackCountWeight * numel(selectedRows) ...
        + cfg.trackStrengthWeight * totalStrength ...
        - cfg.trackDistancePenalty ...
        * mean(distanceResidualList) ...
        - cfg.trackVelocityPenalty ...
        * mean(velocityResidualList);
end

function trackTable = unwrapTrackVelocity( ...
        trackTable, vMax, referenceSpeed, cfg)

    % =========================================================
    % 实测速度先验辅助的全局速度解模糊
    %
    % 对每个轨迹点构造：
    %   v(i,k) = v_alias(i) + k * 2Vmax
    %
    % 使用动态规划寻找整条轨迹总代价最小的模糊数序列。
    % 代价同时考虑：
    %   1. 与实测速度的偏差；
    %   2. 与距离拟合速度的偏差；
    %   3. 相邻时刻解模糊速度的连续性。
    % =========================================================

    ambiguityPeriod = 2 * vMax;

    ambiguityCandidates = ...
        cfg.ambiguityNumberMin:cfg.ambiguityNumberMax;

    aliasedVelocity = ...
        double(trackTable.AliasedVelocity_mps(:));

    numPoints = numel(aliasedVelocity);
    numStates = numel(ambiguityCandidates);

    possibleVelocity = ...
        aliasedVelocity ...
        + ambiguityPeriod * ambiguityCandidates;

    validMask = ...
        possibleVelocity >= cfg.unwrapSpeedMin ...
        & possibleVelocity <= cfg.unwrapSpeedMax;

    measuredCost = ...
        cfg.unwrapMeasuredWeight ...
        * ((possibleVelocity - cfg.measuredSpeed) ...
        / cfg.measuredSpeedStd).^2;

    fitCost = ...
        cfg.unwrapFitWeight ...
        * ((possibleVelocity - referenceSpeed) ...
        / cfg.distanceFitSpeedStd).^2;

    localCost = measuredCost + fitCost;
    localCost(~validMask) = Inf;

    accumulatedCost = inf(numPoints, numStates);
    previousState = zeros(numPoints, numStates);

    accumulatedCost(1, :) = localCost(1, :);

    for pointIdx = 2:numPoints

        for stateIdx = 1:numStates

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

        trackTable.AmbiguityNumber = nan(numPoints, 1);
        trackTable.UnwrappedVelocity_mps = nan(numPoints, 1);
        trackTable.MeasuredSpeed_mps = ...
            repmat(cfg.measuredSpeed, numPoints, 1);

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

    trackTable.AmbiguityNumber = ambiguityNumber;
    trackTable.UnwrappedVelocity_mps = unwrappedVelocity;

    trackTable.MeasuredSpeed_mps = ...
        repmat(cfg.measuredSpeed, numPoints, 1);

    trackTable.MeasuredSpeedResidual_mps = ...
        unwrappedVelocity - cfg.measuredSpeed;

    trackTable.DistanceFitSpeedResidual_mps = ...
        unwrappedVelocity - referenceSpeed;

    trackTable.GlobalUnwrapPathCost = ...
        repmat(bestFinalCost, numPoints, 1);
end

function wrappedVelocity = wrapVelocity(velocity, vMax)
    period = 2 * vMax;
    wrappedVelocity = mod(velocity + vMax, period) - vMax;
end

function difference = circularVelocityDifference( ...
        velocity1, velocity2, period)

    directDifference = abs(velocity1 - velocity2);

    difference = min( ...
        directDifference, ...
        period - directDifference);
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
            (localFrameIdx - 1) ...
            * columnsPerFrame + 1;

        lastColumn = min( ...
            localFrameIdx * columnsPerFrame, ...
            totalColumns);

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
            (localFrameIdx - 1) ...
            * framePeriod * 1e3;

        activeEndMs = ...
            frameStartMs ...
            + activeDuration * 1e3;

        xline( ...
            ax, activeEndMs, ...
            'w--', 'LineWidth', 0.8);

        if localFrameIdx < numFrames
            nextFrameStartMs = ...
                localFrameIdx ...
                * framePeriod * 1e3;

            xline( ...
                ax, nextFrameStartMs, ...
                'w:', 'LineWidth', 0.8);
        end
    end

    hold(ax, 'off');
end
