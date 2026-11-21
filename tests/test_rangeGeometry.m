function tests = test_rangeGeometry
    tests = functiontests(localfunctions);
end

function testThreeFourFiveGeometry(testCase)
    cfg = pradar.defaultConfig(); cfg.perpendicularDistance = 3;
    [c, valid, x] = pradar.rangeGeometry(5, cfg);
    verifyTrue(testCase, valid);
    verifyEqual(testCase, c, 0.8, 'AbsTol', 1e-12);
    verifyEqual(testCase, x, 4, 'AbsTol', 1e-12);
    cfg.radialDirection = -1;
    [c, valid, x] = pradar.rangeGeometry(5, cfg);
    verifyTrue(testCase, valid);
    verifyEqual(testCase, [c x], [-0.8 -4], 'AbsTol', 1e-12);
end

function testInvalidAndNearPerpendicularRanges(testCase)
    cfg = pradar.defaultConfig(); cfg.perpendicularDistance = 3;
    [c, valid, x] = pradar.rangeGeometry([2; 3; NaN; Inf; 3.000001; 5], cfg);
    verifyEqual(testCase, valid, [false(5,1); true]);
    verifyTrue(testCase, all(isnan(c(1:5))));
    verifyTrue(testCase, all(isnan(x(1:5))));
end

function testZeroOffsetCompatibility(testCase)
    cfg = pradar.defaultConfig();
    [c, valid, x] = pradar.rangeGeometry([1; 5; 10], cfg);
    verifyEqual(testCase, c, ones(3,1));
    verifyTrue(testCase, all(valid));
    verifyEqual(testCase, x, [1; 5; 10]);
end

function testGeometryConfigValidation(testCase)
    cfg = pradar.defaultConfig(); cfg.measuredSpeed = 400;
    cfg.radialDirection = 0;
    verifyError(testCase, @() pradar.validateConfig(cfg), 'pradar:InvalidRadialDirection');
    cfg.radialDirection = 1; cfg.perpendicularDistance = -1;
    caught = false;
    try, pradar.validateConfig(cfg); catch, caught = true; end
    verifyTrue(testCase, caught);
end
