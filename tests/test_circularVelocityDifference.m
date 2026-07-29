function tests = test_circularVelocityDifference
    tests = functiontests(localfunctions);
end

function testBoundaryCrossing(testCase)
    period = 161.94;
    actual = pradar.circularVelocityDifference(78, -80, period);
    verifyEqual(testCase, actual, 3.94, 'AbsTol', 1e-10);
end

function testSymmetry(testCase)
    period = 161.94;
    a = pradar.circularVelocityDifference(20, -70, period);
    b = pradar.circularVelocityDifference(-70, 20, period);
    verifyEqual(testCase, a, b, 'AbsTol', 1e-12);
end
