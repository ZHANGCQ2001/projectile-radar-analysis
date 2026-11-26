function tests = test_geometryUnwrap
    tests = functiontests(localfunctions);
end

function testChangingAngleReceding(testCase)
    [cfg, input, trueRadial] = fixture(1);
    track = pradar.unwrapTrackVelocity(input, 80, 400, cfg);
    verifyEqual(testCase, track.TargetSpeed_mps, repmat(400,height(track),1), 'AbsTol', 1e-9);
    verifyEqual(testCase, track.UnwrappedRadialVelocity_mps, trueRadial, 'AbsTol', 1e-9);
    verifyEqual(testCase, track.UnwrappedVelocity_mps, trueRadial, 'AbsTol', 1e-9);
    verifyGreaterThan(testCase, max(trueRadial)-min(trueRadial), 50);
    metrics = pradar.computeVelocityMetrics(track, 400);
    verifyLessThan(testCase, metrics.rmse, 1e-9);
end

function testApproachingDoesNotInferDirectionFromAlias(testCase)
    [cfg, input, trueRadial] = fixture(-1);
    track = pradar.unwrapTrackVelocity(input, 80, 400, cfg);
    verifyTrue(testCase, any(input.AliasedVelocity_mps > 0));
    verifyTrue(testCase, all(trueRadial < 0));
    verifyEqual(testCase, track.UnwrappedRadialVelocity_mps, trueRadial, 'AbsTol', 1e-9);
    verifyEqual(testCase, track.TargetSpeed_mps, repmat(400,height(track),1), 'AbsTol', 1e-9);
end

function testInvalidRowDoesNotPoisonOtherRows(testCase)
    [cfg, input, ~] = fixture(1);
    input.Range_m(4) = cfg.perpendicularDistance;
    track = pradar.unwrapTrackVelocity(input, 80, 400, cfg);
    verifyFalse(testCase, track.GeometryValid(4));
    verifyTrue(testCase, isnan(track.TargetSpeed_mps(4)));
    valid = [1:3 5:height(input)];
    verifyEqual(testCase, track.TargetSpeed_mps(valid), repmat(400,numel(valid),1), 'AbsTol', 1e-9);
end

function testZeroOffsetMatchesRadialSpeed(testCase)
    [cfg, input, ~] = fixture(1); cfg.perpendicularDistance = 0;
    input.AliasedVelocity_mps(:) = pradar.wrapVelocity(400,80);
    track = pradar.unwrapTrackVelocity(input,80,400,cfg);
    verifyEqual(testCase, track.TargetSpeed_mps, track.UnwrappedVelocity_mps);
    verifyEqual(testCase, track.TargetSpeed_mps, repmat(400,height(input),1), 'AbsTol', 1e-9);
end

function testEmptyTrack(testCase)
    cfg = pradar.defaultConfig(); cfg.unwrapMethod = "legacy";
    result = pradar.unwrapTrackVelocity(table(),80,400,cfg);
    verifyEqual(testCase, height(result), 0);
    verifyTrue(testCase, ismember('TargetSpeed_mps',result.Properties.VariableNames));
end

function testAllInvalidGeometry(testCase)
    [cfg, input, ~] = fixture(1); input.Range_m(:) = cfg.perpendicularDistance;
    verifyWarning(testCase, @() pradar.unwrapTrackVelocity(input,80,400,cfg), 'pradar:NoValidGeometry');
end

function testNoAdmissibleAlias(testCase)
    [cfg, input, ~] = fixture(1);
    cfg.ambiguityNumberMin = 0; cfg.ambiguityNumberMax = 0;
    verifyWarning(testCase, @() pradar.unwrapTrackVelocity(input,80,400,cfg), 'pradar:NoUnwrapPath');
end

function testUnsortedInputRestoresOriginalOrder(testCase)
    [cfg, input, trueRadial] = fixture(1);
    order = [5:12 1:4];
    result = pradar.unwrapTrackVelocity(input(order,:),80,400,cfg);
    verifyEqual(testCase, result.UnwrappedRadialVelocity_mps, trueRadial(order), 'AbsTol', 1e-9);
end

function [cfg, input, trueRadial] = fixture(direction)
    cfg = pradar.defaultConfig(); cfg.unwrapMethod = "legacy";
    cfg.perpendicularDistance = 3; cfg.radialDirection = direction;
    cfg.measuredSpeed = 400; cfg.unwrapSpeedMin = 300; cfg.unwrapSpeedMax = 500;
    cfg.measuredSpeedStd = 5; cfg.distanceFitSpeedStd = 5; cfg.unwrapContinuityStd = 5;
    x = linspace(2,10,12).';
    if direction < 0, x = -flipud(x); end
    R = hypot(3,x); trueRadial = 400*x./R;
    input = table((0:11).',R,pradar.wrapVelocity(trueRadial,80), ...
        'VariableNames',{'Time_ms','Range_m','AliasedVelocity_mps'});
end
