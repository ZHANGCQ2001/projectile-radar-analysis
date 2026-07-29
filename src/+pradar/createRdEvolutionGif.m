function createRdEvolutionGif( ...
        rdEnhancedDb, targetData, derived, cfg, outputPath)
%CREATERDEVOLUTIONGIF Export enhanced RD windows as an animated GIF.

    numWindows = size(rdEnhancedDb, 3);
    if numWindows < 1
        warning('pradar:NoGifFrames', 'No RD windows are available.');
        return;
    end

    if exist(outputPath, 'file')
        delete(outputPath);
    end

    visibleValue = 'off';
    if cfg.rdGifVisible
        visibleValue = 'on';
    end

    fig = figure('Name', 'Enhanced RD evolution', 'Color', 'w', ...
        'Visible', visibleValue, 'Position', [100, 100, 980, 760]);
    ax = axes(fig);
    imageHandle = imagesc( ...
        ax, derived.velocityAxis, derived.rangeAxis, ...
        double(rdEnhancedDb(:, :, 1)));
    ax.YDir = 'normal';
    xlabel(ax, 'Aliased velocity (m/s)');
    ylabel(ax, 'Range (m)');
    xlim(ax, [min(derived.velocityAxis), max(derived.velocityAxis)]);
    ylim(ax, [cfg.rdGifRangeMin, cfg.rdGifRangeMax]);
    caxis(ax, cfg.rdGifClim);
    colormap(ax, turbo);
    colorbar(ax);

    temporaryPng = [tempname, '.png'];
    cleanupObject = onCleanup(@() cleanupResources(fig, temporaryPng)); %#ok<NASGU>

    for windowIndex = 1:numWindows
        set(imageHandle, 'CData', double(rdEnhancedDb(:, :, windowIndex)));
        physicalFrame = targetData.windowPhysicalFrame(windowIndex);
        localWindow = targetData.windowIndexInFrame(windowIndex);
        centerTimeMs = targetData.windowTimeMs(windowIndex);
        chirpStart = (localWindow - 1) * cfg.winStep + 1;
        chirpEnd = chirpStart + cfg.winSize - 1;

        title(ax, { ...
            '2-D FFT background-enhanced RD evolution', ...
            sprintf(['Frame %d | Window %d/%d | Chirp %d-%d | ' ...
                'FFT %d | Center %.3f ms'], ...
                physicalFrame, localWindow, derived.windowsPerFrame, ...
                chirpStart, chirpEnd, cfg.dopplerFftSize, centerTimeMs)}, ...
            'Interpreter', 'none');
        drawnow;

        print(fig, temporaryPng, '-dpng', ...
            sprintf('-r%d', cfg.rdGifResolution));
        rgbFrame = imread(temporaryPng);
        [indexedFrame, colorMap] = rgb2ind(rgbFrame, 256, 'nodither');

        if windowIndex == 1
            imwrite(indexedFrame, colorMap, outputPath, 'gif', ...
                'LoopCount', Inf, 'DelayTime', cfg.rdGifDelayTime);
        else
            imwrite(indexedFrame, colorMap, outputPath, 'gif', ...
                'WriteMode', 'append', 'DelayTime', cfg.rdGifDelayTime);
        end
    end
end

function cleanupResources(fig, temporaryPng)
    if exist(temporaryPng, 'file')
        delete(temporaryPng);
    end
    if isgraphics(fig)
        close(fig);
    end
end
