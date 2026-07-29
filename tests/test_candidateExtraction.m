function tests = test_candidateExtraction
    tests = functiontests(localfunctions);
end

function testThreeSeparatedPeaks(testCase)
    cfg = pradar.defaultConfig();
    cfg.measuredSpeed = 400;
    cfg.candidateRangeMin = 0.5;
    cfg.candidateRangeMax = 4.5;
    cfg.candidateThresholdDb = 7;
    cfg.maxCandidatesPerWindow = 3;
    cfg.minCandidateSeparation = 0.5;
    cfg.rangeSmoothBins = 1;

    rangeAxis = (0:0.1:5).';
    map = zeros(numel(rangeAxis), 1);
    map(13) = 18;  % 1.2 m
    map(26) = 12;  % 2.5 m
    map(41) = 9;   % 4.0 m
    velocityMap = zeros(size(map));
    velocityMap(13) = -55;
    velocityMap(26) = 60;
    velocityMap(41) = 0;

    targetData.windowPhysicalFrame = 1;
    targetData.windowIndexInFrame = 1;
    targetData.windowTimeMs = 0.192;

    tableValue = pradar.extractCandidates( ...
        map, velocityMap, targetData, rangeAxis, cfg);
    verifyEqual(testCase, height(tableValue), 3);
    verifyEqual(testCase, sort(tableValue.Range_m), [1.2; 2.5; 4.0], ...
        'AbsTol', 1e-12);
end
