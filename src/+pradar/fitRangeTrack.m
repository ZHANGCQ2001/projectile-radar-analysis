function [speed, intercept, valid] = fitRangeTrack(timeSec, rangeM, cfg)
%FITRANGETRACK Fit a constant-speed straight trajectory to slant ranges.
% Initialize in along-track coordinates, then minimize SLANT-range residuals
% (not transformed-range residuals) when d>0. Center/scale time for stability.
% Only base MATLAB polyfit/fminsearch are needed. d=0 retains linear fitting.
    speed = NaN;
    intercept = NaN;
    valid = false;
    timeSec = double(timeSec(:));
    rangeM = double(rangeM(:));
    [~, geometryValid, alongTrack] = pradar.rangeGeometry(rangeM, cfg);
    if numel(timeSec) ~= numel(rangeM) || numel(timeSec) < 2 ...
            || any(~isfinite(timeSec)) || ~all(geometryValid) ...
            || numel(unique(timeSec)) < 2
        return;
    end
    origin = mean(timeSec);
    timeScale = max(timeSec) - min(timeSec);
    tau = (timeSec - origin) / timeScale;
    p = polyfit(tau, alongTrack, 1);
    if cfg.perpendicularDistance > 0
        options = optimset('Display', 'off', 'MaxIter', 300, ...
            'MaxFunEvals', 1000, 'TolX', 1e-9, 'TolFun', 1e-10);
        p = fminsearch(@loss, p, options);
    end
    speed = p(1) / timeScale;
    intercept = p(2) - speed * origin;
    [~, ~, validPrediction] = pradar.predictRangeTrack(timeSec, speed, intercept, cfg);
    valid = isfinite(speed) && isfinite(intercept) ...
        && speed >= cfg.fitSpeedMin && speed <= cfg.fitSpeedMax ...
        && all(validPrediction);

    function value = loss(candidate)
        x = candidate(1) * tau + candidate(2);
        if candidate(1) <= 0 || any(cfg.radialDirection * x <= 0)
            value = realmax('double') / 100;
            return;
        end
        residual = hypot(cfg.perpendicularDistance, x) - rangeM;
        value = mean(residual.^2);
    end
end
