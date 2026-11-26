function cfg = defaultConfig()
%DEFAULTCONFIG Return common defaults for projectile radar analysis.

    % Raw data and radar parameters
    cfg.caseId = "custom";
    cfg.numSamples = 64;
    cfg.numChirpsPerFrame = 256;
    cfg.numRx = 8;
    cfg.numTx = 1;
    cfg.rangeFftSize = 256;
    cfg.dopplerFftSize = 256;
    cfg.adcSampleRate = 10e6;
    cfg.slope = 60.01e12;
    cfg.startFreq = 77e9;
    cfg.chirpPeriod = 12e-6;
    cfg.framePeriod = 3.5e-3;
    cfg.c = 3e8;

    % Straight-trajectory geometry. Distances are metres; reference/fit/
    % unwrap speed bounds are ALONG-TRAJECTORY speeds. Legacy d=0, +1 is
    % equivalent to radial-only processing. Joint mode supports crossings.
    cfg.perpendicularDistance = 0;
    cfg.radialDirection = 1;       % +1 receding, -1 approaching, 0 joint crossing
    cfg.minRadialProjection = 0.10; % reject ill-conditioned LOS correction

    % Short-time RD processing
    cfg.winSize = 64;
    cfg.winStep = 64;
    cfg.slowTimeMeanRemoval = true;
    cfg.useFullAliasedVelocityAxis = false;
    cfg.highSpeedMin = 0;

    % Candidate extraction
    cfg.candidateRangeMin = 2;
    cfg.candidateRangeMax = 10;
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
    % Balanced track scoring. Coverage is normalized by the number of
    % available windows, so an extra weak clutter point cannot dominate the
    % score simply because it adds a fixed large count reward.
    cfg.trackCoverageWeight = 100;
    cfg.trackContinuityWeight = 30;
    cfg.trackMeanStrengthWeight = 2.5;
    cfg.trackDistanceNormalizedPenalty = 35;
    cfg.trackVelocityNormalizedPenalty = 10;
    cfg.trackMeasuredAliasNormalizedPenalty = 15;

    % Legacy fields are kept for configuration compatibility. The balanced
    % scorer no longer uses raw point count as an absolute reward.
    cfg.trackCountWeight = 100;
    cfg.trackStrengthWeight = 0.30;
    cfg.trackDistancePenalty = 30;
    cfg.trackVelocityPenalty = 0.30;
    cfg.maxTrackIterations = 6;

    % Closest-approach joint estimator (legacy remains explicit for comparison).
    cfg.unwrapMethod = "closestApproach";
    cfg.motionModel = "constantAcceleration"; % or "constantVelocity"
    cfg.useClosestSpeedPrior = true;
    cfg.closestSpeedStd = 35;                 % m/s, ONE prior at x=0
    cfg.closestApproachTimeMs = NaN;          % relative to target-frame start
    cfg.closestMaxExtrapolationMs = 50;       % bounded extrapolation, not truth
    cfg.maxAbsAcceleration = 5e4;            % m/s^2, physical bound
    cfg.motionAccelerationStd = 2e4;         % weak zero-acceleration regularizer
    cfg.jointRangeStd = 0.10;                 % m, measurement error, NOT FFT bin
    cfg.jointRadialStd = 5;                   % m/s, must be calibrated
    cfg.jointHuberDelta = 2.5;
    cfg.jointTransitionWeight = 0.20;
    cfg.jointMaxIterations = 4;
    cfg.jointMaxStarts = 10;
    cfg.jointMaxTrackHypotheses = 6;
    cfg.jointAmbiguityGapThreshold = 9;       % diagnostic cost gap, not probability
    cfg.jointMaxNormalizedResidual = 6;

    % Legacy velocity unwrapping (used only by unwrapMethod="legacy")
    cfg.measuredSpeed = NaN;
    cfg.measuredSpeedStd = 35;
    cfg.distanceFitSpeedStd = 50;
    cfg.unwrapContinuityStd = 25;
    cfg.unwrapMeasuredWeight = 1.00;
    cfg.unwrapFitWeight = 0.45;
    cfg.unwrapContinuityWeight = 0.80;
    cfg.ambiguityNumberMin = -12;
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
    
    % Diagnostic mean-compressed RD maps
    cfg.rdMeanRangeTimeClim = [0, 35];
    cfg.rdMeanVelocityTimeClim = [0, 35];

    % RD GIF output
    cfg.generateRdGif = true;
    cfg.generateRawRdGif = true;
    cfg.generateMeanRemovedRdGif = true;
    cfg.generateEnhancedRdGif = true;
    % Raw/mean-removed RD use the same absolute dB color scale
    cfg.rdPowerGifDynamicRangeDb = 45;
    cfg.rdMeanRemovedVisibleDynamicRangeDb = 40;
    % Background-enhanced RD uses enhancement dB
    cfg.rdGifClim = [0, 35];
    cfg.rdGifRangeMin = 0;
    cfg.rdGifRangeMax = 10;
    cfg.rdGifDelayTime = 0.15;
    cfg.rdGifResolution = 120;
    cfg.rdGifVisible = false;
    cfg.plotVisible = true;
    cfg.saveResults = true;
    cfg.saveFigures = false;
    cfg.outputDir = "";

    % Optional range-velocity coupling correction
    cfg.applyRangeVelocityCouplingCorrection = false;
    cfg.rangeVelocityCouplingSign = 1;

    % RD projection mode
    %
    % "range":
    %   Preserve range dimension and compress velocity dimension.
    %   This is the original processing method.
    %
    % "velocity":
    %   Preserve velocity dimension and compress range dimension.
    cfg.rdProjectionMode = "range";

    % Velocity-domain candidate extraction
    cfg.velocitySmoothBins = 3;
    cfg.minVelocityCandidateSeparation = 10;
end
