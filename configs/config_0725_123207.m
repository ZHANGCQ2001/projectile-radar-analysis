function cfg = config_0725_123207()
%CONFIG_0725_123207 Configuration for the 428.62203 m/s case.

    cfg = pradar.defaultConfig();
    cfg.caseId = "0725_123207";
    cfg.rangeFftSize = 128;
    cfg.winSize = 16;
    cfg.winStep = 16;
    cfg.dopplerFftSize = 128;
    cfg.slowTimeMeanRemoval = true;
    cfg.useFullAliasedVelocityAxis = false;
    cfg.highSpeedMin = 20;

    cfg.candidateRangeMin = 0.25;
    cfg.candidateRangeMax = 3.00;
    cfg.maxCandidatesPerWindow = 6;
    cfg.candidateThresholdDb = 3.0;
    cfg.minCandidateSeparation = 0.25;
    cfg.rangeSmoothBins = 3;

    cfg.fitSpeedMin = 250;
    cfg.fitSpeedMax = 650;
    cfg.minHypothesisSpanMs = 0.60;
    cfg.trackTolerance = 0.50;
    cfg.useVelocityHardGate = true;
    cfg.velocityTolerance = 70;
    cfg.minTrackWindows = 5;
    cfg.trackStartTimeMs = 1.80;
    cfg.trackEndTimeMs = Inf;
    cfg.velocityCostWeight = 0.60;
    cfg.strengthCostWeight = 0.12;

    cfg.measuredSpeed = 428.62203;
    cfg.measuredSpeedStd = 35;
    cfg.distanceFitSpeedStd = 50;
    cfg.unwrapContinuityStd = 25;
    cfg.unwrapMeasuredWeight = 1.00;
    cfg.unwrapFitWeight = 0.45;
    cfg.unwrapContinuityWeight = 0.80;
    cfg.ambiguityNumberMin = -4;
    cfg.ambiguityNumberMax = 8;
    cfg.unwrapSpeedMin = 200;
    cfg.unwrapSpeedMax = 700;

    cfg.backgroundFrameStart = 126;
    cfg.backgroundFrameEnd = 133;
    cfg.targetFrameStart = 134;
    cfg.targetFrameEnd = 135;

    cfg.chirpEnhancedClim = [0, 15];
    cfg.rdEnhancedRangeTimeClim = [0, 35];
    cfg.rdGifDelayTime = 0.18;
    cfg.rdGifResolution = 140;
end
