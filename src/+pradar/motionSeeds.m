function seeds = motionSeeds(t, rangeM, cfg)
%MOTIONSEEDS Range-only starting models. Clipping is INITIALIZATION ONLY.
% No clipping is applied to output measurements or geometrically invalid speed.
    t = double(t(:)); rangeM = double(rangeM(:));
    origin = mean(t); scale = max(max(t)-min(t),1e-4);
    tau = (t-origin)/scale;
    if cfg.radialDirection == 0
        if isfinite(cfg.closestApproachTimeMs)
            splits = cfg.closestApproachTimeMs*1e-3;
        else
            [~,j] = min(rangeM);
            splits = unique([t(j),median(t)]);
        end
    else
        splits = NaN;
    end
    seeds = {};
    lower = max(cfg.fitSpeedMin,cfg.unwrapSpeedMin);
    upper = min(cfg.fitSpeedMax,cfg.unwrapSpeedMax);
    for split = splits(:).'
        if cfg.radialDirection == 0
            side = ones(size(t)); side(t<split)=-1;
        else
            side = cfg.radialDirection*ones(size(t));
        end
        x = side.*sqrt(max(rangeM.^2-cfg.perpendicularDistance^2,0));
        degrees = 1;
        if strcmp(cfg.motionModel,'constantAcceleration') && numel(t)>=4
            degrees = [2,1];
        end
        for degree = degrees
            p = polyfit(tau,x,degree);
            if degree==1, p=[0 p]; end
            m = struct('timeOrigin',origin,'x0',p(3),'v0',p(2)/scale, ...
                'acceleration',2*p(1)/scale^2);
            m.v0 = min(max(m.v0,lower+1e-3),upper-1e-3);
            m.acceleration = min(max(m.acceleration,-0.8*cfg.maxAbsAcceleration), ...
                0.8*cfg.maxAbsAcceleration);
            if isfinite(cfg.closestApproachTimeMs)
                dt = origin-cfg.closestApproachTimeMs*1e-3;
                m.x0 = m.v0*dt-0.5*m.acceleration*dt^2;
            end
            if pradar.motionIsValid(m,t,cfg), seeds{end+1}=m; end %#ok<AGROW>
        end
    end
end
