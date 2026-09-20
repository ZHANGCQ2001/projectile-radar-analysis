function tests = test_trackScoring
    tests = functiontests(localfunctions);
end

function testStrongProjectileBeatsWeakDenseClutter(testCase)
    cfg = pradar.defaultConfig();
    cfg.measuredSpeed = 400;
    cfg.trackTolerance = 0.25;
    cfg.useVelocityHardGate = false;
    cfg.candidateThresholdDb = 3;

    derived = pradar.deriveParameters(cfg);

    speed = 400;
    aliasVelocity = pradar.wrapVelocity(speed, derived.vMax);

    window = (1:10).';
    timeMs = (0:9).';

    clutterRange = 3.0 + speed * timeMs * 1e-3;
    clutterStrength = repmat(8, 10, 1);

    projectileWindows = (2:9).';
    projectileTimeMs = timeMs(projectileWindows);
    projectileRange = 0.5 + speed * projectileTimeMs * 1e-3;
    projectileStrength = repmat(25, numel(projectileWindows), 1);

    globalWindow = [window; projectileWindows];
    physicalFrame = ones(size(globalWindow));
    windowInFrame = globalWindow;
    timeAll = [timeMs; projectileTimeMs];
    rangeAll = [clutterRange; projectileRange];
    velocityAll = repmat(aliasVelocity, size(globalWindow));
    strengthAll = [clutterStrength; projectileStrength];
    rangeBin = ones(size(globalWindow));

    candidates = table( ...
        globalWindow, physicalFrame, windowInFrame, timeAll, rangeAll, ...
        velocityAll, strengthAll, rangeBin, ...
        'VariableNames', { ...
            'GlobalWindow', 'PhysicalFrame', 'WindowInFrame', ...
            'Time_ms', 'Range_m', 'AliasedVelocity_mps', ...
            'RelativeStrength_dB', 'RangeBin'});

    clutterIntercept = 3.0;
    projectileIntercept = 0.5;

    [~, ~, ~, clutterMetric] = pradar.associateCandidates( ...
        candidates, speed, clutterIntercept, cfg, derived);

    [~, ~, ~, projectileMetric] = pradar.associateCandidates( ...
        candidates, speed, projectileIntercept, cfg, derived);

    verifyGreaterThan(testCase, projectileMetric, clutterMetric);
end
