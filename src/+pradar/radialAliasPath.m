function [radial, ambiguity, cost, second] = radialAliasPath(t, alias, prediction, period, cfg)
%RADIALALIASPATH Two-best Viterbi paths in RADIAL measurement space.
% Missing Doppler rows stay NaN. Transitions use actual elapsed time and
% geometric model increments; wrap integers may change freely at boundaries.
    n = numel(t); radial = nan(n,1); ambiguity = nan(n,1);
    second = struct('radial',radial,'ambiguity',ambiguity,'cost',Inf);
    good = find(isfinite(alias) & isfinite(prediction));
    cost = Inf;
    if isempty(good), return; end
    ks = cfg.ambiguityNumberMin:cfg.ambiguityNumberMax;
    possible = double(alias(good)) + period*ks;
    residual = possible-double(prediction(good));
    m = numel(good); s = numel(ks);
    weight = min(1,cfg.winStep/cfg.winSize);
    local = weight*pradar.huberLoss(residual/cfg.jointRadialStd,cfg.jointHuberDelta);
    scores = inf(s,2); scores(:,1) = local(1,:).';
    prevState = zeros(m,s,2); prevRank = zeros(m,s,2);
    for i=2:m
        scale = sqrt(2*cfg.jointRadialStd^2 ...
            + (cfg.motionAccelerationStd*(t(good(i))-t(good(i-1))))^2);
        next = inf(s,2);
        for k=1:s
            transition = weight*cfg.jointTransitionWeight ...
                *pradar.huberLoss((residual(i,k)-residual(i-1,:))/scale,cfg.jointHuberDelta);
            candidates = scores+transition(:);
            [sorted,idx] = sort(candidates(:),'ascend');
            count = min(2,numel(idx));
            next(k,1:count) = sorted(1:count).'+local(i,k);
            [state,rank] = ind2sub([s,2],idx(1:count));
            prevState(i,k,1:count) = reshape(state,1,1,[]);
            prevRank(i,k,1:count) = reshape(rank,1,1,[]);
        end
        scores = next;
    end
    [sorted,idx] = sort(scores(:),'ascend');
    [radial,ambiguity] = trace(idx(1)); cost = sorted(1);
    if numel(idx)>1 && isfinite(sorted(2))
        [second.radial,second.ambiguity] = trace(idx(2));
        second.cost = sorted(2);
    end
    function [u,kout] = trace(last)
        [state,rank] = ind2sub([s,2],last);
        states = zeros(m,1); states(m)=state;
        for j=m:-1:2
            oldState = state;
            state = prevState(j,oldState,rank);
            rank = prevRank(j,oldState,rank);
            states(j-1)=state;
        end
        u=nan(n,1); kout=nan(n,1);
        u(good)=possible(sub2ind([m,s],(1:m).',states));
        kout(good)=ks(states);
    end
end
