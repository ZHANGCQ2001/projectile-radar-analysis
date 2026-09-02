clear;
clc;
close all;

%% Path

studyDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(studyDir);

addpath(fullfile(repoRoot, 'src'));
addpath(fullfile(repoRoot, 'configs'));

%% Configuration

cfg = config_0725_123207();
derived = pradar.deriveParameters(cfg);

dataFile = fullfile( ...
    repoRoot, 'data', '123207_frames_126_135.bin');

backgroundFrames = 1:8;

targetFrame = 9;
originalFrameNumber = 134;

% Frame 134 中弹丸主要出现区域
timeRoiMs = [1.9, 3.05];
rangeRoi = [0.70, 2.00];

% Range track
trackGate_m = 0.25;
trackSmoothLength = 5;

% Time-frequency analysis
tfWindowLength = 32;
tfOverlap = tfWindowLength - 1;
tfNfft = 128;

stftClimDb = [-35, 0];
fsstClimDb = [-35, 0];

%% Basic parameters

lambda = derived.lambda;
Tc = cfg.chirpPeriod;
slowTimeFs = 1 / Tc;

fprintf('========================================\n');
fprintf('Single-frame time-frequency study\n');
fprintf('Original physical frame: %d\n', originalFrameNumber);
fprintf('Chirp period: %.3f us\n', Tc * 1e6);
fprintf('Slow-time sampling rate: %.3f kHz\n', slowTimeFs / 1e3);
fprintf('Maximum aliased velocity: +/- %.3f m/s\n', derived.vMax);
fprintf('TF window length: %d chirps\n', tfWindowLength);
fprintf('TF window duration: %.3f us\n', ...
    tfWindowLength * Tc * 1e6);
fprintf('========================================\n');

%% Open data

fid = fopen(dataFile, 'rb', 'ieee-le');

if fid < 0
    error('Unable to open data file: %s', dataFile);
end

cleanupObject = onCleanup(@() fclose(fid)); %#ok<NASGU>

%% Background range profile

numBackgroundChirps = ...
    numel(backgroundFrames) * cfg.numChirpsPerFrame;

backgroundRangePower = zeros( ...
    cfg.rangeFftSize, numBackgroundChirps, 'single');

columnIndex = 1;

for frameIndex = backgroundFrames

    adcFrame = pradar.readDca1000Frame( ...
        fid, frameIndex, cfg, derived);

    rangeFft = fft( ...
        adcFrame .* derived.rangeWindow, ...
        cfg.rangeFftSize, 1);

    rangePower = sum(abs(rangeFft).^2, 3);

    columns = columnIndex: ...
        columnIndex + cfg.numChirpsPerFrame - 1;

    backgroundRangePower(:, columns) = ...
        single(rangePower);

    columnIndex = columns(end) + 1;
end

backgroundProfile = median( ...
    backgroundRangePower, 2, 'omitnan');

%% Target frame Range FFT

adcTarget = pradar.readDca1000Frame( ...
    fid, targetFrame, cfg, derived);

rangeFftTarget = fft( ...
    adcTarget .* derived.rangeWindow, ...
    cfg.rangeFftSize, 1);

rangePowerTarget = sum( ...
    abs(rangeFftTarget).^2, 3);

rangeEnhancedDb = 10 * log10( ...
    (double(rangePowerTarget) + 1e-12) ./ ...
    (double(backgroundProfile) + 1e-12));

chirpTimeMs = ...
    (0:cfg.numChirpsPerFrame-1) ...
    * Tc * 1e3;

%% Range-time ROI

timeMask = ...
    chirpTimeMs >= timeRoiMs(1) & ...
    chirpTimeMs <= timeRoiMs(2);

rangeMask = ...
    derived.rangeAxis >= rangeRoi(1) & ...
    derived.rangeAxis <= rangeRoi(2);

chirpIndices = find(timeMask);
rangeIndices = find(rangeMask);

%% Track projectile range

