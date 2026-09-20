function output = processWindow(adcWindow, cfg, derived)
%PROCESSWINDOW Process one Sample x Chirp x Rx window into RD products.
%
%   output = pradar.processWindow(adcWindow, cfg, derived)
%
%   The returned structure contains:
%       rangeFft      - range FFT result
%       rangeDoppler  - fftshifted Doppler FFT result
%       rdPower       - noncoherent RX-summed RD power
%       rdDb          - RD power in dB
%
%   Slow-time mean removal is controlled by cfg.slowTimeMeanRemoval.

    if ndims(adcWindow) ~= 3
        error('pradar:InvalidWindowData', ...
            'adcWindow must be Sample x Chirp x Rx.');
    end

    if size(adcWindow, 1) ~= cfg.numSamples
        error('pradar:InvalidWindowData', ...
            'adcWindow sample count does not match cfg.numSamples.');
    end

    if size(adcWindow, 2) ~= cfg.winSize
        error('pradar:InvalidWindowData', ...
            'adcWindow chirp count does not match cfg.winSize.');
    end

    if size(adcWindow, 3) ~= cfg.numRx
        error('pradar:InvalidWindowData', ...
            'adcWindow RX count does not match cfg.numRx.');
    end

    workingWindow = adcWindow;
    if cfg.slowTimeMeanRemoval
        workingWindow = workingWindow - mean(workingWindow, 2);
    end

    rangeFft = fft( ...
        workingWindow .* derived.rangeWindow, ...
        cfg.rangeFftSize, 1);

    rangeDoppler = fftshift( ...
        fft( ...
            rangeFft .* derived.dopplerWindow, ...
            cfg.dopplerFftSize, 2), ...
        2);

    rdPower = sum(abs(rangeDoppler).^2, 3);

    output = struct();
    output.rangeFft = rangeFft;
    output.rangeDoppler = rangeDoppler;
    output.rdPower = single(rdPower);
    output.rdDb = 10 * log10(double(rdPower) + 1e-12);
end
