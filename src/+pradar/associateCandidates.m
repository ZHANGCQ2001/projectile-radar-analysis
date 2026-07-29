function [selectedRows, distanceResiduals, velocityResiduals, metric] = ...
        associateCandidates(candidates, speed, intercept, cfg, derived)
%ASSOCIATECANDIDATES Choose at most one candidate per window for a line.

    selectedRows = [];
    distanceResiduals = [];
    velocityResiduals = [];
    totalStrength = 0;

    expectedAlias = pradar.wrapVelocity(speed, derived.vMax);
    measuredAlias = derived.measuredAliasedSpeed;
    uniqueWindows = unique(candidates.GlobalWindow, 'stable');

    for index = 1:numel(uniqueWindows)
        rows = find(candidates.GlobalWindow == uniqueWindows(index));
        predictedRange = ...
            speed * candidates.Time_ms(rows) * 1e-3 + intercept;
        distanceResidual = abs(candidates.Range_m(rows) - predictedRange);
        velocityResidual = pradar.circularVelocityDifference( ...
            candidates.AliasedVelocity_mps(rows), ...
            expectedAlias, derived.velocityPeriod);
        measuredVelocityResidual = pradar.circularVelocityDifference( ...
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
            velocityScale = derived.vMax;
        end

        cost = ...
            (dRes / cfg.trackTolerance).^2 ...
            + cfg.velocityCostWeight * (vRes / velocityScale).^2 ...
            + cfg.measuredAliasCostWeight ...
            * (measuredVRes / cfg.measuredAliasTolerance).^2 ...
            - cfg.strengthCostWeight ...
            * max(strength, 0) / max(cfg.candidateThresholdDb, 1);

        [~, bestIndex] = min(cost);
        selectedRows(end + 1, 1) = validRows(bestIndex); %#ok<AGROW>
        distanceResiduals(end + 1, 1) = dRes(bestIndex); %#ok<AGROW>
        velocityResiduals(end + 1, 1) = vRes(bestIndex); %#ok<AGROW>
        totalStrength = totalStrength + max(strength(bestIndex), 0);
    end

    if isempty(selectedRows)
        metric = -Inf;
        return;
    end

    metric = ...
        cfg.trackCountWeight * numel(selectedRows) ...
        + cfg.trackStrengthWeight * totalStrength ...
        - cfg.trackDistancePenalty * mean(distanceResiduals) ...
        - cfg.trackVelocityPenalty * mean(velocityResiduals);
end
