function smoke_test_interfaces(outputDir, exportImages)
%SMOKE_TEST_INTERFACES Exercise UI construction and overview reload offline.
% Does not call any hardware/CLI commands. Signal Processing Toolbox is
% needed for the legacy overview RD calculation. Set exportImages=false in
% headless CI; screenshot export requires a desktop graphics stack.
    if nargin < 1, outputDir = fullfile(tempdir,'radar-ui-smoke'); end
    if nargin < 2, exportImages = true; end
    if ~isfolder(outputDir), mkdir(outputDir); end
    repoRoot = fileparts(fileparts(mfilename('fullpath')));
    startup;
    dataFile = fullfile(repoRoot,'data','123207_frames_126_135.bin');
    assert(isfile(dataFile),'Sample BIN missing.');
    app = RadarControlMachineApp;
    mainCleanup = onCleanup(@() close(app.UIFigure)); %#ok<NASGU>
    assert(~isprop(app,'UnwrapBtn'));
    app.DataPathEdit.Value = dataFile;
    feval(app.LoadBtn.ButtonPushedFcn, app.LoadBtn, []);
    app.ViewDropDown.Value = '最大 SNR 趋势图';
    feval(app.ViewDropDown.ValueChangedFcn,app.ViewDropDown,[]);
    plotted = findobj(app.UIAxes_SNR,'Type','line');
    assert(~isempty(plotted),'SNR trend was not plotted.');
    assert(numel(plotted(1).YData)==10,'Expected ten physical-frame SNR values.');
    app.OverviewStartEdit.Value = 3; app.OverviewEndEdit.Value = 6;
    drawnow;
    if exportImages
        exportapp(app.UIFigure,fullfile(outputDir,'interface1.png'));
    end

    cfg = radarui.buildProcessingConfig(struct('overviewTargetFrames',[3 6]));
    win = radarui.ProcessingWindow(dataFile,cfg);
    secondCleanup = onCleanup(@() delete(win)); %#ok<NASGU>
    assert(win.TargetStartEdit.Value==3 && win.TargetEndEdit.Value==6);
    win.ReferenceSpeedEdit.Value = 800;
    win.FitSpeedMinEdit.Value = 600;
    win.FitSpeedMaxEdit.Value = 1000;
    win.PerpendicularDistanceEdit.Value = 1;
    win.MinProjectionEdit.Value = 0.2;
    win.RadialDirectionDropDown.Value = '接近（距离减小）';
    cfg.overviewTargetFrames = [5 8];
    win.setInput(dataFile,cfg);
    assert(win.ReferenceSpeedEdit.Value==800);
    assert(win.FitSpeedMinEdit.Value==600 && win.FitSpeedMaxEdit.Value==1000);
    assert(win.PerpendicularDistanceEdit.Value==1);
    assert(win.MinProjectionEdit.Value==0.2);
    assert(strcmp(win.RadialDirectionDropDown.Value,'接近（距离减小）'));
    assert(win.TargetStartEdit.Value==5 && win.TargetEndEdit.Value==8);
    drawnow;
    if exportImages
        exportapp(win.UIFigure,fullfile(outputDir,'interface2.png'));
    end
    feval(win.RunButton.ButtonPushedFcn,win.RunButton,[]);
    assert(startsWith(win.StatusLabel.Text,'处理完成'), ...
        'Detailed processing did not complete: %s',win.StatusLabel.Text);
    assert(strcmp(win.ExportButton.Enable,'on'));
    fid = fopen(fullfile(outputDir,'ui-smoke-passed.txt'),'w');
    assert(fid >= 0);
    fprintf(fid,'PASS: overview load/SNR, frame handoff, geometry and speed setting retention, detailed processing.\n');
    fclose(fid);
    fprintf('UI smoke test passed: both windows and frame-selection handoff.\n');
end
