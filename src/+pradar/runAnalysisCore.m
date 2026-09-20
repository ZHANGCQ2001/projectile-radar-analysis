function result = runAnalysisCore(cfg, dataFile, progressFcn, cancelFcn)
%RUNANALYSISCORE Run projectile-radar processing without plotting or file I/O side effects.
%
%   result = pradar.runAnalysisCore(cfg, dataFile)
%   result = pradar.runAnalysisCore(cfg, dataFile, progressFcn, cancelFcn)
%
%   progressFcn is called as:
%       progressFcn(stageName, completed, total)
%
%   cancelFcn must return true when cancellation is requested.
%
%   This function intentionally does not create figures, GIFs, or CSV files.
%   It is suitable for use by the upper-machine GUI.

    if nargin < 3
        progressFcn = [];
    end
    if nargin < 4
        cancelFcn = [];
    end

    cfg = pradar.validateConfig(cfg);
    dataFile = string(dataFile);

    if strlength(dataFile) == 0 || ~isfile(dataFile)
        error('pradar:DataFileMissing', ...
            'The supplied data file does not exist: %s', dataFile);
    end

    derived = pradar.deriveParameters(cfg);

    fileInfo = dir(dataFile);
    totalFrames = floor(fileInfo.bytes / derived.bytesPerFrame);
    remainingBytes = mod(fileInfo.bytes, derived.bytesPerFrame);

    validateFrameRange( ...
        cfg.backgroundFrameStart, cfg.backgroundFrameEnd, ...
        totalFrames, 'background');
    validateFrameRange( ...
        cfg.targetFrameStart, cfg.targetFrameEnd, ...
        totalFrames, 'target');

    fid = fopen(dataFile, 'rb', 'ieee-le');
    if fid < 0
        error('pradar:OpenFailed', 'Unable to open %s.', dataFile);
    end
    cleanupObject = onCleanup(@() fclose(fid)); %#ok<NASGU>

    notify(progressFcn, 'background', 0, ...
        cfg.backgroundFrameEnd - cfg.backgroundFrameStart + 1);

    backgroundData = pradar.processFrameRange( ...
        fid, ...
        cfg.backgroundFrameStart, ...
        cfg.backgroundFrameEnd, ...
        cfg, derived, progressFcn, cancelFcn, 'background');

    checkCancelled(cancelFcn);

    notify(progressFcn, 'target', 0, ...
        cfg.targetFrameEnd - cfg.targetFrameStart + 1);

    targetData = pradar.processFrameRange( ...
        fid, ...
        cfg.targetFrameStart, ...
        cfg.targetFrameEnd, ...
        cfg, derived, progressFcn, cancelFcn, 'target');

    checkCancelled(cancelFcn);
    notify(progressFcn, 'analysis', 1, 6);

    backgroundRangePower = median( ...
        backgroundData.rangePowerTime, 2, 'omitnan');
    backgroundRdPower = pradar.buildRdBackground( ...
        backgroundData.rdPowerCube);

    notify(progressFcn, 'analysis', 2, 6);
    checkCancelled(cancelFcn);

    rangeTimeEnhancedDb = pradar.enhancePower( ...
        targetData.rangePowerTime, backgroundRangePower);
    rdEnhancedDb = pradar.enhancePower( ...
        targetData.rdPowerCube, backgroundRdPower);

    rdEnhancedMeanDb = mean(rdEnhancedDb, 3, 'omitnan');
    rdEnhancedMaxDb = max(rdEnhancedDb, [], 3);

    notify(progressFcn, 'analysis', 3, 6);
    checkCancelled(cancelFcn);

    switch cfg.rdProjectionMode
        case "range"
            [rdEnhancedRangeTimeDb, aliasVelocityMap] = ...
                pradar.compressRdToRangeProfile( ...
                    rdEnhancedDb, derived);

            rdEnhancedVelocityTimeDb = [];
            peakRangeMap = [];

            candidateTable = pradar.extractCandidates( ...
                rdEnhancedRangeTimeDb, ...
                aliasVelocityMap, ...
                targetData, ...
                derived.rangeAxis, ...
                cfg);

        case "velocity"
            [rdEnhancedVelocityTimeDb, peakRangeMap] = ...
                pradar.compressRdToVelocityProfile( ...
                    rdEnhancedDb, derived, cfg);

            rdEnhancedRangeTimeDb = [];
            aliasVelocityMap = [];

            candidateTable = pradar.extractVelocityCandidates( ...
                rdEnhancedVelocityTimeDb, ...
                peakRangeMap, ...
                targetData, ...
                derived, ...
                cfg);

        otherwise
            error('pradar:InvalidRdProjectionMode', ...
                'Unsupported RD projection mode: %s', ...
                cfg.rdProjectionMode);
    end

    notify(progressFcn, 'analysis', 4, 6);
    checkCancelled(cancelFcn);

    [trackTable, fitInfo] = pradar.selectTrack( ...
        candidateTable, cfg, derived);

    if fitInfo.valid
        trackTable = pradar.unwrapTrackVelocity( ...
            trackTable, ...
            derived.vMax, ...
            fitInfo.speed, ...
            cfg);

        velocityMetrics = pradar.computeVelocityMetrics( ...
            trackTable, cfg.measuredSpeed);

        couplingOffset = ...
            derived.centerFreq / cfg.slope ...
            .* trackTable.UnwrappedVelocity_mps;

        trackTable.RangeVelocityCouplingMagnitude_m = ...
            abs(couplingOffset);

        if cfg.applyRangeVelocityCouplingCorrection
            trackTable.CorrectedRange_m = ...
                trackTable.Range_m ...
                + cfg.rangeVelocityCouplingSign .* couplingOffset;
        else
            trackTable.CorrectedRange_m = trackTable.Range_m;
        end
    else
        velocityMetrics = pradar.computeVelocityMetrics( ...
            table(), cfg.measuredSpeed);
    end

    notify(progressFcn, 'analysis', 5, 6);
    checkCancelled(cancelFcn);

    keepIntermediateData = false;
    if isfield(cfg, 'keepIntermediateData')
        keepIntermediateData = logical(cfg.keepIntermediateData);
    end

    result = struct();
    result.cfg = cfg;
    result.derived = derived;
    result.dataFile = dataFile;
    result.totalFrames = totalFrames;
    result.trailingBytes = remainingBytes;

    result.backgroundRangePower = backgroundRangePower;
    result.backgroundRdPower = backgroundRdPower;
    result.rdEnhancedMeanDb = rdEnhancedMeanDb;
    result.rdEnhancedMaxDb = rdEnhancedMaxDb;

    result.rdProjectionMode = cfg.rdProjectionMode;
    result.rdEnhancedRangeTimeDb = rdEnhancedRangeTimeDb;
    result.aliasVelocityMap = aliasVelocityMap;
    result.rdEnhancedVelocityTimeDb = rdEnhancedVelocityTimeDb;
    result.peakRangeMap = peakRangeMap;

    result.candidateTable = candidateTable;
    result.trackTable = trackTable;
    result.fitInfo = fitInfo;
    result.velocityMetrics = velocityMetrics;

    if keepIntermediateData
        result.backgroundData = backgroundData;
        result.targetData = targetData;
        result.rangeTimeEnhancedDb = rangeTimeEnhancedDb;
        result.rdEnhancedDb = rdEnhancedDb;
    else
        result.backgroundData = stripHeavyFrameData(backgroundData);
        result.targetData = stripHeavyFrameData(targetData);
        result.rangeTimeEnhancedDb = [];
        result.rdEnhancedDb = [];
    end

    notify(progressFcn, 'analysis', 6, 6);
