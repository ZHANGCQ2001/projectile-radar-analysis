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

    if ~isfinite(cfg.measuredSpeed)
        error('pradar:MissingMeasuredSpeed', ...
            'cfg.measuredSpeed must be supplied for ambiguity resolution.');
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
