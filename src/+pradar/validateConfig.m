function cfg = validateConfig(cfg)
%VALIDATECONFIG Fill missing fields and validate configuration values.

    defaults = pradar.defaultConfig();
    names = fieldnames(defaults);

    for idx = 1:numel(names)
        name = names{idx};
        if ~isfield(cfg, name) || isempty(cfg.(name))
            cfg.(name) = defaults.(name);
        end
    end

    mustBePositiveScalar(cfg.numSamples, 'numSamples');
    mustBePositiveScalar(cfg.numChirpsPerFrame, 'numChirpsPerFrame');
    mustBePositiveScalar(cfg.numRx, 'numRx');
    mustBePositiveScalar(cfg.rangeFftSize, 'rangeFftSize');
    mustBePositiveScalar(cfg.dopplerFftSize, 'dopplerFftSize');
    mustBePositiveScalar(cfg.winSize, 'winSize');
    mustBePositiveScalar(cfg.winStep, 'winStep');
    mustBePositiveScalar( ...
        cfg.velocitySmoothBins, ...
        'velocitySmoothBins');

    mustBePositiveScalar( ...
        cfg.minVelocityCandidateSeparation, ...
        'minVelocityCandidateSeparation');

    validateattributes(cfg.perpendicularDistance, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'nonnegative'}, mfilename, 'perpendicularDistance');
    validateattributes(cfg.radialDirection, {'numeric'}, ...
        {'scalar', 'real', 'finite'}, mfilename, 'radialDirection');
    if ~any(strcmp(cfg.unwrapMethod, {'closestApproach','legacy'}))
        error('pradar:InvalidUnwrapMethod','Unknown unwrapMethod.');
    end
    if ~any(strcmp(cfg.motionModel, {'constantVelocity','constantAcceleration'}))
        error('pradar:InvalidMotionModel','Unknown motionModel.');
    end
    allowedDirections = [-1 1];
    if strcmp(cfg.unwrapMethod,'closestApproach'), allowedDirections = [-1 0 1]; end
    if ~ismember(cfg.radialDirection, allowedDirections)
        error('pradar:InvalidRadialDirection','Use +1/-1, or 0 for joint closest-approach crossing.');
    end
    if cfg.radialDirection==0 && cfg.perpendicularDistance<=0
        error('pradar:UndefinedCollinearCrossing','Crossing mode requires perpendicularDistance > 0.');
    end
    positiveFields = {'closestSpeedStd','closestMaxExtrapolationMs', ...
        'maxAbsAcceleration','motionAccelerationStd','jointRangeStd', ...
        'jointRadialStd','jointHuberDelta','jointMaxNormalizedResidual'};
    for k=1:numel(positiveFields)
        validateattributes(cfg.(positiveFields{k}),{'numeric'}, ...
            {'scalar','real','finite','positive'},mfilename,positiveFields{k});
    end
    for name = {'jointMaxIterations','jointMaxStarts','jointMaxTrackHypotheses'}
        validateattributes(cfg.(name{1}),{'numeric'}, ...
            {'scalar','finite','integer','positive'},mfilename,name{1});
    end
    for name = {'jointTransitionWeight','jointAmbiguityGapThreshold'}
        validateattributes(cfg.(name{1}),{'numeric'}, ...
            {'scalar','real','finite','nonnegative'},mfilename,name{1});
    end
    validateattributes(cfg.useClosestSpeedPrior,{'logical','numeric'},{'scalar','binary'});
    if ~isscalar(cfg.closestApproachTimeMs) || ~isreal(cfg.closestApproachTimeMs) ...
            || ~(isfinite(cfg.closestApproachTimeMs) || isnan(cfg.closestApproachTimeMs))
        error('pradar:InvalidClosestTime','closestApproachTimeMs must be finite or NaN (automatic).');
    end
    validateattributes(cfg.ambiguityNumberMin,{'numeric'},{'scalar','finite','integer'});
    validateattributes(cfg.ambiguityNumberMax,{'numeric'},{'scalar','finite','integer'});
    if cfg.ambiguityNumberMin>cfg.ambiguityNumberMax
        error('pradar:InvalidAmbiguityBounds','Ambiguity bounds are reversed.');
    end
    validateattributes(cfg.minRadialProjection, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'positive', '<=', 1}, ...
        mfilename, 'minRadialProjection');
    if cfg.fitSpeedMin < 0 || cfg.unwrapSpeedMin < 0
        error('pradar:InvalidSpeedMagnitude', ...
            'Along-trajectory speed bounds must be nonnegative; use radialDirection for direction.');
    end

    if cfg.numTx ~= 1
        error('pradar:UnsupportedTxCount', ...
            'The current reader supports numTx = 1 only.');
    end

    if cfg.winSize > cfg.numChirpsPerFrame
        error('pradar:InvalidWindow', ...
            'winSize cannot exceed numChirpsPerFrame.');
    end

    if cfg.dopplerFftSize < cfg.winSize
        error('pradar:InvalidDopplerFft', ...
            'dopplerFftSize must be greater than or equal to winSize.');
    end

    if mod(cfg.dopplerFftSize, 2) ~= 0
        error('pradar:InvalidDopplerFft', ...
            'dopplerFftSize must be even because fftshift velocity axes are used.');
    end

    if cfg.candidateRangeMax <= cfg.candidateRangeMin
        error('pradar:InvalidRangeGate', ...
            'candidateRangeMax must be greater than candidateRangeMin.');
    end

    if cfg.fitSpeedMax <= cfg.fitSpeedMin
        error('pradar:InvalidFitRange', ...
            'fitSpeedMax must be greater than fitSpeedMin.');
    end

    if cfg.unwrapSpeedMax <= cfg.unwrapSpeedMin
        error('pradar:InvalidUnwrapRange', ...
            'unwrapSpeedMax must be greater than unwrapSpeedMin.');
    end

    needsReference = strcmp(cfg.unwrapMethod,'legacy') || cfg.useClosestSpeedPrior;
    if needsReference && (~isscalar(cfg.measuredSpeed) || ~isreal(cfg.measuredSpeed) ...
            || ~isfinite(cfg.measuredSpeed) || cfg.measuredSpeed<=0)
        error('pradar:MissingMeasuredSpeed','Supply a positive closest-point speed or disable its prior.');
    end
    if max(cfg.fitSpeedMin,cfg.unwrapSpeedMin)>=min(cfg.fitSpeedMax,cfg.unwrapSpeedMax)
        error('pradar:DisjointSpeedBounds','Fit and unwrap physical bounds do not overlap.');
    end

    validProjectionModes = ...
        ["range", "velocity"];

    if ~any(cfg.rdProjectionMode ...
            == validProjectionModes)

        error( ...
            'pradar:InvalidRdProjectionMode', ...
            ['rdProjectionMode must be ' ...
             '"range" or "velocity".']);
    end
end

function mustBePositiveScalar(value, name)
    if ~isscalar(value) || ~isfinite(value) || value <= 0
        error('pradar:InvalidConfig', '%s must be a positive scalar.', name);
    end
end
