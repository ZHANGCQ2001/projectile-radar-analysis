function [trackTable, fitInfo] = selectTrack(candidateTable, cfg, derived)
%SELECTTRACK Search, associate and iteratively fit a distance-time track.

    if isfield(cfg, 'unwrapMethod') && strcmp(cfg.unwrapMethod, 'closestApproach')
        [trackTable, fitInfo] = pradar.selectMotionTrack(candidateTable, cfg, derived);
        return;
    end
    trackTable = table();
    fitInfo = struct( ...
        'valid', false, ...
        'speed', NaN, ...
        'intercept', NaN, ...
        'rmse', NaN, ...
        'expectedAliasedSpeed', NaN, ...
        'meanCircularVelocityResidual', NaN, ...
        'geometryRejectedCount', 0, ...
        'speedType', 'along-trajectory');

    if isempty(candidateTable)
        return;
    end

    timeMask = ...
        candidateTable.Time_ms >= cfg.trackStartTimeMs ...
        & candidateTable.Time_ms <= cfg.trackEndTimeMs;
    [~, geometryValid, alongTrack] = pradar.rangeGeometry(candidateTable.Range_m, cfg);
    fitInfo.geometryRejectedCount = nnz(timeMask & ~geometryValid);
    finiteMask = isfinite(candidateTable.Time_ms) ...
        & isfinite(candidateTable.AliasedVelocity_mps) ...
        & isfinite(candidateTable.RelativeStrength_dB);
    selectedMask = timeMask & geometryValid & finiteMask;
    candidates = candidateTable(selectedMask, :);
    candidates.AlongTrack_m = alongTrack(selectedMask);
    candidates = sortrows(candidates, {'Time_ms', 'GlobalWindow'});

    if height(candidates) < 2
        return;
    end

    bestSelection = [];
    bestMetric = -Inf;
    numCandidates = height(candidates);

    for firstIndex = 1:numCandidates - 1
        for secondIndex = firstIndex + 1:numCandidates
            if candidates.GlobalWindow(firstIndex) ...
                    == candidates.GlobalWindow(secondIndex)
                continue;
            end

            time1 = candidates.Time_ms(firstIndex) * 1e-3;
            time2 = candidates.Time_ms(secondIndex) * 1e-3;
            deltaTime = time2 - time1;

            if deltaTime <= 0 ...
                    || deltaTime * 1e3 < cfg.minHypothesisSpanMs
                continue;
            end

            range1 = candidates.AlongTrack_m(firstIndex);
            range2 = candidates.AlongTrack_m(secondIndex);
            speed = (range2 - range1) / deltaTime;

            if speed < cfg.fitSpeedMin || speed > cfg.fitSpeedMax
                continue;
            end

            intercept = range1 - speed * time1;
            [selectedRows, ~, ~, metric] = ...
                pradar.associateCandidates( ...
                    candidates, speed, intercept, cfg, derived);

            if numel(selectedRows) < cfg.minTrackWindows
                continue;
            end

            if metric > bestMetric
                bestMetric = metric;
                bestSelection = selectedRows;
            end
        end
    end

    if numel(bestSelection) < cfg.minTrackWindows
        return;
    end

    selectedRows = bestSelection;

    for iteration = 1:cfg.maxTrackIterations
        selectedTime = candidates.Time_ms(selectedRows) * 1e-3;
        selectedRange = candidates.Range_m(selectedRows);
        [speed, intercept, validFit] = pradar.fitRangeTrack(selectedTime, selectedRange, cfg);

        if ~validFit
            break;
        end

        [newSelection, ~, ~, ~] = pradar.associateCandidates( ...
            candidates, speed, intercept, cfg, derived);

        if numel(newSelection) < cfg.minTrackWindows
            break;
        end

        if isequal(sort(newSelection), sort(selectedRows))
            selectedRows = newSelection;
            break;
        end

        selectedRows = newSelection;
    end

    trackTable = sortrows(candidates(selectedRows, :), 'Time_ms');
    [speed, intercept, validFit] = pradar.fitRangeTrack( ...
        trackTable.Time_ms * 1e-3, trackTable.Range_m, cfg);
    if ~validFit
        trackTable = table();
        return;
    end
    [fittedRange, radialVelocity] = pradar.predictRangeTrack( ...
        trackTable.Time_ms * 1e-3, speed, intercept, cfg);
    distanceResidual = trackTable.Range_m - fittedRange;
    expectedAlias = pradar.wrapVelocity(radialVelocity, derived.vMax);
    circularResidual = pradar.circularVelocityDifference( ...
        trackTable.AliasedVelocity_mps, expectedAlias, derived.velocityPeriod);

    trackTable.FittedRange_m = fittedRange;
    trackTable.FitResidual_m = distanceResidual;
    trackTable.FittedRadialVelocity_mps = radialVelocity;
    trackTable.ExpectedAliasedVelocity_mps = expectedAlias;
    trackTable.CircularVelocityResidual_mps = circularResidual;

    fitInfo.valid = true;
    fitInfo.speed = speed;
    fitInfo.intercept = intercept; % signed along-track position at t=0
    fitInfo.initialSlantRange = hypot(cfg.perpendicularDistance, intercept);
    fitInfo.rmse = sqrt(mean(distanceResidual.^2));
    % Retain the legacy scalar only where the radial speed really is constant.
    if cfg.perpendicularDistance == 0
        fitInfo.expectedAliasedSpeed = expectedAlias(1);
    end
    fitInfo.meanCircularVelocityResidual = mean(circularResidual);
end
