function [rangeM, radialVelocity, valid] = predictRangeTrack(timeSec, speed, intercept, cfg)
%PREDICTRANGETRACK Slant range and radial velocity from along-track motion.
% x(t)=intercept+speed*t; R(t)=hypot(d,x); vr(t)=speed*x/R.
% speed is the positive along-trajectory speed, not the slant-range slope.
    alongTrack = intercept + speed .* double(timeSec);
    rangeM = hypot(cfg.perpendicularDistance, alongTrack);
    projection = alongTrack ./ rangeM;
    radialVelocity = speed .* projection;
    valid = isfinite(rangeM) & rangeM > cfg.perpendicularDistance ...
        & cfg.radialDirection .* alongTrack > 0 ...
        & abs(projection) >= cfg.minRadialProjection;
end
