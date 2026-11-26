function valid = motionIsValid(model, timeSec, cfg)
%MOTIONISVALID Check physical bounds over observations AND anchor interval.
    [tc, vc, valid] = pradar.motionClosestApproach(model);
    if ~valid || isempty(timeSec), valid = false; return; end
    t = double(timeSec(:));
    [~,~,v,x] = pradar.evaluateMotion(t,model,cfg.perpendicularDistance);
    lower = max(cfg.fitSpeedMin,cfg.unwrapSpeedMin);
    upper = min(cfg.fitSpeedMax,cfg.unwrapSpeedMax);
    valid = all(isfinite(x)) && all(isfinite(v)) ...
        && min([v;vc]) >= max(lower,eps) && max([v;vc]) <= upper ...
        && abs(model.acceleration) <= cfg.maxAbsAcceleration;
    if cfg.radialDirection ~= 0
        valid = valid && all(cfg.radialDirection*x >= -1e-8);
    else
        valid = valid && tc >= min(t)-1e-8 && tc <= max(t)+1e-8;
    end
    distanceToInterval = max([min(t)-tc, tc-max(t), 0]);
    valid = valid && distanceToInterval <= cfg.closestMaxExtrapolationMs*1e-3;
    if isfinite(cfg.closestApproachTimeMs)
        valid = valid && abs(tc-cfg.closestApproachTimeMs*1e-3) < 1e-7;
    end
end
