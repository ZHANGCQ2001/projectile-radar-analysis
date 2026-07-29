function tests = test_wrapVelocity
    tests = functiontests(localfunctions);
end

function testKnownValue(testCase)
    vMax = 80.967;
    velocity = 428.62203;
    expected = mod(velocity + vMax, 2 * vMax) - vMax;
    actual = pradar.wrapVelocity(velocity, vMax);
    verifyEqual(testCase, actual, expected, 'AbsTol', 1e-12);
end

function testOutputRange(testCase)
    vMax = 80.967;
    values = -1000:0.25:1000;
    wrapped = pradar.wrapVelocity(values, vMax);
    verifyGreaterThanOrEqual(testCase, wrapped, -vMax);
    verifyLessThan(testCase, wrapped, vMax);
end
