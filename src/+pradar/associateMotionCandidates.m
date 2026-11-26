function [rows, score] = associateMotionCandidates(candidates, model, cfg, derived, bootstrap)
%ASSOCIATEMOTIONCANDIDATES Model-based association without a repeated reference prior.
% Bootstrap uses a wider range gate and soft Doppler cost; final association
% honors the explicit hard gate. The same window can contribute at most once.
    if nargin<5, bootstrap=false; end
    [rangePred,radialPred] = pradar.evaluateMotion( ...
        candidates.Time_ms*1e-3,model,cfg.perpendicularDistance);
    dr=abs(candidates.Range_m-rangePred);
    du=pradar.circularVelocityDifference(candidates.AliasedVelocity_mps, ...
        pradar.wrapVelocity(radialPred,derived.vMax),derived.velocityPeriod);
    missing=~isfinite(candidates.AliasedVelocity_mps);
    du(missing)=0; % missing Doppler contributes NO measurement cost
    gate=cfg.trackTolerance;
    if bootstrap, gate=2*gate; end
    good=isfinite(dr) & dr<=gate & isfinite(radialPred);
    if ~bootstrap && cfg.useVelocityHardGate
        good=good & (missing | du<=cfg.velocityTolerance);
    end
    dvScale=max(cfg.velocityTolerance,cfg.jointRadialStd);
    strength=max(candidates.RelativeStrength_dB,0);
    velocityWeight=cfg.velocityCostWeight;
    if bootstrap, velocityWeight=min(velocityWeight,0.1); end
    cost=(dr/max(gate,eps)).^2+velocityWeight*(du/dvScale).^2 ...
        -cfg.strengthCostWeight*strength/max(cfg.candidateThresholdDb,1);
    groups=unique(candidates.GlobalWindow,'stable'); rows=[];
    for j=1:numel(groups)
        idx=find(candidates.GlobalWindow==groups(j)&good);
        if isempty(idx), continue; end
        [~,k]=min(cost(idx)); rows(end+1,1)=idx(k); %#ok<AGROW>
    end
    score=-Inf;
    if isempty(rows), return; end
    coverage=numel(rows)/numel(groups);
    w=sort(candidates.GlobalWindow(rows));
    breaks=find([true;diff(w)~=1;true]);
    continuity=max(diff(breaks))/numel(rows);
    score=cfg.trackCoverageWeight*coverage+cfg.trackContinuityWeight*continuity ...
        +cfg.trackMeanStrengthWeight*mean(strength(rows)) ...
        -cfg.trackDistanceNormalizedPenalty*mean(dr(rows))/max(gate,eps) ...
        -cfg.trackVelocityNormalizedPenalty*mean(du(rows))/dvScale;
end
