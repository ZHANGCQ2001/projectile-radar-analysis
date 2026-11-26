function trackTable = unwrapTrackVelocity(trackTable, vMax, referenceSpeed, cfg)
%UNWRAPTRACKVELOCITY Geometry-aware dynamic programming over Doppler aliases.
% Enumerate RADIAL Doppler candidates first, then divide each row by its
% signed projection c_i=direction*sqrt(R_i^2-d^2)/R_i. Speed bounds, priors and
% continuity apply to ALONG-TRAJECTORY speed, not radial speed.
% UnwrappedVelocity_mps retains its legacy RADIAL meaning for coupling code.
% TargetSpeed_mps is the new geometry-corrected speed magnitude.
%
% The user reference speed (cfg.measuredSpeed, e.g. 200 m/s) anchors ONLY the
% last observed frame. Frames are solved backwards from that end anchor, with
% continuity linking each earlier frame to the later one. The referenceSpeed
% argument (fitInfo.speed) is an optional secondary end anchor, disabled by
% default. This keeps an accelerating target from being pulled back to the
% end speed at every window.
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
    % Solve backwards: the reference speed belongs to the target's END
    % frame, so the latest valid point is the DP start and each earlier
    % point is reached through a continuity-constrained transition.
    [~, order] = sort(trackTable.Time_ms(validRows), 'descend');
    validRows = validRows(order);
    ambiguityCandidates = cfg.ambiguityNumberMin:cfg.ambiguityNumberMax;
    alias = double(trackTable.AliasedVelocity_mps(validRows));
    possibleRadial = alias(:) + (2*vMax) * ambiguityCandidates;
    possibleSpeed = possibleRadial ./ projection(validRows);
    admissible = isfinite(possibleSpeed) ...
        & possibleSpeed >= cfg.unwrapSpeedMin ...
        & possibleSpeed <= cfg.unwrapSpeedMax;

    % Anchor only the end frame. Middle frames keep zero local prior cost:
    % their valid ambiguity states are fixed by Doppler + geometry + speed
    % bounds and linked by continuity, instead of being biased towards the
    % end speed at every window.
    localCost = zeros(size(possibleSpeed));
    anchorWeight = configValue(cfg, 'unwrapEndAnchorWeight', 2.0);
    endAnchor = cfg.unwrapMeasuredWeight ...
        * ((possibleSpeed(1,:)-cfg.measuredSpeed) / cfg.measuredSpeedStd).^2;
    % The fit speed is only an optional secondary anchor. By default it is
    % disabled because a constant-speed fit over an accelerating trajectory
    % would pull the end frame away from the user-supplied reference speed.
    endFitWeight = configValue(cfg, 'unwrapEndFitWeight', 0);
    if endFitWeight > 0
        endAnchor = endAnchor + endFitWeight ...
            * ((possibleSpeed(1,:)-referenceSpeed) / cfg.distanceFitSpeedStd).^2;
    end
    localCost(1,:) = anchorWeight * endAnchor;
    localCost(~admissible) = Inf;
    [numPoints, numStates] = size(possibleSpeed);
    accumulated = inf(numPoints, numStates);
    previous = zeros(numPoints, numStates);
    accumulated(1, :) = localCost(1, :);
    aliasChangePenalty = configValue(cfg, 'unwrapAliasChangePenalty', 0.5);
    for i = 2:numPoints
        for k = 1:numStates
            if ~isfinite(localCost(i, k)), continue; end
            transition = cfg.unwrapContinuityWeight ...
                * ((possibleSpeed(i,k)-possibleSpeed(i-1,:)) / cfg.unwrapContinuityStd).^2 ...
                + aliasChangePenalty ...
                * abs(ambiguityCandidates(k) - ambiguityCandidates);
            [best, from] = min(accumulated(i-1,:) + transition);
            accumulated(i,k) = localCost(i,k) + best;
            previous(i,k) = from;
        end
    end
    % Backtrack from the earliest frame towards the anchored end frame.
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
    % Residual against the END-frame reference, not a per-frame prior.
    trackTable.DistanceFitSpeedResidual_mps(validRows) = targetSpeed-referenceSpeed;
    trackTable.GlobalUnwrapPathCost(validRows) = bestCost;
end

function value = configValue(cfg, fieldName, defaultValue)
%CONFIGVALUE Read an optional config field with a backward-compatible default.
    if isfield(cfg, fieldName) && ~isempty(cfg.(fieldName))
        value = cfg.(fieldName);
    else
        value = defaultValue;
    end
end
