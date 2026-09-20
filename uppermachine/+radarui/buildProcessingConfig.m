function cfg = buildProcessingConfig(appConfig)
%BUILDPROCESSINGCONFIG Convert upper-machine radar settings to pradar config.
%
%   cfg = radarui.buildProcessingConfig(appConfig)
%
%   appConfig is a plain structure so that the processing module does not
%   depend on private properties of RadarControlMachineApp.

    arguments
        appConfig struct
    end

    cfg = pradar.defaultConfig();
    cfg.caseId = "uppermachine";

    cfg.numSamples = getValue(appConfig, 'numSamples', cfg.numSamples);
    cfg.numChirpsPerFrame = getValue( ...
        appConfig, 'numChirpsPerFrame', cfg.numChirpsPerFrame);
    cfg.numRx = getValue(appConfig, 'numRx', cfg.numRx);
    cfg.numTx = getValue(appConfig, 'numTx', cfg.numTx);
    cfg.rangeFftSize = getValue( ...
        appConfig, 'rangeFftSize', cfg.rangeFftSize);

    cfg.adcSampleRate = getValue( ...
        appConfig, 'adcSampleRateMsps', cfg.adcSampleRate / 1e6) * 1e6;
    cfg.slope = getValue( ...
        appConfig, 'slopeMHzPerUs', cfg.slope / 1e12) * 1e12;
    cfg.startFreq = getValue( ...
        appConfig, 'startFreqGHz', cfg.startFreq / 1e9) * 1e9;
    cfg.chirpPeriod = getValue( ...
        appConfig, 'chirpPeriodUs', cfg.chirpPeriod / 1e-6) * 1e-6;
    cfg.framePeriod = getValue( ...
        appConfig, 'framePeriodMs', cfg.framePeriod * 1e3) * 1e-3;

    % Processing defaults are intentionally independent from the RD display
    % window in the legacy upper machine. The projectile algorithm needs a
    % short-time Doppler window.
    requestedWinSize = getValue(appConfig, 'processingWinSize', 16);
    cfg.winSize = min( ...
        cfg.numChirpsPerFrame, max(2, round(requestedWinSize)));

    requestedWinStep = getValue( ...
        appConfig, 'processingWinStep', cfg.winSize);
    cfg.winStep = min( ...
        cfg.numChirpsPerFrame, max(1, round(requestedWinStep)));

    requestedDopplerFft = getValue( ...
        appConfig, 'processingDopplerFftSize', 128);
    requestedDopplerFft = max(cfg.winSize, round(requestedDopplerFft));
    if mod(requestedDopplerFft, 2) ~= 0
        requestedDopplerFft = requestedDopplerFft + 1;
    end
    cfg.dopplerFftSize = requestedDopplerFft;

    cfg.slowTimeMeanRemoval = false;
    cfg.useFullAliasedVelocityAxis = true;
    cfg.highSpeedMin = 0;
    cfg.rdProjectionMode = "range";

    referenceSpeed = abs(getValue(appConfig, 'approxSpeed', 400));
    if ~isfinite(referenceSpeed) || referenceSpeed <= 0
        referenceSpeed = 400;
    end
    cfg.measuredSpeed = referenceSpeed;

    cfg.fitSpeedMin = max(1, 0.45 * referenceSpeed);
    cfg.fitSpeedMax = max(cfg.fitSpeedMin + 100, 1.55 * referenceSpeed);
    cfg.unwrapSpeedMin = max(0, 0.45 * referenceSpeed);
    cfg.unwrapSpeedMax = max( ...
        cfg.unwrapSpeedMin + 100, 1.55 * referenceSpeed);

    cfg.measuredSpeedStd = max(35, 0.08 * referenceSpeed);
    cfg.distanceFitSpeedStd = max(50, 0.10 * referenceSpeed);
    cfg.unwrapContinuityStd = max(25, 0.05 * referenceSpeed);

    % The processing window replaces these values after it knows the file
    % length. Keep them valid for parameter derivation before a file is read.
    cfg.backgroundFrameStart = 1;
    cfg.backgroundFrameEnd = 1;
    cfg.targetFrameStart = 1;
    cfg.targetFrameEnd = 1;

    cfg.generateRdGif = false;
    cfg.generateRawRdGif = false;
    cfg.generateMeanRemovedRdGif = false;
    cfg.generateEnhancedRdGif = false;
    cfg.plotVisible = false;
    cfg.saveResults = false;
    cfg.saveFigures = false;

    % GUI result keeps compact maps/tables by default, not the full 3-D
    % background and target RD cubes.
    cfg.keepIntermediateData = false;
end

function value = getValue(s, fieldName, defaultValue)
    if isfield(s, fieldName)
        candidate = s.(fieldName);
        if ~isempty(candidate)
            value = candidate;
            return;
        end
    end

    value = defaultValue;
end
