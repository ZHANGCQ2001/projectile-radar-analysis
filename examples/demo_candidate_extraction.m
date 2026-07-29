%% Candidate extraction demonstration without raw radar data

repoRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(repoRoot, 'src'));

cfg = pradar.defaultConfig();
cfg.measuredSpeed = 400;
cfg.candidateRangeMin = 0.5;
cfg.candidateRangeMax = 4.5;
cfg.candidateThresholdDb = 7;
cfg.maxCandidatesPerWindow = 3;
cfg.minCandidateSeparation = 0.5;
cfg.rangeSmoothBins = 3;

rangeAxis = linspace(0, 5, 101);
numWindows = 5;
rangeTimeMapDb = zeros(numel(rangeAxis), numWindows);
aliasVelocityMap = zeros(size(rangeTimeMapDb));

rng(1);
rangeTimeMapDb = rangeTimeMapDb + 1.2 * randn(size(rangeTimeMapDb));

candidateRanges = [1.2, 2.5, 4.0];
candidateStrengths = [18, 12, 9];
candidateVelocities = [-55, 60, 0];

for windowIndex = 1:numWindows
    for peakIndex = 1:numel(candidateRanges)
        center = candidateRanges(peakIndex) + 0.08 * (windowIndex - 1);
        profile = candidateStrengths(peakIndex) * exp( ...
            -0.5 * ((rangeAxis - center) / 0.08).^2);
        rangeTimeMapDb(:, windowIndex) = ...
            rangeTimeMapDb(:, windowIndex) + profile(:);
        [~, bin] = min(abs(rangeAxis - center));
        aliasVelocityMap(:, windowIndex) = candidateVelocities(peakIndex);
        aliasVelocityMap(bin, windowIndex) = candidateVelocities(peakIndex);
    end
end

targetData.windowPhysicalFrame = ones(1, numWindows);
targetData.windowIndexInFrame = 1:numWindows;
targetData.windowTimeMs = (0:numWindows - 1) * 0.192;

candidateTable = pradar.extractCandidates( ...
    rangeTimeMapDb, aliasVelocityMap, targetData, rangeAxis, cfg);
disp(candidateTable);

figure('Color', 'w');
imagesc(targetData.windowTimeMs, rangeAxis, rangeTimeMapDb);
axis xy;
colorbar;
hold on;
plot(candidateTable.Time_ms, candidateTable.Range_m, ...
    'wo', 'MarkerFaceColor', 'r', 'MarkerSize', 7);
xlabel('Time (ms)');
ylabel('Range (m)');
title('Synthetic candidate extraction demonstration');