rawTrackRange = trackRangeFromEnhancedMap( ...
    rangeEnhancedDb, ...
    derived.rangeAxis, ...
    chirpIndices, ...
    rangeIndices, ...
    trackGate_m);

trackRange = movmedian( ...
    rawTrackRange, trackSmoothLength, ...
    'omitnan');

trackRange = movmean( ...
    trackRange, trackSmoothLength, ...
    'omitnan');

%% Figure 1: single-frame range-time track

figure('Color', 'w');

imagesc( ...
    chirpTimeMs, ...
    derived.rangeAxis, ...
    rangeEnhancedDb);

axis xy;

ylim([0, 3]);
xlim([0, cfg.numChirpsPerFrame * Tc * 1e3]);

caxis([0, 15]);
colormap(turbo);
colorbar;

hold on;

plot( ...
    chirpTimeMs(chirpIndices), ...
    rawTrackRange, ...
    'w.', ...
    'MarkerSize', 8);

plot( ...
    chirpTimeMs(chirpIndices), ...
    trackRange, ...
    'r-', ...
    'LineWidth', 2);

hold off;

xlabel('Time (ms)');
ylabel('Range (m)');

title(sprintf( ...
    'Single-frame range-time tracking: physical frame %d', ...
    originalFrameNumber));

legend( ...
    'Raw range peak', ...
    'Smoothed target track', ...
    'Location', 'best');

%% Extract complex slow-time signal along range track

numTrackChirps = numel(chirpIndices);

trackSignalRx = complex(zeros( ...
    numTrackChirps, cfg.numRx));

for timeIndex = 1:numTrackChirps

    chirpIndex = chirpIndices(timeIndex);
    targetRange = trackRange(timeIndex);

    for rxIndex = 1:cfg.numRx

        rangeData = double( ...
            rangeFftTarget(:, chirpIndex, rxIndex));

        trackSignalRx(timeIndex, rxIndex) = ...
            interp1( ...
            derived.rangeAxis, ...
            rangeData, ...
            targetRange, ...
            'linear', ...
            0);
    end
end

%% STFT

tfWindow = pradar.makeHannWindow(tfWindowLength);

stftPower = [];

for rxIndex = 1:cfg.numRx

    [stftRx, frequencyStft, timeStft] = ...
        spectrogram( ...
        trackSignalRx(:, rxIndex), ...
        tfWindow, ...
        tfOverlap, ...
        tfNfft, ...
        slowTimeFs, ...
        'centered');

    if isempty(stftPower)
        stftPower = zeros(size(stftRx));
    end

    stftPower = stftPower + abs(stftRx).^2;
end

velocityStft = ...
    frequencyStft * lambda / 2;

timeStftMs = ...
    chirpTimeMs(chirpIndices(1)) ...
    + timeStft * 1e3;

stftPowerDb = 10 * log10( ...
    stftPower / max(stftPower(:)) + 1e-12);

[~, ridgeIndexStft] = max(stftPower, [], 1);

ridgeVelocityStft = ...
    velocityStft(ridgeIndexStft);

%% Figure 2: STFT

figure('Color', 'w');

imagesc( ...
    timeStftMs, ...
    velocityStft, ...
    stftPowerDb);

axis xy;

caxis(stftClimDb);
colormap(turbo);
colorbar;

hold on;

plot( ...
    timeStftMs, ...
    ridgeVelocityStft, ...
    'w-', ...
    'LineWidth', 1.6);

hold off;

ylim([-derived.vMax, derived.vMax]);

xlabel('Time (ms)');
ylabel('Aliased radial velocity (m/s)');

title(sprintf( ...
    'STFT time-velocity response: physical frame %d', ...
    originalFrameNumber));

%% FSST

