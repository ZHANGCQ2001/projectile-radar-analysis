function tests = test_enhancePower
    tests = functiontests(localfunctions);
end

function testPowerRatio(testCase)
    target = single([1, 10, 100]);
    background = single([1, 1, 10]);
    actual = pradar.enhancePower(target, background);
    expected = [0, 10, 10];
    verifyEqual(testCase, double(actual), expected, 'AbsTol', 1e-5);
end
