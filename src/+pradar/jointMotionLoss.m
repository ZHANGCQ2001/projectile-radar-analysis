function [cost, parts] = jointMotionLoss(model, t, rangeM, radial, cfg, useAnchor)
%JOINTMOTIONLOSS Slant range + RADIAL data + one closest-speed prior.
% Only independent physical bounds apply globally. No scalar fit-speed prior.
    if nargin < 6, useAnchor = true; end
    parts = struct('range',Inf,'radial',Inf,'transition',Inf,'anchor',0,'motion',0);
    cost = 1e100;
    if ~pradar.motionIsValid(model,t,cfg), return; end
    [predR,predU] = pradar.evaluateMotion(t,model,cfg.perpendicularDistance);
    goodR = isfinite(rangeM);
    if any(~isfinite(predR(goodR))), return; end
    % Conservative overlap discount, not a full covariance correction.
    weight = min(1,cfg.winStep/cfg.winSize);
    rho = @(e) pradar.huberLoss(e,cfg.jointHuberDelta);
    parts.range = weight*sum(rho((predR(goodR)-rangeM(goodR))/cfg.jointRangeStd));
    parts.radial = 0; parts.transition = 0;
    if ~isempty(radial)
        good = find(isfinite(radial) & isfinite(predU));
        e = radial(good)-predU(good);
        parts.radial = weight*sum(rho(e/cfg.jointRadialStd));
        if numel(good)>1
            dt = diff(t(good));
            scale = sqrt(2*cfg.jointRadialStd^2 ...
                + (cfg.motionAccelerationStd*dt).^2);
            % Penalize prediction-residual increments, not true velocity change.
            parts.transition = weight*cfg.jointTransitionWeight ...
                *sum(rho(diff(e)./scale));
        end
    end
    [~,vc] = pradar.motionClosestApproach(model);
    if useAnchor && cfg.useClosestSpeedPrior
        parts.anchor = ((vc-cfg.measuredSpeed)/cfg.closestSpeedStd)^2;
    end
    if strcmp(cfg.motionModel,'constantAcceleration')
        parts.motion = (model.acceleration/cfg.motionAccelerationStd)^2;
    end
    cost = parts.range+parts.radial+parts.transition+parts.anchor+parts.motion;
end
