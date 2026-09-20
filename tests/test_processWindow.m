function tests = test_processWindow
    tests = functiontests(localfunctions);
end

function testOutputShapesAndPower(testCase)
    cfg = pradar.defaultConfig();
    cfg.measuredSpeed = 400;
    cfg.winSize = 16;
    cfg.winStep = 16;
    cfg.dopplerFftSize = 128;
    cfg.slowTimeMeanRemoval = false;

    derived = pradar.deriveParameters(cfg);

    rng(1);
    realPart = randn( ...
        cfg.numSamples, cfg.winSize, cfg.numRx, 'single');
    imagPart = randn( ...
        cfg.numSamples, cfg.winSize, cfg.numRx, 'single');
    adcWindow = complex(realPart, imagPart);

    output = pradar.processWindow(adcWindow, cfg, derived);

    verifyEqual(testCase, ...
        size(output.rangeFft), ...
        [cfg.rangeFftSize, cfg.winSize, cfg.numRx]);

    verifyEqual(testCase, ...
        size(output.rangeDoppler), ...
        [cfg.rangeFftSize, cfg.dopplerFftSize, cfg.numRx]);

    verifyEqual(testCase, ...
        size(output.rdPower), ...
        [cfg.rangeFftSize, cfg.dopplerFftSize]);

    verifyEqual(testCase, ...
        size(output.rdDb), ...
        [cfg.rangeFftSize, cfg.dopplerFftSize]);

    verifyGreaterThanOrEqual(testCase, ...
        min(output.rdPower(:)), single(0));

    verifyTrue(testCase, all(isfinite(output.rdDb(:))));
end

function testMeanRemovalSuppressesConstantSlowTime(testCase)
    cfg = pradar.defaultConfig();
    cfg.measuredSpeed = 400;
    cfg.winSize = 16;
    cfg.winStep = 16;
    cfg.dopplerFftSize = 128;
    cfg.slowTimeMeanRemoval = true;

    derived = pradar.deriveParameters(cfg);

    base = complex( ...
        ones(cfg.numSamples, 1, cfg.numRx, 'single'), ...
        zeros(cfg.numSamples, 1, cfg.numRx, 'single'));
    adcWindow = repmat(base, 1, cfg.winSize, 1);

    output = pradar.processWindow(adcWindow, cfg, derived);

    verifyLessThan(testCase, ...
        max(abs(output.rdPower(:))), single(1e-8));
end
