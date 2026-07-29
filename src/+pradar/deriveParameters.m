function derived = deriveParameters(cfg)
%DERIVEPARAMETERS Compute axes, window functions and frame sizes.

    derived.complexSamplesPerFrame = ...
        cfg.numSamples * cfg.numChirpsPerFrame * cfg.numRx;
    derived.bytesPerFrame = derived.complexSamplesPerFrame * 4;
    derived.uint16PerFrame = derived.complexSamplesPerFrame * 2;

    derived.rangeBinSpacing = ...
        cfg.c * cfg.adcSampleRate / ...
        (2 * cfg.slope * cfg.rangeFftSize);
    derived.rangeAxis = ...
        (0:cfg.rangeFftSize - 1) * derived.rangeBinSpacing;

    adcDuration = cfg.numSamples / cfg.adcSampleRate;
    derived.bandwidth = cfg.slope * adcDuration;
    derived.centerFreq = cfg.startFreq + derived.bandwidth / 2;
    derived.lambda = cfg.c / derived.centerFreq;

    derived.trueVelocityResolution = ...
        derived.lambda / (2 * cfg.winSize * cfg.chirpPeriod);
    derived.velocityGridSpacing = ...
        derived.lambda / (2 * cfg.dopplerFftSize * cfg.chirpPeriod);
    derived.velocityAxis = ...
        (-cfg.dopplerFftSize / 2 : cfg.dopplerFftSize / 2 - 1) ...
        * derived.velocityGridSpacing;

    derived.vMax = derived.lambda / (4 * cfg.chirpPeriod);
    derived.velocityPeriod = 2 * derived.vMax;
    derived.measuredAliasedSpeed = ...
        pradar.wrapVelocity(cfg.measuredSpeed, derived.vMax);

    derived.windowsPerFrame = floor( ...
        (cfg.numChirpsPerFrame - cfg.winSize) / cfg.winStep) + 1;

    derived.rangeWindow = reshape( ...
        single(pradar.makeHannWindow(cfg.numSamples)), ...
        cfg.numSamples, 1, 1);
    derived.dopplerWindow = reshape( ...
        single(pradar.makeHannWindow(cfg.winSize)).', ...
        1, cfg.winSize, 1);

    if cfg.useFullAliasedVelocityAxis
        derived.velocityMask = true(size(derived.velocityAxis));
    else
        derived.velocityMask = ...
            abs(derived.velocityAxis) >= cfg.highSpeedMin;
    end

    if ~any(derived.velocityMask)
        error('pradar:EmptyVelocityMask', ...
            'No velocity bins remain after applying the velocity mask.');
    end

    derived.selectedVelocityAxis = ...
        derived.velocityAxis(derived.velocityMask);
end
