function addFrameLines(ax, numFrames, framePeriod, activeDuration)
%ADDFRAMELINES Mark active-frame boundaries and idle gaps.

    hold(ax, 'on');
    for frameIndex = 1:numFrames - 1
        activeEndMs = ...
            ((frameIndex - 1) * framePeriod + activeDuration) * 1e3;
        nextFrameStartMs = frameIndex * framePeriod * 1e3;
        xline(ax, activeEndMs, 'w:', 'LineWidth', 0.7);
        xline(ax, nextFrameStartMs, 'w:', 'LineWidth', 0.7);
    end
    hold(ax, 'off');
end
