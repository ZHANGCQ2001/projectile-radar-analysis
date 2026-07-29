function cfg = defaultConfig()
%DEFAULTCONFIG Return common defaults for projectile radar analysis.

    % Raw data and radar parameters
    cfg.caseId = "custom";
    cfg.numSamples = 64;
    cfg.numChirpsPerFrame = 256;
    cfg.numRx = 8;
    cfg.numTx = 1;
    cfg.rangeFftSize = 256;
    cfg.dopplerFftSize = 128;
    cfg.adcSampleRate = 10e6;
    cfg.slope = 60.01e12;
    cfg.startFreq = 77e9;
    cfg.chirpPeriod = 12e-6;
    cfg.framePeriod = 3.5e-3;
    cfg.c = 3e8;

    % Short-time RD processing
    cfg.winSize = 16;
    cfg.winStep = 16;
    cfg.slowTimeMeanRemoval = true;
    cfg.useFullAliasedVelocityAxis = false;
    cfg.highSpeedMin = 0;

    % Candidate extraction
    cfg.candidateRangeMin = 0.25;
    cfg.candidateRangeMax = 6.0;
    cfg.candidateThresholdDb = 3.0;
    cfg.maxCandidatesPerWindow = 6;
    cfg.minCandidateSeparation = 0.25;
    cfg.rangeSmoothBins = 3;

    % Track search and association
    cfg.fitSpeedMin = 200;
    cfg.fitSpeedMax = 1700;
    cfg.minHypothesisSpanMs = 0.40;
    cfg.trackTolerance = 0.55;
    cfg.useVelocityHardGate = false;
    cfg.velocityTolerance = 70;
    cfg.velocityCostWeight = 0.30;
    cfg.measuredAliasTolerance = 60;
    cfg.measuredAliasCostWeight = 0.30;
    cfg.strengthCostWeight = 0.10;
    cfg.minTrackWindows = 5;
    cfg.trackStartTimeMs = -Inf;
    cfg.trackEndTimeMs = Inf;
    cfg.trackCountWeight = 100;
    cfg.trackStrengthWeight = 0.30;
    cfg.trackDistancePenalty = 30;
    cfg.trackVelocityPenalty = 0.30;
    cfg.maxTrackIterations = 6;

    % Velocity unwrapping
    cfg.measuredSpeed = NaN;
    cfg.measuredSpeedStd = 35;
    cfg.distanceFitSpeedStd = 50;
    cfg.unwrapContinuityStd = 25;
    cfg.unwrapMeasuredWeight = 1.00;
    cfg.unwrapFitWeight = 0.45;
    cfg.unwrapContinuityWeight = 0.80;
    cfg.ambiguityNumberMin = -4;
    cfg.ambiguityNumberMax = 12;
    cfg.unwrapSpeedMin = 0;
    cfg.unwrapSpeedMax = 2000;

    % Frame ranges
    cfg.backgroundFrameStart = 1;
    cfg.backgroundFrameEnd = 1;
    cfg.targetFrameStart = 2;
    cfg.targetFrameEnd = 2;

    % Display and output
    cfg.displayRangeMin = 0;
    cfg.displayRangeMax = 10;
    cfg.rawDynamicRangeDb = 35;
    cfg.chirpEnhancedClim = [0, 15];
    cfg.rdEnhancedRangeTimeClim = [0, 35];
    cfg.generateRdGif = true;
    cfg.rdGifDelayTime = 0.15;
    cfg.rdGifClim = [0, 35];
    cfg.rdGifRangeMin = 0;
    cfg.rdGifRangeMax = 10;
    cfg.rdGifResolution = 120;
    cfg.rdGifVisible = false;
    cfg.plotVisible = true;
    cfg.saveResults = true;
    cfg.saveFigures = false;
    cfg.outputDir = "";

    % Optional range-velocity coupling correction
    cfg.applyRangeVelocityCouplingCorrection = false;
    cfg.rangeVelocityCouplingSign = 1;
end
