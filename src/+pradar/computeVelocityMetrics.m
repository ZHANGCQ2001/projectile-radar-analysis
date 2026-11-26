function metrics = computeVelocityMetrics(trackTable, measuredSpeed, unwrapInfo)
%COMPUTEVELOCITYMETRICS Calculate velocity accuracy statistics.

    metrics = struct( ...
        'meanSpeed', NaN, ...
        'standardDeviation', NaN, ...
        'mae', NaN, ...
        'rmse', NaN, ...
        'minimumAbsoluteError', NaN, ...
        'relativeRmsePercent', NaN, ...
        'relativeMinimumAbsoluteErrorPercent', NaN);

    if nargin<3, unwrapInfo=struct(); end
    metrics.referenceScope = 'legacy-global';
    metrics.closestSpeed = NaN;
    metrics.closestReferenceResidual = NaN;
    metrics.radialModelRmse = NaN;
    if isfield(unwrapInfo,'method') && strcmp(unwrapInfo.method,'closestApproach')
        metrics.referenceScope = 'closest-point-only';
        if isfield(unwrapInfo,'closestSpeed')
            metrics.closestSpeed = unwrapInfo.closestSpeed;
            metrics.closestReferenceResidual = unwrapInfo.anchorResidual;
            metrics.radialModelRmse = unwrapInfo.radialRmse;
        end
    end
    if isempty(trackTable), return; end
    if ismember('TargetSpeed_mps', trackTable.Properties.VariableNames)
        velocity = trackTable.TargetSpeed_mps;
    elseif ismember('UnwrappedVelocity_mps', trackTable.Properties.VariableNames)
        velocity = trackTable.UnwrappedVelocity_mps;
    else
        return;
    end
    velocity = velocity(isfinite(velocity));
    if isempty(velocity), return; end
    if strcmp(metrics.referenceScope,'closest-point-only')
        metrics.meanSpeed = mean(velocity);
        metrics.standardDeviation = std(velocity);
        % Legacy RMSE/MAE fields remain NaN: anchor residual is NOT accuracy.
        return;
    end
    errorValue = velocity - measuredSpeed;

    metrics.meanSpeed = mean(velocity);
    metrics.standardDeviation = std(velocity);
    metrics.mae = mean(abs(errorValue));
    metrics.rmse = sqrt(mean(errorValue.^2));
    metrics.minimumAbsoluteError = min(abs(errorValue));
    metrics.relativeRmsePercent = ...
        metrics.rmse / abs(measuredSpeed) * 100;
    metrics.relativeMinimumAbsoluteErrorPercent = ...
        metrics.minimumAbsoluteError / abs(measuredSpeed) * 100;
end
