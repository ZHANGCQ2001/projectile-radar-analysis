function tests = test_runAnalysisCore
    tests = functiontests(localfunctions);
end

function testMinimalRepositoryDataRun(testCase)
    repoRoot = fileparts(fileparts(mfilename('fullpath')));
    dataFile = fullfile( ...
        repoRoot, 'data', '123207_frames_126_135.bin');

    assumeTrue(testCase, isfile(dataFile), ...
        'Repository sample BIN file is not available.');

    cfg = pradar.defaultConfig();
    cfg.caseId = "unit_core";
    cfg.measuredSpeed = 428.62203;
    cfg.winSize = 16;
    cfg.winStep = 16;
    cfg.dopplerFftSize = 128;
    cfg.slowTimeMeanRemoval = false;
    cfg.useFullAliasedVelocityAxis = true;

    cfg.backgroundFrameStart = 1;
    cfg.backgroundFrameEnd = 1;
    cfg.targetFrameStart = 2;
    cfg.targetFrameEnd = 2;

    cfg.candidateRangeMin = 0.25;
    cfg.candidateRangeMax = 6.0;
    cfg.candidateThresholdDb = 3.0;
    cfg.fitSpeedMin = 200;
    cfg.fitSpeedMax = 800;
    cfg.unwrapSpeedMin = 150;
    cfg.unwrapSpeedMax = 850;

    cfg.generateRdGif = false;
    cfg.plotVisible = false;
    cfg.saveResults = false;
    cfg.keepIntermediateData = false;

    result = pradar.runAnalysisCore(cfg, dataFile);

    verifyEqual(testCase, result.totalFrames, 10);
    verifySize(testCase, result.backgroundRdPower, ...
        [cfg.rangeFftSize, cfg.dopplerFftSize]);
    verifySize(testCase, result.rdEnhancedMeanDb, ...
        [cfg.rangeFftSize, cfg.dopplerFftSize]);
    verifyTrue(testCase, istable(result.candidateTable));
    verifyTrue(testCase, istable(result.trackTable));
    verifyTrue(testCase, isstruct(result.fitInfo));
    verifyTrue(testCase, isstruct(result.velocityMetrics));
    verifyEmpty(testCase, result.rdEnhancedDb);
    verifyEmpty(testCase, result.targetData.rdPowerCube);
end
