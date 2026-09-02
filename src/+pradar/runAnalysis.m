function result = runAnalysis(cfg, dataFile)
%RUNANALYSIS Run the complete projectile radar analysis pipeline.
%
%   result = pradar.runAnalysis(cfg, dataFile)

    cfg = pradar.validateConfig(cfg);
    dataFile = string(dataFile);

    if strlength(dataFile) == 0 || ~isfile(dataFile)
        error('pradar:DataFileMissing', ...
            'The supplied data file does not exist: %s', dataFile);
    end

    if strlength(cfg.outputDir) == 0
        cfg.outputDir = fullfile(fileparts(dataFile), 'results');
    end
    if ~isfolder(cfg.outputDir)
        mkdir(cfg.outputDir);
    end

    derived = pradar.deriveParameters(cfg);
    fileInfo = dir(dataFile);
    totalFrames = floor(fileInfo.bytes / derived.bytesPerFrame);
    remainingBytes = mod(fileInfo.bytes, derived.bytesPerFrame);

    validateFrameRange( ...
        cfg.backgroundFrameStart, cfg.backgroundFrameEnd, totalFrames, ...
        'background');
    validateFrameRange( ...
        cfg.targetFrameStart, cfg.targetFrameEnd, totalFrames, 'target');

    fprintf('========================================\n');
    fprintf('Case: %s\n', cfg.caseId);
    fprintf('Data file: %s\n', dataFile);
    fprintf('Complete physical frames: %d\n', totalFrames);
    fprintf('Trailing bytes: %d\n', remainingBytes);
    fprintf('Range-bin spacing: %.4f m\n', derived.rangeBinSpacing);
    fprintf('Theoretical range resolution: %.4f m\n', ...
        cfg.c / (2 * derived.bandwidth));
    fprintf('True velocity resolution: %.3f m/s\n', ...
        derived.trueVelocityResolution);
    fprintf('Velocity grid spacing: %.3f m/s\n', ...
        derived.velocityGridSpacing);
    fprintf('Maximum unambiguous velocity: +/- %.3f m/s\n', ...
        derived.vMax);
    fprintf('Measured velocity: %.5f m/s\n', cfg.measuredSpeed);
    fprintf('Measured aliased velocity: %+.3f m/s\n', ...
        derived.measuredAliasedSpeed);
    fprintf('========================================\n');

    fid = fopen(dataFile, 'rb', 'ieee-le');
    if fid < 0
        error('pradar:OpenFailed', 'Unable to open %s.', dataFile);
    end
    cleanupObject = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf('\nProcessing background frames...\n');
    backgroundData = pradar.processFrameRange( ...
        fid, cfg.backgroundFrameStart, cfg.backgroundFrameEnd, cfg, derived);
    fprintf('\nProcessing target frames...\n');
    targetData = pradar.processFrameRange( ...
        fid, cfg.targetFrameStart, cfg.targetFrameEnd, cfg, derived);

    backgroundRangePower = median( ...
        backgroundData.rangePowerTime, 2, 'omitnan');
    backgroundRdPower = pradar.buildRdBackground( ...
        backgroundData.rdPowerCube);
    rangeTimeEnhancedDb = pradar.enhancePower( ...
        targetData.rangePowerTime, backgroundRangePower);
    rdEnhancedDb = pradar.enhancePower( ...
        targetData.rdPowerCube, backgroundRdPower);

    [rdEnhancedRangeTimeDb, aliasVelocityMap] = ...
        pradar.compressRdToRangeProfile(rdEnhancedDb, derived);
    candidateTable = pradar.extractCandidates( ...
        rdEnhancedRangeTimeDb, aliasVelocityMap, ...
        targetData, derived.rangeAxis, cfg);
    [trackTable, fitInfo] = pradar.selectTrack( ...
        candidateTable, cfg, derived);

    if fitInfo.valid
        trackTable = pradar.unwrapTrackVelocity( ...
            trackTable, derived.vMax, fitInfo.speed, cfg);
        velocityMetrics = pradar.computeVelocityMetrics( ...
            trackTable, cfg.measuredSpeed);

        couplingOffset = ...
            derived.centerFreq / cfg.slope ...
            .* trackTable.UnwrappedVelocity_mps;
        trackTable.RangeVelocityCouplingMagnitude_m = abs(couplingOffset);
        if cfg.applyRangeVelocityCouplingCorrection
            trackTable.CorrectedRange_m = trackTable.Range_m ...
                + cfg.rangeVelocityCouplingSign .* couplingOffset;
        else
            trackTable.CorrectedRange_m = trackTable.Range_m;
        end
    else
        velocityMetrics = pradar.computeVelocityMetrics(table(), cfg.measuredSpeed);
    end

    result = struct();
    result.cfg = cfg;
    result.derived = derived;
    result.backgroundData = backgroundData;
    result.targetData = targetData;
    result.backgroundRangePower = backgroundRangePower;
    result.backgroundRdPower = backgroundRdPower;
    result.rangeTimeEnhancedDb = rangeTimeEnhancedDb;
    result.rdEnhancedDb = rdEnhancedDb;
    result.rdEnhancedRangeTimeDb = rdEnhancedRangeTimeDb;
    result.aliasVelocityMap = aliasVelocityMap;
    result.candidateTable = candidateTable;
    result.trackTable = trackTable;
    result.fitInfo = fitInfo;
    result.velocityMetrics = velocityMetrics;

    result.figures = pradar.plotResults(result);

    %% RD diagnostic GIFs

    [~, baseName, ~] = fileparts(dataFile);

    result.gifPaths = struct( ...
        'raw', "", ...
        'meanRemoved', "", ...
        'enhanced', "");

    result.gifPath = "";

    if cfg.generateRdGif

        %% -------------------------------------------------
        % Raw and mean-removed RD
        %
        % targetData.rdPowerCube already contains the
        % current algorithm result. For 0725_123207,
        % slowTimeMeanRemoval = true, so it is the
        % mean-removed RD power cube.
        %
        % To obtain the raw RD, process only the target
        % frames once more with mean removal disabled.
        % --------------------------------------------------

        needPowerGif = ...
            cfg.generateRawRdGif ...
            || cfg.generateMeanRemovedRdGif;

        if needPowerGif

            cfgRaw = cfg;
            cfgRaw.slowTimeMeanRemoval = false;

            fprintf('\nProcessing raw target RD for GIF...\n');

            rawTargetData = ...
                pradar.processFrameRange( ...
                    fid, ...
                    cfg.targetFrameStart, ...
                    cfg.targetFrameEnd, ...
                    cfgRaw, ...
                    derived);

            rawRdDb = ...
                10 * log10( ...
                    double(rawTargetData.rdPowerCube) ...
                    + 1e-12);

            if cfg.slowTimeMeanRemoval
            
                meanRemovedRdDb = ...
                    10 * log10( ...
                        double(targetData.rdPowerCube) ...
                        + 1e-12);
            
                meanRemovedMetadata = targetData;
            
            else
            
                cfgMeanRemoved = cfg;
                cfgMeanRemoved.slowTimeMeanRemoval = true;
            
                fprintf( ...
                    '\nProcessing mean-removed target RD for GIF...\n');
            
                meanRemovedTargetData = ...
                    pradar.processFrameRange( ...
                        fid, ...
                        cfg.targetFrameStart, ...
                        cfg.targetFrameEnd, ...
                        cfgMeanRemoved, ...
                        derived);
            
                meanRemovedRdDb = ...
                    10 * log10( ...
                        double( ...
                            meanRemovedTargetData.rdPowerCube) ...
                        + 1e-12);
            
                meanRemovedMetadata = ...
                    meanRemovedTargetData;
            end

            %% Common absolute-dB color scale

            rawFinite = ...
                rawRdDb(isfinite(rawRdDb));

            meanFinite = ...
                meanRemovedRdDb( ...
                    isfinite(meanRemovedRdDb));

            commonMaximum = max( ...
                max(rawFinite), ...
                max(meanFinite));

            powerClim = [ ...
                commonMaximum ...
                    - cfg.rdPowerGifDynamicRangeDb, ...
                commonMaximum];

            %% Raw RD GIF

            if cfg.generateRawRdGif

                rawGifPath = fullfile( ...
                    cfg.outputDir, ...
                    baseName + "_RD_raw.gif");

                pradar.createRdCubeGif( ...
                    rawRdDb, ...
                    rawTargetData, ...
                    derived, ...
                    cfg, ...
                    rawGifPath, ...
                    "Short-time RD before mean removal",...
                    powerClim);

                result.gifPaths.raw = rawGifPath;
            end

            %% Mean-removed RD GIF

            if cfg.generateMeanRemovedRdGif

                meanGifPath = fullfile( ...
                    cfg.outputDir, ...
                    baseName + "_RD_mean_removed.gif");

                pradar.createRdCubeGif( ...
                    meanRemovedRdDb, ...
                    meanRemovedMetadata, ...
                    derived, ...
                    cfg, ...
                    meanGifPath, ...
                    "Short-time RD after mean removal", ...
                    powerClim);

                result.gifPaths.meanRemoved = ...
                    meanGifPath;
            end
        end

        %% -------------------------------------------------
        % Background-enhanced RD
        % --------------------------------------------------

        if cfg.generateEnhancedRdGif

            enhancedGifPath = fullfile( ...
                cfg.outputDir, ...
                baseName + "_RD_enhanced.gif");

            pradar.createRdCubeGif( ...
                rdEnhancedDb, ...
                targetData, ...
                derived, ...
                cfg, ...
                enhancedGifPath, ...
                "Background-enhanced short-time RD evolution", ...
                cfg.rdGifClim);

            result.gifPaths.enhanced = ...
                enhancedGifPath;

            % Keep compatibility with old code
            result.gifPath = ...
                enhancedGifPath;
        end
    end

    if cfg.saveResults
        matPath = fullfile(cfg.outputDir, baseName + "_analysis.mat");
        candidateCsvPath = fullfile( ...
            cfg.outputDir, baseName + "_candidates.csv");
        trackCsvPath = fullfile(cfg.outputDir, baseName + "_track.csv");
    
        resultWithFigures = result;
    
        if isfield(result, 'figures')
            result = rmfield(result, 'figures');
        end
    
        save(matPath, 'result', '-v7.3');
    
        result = resultWithFigures;
    
        writetable(candidateTable, candidateCsvPath);
    
        if fitInfo.valid
            writetable(trackTable, trackCsvPath);
        end
    end

    if cfg.saveFigures
        saveFigureSet(result.figures, cfg.outputDir, baseName);
    end

    printSummary(result);
