function output = processFrameRange( ...
        fid, frameStart, frameEnd, cfg, derived, ...
        progressFcn, cancelFcn, stageName)
%PROCESSFRAMERANGE Process physical frames into range-time and RD products.
%
%   The first five arguments preserve the original API.
%   Optional arguments are used by GUI callers:
%       progressFcn(stageName, completedFrames, totalFrames)
%       cancelFcn() -> logical
%       stageName   -> string/char label

    if nargin < 6
        progressFcn = [];
    end
    if nargin < 7
        cancelFcn = [];
    end
    if nargin < 8 || strlength(string(stageName)) == 0
        stageName = "frames";
    end

    numFrames = frameEnd - frameStart + 1;
    totalChirps = numFrames * cfg.numChirpsPerFrame;
    totalWindows = numFrames * derived.windowsPerFrame;

    output.rangePowerTime = nan( ...
        cfg.rangeFftSize, totalChirps, 'single');
    output.chirpTimeMs = nan(1, totalChirps);
    output.rdPowerCube = nan( ...
        cfg.rangeFftSize, cfg.dopplerFftSize, ...
        totalWindows, 'single');
    output.windowTimeMs = nan(1, totalWindows);
    output.windowPhysicalFrame = nan(1, totalWindows);
    output.windowIndexInFrame = nan(1, totalWindows);
    output.numFrames = numFrames;

    chirpColumn = 1;
    windowColumn = 1;

    for frameIndex = frameStart:frameEnd
        checkCancelled(cancelFcn);

        completedFrames = frameIndex - frameStart;

        if isempty(progressFcn)
            fprintf('  Processing physical frame %d / %d\n', ...
                frameIndex, frameEnd);
        else
            progressFcn(stageName, completedFrames, numFrames);
        end

        adcFrame = pradar.readDca1000Frame( ...
            fid, frameIndex, cfg, derived);

        rangeFftAll = fft( ...
            adcFrame .* derived.rangeWindow, ...
            cfg.rangeFftSize, 1);
        rangePower = sum(abs(rangeFftAll).^2, 3);

        chirpEndColumn = ...
            chirpColumn + cfg.numChirpsPerFrame - 1;
        chirpColumns = chirpColumn:chirpEndColumn;

        output.rangePowerTime(:, chirpColumns) = ...
            single(rangePower);

        relativeFrameIndex = frameIndex - frameStart;
        output.chirpTimeMs(chirpColumns) = ...
            (relativeFrameIndex * cfg.framePeriod ...
            + (0:cfg.numChirpsPerFrame - 1) ...
            * cfg.chirpPeriod) * 1e3;

        chirpColumn = chirpEndColumn + 1;

        for localWindowIndex = 1:derived.windowsPerFrame
            checkCancelled(cancelFcn);

            chirpStart = ...
                (localWindowIndex - 1) * cfg.winStep + 1;
            chirpEnd = chirpStart + cfg.winSize - 1;
            chirpIndices = chirpStart:chirpEnd;

            adcWindow = adcFrame(:, chirpIndices, :);
            windowResult = pradar.processWindow( ...
                adcWindow, cfg, derived);

            output.rdPowerCube(:, :, windowColumn) = ...
                windowResult.rdPower;

            windowCenterChirp = ...
                (chirpStart - 1) + (cfg.winSize - 1) / 2;

            output.windowTimeMs(windowColumn) = ...
                (relativeFrameIndex * cfg.framePeriod ...
                + windowCenterChirp * cfg.chirpPeriod) * 1e3;

            output.windowPhysicalFrame(windowColumn) = frameIndex;
            output.windowIndexInFrame(windowColumn) = ...
                localWindowIndex;

            windowColumn = windowColumn + 1;
        end

        if ~isempty(progressFcn)
            progressFcn(stageName, ...
                completedFrames + 1, numFrames);
        end
    end
end

function checkCancelled(cancelFcn)
    if ~isempty(cancelFcn) && cancelFcn()
        error('pradar:Cancelled', ...
            'Processing was cancelled by the user.');
    end
end
