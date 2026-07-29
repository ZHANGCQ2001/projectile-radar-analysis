function output = processFrameRange(fid, frameStart, frameEnd, cfg, derived)
%PROCESSFRAMERANGE Process physical frames into range-time and RD power cubes.

    numFrames = frameEnd - frameStart + 1;
    totalChirps = numFrames * cfg.numChirpsPerFrame;
    totalWindows = numFrames * derived.windowsPerFrame;

    output.rangePowerTime = nan( ...
        cfg.rangeFftSize, totalChirps, 'single');
    output.chirpTimeMs = nan(1, totalChirps);
    output.rdPowerCube = nan( ...
        cfg.rangeFftSize, cfg.dopplerFftSize, totalWindows, 'single');
    output.windowTimeMs = nan(1, totalWindows);
    output.windowPhysicalFrame = nan(1, totalWindows);
    output.windowIndexInFrame = nan(1, totalWindows);
    output.numFrames = numFrames;

    chirpColumn = 1;
    windowColumn = 1;

    for frameIndex = frameStart:frameEnd
        fprintf('  Processing physical frame %d / %d\n', ...
            frameIndex, frameEnd);

        adcFrame = pradar.readDca1000Frame( ...
            fid, frameIndex, cfg, derived);

        rangeFftAll = fft( ...
            adcFrame .* derived.rangeWindow, cfg.rangeFftSize, 1);
        rangePower = sum(abs(rangeFftAll).^2, 3);

        chirpEndColumn = chirpColumn + cfg.numChirpsPerFrame - 1;
        chirpColumns = chirpColumn:chirpEndColumn;
        output.rangePowerTime(:, chirpColumns) = single(rangePower);

        relativeFrameIndex = frameIndex - frameStart;
        output.chirpTimeMs(chirpColumns) = ...
            (relativeFrameIndex * cfg.framePeriod ...
            + (0:cfg.numChirpsPerFrame - 1) * cfg.chirpPeriod) * 1e3;
        chirpColumn = chirpEndColumn + 1;

        for localWindowIndex = 1:derived.windowsPerFrame
            chirpStart = (localWindowIndex - 1) * cfg.winStep + 1;
            chirpEnd = chirpStart + cfg.winSize - 1;
            chirpIndices = chirpStart:chirpEnd;

            adcWindow = adcFrame(:, chirpIndices, :);
            if cfg.slowTimeMeanRemoval
                adcWindow = adcWindow - mean(adcWindow, 2);
            end

            rangeFftWindow = fft( ...
                adcWindow .* derived.rangeWindow, cfg.rangeFftSize, 1);
            windowedRangeData = rangeFftWindow .* derived.dopplerWindow;
            rangeDoppler = fftshift( ...
                fft(windowedRangeData, cfg.dopplerFftSize, 2), 2);
            rdPower = sum(abs(rangeDoppler).^2, 3);
            output.rdPowerCube(:, :, windowColumn) = single(rdPower);

            windowCenterChirp = ...
                (chirpStart - 1) + (cfg.winSize - 1) / 2;
            output.windowTimeMs(windowColumn) = ...
                (relativeFrameIndex * cfg.framePeriod ...
                + windowCenterChirp * cfg.chirpPeriod) * 1e3;
            output.windowPhysicalFrame(windowColumn) = frameIndex;
            output.windowIndexInFrame(windowColumn) = localWindowIndex;
            windowColumn = windowColumn + 1;
        end
    end
end
