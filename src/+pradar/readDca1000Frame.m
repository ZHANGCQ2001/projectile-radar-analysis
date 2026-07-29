function adcFrame = readDca1000Frame(fid, frameIndex, cfg, derived)
%READDCA1000FRAME Read one physical frame and return Sample x Chirp x Rx.

    arguments
        fid (1,1) double
        frameIndex (1,1) double {mustBeInteger, mustBePositive}
        cfg struct
        derived struct
    end

    byteOffset = (frameIndex - 1) * derived.bytesPerFrame;

    if fseek(fid, byteOffset, 'bof') ~= 0
        error('pradar:FileSeekFailed', ...
            'Unable to seek to physical frame %d.', frameIndex);
    end

    rawData = fread(fid, derived.uint16PerFrame, 'uint16=>double');

    if numel(rawData) ~= derived.uint16PerFrame
        error('pradar:IncompleteFrame', ...
            'Physical frame %d is incomplete.', frameIndex);
    end

    negativeMask = rawData >= 2^15;
    rawData(negativeMask) = rawData(negativeMask) - 2^16;

    adcComplex = complex(rawData(1:2:end), rawData(2:2:end));
    adcComplex = reshape( ...
        adcComplex, cfg.numSamples, cfg.numRx, cfg.numChirpsPerFrame);

    adcFrame = single(permute(adcComplex, [1, 3, 2]));
end
