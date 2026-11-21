function tests = test_overviewSnr
    tests = functiontests(localfunctions);
end

function setupOnce(~)
    root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(root,'uppermachine'));
end

function testFrameMaximum(testCase)
    [f,y] = radarui.summarizeFrameSnr([1 9 4 2 3 5],3);
    verifyEqual(testCase,f,[1;2]); verifyEqual(testCase,y,[9;5]);
end

function testMissingWindowsRemainMissing(testCase)
    [f,y] = radarui.summarizeFrameSnr([NaN -Inf NaN 1 NaN 3],3);
    verifyEqual(testCase,f,[1;2]); verifyTrue(testCase,isnan(y(1)));
    verifyEqual(testCase,y(2),3);
end

function testEmptyAndPartialFrame(testCase)
    [f,y] = radarui.summarizeFrameSnr([],4);
    verifyEmpty(testCase,f); verifyEmpty(testCase,y);
    [f,y] = radarui.summarizeFrameSnr([1 2 3 4 9],4);
    verifyEqual(testCase,f,[1;2]); verifyEqual(testCase,y,[4;9]);
end

function testOverviewNoLongerOwnsUnwrapping(testCase)
    root = fileparts(fileparts(mfilename('fullpath')));
    code = fileread(fullfile(root,'uppermachine','RadarControlMachineApp.m'));
    removed = {'UnwrapBtn','ApproxSpeedEdit','PerpDistanceEdit', ...
        'FitConfirmButtonPushed','calculateSingleTargetUnwrappedSpeed','拟合趋势图'};
    for k=1:numel(removed), verifyFalse(testCase,contains(code,removed{k})); end
    verifyTrue(testCase,contains(code,'radarui.summarizeFrameSnr'));
    verifyTrue(testCase,contains(code,'appConfig.overviewTargetFrames'));
end

function testFrameSelectionHandoff(testCase)
    input = struct('overviewTargetFrames',[12 18]);
    cfg = radarui.buildProcessingConfig(input);
    verifyEqual(testCase,cfg.overviewTargetFrames,[12 18]);
    verifyEqual(testCase,cfg.perpendicularDistance,0);
end
