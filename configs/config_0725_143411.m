function cfg = config_0725_143411()
%CONFIG_0725_143411 Configuration for the 1207.82892 m/s case.

    cfg = pradar.defaultConfig();
    cfg.caseId = "0725_143411";
    cfg.rangeFftSize = 256;
    cfg.winSize = 16;
    cfg.winStep = 16;
    cfg.dopplerFftSize = 128;
    cfg.slowTimeMeanRemoval = false;
    cfg.useFullAliasedVelocityAxis = true;
    cfg.highSpeedMin = 0;

    cfg.candidateRangeMin = 1.00;
    cfg.candidateRangeMax = 5.50;
    cfg.candidateThresholdDb = 7.0;
    cfg.maxCandidatesPerWindow = 4;
    cfg.minCandidateSeparation = 0.22;
    cfg.rangeSmoothBins = 3;

    cfg.fitSpeedMin = 700;
    cfg.fitSpeedMax = 1700;
    cfg.minHypothesisSpanMs = 0.40;
    cfg.trackTolerance = 0.85;
    cfg.useVelocityHardGate = false;
    cfg.velocityCostWeight = 0.25;
    cfg.strengthCostWeight = 0.10;
    cfg.trackCountWeight = 100;
    cfg.trackStrengthWeight = 0.30;
    cfg.trackDistancePenalty = 35;
    cfg.trackVelocityPenalty = 0.20;
    cfg.minTrackWindows = 6;
    cfg.trackStartTimeMs = 1.65;
    cfg.trackEndTimeMs = 4.90;

    cfg.measuredSpeed = 1207.82892;
    cfg.measuredSpeedStd = 60;
    cfg.distanceFitSpeedStd = 120;
    cfg.unwrapContinuityStd = 50;
    cfg.unwrapMeasuredWeight = 1.00;
    cfg.unwrapFitWeight = 0.35;
    cfg.unwrapContinuityWeight = 0.80;
    cfg.ambiguityNumberMin = -2;
    cfg.ambiguityNumberMax = 12;
    cfg.unwrapSpeedMin = 650;
    cfg.unwrapSpeedMax = 1350;

    cfg.backgroundFrameStart = 79;
    cfg.backgroundFrameEnd = 86;
    cfg.targetFrameStart = 87;
    cfg.targetFrameEnd = 88;

    cfg.chirpEnhancedClim = [0, 18];
    cfg.rdEnhancedRangeTimeClim = [0, 35];
    cfg.rdGifDelayTime = 0.12;
    cfg.rdGifResolution = 120;
end
