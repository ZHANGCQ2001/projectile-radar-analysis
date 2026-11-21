function [frameIndex, frameSnr] = summarizeFrameSnr(windowSnr, windowsPerFrame)
%SUMMARIZEFRAMESNR Collapse window maxima to one maximum per physical frame.
% Invalid windows remain missing; a frame with no finite SNR is NaN.
    validateattributes(windowsPerFrame, {'numeric'}, ...
        {'scalar', 'integer', 'positive', 'finite'});
    if isempty(windowSnr)
        frameIndex = zeros(0,1); frameSnr = zeros(0,1); return;
    end
    validateattributes(windowSnr, {'numeric'}, {'vector'});
    windowSnr = double(windowSnr(:));
    nFrames = ceil(numel(windowSnr) / windowsPerFrame);
    frameIndex = (1:nFrames).';
    frameSnr = nan(nFrames, 1);
    for k = 1:nFrames
        values = windowSnr((k-1)*windowsPerFrame+1:min(k*windowsPerFrame, numel(windowSnr)));
        values = values(isfinite(values));
        if ~isempty(values), frameSnr(k) = max(values); end
    end
end
