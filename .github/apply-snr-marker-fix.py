from pathlib import Path
import hashlib

path = Path('uppermachine/RadarControlMachineApp.m')
raw = path.read_bytes()
assert hashlib.sha1(b'blob ' + str(len(raw)).encode() + b'\0' + raw).hexdigest() == '1718973ae9c77351da6fa5e958a9f20ba081e42f', 'App source changed; review before patching'
text = raw.decode('utf-8')

def replace(old, new):
    global text
    assert text.count(old) == 1, 'Patch anchor is missing or not unique: ' + old[:100]
    text = text.replace(old, new, 1)

replace('        hLegend_RawADC\n',
        '        hLegend_RawADC\n        hSnrCurrentFrameLine % Single owned marker for the overview frame\n')
replace('''            app.lastTrendLogWindowIdx = NaN;
        end

        function logCurrentTrendPoint''', '''            app.lastTrendLogWindowIdx = NaN;
            % cla alone does not delete ConstantLine objects with hidden handles.
            updateSnrCurrentFrameMarker(app, []);
            if ~isempty(app.UIAxes_SNR) && isgraphics(app.UIAxes_SNR)
                cla(app.UIAxes_SNR);
            end
        end

        function logCurrentTrendPoint''')
replace('''        function refreshTrendPlot(app, currentIdx)
''', '''        function updateSnrCurrentFrameMarker(app, physicalFrame)
            if isempty(app.UIAxes_SNR) || ~isgraphics(app.UIAxes_SNR)
                app.hSnrCurrentFrameLine = [];
                return;
            end

            % findall includes HandleVisibility='off' objects left by old code.
            % Constant lines in this overview axes represent the current frame.
            markers = findall(app.UIAxes_SNR, 'Type', 'constantline');
            if isempty(physicalFrame)
                delete(markers);
                app.hSnrCurrentFrameLine = [];
                return;
            end

            marker = app.hSnrCurrentFrameLine;
            if isscalar(marker) && isgraphics(marker) && ...
                    isequal(marker.Parent, app.UIAxes_SNR)
                % Keep one owned marker and remove any stale duplicates.
                delete(markers(markers ~= marker));
                marker.Value = physicalFrame;
                marker.Visible = 'on';
            else
                delete(markers);
                app.hSnrCurrentFrameLine = xline(app.UIAxes_SNR, ...
                    physicalFrame, '--', '当前帧', ...
                    'Tag', 'OverviewCurrentFrame', ...
                    'HandleVisibility', 'off', ...
                    'HitTest', 'off', 'PickableParts', 'none');
            end
        end

        function refreshTrendPlot(app, currentIdx)
''')
replace('''            if isempty(app.trendSnr), return; end
            [frameIndex, frameSnr]''', '''            if isempty(app.trendSnr)
                updateSnrCurrentFrameMarker(app, []);
                return;
            end
            [frameIndex, frameSnr]''')
replace('''            if nargin >= 2 && isfinite(currentIdx)
                physicalFrame = floor((currentIdx - 1) / app.windows_per_frame) + 1;
                xline(app.UIAxes_SNR, physicalFrame, '--', '当前帧', ...
                    'HandleVisibility', 'off');
            end
''', '''            physicalFrame = [];
            if nargin >= 2 && isscalar(currentIdx) && isfinite(currentIdx) && ...
                    currentIdx >= 1 && currentIdx <= numel(app.trendSnr)
                physicalFrame = floor((round(currentIdx) - 1) / app.windows_per_frame) + 1;
            end
            updateSnrCurrentFrameMarker(app, physicalFrame);
''')
replace('''            % Clear display/cache state created with the previous window
            % parameters before rebuilding the velocity axis and RD grid.
            app.current_rd_db_shifted = [];
''', '''            % Clear the previous file's SNR curve and hidden frame marker
            % before drawnow or any new-file parsing / precomputation can run.
            clearTrendCache(app);

            % Clear display/cache state created with the previous window
            % parameters before rebuilding the velocity axis and RD grid.
            app.current_rd_db_shifted = [];
''')
path.write_text(text, encoding='utf-8', newline='\n')
print('Patched', path)
