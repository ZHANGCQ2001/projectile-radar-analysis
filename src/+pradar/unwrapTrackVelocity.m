function trackTable = unwrapTrackVelocity(trackTable, vMax, referenceSpeed, cfg)
%UNWRAPTRACKVELOCITY Geometry-aware dynamic programming over Doppler aliases.
% Enumerate RADIAL Doppler candidates first, then divide each row by its
% signed projection c_i=direction*sqrt(R_i^2-d^2)/R_i. Speed bounds, priors and
% continuity apply to ALONG-TRAJECTORY speed, not radial speed.
% UnwrappedVelocity_mps retains its legacy RADIAL meaning for coupling code.
% TargetSpeed_mps is the new geometry-corrected speed magnitude.
    validateattributes(vMax, {'numeric'}, {'scalar', 'positive', 'finite'});
    n = height(trackTable);
    trackTable.AmbiguityNumber = nan(n, 1);
    trackTable.UnwrappedVelocity_mps = nan(n, 1);
    trackTable.UnwrappedRadialVelocity_mps = nan(n, 1);
    trackTable.TargetSpeed_mps = nan(n, 1);
    trackTable.RadialProjection = nan(n, 1);
    trackTable.AspectAngle_deg = nan(n, 1);
    trackTable.GeometryValid = false(n, 1);
    trackTable.MeasuredSpeed_mps = repmat(cfg.measuredSpeed, n, 1);
    trackTable.MeasuredSpeedResidual_mps = nan(n, 1);
    trackTable.DistanceFitSpeedResidual_mps = nan(n, 1);
    trackTable.GlobalUnwrapPathCost = nan(n, 1);
    if n == 0, return; end

    [projection, validGeometry] = pradar.rangeGeometry(trackTable.Range_m, cfg);
    trackTable.RadialProjection = projection;
    trackTable.GeometryValid = validGeometry;
    trackTable.AspectAngle_deg(validGeometry) = acosd(abs(projection(validGeometry)));
    validRows = find(validGeometry & isfinite(trackTable.AliasedVelocity_mps));
    if isempty(validRows)
        warning('pradar:NoValidGeometry', ...
            'No valid LOS geometry: require R>d and |cos(theta)|>=minRadialProjection.');
        return;
    end
    % Preserve original table order while solving in chronological order.
    [~, order] = sort(trackTable.Time_ms(validRows));
    validRows = validRows(order);
    ambiguityCandidates = cfg.ambiguityNumberMin:cfg.ambiguityNumberMax;
    alias = double(trackTable.AliasedVelocity_mps(validRows));
    possibleRadial = alias(:) + (2*vMax) * ambiguityCandidates;
    possibleSpeed = possibleRadial ./ projection(validRows);
    admissible = isfinite(possibleSpeed) ...
        & possibleSpeed >= cfg.unwrapSpeedMin ...
        & possibleSpeed <= cfg.unwrapSpeedMax;
    localCost = cfg.unwrapMeasuredWeight ...
        * ((possibleSpeed-cfg.measuredSpeed) / cfg.measuredSpeedStd).^2 ...
        + cfg.unwrapFitWeight ...
        * ((possibleSpeed-referenceSpeed) / cfg.distanceFitSpeedStd).^2;
    localCost(~admissible) = Inf;
    [numPoints, numStates] = size(possibleSpeed);
    accumulated = inf(numPoints, numStates);
    previous = zeros(numPoints, numStates);
    accumulated(1, :) = localCost(1, :);
    for i = 2:numPoints
        for k = 1:numStates
            if ~isfinite(localCost(i, k)), continue; end
            transition = cfg.unwrapContinuityWeight ...
                * ((possibleSpeed(i,k)-possibleSpeed(i-1,:)) / cfg.unwrapContinuityStd).^2;
            [best, from] = min(accumulated(i-1,:) + transition);
            accumulated(i,k) = localCost(i,k) + best;
            previous(i,k) = from;
        end
    end
    [bestCost, state] = min(accumulated(end,:));
    if ~isfinite(bestCost)
        warning('pradar:NoUnwrapPath', ...
            'No valid ambiguity path; check geometry, direction and ambiguity/speed bounds.');
        return;
    end
    states = zeros(numPoints,1);
    states(end) = state;
    for i = numPoints:-1:2
        states(i-1) = previous(i,states(i));
    end
    idx = sub2ind(size(possibleSpeed), (1:numPoints).', states);
    radial = possibleRadial(idx);
    targetSpeed = possibleSpeed(idx);
    selectedAmbiguity = ambiguityCandidates(states);
    trackTable.AmbiguityNumber(validRows) = selectedAmbiguity(:);
    trackTable.UnwrappedVelocity_mps(validRows) = radial;
    trackTable.UnwrappedRadialVelocity_mps(validRows) = radial;
    trackTable.TargetSpeed_mps(validRows) = targetSpeed;
    trackTable.MeasuredSpeedResidual_mps(validRows) = targetSpeed-cfg.measuredSpeed;
    trackTable.DistanceFitSpeedResidual_mps(validRows) = targetSpeed-referenceSpeed;
    trackTable.GlobalUnwrapPathCost(validRows) = bestCost;
end
