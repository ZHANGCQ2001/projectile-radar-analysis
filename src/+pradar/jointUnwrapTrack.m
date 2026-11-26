function [track, info] = jointUnwrapTrack(track, vMax, cfg)
%JOINTUNWRAPTRACK Joint slant-range/radial-alias fit, one closest-speed prior.
% Alternates two-best RADIAL Viterbi paths and robust continuous fitting from
% multiple starts. This is a bounded search, NOT a proof of the global optimum.
% Direct pointwise speed and model speed are deliberately separate columns.
    validateattributes(vMax,{'numeric'},{'scalar','real','finite','positive'});
    cfg = pradar.validateConfig(cfg);
    n = height(track);
    fields = {'AmbiguityNumber','UnwrappedVelocity_mps','UnwrappedRadialVelocity_mps', ...
        'TargetSpeed_mps','ModelTargetSpeed_mps','RadialProjection','ModelRadialProjection', ...
        'AspectAngle_deg','FittedRange_m','FitResidual_m','FittedRadialVelocity_mps', ...
        'RadialFitResidual_mps','GlobalUnwrapPathCost','MeasuredSpeedResidual_mps', ...
        'DistanceFitSpeedResidual_mps'};
    for j=1:numel(fields), track.(fields{j})=nan(n,1); end
    track.GeometryValid=false(n,1); track.RangeObservationValid=false(n,1);
    track.MeasuredSpeed_mps=nan(n,1); % no fake per-point ground truth
    info = struct('method','closestApproach','valid',false,'status','insufficient-data', ...
        'model',struct(),'cost',Inf,'alternativeCost',Inf,'ambiguityCostGap',NaN, ...
        'ambiguityUncertain',true,'searchIsExhaustive',false,'numStarts',0, ...
        'numDistinctPaths',0,'closestTimeMs',NaN,'closestSpeed',NaN, ...
        'anchorResidual',NaN,'acceleration',NaN,'rangeRmse',NaN,'radialRmse',NaN, ...
        'closestTimeExtrapolated',false,'referenceIsIndependentValidation',false);
    if n==0, return; end
    required={'Time_ms','Range_m','AliasedVelocity_mps'};
    if ~all(ismember(required,track.Properties.VariableNames))
        error('pradar:MissingJointObservations','Joint solver needs Time_ms, Range_m and AliasedVelocity_mps.');
    end
    valid = isfinite(track.Time_ms) & isfinite(track.Range_m) & track.Range_m>0 ...
        & track.Range_m >= cfg.perpendicularDistance-3*cfg.jointRangeStd;
    track.RangeObservationValid=valid;
    rows=find(valid); [~,order]=sort(track.Time_ms(rows)); rows=rows(order);
    t=double(track.Time_ms(rows))*1e-3;
    if numel(t)<3 || (strcmp(cfg.motionModel,'constantAcceleration') && numel(t)<4), return; end
    if any(diff(t)<=0)
        error('pradar:DuplicateTrackTime','Select at most one target per window; track times must be distinct.');
    end
    R=double(track.Range_m(rows)); alias=double(track.AliasedVelocity_mps(rows));
    if ~any(isfinite(alias)), info.status='no-doppler'; return; end
    period=2*vMax;
    seeds=pradar.motionSeeds(t,R,cfg);
    if isempty(seeds), info.status='no-feasible-motion-seed'; return; end
    initial=seeds;
    for j=1:numel(initial)
        [m,~,ok]=pradar.fitMotionModel(t,R,[],initial{j},cfg,false);
        if ok, seeds=[{m},seeds]; end %#ok<AGROW>
    end
    base=seeds{1};
    speeds=linspace(max(cfg.fitSpeedMin,cfg.unwrapSpeedMin)+1, ...
        min(cfg.fitSpeedMax,cfg.unwrapSpeedMax)-1,5);
    if cfg.useClosestSpeedPrior, speeds=[cfg.measuredSpeed,speeds]; end
    for v=speeds
        m=base; m.v0=v; m.acceleration=0;
        if isfinite(cfg.closestApproachTimeMs)
            m.x0=v*(m.timeOrigin-cfg.closestApproachTimeMs*1e-3);
        end
        if pradar.motionIsValid(m,t,cfg), seeds{end+1}=m; end %#ok<AGROW>
    end
    seeds=seeds(1:min(numel(seeds),cfg.jointMaxStarts));
    solutions={};
    for j=1:numel(seeds)
        info.numStarts=info.numStarts+1;
        m=seeds{j}; lastK=[];
        for iter=1:cfg.jointMaxIterations
            [~,prediction]=pradar.evaluateMotion(t,m,cfg.perpendicularDistance);
            [radial,k,pathCost]=pradar.radialAliasPath(t,alias,prediction,period,cfg);
            if ~isfinite(pathCost), break; end
            [next,~,ok]=pradar.fitMotionModel(t,R,radial,m,cfg,true);
            if ~ok, break; end
            change=abs(next.v0-m.v0)+abs(next.x0-m.x0);
            m=next;
            if isequaln(k,lastK) && change<1e-5, break; end
            lastK=k;
        end
        [~,prediction]=pradar.evaluateMotion(t,m,cfg.perpendicularDistance);
        [radial,k,~,alternative]=pradar.radialAliasPath(t,alias,prediction,period,cfg);
        addSolution(m,radial,k);
        % Retain a distinct conditional path and refit it without collapsing
        % it back onto the best path. This gives an explicit competing solution.
        if isfinite(alternative.cost)
            [other,~,ok]=pradar.fitMotionModel(t,R,alternative.radial,m,cfg,true);
            if ok, addSolution(other,alternative.radial,alternative.ambiguity); end
        end
    end
    if isempty(solutions), info.status='no-feasible-joint-solution'; return; end
    costs=cellfun(@(s)s.cost,solutions); [~,order]=sort(costs);
    best=solutions{order(1)}; m=best.model;
    [predR,predU,V,x,c]=pradar.evaluateMotion(t,m,cfg.perpendicularDistance);
    radial=best.radial;
    track.AmbiguityNumber(rows)=best.k;
    track.UnwrappedVelocity_mps(rows)=radial;
    track.UnwrappedRadialVelocity_mps(rows)=radial;
    track.ModelTargetSpeed_mps(rows)=V;
    track.ModelRadialProjection(rows)=c;
    track.FittedRange_m(rows)=predR;
    track.FitResidual_m(rows)=R-predR;
    track.FittedRadialVelocity_mps(rows)=predU;
    track.RadialFitResidual_mps(rows)=radial-predU;
    % Use each actual range for direct correction. Never clamp R<=d into a
    % valid output, and never fill an unobservable point with a model value.
    cMeasured=nan(size(R)); g=R>cfg.perpendicularDistance;
    cMeasured(g)=sign(x(g)).*sqrt((R(g)-cfg.perpendicularDistance) ...
        .*(R(g)+cfg.perpendicularDistance))./R(g);
    direct=g & abs(cMeasured)>=cfg.minRadialProjection & isfinite(radial);
    track.RadialProjection(rows)=cMeasured;
    track.GeometryValid(rows)=direct;
    track.TargetSpeed_mps(rows(direct))=radial(direct)./cMeasured(direct);
    track.AspectAngle_deg(rows(g))=acosd(min(1,abs(cMeasured(g))));
    track.DistanceFitSpeedResidual_mps(rows(direct))= ...
        track.TargetSpeed_mps(rows(direct))-V(direct);
    track.GlobalUnwrapPathCost(rows)=best.cost;
    [tc,vc]=pradar.motionClosestApproach(m);
    info.model=m; info.cost=best.cost; info.costComponents=best.parts;
    info.numDistinctPaths=numel(solutions);
    info.closestTimeMs=tc*1e3; info.closestSpeed=vc;
    if cfg.useClosestSpeedPrior, info.anchorResidual=vc-cfg.measuredSpeed; end
    info.acceleration=m.acceleration;
    info.rangeRmse=sqrt(mean((R-predR).^2));
    good=isfinite(radial)&isfinite(predU);
    info.radialRmse=sqrt(mean((radial(good)-predU(good)).^2));
    info.closestTimeExtrapolated=tc<min(t) || tc>max(t);
    if numel(order)>1
        info.alternativeCost=solutions{order(2)}.cost;
        info.ambiguityCostGap=max(0,info.alternativeCost-info.cost);
        info.alternativeModel=solutions{order(2)}.model;
        info.alternativeAmbiguity=solutions{order(2)}.k;
    end
    info.valid=isfinite(info.cost) && info.cost<1e90;
    largeResidual=info.rangeRmse>cfg.jointMaxNormalizedResidual*cfg.jointRangeStd ...
        || info.radialRmse>cfg.jointMaxNormalizedResidual*cfg.jointRadialStd;
    farExtrap=max([min(t)-tc,tc-max(t),0])>3*(max(t)-min(t));
    info.ambiguityUncertain=~isfinite(info.ambiguityCostGap) ...
        || info.ambiguityCostGap<cfg.jointAmbiguityGapThreshold || largeResidual || farExtrap;
    info.status='estimated';
    if info.ambiguityUncertain, info.status='uncertain'; end
    % A large residual is a model/data mismatch, not a trustworthy solution.
    if largeResidual, info.status='model-mismatch'; end

    function addSolution(model,u,k)
        if ~any(isfinite(u)), return; end
        [value,parts]=pradar.jointMotionLoss(model,t,R,u,cfg,true);
        if ~isfinite(value) || value>=1e90, return; end
        candidate=struct('model',model,'radial',u,'k',k,'cost',value,'parts',parts);
        for z=1:numel(solutions)
            if isequaln(solutions{z}.k,k)
                if value<solutions{z}.cost, solutions{z}=candidate; end
                return;
            end
        end
        solutions{end+1}=candidate;
    end
end
