function cfg = config_template()
%CONFIG_TEMPLATE Copy and edit this file for a new data set.

    cfg = pradar.defaultConfig();
    cfg.caseId = "replace_me";

    cfg.measuredSpeed = 400;        % m/s
    cfg.backgroundFrameStart = 1;
    cfg.backgroundFrameEnd = 8;
    cfg.targetFrameStart = 9;
    cfg.targetFrameEnd = 10;

    cfg.candidateRangeMin = 0.5;
    cfg.candidateRangeMax = 6.0;
    cfg.fitSpeedMin = 250;
    cfg.fitSpeedMax = 700;
    cfg.unwrapSpeedMin = 200;
    cfg.unwrapSpeedMax = 750;

    % Enable only when the expected aliased target velocity is safely away
    % from zero Doppler, or after validating that target attenuation is small.
    cfg.slowTimeMeanRemoval = true;
end
