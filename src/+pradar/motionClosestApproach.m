function [tc, vc, valid] = motionClosestApproach(model)
%MOTIONCLOSESTAPPROACH Root with POSITIVE along-track speed.
% A stable quadratic root avoids subtracting two similar velocities.
    disc = model.v0^2 - 2 * model.acceleration * model.x0;
    valid = isfinite(disc) && disc > 0 && isfinite(model.v0);
    tc = NaN; vc = NaN;
    if ~valid, return; end
    vc = sqrt(disc);
    denominator = model.v0 + vc;
    if denominator <= 0
        valid = false;
        return;
    end
    tc = model.timeOrigin - 2 * model.x0 / denominator;
    valid = isfinite(tc) && vc > 0;
end
