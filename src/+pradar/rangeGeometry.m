function [projection, valid, alongTrack] = rangeGeometry(rangeM, cfg)
%RANGEGEOMETRY Signed LOS projection for a straight trajectory.
% R is the measured radar-to-target slant range, d is the perpendicular
% radar-to-trajectory distance. Direction +1 means increasing range, -1
% decreasing range. A selected segment must remain on one side of closest
% approach. Never clamp R<=d or a near-zero projection into a valid speed.
    rangeM = double(rangeM);
    d = cfg.perpendicularDistance;
    projection = nan(size(rangeM));
    alongTrack = nan(size(rangeM));
    valid = isfinite(rangeM) & rangeM > d;
    alongTrack(valid) = cfg.radialDirection ...
        .* sqrt((rangeM(valid)-d) .* (rangeM(valid)+d));
    projection(valid) = alongTrack(valid) ./ rangeM(valid);
    valid = valid & abs(projection) >= cfg.minRadialProjection;
    projection(~valid) = NaN;
    alongTrack(~valid) = NaN;
end