end

function validateFrameRange(frameStart, frameEnd, totalFrames, label)
    if ~isscalar(frameStart) || ~isscalar(frameEnd) ...
            || ~isfinite(frameStart) || ~isfinite(frameEnd) ...
            || frameStart ~= floor(frameStart) ...
            || frameEnd ~= floor(frameEnd) ...
            || frameStart < 1 ...
            || frameEnd < frameStart ...
            || frameEnd > totalFrames
        error('pradar:InvalidFrameRange', ...
            ['Invalid %s frame range [%g, %g]. ' ...
             'The file contains %d complete physical frames.'], ...
            label, frameStart, frameEnd, totalFrames);
    end
end

function checkCancelled(cancelFcn)
    if ~isempty(cancelFcn) && cancelFcn()
        error('pradar:Cancelled', ...
            'Processing was cancelled by the user.');
    end
end

function notify(progressFcn, stageName, completed, total)
    if isempty(progressFcn)
        return;
    end

    progressFcn(stageName, completed, total);
end

function lightData = stripHeavyFrameData(frameData)
    lightData = frameData;

    if isfield(lightData, 'rangePowerTime')
        lightData.rangePowerTime = [];
    end
    if isfield(lightData, 'rdPowerCube')
        lightData.rdPowerCube = [];
    end
end
