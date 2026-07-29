function enhancedDb = enhancePower(targetPower, backgroundPower)
%ENHANCEPOWER Calculate a target-to-background power ratio in dB.

    powerFloor = single(1e-12);
    enhancedDb = 10 * log10( ...
        (targetPower + powerFloor) ./ (backgroundPower + powerFloor));
end
