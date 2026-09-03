function cfg = config_0725_135656()
%CONFIG_0725_135656 Configuration for the 432.09819 m/s case.

    cfg = pradar.defaultConfig();
    cfg.caseId = "0725_135656";
    cfg.rangeFftSize = 256;
    cfg.winSize = 16;
    cfg.winStep = 16;
    cfg.dopplerFftSize = 128;
    cfg.slowTimeMeanRemoval = false;
    cfg.useFullAliasedVelocityAxis = false;
    cfg.highSpeedMin = 0;

    cfg.candidateRangeMin = 0.30;
    cfg.candidateRangeMax = 6.00;
    cfg.maxCandidatesPerWindow = 5;
    cfg.candidateThresholdDb = 3.0;
    cfg.minCandidateSeparation = 0.30;
    cfg.rangeSmoothBins = 3;

    cfg.fitSpeedMin = 300;
    cfg.fitSpeedMax = 700;
    cfg.minHypothesisSpanMs = 0.40;
    cfg.trackTolerance = 0.55;
    cfg.useVelocityHardGate = false;
    cfg.velocityCostWeight = 0.30;
    cfg.minTrackWindows = 6;
    cfg.trackStartTimeMs = 1.60;
    cfg.trackEndTimeMs = Inf;

    cfg.measuredSpeed = 432.09819;
    cfg.measuredSpeedStd = 35;
    cfg.distanceFitSpeedStd = 50;
    cfg.unwrapContinuityStd = 25;
    cfg.unwrapMeasuredWeight = 1.00;
    cfg.unwrapFitWeight = 0.45;
    cfg.unwrapContinuityWeight = 0.80;
    cfg.ambiguityNumberMin = -4;
    cfg.ambiguityNumberMax = 8;
    cfg.unwrapSpeedMin = 250;
    cfg.unwrapSpeedMax = 750;

    cfg.backgroundFrameStart = 170;
    cfg.backgroundFrameEnd = 176;
    cfg.targetFrameStart = 178;
    cfg.targetFrameEnd = 180;

    cfg.chirpEnhancedClim = [0, 15];
    cfg.rdEnhancedRangeTimeClim = [0, 35];
    cfg.rdGifDelayTime = 0.15;
    cfg.rdGifResolution = 120;
end
