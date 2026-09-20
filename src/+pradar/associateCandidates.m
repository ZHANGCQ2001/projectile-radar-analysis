function [selectedRows, distanceResiduals, velocityResiduals, metric] = ...
        associateCandidates(candidates, speed, intercept, cfg, derived)
%ASSOCIATECANDIDATES Choose at most one candidate per window for a line.
%
%   Candidate association is intentionally separated into two stages:
%   1) choose the best candidate in each window for the proposed line;
%   2) score the whole associated track using normalized coverage,
%      continuity, mean enhancement strength, and residual quality.
%
%   This avoids the previous failure mode where each additional weak clutter
%   point contributed a very large fixed reward and could dominate a
%   shorter but much stronger projectile track.

    selectedRows = [];
    distanceResiduals = [];
    velocityResiduals = [];
    selectedMeasuredVelocityResiduals = [];
    selectedStrengths = [];

    expectedAlias = pradar.wrapVelocity(speed, derived.vMax);
    measuredAlias = derived.measuredAliasedSpeed;
    uniqueWindows = unique(candidates.GlobalWindow, 'stable');

    for index = 1:numel(uniqueWindows)
        rows = find(candidates.GlobalWindow == uniqueWindows(index));
        predictedRange = ...
            speed * candidates.Time_ms(rows) * 1e-3 + intercept;

        distanceResidual = ...
            abs(candidates.Range_m(rows) - predictedRange);

        velocityResidual = pradar.circularVelocityDifference( ...
            candidates.AliasedVelocity_mps(rows), ...
            expectedAlias, derived.velocityPeriod);

        measuredVelocityResidual = ...
            pradar.circularVelocityDifference( ...
                candidates.AliasedVelocity_mps(rows), ...
                measuredAlias, derived.velocityPeriod);

        validMask = distanceResidual <= cfg.trackTolerance;

        if cfg.useVelocityHardGate
            validMask = validMask ...
                & velocityResidual <= cfg.velocityTolerance;
        end

        if ~any(validMask)
            continue;
        end

        validRows = rows(validMask);
        dRes = distanceResidual(validMask);
        vRes = velocityResidual(validMask);
        measuredVRes = measuredVelocityResidual(validMask);
        strength = candidates.RelativeStrength_dB(validRows);

        velocityScale = cfg.velocityTolerance;
        if ~cfg.useVelocityHardGate
            velocityScale = max(derived.vMax, eps);
        end

        % Per-window association cost. Strength helps choose between nearby
        % candidates, but geometry and velocity consistency still dominate.
        cost = ...
            (dRes / max(cfg.trackTolerance, eps)).^2 ...
            + cfg.velocityCostWeight ...
            * (vRes / max(velocityScale, eps)).^2 ...
            + cfg.measuredAliasCostWeight ...
            * (measuredVRes / max(cfg.measuredAliasTolerance, eps)).^2 ...
            - cfg.strengthCostWeight ...
            * max(strength, 0) / max(cfg.candidateThresholdDb, 1);

        [~, bestIndex] = min(cost);

        selectedRows(end + 1, 1) = ...
            validRows(bestIndex); %#ok<AGROW>
        distanceResiduals(end + 1, 1) = ...
            dRes(bestIndex); %#ok<AGROW>
        velocityResiduals(end + 1, 1) = ...
            vRes(bestIndex); %#ok<AGROW>
        selectedMeasuredVelocityResiduals(end + 1, 1) = ...
            measuredVRes(bestIndex); %#ok<AGROW>
        selectedStrengths(end + 1, 1) = ...
            max(strength(bestIndex), 0); %#ok<AGROW>
    end

    if isempty(selectedRows)
        metric = -Inf;
        return;
    end

    numAvailableWindows = max(1, numel(uniqueWindows));
    numSelected = numel(selectedRows);

    coverageRatio = numSelected / numAvailableWindows;

    selectedWindows = ...
        sort(double(candidates.GlobalWindow(selectedRows)));
    continuityRatio = longestConsecutiveRun(selectedWindows) ...
        / max(1, numSelected);

    meanStrength = mean(selectedStrengths);

    meanDistanceResidualNormalized = ...
        mean(distanceResiduals) / max(cfg.trackTolerance, eps);

    velocityScale = cfg.velocityTolerance;
    if ~cfg.useVelocityHardGate
        velocityScale = max(derived.vMax, eps);
    end
    meanVelocityResidualNormalized = ...
        mean(velocityResiduals) / max(velocityScale, eps);

    meanMeasuredAliasResidualNormalized = ...
        mean(selectedMeasuredVelocityResiduals) ...
        / max(cfg.measuredAliasTolerance, eps);

    metric = ...
        cfg.trackCoverageWeight * coverageRatio ...
        + cfg.trackContinuityWeight * continuityRatio ...
        + cfg.trackMeanStrengthWeight * meanStrength ...
        - cfg.trackDistanceNormalizedPenalty ...
        * meanDistanceResidualNormalized ...
        - cfg.trackVelocityNormalizedPenalty ...
        * meanVelocityResidualNormalized ...
        - cfg.trackMeasuredAliasNormalizedPenalty ...
        * meanMeasuredAliasResidualNormalized;
end

function runLength = longestConsecutiveRun(windowIndices)
    if isempty(windowIndices)
        runLength = 0;
        return;
    end

    windowIndices = unique(windowIndices(:).');
    if numel(windowIndices) == 1
        runLength = 1;
        return;
    end

    breaks = [true, diff(windowIndices) ~= 1, true];
    edgeIndex = find(breaks);
    segmentLengths = diff(edgeIndex);

    if isempty(segmentLengths)
        runLength = 1;
    else
        runLength = max(segmentLengths);
    end
end
