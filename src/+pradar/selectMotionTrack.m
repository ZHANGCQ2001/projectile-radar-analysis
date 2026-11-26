function [track,fit] = selectMotionTrack(input,cfg,derived)
%SELECTMOTIONTRACK Bounded multi-hypothesis association and joint alias fitting.
% Initial hypotheses use geometry/range, not the closest-speed prior.
    track=table();
    fit=struct('valid',false,'speed',NaN,'intercept',NaN,'rmse',NaN, ...
        'expectedAliasedSpeed',NaN,'meanCircularVelocityResidual',NaN, ...
        'geometryRejectedCount',0,'speedType','closest-approach');
    if isempty(input), return; end
    inTime=input.Time_ms>=cfg.trackStartTimeMs & input.Time_ms<=cfg.trackEndTimeMs;
    geometry=isfinite(input.Range_m)&input.Range_m>0 ...
        & input.Range_m>=cfg.perpendicularDistance-3*cfg.jointRangeStd;
    fit.geometryRejectedCount=nnz(inTime & ~geometry);
    good=inTime & geometry & isfinite(input.Time_ms) & isfinite(input.RelativeStrength_dB);
    c=sortrows(input(good,:),{'Time_ms','GlobalWindow'});
    groups=unique(c.GlobalWindow,'stable');
    if numel(groups)<cfg.minTrackWindows, return; end
    % Sample at most 16 windows and two strongest candidates per window.
    % Limits pair enumeration while retaining widely separated hypotheses.
    sampleGroups=groups(unique(round(linspace(1,numel(groups),min(16,numel(groups))))));
    sample=[];
    for j=1:numel(sampleGroups)
        idx=find(c.GlobalWindow==sampleGroups(j));
        [~,order]=sort(c.RelativeStrength_dB(idx),'descend');
        sample=[sample;idx(order(1:min(2,numel(order))))]; %#ok<AGROW>
    end
    splits=NaN;
    if cfg.radialDirection==0
        if isfinite(cfg.closestApproachTimeMs)
            splits=cfg.closestApproachTimeMs*1e-3;
        else
            [~,j]=min(c.Range_m);
            splits=unique([c.Time_ms(j),median(c.Time_ms)])/1000;
        end
    end
    proposals={}; scores=[]; selections={};
    for split=splits(:).'
        if cfg.radialDirection==0
            signX=ones(height(c),1); signX(c.Time_ms*1e-3<split)=-1;
        else
            signX=cfg.radialDirection*ones(height(c),1);
        end
        initialX=signX.*sqrt(max(c.Range_m.^2-cfg.perpendicularDistance^2,0));
        for ia=1:numel(sample)-1
            for ib=ia+1:numel(sample)
                a=sample(ia); b=sample(ib);
                dt=(c.Time_ms(b)-c.Time_ms(a))*1e-3;
                if dt<max(1e-8,cfg.minHypothesisSpanMs*1e-3), continue; end
                v=(initialX(b)-initialX(a))/dt;
                if v<cfg.fitSpeedMin || v>cfg.fitSpeedMax, continue; end
                m=struct('timeOrigin',c.Time_ms(a)*1e-3,'x0',initialX(a), ...
                    'v0',v,'acceleration',0);
                if isfinite(cfg.closestApproachTimeMs)
                    m.x0=v*(m.timeOrigin-cfg.closestApproachTimeMs*1e-3);
                end
                [rows,score]=pradar.associateMotionCandidates(c,m,cfg,derived,true);
                if numel(rows)<cfg.minTrackWindows, continue; end
                % Keep the best representative of each selected row set.
                same=find(cellfun(@(x)isequal(x,rows),selections),1);
                if ~isempty(same)
                    if score>scores(same), scores(same)=score; proposals{same}=m; end
                else
                    proposals{end+1}=m; scores(end+1)=score; selections{end+1}=rows; %#ok<AGROW>
                end
            end
        end
    end
    if isempty(proposals), return; end
    [~,order]=sort(scores,'descend');
    order=order(1:min(numel(order),cfg.jointMaxTrackHypotheses));
    bestScore=-Inf;
    for j=order
        m=proposals{j}; rows=selections{j};
        % Refine shape from ranges, including low-projection samples.
        for iteration=1:3
            t=c.Time_ms(rows)*1e-3; R=c.Range_m(rows);
            seeds=pradar.motionSeeds(t,R,cfg);
            seeds=[{m},seeds];
            bestRange=Inf; fitted=m;
            for k=1:numel(seeds)
                [trial,value,ok]=pradar.fitMotionModel(t,R,[],seeds{k},cfg,false);
                if ok && value<bestRange, bestRange=value; fitted=trial; end
            end
            m=fitted;
            [newRows,~]=pradar.associateMotionCandidates(c,m,cfg,derived,true);
            if numel(newRows)<cfg.minTrackWindows, break; end
            if isequal(newRows,rows), rows=newRows; break; end
            rows=newRows;
        end
        [candidate,info]=pradar.jointUnwrapTrack(c(rows,:),derived.vMax,cfg);
        if ~info.valid || strcmp(info.status,'model-mismatch'), continue; end
        [finalRows,score]=pradar.associateMotionCandidates(c,info.model,cfg,derived,false);
        if numel(finalRows)<cfg.minTrackWindows, continue; end
        if ~isequal(finalRows,rows)
            [candidate,info]=pradar.jointUnwrapTrack(c(finalRows,:),derived.vMax,cfg);
            if ~info.valid || strcmp(info.status,'model-mismatch'), continue; end
            [checked,score]=pradar.associateMotionCandidates(c,info.model,cfg,derived,false);
            if ~isequal(checked,finalRows), continue; end
        end
        % The anchor enters once per full hypothesis, never once per point.
        score=score-info.costComponents.anchor;
        if score>bestScore
            bestScore=score; track=candidate;
            fit.valid=true; fit.speed=info.closestSpeed;
            fit.motion=info.model; fit.unwrapInfo=info;
            fit.intercept=info.model.x0-info.model.v0*info.model.timeOrigin ...
                +0.5*info.model.acceleration*info.model.timeOrigin^2;
            fit.initialSlantRange=hypot(cfg.perpendicularDistance,fit.intercept);
            fit.rmse=info.rangeRmse;
            fit.meanCircularVelocityResidual=mean(abs(track.RadialFitResidual_mps),'omitnan');
            track.ExpectedAliasedVelocity_mps=pradar.wrapVelocity( ...
                track.FittedRadialVelocity_mps,derived.vMax);
            track.CircularVelocityResidual_mps=pradar.circularVelocityDifference( ...
                track.AliasedVelocity_mps,track.ExpectedAliasedVelocity_mps,derived.velocityPeriod);
        end
    end
end
