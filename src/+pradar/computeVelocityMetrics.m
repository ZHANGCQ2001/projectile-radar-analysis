function metrics = computeVelocityMetrics(trackTable, measuredSpeed)
%COMPUTEVELOCITYMETRICS Calculate velocity accuracy statistics.

    metrics = struct( ...
        'meanSpeed', NaN, ...
        'standardDeviation', NaN, ...
        'mae', NaN, ...
        'rmse', NaN, ...
        'minimumAbsoluteError', NaN, ...
        'relativeRmsePercent', NaN, ...
        'relativeMinimumAbsoluteErrorPercent', NaN);

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