if exist('fsst', 'file') == 2

    fsstPower = [];

    for rxIndex = 1:cfg.numRx

        [fsstRx, frequencyFsst, timeFsst] = ...
            fsst( ...
            trackSignalRx(:, rxIndex), ...
            slowTimeFs, ...
            tfWindow);

        if isempty(fsstPower)
            fsstPower = zeros(size(fsstRx));
        end

        fsstPower = fsstPower + abs(fsstRx).^2;
    end

    velocityFsst = ...
        frequencyFsst * lambda / 2;

    timeFsstMs = ...
        chirpTimeMs(chirpIndices(1)) ...
        + timeFsst * 1e3;

    fsstPowerDb = 10 * log10( ...
        fsstPower / max(fsstPower(:)) + 1e-12);

    [~, ridgeIndexFsst] = max( ...
        fsstPower, [], 1);

    ridgeVelocityFsst = ...
        velocityFsst(ridgeIndexFsst);

    %% Figure 3: FSST

    figure('Color', 'w');

    imagesc( ...
        timeFsstMs, ...
        velocityFsst, ...
        fsstPowerDb);

    axis xy;

    caxis(fsstClimDb);
    colormap(turbo);
    colorbar;

    hold on;

    plot( ...
        timeFsstMs, ...
        ridgeVelocityFsst, ...
        'w-', ...
        'LineWidth', 1.6);

    hold off;

    ylim([-derived.vMax, derived.vMax]);

    xlabel('Time (ms)');
    ylabel('Aliased radial velocity (m/s)');

    title(sprintf( ...
        'FSST time-velocity response: physical frame %d', ...
        originalFrameNumber));

    %% Figure 4: ridge comparison

    figure('Color', 'w');

    plot( ...
        timeStftMs, ...
        ridgeVelocityStft, ...
        'LineWidth', 1.5);

    hold on;

    plot( ...
        timeFsstMs, ...
        ridgeVelocityFsst, ...
        'LineWidth', 1.5);

    hold off;

    grid on;
    box on;

    ylim([-derived.vMax, derived.vMax]);

    xlabel('Time (ms)');
    ylabel('Aliased radial velocity (m/s)');

    title('STFT and FSST ridge comparison');

    legend( ...
        'STFT ridge', ...
        'FSST ridge', ...
        'Location', 'best');

else

    warning([ ...
        'fsst is unavailable. ' ...
        'Signal Processing Toolbox may be required.']);

end

%% Local function

function trackRange = trackRangeFromEnhancedMap( ...
        enhancedDb, rangeAxis, ...
        chirpIndices, rangeIndices, gate_m)

    roiMap = enhancedDb( ...
        rangeIndices, chirpIndices);

    [~, linearIndex] = max(roiMap(:));

    [seedRangeLocal, seedTimeLocal] = ...
        ind2sub(size(roiMap), linearIndex);

    seedRangeIndex = ...
        rangeIndices(seedRangeLocal);

    numTimes = numel(chirpIndices);

    trackRange = nan(1, numTimes);

    trackRange(seedTimeLocal) = ...
        rangeAxis(seedRangeIndex);

    % Forward
    for timeLocal = seedTimeLocal+1:numTimes

        previousRange = ...
            trackRange(timeLocal-1);

        allowed = rangeIndices( ...
            abs(rangeAxis(rangeIndices) ...
            - previousRange) <= gate_m);

        if isempty(allowed)
            trackRange(timeLocal) = previousRange;
            continue;
        end

        chirpIndex = ...
            chirpIndices(timeLocal);

        [~, localMaximum] = max( ...
            enhancedDb(allowed, chirpIndex));

        trackRange(timeLocal) = ...
            rangeAxis(allowed(localMaximum));
    end

    % Backward
    for timeLocal = seedTimeLocal-1:-1:1

        previousRange = ...
            trackRange(timeLocal+1);

        allowed = rangeIndices( ...
            abs(rangeAxis(rangeIndices) ...
            - previousRange) <= gate_m);

        if isempty(allowed)
            trackRange(timeLocal) = previousRange;
            continue;
        end

        chirpIndex = ...
            chirpIndices(timeLocal);

        [~, localMaximum] = max( ...
            enhancedDb(allowed, chirpIndex));

        trackRange(timeLocal) = ...
            rangeAxis(allowed(localMaximum));
    end
end