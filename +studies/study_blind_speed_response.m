clear;
clc;
close all;

%% Repository path

studyDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(studyDir);

addpath(fullfile(repoRoot, 'src'));
addpath(fullfile(repoRoot, 'configs'));

%% Radar configuration

cfg = pradar.defaultConfig();

cfg.winSize = 16;
cfg.dopplerFftSize = 128;
cfg.chirpPeriod = 12e-6;

derived = pradar.deriveParameters(cfg);

N = cfg.winSize;
Tc = cfg.chirpPeriod;
lambda = derived.lambda;
Nd = cfg.dopplerFftSize;

vMax = derived.vMax;
blindSpeed = 2 * vMax;

fprintf('========================================\n');
fprintf('Blind-speed response study\n');
fprintf('Wavelength: %.6f m\n', lambda);
fprintf('Chirp period: %.3f us\n', Tc * 1e6);
fprintf('Slow-time window: %d chirps\n', N);
fprintf('Doppler FFT size: %d\n', Nd);
fprintf('Maximum unambiguous velocity: %.3f m/s\n', vMax);
fprintf('Blind-speed interval: %.3f m/s\n', blindSpeed);
fprintf('========================================\n');

%% Velocity offset around one blind speed

deltaV = linspace(-20, 20, 1601);

%% Theoretical response of slow-time mean removal

omega = 4 * pi * Tc / lambda .* deltaV;

meanGain = ones(size(omega));

nonzeroMask = abs(omega) > 1e-12;

meanGain(nonzeroMask) = ...
    sin(N * omega(nonzeroMask) / 2) ./ ...
    (N * sin(omega(nonzeroMask) / 2));

meanGain(~nonzeroMask) = 1;

powerRemainTheory = 1 - abs(meanGain).^2;

powerRemainTheory = max(powerRemainTheory, 1e-12);

attenuationTheoryDb = -10 * log10(powerRemainTheory);

%% Numerical simulation

n = (0:N-1).';

dopplerWindow = pradar.makeHannWindow(N);

powerRemainSimulation = zeros(size(deltaV));
peakAttenuationDb = zeros(size(deltaV));

for index = 1:numel(deltaV)

    dv = deltaV(index);

    phaseIncrement = 4 * pi * dv * Tc / lambda;

    x = exp(1j * phaseIncrement * n);

    %% Total-power response

    xRemoved = x - mean(x);

    powerRemainSimulation(index) = ...
        sum(abs(xRemoved).^2) / sum(abs(x).^2);

    %% Current processing-chain peak response

    xReference = x .* dopplerWindow;
    xProcessed = xRemoved .* dopplerWindow;

    spectrumReference = fftshift(fft(xReference, Nd));
    spectrumProcessed = fftshift(fft(xProcessed, Nd));

    referencePeakPower = max(abs(spectrumReference).^2);
    processedPeakPower = max(abs(spectrumProcessed).^2);

    peakRatio = processedPeakPower / referencePeakPower;

    peakRatio = max(peakRatio, 1e-12);

    peakAttenuationDb(index) = -10 * log10(peakRatio);

end

powerRemainSimulation = max(powerRemainSimulation, 1e-12);

attenuationSimulationDb = ...
    -10 * log10(powerRemainSimulation);

%% Limit display range

displayMaxDb = 60;

attenuationTheoryPlot = ...
    min(attenuationTheoryDb, displayMaxDb);

attenuationSimulationPlot = ...
    min(attenuationSimulationDb, displayMaxDb);

peakAttenuationPlot = ...
    min(peakAttenuationDb, displayMaxDb);

%% Figure 1: theoretical validation

figure('Color', 'w');

plot(deltaV, attenuationTheoryPlot, ...
    'LineWidth', 1.8);
hold on;

plot(deltaV, attenuationSimulationPlot, '--', ...
    'LineWidth', 1.5);

xline(0, ':', 'Blind speed');

grid on;
box on;

xlabel('Velocity offset from blind speed \Delta v (m/s)');
ylabel('Attenuation (dB)');

title('Slow-time mean-removal blind-speed response');

legend( ...
    'Theoretical response', ...
    'Numerical simulation', ...
    'Location', 'best');

xlim([min(deltaV), max(deltaV)]);
ylim([0, displayMaxDb]);

%% Figure 2: practical processing-chain response

figure('Color', 'w');

plot(deltaV, attenuationTheoryPlot, ...
    'LineWidth', 1.6);
hold on;

plot(deltaV, peakAttenuationPlot, ...
    'LineWidth', 1.8);

xline(0, ':', 'Blind speed');

grid on;
box on;

xlabel('Velocity offset from blind speed \Delta v (m/s)');
ylabel('Attenuation (dB)');

title(sprintf( ...
    'Blind-speed response: %d-chirp window, %d-point Doppler FFT', ...
    N, Nd));

legend( ...
    'Mean-removal total-power response', ...
    'RD peak-power response', ...
    'Location', 'best');

xlim([min(deltaV), max(deltaV)]);
ylim([0, displayMaxDb]);

%% Representative velocity offsets

sampleOffsets = [0.5, 1, 2, 3, 5, 7.5, 10];

sampleTheory = interp1( ...
    deltaV, attenuationTheoryDb, ...
    sampleOffsets, 'linear');

samplePeak = interp1( ...
    deltaV, peakAttenuationDb, ...
    sampleOffsets, 'linear');

resultTable = table( ...
    sampleOffsets.', ...
    sampleTheory.', ...
    samplePeak.', ...
    'VariableNames', { ...
    'VelocityOffset_mps', ...
    'TheoryAttenuation_dB', ...
    'RdPeakAttenuation_dB'});

disp(resultTable);