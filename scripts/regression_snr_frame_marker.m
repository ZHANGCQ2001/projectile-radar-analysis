function regression_snr_frame_marker(outputDir)
%REGRESSION_SNR_FRAME_MARKER Check one marker during navigation and reload.
% Offline App callback regression; no FPGA/CLI acquisition commands are run.
% Requires Signal Processing Toolbox for the existing overview RD pipeline.
    if nargin < 1, outputDir = fullfile(tempdir, 'radar-snr-marker-test'); end
    if ~isfolder(outputDir), mkdir(outputDir); end
    root = fileparts(fileparts(mfilename('fullpath')));
    startup;
    dataFile = fullfile(root, 'data', '123207_frames_126_135.bin');
    assert(isfile(dataFile), 'Repository sample BIN is missing.');

    % Use a different, shorter BIN to catch stale axes across file changes.
    tmpDir = tempname;
    mkdir(tmpDir);
    tmpCleanup = onCleanup(@() rmdir(tmpDir, 's')); %#ok<NASGU>
    shortFile = fullfile(tmpDir, 'three_frames.bin');
    bytesPerFrame = 64 * 256 * 8 * 4;
    copyFirstBytes(dataFile, shortFile, 3 * bytesPerFrame);

    app = RadarControlMachineApp;
    appCleanup = onCleanup(@() close(app.UIFigure)); %#ok<NASGU>
    loadFile(app, dataFile);
    selectView(app, '最大 SNR 趋势图');
    marker = assertMarker(app, 1);
    initialSnr = assertCurve(app, 10);

    % Slider navigation, repeats, backward jumps, and the end frame.
    for windowIndex = [1 5 10 4 1 10 10 2]
        visitWindow(app, windowIndex);
        current = assertMarker(app, windowIndex);
        assert(isequal(current, marker), 'Navigation recreated the marker.');
        assert(isequaln(assertCurve(app, 10), initialSnr), ...
            'Moving the marker changed the SNR data.');
    end
    feval(app.NextButton.ButtonPushedFcn, app.NextButton, []);
    assertMarker(app, 3);
    feval(app.PrevButton.ButtonPushedFcn, app.PrevButton, []);
    assertMarker(app, 2);

    % View switches must not recreate or accumulate markers.
    for k = 1:3
        selectView(app, '频点 RD 图');
        selectView(app, '最大 SNR 趋势图');
        assert(isequal(assertMarker(app, 2), marker));
    end

    % Simulate unowned hidden lines from the previous implementation.
    stale = xline(app.UIAxes_SNR, [3 7], '--', '当前帧', ...
        'HandleVisibility', 'off');
    visitWindow(app, 6);
    assert(isequal(assertMarker(app, 6), marker));
    assert(~any(isgraphics(stale)), 'Legacy hidden markers were not removed.');

    % A reload must destroy the old marker, including hidden leftovers.
    stale = xline(app.UIAxes_SNR, 9, '--', '当前帧', ...
        'HandleVisibility', 'off');
    loadFile(app, shortFile);
    shortMarker = assertMarker(app, 1);
    assert(~isgraphics(marker) && ~isgraphics(stale));
    assertCurve(app, 3);
    visitWindow(app, 3);
    assert(isequal(assertMarker(app, 3), shortMarker));
    loadFile(app, dataFile);
    assert(~isgraphics(shortMarker));
    assertMarker(app, 1);
    assertCurve(app, 10);

    % Match the reported setting: 64 chirps / step 64 -> four windows/frame.
    feval(app.SettingsBtn.ButtonPushedFcn, app.SettingsBtn, []);
    settings = findall(groot, 'Type', 'figure', 'Name', '参数配置');
    assert(isscalar(settings), 'Expected one settings dialog.');
    fields = findall(settings, '-isa', 'matlab.ui.control.NumericEditField');
    winSize = fields(arrayfun(@(h) isequal(h.Position, [190 265 120 22]), fields));
    winStep = fields(arrayfun(@(h) isequal(h.Position, [190 230 120 22]), fields));
    assert(isscalar(winSize) && isscalar(winStep));
    winSize.Value = 64;
    winStep.Value = 64;
    saveButton = findall(settings, '-isa', 'matlab.ui.control.Button', ...
        'Text', '保存并应用');
    feval(saveButton.ButtonPushedFcn, saveButton, []);
    assert(isempty(findall(app.UIAxes_SNR, 'Type', 'constantline')), ...
        'Settings invalidation retained a current-frame marker.');
    loadFile(app, dataFile);
    marker = assertMarker(app, 1);
    for windowIndex = [1 2 4 5 19 38 40 1]
        visitWindow(app, windowIndex);
        expectedFrame = floor((windowIndex - 1) / 4) + 1;
        assert(isequal(assertMarker(app, expectedFrame), marker));
        assertCurve(app, 10);
    end
    loadFile(app, shortFile);
    assert(~isgraphics(marker));
    assertMarker(app, 1);
    assertCurve(app, 3);

    % If axes contents are cleared externally, recover exactly one marker.
    cla(app.UIAxes_SNR, 'reset');
    visitWindow(app, 9);
    assertMarker(app, 3);
    assertCurve(app, 3);
    drawnow;

    fid = fopen(fullfile(outputDir, 'snr-frame-marker-passed.txt'), 'w');
    assert(fid >= 0);
    fileCleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, ['PASS: single current-frame marker; slider/prev/next; view changes; ' ...
        'legacy hidden-line cleanup; long-short-long file reload; settings reset; ' ...
        'four windows per frame; axes reset recovery; unchanged SNR values.\n']);
    fprintf('SNR frame marker regression passed.\n');
end

function marker = assertMarker(app, expectedFrame)
    % findall is essential: findobj would hide the exact objects being tested.
    marker = findall(app.UIAxes_SNR, 'Type', 'constantline');
    assert(numel(marker) == 1, 'Expected exactly one frame marker; found %d.', numel(marker));
    assert(marker.Value == expectedFrame, 'Marker does not match current physical frame.');
    assert(strcmp(marker.Label, '当前帧'));
    assert(strcmp(marker.Tag, 'OverviewCurrentFrame'));
    assert(strcmp(marker.Visible, 'on'));
end

function y = assertCurve(app, expectedFrames)
    curve = findall(app.UIAxes_SNR, 'Type', 'line');
    assert(isscalar(curve), 'Expected exactly one SNR curve.');
    assert(numel(curve.YData) == expectedFrames);
    y = curve.YData;
end

function visitWindow(app, windowIndex)
    app.FrameSlider.Value = windowIndex;
    feval(app.FrameSlider.ValueChangedFcn, app.FrameSlider, []);
end

function selectView(app, name)
    app.ViewDropDown.Value = name;
    feval(app.ViewDropDown.ValueChangedFcn, app.ViewDropDown, []);
end

function loadFile(app, file)
    app.DataPathEdit.Value = file;
    feval(app.LoadBtn.ButtonPushedFcn, app.LoadBtn, []);
end

function copyFirstBytes(source, target, count)
    input = fopen(source, 'rb');
    assert(input >= 0);
    inputCleanup = onCleanup(@() fclose(input)); %#ok<NASGU>
    bytes = fread(input, count, '*uint8');
    assert(numel(bytes) == count);
    output = fopen(target, 'wb');
    assert(output >= 0);
    outputCleanup = onCleanup(@() fclose(output)); %#ok<NASGU>
    assert(fwrite(output, bytes, 'uint8') == count);
end
