function [trackTable, fitInfo] = selectTrack(candidateTable, cfg, derived)
%SELECTTRACK Search, associate and iteratively fit a distance-time track.

    trackTable = table();
    fitInfo = struct( ...
        'valid', false, ...
        'speed', NaN, ...
        'intercept', NaN, ...
        'rmse', NaN, ...
        'expectedAliasedSpeed', NaN, ...
        'meanCircularVelocityResidual', NaN);

    if isempty(candidateTable)
        return;
    end

    timeMask = ...
        candidateTable.Time_ms >= cfg.trackStartTimeMs ...
        & candidateTable.Time_ms <= cfg.trackEndTimeMs;
    candidates = candidateTable(timeMask, :);

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

            range1 = candidates.Range_m(firstIndex);
            range2 = candidates.Range_m(secondIndex);
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
        coefficients = polyfit(selectedTime, selectedRange, 1);
        speed = coefficients(1);
        intercept = coefficients(2);

        if speed < cfg.fitSpeedMin || speed > cfg.fitSpeedMax
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
    coefficients = polyfit( ...
        trackTable.Time_ms * 1e-3, trackTable.Range_m, 1);
    fittedRange = polyval(coefficients, trackTable.Time_ms * 1e-3);
    distanceResidual = trackTable.Range_m - fittedRange;
    expectedAlias = pradar.wrapVelocity(coefficients(1), derived.vMax);
    circularResidual = pradar.circularVelocityDifference( ...
        trackTable.AliasedVelocity_mps, ...
        expectedAlias, derived.velocityPeriod);

    trackTable.FittedRange_m = fittedRange;
    trackTable.FitResidual_m = distanceResidual;
    trackTable.ExpectedAliasedVelocity_mps = ...
        repmat(expectedAlias, height(trackTable), 1);
    trackTable.CircularVelocityResidual_mps = circularResidual;

    fitInfo.valid = true;
    fitInfo.speed = coefficients(1);
    fitInfo.intercept = coefficients(2);
    fitInfo.rmse = sqrt(mean(distanceResidual.^2));
    fitInfo.expectedAliasedSpeed = expectedAlias;
    fitInfo.meanCircularVelocityResidual = mean(circularResidual);
end
