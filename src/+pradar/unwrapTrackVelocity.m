function trackTable = unwrapTrackVelocity(trackTable, vMax, referenceSpeed, cfg)
%UNWRAPTRACKVELOCITY Resolve velocity ambiguity with dynamic programming.

    ambiguityPeriod = 2 * vMax;
    ambiguityCandidates = ...
        cfg.ambiguityNumberMin:cfg.ambiguityNumberMax;
    aliasedVelocity = double(trackTable.AliasedVelocity_mps(:));
    numPoints = numel(aliasedVelocity);
    numStates = numel(ambiguityCandidates);

    possibleVelocity = ...
        aliasedVelocity + ambiguityPeriod * ambiguityCandidates;
    validMask = ...
        possibleVelocity >= cfg.unwrapSpeedMin ...
        & possibleVelocity <= cfg.unwrapSpeedMax;

    measuredCost = cfg.unwrapMeasuredWeight ...
        * ((possibleVelocity - cfg.measuredSpeed) ...
        / cfg.measuredSpeedStd).^2;
    fitCost = cfg.unwrapFitWeight ...
        * ((possibleVelocity - referenceSpeed) ...
        / cfg.distanceFitSpeedStd).^2;
    localCost = measuredCost + fitCost;
    localCost(~validMask) = Inf;

    accumulatedCost = inf(numPoints, numStates);
    previousState = zeros(numPoints, numStates);
    accumulatedCost(1, :) = localCost(1, :);

    for pointIndex = 2:numPoints
        for stateIndex = 1:numStates
            if ~isfinite(localCost(pointIndex, stateIndex))
                continue;
            end

            transitionCost = cfg.unwrapContinuityWeight ...
                * ((possibleVelocity(pointIndex, stateIndex) ...
                - possibleVelocity(pointIndex - 1, :)) ...
                / cfg.unwrapContinuityStd).^2;
            totalCost = accumulatedCost(pointIndex - 1, :) ...
                + transitionCost;
            [minimumCost, bestPreviousState] = min(totalCost);
            accumulatedCost(pointIndex, stateIndex) = ...
                localCost(pointIndex, stateIndex) + minimumCost;
            previousState(pointIndex, stateIndex) = bestPreviousState;
        end
    end

    [bestFinalCost, bestState] = min(accumulatedCost(end, :));

    if ~isfinite(bestFinalCost)
        warning('pradar:NoUnwrapPath', ...
            'No valid ambiguity path was found.');
        trackTable.AmbiguityNumber = nan(numPoints, 1);
        trackTable.UnwrappedVelocity_mps = nan(numPoints, 1);
        return;
    end

    bestStateSequence = zeros(numPoints, 1);
    bestStateSequence(end) = bestState;

    for pointIndex = numPoints:-1:2
        bestStateSequence(pointIndex - 1) = previousState( ...
            pointIndex, bestStateSequence(pointIndex));
    end

    linearIndex = sub2ind( ...
        size(possibleVelocity), (1:numPoints).', bestStateSequence);
    unwrappedVelocity = possibleVelocity(linearIndex);
    ambiguityNumber = ambiguityCandidates(bestStateSequence).';

    trackTable.AmbiguityNumber = ambiguityNumber;
    trackTable.UnwrappedVelocity_mps = unwrappedVelocity;
    trackTable.MeasuredSpeed_mps = ...
        repmat(cfg.measuredSpeed, numPoints, 1);
    trackTable.MeasuredSpeedResidual_mps = ...
        unwrappedVelocity - cfg.measuredSpeed;
    trackTable.DistanceFitSpeedResidual_mps = ...
        unwrappedVelocity - referenceSpeed;
    trackTable.GlobalUnwrapPathCost = ...
        repmat(bestFinalCost, numPoints, 1);
end
