function [rangeTimeMapDb, aliasVelocityMap] = ...
        compressRdToRangeProfile(rdEnhancedDb, derived)
%COMPRESSRDTORANGEPROFILE Max-compress RD enhancement along velocity.

    selectedRd = rdEnhancedDb(:, derived.velocityMask, :);
    [rangeMaximum, velocityIndex] = max(selectedRd, [], 2);

    rangeTimeMapDb = reshape( ...
        rangeMaximum, size(rdEnhancedDb, 1), size(rdEnhancedDb, 3));
    velocityIndex = reshape( ...
        velocityIndex, size(rdEnhancedDb, 1), size(rdEnhancedDb, 3));

    aliasVelocityMap = nan(size(rangeTimeMapDb), 'single');
    for windowIndex = 1:size(rangeTimeMapDb, 2)
        aliasVelocityMap(:, windowIndex) = single( ...
            derived.selectedVelocityAxis(velocityIndex(:, windowIndex)));
    end
end
