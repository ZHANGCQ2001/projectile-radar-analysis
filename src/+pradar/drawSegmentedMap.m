function ax = drawSegmentedMap( ...
        timeAxisMs, rangeAxis, mapData, columnsPerFrame, numFrames, ...
        figureName, titleText, rangeLimits, colorLimits, visibleValue)
%DRAWSEGMENTEDMAP Draw frame segments while preserving inter-frame gaps.

    if nargin < 10
        visibleValue = 'on';
    end

    fig = figure('Name', figureName, 'Color', 'w', ...
        'Visible', visibleValue);
    ax = axes(fig);
    hold(ax, 'on');

    for frameIndex = 1:numFrames
        startColumn = (frameIndex - 1) * columnsPerFrame + 1;
        endColumn = min(frameIndex * columnsPerFrame, size(mapData, 2));
        columns = startColumn:endColumn;
        if isempty(columns)
            continue;
        end
        imagesc(ax, timeAxisMs(columns), rangeAxis, mapData(:, columns));
    end

    ax.YDir = 'normal';
    ylim(ax, rangeLimits);
    caxis(ax, colorLimits);
    colormap(ax, turbo);
    colorbar(ax);
    grid(ax, 'on');
    xlabel(ax, 'Time (ms)');
    ylabel(ax, 'Range (m)');
    title(ax, titleText, 'Interpreter', 'none');
    hold(ax, 'off');
end
