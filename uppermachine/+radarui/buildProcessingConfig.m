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
    requestedWinSize = getValue(appConfig, 'processingWinSize', 64);
    cfg.winSize = min( ...
        cfg.numChirpsPerFrame, max(2, round(requestedWinSize)));

    requestedWinStep = getValue( ...
        appConfig, 'processingWinStep', cfg.winSize);
    cfg.winStep = min( ...
        cfg.numChirpsPerFrame, max(1, round(requestedWinStep)));

    requestedDopplerFft = getValue( ...
        appConfig, 'processingDopplerFftSize', 256);
    requestedDopplerFft = max(cfg.winSize, round(requestedDopplerFft));
    if mod(requestedDopplerFft, 2) ~= 0
        requestedDopplerFft = requestedDopplerFft + 1;
    end
    cfg.dopplerFftSize = requestedDopplerFft;

    cfg.slowTimeMeanRemoval = false;
    cfg.useFullAliasedVelocityAxis = true;
    cfg.highSpeedMin = 0;
    cfg.rdProjectionMode = "range";

    % Keep algorithm gates separate from display limits. The default GUI
    % shows a wider scene while candidate extraction may use a tighter gate.
    cfg.displayRangeMin = 0;
    cfg.displayRangeMax = 10;

    % Interface 2 owns the editable reference speed and geometry settings.
    % These are initial defaults, not speed measurements from interface 1.
    cfg.useVelocityHardGate = true;
    cfg.velocityTolerance = 70;
    cfg.velocityCostWeight = 0.60;
    cfg.measuredAliasTolerance = 60;
    cfg.measuredAliasCostWeight = 0.60;
    cfg.strengthCostWeight = 0.18;
    cfg.trackStartTimeMs = 0;
    cfg.trackEndTimeMs = Inf;

    referenceSpeed = abs(getValue(appConfig, 'approxSpeed', 400));
    if ~isfinite(referenceSpeed) || referenceSpeed <= 0
        referenceSpeed = 400;
    end
    cfg.measuredSpeed = referenceSpeed;

    % Physical bounds are independent of the closest-point speed prior.
    % Editing the anchor must not silently prune other-time velocity branches.
    cfg.fitSpeedMin = 1;
    cfg.fitSpeedMax = 2000;
    cfg.unwrapSpeedMin = cfg.fitSpeedMin;
    cfg.unwrapSpeedMax = cfg.fitSpeedMax;

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
    if isfield(appConfig, 'overviewTargetFrames')
        cfg.overviewTargetFrames = appConfig.overviewTargetFrames;
    end
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
