function [rangeM,radial] = predictTrackResult(timeSec,fitInfo,cfg)
%PREDICTTRACKRESULT Plot either the joint model or legacy constant-speed fit.
    if isfield(fitInfo,'motion')
        [rangeM,radial]=pradar.evaluateMotion(timeSec,fitInfo.motion,cfg.perpendicularDistance);
    else
        [rangeM,radial]=pradar.predictRangeTrack(timeSec,fitInfo.speed,fitInfo.intercept,cfg);
    end
end
