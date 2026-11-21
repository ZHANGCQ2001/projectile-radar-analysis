function tests = test_geometryTrack
    tests = functiontests(localfunctions);
end

function testRecedingNonlinearRange(testCase)
    [cfg, derived, candidates] = fixture(1,3);
    [track, fit] = pradar.selectTrack(candidates,cfg,derived);
    verifyTrue(testCase, fit.valid);
    verifyEqual(testCase, height(track),height(candidates));
    verifyEqual(testCase, fit.speed,400,'AbsTol',1e-4);
    verifyLessThan(testCase, fit.rmse,1e-7);
    verifyGreaterThan(testCase, (max(track.FittedRadialVelocity_mps)-min(track.FittedRadialVelocity_mps)),20);
    verifyTrue(testCase, isnan(fit.expectedAliasedSpeed));
    output = pradar.unwrapTrackVelocity(track,derived.vMax,fit.speed,cfg);
    verifyEqual(testCase, output.TargetSpeed_mps, repmat(400,height(output),1),'AbsTol',1e-6);
end

function testApproachingNonlinearRange(testCase)
    [cfg, derived, candidates] = fixture(-1,3);
    [track, fit] = pradar.selectTrack(candidates,cfg,derived);
    verifyTrue(testCase, fit.valid);
    verifyEqual(testCase, fit.speed,400,'AbsTol',1e-4);
    verifyTrue(testCase, all(track.FittedRadialVelocity_mps<0));
    verifyLessThan(testCase,fit.rmse,1e-7);
end

function testLegacyCollinearFit(testCase)
    [cfg, derived, candidates] = fixture(1,0);
    [track, fit] = pradar.selectTrack(candidates,cfg,derived);
    coefficients = polyfit(candidates.Time_ms*1e-3,candidates.Range_m,1);
    verifyTrue(testCase,fit.valid);
    verifyEqual(testCase, [fit.speed fit.intercept],coefficients,'AbsTol',1e-8);
    verifyEqual(testCase,track.ExpectedAliasedVelocity_mps, ...
        repmat(pradar.wrapVelocity(400,derived.vMax),height(track),1),'AbsTol',1e-8);
end

function testImpossibleRangeRejected(testCase)
    [cfg, derived, candidates] = fixture(1,3);
    invalid = candidates(1,:); invalid.Range_m = 2; invalid.RelativeStrength_dB = 100;
    [track, fit] = pradar.selectTrack([invalid;candidates],cfg,derived);
    verifyTrue(testCase,fit.valid);
    verifyEqual(testCase,fit.geometryRejectedCount,1);
    verifyTrue(testCase,all(track.Range_m>3));
end

function testNoisyFitUsesSlantResiduals(testCase)
    [cfg, ~, candidates] = fixture(1,3);
    t = candidates.Time_ms*1e-3; R = candidates.Range_m + 0.01*sin((1:height(candidates)).');
    [~,~,x] = pradar.rangeGeometry(R,cfg);
    initial = polyfit(t,x,1);
    initialSse = sum((hypot(3,polyval(initial,t))-R).^2);
    [speed,intercept,valid] = pradar.fitRangeTrack(t,R,cfg);
    verifyTrue(testCase,valid);
    sse = sum((pradar.predictRangeTrack(t,speed,intercept,cfg)-R).^2);
    verifyLessThanOrEqual(testCase,sse,initialSse+1e-10);
end

function [cfg, derived, candidates] = fixture(direction,d)
    cfg = pradar.defaultConfig(); cfg.measuredSpeed = 400;
    cfg.perpendicularDistance = d; cfg.radialDirection = direction;
    cfg.fitSpeedMin = 300; cfg.fitSpeedMax = 500;
    cfg.unwrapSpeedMin = 300; cfg.unwrapSpeedMax = 500;
    cfg.trackTolerance = 0.05; cfg.useVelocityHardGate = true;
    cfg.velocityTolerance = 5;
    derived = pradar.deriveParameters(cfg);
    t = (0:11).'*0.6;
    x0 = 2; if direction < 0, x0 = -5; end
    x = x0+400*t*1e-3; R = hypot(d,x); radial = 400*x./R;
    n = numel(t); idx = (1:n).';
    candidates = table(idx,ones(n,1),idx,t,R, ...
        pradar.wrapVelocity(radial,derived.vMax),repmat(25,n,1),ones(n,1), ...
        'VariableNames',{'GlobalWindow','PhysicalFrame','WindowInFrame','Time_ms', ...
        'Range_m','AliasedVelocity_mps','RelativeStrength_dB','RangeBin'});
end