end

function validateFrameRange(frameStart, frameEnd, totalFrames, label)
    if frameStart < 1 || frameEnd < frameStart || frameEnd > totalFrames
        error('pradar:InvalidFrameRange', ...
            '%s frame range %d-%d is invalid; file contains %d frames.', ...
            label, frameStart, frameEnd, totalFrames);
    end
end

function saveFigureSet(figures, outputDir, baseName)
    names = fieldnames(figures);
    for index = 1:numel(names)
        fig = figures.(names{index});
        if isgraphics(fig)
            outputPath = fullfile( ...
                outputDir, baseName + "_" + names{index} + ".png");
            exportgraphics(fig, outputPath, 'Resolution', 180);
        end
    end
end

function printSummary(result)
    fprintf('\n========================================\n');
    fprintf('Analysis summary\n');
    fprintf('Candidates: %d\n', height(result.candidateTable));
    if result.fitInfo.valid
        fprintf('Track points: %d\n', height(result.trackTable));
        fprintf('Distance-fit speed: %.2f m/s\n', result.fitInfo.speed);
        fprintf('Distance-fit RMSE: %.3f m\n', result.fitInfo.rmse);
        fprintf('Mean unwrapped speed: %.2f m/s\n', ...
            result.velocityMetrics.meanSpeed);
        fprintf('Velocity MAE: %.2f m/s\n', result.velocityMetrics.mae);
        fprintf('Velocity RMSE: %.2f m/s (%.3f%%)\n', ...
            result.velocityMetrics.rmse, ...
            result.velocityMetrics.relativeRmsePercent);
        fprintf('Minimum absolute error: %.2f m/s (%.3f%%)\n', ...
            result.velocityMetrics.minimumAbsoluteError, ...
            result.velocityMetrics.relativeMinimumAbsoluteErrorPercent);
    else
        fprintf('No valid track was found.\n');
    end
    fprintf('========================================\n');
end
