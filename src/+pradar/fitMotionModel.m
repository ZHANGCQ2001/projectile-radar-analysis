function [model, cost, converged] = fitMotionModel(t, rangeM, radial, seed, cfg, useAnchor)
%FITMOTIONMODEL Scale optimization variables to metre-sized displacements.
% No Optimization Toolbox is required. Known closest time is held fixed.
    if nargin < 6, useAnchor = true; end
    t = double(t(:)); rangeM = double(rangeM(:));
    if ~isempty(radial), radial = double(radial(:)); end
    origin = mean(t); scale = max(max(t)-min(t),1e-4);
    [~,~,v0,x0] = pradar.evaluateMotion(origin,seed,cfg.perpendicularDistance);
    useA = strcmp(cfg.motionModel,'constantAcceleration');
    fixed = isfinite(cfg.closestApproachTimeMs);
    if fixed
        tc = cfg.closestApproachTimeMs*1e-3;
        vc = v0 + seed.acceleration*(tc-origin);
        z = vc*scale;
    else
        z = [x0,v0*scale];
    end
    if useA, z(end+1) = 0.5*seed.acceleration*scale^2; end
    options = optimset('Display','off','MaxIter',500,'MaxFunEvals',1800, ...
        'TolX',1e-8,'TolFun',1e-8);
    [z,cost,exitflag] = fminsearch(@objective,z,options);
    model = decode(z);
    converged = exitflag > 0 && isfinite(cost) && cost < 1e90;

    function value = objective(p)
        value = pradar.jointMotionLoss(decode(p),t,rangeM,radial,cfg,useAnchor);
    end
    function m = decode(p)
        a = 0;
        if useA, a = 2*p(end)/scale^2; end
        if fixed
            v = p(1)/scale;
            tau = origin-cfg.closestApproachTimeMs*1e-3;
            m = struct('timeOrigin',origin,'x0',v*tau+0.5*a*tau^2, ...
                'v0',v+a*tau,'acceleration',a);
        else
            m = struct('timeOrigin',origin,'x0',p(1), ...
                'v0',p(2)/scale,'acceleration',a);
        end
    end
end
